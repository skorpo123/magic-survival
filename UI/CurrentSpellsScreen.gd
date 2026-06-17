class_name CurrentSpellsScreen extends Control

signal close_requested

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const VIOLET := Color(0.5, 0.3, 0.8)
const CORNER := 6
const BORDER_W := 1
const CARD_W := 198.0
const CARD_H := 252.0

var _title_label: Label
var _spells_container: GridContainer
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

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"spells_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(_title_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(500, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ornament)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)

	_spells_container = GridContainer.new()
	_spells_container.columns = 8
	_spells_container.add_theme_constant_override("h_separation", 10)
	_spells_container.add_theme_constant_override("v_separation", 10)
	grid_center.add_child(_spells_container)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 16
	vbox.add_child(spacer2)

	_back_btn = _make_button(SettingsManager.t(&"btn_return"), GOLD)
	_back_btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"); close_requested.emit())
	var btn_center := CenterContainer.new()
	btn_center.add_child(_back_btn)
	vbox.add_child(btn_center)

func show_spells() -> void:
	_refresh_spells()

func _refresh_spells() -> void:
	for child in _spells_container.get_children():
		child.queue_free()

	var manager := _find_level_up_manager()
	if not manager:
		var empty_label := Label.new()
		empty_label.text = SettingsManager.t(&"spells_empty")
		empty_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.55))
		empty_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		_spells_container.add_child(empty_label)
		return

	for spell_id: StringName in manager._owned_spells:
		var spell: Spell = manager._owned_spells[spell_id]
		_spells_container.add_child(_make_spell_card(spell))

func _make_spell_card(spell: Spell) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
	panel.size = Vector2(CARD_W, CARD_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	style.set_corner_radius_all(CORNER)
	style.set_border_width_all(BORDER_W)
	style.border_color = Color(0.35, 0.3, 0.4, 0.3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if spell.icon:
		icon.texture = spell.icon
	vbox.add_child(icon)

	var name_label := Label.new()
	var spell_name_tr := SettingsManager.t(&"spell_" + String(spell.spell_id))
	name_label.text = spell_name_tr
	name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
	name_label.add_theme_color_override("font_color", TEXT_COL)
	vbox.add_child(name_label)

	var level_label := Label.new()
	level_label.text = _make_level_dots(spell.current_level, spell.max_level)
	level_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	level_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.68))
	vbox.add_child(level_label)

	if spell.active_modification:
		var mod_label := Label.new()
		var mod_name_tr := spell.active_modification.mod_name
		mod_label.text = "◈ %s" % mod_name_tr
		mod_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
		mod_label.add_theme_color_override("font_color", VIOLET)
		vbox.add_child(mod_label)

	return panel

func _make_level_dots(current: int, max_lvl: int) -> String:
	var dots := ""
	for i in range(max_lvl):
		if i < current:
			dots += "●"
		else:
			dots += "○"
	return "Lv.%d  %s" % [current, dots]

func _find_level_up_manager() -> LevelUpManager:
	var nodes := get_tree().get_nodes_in_group("level_up_manager")
	if nodes.size() > 0:
		return nodes[0] as LevelUpManager
	return null

func _refresh_texts() -> void:
	if _title_label:
		_title_label.text = SettingsManager.t(&"spells_title")
	if _back_btn:
		_back_btn.text = SettingsManager.t(&"btn_return")

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
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(accent.r * 0.05, accent.g * 0.05, accent.b * 0.05, 0.8)
	btn_style.set_corner_radius_all(CORNER)
	btn_style.set_border_width_all(BORDER_W)
	btn_style.border_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.5)
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", btn_style)
	var hover := btn_style.duplicate()
	hover.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.85)
	hover.border_color = Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

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
