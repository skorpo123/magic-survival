class_name SettingsMenu extends Control

signal close_requested

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const VIOLET := Color(0.5, 0.3, 0.8)
const CYAN := Color(0.3, 0.75, 0.95)
const CORNER := 6
const BORDER_W := 1

var _fullscreen_check: CheckBox
var _vsync_check: CheckBox
var _master_slider: HSlider
var _master_label: Label
var _shake_slider: HSlider
var _shake_label: Label
var _ui_scale_slider: HSlider
var _ui_scale_label: Label
var _lang_option: OptionButton
var _title_label: Label
var _fs_label: Label
var _vol_label: Label
var _lang_label: Label
var _shake_label_title: Label
var _vsync_label: Label
var _ui_scale_label_title: Label
var _back_btn: Button

func _ready() -> void:
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 22)
	center.add_child(panel)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"settings_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	panel.add_child(_title_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(500, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ornament)

	_fs_label = _make_section_label("")
	panel.add_child(_fs_label)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = SettingsManager.t(&"opt_fullscreen")
	_fullscreen_check.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_fullscreen_check.add_theme_color_override("font_color", TEXT_COL)
	_fullscreen_check.add_theme_color_override("font_hover_color", Color(min(TEXT_COL.r + 0.15, 1.0), min(TEXT_COL.g + 0.15, 1.0), min(TEXT_COL.b + 0.15, 1.0)))
	_fullscreen_check.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_fullscreen_check.add_theme_constant_override("shadow_offset_x", 1)
	_fullscreen_check.add_theme_constant_override("shadow_offset_y", 1)
	_fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	panel.add_child(_fullscreen_check)

	_vsync_label = _make_section_label("")
	panel.add_child(_vsync_label)

	_vsync_check = CheckBox.new()
	_vsync_check.text = SettingsManager.t(&"opt_vsync")
	_vsync_check.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_vsync_check.add_theme_color_override("font_color", TEXT_COL)
	_vsync_check.add_theme_color_override("font_hover_color", Color(min(TEXT_COL.r + 0.15, 1.0), min(TEXT_COL.g + 0.15, 1.0), min(TEXT_COL.b + 0.15, 1.0)))
	_vsync_check.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_vsync_check.add_theme_constant_override("shadow_offset_x", 1)
	_vsync_check.add_theme_constant_override("shadow_offset_y", 1)
	_vsync_check.button_pressed = SettingsManager.get_vsync()
	_vsync_check.toggled.connect(_on_vsync_toggled)
	panel.add_child(_vsync_check)

	_ui_scale_label_title = _make_section_label(SettingsManager.t(&"opt_ui_scale"))
	panel.add_child(_ui_scale_label_title)

	var scale_row := HBoxContainer.new()
	scale_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scale_row.add_theme_constant_override("separation", 16)
	panel.add_child(scale_row)

	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.75
	_ui_scale_slider.max_value = 1.5
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.value = SettingsManager.get_ui_scale()
	_ui_scale_slider.custom_minimum_size.x = 420
	_ui_scale_slider.add_theme_color_override("grabber_area", GOLD)
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	scale_row.add_child(_ui_scale_slider)

	_ui_scale_label = Label.new()
	_ui_scale_label.text = "%.0f%%" % (SettingsManager.get_ui_scale() * 100)
	_ui_scale_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_ui_scale_label.add_theme_color_override("font_color", GOLD)
	_ui_scale_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_ui_scale_label.add_theme_constant_override("shadow_offset_x", 1)
	_ui_scale_label.add_theme_constant_override("shadow_offset_y", 1)
	_ui_scale_label.custom_minimum_size.x = 60
	_ui_scale_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	scale_row.add_child(_ui_scale_label)

	_vol_label = _make_section_label(SettingsManager.t(&"opt_volume"))
	panel.add_child(_vol_label)

	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vol_row.add_theme_constant_override("separation", 16)
	panel.add_child(vol_row)

	_master_slider = HSlider.new()
	_master_slider.min_value = 0.0
	_master_slider.max_value = 100.0
	_master_slider.step = 5.0
	_master_slider.value = SettingsManager.get_volume()
	_master_slider.custom_minimum_size.x = 420
	_master_slider.add_theme_color_override("grabber_area", VIOLET)
	_master_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_master_slider)

	_master_label = Label.new()
	_master_label.text = "%d%%" % int(SettingsManager.get_volume())
	_master_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_master_label.add_theme_color_override("font_color", VIOLET)
	_master_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_master_label.add_theme_constant_override("shadow_offset_x", 1)
	_master_label.add_theme_constant_override("shadow_offset_y", 1)
	_master_label.custom_minimum_size.x = 60
	_master_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	vol_row.add_child(_master_label)

	_shake_label_title = _make_section_label(SettingsManager.t(&"opt_shake"))
	panel.add_child(_shake_label_title)

	var shake_row := HBoxContainer.new()
	shake_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shake_row.add_theme_constant_override("separation", 16)
	panel.add_child(shake_row)

	_shake_slider = HSlider.new()
	_shake_slider.min_value = 0.0
	_shake_slider.max_value = 100.0
	_shake_slider.step = 5.0
	_shake_slider.value = SettingsManager.get_screen_shake()
	_shake_slider.custom_minimum_size.x = 420
	_shake_slider.add_theme_color_override("grabber_area", CYAN)
	_shake_slider.value_changed.connect(_on_shake_changed)
	shake_row.add_child(_shake_slider)

	_shake_label = Label.new()
	_shake_label.text = "%d%%" % int(SettingsManager.get_screen_shake())
	_shake_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_shake_label.add_theme_color_override("font_color", CYAN)
	_shake_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_shake_label.add_theme_constant_override("shadow_offset_x", 1)
	_shake_label.add_theme_constant_override("shadow_offset_y", 1)
	_shake_label.custom_minimum_size.x = 60
	_shake_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	shake_row.add_child(_shake_label)

	_lang_label = _make_section_label(SettingsManager.t(&"opt_language"))
	panel.add_child(_lang_label)

	_lang_option = OptionButton.new()
	var lang_idx := 0
	var current_lang := SettingsManager.get_language()
	var i := 0
	for lang_key in SettingsManager.LANGUAGES:
		_lang_option.add_item(SettingsManager.LANGUAGES[lang_key], i)
		if lang_key == current_lang:
			lang_idx = i
		i += 1
	_lang_option.selected = lang_idx
	_lang_option.item_selected.connect(_on_language_selected)
	_lang_option.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_lang_option.add_theme_color_override("font_color", TEXT_COL)
	_lang_option.add_theme_color_override("font_hover_color", Color(min(TEXT_COL.r + 0.15, 1.0), min(TEXT_COL.g + 0.15, 1.0), min(TEXT_COL.b + 0.15, 1.0)))
	_lang_option.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_lang_option.add_theme_constant_override("shadow_offset_x", 1)
	_lang_option.add_theme_constant_override("shadow_offset_y", 1)
	var opt_style := StyleBoxFlat.new()
	opt_style.bg_color = Color(0.06, 0.04, 0.10, 0.85)
	opt_style.set_corner_radius_all(CORNER)
	opt_style.set_border_width_all(BORDER_W)
	opt_style.border_color = Color(0.25, 0.18, 0.4, 0.5)
	_lang_option.add_theme_stylebox_override("normal", opt_style)
	panel.add_child(_lang_option)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	panel.add_child(spacer)

	_back_btn = _make_button(SettingsManager.t(&"btn_return"), GOLD)
	_back_btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"); close_requested.emit())
	panel.add_child(_back_btn)

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	lbl.add_theme_color_override("font_color", TEXT_COL)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 52)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color(min(accent.r + 0.3, 1.0), min(accent.g + 0.3, 1.0), min(accent.b + 0.3, 1.0)))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.9))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.8)
	style.set_corner_radius_all(CORNER)
	style.set_border_width_all(BORDER_W)
	style.border_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.85)
	hover.border_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_s := style.duplicate()
	pressed_s.bg_color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2)
	pressed_s.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed_s)
	return btn

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.set_vsync(pressed)

func _on_volume_changed(value: float) -> void:
	SettingsManager.set_volume(value)
	_master_label.text = "%d%%" % int(value)

func _on_shake_changed(value: float) -> void:
	SettingsManager.set_screen_shake(value)
	_shake_label.text = "%d%%" % int(value)

func _on_ui_scale_changed(value: float) -> void:
	SettingsManager.set_ui_scale(value)
	_ui_scale_label.text = "%.0f%%" % (value * 100)
	_apply_ui_scale(value)

func _apply_ui_scale(_scale: float) -> void:
	pass

func _on_language_selected(idx: int) -> void:
	var keys := SettingsManager.LANGUAGES.keys()
	if idx >= 0 and idx < keys.size():
		SettingsManager.set_language(keys[idx])

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"settings_title")
	_fullscreen_check.text = SettingsManager.t(&"opt_fullscreen")
	_vsync_check.text = SettingsManager.t(&"opt_vsync")
	_ui_scale_label_title.text = SettingsManager.t(&"opt_ui_scale")
	_vol_label.text = SettingsManager.t(&"opt_volume")
	_shake_label_title.text = SettingsManager.t(&"opt_shake")
	_lang_label.text = SettingsManager.t(&"opt_language")
	_back_btn.text = SettingsManager.t(&"btn_return")
	sync_controls()

func sync_controls() -> void:
	_fullscreen_check.button_pressed = SettingsManager.get_fullscreen()
	_vsync_check.button_pressed = SettingsManager.get_vsync()
	_ui_scale_slider.value = SettingsManager.get_ui_scale()
	_ui_scale_label.text = "%.0f%%" % (SettingsManager.get_ui_scale() * 100)
	_master_slider.value = SettingsManager.get_volume()
	_master_label.text = "%d%%" % int(SettingsManager.get_volume())
	_shake_slider.value = SettingsManager.get_screen_shake()
	_shake_label.text = "%d%%" % int(SettingsManager.get_screen_shake())
	var current_lang := SettingsManager.get_language()
	var i := 0
	for lang_key in SettingsManager.LANGUAGES:
		if lang_key == current_lang:
			_lang_option.selected = i
			break
		i += 1

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

class _OrnamentLine extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var line_w := w * 0.35
		var cx := w * 0.5
		var col := Color(0.55, 0.48, 0.3, 0.3)
		draw_line(Vector2(cx - line_w, y), Vector2(cx - 8, y), col, 1.0, true)
		draw_line(Vector2(cx + 8, y), Vector2(cx + line_w, y), col, 1.0, true)
		draw_circle(Vector2(cx - 8, y), 2.0, Color(0.65, 0.55, 0.35, 0.4))
		draw_circle(Vector2(cx + 8, y), 2.0, Color(0.65, 0.55, 0.35, 0.4))
		draw_circle(Vector2(cx, y), 1.5, Color(0.65, 0.55, 0.35, 0.5))
