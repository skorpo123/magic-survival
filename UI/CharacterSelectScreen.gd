class_name CharacterSelectScreen extends Control

const CARD_SPACING := 20.0
const ENTRANCE_STAGGER := 0.12
const BG := Color(0.025, 0.018, 0.06, 1.0)
const GOLD := Color(0.85, 0.75, 0.55)
const GREEN := Color(0.3, 0.85, 0.55)

signal class_selected(class_data: Dictionary)
signal back_requested

var _selected_id: StringName = &"arcanist"
var _class_list: Array[Dictionary] = []
var _card_nodes: Array[ClassCard] = []
var _is_selecting := false
var _title_pulse_t: float = 0.0

var _overlay: ColorRect
var _fade_overlay: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _ornament: Control
var _currency_label: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _unlock_btn: Button
var _play_btn: Button
var _back_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = BG
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100
	add_child(_fade_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.z_index = 3
	add_child(vbox)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_margin.add_theme_constant_override("margin_left", 40)
	top_margin.add_theme_constant_override("margin_right", 40)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_theme_constant_override("separation", 4)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top_vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"class_select_title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(36))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = SettingsManager.t(&"class_select_subtitle")
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.57, 0.72, 0.85))
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_subtitle_label)

	_ornament = _OrnamentLine.new()
	_ornament.custom_minimum_size = Vector2(500, 10)
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_ornament)

	_currency_label = Label.new()
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_currency_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.8))
	_currency_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_currency_label.add_theme_constant_override("shadow_offset_x", 1)
	_currency_label.add_theme_constant_override("shadow_offset_y", 1)
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_currency_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_empty_style := StyleBoxEmpty.new()
	_scroll.add_theme_stylebox_override("panel", scroll_empty_style)
	_scroll.add_theme_stylebox_override("panel_disabled", scroll_empty_style)
	_scroll.add_theme_stylebox_override("scroll", scroll_empty_style)
	_scroll.add_theme_stylebox_override("scroll_focus", scroll_empty_style)
	_scroll.add_theme_stylebox_override("grabber", scroll_empty_style)
	_scroll.add_theme_stylebox_override("grabber_highlight", scroll_empty_style)
	_scroll.add_theme_stylebox_override("grabber_pressed", scroll_empty_style)
	vbox.add_child(_scroll)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(grid_center)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", int(CARD_SPACING))
	_grid.add_theme_constant_override("v_separation", int(CARD_SPACING))
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid_center.add_child(_grid)

	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_top", 8)
	btn_margin.add_theme_constant_override("margin_bottom", 16)
	btn_margin.add_theme_constant_override("margin_left", 40)
	btn_margin.add_theme_constant_override("margin_right", 40)
	btn_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(btn_margin)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	btn_margin.add_child(btn_row)

	_back_btn = Button.new()
	_back_btn.text = SettingsManager.t(&"btn_return")
	_back_btn.custom_minimum_size = Vector2(220, 48)
	_back_btn.pressed.connect(_on_back_pressed)
	_build_button_style(_back_btn, Color(0.5, 0.3, 0.8))
	btn_row.add_child(_back_btn)

	_unlock_btn = Button.new()
	_unlock_btn.text = SettingsManager.t(&"class_unlock")
	_unlock_btn.custom_minimum_size = Vector2(260, 52)
	_unlock_btn.pressed.connect(_on_unlock_pressed)
	_build_button_style(_unlock_btn, GREEN)
	btn_row.add_child(_unlock_btn)

	_play_btn = Button.new()
	_play_btn.text = SettingsManager.t(&"btn_play")
	_play_btn.custom_minimum_size = Vector2(260, 52)
	_play_btn.pressed.connect(_on_play_pressed)
	_build_button_style(_play_btn, GOLD)
	btn_row.add_child(_play_btn)

func _build_button_style(btn: Button, accent: Color) -> void:
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	btn.add_theme_color_override("font_color", Color(accent.r * 0.7 + 0.3, accent.g * 0.7 + 0.3, accent.b * 0.7 + 0.3))
	btn.add_theme_color_override("font_hover_color", Color(min(accent.r + 0.3, 1.0), min(accent.g + 0.3, 1.0), min(accent.b + 0.3, 1.0)))
	btn.add_theme_color_override("font_disabled_color", Color(0.25, 0.22, 0.3, 0.5))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.85)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.5)
	style.content_margin_left = 20
	style.content_margin_right = 20
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.1, 0.06, 0.16, 0.9)
	hover.border_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.15, 0.1, 0.22, 0.95)
	pressed.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", style)

func show_screen() -> void:
	_class_list = CharacterManager.get_all_classes()
	_selected_id = CharacterManager._selected_class_id
	if _selected_id == &"" or not CharacterManager.is_unlocked(_selected_id):
		_selected_id = &"arcanist"
	_is_selecting = false

	for child in _grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_animate_title_in()

	for i in _class_list.size():
		var cls := _class_list[i]
		var card := ClassCard.new()
		card.setup(cls, i)
		_grid.add_child(card)
		_card_nodes.append(card)
		var idx: int = i
		card.card_clicked.connect(func() -> void: _on_card_pressed(idx))
		card.play_entrance(0.25 + i * ENTRANCE_STAGGER)

	_update_selection_visuals()
	_update_ui()
	_fade_overlay.color = Color(0, 0, 0, 0)
	visible = true

func hide_screen() -> void:
	visible = false

func _animate_title_in() -> void:
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_subtitle_label, "modulate:a", 0.7, 0.5).set_ease(Tween.EASE_OUT).set_delay(0.15)

func _process(delta: float) -> void:
	_title_pulse_t += delta
	var pulse := 0.88 + 0.12 * sin(_title_pulse_t * 2.0)
	_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.88, pulse * 0.65))

func _on_card_pressed(index: int) -> void:
	if _is_selecting or index < 0 or index >= _class_list.size():
		return
	var cls: Dictionary = _class_list[index]
	if not CharacterManager.is_unlocked(cls.id):
		return
	_selected_id = cls.id
	CharacterManager.select_class(cls.id)
	_update_selection_visuals()
	_update_ui()

func _apply_selection() -> void:
	visible = false
	class_selected.emit(CharacterManager.get_selected_class())

func _update_selection_visuals() -> void:
	for i in _card_nodes.size():
		if is_instance_valid(_card_nodes[i]):
			_card_nodes[i].set_selected(_class_list[i].id == _selected_id)

func _update_ui() -> void:
	_currency_label.text = "%s: %d" % [SettingsManager.t(&"currency"), UpgradeManager.persistent_currency]
	_unlock_btn.disabled = not CharacterManager.can_unlock()
	_play_btn.disabled = _selected_id == &""

func _on_unlock_pressed() -> void:
	var opened := CharacterManager.try_unlock_random()
	if opened.is_empty():
		return
	show_screen()

func _on_play_pressed() -> void:
	if _selected_id == &"":
		return
	CharacterManager.select_class(_selected_id)
	_is_selecting = true
	for i in _card_nodes.size():
		if is_instance_valid(_card_nodes[i]):
			_card_nodes[i].play_exit(_class_list[i].id == _selected_id)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	t.tween_property(_subtitle_label, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.chain()
	t.tween_interval(0.15)
	t.set_parallel(false)
	t.tween_property(_fade_overlay, "color:a", 1.0, 0.45).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _apply_selection())

func _on_back_pressed() -> void:
	back_requested.emit()

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"class_select_title")
	_subtitle_label.text = SettingsManager.t(&"class_select_subtitle")
	_unlock_btn.text = SettingsManager.t(&"class_unlock")
	_play_btn.text = SettingsManager.t(&"btn_play")
	_back_btn.text = SettingsManager.t(&"btn_return")
	_update_ui()

class _OrnamentLine extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var line_w := w * 0.38
		var cx := w * 0.5
		var col := Color(0.55, 0.48, 0.3, 0.4)
		draw_line(Vector2(cx - line_w, y), Vector2(cx - 12, y), col, 1.0, true)
		draw_line(Vector2(cx + 12, y), Vector2(cx + line_w, y), col, 1.0, true)
		draw_rect(Rect2(cx - 5, y - 1.5, 10, 3), Color(0.65, 0.55, 0.35, 0.5))
