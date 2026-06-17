class_name SpellCard
extends Control

signal card_clicked()

const CARD_W := 660.0
const CARD_H := 120.0
const CORNER_R := 16.0
const ICON_SIZE := 80.0
const PAD := 20.0

var _data: LevelUpCard
var _index: int
var _hover_t: float = 0.0
var _hover_target: float = 0.0
var _flash_t: float = 0.0
var _is_exiting := false
var _is_selected := false
var _entrance_done := false

var _level_label: Label
var _title_label: Label
var _desc_label: Label
var _mod_label: Label
var _icon_container: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	size = Vector2(CARD_W, CARD_H)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	clip_contents = true
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void: _hover_target = 0.0)
	_build_ui()

func setup(data: LevelUpCard, index: int) -> void:
	_data = data
	_index = index

	_title_label.text = data.title
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	_level_label.text = _get_level_text()
	var accent := data.rarity_color
	_level_label.add_theme_color_override("font_color", accent)

	_desc_label.text = data.description
	_desc_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.8))

	if data.card_type == LevelUpCard.CardType.SPELL_UPGRADE and data.new_level >= 5:
		_mod_label.visible = true
		_mod_label.text = SettingsManager.t(&"lu_learn_mod")
		_mod_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.95))
	else:
		_mod_label.visible = false

	_setup_icon()

func _build_ui() -> void:
	_icon_container = Control.new()
	_icon_container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_container.position = Vector2(PAD, (CARD_H - ICON_SIZE) * 0.5)
	_icon_container.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_container)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_title_label.position = Vector2(PAD + ICON_SIZE + 14.0, 12.0)
	_title_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 130.0, 28.0)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_level_label.position = Vector2(CARD_W - PAD - 120.0, 14.0)
	_level_label.size = Vector2(120.0, 24.0)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_desc_label.position = Vector2(PAD + ICON_SIZE + 14.0, 44.0)
	_desc_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 20.0, 36.0)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)

	_mod_label = Label.new()
	_mod_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	_mod_label.position = Vector2(PAD + ICON_SIZE + 14.0, 80.0)
	_mod_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 20.0, 22.0)
	_mod_label.visible = false
	_mod_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mod_label)

func _setup_icon() -> void:
	for c in _icon_container.get_children():
		c.queue_free()

	var icon_tex: Texture2D = null
	if _data and _data.icon:
		icon_tex = _data.icon

	if icon_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var accent := _data.rarity_color
		tex_rect.modulate = Color(
			minf(accent.r * 0.4 + 0.6, 1.0),
			minf(accent.g * 0.4 + 0.6, 1.0),
			minf(accent.b * 0.4 + 0.6, 1.0),
			1.0
		)
		_icon_container.add_child(tex_rect)
	else:
		var sym_label := Label.new()
		sym_label.text = _get_type_symbol()
		sym_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sym_label.add_theme_font_size_override("font_size", SettingsManager.font_size(36))
		sym_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		sym_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _data:
			sym_label.add_theme_color_override("font_color", _data.rarity_color)
		_icon_container.add_child(sym_label)

func _get_level_text() -> String:
	if not _data:
		return ""
	match _data.card_type:
		LevelUpCard.CardType.SPELL_UPGRADE:
			return "Lv %d" % _data.new_level
		LevelUpCard.CardType.SPELL_MODIFICATION:
			return SettingsManager.t(&"card_epic_mod")
		LevelUpCard.CardType.NEW_SPELL:
			return SettingsManager.t(&"card_new_spell")
		LevelUpCard.CardType.STAT_BOOST:
			return "Lv %d" % _data.stat_level
		LevelUpCard.CardType.SPELL_FUSION:
			return SettingsManager.t(&"card_fusion")
	return ""

func _get_type_symbol() -> String:
	if not _data:
		return ""
	match _data.card_type:
		LevelUpCard.CardType.NEW_SPELL:
			return "✦"
		LevelUpCard.CardType.SPELL_UPGRADE:
			return "▲"
		LevelUpCard.CardType.SPELL_MODIFICATION:
			return "◆"
		LevelUpCard.CardType.STAT_BOOST:
			return "✧"
		LevelUpCard.CardType.SPELL_FUSION:
			return "★"
	return ""

func play_entrance(delay: float) -> void:
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.03, 1.03), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	t.chain()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: _entrance_done = true)

func play_exit(is_selected: bool) -> void:
	_is_exiting = true
	_is_selected = is_selected
	if is_selected:
		_flash_t = 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1).set_ease(Tween.EASE_OUT)
		t.set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2).set_ease(Tween.EASE_IN)
	else:
		var dir := -1.0 if _index % 2 == 0 else 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
		t.tween_property(self, "position:x", position.x + dir * 50.0, 0.15).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 4.0, 0.0)
	queue_redraw()

func _draw() -> void:
	if not _data:
		return
	var accent := _data.rarity_color
	var h := _hover_t
	_draw_bg(accent, h)
	_draw_border(accent, h)
	_draw_flash()

func _draw_bg(accent: Color, h: float) -> void:
	var bg := Color(
		0.04 + h * 0.01,
		0.035 + h * 0.01,
		0.06 + h * 0.01,
		0.93
	)
	draw_rect(Rect2(0, 0, CARD_W, CARD_H), bg)

func _draw_border(accent: Color, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var points := PackedVector2Array()
	var step := 4.0
	var jx := 5.0
	var jy := 5.0
	var x := 0.0
	while x < CARD_W:
		points.append(Vector2(x + rng.randf_range(-jx * 0.3, jx * 0.3), rng.randf_range(-jy, jy)))
		x += step
	var y := 0.0
	while y < CARD_H:
		points.append(Vector2(CARD_W + rng.randf_range(-jx, jx), y + rng.randf_range(-jy * 0.3, jy * 0.3)))
		y += step
	x = CARD_W
	while x > 0:
		points.append(Vector2(x + rng.randf_range(-jx * 0.3, jx * 0.3), CARD_H + rng.randf_range(-jy, jy)))
		x -= step
	y = CARD_H
	while y > 0:
		points.append(Vector2(rng.randf_range(-jx, jx), y + rng.randf_range(-jy * 0.3, jy * 0.3)))
		y -= step
	points.append(points[0])
	var col := Color(
		minf(accent.r * 0.5 + h * 0.4, 1.0),
		minf(accent.g * 0.5 + h * 0.4, 1.0),
		minf(accent.b * 0.5 + h * 0.4, 1.0),
		0.5 + h * 0.4
	)
	draw_polyline(points, col, 1.5 + h * 0.5, true)

func _draw_flash() -> void:
	if _flash_t < 0.01:
		return
	draw_rect(Rect2(0, 0, CARD_W, CARD_H), Color(1, 1, 1, _flash_t * 0.4))

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

func _on_gui_input(event: InputEvent) -> void:
	if _is_exiting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()

func _on_click() -> void:
	_flash_t = 1.0
	card_clicked.emit()
