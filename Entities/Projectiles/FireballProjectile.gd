class_name FireballProjectile extends Node2D

@export_group("Sprite Sheet")
@export var anim_fps: float = 20.0

@export_group("Visual")
@export var sprite_scale: float = 0.12
@export var glow_radius: float = 35.0

static var _shared_material: CanvasItemMaterial = null
static var _shared_frames: SpriteFrames = null
static var _glow_texture: ImageTexture = null

var direction: Vector2 = Vector2.ZERO
var spell: Spell
var current_pierce: int = 1
var _is_active: bool = false
var _is_split_child: bool = false
var _spawned: bool = false
var _pulse_phase: float = 0.0
var _base_glow_scale: float = 1.4
var _fade_tween: Tween = null
var _hit_check_cd: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO

var _anim: AnimatedSprite2D = null
var _glow_sprite: Sprite2D = null

func _ready() -> void:
	z_index = 2
	var notifier := get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
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
		_shared_frames.set_animation_speed("fly", anim_fps)
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
					var r: float = lerp(0.4, 1.0, fade)
					var g: float = lerp(0.15, 0.7, fade)
					var b: float = lerp(0.02, 0.2, fade)
					var a := fade * fade * 0.55
					img.set_pixel(px, py, Color(r, g, b, a))
		_glow_texture = ImageTexture.create_from_image(img)
	return _glow_texture

func _build_visual() -> void:
	var mat := _get_shared_material()

	_anim = AnimatedSprite2D.new()
	_anim.material = mat
	_anim.centered = true
	_anim.scale = Vector2(sprite_scale, sprite_scale)
	_anim.z_index = 1
	_anim.sprite_frames = _get_shared_frames()
	add_child(_anim)

	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _get_glow_texture()
	_glow_sprite.material = mat
	_glow_sprite.centered = true
	_glow_sprite.scale = Vector2(2.5, 2.5)
	_glow_sprite.z_index = 0
	_glow_sprite.modulate = Color(2.5, 2.0, 1.5, 1.0)
	add_child(_glow_sprite)

func on_spawn() -> void:
	_is_active = true
	_is_split_child = false
	_spawned = true
	_hit_check_cd = 0.0
	_prev_position = Vector2.ZERO
	_base_glow_scale = 2.5
	modulate = Color(2.5, 2.0, 1.5, 1)
	_pulse_phase = randf() * TAU
	visible = true
	if _anim:
		_anim.play("fly")
		_anim.scale = Vector2(sprite_scale, sprite_scale)
	if _glow_sprite:
		_glow_sprite.visible = true
	set_physics_process(true)

func on_despawn() -> void:
	_is_active = false
	_is_split_child = false
	_spawned = false
	direction = Vector2.ZERO
	spell = null
	current_pierce = 0
	modulate = Color(1, 1, 1, 1)
	if _anim:
		_anim.stop()
	if _glow_sprite:
		_glow_sprite.visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	set_physics_process(false)

func setup(dir: Vector2, spell_data: Spell, _player_stats: PlayerStats = null) -> void:
	direction = dir.normalized()
	spell = spell_data
	current_pierce = spell.get_pierce()
	rotation = direction.angle()
	if spell:
		var area_mult := spell.get_area_multiplier()
		if area_mult > 1.01:
			var visual_mult := sqrt(area_mult)
			if _anim:
				_anim.scale = Vector2(sprite_scale, sprite_scale) * visual_mult
			if _glow_sprite:
				_base_glow_scale = 1.4 * visual_mult
				_glow_sprite.scale = Vector2(_base_glow_scale, _base_glow_scale)

func _physics_process(delta: float) -> void:
	if not spell or not _is_active:
		return
	_prev_position = global_position
	var speed := spell.get_speed()
	position += direction * speed * delta
	_pulse_phase += delta * 6.0

	if _glow_sprite:
		var pulse := 1.0 + 0.1 * sin(_pulse_phase)
		_glow_sprite.scale = Vector2(_base_glow_scale, _base_glow_scale) * pulse

	if spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.HOMING:
		_apply_homing(delta)

	_check_line_hit()

func _check_line_hit() -> void:
	if not spell or not _is_active:
		return
	var dmg_mult := 1.0
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var dmg := spell.get_damage(dmg_mult) * ComboTracker.get_damage_multiplier()
	var crit_chance: float = 0.0
	if player and player.stats:
		crit_chance = player.stats.crit_chance
	if randf() < clampf(crit_chance, 0.0, 1.0):
		var crit_mult: float = 2.0
		if player and player.stats:
			crit_mult = player.stats.crit_damage_mult
		dmg *= crit_mult
	RunTracker.set_current_spell(spell.spell_id)
	var result := SwarmManager.damage_line(_prev_position, global_position, 20.0, dmg)
	var killed: int = result[0]
	var hit: int = result[1]
	var result2 := EnemyMeshManager.damage_line(_prev_position, global_position, 22.0, dmg)
	killed += result2[0]
	hit += result2[1]
	if hit > 0:
		RunTracker.record_damage(dmg * killed)
		current_pierce -= hit
		SoundManager.play_sound("hit_enemy")
		if current_pierce > 0:
			JuiceManager.spawn_attack_flash(global_position, spell.color)
			JuiceManager.screen_shake(2.0, 0.04)
		if not _is_split_child and spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.SPLIT:
			_split_on_hit(global_position)
			_explode()
			_deferred_despawn()
		elif current_pierce <= 0:
			_explode()
			_deferred_despawn()

func _apply_homing(delta: float) -> void:
	var closest_pos := _find_closest_enemy_pos()
	if closest_pos == Vector2.ZERO:
		return
	var desired := (closest_pos - global_position).normalized()
	direction = direction.move_toward(desired, spell.active_modification.homing_strength * delta)
	rotation = direction.angle()

func _find_closest_enemy_pos() -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = 550.0
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(global_position, 550.0)
	if swarm_pos != Vector2.ZERO:
		min_dist = global_position.distance_to(swarm_pos)
		best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(global_position, 550.0)
	if mesh_pos != Vector2.ZERO:
		var mesh_dist: float = global_position.distance_to(mesh_pos)
		if mesh_dist < min_dist:
			best_pos = mesh_pos
	return best_pos

func _explode() -> void:
	if not spell:
		return
	var radius := spell.explosion_radius * spell.get_area_multiplier()
	var player := GameManager.get_player()
	var dmg_mult := 1.0
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var area_dmg := spell.get_damage(dmg_mult) * 0.5 * ComboTracker.get_damage_multiplier()

	RunTracker.set_current_spell(spell.spell_id)
	SwarmManager.damage_area(global_position, radius, area_dmg)
	EnemyMeshManager.damage_area(global_position, radius, area_dmg)
	RunTracker.record_damage(area_dmg * 4.0)

	JuiceManager.spawn_fireball_explosion(global_position, radius)
	JuiceManager.screen_shake(5.0, 0.1)

func _chain_to_next(source: Node2D) -> void:
	if not spell or not spell.active_modification:
		return
	var chain_range: float = spell.active_modification.chain_range
	var player := GameManager.get_player()
	var dmg_mult := 1.0
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var chain_dmg := spell.get_damage(dmg_mult) * spell.active_modification.chain_damage_mult
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(source.global_position, chain_range)
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(source.global_position, chain_range)
	var best_pos: Vector2 = Vector2.ZERO
	if swarm_pos != Vector2.ZERO and mesh_pos != Vector2.ZERO:
		if source.global_position.distance_to(swarm_pos) < source.global_position.distance_to(mesh_pos):
			best_pos = swarm_pos
		else:
			best_pos = mesh_pos
	elif swarm_pos != Vector2.ZERO:
		best_pos = swarm_pos
	elif mesh_pos != Vector2.ZERO:
		best_pos = mesh_pos
	if best_pos != Vector2.ZERO:
		RunTracker.set_current_spell(spell.spell_id)
		SwarmManager.damage_area(best_pos, 30.0, chain_dmg)
		EnemyMeshManager.damage_area(best_pos, 30.0, chain_dmg)
		RunTracker.record_damage(chain_dmg)

func _split_on_hit(hit_pos: Vector2) -> void:
	if not spell or not spell.active_modification:
		return
	var split_count := spell.active_modification.split_count
	var spread := spell.active_modification.split_angle_spread
	var player := GameManager.get_player()
	var player_stats: PlayerStats = null
	if player and "stats" in player and player.stats is PlayerStats:
		player_stats = player.stats
	var base_angle := direction.angle()
	for i in range(split_count):
		var angle: float
		if split_count > 1:
			angle = base_angle - spread / 2.0 + spread * (float(i) / float(split_count - 1))
		else:
			angle = base_angle
		var dir := Vector2.RIGHT.rotated(angle)
		var proj := PoolManager.spawn(spell.pool_name, hit_pos)
		if proj:
			if proj.has_method("setup"):
				proj.setup(dir, spell, player_stats)
			if proj.has_method("on_spawn"):
				proj.on_spawn()
			if "_is_split_child" in proj:
				proj._is_split_child = true
			if "current_pierce" in proj:
				proj.current_pierce = 1
			if "_anim" in proj and proj._anim:
				proj._anim.scale = Vector2(sprite_scale * 0.6, sprite_scale * 0.6)
			if "_glow_sprite" in proj and proj._glow_sprite:
				proj._glow_sprite.scale = Vector2(1.4 * 0.6, 1.4 * 0.6)

func _deferred_despawn() -> void:
	_is_active = false
	_spawned = false
	if _anim:
		_anim.stop()
	if _glow_sprite:
		_glow_sprite.visible = false
	var pool_name := spell.pool_name
	(func() -> void:
		PoolManager.despawn(pool_name, self)
	).call_deferred()

func _on_screen_exited() -> void:
	if not _is_active:
		return
	_start_fade()

func _start_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(func() -> void:
		if spell:
			PoolManager.despawn(spell.pool_name, self)
	)

func _get_spell_type(s: Spell) -> StringName:
	if not s:
		return &""
	match s.spell_id:
		&"magic_bolt": return &"arcane"
		&"fireball": return &"fire"
		&"fire_breath": return &"fire"
		&"lightning_strike": return &"lightning"
		&"electric_zone": return &"lightning"
		&"cyclone": return &"arcane"
		&"arcane_ray": return &"arcane"
		&"orbiting_arcana": return &"arcane"
		&"spirit": return &"arcane"
		&"shield": return &"arcane"
		&"needle": return &"cold"
		&"poison_pool": return &"cold"
		_: return &""
