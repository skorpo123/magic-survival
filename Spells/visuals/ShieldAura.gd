class_name ShieldAura
extends Node2D

const SHIELD_RADIUS := 70.0
const DOME_SEGMENTS := 64
const SPIKE_COUNT := 8

var _player: Node2D = null

# State
var _charges: int = 0
var _max_charges: int = 2
var _primary_color := Color(0.3, 0.7, 1.0)
var _secondary_color := Color(0.2, 0.4, 0.8)
var _is_aegis := false
var _has_thorns := false

# Hit flash
var _hit_flash_time: float = -1.0
var _hit_flash_pos := Vector2.ZERO
const HIT_FLASH_DURATION := 0.35
const HIT_FLASH_RADIUS := 80.0

# Spike animation
var _spike_phase: float = 0.0

# Dome visual params (set by state)
var _dome_color := Color(0.3, 0.7, 1.0)
var _alpha_base := 0.10
var _alpha_edge := 0.40

const CHARGE_COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.1),   # 1 charge — red
	Color(0.2, 0.6, 1.0),    # 2 charges — blue
	Color(0.3, 0.9, 0.4),    # 3 charges — green
	Color(0.95, 0.85, 0.2),  # 4 charges — yellow
	Color(0.9, 0.4, 0.95),   # 5 charges — magenta
	Color(0.2, 0.9, 0.9),    # 6 charges — cyan
	Color(1.0, 0.6, 0.1),    # 7 charges — orange
	Color(0.6, 0.3, 1.0),    # 8 charges — purple
]

func setup(player_node: Node2D) -> void:
	_player = player_node

func set_colors(primary: Color, secondary: Color) -> void:
	_primary_color = primary
	_secondary_color = secondary
	_apply_state_visual()

func set_thorns(active: bool) -> void:
	_has_thorns = active
	queue_redraw()

func set_aegis(active: bool) -> void:
	_is_aegis = active
	_apply_state_visual()

func set_charges(charges: int, max_charges: int) -> void:
	_charges = charges
	_max_charges = max_charges
	_apply_state_visual()

func _apply_state_visual() -> void:
	if _is_aegis:
		_dome_color = Color(1.0, 0.85, 0.3)
		_alpha_base = 0.14
		_alpha_edge = 0.50
	elif _charges <= 0:
		_dome_color = Color(0.25, 0.25, 0.25)
		_alpha_base = 0.04
		_alpha_edge = 0.10
	else:
		var idx: int = clampi(_charges - 1, 0, CHARGE_COLORS.size() - 1)
		_dome_color = CHARGE_COLORS[idx]
		_alpha_base = 0.10
		_alpha_edge = 0.40
	queue_redraw()

func on_charge_used(damage_pos: Vector2) -> void:
	_hit_flash_time = 0.0
	_hit_flash_pos = damage_pos - global_position

func on_charge_recovered() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	global_position = _player.global_position

	if _hit_flash_time >= 0.0:
		_hit_flash_time += delta
		queue_redraw()
		if _hit_flash_time >= HIT_FLASH_DURATION:
			_hit_flash_time = -1.0

	if _has_thorns and _charges > 0:
		_spike_phase += delta * 0.3
		queue_redraw()

func _draw() -> void:
	_draw_dome()
	if _has_thorns and _charges > 0:
		_draw_spikes()
	if _hit_flash_time >= 0.0:
		_draw_hit_flash()

func _draw_dome() -> void:
	if _charges <= 0 and not _is_aegis:
		return

	# Smooth gradient: many thin rings, alpha rises toward edge
	var ring_count := 24
	for i in range(ring_count):
		var t := float(i) / float(ring_count)
		var r := t * SHIELD_RADIUS
		var ring_w := SHIELD_RADIUS / float(ring_count) + 1.0

		# Smooth curve: near-zero at center, rises toward edge
		var a := _alpha_base + (_alpha_edge - _alpha_base) * pow(t, 1.8)
		a = clampf(a, 0.0, 0.55)

		var col := Color(_dome_color.r, _dome_color.g, _dome_color.b, a)
		var pts := PackedVector2Array()
		for j in range(DOME_SEGMENTS + 1):
			var angle := TAU * float(j) / float(DOME_SEGMENTS)
			pts.append(Vector2(cos(angle), sin(angle)) * r)
		draw_polyline(pts, col, ring_w)

	# Bright edge ring
	var edge_col := Color(_dome_color.r, _dome_color.g, _dome_color.b, _alpha_edge * 0.8)
	var edge_pts := PackedVector2Array()
	for i in range(DOME_SEGMENTS + 1):
		var angle := TAU * float(i) / float(DOME_SEGMENTS)
		edge_pts.append(Vector2(cos(angle), sin(angle)) * SHIELD_RADIUS)
	draw_polyline(edge_pts, edge_col, 2.0)

func _draw_hit_flash() -> void:
	var progress := _hit_flash_time / HIT_FLASH_DURATION
	var current_radius := progress * HIT_FLASH_RADIUS
	var fade := 1.0 - progress

	var flash_col := Color(_dome_color.r, _dome_color.g, _dome_color.b, fade * 0.6)
	var ring_points := PackedVector2Array()
	for i in range(DOME_SEGMENTS + 1):
		var angle := TAU * float(i) / float(DOME_SEGMENTS)
		ring_points.append(_hit_flash_pos + Vector2(cos(angle), sin(angle)) * current_radius)
	draw_polyline(ring_points, flash_col, 2.0)

func _draw_spikes() -> void:
	var base_len := 10.0
	var base_w := 3.5
	var col := _dome_color

	for i in range(SPIKE_COUNT):
		var angle := (TAU / SPIKE_COUNT) * i + _spike_phase
		var tip_len := base_len + sin(_spike_phase * 2.0 + i * 1.3) * 3.0
		var center := Vector2(cos(angle), sin(angle)) * SHIELD_RADIUS
		var tip := center + Vector2(cos(angle), sin(angle)) * tip_len
		var perp := Vector2(-sin(angle), cos(angle))
		var left := center + perp * base_w * 0.5
		var right := center - perp * base_w * 0.5
		var pts := PackedVector2Array([left, tip, right])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.7))
