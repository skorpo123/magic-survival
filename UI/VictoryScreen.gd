class_name VictoryScreen extends Control

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.85, 0.7, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const VIOLET := Color(0.5, 0.3, 0.8)
const CORNER := 6
const BORDER_W := 1

var _time_label: Label
var _kills_label: Label
var _level_label: Label
var _earned_label: Label
var _vault_label: Label
var _menu_btn: Button
var _restart_btn: Button
var _endless_btn: Button
var _title_label: Label
var _pulse_t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"victory_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(52))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(_title_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(500, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ornament)

	var subtitle := Label.new()
	subtitle.text = SettingsManager.t(&"victory_subtitle")
	subtitle.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	subtitle.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.5))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	vbox.add_child(spacer)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_time_label.add_theme_color_override("font_color", TEXT_COL)
	_time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_time_label.add_theme_constant_override("shadow_offset_x", 1)
	_time_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_time_label)

	_kills_label = Label.new()
	_kills_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_kills_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_kills_label.add_theme_color_override("font_color", TEXT_COL)
	_kills_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_kills_label.add_theme_constant_override("shadow_offset_x", 1)
	_kills_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_kills_label)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_level_label.add_theme_color_override("font_color", GOLD)
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_level_label.add_theme_constant_override("shadow_offset_x", 1)
	_level_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_level_label)

	_earned_label = Label.new()
	_earned_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_earned_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_earned_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_earned_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_earned_label.add_theme_constant_override("shadow_offset_x", 1)
	_earned_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_earned_label)

	_vault_label = Label.new()
	_vault_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_vault_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_vault_label.add_theme_color_override("font_color", GOLD)
	_vault_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_vault_label.add_theme_constant_override("shadow_offset_x", 1)
	_vault_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_vault_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 36
	vbox.add_child(spacer2)

	_endless_btn = _make_button(SettingsManager.t(&"btn_continue_endless"), GOLD)
	_endless_btn.pressed.connect(_on_endless)
	vbox.add_child(_endless_btn)

	_restart_btn = _make_button(SettingsManager.t(&"btn_restart"), Color(0.5, 0.7, 0.4))
	_restart_btn.pressed.connect(_on_restart)
	vbox.add_child(_restart_btn)

	_menu_btn = _make_button(SettingsManager.t(&"btn_return_menu"), VIOLET)
	_menu_btn.pressed.connect(_on_menu)
	vbox.add_child(_menu_btn)

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"victory_title")
	_endless_btn.text = SettingsManager.t(&"btn_continue_endless")
	_restart_btn.text = SettingsManager.t(&"btn_restart")
	_menu_btn.text = SettingsManager.t(&"btn_return_menu")

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(340, 56)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"))
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color(minf(accent.r + 0.3, 1.0), minf(accent.g + 0.3, 1.0), minf(accent.b + 0.3, 1.0)))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.9))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.8)
	style.set_corner_radius_all(CORNER)
	style.set_border_width_all(BORDER_W)
	style.border_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.5)
	style.content_margin_left = 20
	style.content_margin_right = 20
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

func _on_endless() -> void:
	visible = false
	GameManager.enter_endless()

func _on_restart() -> void:
	visible = false
	GameManager.start_game()

func _on_menu() -> void:
	visible = false
	GameManager.return_to_menu()

func _process(_delta: float) -> void:
	if visible:
		_pulse_t += _delta
		var pulse := 0.7 + 0.15 * sin(_pulse_t * 2.0)
		_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.82, pulse * 0.3))
		_time_label.text = SettingsManager.t(&"stat_time") + "  " + GameManager.format_time()
		_kills_label.text = SettingsManager.t(&"stat_kills") + "  %d" % GameManager.enemies_killed
		_level_label.text = SettingsManager.t(&"stat_level") + "  %d" % GameManager.current_level
		if _earned_label:
			_earned_label.text = SettingsManager.t(&"earned_currency") + "  %d" % GameManager._last_run_currency
		if _vault_label:
			_vault_label.text = SettingsManager.t(&"total_vault") + "  %d" % UpgradeManager.persistent_currency

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
