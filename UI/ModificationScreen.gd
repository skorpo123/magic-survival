class_name ModificationScreen extends Control

const BG := Color(0.0, 0.0, 0.0, 1.0)
const GOLD := Color(0.9, 0.75, 0.3)
const MOD_GOLD := Color(1.0, 0.85, 0.35)
const ORB_SIZE := 100.0
const TRIANGLE_TOP_Y := 160.0
const TRIANGLE_BOTTOM_Y := 340.0
const TRIANGLE_SPREAD := 160.0

var _overlay: ColorRect
var _center: CenterContainer
var _vbox: VBoxContainer
var _title_label: Label
var _desc_container: VBoxContainer
var _desc_name: Label
var _desc_effects: Label
var _study_btn: Button
var _orbs_host: Control
var _current_mods: Array[SpellModification] = []
var _current_spell: Spell = null
var _mod_orbs: Array[_ModOrb] = []
var _level_up_manager: LevelUpManager = null
var _is_selecting := false
var _selected_index: int = -1
var _fusion_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_to_group("modification_ui")
	visible = false
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = BG
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.z_index = 3
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 6)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.add_child(_vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"mod_title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(32))
	_title_label.add_theme_color_override("font_color", MOD_GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("outline_size", 3)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_title_label)

	_orbs_host = Control.new()
	_orbs_host.custom_minimum_size = Vector2(500, 420)
	_orbs_host.size = Vector2(500, 420)
	_orbs_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_orbs_host)

	_desc_container = VBoxContainer.new()
	_desc_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_desc_container.add_theme_constant_override("separation", 6)
	_desc_container.custom_minimum_size = Vector2(500, 0)
	_desc_container.visible = false
	_vbox.add_child(_desc_container)

	_desc_name = Label.new()
	_desc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_name.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_desc_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_desc_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_desc_name.add_theme_constant_override("outline_size", 3)
	_desc_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_container.add_child(_desc_name)

	_desc_effects = Label.new()
	_desc_effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_effects.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_desc_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_container.add_child(_desc_effects)

	_study_btn = Button.new()
	_study_btn.text = SettingsManager.t(&"btn_study")
	_study_btn.custom_minimum_size = Vector2(280, 52)
	_study_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_study_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_study_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_study_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.28, 0.35, 0.5))
	_study_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_study_btn.add_theme_constant_override("shadow_offset_x", 1)
	_study_btn.add_theme_constant_override("shadow_offset_y", 1)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.12, 0.1, 0.18, 0.9)
	btn_normal.set_corner_radius_all(8)
	btn_normal.set_border_width_all(2)
	btn_normal.border_color = Color(0.5, 0.4, 0.7, 0.7)
	btn_normal.content_margin_left = 24
	btn_normal.content_margin_right = 24
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	_study_btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.18, 0.14, 0.26, 0.95)
	btn_hover.border_color = Color(0.7, 0.55, 0.9, 0.85)
	_study_btn.add_theme_stylebox_override("hover", btn_hover)
	_study_btn.add_theme_stylebox_override("disabled", btn_normal)
	_study_btn.disabled = true
	_study_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_study_btn.pressed.connect(_on_study_pressed)
	_vbox.add_child(_study_btn)

	var fusion_btn := Button.new()
	fusion_btn.text = SettingsManager.t(&"card_fusion")
	fusion_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	fusion_btn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.2))
	fusion_btn.custom_minimum_size = Vector2(240, 40)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.04, 0.09, 0.9)
	n.border_color = Color(0.55, 0.35, 0.8, 0.7)
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.set_corner_radius_all(4)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 4; n.content_margin_bottom = 4
	fusion_btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate()
	h.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	h.border_color = Color(0.7, 0.5, 0.9, 0.9)
	fusion_btn.add_theme_stylebox_override("hover", h)
	fusion_btn.pressed.connect(_on_fusion_btn_pressed)
	_vbox.add_child(fusion_btn)
	_fusion_btn = fusion_btn

func show_modifications(spell: Spell) -> void:
	if visible:
		return
	_current_spell = spell
	_current_mods.clear()
	_mod_orbs.clear()
	_selected_index = -1
	_is_selecting = false
	visible = true

	if spell.modifications.size() > 0:
		_current_mods = spell.modifications.duplicate()

	_desc_container.visible = false
	_study_btn.disabled = true

	for child in _orbs_host.get_children():
		child.queue_free()

	_title_label.modulate.a = 0.0
	_animate_title_in()

	var positions := _get_triangle_positions(_current_mods.size())
	for i in range(_current_mods.size()):
		var mod: SpellModification = _current_mods[i]
		var orb := _ModOrb.new()
		orb.position = positions[i]
		_orbs_host.add_child(orb)
		orb.setup(mod, spell)
		orb.orb_clicked.connect(_on_orb_clicked.bind(i))
		_mod_orbs.append(orb)
		orb.play_entrance(0.2 + i * 0.12)

func _get_triangle_positions(count: int) -> Array[Vector2]:
	var center_x := 250.0
	var positions: Array[Vector2] = []
	if count >= 1:
		positions.append(Vector2(center_x, TRIANGLE_TOP_Y))
	if count >= 2:
		positions.append(Vector2(center_x - TRIANGLE_SPREAD, TRIANGLE_BOTTOM_Y))
	if count >= 3:
		positions.append(Vector2(center_x + TRIANGLE_SPREAD, TRIANGLE_BOTTOM_Y))
	return positions

func _animate_title_in() -> void:
	_title_label.modulate.a = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_title_label, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	pass

func _on_orb_clicked(index: int) -> void:
	if _is_selecting or index < 0 or index >= _current_mods.size():
		return
	_selected_index = index
	var mod := _current_mods[index]

	for i in range(_mod_orbs.size()):
		if is_instance_valid(_mod_orbs[i]):
			_mod_orbs[i].set_selected(i == index)

		_desc_name.text = SettingsManager.t(&"mod_" + mod.mod_id) if mod.mod_id != &"" else mod.mod_name
	_desc_container.visible = true
	_build_effect_text(mod)
	_study_btn.disabled = false

func _build_effect_text(mod: SpellModification) -> void:
	var lines: PackedStringArray = []
	if mod.damage_multiplier > 1.0:
		lines.append("[color=#4ADE80]+" + str(int((mod.damage_multiplier - 1.0) * 100)) + "% урон[/color]")
	elif mod.damage_multiplier < 1.0:
		lines.append("[color=#F87171]" + str(int((mod.damage_multiplier - 1.0) * 100)) + "% урон[/color]")
	if mod.cooldown_multiplier < 1.0:
		lines.append("[color=#4ADE80]+" + str(int((1.0 - mod.cooldown_multiplier) * 100)) + "% скорость[/color]")
	elif mod.cooldown_multiplier > 1.0:
		lines.append("[color=#F87171]+" + str(int((mod.cooldown_multiplier - 1.0) * 100)) + "% кулдаун[/color]")
	if mod.projectile_count_add > 0:
		lines.append("[color=#4ADE80]+" + str(mod.projectile_count_add) + " снаряд[/color]")
	if mod.chain_count_add > 0:
		lines.append("[color=#4ADE80]+" + str(mod.chain_count_add) + " цепей[/color]")
	if mod.chain_range > 0.0:
		lines.append("[color=#4ADE80]+" + str(int(mod.chain_range)) + " радиус цепи[/color]")
	if mod.speed_multiplier > 1.0:
		lines.append("[color=#4ADE80]+" + str(int((mod.speed_multiplier - 1.0) * 100)) + "% скорость снарядов[/color]")
	if mod.area_multiplier > 1.0:
		lines.append("[color=#4ADE80]+" + str(int((mod.area_multiplier - 1.0) * 100)) + "% радиус AoE[/color]")
	if mod.description != "":
		lines.append("[color=#9CA3AF]" + mod.description + "[/color]")
	_desc_effects.text = "\n".join(lines)

func _on_study_pressed() -> void:
	if _selected_index < 0 or _is_selecting:
		return
	_is_selecting = true
	_study_btn.disabled = true

	for i in range(_mod_orbs.size()):
		if is_instance_valid(_mod_orbs[i]):
			_mod_orbs[i].play_exit(i == _selected_index)

	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	t.tween_property(_desc_container, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.chain()
	t.tween_interval(0.35)
	t.tween_callback(func() -> void: _apply_modification(_selected_index))

func _apply_modification(index: int) -> void:
	var mod: SpellModification = _current_mods[index]
	if _current_spell and _current_spell.is_max_level():
		_current_spell.apply_modification(mod)
		var manager := _find_level_up_manager()
		if manager:
			manager.notify_modification_applied(_current_spell)
	visible = false
	_current_mods.clear()
	_mod_orbs.clear()
	GameManager.exit_level_up()
	var manager := _find_level_up_manager()
	if manager:
		manager._try_show_level_up()

func _find_level_up_manager() -> LevelUpManager:
	if _level_up_manager and is_instance_valid(_level_up_manager):
		return _level_up_manager
	var nodes := get_tree().get_nodes_in_group("level_up_manager")
	for n in nodes:
		if n is LevelUpManager:
			_level_up_manager = n
			return n
	return null

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"mod_title")
	if _fusion_btn:
		_fusion_btn.text = SettingsManager.t(&"card_fusion")

func _on_fusion_btn_pressed() -> void:
	if FusionGrimoire.is_open:
		return
	var grimoire := FusionGrimoire.new()
	get_parent().add_child(grimoire)


class _ModOrb extends Control:
	signal orb_clicked()

	const SIZE := 100.0
	const RADIUS := 50.0

	var _mod: SpellModification
	var _spell: Spell
	var _hover_t: float = 0.0
	var _hover_target: float = 0.0
	var _selected: bool = false
	var _entrance_done := false
	var _pulse_phase: float = 0.0
	var _icon_label: Label
	var _name_label: Label

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		custom_minimum_size = Vector2(SIZE, SIZE + 30)
		size = Vector2(SIZE, SIZE + 30)
		pivot_offset = Vector2(SIZE * 0.5, SIZE * 0.5)
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 0.0
		scale = Vector2(0.5, 0.5)
		gui_input.connect(_on_gui_input)
		mouse_entered.connect(func() -> void: _hover_target = 1.0)
		mouse_exited.connect(func() -> void: _hover_target = 0.0)
		_build_ui()

	func setup(mod: SpellModification, spell: Spell) -> void:
		_mod = mod
		_spell = spell
		if mod.mod_id != &"":
			var sid: String = String(mod.mod_id)
			var icon_path := "res://Sprites/mod_%s_icon_pix.png" % sid
			if ResourceLoader.exists(icon_path):
				_icon_label.text = ""
			else:
				_icon_label.text = _get_mod_symbol(mod)
		else:
			_icon_label.text = _get_mod_symbol(mod)
			_name_label.text = SettingsManager.t(&"mod_" + mod.mod_id) if mod.mod_id != &"" else mod.mod_name

	func _build_ui() -> void:
		_icon_label = Label.new()
		_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_icon_label.add_theme_font_size_override("font_size", SettingsManager.font_size(32))
		_icon_label.position = Vector2(0, 0)
		_icon_label.size = Vector2(SIZE, SIZE)
		_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_label)

		_name_label = Label.new()
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
		_name_label.position = Vector2(-20, SIZE + 4)
		_name_label.size = Vector2(SIZE + 40, 24)
		_name_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
		_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_name_label.add_theme_constant_override("outline_size", 2)
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name_label)

	func _get_mod_symbol(mod: SpellModification) -> String:
		match mod.mod_type:
			SpellModification.ModType.CHAIN: return "⚡"
			SpellModification.ModType.EXPLODE: return "💥"
			SpellModification.ModType.SPEED_BOOST: return "🔥"
			SpellModification.ModType.PIERCE_BOOST: return "🎯"
			SpellModification.ModType.SPLIT: return "✦"
			_: return "◆"

	func set_selected(val: bool) -> void:
		_selected = val
		queue_redraw()

	func play_entrance(delay: float) -> void:
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(delay)
		t.set_parallel(true)
		t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
		t.chain()
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(func() -> void: _entrance_done = true)

	func play_exit(is_selected: bool) -> void:
		if is_selected:
			var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
			t.set_parallel(true)
			t.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
		else:
			var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
			t.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
			t.tween_property(self, "scale", Vector2(0.7, 0.7), 0.15).set_ease(Tween.EASE_IN)

	func _process(delta: float) -> void:
		_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
		_pulse_phase += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var h := _hover_t
		var pulse := 1.0 + sin(_pulse_phase) * 0.08
		var col := _get_color()
		var r := RADIUS * pulse

		for i in range(3):
			var t := i / 3.0
			var expand := (8.0 + h * 10.0) * (1.0 - t)
			var a := (0.3 + h * 0.3) * (1.0 - t) * 0.4
			draw_circle(Vector2(SIZE * 0.5, SIZE * 0.5), r + expand, Color(col.r, col.g, col.b, a))

		draw_circle(Vector2(SIZE * 0.5, SIZE * 0.5), r, Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.95))
		draw_arc(Vector2(SIZE * 0.5, SIZE * 0.5), r, 0, TAU, 32, Color(col.r, col.g, col.b, 0.6 + h * 0.3), 2.0 + h * 1.0, true)

		if _selected:
			draw_arc(Vector2(SIZE * 0.5, SIZE * 0.5), r + 6.0, 0, TAU, 32, Color(col.r, col.g, col.b, 0.8), 3.0, true)

	func _get_color() -> Color:
		if not _mod:
			return Color(0.5, 0.3, 0.8)
		match _mod.mod_type:
			SpellModification.ModType.CHAIN: return Color(0.4, 0.7, 1.0)
			SpellModification.ModType.EXPLODE: return Color(1.0, 0.5, 0.2)
			SpellModification.ModType.SPEED_BOOST: return Color(1.0, 0.3, 0.3)
			SpellModification.ModType.PIERCE_BOOST: return Color(0.3, 0.9, 0.6)
			SpellModification.ModType.SPLIT: return Color(0.8, 0.5, 1.0)
			_: return Color(0.6, 0.4, 0.9)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			orb_clicked.emit()
