class_name SpiritOrb
extends Node2D

signal orb_fire_done()

var _hover_offset: Vector2 = Vector2.ZERO
var _target_offset: Vector2 = Vector2.ZERO
var _color_primary: Color = Color(0.85, 0.75, 1.0)
var _color_secondary: Color = Color(0.5, 0.35, 0.8)
var _pulse_phase: float = 0.0
var _flash_t: float = 0.0
var _is_active: bool = false
var _sprite: Sprite2D = null
var _glow_sprite: Sprite2D = null
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _is_haunt: bool = false
var _haunting: bool = false
var _haunt_target: Vector2 = Vector2.ZERO
var _haunt_speed: float = 500.0
var _haunt_dmg: float = 0.0
var _haunt_aoe_radius: float = 60.0
var _haunt_recovering: bool = false
var _haunt_recovery_timer: float = 0.0

const ANIM_FPS := 8.0
const FRAME_COUNT := 6
const ORB_SCALE := 0.23
const GLOW_SCALE := 0.35

static var _frames: Array[Texture2D] = []
static var _shared_mat: CanvasItemMaterial = null
static var _glow_texture: ImageTexture = null

func _ready() -> void:
	z_index = 3
	visible = false
	_ensure_frames()
	_ensure_glow()
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE)
	_sprite.z_index = 2
	_sprite.material = _get_shared_mat()
	add_child(_sprite)
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _glow_texture
	_glow_sprite.centered = true
	_glow_sprite.scale = Vector2(GLOW_SCALE, GLOW_SCALE)
	_glow_sprite.z_index = 1
	_glow_sprite.material = _get_shared_mat()
	add_child(_glow_sprite)

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func _ensure_glow() -> void:
	if _glow_texture:
		return
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
				var r: float = lerp(0.5, 1.0, fade)
				var g: float = lerp(0.4, 0.9, fade)
				var b := 1.0
				var a := fade * fade * 0.5
				img.set_pixel(px, py, Color(r, g, b, a))
	_glow_texture = ImageTexture.create_from_image(img)

func _ensure_frames() -> void:
	if _frames.size() > 0:
		return
	for i in range(FRAME_COUNT):
		var path := "res://Sprites/0" + str(i) + "_spirit_pix.png"
		var tex := load(path) as Texture2D
		if tex:
			_frames.append(tex)

func setup(offset: Vector2, color_primary: Color, color_secondary: Color, is_haunt: bool = false) -> void:
	_hover_offset = offset
	_target_offset = offset
	_color_primary = color_primary
	_color_secondary = color_secondary
	_is_haunt = is_haunt
	_is_active = true
	visible = true
	_pulse_phase = randf() * TAU
	_anim_timer = 0.0
	_anim_frame = randi() % FRAME_COUNT

func update_offset(new_offset: Vector2) -> void:
	_target_offset = new_offset

func fire(_target_pos: Vector2) -> void:
	_flash_t = 1.0

func start_haunt(target_pos: Vector2, damage: float) -> void:
	_haunting = true
	_haunt_target = target_pos
	_haunt_dmg = damage
	_flash_t = 1.5

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _is_active:
		return
	if _haunting:
		_process_haunt(delta)
		return
	if _haunt_recovering:
		_process_recovery(delta)
		return
	var player := GameManager.get_player()
	if not player:
		return
	_hover_offset = _hover_offset.move_toward(_target_offset, delta * 8.0)
	global_position = player.global_position + _hover_offset
	_pulse_phase += delta * (8.0 if _is_haunt else 4.0)
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * (10.0 if _is_haunt else 6.0), 0.0)
	_anim_timer += delta
	if _anim_timer >= 1.0 / ANIM_FPS:
		_anim_timer -= 1.0 / ANIM_FPS
		_anim_frame = (_anim_frame + 1) % FRAME_COUNT
		if _frames.size() > _anim_frame:
			_sprite.texture = _frames[_anim_frame]
	var flash_mult := 1.0 + _flash_t * (4.0 if _is_haunt else 2.0)
	var haunt_flicker := 1.0
	if _is_haunt:
		haunt_flicker = 0.7 + 0.3 * absf(sin(_pulse_phase * 1.7))
		_sprite.modulate = Color(_color_primary.r * flash_mult * haunt_flicker * 2.0, _color_primary.g * flash_mult * haunt_flicker * 2.0, _color_primary.b * flash_mult * haunt_flicker * 2.0, 0.95)
	_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE) * (1.0 + sin(_pulse_phase) * 0.08)
	if _glow_sprite:
		var glow_pulse := 1.0 + sin(_pulse_phase) * 0.15
		_glow_sprite.scale = Vector2(GLOW_SCALE, GLOW_SCALE) * glow_pulse * flash_mult
		_glow_sprite.visible = true

func _process_haunt(delta: float) -> void:
	var to_target := _haunt_target - global_position
	var dist := to_target.length()
	if dist < 20.0:
		SwarmManager.damage_area(global_position, _haunt_aoe_radius, _haunt_dmg)
		EnemyMeshManager.damage_area(global_position, _haunt_aoe_radius, _haunt_dmg)
		JuiceManager.spawn_attack_flash(global_position, _color_primary)
		_haunting = false
		_haunt_recovering = true
		_haunt_recovery_timer = 2.0
		_flash_t = 0.0
		return
	var dir := to_target.normalized()
	global_position += dir * _haunt_speed * delta
	_pulse_phase += delta * 12.0
	_flash_t = maxf(_flash_t - delta * 4.0, 0.5)
	_anim_timer += delta
	if _anim_timer >= 1.0 / ANIM_FPS:
		_anim_timer -= 1.0 / ANIM_FPS
		_anim_frame = (_anim_frame + 1) % FRAME_COUNT
		if _frames.size() > _anim_frame:
			_sprite.texture = _frames[_anim_frame]
	var flash_mult := 1.0 + _flash_t * 3.0
	_sprite.modulate = Color(_color_primary.r * flash_mult * 2.0, _color_primary.g * flash_mult * 2.0, _color_primary.b * flash_mult * 2.0, 0.95)
	_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE) * (1.0 + sin(_pulse_phase) * 0.12)
	if _glow_sprite:
		_glow_sprite.scale = Vector2(GLOW_SCALE * 1.5, GLOW_SCALE * 1.5) * (1.0 + sin(_pulse_phase) * 0.2) * flash_mult
		_glow_sprite.visible = true

func _process_recovery(delta: float) -> void:
	_haunt_recovery_timer -= delta
	var player := GameManager.get_player()
	if not player:
		return
	var target_pos := player.global_position + _hover_offset
	var to_target := target_pos - global_position
	var dist := to_target.length()
	if dist < 5.0 or _haunt_recovery_timer <= 0.0:
		_haunt_recovering = false
		global_position = target_pos
		return
	var move_speed := 200.0 * (1.0 - _haunt_recovery_timer / 2.0)
	global_position += to_target.normalized() * maxf(move_speed, 80.0) * delta
	_pulse_phase += delta * 4.0
	_anim_timer += delta
	if _anim_timer >= 1.0 / ANIM_FPS:
		_anim_timer -= 1.0 / ANIM_FPS
		_anim_frame = (_anim_frame + 1) % FRAME_COUNT
		if _frames.size() > _anim_frame:
			_sprite.texture = _frames[_anim_frame]
	_sprite.modulate = Color(_color_primary.r * 1.4, _color_primary.g * 1.4, _color_primary.b * 1.4, 0.8)
	_sprite.scale = Vector2(ORB_SCALE, ORB_SCALE) * (1.0 + sin(_pulse_phase) * 0.05)
	if _glow_sprite:
		_glow_sprite.scale = Vector2(GLOW_SCALE, GLOW_SCALE)
		_glow_sprite.visible = true
