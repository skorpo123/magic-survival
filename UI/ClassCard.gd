class_name ClassCard
extends Control

signal card_clicked()

const CARD_W := 300.0
const CARD_H := 250.0
const CORNER_R := 10.0

var _class_data: Dictionary
var _is_locked: bool = false
var _is_selected: bool = false
var _index: int = 0
var _hover_t: float = 0.0
var _hover_target: float = 0.0
var _flash_t: float = 0.0
var _is_exiting := false
var _entrance_done := false
var _select_pulse: float = 0.0

var _icon_color: Color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(CARD_W, CARD_H)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void: _hover_target = 0.0)

func _gui_input(event: InputEvent) -> void:
	if _is_exiting or _is_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_flash_t = 1.0
		card_clicked.emit()

func setup(class_data: Dictionary, index: int) -> void:
	_class_data = class_data
	_index = index
	_icon_color = class_data.get("icon_color", Color(0.85, 0.75, 0.55))
	_is_locked = not CharacterManager.is_unlocked(class_data.id)

func play_entrance(delay: float) -> void:
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	t.chain()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: _entrance_done = true)

func play_exit(is_selected: bool) -> void:
	_is_exiting = true
	_is_selected = is_selected
	if is_selected:
		_flash_t = 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1).set_ease(Tween.EASE_OUT)
		t.set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2).set_ease(Tween.EASE_IN)
	else:
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(0.9, 0.9), 0.15).set_ease(Tween.EASE_IN)

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_select_pulse = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_hover_t = lerpf(_hover_t, _hover_target, delta * 14.0)
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 5.0, 0.0)
	if _is_selected:
		_select_pulse += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var accent := _icon_color if not _is_locked else Color(0.3, 0.3, 0.35)
	var h := _hover_t

	if _is_selected:
		var pa := 0.5 + sin(_select_pulse) * 0.15
		_draw_rounded_rect(Rect2(-3, -3, CARD_W + 6, CARD_H + 6), CORNER_R + 3, Color(accent.r, accent.g, accent.b, pa))

	_draw_card_bg(accent, h)
	_draw_icon(accent, h)
	_draw_separator(accent, h)
	_draw_labels(accent)

	if h > 0.01:
		_draw_hover_highlight(h)

	_draw_flash()

	if _is_locked:
		_draw_lock_overlay()

func _draw_card_bg(accent: Color, h: float) -> void:
	var darkening := h * 0.015
	var bg := Color(0.055 - darkening, 0.042 - darkening, 0.085 - darkening, 0.96)
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, bg)

	var border_alpha := 0.35 + h * 0.2
	_draw_rounded_rect_border(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, border_alpha))

func _draw_icon(accent: Color, h: float) -> void:
	var cx := CARD_W * 0.5
	var cy := 60.0
	var sz := 30.0
	var icon_alpha := 0.9
	if _is_locked:
		icon_alpha = 0.3

	var glow_a := (0.15 + h * 0.15) * icon_alpha
	draw_circle(Vector2(cx, cy), sz + 6.0, Color(accent.r, accent.g, accent.b, glow_a * 0.3))

	var col := Color(accent.r, accent.g, accent.b, icon_alpha)
	draw_arc(Vector2(cx, cy), sz, 0, TAU, 24, col, 2.0, true)
	draw_arc(Vector2(cx, cy), sz * 0.55, 0, TAU, 16, Color(accent.r, accent.g, accent.b, icon_alpha * 0.4), 1.0, true)

	var inner_sz := sz * 0.32
	var corners := PackedVector2Array([
		Vector2(cx, cy - inner_sz),
		Vector2(cx + inner_sz, cy),
		Vector2(cx, cy + inner_sz),
		Vector2(cx - inner_sz, cy),
	])
	if _class_data.has("id"):
		match _class_data.id:
			&"pyromancer":
				corners = PackedVector2Array([
					Vector2(cx, cy - sz * 0.45),
					Vector2(cx + sz * 0.35, cy + sz * 0.2),
					Vector2(cx - sz * 0.35, cy + sz * 0.2),
				])
			&"stormcaller", &"electromant":
				corners = PackedVector2Array([
					Vector2(cx, cy - sz * 0.5),
					Vector2(cx + sz * 0.4, cy + sz * 0.15),
					Vector2(cx, cy + sz * 0.35),
					Vector2(cx - sz * 0.4, cy + sz * 0.15),
				])
	if corners.size() >= 3:
		draw_colored_polygon(corners, Color(accent.r, accent.g, accent.b, icon_alpha * 0.35))
		draw_polyline(corners, col, 1.5, true)

func _draw_separator(accent: Color, h: float) -> void:
	var y := 100.0
	var w := 65.0 + h * 14.0
	var x := (CARD_W - w) * 0.5
	var a := 0.18 + h * 0.12
	draw_line(Vector2(x, y), Vector2(x + w, y), Color(accent.r, accent.g, accent.b, a), 1.0, true)

func _draw_labels(accent: Color) -> void:
	if _is_locked:
		_draw_centered_text("???", 135.0, 15, Color(0.4, 0.38, 0.45))
		_draw_lock_icon(CARD_W * 0.5, 185.0)
		return

	var name_text := SettingsManager.t(_class_data.name_key) if _class_data.has("name_key") else "?"
	_draw_centered_text(name_text, 128.0, 16, Color(0.95, 0.93, 0.88))

	var desc_text := SettingsManager.t(_class_data.desc_key) if _class_data.has("desc_key") else ""
	if desc_text.length() > 42:
		desc_text = desc_text.substr(0, 39) + "..."
	_draw_centered_text(desc_text, 156.0, 11, Color(0.55, 0.52, 0.6, 0.8))

	var spell_text := SettingsManager.t(&"spell_" + String(_class_data.spell_id)) if _class_data.has("spell_id") else ""
	_draw_centered_text(spell_text, 183.0, 11, Color(accent.r * 0.6 + 0.4, accent.g * 0.6 + 0.4, accent.b * 0.6 + 0.4, 0.55))

func _draw_centered_text(text: String, y: float, font_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, CARD_W, font_size, color)

func _draw_lock_icon(cx: float, cy: float) -> void:
	var col := Color(0.45, 0.42, 0.5, 0.6)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(cx - 8, cy + 6), "\U0001F512", HORIZONTAL_ALIGNMENT_CENTER, 16, 18, col)

func _draw_hover_highlight(h: float) -> void:
	var a := h * 0.06
	_draw_rounded_rect(Rect2(2, 2, CARD_W - 4, CARD_H - 4), CORNER_R - 1, Color(1, 1, 1, a))

func _draw_flash() -> void:
	if _flash_t < 0.01:
		return
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, Color(1, 1, 1, _flash_t * 0.4))

func _draw_lock_overlay() -> void:
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, Color(0, 0, 0, 0.5))

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r < 1.0:
		draw_rect(rect, color)
		return
	var p := rect.position
	var s := rect.size
	draw_circle(p + Vector2(r, r), r, color)
	draw_circle(p + Vector2(s.x - r, r), r, color)
	draw_circle(p + Vector2(r, s.y - r), r, color)
	draw_circle(p + Vector2(s.x - r, s.y - r), r, color)
	draw_rect(Rect2(p.x + r, p.y, s.x - 2.0 * r, s.y), color)
	draw_rect(Rect2(p.x, p.y + r, s.x, s.y - 2.0 * r), color)

func _draw_rounded_rect_border(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var s := rect.size
	var pts := PackedVector2Array()
	var segments := 12
	for i in range(4):
		var center: Vector2
		match i:
			0: center = p + Vector2(r, r)
			1: center = p + Vector2(s.x - r, r)
			2: center = p + Vector2(s.x - r, s.y - r)
			3: center = p + Vector2(r, s.y - r)
		var base_angle: float = i * PI * 0.5
		for j in range(segments + 1):
			var angle := base_angle + (PI * 0.5) * j / segments
			pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_polyline(pts, color, 1.0, true)
