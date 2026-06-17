class_name LevelUpScreen extends Control

const CARD_SPACING := 16.0
const ENTRANCE_STAGGER := 0.1
const BG := Color(0.0, 0.0, 0.0, 1.0)
const GOLD := Color(0.85, 0.7, 0.35)

var _overlay: ColorRect
var _center: CenterContainer
var _vbox: VBoxContainer
var _level_label: Label
var _title_label: Label
var _ornament: Control
var _cards_vbox: VBoxContainer
var _current_cards: Array[LevelUpCard] = []
var _spell_cards: Array[SpellCard] = []
var _level_up_manager: LevelUpManager
var _is_selecting := false
var _title_pulse_t: float = 0.0
var _fusion_pentagram: _PentagramButton

var _mana_return_streak: int = 0
var _mana_return_btn: Button = null
const MANA_RETURN_RATES: Array[float] = [0.40, 0.20, 0.08, 0.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_to_group("level_up_ui")
	visible = false
	_build_ui()
	EventBus.game_started.connect(_on_game_started)
	SettingsManager.language_changed.connect(_refresh_texts)

func _on_game_started() -> void:
	_mana_return_streak = 0
	_update_mana_return_ui()

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
	_center.clip_contents = true
	_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.z_index = 3
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 10)
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.add_child(_vbox)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	_level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	_level_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_level_label.add_theme_constant_override("shadow_offset_x", 1)
	_level_label.add_theme_constant_override("shadow_offset_y", 1)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_level_label.add_theme_constant_override("outline_size", 2)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_level_label)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"lu_title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(32))
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.65))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _title_row := HBoxContainer.new()
	_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_row.add_theme_constant_override("separation", 12)
	_title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_row.add_child(_title_label)
	_vbox.add_child(_title_row)

	_fusion_pentagram = _PentagramButton.new()
	_fusion_pentagram.mouse_filter = Control.MOUSE_FILTER_STOP
	_fusion_pentagram.pentagram_clicked.connect(_on_fusion_pentagram_clicked)
	_title_row.add_child(_fusion_pentagram)

	_ornament = _OrnamentLine.new()
	_ornament.custom_minimum_size = Vector2(350, 10)
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_ornament)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_vbox.clip_contents = true
	_cards_vbox.add_theme_constant_override("separation", int(CARD_SPACING))
	_cards_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_cards_vbox)

	_mana_return_btn = Button.new()
	_mana_return_btn.custom_minimum_size = Vector2(500, 40)
	_mana_return_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
	_mana_return_btn.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	_mana_return_btn.add_theme_color_override("font_hover_color", Color(0.6, 0.9, 1.0))
	_mana_return_btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.35, 0.6))
	_mana_return_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_mana_return_btn.add_theme_constant_override("shadow_offset_x", 1)
	_mana_return_btn.add_theme_constant_override("shadow_offset_y", 1)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.03, 0.04, 0.08, 0.9)
	btn_style.set_corner_radius_all(4)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.2, 0.35, 0.55, 0.6)
	_mana_return_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	btn_hover.border_color = Color(0.35, 0.55, 0.85, 0.8)
	_mana_return_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = Color(0.02, 0.02, 0.03, 0.7)
	btn_disabled.border_color = Color(0.15, 0.15, 0.18, 0.4)
	_mana_return_btn.add_theme_stylebox_override("disabled", btn_disabled)
	_mana_return_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_mana_return_btn.pressed.connect(_on_mana_return)
	_vbox.add_child(_mana_return_btn)
	_update_mana_return_ui()

func show_cards(cards: Array[LevelUpCard]) -> void:
	_current_cards = cards
	_spell_cards.clear()
	_is_selecting = false
	visible = true
	_update_level_label()

	for child in _cards_vbox.get_children():
		_cards_vbox.remove_child(child)
		child.queue_free()

	_level_label.modulate.a = 0.0
	_title_label.modulate.a = 0.0
	_animate_title_in()

	for i in range(cards.size()):
		var card := SpellCard.new()
		card.custom_minimum_size = Vector2(SpellCard.CARD_W, SpellCard.CARD_H)
		_cards_vbox.add_child(card)
		card.setup(cards[i], i)
		card.card_clicked.connect(_on_card_selected.bind(i))
		_spell_cards.append(card)
		card.play_entrance(0.15 + i * ENTRANCE_STAGGER)

	_update_mana_return_ui()

	var has_fusion := false
	for card in cards:
		if card.card_type == LevelUpCard.CardType.SPELL_FUSION:
			has_fusion = true
			break
	if _fusion_pentagram:
		_fusion_pentagram.set_available(has_fusion)

func _update_level_label() -> void:
	_level_label.text = SettingsManager.t(&"lu_current_level") % GameManager.current_level

func _animate_title_in() -> void:
	_title_label.modulate.a = 0.0
	_level_label.modulate.a = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(_level_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_delay(0.1)

func _process(delta: float) -> void:
	_title_pulse_t += delta
	var pulse := 0.85 + 0.15 * sin(_title_pulse_t * 2.0)
	_title_label.add_theme_color_override("font_color", Color(0.95 * pulse, 0.9 * pulse, 0.65 * pulse))

func _update_mana_return_ui() -> void:
	if not _mana_return_btn:
		return
	var idx := mini(_mana_return_streak, MANA_RETURN_RATES.size() - 1)
	var rate := MANA_RETURN_RATES[idx]
	if rate <= 0.0:
		_mana_return_btn.text = SettingsManager.t(&"btn_mana_return_disabled")
		_mana_return_btn.disabled = true
	else:
		var pct := int(rate * 100)
		_mana_return_btn.text = SettingsManager.t(&"btn_mana_return") % pct
		_mana_return_btn.disabled = false

func _on_mana_return() -> void:
	if _is_selecting:
		return
	var idx := mini(_mana_return_streak, MANA_RETURN_RATES.size() - 1)
	var rate := MANA_RETURN_RATES[idx]
	if rate <= 0.0:
		return
	var raw := GameManager.get_player()
	if not raw or not raw is Player:
		return
	var player: Player = raw
	if not player.stats:
		return
	_is_selecting = true
	var xp_required: float = player.stats.get_xp_required()
	var refund: float = xp_required * rate
	player.stats.current_xp += refund
	EventBus.player_xp_gained.emit(refund)
	player.xp_changed.emit(player.stats.current_xp, xp_required)
	_mana_return_streak += 1
	_current_cards.clear()
	_spell_cards.clear()
	visible = false
	var manager := _find_level_up_manager()
	if manager:
		manager.apply_mana_return()

func on_game_reset() -> void:
	_mana_return_streak = 0

func _on_card_selected(index: int) -> void:
	if _is_selecting or index < 0 or index >= _current_cards.size():
		return
	_is_selecting = true
	_mana_return_streak = 0

	for i in range(_spell_cards.size()):
		if is_instance_valid(_spell_cards[i]):
			_spell_cards[i].play_exit(i == index)

	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	t.tween_property(_level_label, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.chain()
	t.tween_interval(0.3)
	t.tween_callback(func() -> void: _apply_selection(index))

func _apply_selection(index: int) -> void:
	visible = false
	var card := _current_cards[index]
	_current_cards.clear()
	_spell_cards.clear()
	var manager := _find_level_up_manager()
	if manager:
		manager.apply_card(card)

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"lu_title")
	_update_level_label()
	_update_mana_return_ui()

func _on_fusion_pentagram_clicked() -> void:
	if _is_selecting:
		return
	if FusionGrimoire.is_open:
		return
	var grimoire := FusionGrimoire.new()
	get_parent().add_child(grimoire)

func _find_level_up_manager() -> LevelUpManager:
	if _level_up_manager and is_instance_valid(_level_up_manager):
		return _level_up_manager
	var nodes := get_tree().get_nodes_in_group("level_up_manager")
	for n in nodes:
		if n is LevelUpManager:
			_level_up_manager = n
			return n
	return null

class _OrnamentLine extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var line_w := w * 0.35
		var cx := w * 0.5
		var col := Color(0.55, 0.48, 0.3, 0.3)
		draw_line(Vector2(cx - line_w, y), Vector2(cx - 10, y), col, 1.0, true)
		draw_line(Vector2(cx + 10, y), Vector2(cx + line_w, y), col, 1.0, true)
		draw_rect(Rect2(cx - 5, y - 1.0, 10, 2), Color(0.65, 0.55, 0.35, 0.4))

class _PentagramButton extends Control:
	signal pentagram_clicked()

	const SIZE := 60.0

	var _available: bool = false
	var _pulse_t: float = 0.0
	var _hover_t: float = 0.0
	var _hover_target: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size = Vector2(SIZE, SIZE)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		mouse_entered.connect(func() -> void: _hover_target = 1.0)
		mouse_exited.connect(func() -> void: _hover_target = 0.0)

	func set_available(val: bool) -> void:
		_available = val
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse_t += delta * 3.0
		_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
		queue_redraw()

	func _draw() -> void:
		var cx := SIZE * 0.5
		var cy := SIZE * 0.5
		var r := SIZE * 0.42
		var col: Color
		if _available:
			var pulse := 0.7 + 0.3 * sin(_pulse_t * 2.0)
			col = Color(0.2 * pulse, 0.9 * pulse, 1.0, 0.8 + _hover_t * 0.2)
			for i in range(3):
				var expand := (4.0 + _hover_t * 6.0) * (1.0 - i / 3.0)
				var a := 0.15 * (1.0 - i / 3.0)
				draw_circle(Vector2(cx, cy), r + expand, Color(0.2, 0.9, 1.0, a))
		else:
			col = Color(0.6, 0.15, 0.3, 0.6 + _hover_t * 0.2)

		var star_points := PackedVector2Array()
		for i in range(10):
			var angle := -PI / 2.0 + i * PI / 5.0
			var dist := r if i % 2 == 0 else r * 0.4
			star_points.append(Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist))
		star_points.append(star_points[0])
		draw_polyline(star_points, col, 2.0 + _hover_t, true)
		draw_circle(Vector2(cx, cy), 3.0, col)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pentagram_clicked.emit()
