class_name DamageZone
extends Node2D

var _damage: float = 10.0
var _damage_interval: float = 0.5
var _damage_timer: float = 0.0
var _center: Node2D = null
var _radius: float = 80.0
var _zone_color: Color = Color(0.5, 0.3, 0.8)
var _spell_id: StringName = &""
var _pulse_tween: Tween = null
var _circle: Sprite2D = null

static var _shared_mat: CanvasItemMaterial = null
static var _shared_texture: ImageTexture = null

func _ready() -> void:
	z_index = 2
	material = _get_shared_mat()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_mat

func setup(center: Node2D, radius: float, damage: float, damage_interval: float, color: Color = Color(0.5, 0.3, 0.8), sid: StringName = &"") -> void:
	_center = center
	_radius = radius
	_damage = damage
	_damage_interval = damage_interval
	_damage_timer = 0.0
	_zone_color = color
	_spell_id = sid
	_ensure_circle()

func update_params(radius: float, damage: float, damage_interval: float) -> void:
	_radius = radius
	_damage = damage
	_damage_interval = damage_interval
	if _circle:
		_circle.scale = Vector2.ONE * _radius / 32.0

func _ensure_circle() -> void:
	if _circle:
		return
	if not _shared_texture:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := size / 2.0
		for px in range(size):
			for py in range(size):
				var dx := (px - c) / c
				var dy := (py - c) / c
				var dist := sqrt(dx * dx + dy * dy)
				if dist <= 1.0:
					var fade := 1.0 - dist
					var a := fade * fade * 0.25
					img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
				else:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
		_shared_texture = ImageTexture.create_from_image(img)
	_circle = Sprite2D.new()
	_circle.texture = _shared_texture
	_circle.centered = true
	_circle.scale = Vector2.ONE * _radius / 32.0
	_circle.z_index = 0
	_circle.material = _get_shared_mat()
	_circle.modulate = _zone_color
	add_child(_circle)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not is_instance_valid(_center):
		return
	global_position = _center.global_position

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		_deal_damage()
		_start_pulse()

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	if not _circle:
		return
	_circle.modulate.a = 2.0
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_circle, "modulate:a", 1.0, _damage_interval * 0.5).set_ease(Tween.EASE_OUT)

func _deal_damage() -> void:
	var dmg := _damage * ComboTracker.get_damage_multiplier()
	RunTracker.set_current_spell(_spell_id)
	SwarmManager.damage_area(global_position, _radius, dmg)
	EnemyMeshManager.damage_area(global_position, _radius, dmg)
	RunTracker.record_damage(dmg * 2.0)
