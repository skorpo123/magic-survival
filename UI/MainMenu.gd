class_name MainMenu extends Control

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const VIOLET := Color(0.5, 0.3, 0.8)
const CRIMSON := Color(0.7, 0.15, 0.15)
const GREEN := Color(0.4, 0.85, 0.6)
const CORNER := 6
const BORDER_W := 1

var _play_btn: Button
var _settings_btn: Button
var _exit_btn: Button
var _settings_menu: SettingsMenu
var _title_label: Label
var _pulse_t: float = 0.0
var _inner_power_btn: Button
var _inner_power_screen: InnerPowerScreen

signal play_pressed

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

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	add_child(center)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"menu_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(56))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	center.add_child(_title_label)

	var divider := HBoxContainer.new()
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	divider.custom_minimum_size.y = 20
	center.add_child(divider)

	var line_l := ColorRect.new()
	line_l.custom_minimum_size = Vector2(160, 1)
	line_l.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
	divider.add_child(line_l)

	var diamond := Label.new()
	diamond.text = "◆"
	diamond.add_theme_font_size_override("font_size", SettingsManager.font_size(10))
	diamond.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.5))
	divider.add_child(diamond)

	var line_r := ColorRect.new()
	line_r.custom_minimum_size = Vector2(160, 1)
	line_r.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.4)
	divider.add_child(line_r)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t(&"menu_subtitle")
	subtitle.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	subtitle.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.5))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 70
	center.add_child(spacer)

	_play_btn = _make_button(SettingsManager.t(&"btn_play"), GOLD)
	_play_btn.pressed.connect(_on_play)
	center.add_child(_play_btn)

	_inner_power_btn = _make_button(SettingsManager.t(&"btn_inner_power"), GREEN)
	_inner_power_btn.pressed.connect(_on_inner_power)
	center.add_child(_inner_power_btn)

	_settings_btn = _make_button(SettingsManager.t(&"btn_settings"), VIOLET)
	_settings_btn.pressed.connect(_on_settings)
	center.add_child(_settings_btn)

	_exit_btn = _make_button(SettingsManager.t(&"btn_exit"), CRIMSON)
	_exit_btn.pressed.connect(_on_exit)
	center.add_child(_exit_btn)

	_settings_menu = SettingsMenu.new()
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.visible = false
	_settings_menu.close_requested.connect(_on_submenu_close)
	add_child(_settings_menu)

	_inner_power_screen = InnerPowerScreen.new()
	_inner_power_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inner_power_screen.visible = false
	_inner_power_screen.close_requested.connect(_on_submenu_close)
	add_child(_inner_power_screen)

func _process(delta: float) -> void:
	_pulse_t += delta
	var pulse := 0.75 + 0.15 * sin(_pulse_t * 1.5)
	_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.78, pulse * 0.32))

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"menu_title")
	_play_btn.text = SettingsManager.t(&"btn_play")
	_settings_btn.text = SettingsManager.t(&"btn_settings")
	_inner_power_btn.text = SettingsManager.t(&"btn_inner_power")
	_exit_btn.text = SettingsManager.t(&"btn_exit")

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(380, 58)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"))
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
	style.content_margin_left = 28
	style.content_margin_right = 28
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

func _on_play() -> void:
	play_pressed.emit()

func _on_settings() -> void:
	_settings_menu.sync_controls()
	_settings_menu.visible = true

func _on_inner_power() -> void:
	_inner_power_screen._refresh_all()
	_inner_power_screen.visible = true

func _on_submenu_close() -> void:
	_settings_menu.visible = false
	if _inner_power_screen:
		_inner_power_screen.visible = false

func _on_exit() -> void:
	get_tree().quit()
