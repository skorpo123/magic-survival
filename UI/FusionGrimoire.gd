class_name FusionGrimoire extends Control

const BG_COLOR := Color(0.04, 0.025, 0.065, 1.0)
const CARD_BG := Color(0.08, 0.055, 0.12, 0.95)
const CARD_BORDER := Color(0.25, 0.18, 0.35, 0.7)
const FUSION_COLOR := Color(0.95, 0.65, 0.2)
const TEXT_COL := Color(0.82, 0.78, 0.88)
const DIM_COLOR := Color(0.5, 0.45, 0.6)
const BUFF_COLOR := Color(0.4, 0.82, 0.55)
const DEBUFF_COLOR := Color(0.88, 0.32, 0.32)
const ACCENT := Color(0.55, 0.35, 0.8)
const GOLD := Color(0.8, 0.65, 0.3)
const CORNER := 6
const BORDER_W := 1
const CARD_W := 280.0
const CARD_H := 420.0
const GRID_COLUMNS_MAX := 4
const GRID_COLUMNS_MIN := 2
const CARD_GAP := 20.0

var _close_btn: Button
var _scroll: ScrollContainer
var _content: GridContainer
var _detail_overlay: Control
var _recipes: Array[Dictionary] = []
var _title_label: Label

static var is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	is_open = true
	_setup_ui()
	_load_recipes()
	_populate_grid()
	_update_columns()
	get_tree().root.size_changed.connect(_on_viewport_resized)
	GameManager.pause_game()
	grab_focus()

func _exit_tree() -> void:
	is_open = false
	if get_tree() and get_tree().root:
		if get_tree().root.size_changed.is_connected(_on_viewport_resized):
			get_tree().root.size_changed.disconnect(_on_viewport_resized)
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.resume_game()

func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp_size := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_title_label.text = SettingsManager.t(&"card_fusion")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", FUSION_COLOR)
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

	_content = GridContainer.new()
	_content.columns = GRID_COLUMNS_MAX
	_content.add_theme_constant_override("h_separation", int(CARD_GAP))
	_content.add_theme_constant_override("v_separation", int(CARD_GAP))
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_center.add_child(_content)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 18
	panel.add_child(spacer2)

	var btn_center := CenterContainer.new()
	panel.add_child(btn_center)

	_close_btn = Button.new()
	_close_btn.text = SettingsManager.t(&"btn_return")
	_close_btn.custom_minimum_size = Vector2(280, 52)
	_close_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_close_btn.add_theme_color_override("font_color", GOLD)
	_close_btn.add_theme_color_override("font_hover_color", Color(min(GOLD.r + 0.3, 1.0), min(GOLD.g + 0.3, 1.0), min(GOLD.b + 0.3, 1.0)))
	_close_btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 0.9))
	_close_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_close_btn.add_theme_constant_override("shadow_offset_x", 1)
	_close_btn.add_theme_constant_override("shadow_offset_y", 1)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(GOLD.r * 0.05, GOLD.g * 0.05, GOLD.b * 0.05, 0.8)
	btn_style.set_corner_radius_all(CORNER)
	btn_style.set_border_width_all(BORDER_W)
	btn_style.border_color = Color(GOLD.r * 0.35, GOLD.g * 0.35, GOLD.b * 0.35, 0.5)
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	_close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(GOLD.r * 0.12, GOLD.g * 0.12, GOLD.b * 0.12, 0.85)
	btn_hover.border_color = Color(GOLD.r * 0.6, GOLD.g * 0.6, GOLD.b * 0.6, 0.8)
	_close_btn.add_theme_stylebox_override("hover", btn_hover)
	_close_btn.pressed.connect(_on_close)
	btn_center.add_child(_close_btn)

	_detail_overlay = Control.new()
	_detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.visible = false
	_detail_overlay.z_index = 10
	add_child(_detail_overlay)

func _load_recipes() -> void:
	var fusion_manager := get_node_or_null("/root/SpellFusionManager")
	if not fusion_manager or not fusion_manager.has_method("get_all_recipes"):
		return
	_recipes = fusion_manager.get_all_recipes()

func _populate_grid() -> void:
	for child in _content.get_children():
		child.queue_free()
	for recipe in _recipes:
		_content.add_child(_create_card(recipe))

func _create_card(recipe: Dictionary) -> PanelContainer:
	var border_col: Color = recipe.get("color", CARD_BORDER)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var cs := StyleBoxFlat.new()
	cs.bg_color = CARD_BG
	cs.border_color = border_col
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(CORNER)
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	cs.content_margin_top = 14
	cs.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", cs)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(144, 144)
	sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = recipe.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	vbox.add_child(sprite)

	var name_label := Label.new()
	var lang: String = SettingsManager._lang if SettingsManager else "ru"
	var name_key := "tr_name_ru" if lang == "ru" else "tr_name_en"
	name_label.text = recipe.get(name_key, recipe.get("tr_name_en", "???"))
	name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", FUSION_COLOR)
	name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_label)

	var main_id: StringName = recipe.get("main_id", &"")
	var secondary_id: StringName = recipe.get("secondary_id", &"")
	var main_mod: StringName = recipe.get("main_mod_id", &"")
	var sec_mod: StringName = recipe.get("secondary_mod_id", &"")
	var main_name := SettingsManager.t(&"spell_" + String(main_id))
	var sec_name := SettingsManager.t(&"spell_" + String(secondary_id))
	var main_mod_name := _get_mod_tr(main_mod)
	var sec_mod_name := _get_mod_tr(sec_mod)

	var combo := Label.new()
	combo.text = "%s (%s)\n+ %s (%s)" % [main_name, main_mod_name, sec_name, sec_mod_name]
	combo.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	combo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combo.add_theme_color_override("font_color", Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, 0.7))
	combo.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	vbox.add_child(combo)

	var desc := Label.new()
	desc.text = recipe.get("desc", "")
	desc.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.75))
	desc.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	var gui_event := Callable(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(recipe)
	)
	card.gui_input.connect(gui_event)

	return card

func _show_detail(recipe: Dictionary) -> void:
	for child in _detail_overlay.get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail_overlay.add_child(center)

	var dpanel := PanelContainer.new()
	dpanel.custom_minimum_size = Vector2(520, 0)
	dpanel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dpanel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.09, 0.98)
	ps.border_color = recipe.get("color", CARD_BORDER)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.content_margin_left = 24
	ps.content_margin_right = 24
	ps.content_margin_top = 20
	ps.content_margin_bottom = 20
	dpanel.add_theme_stylebox_override("panel", ps)
	center.add_child(dpanel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	dpanel.add_child(vbox)

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(close_row)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	close_btn.pressed.connect(_hide_detail)
	close_row.add_child(close_btn)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(144, 144)
	sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path_d: String = recipe.get("icon_path", "")
	if icon_path_d != "" and ResourceLoader.exists(icon_path_d):
		sprite.texture = load(icon_path_d)
	vbox.add_child(sprite)

	var lang: String = SettingsManager._lang if SettingsManager else "ru"
	var name_key := "tr_name_ru" if lang == "ru" else "tr_name_en"
	var name_label := Label.new()
	name_label.text = recipe.get(name_key, recipe.get("tr_name_en", "???"))
	name_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", FUSION_COLOR)
	name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(24))
	vbox.add_child(name_label)

	var main_id_d: StringName = recipe.get("main_id", &"")
	var secondary_id_d: StringName = recipe.get("secondary_id", &"")
	var main_mod_d: StringName = recipe.get("main_mod_id", &"")
	var sec_mod_d: StringName = recipe.get("secondary_mod_id", &"")
	var main_name_d := SettingsManager.t(&"spell_" + String(main_id_d))
	var sec_name_d := SettingsManager.t(&"spell_" + String(secondary_id_d))
	var main_mod_name_d := _get_mod_tr(main_mod_d)
	var sec_mod_name_d := _get_mod_tr(sec_mod_d)

	var combo := Label.new()
	combo.text = "%s (%s) + %s (%s)" % [main_name_d, main_mod_name_d, sec_name_d, sec_mod_name_d]
	combo.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	combo.add_theme_color_override("font_color", Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, 0.7))
	combo.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	combo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(combo)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separator", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2))
	vbox.add_child(sep1)

	var desc := Label.new()
	desc.text = recipe.get("desc", "")
	desc.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.9))
	desc.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var buffs: Array = recipe.get("buffs", [])
	var debuffs: Array = recipe.get("debuffs", [])

	if buffs.size() > 0 or debuffs.size() > 0:
		var sep2 := HSeparator.new()
		sep2.add_theme_color_override("separator", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15))
		vbox.add_child(sep2)

	for buff_text in buffs:
		var bl := Label.new()
		bl.text = "+ " + buff_text
		bl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		bl.add_theme_color_override("font_color", BUFF_COLOR)
		bl.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(bl)

	for debuff_text in debuffs:
		var dl := Label.new()
		dl.text = "- " + debuff_text
		dl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		dl.add_theme_color_override("font_color", DEBUFF_COLOR)
		dl.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(dl)

	_detail_overlay.visible = true

func _hide_detail() -> void:
	_detail_overlay.visible = false
	for child in _detail_overlay.get_children():
		child.queue_free()

func _get_mod_tr(mod_id: StringName) -> String:
	var generic_key := _mod_id_to_generic_key(mod_id)
	var tr_key := &"mod_" + generic_key
	var translated := SettingsManager.t(tr_key)
	if translated != "" and translated != String(tr_key):
		return translated
	var mod_name := String(mod_id)
	var parts := mod_name.split("_")
	if parts.size() > 1:
		parts.remove_at(0)
	return " ".join(parts).capitalize()

func _mod_id_to_generic_key(mod_id: StringName) -> String:
	match mod_id:
		&"fireball_meteor": return "mega_explosion"
		&"fireball_split": return "split_fireball"
		&"fireball_pierce": return "piercing_blaze"
		&"lightning_strike_rapid": return "thunderstorm"
		&"lightning_strike_chain": return "chain_amplifier"
		&"cyclone_twin": return "tempest"
		&"cyclone_gravity": return "tornado"
		&"cyclone_gale": return "gale_force"
		&"electric_zone_chain": return "chain_field"
		&"shield_refraction": return "refraction_shield_mod"
		&"orbiting_arcana_cross": return "multiplicity"
		&"orbiting_arcana_vortex": return "wide_orbit"
		&"orbiting_arcana_blade": return "acceleration"
		&"spirit_phantom": return "phantom"
		&"spirit_blades": return "phantom_blades"
		&"spirit_wraith": return "wraith"
		&"fire_breath_ash": return "burning_ash"
		&"poison_pool_bloom": return "toxic_bloom"
		&"poison_pool_plague": return "plague"
		&"frost_nova_permafrost": return "permafrost"
		&"magic_bolt_storm": return "magic_missile_storm"
		_: return String(mod_id)

func _on_viewport_resized() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	size = vp_size
	_update_columns()

func _update_columns() -> void:
	if not _content:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var margin_h := 80.0 * 2.0
	var available_w := vp_size.x - margin_h
	var cols := int(available_w / (CARD_W + CARD_GAP))
	cols = clampi(cols, GRID_COLUMNS_MIN, GRID_COLUMNS_MAX)
	if _content.columns != cols:
		_content.columns = cols

func _on_close() -> void:
	queue_free()

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _detail_overlay.visible:
				_hide_detail()
				get_viewport().set_input_as_handled()
			else:
				_on_close()
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
