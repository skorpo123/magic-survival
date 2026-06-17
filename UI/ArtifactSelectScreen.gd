class_name ArtifactSelectScreen extends Control

const CARD_SPACING := 28.0
const ENTRANCE_STAGGER := 0.12
const BG := Color(0.025, 0.018, 0.06, 1.0)
const ARTIFACT_GOLD := Color(0.9, 0.75, 0.3)

var _current_artifacts: Array[ArtifactData] = []
var _current_rarity: int = ItemRarity.Tier.COMMON
var _is_selecting := false

var _overlay: ColorRect
var _center: CenterContainer
var _vbox: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _ornament: Control
var _grid: GridContainer
var _card_nodes: Array[ArtifactCard] = []
var _title_pulse_t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build_ui()
	EventBus.chest_opened.connect(_on_chest_opened)
	EventBus.game_started.connect(_on_game_started)
	SettingsManager.language_changed.connect(_refresh_texts)

func _on_game_started() -> void:
	visible = false
	_current_artifacts.clear()
	_card_nodes.clear()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = BG
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var stars := _StarField.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.z_index = 3
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 10)
	_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_center.add_child(_vbox)

	_title_label = Label.new()
	_title_label.text = SettingsManager.t(&"artifact_title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_title_label.add_theme_color_override("font_color", ARTIFACT_GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = SettingsManager.t(&"artifact_subtitle")
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", SettingsManager.font_size(15))
	_subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.8, 0.9))
	_subtitle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_subtitle_label.add_theme_constant_override("shadow_offset_x", 1)
	_subtitle_label.add_theme_constant_override("shadow_offset_y", 1)
	_subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_subtitle_label.add_theme_constant_override("outline_size", 2)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_subtitle_label)

	_ornament = _OrnamentLine.new()
	_ornament.custom_minimum_size = Vector2(500, 12)
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_ornament)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 32)
	_grid.add_theme_constant_override("v_separation", 24)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_child(_grid)

func _on_chest_opened(artifacts: Array, chest_rarity: int, _is_boss_chest: bool = false) -> void:
	if artifacts.is_empty():
		GameManager.exit_artifact_select()
		return
	_current_artifacts.clear()
	for a in artifacts:
		if a is ArtifactData:
			_current_artifacts.append(a)
	if _current_artifacts.is_empty():
		GameManager.exit_artifact_select()
		return
	_current_rarity = chest_rarity
	_show_offer()

func _show_offer() -> void:
	_is_selecting = false
	visible = true
	_overlay.modulate.a = 0.0
	var fade_t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_t.tween_property(_overlay, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)

	var rarity_name: String = "?"
	match _current_rarity:
		ItemRarity.Tier.COMMON:
			rarity_name = SettingsManager.t(&"rarity_common")
		ItemRarity.Tier.UNCOMMON:
			rarity_name = SettingsManager.t(&"rarity_uncommon")
		ItemRarity.Tier.RARE:
			rarity_name = SettingsManager.t(&"rarity_rare")
		ItemRarity.Tier.LEGENDARY:
			rarity_name = SettingsManager.t(&"rarity_legendary")
	_title_label.text = SettingsManager.t(&"artifact_title") + "  [%s]" % rarity_name
	_title_label.modulate = ItemRarity.COLORS.get(_current_rarity, Color.WHITE)

	for child in _grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_animate_title_in()

	for i in _current_artifacts.size():
		var artifact: ArtifactData = _current_artifacts[i]
		var card := ArtifactCard.new()
		_grid.add_child(card)
		card.setup(artifact)
		var idx: int = i
		card.card_clicked.connect(func() -> void: _select_artifact(idx))
		_card_nodes.append(card)
		card.play_entrance(0.25 + i * ENTRANCE_STAGGER)

func _animate_title_in() -> void:
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_subtitle_label, "modulate:a", 0.7, 0.5).set_ease(Tween.EASE_OUT).set_delay(0.15)

func _process(delta: float) -> void:
	_title_pulse_t += delta
	var pulse := 0.88 + 0.12 * sin(_title_pulse_t * 2.0)
	_title_label.add_theme_color_override("font_color", Color(pulse, pulse * 0.78, pulse * 0.28))

func _select_artifact(idx: int) -> void:
	if _is_selecting or idx < 0 or idx >= _current_artifacts.size():
		return
	_is_selecting = true

	for i in _card_nodes.size():
		if is_instance_valid(_card_nodes[i]):
			_card_nodes[i].play_exit(i == idx)

	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_property(_title_label, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	t.tween_property(_subtitle_label, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.chain()
	t.tween_interval(0.35)
	t.tween_callback(func() -> void: _apply_selection(idx))

func _apply_selection(idx: int) -> void:
	visible = false
	var artifact: ArtifactData = _current_artifacts[idx]
	EventBus.artifact_equipped.emit(artifact)
	GameManager.exit_artifact_select()
	_current_artifacts.clear()
	_card_nodes.clear()

func _refresh_texts() -> void:
	_title_label.text = SettingsManager.t(&"artifact_title")
	_subtitle_label.text = SettingsManager.t(&"artifact_subtitle")

func _input(_event: InputEvent) -> void:
	pass

class _StarField extends Control:
	var _stars: Array[Dictionary] = []

	func _ready() -> void:
		for i in range(40):
			_stars.append({
				"pos": Vector2(randf() * 2000, randf() * 1200),
				"size": randf_range(0.5, 2.0),
				"speed": randf_range(0.1, 0.4),
				"alpha": randf_range(0.15, 0.5)
			})

	func _process(delta: float) -> void:
		for s in _stars:
			var pos: Vector2 = s["pos"]
			pos.y -= float(s["speed"]) * delta * 60.0
			if pos.y < -10:
				pos.y = 1210.0
				pos.x = randf() * 2000.0
			s["pos"] = pos
		queue_redraw()

	func _draw() -> void:
		for s in _stars:
			var a: float = float(s["alpha"]) * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.001 * float(s["speed"]) * 3.0))
			draw_circle(s["pos"], float(s["size"]), Color(0.6, 0.5, 0.8, a))

class _OrnamentLine extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var line_w := w * 0.35
		var cx := w * 0.5
		var col := Color(0.55, 0.42, 0.25, 0.35)
		draw_line(Vector2(cx - line_w, y), Vector2(cx - 10, y), col, 1.0, true)
		draw_line(Vector2(cx + 10, y), Vector2(cx + line_w, y), col, 1.0, true)
		draw_rect(Rect2(cx - 6, y - 1.0, 12, 2), Color(0.65, 0.50, 0.30, 0.45))
