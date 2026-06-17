class_name ChestIndicator extends Control

var _target_chest: Node2D = null
var _dist_label: Label = null
var _pulse_phase: float = 0.0
var _arrow_dir: Vector2 = Vector2.UP

const EDGE_MARGIN := 60.0

func setup(chest: Node2D) -> void:
	_target_chest = chest
	var rarity: int = chest.rarity if "rarity" in chest else ItemRarity.Tier.COMMON
	var col: Color = ItemRarity.COLORS.get(rarity, Color.GRAY)

	_dist_label = Label.new()
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dist_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	_dist_label.add_theme_color_override("font_color", col)
	_dist_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_dist_label.add_theme_constant_override("outline_size", 2)
	_dist_label.position = Vector2(-20, 18)
	_dist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dist_label)

func _process(delta: float) -> void:
	if not is_instance_valid(_target_chest):
		queue_free()
		return

	_pulse_phase += delta * 3.0
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var viewport_size := get_viewport_rect().size
	var half := viewport_size * 0.5
	var to_chest := _target_chest.global_position - cam.get_screen_center_position()
	var dist := to_chest.length()

	if _dist_label:
		_dist_label.text = "%dm" % int(dist / 32.0)

	var dir := to_chest.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_arrow_dir = dir

	var clamped := _clamp_to_edge(half, dir, half - Vector2.ONE * EDGE_MARGIN)
	position = clamped

	var chest_screen := _target_chest.global_position - cam.get_screen_center_position() + half
	var on_screen := Rect2(Vector2.ZERO, viewport_size).grow(-EDGE_MARGIN * 2.0).has_point(chest_screen)
	visible = not on_screen

	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var rarity: int = _target_chest.rarity if is_instance_valid(_target_chest) and "rarity" in _target_chest else ItemRarity.Tier.COMMON
	var col: Color = ItemRarity.COLORS.get(rarity, Color.GRAY)
	var pulse := 0.7 + 0.3 * sin(_pulse_phase)
	var draw_col := Color(col.r * pulse, col.g * pulse, col.b * pulse, 0.9)

	var angle := _arrow_dir.angle() + PI * 0.5
	var tip := Vector2(0, -12)
	var left := Vector2(-7, 5)
	var right := Vector2(7, 5)
	var pts := PackedVector2Array([tip, left, right])
	var transformed := PackedVector2Array()
	for pt in pts:
		transformed.append(pt.rotated(angle))
	draw_colored_polygon(transformed, draw_col)

func _clamp_to_edge(center: Vector2, dir: Vector2, half: Vector2) -> Vector2:
	var t_vals: Array[float] = []
	if dir.x != 0.0:
		t_vals.append(half.x / absf(dir.x))
	if dir.y != 0.0:
		t_vals.append(half.y / absf(dir.y))
	if t_vals.is_empty():
		return center
	var t: float = t_vals.min()
	return center + dir * t
