class_name InnerPowerScreen extends Control

signal close_requested

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const GREEN := Color(0.4, 0.85, 0.6)
const CORNER := 6
const BORDER_W := 1
const MAX_LEVEL := 5

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

const ICON_SIZE := Vector2(36, 36)

const STAT_DEFS: Array = [
	{"key": "max_hp", "label_key": &"stat_max_hp", "color": Color(0.9, 0.3, 0.3), "icon_key": &"stat_max_hp"},
	{"key": "hp_regen", "label_key": &"stat_hp_regen", "color": Color(0.4, 0.95, 0.5), "icon_key": &"stat_hp_regen"},
	{"key": "damage_reduction", "label_key": &"stat_dmg_reduction", "color": Color(0.85, 0.4, 0.4), "icon_key": &"stat_dmg_reduction"},
	{"key": "dodge_chance", "label_key": &"stat_dodge", "color": Color(0.7, 0.75, 0.85), "icon_key": &"stat_dodge"},
	{"key": "move_speed", "label_key": &"stat_speed", "color": Color(0.3, 0.8, 1.0), "icon_key": &"stat_speed"},
	{"key": "magic_power", "label_key": &"stat_magic", "color": Color(0.8, 0.4, 1.0), "icon_key": &"stat_magic"},
	{"key": "crit_chance", "label_key": &"stat_crit_chance", "color": Color(1.0, 0.65, 0.2), "icon_key": &"stat_crit_chance"},
	{"key": "crit_damage_mult", "label_key": &"stat_crit_damage", "color": Color(0.95, 0.3, 0.3), "icon_key": &"stat_crit_damage"},
	{"key": "cooldown_reduction", "label_key": &"stat_cd", "color": Color(1.0, 0.9, 0.3), "icon_key": &"stat_cd"},
	{"key": "spell_duration_mult", "label_key": &"stat_spell_duration", "color": Color(0.6, 0.8, 1.0), "icon_key": &"stat_spell_duration"},
	{"key": "projectile_speed_mult", "label_key": &"stat_proj_speed", "color": Color(0.5, 0.75, 1.0), "icon_key": &"stat_proj_speed"},
	{"key": "area_multiplier", "label_key": &"stat_area", "color": Color(1.0, 0.6, 0.25), "icon_key": &"stat_area"},
	{"key": "pickup_range", "label_key": &"stat_pickup", "color": Color(0.5, 0.65, 0.95), "icon_key": &"stat_pickup"},
	{"key": "mana_gain", "label_key": &"stat_mana_gain", "color": Color(0.4, 0.85, 0.95), "icon_key": &"stat_mana_gain"},
	{"key": "life_steal", "label_key": &"stat_life_steal", "color": Color(0.85, 0.25, 0.35), "icon_key": &"stat_life_steal"},
	{"key": "enemy_max_hp_mult", "label_key": &"stat_enemy_hp", "color": Color(0.75, 0.5, 0.85), "icon_key": &"stat_enemy_hp"},
]

var _upgrade_buttons: Dictionary = {}
var _level_labels: Dictionary = {}
var _cost_labels: Dictionary = {}
var _currency_label: Label = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _back_btn: Button = null
var _reset_btn: Button = null
var _confirm_panel: PanelContainer = null
var _confirm_visible: bool = false
var _refund_label: Label = null

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
	panel.add_theme_constant_override("separation", 8)
	center.add_child(panel)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"inner_power_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", GREEN)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	panel.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = SettingsManager.t(&"inner_power_subtitle")
	_subtitle_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	_subtitle_label.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.45))
	panel.add_child(_subtitle_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(500, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ornament)

	_currency_label = Label.new()
	_currency_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_size_override("font_size", SettingsManager.font_size(22))
	_currency_label.add_theme_color_override("font_color", GOLD)
	_currency_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_currency_label.add_theme_constant_override("shadow_offset_x", 1)
	_currency_label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(_currency_label)

	_refund_label = Label.new()
	_refund_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_refund_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_refund_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_refund_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_refund_label.add_theme_constant_override("shadow_offset_x", 1)
	_refund_label.add_theme_constant_override("shadow_offset_y", 1)
	_refund_label.visible = false
	panel.add_child(_refund_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	panel.add_child(spacer)

	for def: Dictionary in STAT_DEFS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var key: String = def["key"]
		var col: Color = def["color"]

		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_key: StringName = def.get("icon_key", &"")
		if icon_key != &"" and STAT_ICON_PATHS.has(icon_key):
			var path: String = STAT_ICON_PATHS[icon_key]
			if ResourceLoader.exists(path):
				icon.texture = load(path)
		row.add_child(icon)

		var lbl := Label.new()
		lbl.text = SettingsManager.t(def["label_key"])
		lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
		lbl.add_theme_color_override("font_color", col)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.custom_minimum_size.x = 160
		lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lbl)

		var stars := Label.new()
		stars.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
		stars.add_theme_color_override("font_color", GOLD)
		stars.custom_minimum_size.x = 110
		stars.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(stars)
		_level_labels[key] = stars

		var cost_lbl := Label.new()
		cost_lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
		cost_lbl.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
		cost_lbl.custom_minimum_size.x = 90
		cost_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cost_lbl)
		_cost_labels[key] = cost_lbl

		var btn := Button.new()
		btn.text = "▲"
		btn.custom_minimum_size = Vector2(46, 36)
		btn.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
		btn.add_theme_color_override("font_color", GREEN)
		btn.add_theme_color_override("font_hover_color", Color(min(GREEN.r + 0.3, 1.0), min(GREEN.g + 0.3, 1.0), min(GREEN.b + 0.3, 1.0)))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.9))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(GREEN.r * 0.05, GREEN.g * 0.05, GREEN.b * 0.05, 0.8)
		style.set_corner_radius_all(CORNER)
		style.set_border_width_all(BORDER_W)
		style.border_color = Color(GREEN.r * 0.35, GREEN.g * 0.35, GREEN.b * 0.35, 0.5)
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(GREEN.r * 0.12, GREEN.g * 0.12, GREEN.b * 0.12, 0.85)
		hover.border_color = Color(GREEN.r * 0.6, GREEN.g * 0.6, GREEN.b * 0.6, 0.8)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(_on_upgrade.bind(key))
		row.add_child(btn)
		_upgrade_buttons[key] = btn

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	panel.add_child(spacer2)

	_back_btn = _make_button(SettingsManager.t(&"btn_return"), GOLD)
	_back_btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"); close_requested.emit())
	panel.add_child(_back_btn)

	_reset_btn = _make_button(SettingsManager.t(&"btn_reset_upgrades"), Color(0.85, 0.35, 0.35))
	_reset_btn.pressed.connect(_on_reset_pressed)
	panel.add_child(_reset_btn)

	_build_confirm_dialog()
	_show_confirm_dialog(false)

	_refresh_all()

func _refresh_all() -> void:
	if _currency_label:
		_currency_label.text = SettingsManager.t(&"vault_label") + ": " + str(UpgradeManager.persistent_currency)
	if _refund_label:
		_refund_label.visible = false
	for def: Dictionary in STAT_DEFS:
		var key: String = def["key"]
		var level: int = UpgradeManager.get_upgrade_level(key)
		var stars_text := ""
		for i in range(MAX_LEVEL):
			if i < level:
				stars_text += "★"
			else:
				stars_text += "☆"
		if _level_labels.has(key):
			var lbl: Label = _level_labels[key]
			lbl.text = stars_text
		if _cost_labels.has(key):
			var cost_lbl: Label = _cost_labels[key]
			if level >= MAX_LEVEL:
				cost_lbl.text = SettingsManager.t(&"upgrade_max")
				cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.5))
			else:
				cost_lbl.text = str(UpgradeManager.get_upgrade_cost(key, level))
				cost_lbl.add_theme_color_override("font_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
		if _upgrade_buttons.has(key):
			var btn: Button = _upgrade_buttons[key]
			var cost: int = UpgradeManager.get_upgrade_cost(key, level)
			btn.disabled = level >= MAX_LEVEL or UpgradeManager.persistent_currency < cost
			btn.add_theme_color_override("font_color", GREEN if not btn.disabled else Color(0.3, 0.3, 0.3, 0.4))

func _on_upgrade(key: String) -> void:
	if UpgradeManager.purchase_upgrade(key):
		SoundManager.play_sound("button_click")
		_refresh_all()

func _on_reset_pressed() -> void:
	var has_upgrades: bool = false
	for def: Dictionary in STAT_DEFS:
		if UpgradeManager.get_upgrade_level(def["key"]) > 0:
			has_upgrades = true
			break
	if not has_upgrades:
		return
	_show_confirm_dialog(true)

func _build_confirm_dialog() -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.offset_left = -160
	_confirm_panel.offset_top = -80
	_confirm_panel.offset_right = 160
	_confirm_panel.offset_bottom = 80
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.02, 0.06, 0.96)
	panel_style.set_corner_radius_all(8)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.85, 0.35, 0.35, 0.7)
	_confirm_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_confirm_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(vbox)

	var title := Label.new()
	title.text = SettingsManager.t(&"reset_confirm_title")
	title.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	title.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = SettingsManager.t(&"reset_confirm_desc")
	desc.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	desc.add_theme_color_override("font_color", Color(0.7, 0.65, 0.75, 0.8))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 280
	vbox.add_child(desc)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var cancel_btn := _make_button(SettingsManager.t(&"btn_cancel_reset"), Color(0.5, 0.5, 0.55))
	cancel_btn.custom_minimum_size = Vector2(130, 40)
	cancel_btn.pressed.connect(_show_confirm_dialog.bind(false))
	hbox.add_child(cancel_btn)

	var confirm_btn := _make_button(SettingsManager.t(&"btn_confirm_reset"), Color(0.85, 0.35, 0.35))
	confirm_btn.custom_minimum_size = Vector2(130, 40)
	confirm_btn.pressed.connect(_on_reset_confirm)
	hbox.add_child(confirm_btn)

func _show_confirm_dialog(show: bool) -> void:
	_confirm_visible = show
	if _confirm_panel:
		_confirm_panel.visible = show

func _on_reset_confirm() -> void:
	var refund: int = UpgradeManager.reset_all_upgrades()
	SoundManager.play_sound("button_click")
	_show_confirm_dialog(false)
	_refresh_all()
	if _refund_label:
		_refund_label.text = SettingsManager.t(&"reset_done") % refund
		_refund_label.visible = true

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _confirm_visible:
			_show_confirm_dialog(false)
		else:
			close_requested.emit()
		get_viewport().set_input_as_handled()

func _refresh_texts() -> void:
	if _title_label:
		_title_label.text = SettingsManager.t(&"inner_power_title")
	if _subtitle_label:
		_subtitle_label.text = SettingsManager.t(&"inner_power_subtitle")
	if _back_btn:
		_back_btn.text = SettingsManager.t(&"btn_return")
	if _reset_btn:
		_reset_btn.text = SettingsManager.t(&"btn_reset_upgrades")
	_refresh_all()

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

class _OrnamentLine extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var line_w := w * 0.35
		var cx := w * 0.5
		var col := Color(0.4, 0.7, 0.5, 0.3)
		draw_line(Vector2(cx - line_w, y), Vector2(cx - 8, y), col, 1.0, true)
		draw_line(Vector2(cx + 8, y), Vector2(cx + line_w, y), col, 1.0, true)
		draw_circle(Vector2(cx - 8, y), 2.0, Color(0.5, 0.8, 0.6, 0.4))
		draw_circle(Vector2(cx + 8, y), 2.0, Color(0.5, 0.8, 0.6, 0.4))
		draw_circle(Vector2(cx, y), 1.5, Color(0.5, 0.8, 0.6, 0.5))
