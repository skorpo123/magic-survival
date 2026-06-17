class_name MeteorProjectile extends Node2D

var direction: Vector2 = Vector2.ZERO
var spell: Spell
var _is_active: bool = false
var _speed: float = 300.0
var _damage: float = 0.0
var _impact_radius: float = 60.0
var _start_pos: Vector2 = Vector2.ZERO
var _target_pos: Vector2 = Vector2.ZERO
var _total_distance: float = 0.0
var _distance_traveled: float = 0.0
var _trail: BurstParticles2D = null
var _sprite: AnimatedSprite2D = null
var _glow: Sprite2D = null
var _impact_done: bool = false
var _visual_mult: float = 1.0

static var _shared_material: CanvasItemMaterial = null
static var _shared_frames: SpriteFrames = null
static var _glow_texture: ImageTexture = null

func _ready() -> void:
	z_index = 3
	_build_visual()
	set_physics_process(false)

func _get_shared_material() -> CanvasItemMaterial:
	if not _shared_material:
		_shared_material = CanvasItemMaterial.new()
		_shared_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_material

func _get_shared_frames() -> SpriteFrames:
	if not _shared_frames:
		_shared_frames = SpriteFrames.new()
		_shared_frames.add_animation("fly")
		_shared_frames.set_animation_speed("fly", 20.0)
		_shared_frames.set_animation_loop("fly", true)
		for i in range(9):
			var num: String = ("0" + str(i)) if i < 10 else str(i)
			var tex := load("res://Sprites/" + num + "_fireball_fly.png") as Texture2D
			if tex:
				_shared_frames.add_frame("fly", tex)
	return _shared_frames

func _get_glow_texture() -> ImageTexture:
	if not _glow_texture:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := size / 2.0
		for px in range(size):
			for py in range(size):
				var dx := (px - c) / c
				var dy := (py - c) / c
				var dist := sqrt(dx * dx + dy * dy)
				if dist > 1.0:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
				else:
					var fade := 1.0 - dist
					var r: float = lerp(0.6, 1.0, fade)
					var g: float = lerp(0.2, 0.7, fade)
					var b: float = lerp(0.02, 0.15, fade)
					var a := fade * fade * 0.7
					img.set_pixel(px, py, Color(r, g, b, a))
		_glow_texture = ImageTexture.create_from_image(img)
	return _glow_texture

func _build_visual() -> void:
	var mat := _get_shared_material()

	_sprite = AnimatedSprite2D.new()
	_sprite.material = mat
	_sprite.centered = true
	_sprite.scale = Vector2(0.45, 0.45)
	_sprite.z_index = 1
	_sprite.sprite_frames = _get_shared_frames()
	add_child(_sprite)

	_glow = Sprite2D.new()
	_glow.texture = _get_glow_texture()
	_glow.material = mat
	_glow.centered = true
	_glow.scale = Vector2(6.0, 6.0)
	_glow.z_index = 0
	_glow.modulate = Color(3.0, 2.0, 1.2, 1.0)
	add_child(_glow)

	_trail = BurstParticles2D.new()
	_trail.num_particles = 20
	_trail.lifetime = 0.6
	_trail.lifetime_randomness = 0.3
	_trail.repeat = true
	_trail.free_when_finished = false
	_trail.autostart = false
	_trail.texture = preload("res://addons/BurstParticles2D/orb_small.png")
	_trail.image_scale = 0.30
	_trail.image_scale_randomness = 0.6
	_trail.blend_mode = BurstParticles2D.BlendMode.Add
	_trail.spread_degrees = 360.0
	_trail.distance = 60.0
	_trail.distance_randomness = 0.7
	_trail.start_radius = 25.0
	_trail.center_concentration = 3.0
	_trail.angle_degrees = 360.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.6, 0.1, 0.0))
	gradient.add_point(0.2, Color(1.0, 0.4, 0.05, 0.9))
	gradient.add_point(0.5, Color(0.9, 0.2, 0.02, 0.7))
	gradient.add_point(1.0, Color(0.5, 0.05, 0.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	_trail.gradient = grad_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.8))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	_trail.scale_curve = scale_curve

	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))
	alpha_curve.add_point(Vector2(0.15, 1.0))
	alpha_curve.add_point(Vector2(0.7, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	_trail.alpha_curve = alpha_curve

	add_child(_trail)

func setup(dir: Vector2, spell_data: Spell, player_stats: PlayerStats = null) -> void:
	direction = dir.normalized()
	spell = spell_data
	_damage = spell.get_damage(1.0)
	if player_stats:
		_damage *= player_stats.magic_power
	_damage *= ComboTracker.get_damage_multiplier()
	if player_stats:
		_damage *= spell.roll_crit_mult(player_stats)
	if spell.was_last_crit():
		EventBus.crit_landed.emit(_damage, global_position)
	_impact_radius = spell.explosion_radius * spell.get_area_multiplier()
	_speed = spell.get_speed()
	_visual_mult = sqrt(spell.get_area_multiplier()) if spell.get_area_multiplier() > 1.01 else 1.0

func set_target(target_pos: Vector2, dist: float = 0.0) -> void:
	_target_pos = target_pos
	_start_pos = global_position
	_total_distance = dist if dist > 0.0 else _start_pos.distance_to(target_pos)

func on_spawn() -> void:
	_is_active = true
	_impact_done = false
	_distance_traveled = 0.0
	modulate = Color(2.5, 2.0, 1.5, 1.0)
	visible = true
	if _sprite:
		_sprite.play("fly")
		_sprite.scale = Vector2(0.45, 0.45) * _visual_mult
	if _glow:
		_glow.visible = true
		_glow.scale = Vector2(6.0, 6.0) * _visual_mult
	if _trail:
		_trail.burst()
	rotation = direction.angle()
	set_physics_process(true)

func on_despawn() -> void:
	_is_active = false
	visible = false
	if _trail:
		_trail.kill()
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	var step := _speed * delta
	global_position += direction * step
	_distance_traveled += step
	rotation = direction.angle()

	if _glow:
		var pulse := 1.0 + sin(_distance_traveled * 0.03) * 0.15
		_glow.scale = Vector2(6.0, 6.0) * pulse

	if _trail:
		_trail.global_position = global_position

	if _distance_traveled >= _total_distance and not _impact_done:
		_on_impact()

func _on_impact() -> void:
	_impact_done = true
	_is_active = false

	RunTracker.set_current_spell(spell.spell_id)
	SwarmManager.damage_area(global_position, _impact_radius, _damage)
	EnemyMeshManager.damage_area(global_position, _impact_radius, _damage)
	RunTracker.record_damage(_damage * 5.0)

	var visual_scale: float = _impact_radius / 200.0

	JuiceManager.spawn_fireball_explosion(global_position, _impact_radius)
	BurstEffectPool.spawn("meteor", global_position, Color(1.0, 0.5, 0.1), visual_scale)
	JuiceManager.screen_shake(10.0, 0.18)

	var shockwave := BossShockwave.new()
	get_tree().current_scene.add_child(shockwave)
	shockwave.play(global_position, 0.5, _impact_radius)

	queue_free()
