class_name PauseMenu extends Control

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const VIOLET := Color(0.5, 0.3, 0.8)
const CRIMSON := Color(0.7, 0.15, 0.15)
const ARTIFACT_COL := Color(0.7, 0.45, 0.9)
const CORNER := 6
const BORDER_W := 1
const STAT_LABEL_COL := Color(0.55, 0.52, 0.62)
const STAT_COLOR_BONUS := Color(0.3, 0.85, 0.4)
const STAT_COLOR_ZERO := Color(0.45, 0.45, 0.5)
const STAT_COLOR_DEFAULT := Color(0.9, 0.87, 0.95)
const ICON_SIZE := Vector2(36, 36)

const STAT_ICON_PATHS: Dictionary = {
	&"stat_max_hp": "res://Sprites/Health_icon_pix.png",
	&"stat_hp_regen": "res://Sprites/HP_Regeneration_icon_pix.png",
	&"stat_dmg_reduction": "res://Sprites/Damage_Taken_icon_pix.png",
	&"stat_dodge": "res://Sprites/Dodge_icon_pix.png",
	&"stat_speed": "res://Sprites/Movement_Speed_icon_pix.png",
	&"stat_crit_chance": "res://Sprites/Crit_Chance_icon_pix.png",
	&"stat_crit_damage": "res://Sprites/Crit_Damage_icon_pix.png",
	&"stat_magic": "res://Sprites/Magic_Power_icon_pix.png",
	&"stat_atk_mult": "res://Sprites/Damage_Multiplier_icon_pix.png",
	&"stat_spell_duration": "res://Sprites/Spell_Duration_icon_pix.png",
	&"stat_area": "res://Sprites/Spell_Size_icon_pix.png",
	&"stat_cd": "res://Sprites/Cooldown_Reduction_icon_pix.png",
	&"stat_proj_speed": "res://Sprites/Attack_Power_icon_pix.png",
	&"stat_enemy_hp": "res://Sprites/Enemy_Max_HP_icon_pix.png",
	&"stat_mana_gain": "res://Sprites/XP_icon_pix.png",
	&"stat_pickup": "res://Sprites/Pickup_Radius_icon_pix.png",
	&"stat_life_steal": "res://Sprites/Lifesteal_icon_pix.png",
}

# --- Stat definitions: [translation_key, format_type] ---
# format_type: 0=int, 1=per_sec, 2=percent(0-1), 3=mult, 5=percent_bare
const STAT_DEFS: Array[Array] = [
	[&"stat_max_hp", 4],
	[&"stat_hp_regen", 1],
	[&"stat_dmg_reduction", 5],
	[&"stat_dodge", 2],
	[&"stat_speed", 0],
	[&"stat_crit_chance", 2],
	[&"stat_crit_damage", 0],
	[&"stat_magic", 3],
	[&"stat_atk_mult", 5],
	[&"stat_spell_duration", 5],
	[&"stat_area", 5],
	[&"stat_cd", 5],
	[&"stat_proj_speed", 3],
	[&"stat_enemy_hp", 5],
	[&"stat_mana_gain", 5],
	[&"stat_pickup", 0],
	[&"stat_life_steal", 2],
]

var _settings_menu: SettingsMenu
var _artifacts_screen: ArtifactSlotsScreen
var _title_label: Label
var _summary_label: Label
var _stat_icon_rects: Array[TextureRect] = []
var _stat_labels: Array[Label] = []
var _stat_values: Array[Label] = []
var _btn_continue: Button
var _btn_settings: Button
var _btn_artifacts: Button
var _btn_abandon: Button
var _btn_spells: Button
var _current_spells_screen: CurrentSpellsScreen
var _pulse_t: float = 0.0
var _confirm_overlay: ColorRect
var _confirm_title: Label
var _confirm_msg: Label

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"pause_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(800, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ornament)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_summary_label.add_theme_color_override("font_color", TEXT_COL)
	_summary_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_summary_label.add_theme_constant_override("shadow_offset_x", 1)
	_summary_label.add_theme_constant_override("shadow_offset_y", 1)
	_summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_summary_label)

	var spacer_top := Control.new()
	spacer_top.custom_minimum_size.y = 4
	vbox.add_child(spacer_top)

	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 80)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cols)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 2)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 2)
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right_col)

	var left_count: int = 9
	for i: int in range(STAT_DEFS.size()):
		var def: Array = STAT_DEFS[i]
		var row := _make_stat_row(def)
		if i < left_count:
			left_col.add_child(row)
		else:
			right_col.add_child(row)

	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size.y = 6
	vbox.add_child(spacer_mid)

	_btn_continue = _make_button(SettingsManager.t(&"pause_continue"), GOLD)
	_btn_continue.custom_minimum_size = Vector2(280, 52)
	_btn_continue.pressed.connect(_on_resume)
	vbox.add_child(_btn_continue)

	var spacer_bot := Control.new()
	spacer_bot.custom_minimum_size.y = 6
	vbox.add_child(spacer_bot)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 24)
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_row)

	_btn_settings = _make_circle_button("⚙", VIOLET)
	_btn_settings.pressed.connect(_on_settings)
	bottom_row.add_child(_btn_settings)

	_btn_artifacts = _make_circle_button("◈", ARTIFACT_COL)
	_btn_artifacts.pressed.connect(_on_artifacts)
	bottom_row.add_child(_btn_artifacts)

	_btn_spells = _make_circle_button("⚡", Color(0.9, 0.75, 0.2))
	_btn_spells.pressed.connect(_on_spells)
	bottom_row.add_child(_btn_spells)

	_btn_abandon = _make_circle_button("✕", CRIMSON)
	_btn_abandon.pressed.connect(_on_main_menu)
	bottom_row.add_child(_btn_abandon)

	_settings_menu = SettingsMenu.new()
	_settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_menu.visible = false
	_settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_menu.close_requested.connect(_on_settings_close)
	add_child(_settings_menu)

	_artifacts_screen = ArtifactSlotsScreen.new()
	_artifacts_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_artifacts_screen.visible = false
	_artifacts_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_artifacts_screen.close_requested.connect(_on_artifacts_close)
	add_child(_artifacts_screen)

	_current_spells_screen = CurrentSpellsScreen.new()
	_current_spells_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_current_spells_screen.visible = false
	_current_spells_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_current_spells_screen.close_requested.connect(_on_spells_close)
	add_child(_current_spells_screen)

	_build_confirm_overlay()

func _process(delta: float) -> void:
	_pulse_t += delta
	var pulse := 0.7 + 0.15 * sin(_pulse_t * 2.0)
	_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.78, pulse * 0.32))
	if visible:
		_refresh_summary()
		_refresh_stat_values()

func _make_stat_row(def: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- ICON ---
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = STAT_ICON_PATHS.get(def[0], "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	row.add_child(icon)
	_stat_icon_rects.append(icon)

	var lbl := Label.new()
	lbl.text = SettingsManager.t(def[0])
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	lbl.add_theme_color_override("font_color", STAT_LABEL_COL)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	_stat_labels.append(lbl)

	var val := Label.new()
	val.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	val.add_theme_color_override("font_color", STAT_COLOR_DEFAULT)
	val.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	_stat_values.append(val)

	return row

func _refresh_summary() -> void:
	var lvl: int = GameManager.current_level
	var time_str: String = GameManager.format_time()
	var kills: int = GameManager.enemies_killed
	_summary_label.text = SettingsManager.t(&"pause_summary") % [lvl, time_str, kills]

func _refresh_stat_values() -> void:
	var player := GameManager.get_player()
	if player == null or player.stats == null:
		return
	var s: PlayerStats = player.stats
	for i: int in range(STAT_DEFS.size()):
		if i >= _stat_values.size():
			break
		var def: Array = STAT_DEFS[i]
		var key: StringName = def[0]
		var fmt: int = def[1]
		var v: float = 0.0
		match key:
			&"stat_max_hp": v = s.max_hp
			&"stat_hp_regen": v = s.hp_regen
			&"stat_dmg_reduction": v = s.damage_reduction
			&"stat_dodge": v = s.dodge_chance
			&"stat_speed": v = s.move_speed
			&"stat_crit_chance": v = s.crit_chance
			&"stat_crit_damage": v = s.crit_damage_mult * 100.0
			&"stat_magic": v = s.magic_power * 100.0
			&"stat_atk_mult": v = s.magic_power - 1.0
			&"stat_spell_duration": v = s.spell_duration_mult - 1.0
			&"stat_area": v = s.area_multiplier - 1.0
			&"stat_cd": v = s.cooldown_reduction
			&"stat_proj_speed": v = s.projectile_speed_mult
			&"stat_enemy_hp": v = s.enemy_max_hp_mult - 1.0
			&"stat_mana_gain": v = s.mana_gain - 1.0
			&"stat_life_steal": v = s.life_steal
			&"stat_pickup": v = s.pickup_range
		_stat_values[i].text = _format_stat(v, fmt)
		_stat_values[i].add_theme_color_override("font_color", _get_stat_color(key, v))

func _get_stat_color(key: StringName, val: float) -> Color:
	var is_zero: bool = is_zero_approx(val)
	var is_default: bool = false
	match key:
		&"stat_max_hp": is_default = is_equal_approx(val, 100.0)
		&"stat_hp_regen": is_default = is_zero
		&"stat_dmg_reduction": is_default = is_zero
		&"stat_dodge": is_default = is_zero
		&"stat_speed": is_default = is_equal_approx(val, 150.0)
		&"stat_crit_chance": is_default = is_zero
		&"stat_crit_damage": is_default = is_equal_approx(val, 200.0)
		&"stat_magic": is_default = is_equal_approx(val, 100.0)
		&"stat_atk_mult": is_default = is_zero
		&"stat_spell_duration": is_default = is_zero
		&"stat_area": is_default = is_zero
		&"stat_cd": is_default = is_zero
		&"stat_proj_speed": is_default = is_equal_approx(val, 1.0)
		&"stat_enemy_hp": is_default = is_zero
		&"stat_mana_gain": is_default = is_zero
		&"stat_life_steal": is_default = is_zero
		&"stat_pickup": is_default = is_equal_approx(val, 80.0)
	if is_zero:
		return STAT_COLOR_ZERO
	if is_default:
		return STAT_COLOR_DEFAULT
	return STAT_COLOR_BONUS

func _format_stat(v: float, fmt: int) -> String:
	match fmt:
		0: return "%d" % int(v)
		1: return "%.1f/s" % v
		2: return "%d%%" % int(v * 100)
		3: return "×%.2f" % v
		4: return "%d / %d" % [int(v), int(v)]
		5: return "%+d%%" % int(v * 100)
		_: return "%d" % int(v)

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"pause_title")
	_btn_continue.text = SettingsManager.t(&"pause_continue")
	for i: int in range(STAT_DEFS.size()):
		if i < _stat_labels.size():
			_stat_labels[i].text = SettingsManager.t(STAT_DEFS[i][0])
	_refresh_summary()

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(340, 56)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
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

func _make_circle_button(icon: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(56, 56)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(24))
	btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"))
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color(min(accent.r + 0.3, 1.0), min(accent.g + 0.3, 1.0), min(accent.b + 0.3, 1.0)))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.9))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.08, 0.75)
	style.set_corner_radius_all(28)
	style.set_border_width_all(BORDER_W)
	style.border_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.5)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 0.85)
	hover.border_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_s := style.duplicate()
	pressed_s.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22)
	pressed_s.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed_s)
	return btn

func _on_resume() -> void:
	visible = false
	GameManager.resume_game()

func _on_settings() -> void:
	_settings_menu.sync_controls()
	_settings_menu.visible = true

func _on_settings_close() -> void:
	_settings_menu.visible = false

func _on_artifacts() -> void:
	_artifacts_screen.refresh()
	_artifacts_screen.visible = true

func _on_artifacts_close() -> void:
	_artifacts_screen.visible = false

func _on_spells() -> void:
	_current_spells_screen.visible = true
	_current_spells_screen.show_spells()

func _on_spells_close() -> void:
	_current_spells_screen.visible = false

func _on_main_menu() -> void:
	_confirm_overlay.visible = true

func _on_confirm_exit() -> void:
	_confirm_overlay.visible = false
	visible = false
	GameManager.trigger_game_over()

func _on_confirm_cancel() -> void:
	_confirm_overlay.visible = false

func _build_confirm_overlay() -> void:
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(center)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 16)
	center.add_child(panel)

	_confirm_title = Label.new()
	_confirm_title.text = SettingsManager.t(&"confirm_exit_title")
	_confirm_title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_confirm_title.add_theme_font_size_override("font_size", SettingsManager.font_size(28))
	_confirm_title.add_theme_color_override("font_color", GOLD)
	panel.add_child(_confirm_title)

	_confirm_msg = Label.new()
	_confirm_msg.text = SettingsManager.t(&"confirm_exit_msg")
	_confirm_msg.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_confirm_msg.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	_confirm_msg.add_theme_color_override("font_color", TEXT_COL)
	panel.add_child(_confirm_msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	panel.add_child(btn_row)

	var btn_confirm := Button.new()
	btn_confirm.text = SettingsManager.t(&"confirm_exit_yes")
	btn_confirm.custom_minimum_size = Vector2(200, 48)
	btn_confirm.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	btn_confirm.add_theme_color_override("font_color", Color.WHITE)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = CRIMSON
	confirm_style.set_corner_radius_all(CORNER)
	confirm_style.content_margin_left = 20
	confirm_style.content_margin_right = 20
	btn_confirm.add_theme_stylebox_override("normal", confirm_style)
	var confirm_hover := confirm_style.duplicate()
	confirm_hover.bg_color = Color(CRIMSON.r * 1.3, CRIMSON.g * 1.3, CRIMSON.b * 1.3)
	btn_confirm.add_theme_stylebox_override("hover", confirm_hover)
	btn_confirm.pressed.connect(_on_confirm_exit)
	btn_row.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.text = "✕"
	btn_cancel.custom_minimum_size = Vector2(48, 48)
	btn_cancel.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	btn_cancel.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.15, 0.13, 0.18, 0.9)
	cancel_style.set_corner_radius_all(CORNER)
	cancel_style.set_border_width_all(1)
	cancel_style.border_color = Color(0.35, 0.3, 0.4, 0.5)
	btn_cancel.add_theme_stylebox_override("normal", cancel_style)
	btn_cancel.pressed.connect(_on_confirm_cancel)
	btn_row.add_child(btn_cancel)

	SettingsManager.language_changed.connect(_refresh_confirm_texts)

func _refresh_confirm_texts() -> void:
	if _confirm_title:
		_confirm_title.text = SettingsManager.t(&"confirm_exit_title")
	if _confirm_msg:
		_confirm_msg.text = SettingsManager.t(&"confirm_exit_msg")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_menu.visible:
			_settings_menu.visible = false
			accept_event()
			return
		if _artifacts_screen.visible:
			_artifacts_screen.visible = false
			accept_event()
			return
		if _confirm_overlay.visible:
			_confirm_overlay.visible = false
			accept_event()
			return
		if _current_spells_screen.visible:
			_current_spells_screen.visible = false
			accept_event()
			return
		if visible:
			visible = false
			GameManager.resume_game()
			accept_event()
			return
		if GameManager.is_playing():
			visible = true
			GameManager.pause_game()
			accept_event()

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
