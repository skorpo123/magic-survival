class_name OrbitingBlade
extends Node2D

var _orbit_radius: float = 80.0
var _orbit_speed: float = 3.0
var _angle_offset: float = 0.0
var _damage: float = 10.0
var _damage_interval: float = 0.5
var _damage_timer: float = 0.0
var _center: Node2D = null
var _anim: AnimatedSprite2D = null
var _spell_color: Color = Color(0.3, 0.8, 1.0)
var _spell_id: StringName = &""
var _is_setup: bool = false

static var _blade_frames: SpriteFrames = null
static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.material = _get_shared_mat()
	add_child(_anim)
	z_index = 3

	if _is_setup:
		_setup_visual()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func setup(center: Node2D, radius: float, speed: float, angle_offset: float, damage: float, damage_interval: float, sid: StringName = &"") -> void:
	_center = center
	_orbit_radius = radius
	_orbit_speed = speed
	_angle_offset = angle_offset
	_damage = damage
	_damage_interval = damage_interval
	_damage_timer = 0.0
	_spell_id = sid
	_is_setup = true
	if is_inside_tree():
		_setup_visual()

func set_spell_color(color: Color) -> void:
	_spell_color = color
	if _anim:
		_anim.modulate = color

func update_params(radius: float, speed: float, damage: float, damage_interval: float) -> void:
	_orbit_radius = radius
	_orbit_speed = speed
	_damage = damage
	_damage_interval = damage_interval

func _setup_visual() -> void:
	if not _blade_frames:
		_blade_frames = SpriteFrames.new()
		_blade_frames.add_animation("fly")
		_blade_frames.set_animation_speed("fly", 14.0)
		_blade_frames.set_animation_loop("fly", true)
		var blade_tex: Texture2D = load("res://Sprites/orbiting_arcana.png")
		if blade_tex:
			_blade_frames.add_frame("fly", blade_tex)
	_anim.sprite_frames = _blade_frames
	_anim.play("fly")
	_anim.scale = Vector2(0.5, 0.5)
	_anim.modulate = _spell_color

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not is_instance_valid(_center):
		return
	_angle_offset += _orbit_speed * delta
	var offset := Vector2.RIGHT.rotated(_angle_offset) * _orbit_radius
	global_position = _center.global_position + offset
	rotation = _angle_offset

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		_deal_damage()

func _deal_damage() -> void:
	if _spell_id != &"":
		RunTracker.set_current_spell(_spell_id)
	SwarmManager.damage_area(global_position, 12.0, _damage)
	EnemyMeshManager.damage_area(global_position, 15.0, _damage)
	if _spell_id != &"":
		RunTracker.record_damage(_damage)
