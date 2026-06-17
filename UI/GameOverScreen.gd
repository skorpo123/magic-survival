class_name GameOverScreen extends Control

const BG_COLOR := Color(0.012, 0.008, 0.022, 1.0)
const GOLD := Color(0.8, 0.65, 0.3)
const TEXT_COL := Color(0.85, 0.82, 0.92)
const CRIMSON := Color(0.7, 0.15, 0.15)
const VIOLET := Color(0.5, 0.3, 0.8)
const CORNER := 6
const BORDER_W := 1
const BAR_HEIGHT := 28
const BAR_BG := Color(0.12, 0.10, 0.16, 0.7)
const CONTENT_WIDTH := 680
const FADE_DURATION := 0.3
const FADE_STAGGER := 0.1

var _title_label: Label
var _menu_btn: Button
var _restart_btn: Button
var _pulse_t: float = 0.0
var _sections: Array[Control] = []
var _fade_elapsed: float = 0.0
var _fading: bool = false
var _stat_values: Dictionary = {}
var _stat_labels: Dictionary = {}

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

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = CONTENT_WIDTH
	content.add_theme_constant_override("separation", 0)
	center.add_child(content)

	_build_title(content)
	_add_spacer(content, 8)
	_build_stats_grid(content)
	_add_spacer(content, 16)
	_build_damage_section(content)
	_add_spacer(content, 12)
	_build_kills_section(content)
	_add_spacer(content, 12)
	_build_highlights(content)
	_add_spacer(content, 24)
	_build_buttons(content)
	_add_spacer(content, 30)

func _build_title(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 80
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.content_margin_top = 16
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var center := CenterContainer.new()
	panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"run_summary_title")
	_title_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(36))
	_title_label.add_theme_color_override("font_color", CRIMSON)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_title_label)

	var ornament := _OrnamentLine.new()
	ornament.custom_minimum_size = Vector2(400, 10)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(ornament)

	_register_section(panel)

func _build_stats_grid(parent: Control) -> void:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 8)
	wrapper.add_child(grid)

	_add_stat_cell(grid, &"run_summary_time", &"time_value", "")
	_add_stat_cell(grid, &"stat_level", &"level_value", "")
	_add_stat_cell(grid, &"run_summary_kills", &"kills_value", "")
	_add_stat_cell(grid, &"earned_currency", &"earned_value", "")
	_add_stat_cell(grid, &"run_summary_combo", &"combo_value", "")
	_add_stat_cell(grid, &"total_vault", &"vault_value", "")

	_register_section(wrapper)

func _add_stat_cell(parent: Control, label_key: StringName, value_name: StringName, _default_val: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.custom_minimum_size.x = 320
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = SettingsManager.t(label_key)
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(17))
	lbl.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.65))
	hbox.add_child(lbl)
	_stat_labels[value_name] = lbl

	var val := Label.new()
	val.name = String(value_name)
	val.text = _default_val
	val.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_size_override("font_size", SettingsManager.font_size(17))
	val.add_theme_color_override("font_color", GOLD)
	hbox.add_child(val)
	_stat_values[value_name] = val

func _build_section_header(parent: Control, title_key: StringName) -> VBoxContainer:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.custom_minimum_size.x = CONTENT_WIDTH - 100
	outer_vbox.add_theme_constant_override("separation", 6)
	wrapper.add_child(outer_vbox)

	var header := Label.new()
	header.text = SettingsManager.t(title_key)
	header.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
	header.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.5))
	outer_vbox.add_child(header)

	return outer_vbox

func _build_damage_section(parent: Control) -> void:
	var outer_vbox := _build_section_header(parent, &"run_summary_damage")

	var bars_container := VBoxContainer.new()
	bars_container.name = "DamageBars"
	bars_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(bars_container)

	_register_section(outer_vbox.get_parent())

func _build_kills_section(parent: Control) -> void:
	var outer_vbox := _build_section_header(parent, &"run_summary_kills")

	var bars_container := VBoxContainer.new()
	bars_container.name = "KillsBars"
	bars_container.add_theme_constant_override("separation", 3)
	outer_vbox.add_child(bars_container)

	_register_section(outer_vbox.get_parent())

func _build_highlights(parent: Control) -> void:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size.x = CONTENT_WIDTH - 100
	vbox.add_theme_constant_override("separation", 8)
	wrapper.add_child(vbox)

	var strongest_label := Label.new()
	strongest_label.name = "StrongestLabel"
	strongest_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	strongest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strongest_label.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	strongest_label.add_theme_color_override("font_color", GOLD)
	vbox.add_child(strongest_label)

	var art_header := Label.new()
	art_header.text = SettingsManager.t(&"run_summary_artifacts")
	art_header.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	art_header.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	art_header.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.5))
	vbox.add_child(art_header)

	var art_container := HBoxContainer.new()
	art_container.name = "ArtifactsContainer"
	art_container.alignment = BoxContainer.ALIGNMENT_CENTER
	art_container.add_theme_constant_override("separation", 8)
	vbox.add_child(art_container)

	_register_section(wrapper)

func _build_buttons(parent: Control) -> void:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	wrapper.add_child(hbox)

	_restart_btn = _make_button(SettingsManager.t(&"btn_restart_run"), GOLD)
	_restart_btn.pressed.connect(_on_restart)
	hbox.add_child(_restart_btn)

	_menu_btn = _make_button(SettingsManager.t(&"btn_main_menu"), VIOLET)
	_menu_btn.pressed.connect(_on_menu)
	hbox.add_child(_menu_btn)

	_register_section(wrapper)

func _make_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 48)
	btn.add_theme_font_size_override("font_size", SettingsManager.font_size(17))
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

func _add_spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)

func _register_section(section: Control) -> void:
	_sections.append(section)
	section.modulate.a = 0.0

func show_game_over() -> void:
	visible = true
	_fade_elapsed = 0.0
	_fading = true
	_refresh_stats()

func _process(delta: float) -> void:
	if visible:
		_pulse_t += delta
		var pulse := 0.6 + 0.15 * sin(_pulse_t * 2.0)
		_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.2, pulse * 0.2))

	if _fading:
		_fade_elapsed += delta
		for i in range(_sections.size()):
			var delay: float = i * FADE_STAGGER
			var t: float = clampf((_fade_elapsed - delay) / FADE_DURATION, 0.0, 1.0)
			_sections[i].modulate.a = _ease_out(t)
		if _fade_elapsed >= _sections.size() * FADE_STAGGER + FADE_DURATION:
			_fading = false

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"run_summary_title")
	_restart_btn.text = SettingsManager.t(&"btn_restart_run")
	_menu_btn.text = SettingsManager.t(&"btn_main_menu")
	var label_keys: Dictionary = {
		&"time_value": &"run_summary_time",
		&"kills_value": &"run_summary_kills",
		&"level_value": &"stat_level",
		&"earned_value": &"earned_currency",
		&"combo_value": &"run_summary_combo",
		&"vault_value": &"total_vault",
	}
	for key in label_keys:
		if _stat_labels.has(key):
			_stat_labels[key].text = SettingsManager.t(label_keys[key])

func _refresh_stats() -> void:
	_stat_values[&"time_value"].text = GameManager.format_time()
	_stat_values[&"kills_value"].text = str(RunTracker.get_total_kills())
	_stat_values[&"level_value"].text = str(GameManager.current_level)
	_stat_values[&"earned_value"].text = str(GameManager._last_run_currency)
	_stat_values[&"combo_value"].text = "×" + str(RunTracker.max_combo)
	_stat_values[&"vault_value"].text = str(UpgradeManager.persistent_currency)

	_populate_damage_bars()
	_populate_kills_bars()
	_populate_highlights()

func _populate_damage_bars() -> void:
	var wrapper: CenterContainer = _sections[2]
	var outer_vbox: VBoxContainer = wrapper.get_child(0)
	var container: VBoxContainer = outer_vbox.get_node("DamageBars")
	_clear_container(container)

	var spell_dmg := RunTracker.get_sorted_spell_damage()
	if spell_dmg.is_empty():
		_add_no_data(container)
		return

	var total_dmg: float = RunTracker.total_damage_dealt
	for entry in spell_dmg:
		var pct: float = 0.0
		if total_dmg > 0.0:
			pct = entry["damage"] / total_dmg * 100.0
		var spell_key := &"spell_" + String(entry["id"]).to_lower()
		var spell_name := SettingsManager.t(spell_key)
		if spell_name == String(spell_key):
			spell_name = String(entry["id"]).replace("_", " ").capitalize()
		var color := _get_spell_color(entry["id"])
		container.add_child(_make_bar(spell_name, pct, color, true))

func _populate_kills_bars() -> void:
	var wrapper: CenterContainer = _sections[3]
	var outer_vbox: VBoxContainer = wrapper.get_child(0)
	var container: VBoxContainer = outer_vbox.get_node("KillsBars")
	_clear_container(container)

	var kills := RunTracker.kills_by_type
	if kills.is_empty():
		_add_no_data(container)
		return

	var sorted_kills: Array = []
	for k in kills.keys():
		sorted_kills.append({key = k, val = kills[k]})
	sorted_kills.sort_custom(func(a, b) -> bool: return a.val > b.val)

	var max_kill: int = 0
	for entry in sorted_kills:
		if entry.val > max_kill:
			max_kill = entry.val

	for entry in sorted_kills:
		var type_key := &"enemy_" + String(entry.key).to_lower()
		var type_name := SettingsManager.t(type_key)
		if type_name == String(type_key):
			type_name = String(entry.key).replace("_", " ").capitalize()
		var pct: float = float(entry.val) / float(max_kill) * 100.0 if max_kill > 0 else 0.0
		var color := _get_enemy_color(entry.key)
		container.add_child(_make_kill_bar(type_name, entry.val, pct, color))

func _populate_highlights() -> void:
	var highlights_section := _sections[4]
	var wrapper: CenterContainer = highlights_section
	var vbox: VBoxContainer = wrapper.get_child(0)

	var strongest_label: Label = vbox.get_node("StrongestLabel")
	var strongest := RunTracker.strongest_spell_id
	if strongest != &"":
		var spell_key := &"spell_" + String(strongest).to_lower()
		var spell_name := SettingsManager.t(spell_key)
		if spell_name == String(spell_key):
			spell_name = String(strongest).replace("_", " ").capitalize()
		strongest_label.text = SettingsManager.t(&"run_summary_strongest") + ":  " + spell_name
		strongest_label.visible = true
	else:
		strongest_label.visible = false

	var art_container: HBoxContainer = vbox.get_node("ArtifactsContainer")
	_clear_container(art_container)
	var artifacts := RunTracker.artifacts_collected
	if artifacts.is_empty():
		var no_data := Label.new()
		no_data.text = SettingsManager.t(&"run_summary_no_data")
		no_data.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
		no_data.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.35))
		art_container.add_child(no_data)
	else:
		for art in artifacts:
			var badge := Label.new()
			if art is ArtifactData:
				var art_name: String = art.artifact_name
				if art.name_key != &"":
					var localized := SettingsManager.t(art.name_key)
					if localized != String(art.name_key):
						art_name = localized
				badge.text = art_name
			else:
				badge.text = str(art)
			badge.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
			badge.add_theme_color_override("font_color", GOLD)
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = Color(GOLD.r * 0.08, GOLD.g * 0.08, GOLD.b * 0.08, 0.6)
			badge_style.set_corner_radius_all(4)
			badge_style.set_border_width_all(1)
			badge_style.border_color = Color(GOLD.r * 0.3, GOLD.g * 0.3, GOLD.b * 0.3, 0.5)
			badge_style.content_margin_left = 8
			badge_style.content_margin_right = 8
			badge_style.content_margin_top = 3
			badge_style.content_margin_bottom = 3
			badge.add_theme_stylebox_override("normal", badge_style)
			art_container.add_child(badge)

func _make_bar(label_text: String, pct: float, accent: Color, show_pct: bool) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size.y = BAR_HEIGHT
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	lbl.custom_minimum_size.x = 160
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	lbl.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.75))
	hbox.add_child(lbl)

	var bar_control := _BarChart.new()
	bar_control.custom_minimum_size = Vector2(0, BAR_HEIGHT - 4)
	bar_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_control.fill_pct = pct
	bar_control.fill_color = accent
	hbox.add_child(bar_control)

	if show_pct:
		var pct_label := Label.new()
		pct_label.text = "%.1f%%" % pct
		pct_label.custom_minimum_size.x = 55
		pct_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		pct_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
		pct_label.add_theme_color_override("font_color", accent)
		hbox.add_child(pct_label)

	return hbox

func _make_kill_bar(label_text: String, count: int, pct: float, accent: Color) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.custom_minimum_size.y = 22
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	lbl.custom_minimum_size.x = 160
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	lbl.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.65))
	hbox.add_child(lbl)

	var bar_control := _BarChart.new()
	bar_control.custom_minimum_size = Vector2(0, 18)
	bar_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_control.fill_pct = pct
	bar_control.fill_color = accent
	hbox.add_child(bar_control)

	var count_label := Label.new()
	count_label.text = str(count)
	count_label.custom_minimum_size.x = 55
	count_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	count_label.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.55))
	hbox.add_child(count_label)

	return hbox

func _add_no_data(container: Control) -> void:
	var lbl := Label.new()
	lbl.text = SettingsManager.t(&"run_summary_no_data")
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	lbl.add_theme_color_override("font_color", Color(TEXT_COL.r, TEXT_COL.g, TEXT_COL.b, 0.35))
	container.add_child(lbl)

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _get_spell_color(spell_id: StringName) -> Color:
	match spell_id:
		&"fireball": return Color(1.0, 0.45, 0.15)
		&"magic_bolt": return Color(0.5, 0.4, 0.9)
		&"lightning_strike": return Color(0.9, 0.85, 0.3)
		&"ice_shard": return Color(0.5, 0.85, 1.0)
		&"arcane_orb": return Color(0.6, 0.3, 0.9)
		&"spirit_orb": return Color(0.4, 0.8, 0.6)
		&"blade": return Color(0.75, 0.75, 0.8)
		&"electric_zone": return Color(0.3, 0.7, 1.0)
		&"cyclone": return Color(0.4, 0.6, 0.9)
		&"arcane_ray": return Color(0.7, 0.4, 1.0)
		&"shield": return Color(0.4, 0.75, 0.95)
		&"fire_breath": return Color(1.0, 0.35, 0.1)
		&"needle": return Color(0.65, 0.55, 0.85)
		&"poison_pool": return Color(0.45, 0.85, 0.2)
		&"frost_nova": return Color(0.5, 0.8, 1.0)
	return Color(0.6, 0.5, 0.8)

func _get_enemy_color(enemy_type: String) -> Color:
	match enemy_type:
		&"small": return Color(0.5, 0.55, 0.6)
		&"medium": return Color(0.65, 0.5, 0.35)
		&"big": return Color(0.8, 0.3, 0.3)
		&"mine": return Color(0.9, 0.6, 0.2)
		&"overlord": return Color(0.7, 0.3, 0.8)
		&"rampage": return Color(0.9, 0.2, 0.15)
		&"medium_boss": return Color(0.85, 0.55, 0.2)
		&"mine_boss": return Color(0.95, 0.65, 0.15)
		&"big_boss": return Color(0.85, 0.2, 0.2)
		&"rampage_boss": return Color(0.95, 0.15, 0.1)
		&"overlord_boss": return Color(0.75, 0.25, 0.85)
	return Color(0.5, 0.5, 0.55)

func _on_restart() -> void:
	visible = false
	GameManager.start_game()

func _on_menu() -> void:
	visible = false
	GameManager.return_to_menu()

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

class _BarChart extends Control:
	var fill_pct: float = 0.0
	var fill_color: Color = Color(0.6, 0.5, 0.8)

	func _draw() -> void:
		var bg_rect := Rect2(Vector2.ZERO, size)
		draw_rect(bg_rect, BAR_BG, true, 0.0, false)

		var fill_w: float = size.x * clampf(fill_pct / 100.0, 0.0, 1.0)
		if fill_w > 1.0:
			var fill_rect := Rect2(Vector2.ZERO, Vector2(fill_w, size.y))
			var c := fill_color
			draw_rect(fill_rect, c, true, 0.0, false)

			var highlight := Color(minf(c.r + 0.15, 1.0), minf(c.g + 0.15, 1.0), minf(c.b + 0.15, 1.0), 0.3)
			var hl_rect := Rect2(Vector2.ZERO, Vector2(fill_w, size.y * 0.4))
			draw_rect(hl_rect, highlight, true, 0.0, false)
