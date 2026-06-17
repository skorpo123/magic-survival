class_name LightningImpact
extends Node2D

var _age: float = 0.0
var _lifetime: float = 0.35
var _active: bool = false
var _flash_radius: float = 30.0
var _sparks: Array[Vector2] = []
var _spark_angles: PackedFloat32Array = PackedFloat32Array()
var _spark_lengths: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	top_level = true
	z_index = 3
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func activate(pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	global_position = pos
	_age = 0.0
	_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_flash_radius = 30.0 * scale_mult
	_sparks.clear()
	_spark_angles = PackedFloat32Array()
	_spark_lengths = PackedFloat32Array()
	var spark_count: int = randi_range(6, 10)
	for i in range(spark_count):
		var angle: float = (TAU / float(spark_count)) * float(i) + randf_range(-0.3, 0.3)
		_spark_angles.append(angle)
		_spark_lengths.append(randf_range(15.0, 45.0) * scale_mult)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		_active = false
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	queue_redraw()

func _draw() -> void:
	var alpha := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	var progress := _age / _lifetime

	var flash_alpha := alpha * 0.9
	var current_radius := _flash_radius * (0.5 + progress * 1.5)
	var flash_color := Color(0.8, 0.9, 1.0, flash_alpha)
	draw_circle(Vector2.ZERO, current_radius, flash_color)

	var core_alpha := alpha * 0.6
	var core_radius := current_radius * 0.4
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 1.0, 1.0, core_alpha))

	for i in range(_spark_angles.size()):
		var angle: float = _spark_angles[i]
		var max_len: float = _spark_lengths[i]
		var len: float = max_len * clampf(1.0 - progress * 1.5, 0.0, 1.0)
		if len < 1.0:
			continue
		var dir := Vector2(cos(angle), sin(angle))
		var start := dir * current_radius * 0.3
		var end_pos := dir * (current_radius * 0.3 + len)
		var spark_alpha := alpha * 0.8
		draw_line(start, end_pos, Color(0.6, 0.85, 1.0, spark_alpha), 2.0, true)
		draw_circle(end_pos, 2.0, Color(1.0, 1.0, 1.0, spark_alpha * 0.7))
