class_name SpiritBolt
extends Node2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 600.0
var _damage: float = 10.0
var _damage_interval: float = 0.05
var _damage_timer: float = 0.0
var _half_width: float = 8.0
var _age: float = 0.0
var _max_age: float = 1.5
var _color_primary: Color = Color(0.85, 0.75, 1.0)
var _color_secondary: Color = Color(0.5, 0.35, 0.8)
var _anim: AnimatedSprite2D = null
var _glow_sprite: Sprite2D = null
var _pulse_phase: float = 0.0
var _piercing: bool = false
var _trail_length: float = 60.0
var _prev_position: Vector2 = Vector2.ZERO
var _on_deactivate_callback: Callable = Callable()
var _visual_mult: float = 1.0

static var _shared_frames: SpriteFrames = null
static var _shared_material: CanvasItemMaterial = null
static var _glow_texture: ImageTexture = null

const SPRITE_SCALE := 0.02

func _ready() -> void:
	top_level = true
	z_index = 3
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_build_visual()

func _build_visual() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.material = _get_material()
	_anim.centered = true
	_anim.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_anim.z_index = 1
	_anim.sprite_frames = _get_frames()
	add_child(_anim)

	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _get_glow_texture()
	_glow_sprite.material = _get_material()
	_glow_sprite.centered = true
	_glow_sprite.scale = Vector2(0.5, 0.5)
	_glow_sprite.z_index = 0
	add_child(_glow_sprite)

func _get_material() -> CanvasItemMaterial:
	if not _shared_material:
		_shared_material = CanvasItemMaterial.new()
		_shared_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_material

func _get_frames() -> SpriteFrames:
	if _shared_frames:
		return _shared_frames
	_shared_frames = SpriteFrames.new()
	_shared_frames.add_animation("fly")
	_shared_frames.set_animation_speed("fly", 20.0)
	_shared_frames.set_animation_loop("fly", true)
	for i in range(8):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		var tex := load("res://Sprites/" + num + "_magic_bolt_fly.png") as Texture2D
		if tex:
			_shared_frames.add_frame("fly", tex)
	return _shared_frames

func _get_glow_texture() -> ImageTexture:
	if _glow_texture:
		return _glow_texture
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
				var g: float = lerp(0.5, 0.9, fade)
				var b := 1.0
				var a := fade * fade * 0.45
				img.set_pixel(px, py, Color(r, g, b, a))
	_glow_texture = ImageTexture.create_from_image(img)
	return _glow_texture

func launch(pos: Vector2, direction: Vector2, damage: float, speed: float, color_primary: Color, color_secondary: Color, piercing: bool = false, area_mult: float = 1.0) -> void:
	global_position = pos
	_prev_position = pos
	_direction = direction.normalized()
	_damage = damage
	_speed = speed
	_color_primary = color_primary
	_color_secondary = color_secondary
	_age = 0.0
	_damage_timer = 0.0
	_pulse_phase = randf() * TAU
	_piercing = piercing
	_visual_mult = sqrt(area_mult) if area_mult > 1.01 else 1.0
	if piercing:
		_max_age = 2.5
		_trail_length = 80.0
	rotation = _direction.angle()
	_anim.play("fly")
	_anim.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * _visual_mult
	_anim.modulate = Color(_color_primary.r * 2.5, _color_primary.g * 2.5, _color_primary.b * 2.5, 1.0)
	_glow_sprite.scale = Vector2(0.5, 0.5) * _visual_mult
	_glow_sprite.modulate = Color(_color_primary.r * 1.5, _color_primary.g * 1.5, _color_primary.b * 1.5, 1.0)
	_glow_sprite.visible = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta
	if _age >= _max_age:
		_deactivate()
		return
	global_position += _direction * _speed * delta
	_pulse_phase += delta * 8.0
	if _glow_sprite:
		var pulse := 1.0 + 0.1 * sin(_pulse_phase)
		_glow_sprite.scale = Vector2(0.5, 0.5) * _visual_mult * pulse
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		if _piercing:
			_damage_timer = 0.1
		SwarmManager.damage_line(_prev_position, global_position, _half_width, _damage)
		EnemyMeshManager.damage_line(_prev_position, global_position, _half_width, _damage)
	_prev_position = global_position
	if _piercing:
		queue_redraw()

func _draw() -> void:
	if not _piercing:
		return
	var trail_start := -_direction * _trail_length
	var trail_end := Vector2.ZERO
	for i in range(8):
		var t := float(i) / 8.0
		var p := trail_start + (trail_end - trail_start) * t
		var a := 0.15 * (1.0 - t)
		draw_circle(p, 3.0 * (1.0 - t * 0.5), Color(_color_primary.r, _color_primary.g, _color_primary.b, a))

func _deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if _anim:
		_anim.stop()
	if _glow_sprite:
		_glow_sprite.visible = false
	if _on_deactivate_callback.is_valid():
		_on_deactivate_callback.call(self)
