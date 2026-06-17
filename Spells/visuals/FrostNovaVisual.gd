class_name FrostNovaVisual
extends Node2D

var _pos: Vector2 = Vector2.ZERO
var _max_radius: float = 140.0
var _color: Color = Color(0.6, 0.85, 1.0)
var _time: float = 0.0
var _expansion_time: float = 0.35
var _lifetime: float = 1.0

func setup(pos: Vector2, radius: float, color: Color, expansion_time: float) -> void:
	_pos = pos
	_max_radius = radius
	_color = color
	_expansion_time = expansion_time
	_lifetime = expansion_time + 0.6
	global_position = _pos
	_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _time >= _lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _time / _expansion_time
	var expand := minf(t, 1.0)
	var r := _max_radius * expand

	var fade := 1.0
	if _time > _expansion_time:
		fade = 1.0 - (_time - _expansion_time) / 0.6

	var alpha := fade * 0.85

	var segments := 48

	var ring_width := 3.0 + (1.0 - expand) * 4.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, segments, Color(_color.r * 1.4, _color.g * 1.4, _color.b * 1.5, alpha), ring_width, true)

	var inner_r := r * 0.85
	draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, segments, Color(_color.r * 0.6, _color.g * 0.7, _color.b * 0.9, alpha * 0.3), 1.5, true)

	var crystal_count := 12
	for i in range(crystal_count):
		var a := TAU / crystal_count * i + _time * 2.0
		var crystal_len := r * 0.25 * (0.6 + 0.4 * sin(_time * 4.0 + i * 1.5))
		var base_pos := Vector2(cos(a), sin(a)) * (r * 0.85)
		var tip_pos := Vector2(cos(a), sin(a)) * (r * 0.85 + crystal_len)
		draw_line(base_pos, tip_pos, Color(_color.r * 1.3, _color.g * 1.3, _color.b * 1.4, alpha * 0.7), 2.5, true)
		draw_circle(tip_pos, 2.0, Color(1.0, 1.0, 1.0, alpha * 0.5))

	var fill_r := r * 0.95
	draw_circle(Vector2.ZERO, fill_r, Color(_color.r * 0.15, _color.g * 0.2, _color.b * 0.3, alpha * 0.08))
