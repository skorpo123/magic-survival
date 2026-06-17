class_name ArtifactSlotsScreen extends Control

signal close_requested

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const CORNER := 6
const BORDER_W := 1
const SLOT_COLUMNS: int = 8
const SLOT_SIZE := Vector2(132, 168)

const RARITY_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6),
	1: Color(0.3, 0.8, 0.4),
	2: Color(0.3, 0.6, 1.0),
	3: Color(0.9, 0.7, 0.2),
}

var _title_label: Label = null
var _back_btn: Button = null
var _slots_host: GridContainer = null
var _empty_label: Label = null

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
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	margin.add_child(panel)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"artifact_slots_title")
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

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	panel.add_child(spacer)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(grid_center)

	_slots_host = GridContainer.new()
	_slots_host.columns = SLOT_COLUMNS
	_slots_host.add_theme_constant_override("h_separation", 10)
	_slots_host.add_theme_constant_override("v_separation", 10)
	_slots_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_center.add_child(_slots_host)

	_empty_label = Label.new()
	_empty_label.text = SettingsManager.t(&"artifact_empty")
	_empty_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_empty_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.55))
	_empty_label.visible = false
	panel.add_child(_empty_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 18
	panel.add_child(spacer2)

	_back_btn = _make_button(SettingsManager.t(&"btn_return"), GOLD)
	_back_btn.pressed.connect(func() -> void: SoundManager.play_sound("button_click"); close_requested.emit())
	var btn_center := CenterContainer.new()
	btn_center.add_child(_back_btn)
	panel.add_child(btn_center)

	refresh()

func _make_artifact_card(artifact: ArtifactData) -> PanelContainer:
	var rarity: int = artifact.rarity if "rarity" in artifact else 0

	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var col: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r * 0.10, col.g * 0.10, col.b * 0.15, 0.7)
	style.border_color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.7)
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.set_corner_radius_all(CORNER)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(col.r * 0.05, col.g * 0.05, col.b * 0.08, 0.3)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(glow)
	panel.move_child(glow, 0)

	var stars := Label.new()
	stars.text = "★".repeat(rarity + 1)
	stars.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	stars.add_theme_color_override("font_color", col)
	stars.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	stars.add_theme_constant_override("shadow_offset_x", 1)
	stars.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(stars)

	var name_lbl := Label.new()
	var art_name: String = ""
	if artifact.name_key != &"":
		art_name = SettingsManager.t(artifact.name_key)
	else:
		art_name = artifact.artifact_name
	name_lbl.text = art_name
	name_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.custom_minimum_size.y = 36
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	var art_desc: String = ""
	if artifact.desc_key != &"":
		art_desc = SettingsManager.t(artifact.desc_key)
	else:
		art_desc = artifact.description
	desc_lbl.text = art_desc
	desc_lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(11))
	desc_lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.85))
	desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	desc_lbl.add_theme_constant_override("shadow_offset_x", 1)
	desc_lbl.add_theme_constant_override("shadow_offset_y", 1)
	desc_lbl.custom_minimum_size.y = 48
	desc_lbl.clip_text = true
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	return panel

func refresh() -> void:
	if not _slots_host:
		return
	for child in _slots_host.get_children():
		child.queue_free()

	var equipped: Array[ArtifactData] = ArtifactManager.equipped
	_empty_label.visible = equipped.is_empty()
	_slots_host.visible = not equipped.is_empty()

	for art in equipped:
		_slots_host.add_child(_make_artifact_card(art))

func _refresh_texts() -> void:
	if _title_label:
		_title_label.text = SettingsManager.t(&"artifact_slots_title")
	if _back_btn:
		_back_btn.text = SettingsManager.t(&"btn_return")
	refresh()

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
