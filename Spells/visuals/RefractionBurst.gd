class_name RefractionBurst
extends Node2D

var _directions: PackedVector2Array = PackedVector2Array()
var _color: Color = Color(0.3, 0.7, 1.0)
var _age: float = 0.0
var _lifetime: float = 0.35
var _half_width: float = 8.0

static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	top_level = true
	z_index = 4
	material = _get_shared_mat()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func setup(pos: Vector2, dirs: PackedVector2Array, ray_color: Color) -> void:
	global_position = pos
	_directions = dirs
	_color = ray_color
	modulate = Color(2.0, 2.0, 2.0, 1.0)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - clampf(_age / _lifetime, 0.0, 1.0)
	var length := 800.0
	var hw: float = _half_width
	for dir in _directions:
		var end := dir * length
		draw_line(Vector2.ZERO, end, Color(_color.r * 0.5, _color.g * 0.5, _color.b * 0.5, alpha * 0.4), hw * 1.5, true)
		draw_line(Vector2.ZERO, end, Color(_color.r, _color.g, _color.b, alpha * 0.7), hw * 0.7, true)
		draw_line(Vector2.ZERO, end, Color(1.0, 1.0, 1.0, alpha * 0.9), maxf(hw * 0.2, 1.0), true)
