class_name HUD extends Control

const SLOT_SIZE := 54.0
const SLOT_GAP := 8.0

var _timer_label: Label
var _xp_bar: _XPBar
var _hp_bar: _HPBar
var _spell_panel: Control
var _spell_slots: Array[_SpellSlot] = []
var _timer_accum: float = 0.0
var _currency_label: Label
var _artifact_label: Label
var _chest_indicators: Array[ChestIndicator] = []
var _boss_health_bar: BossHealthBar
var _fusion_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build_ui()
	SettingsManager.language_changed.connect(_refresh_texts)
	EventBus.player_damaged.connect(_on_hp_changed)
	EventBus.player_healed.connect(_on_hp_changed)
	EventBus.player_xp_gained.connect(_on_xp_changed)
	EventBus.player_level_up.connect(_on_level_up)
	EventBus.spell_upgraded.connect(_on_spell_upgraded)
	EventBus.game_started.connect(_on_game_started)
	EventBus.currency_collected.connect(_on_currency_changed)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
	EventBus.chest_spawned.connect(_on_chest_spawned)
	EventBus.chest_removed.connect(_on_chest_removed)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_xp_bar = _XPBar.new()
	_xp_bar.anchor_left = 0.0
	_xp_bar.anchor_right = 1.0
	_xp_bar.anchor_top = 0.0
	_xp_bar.anchor_bottom = 0.0
	_xp_bar.offset_left = 0.0
	_xp_bar.offset_right = 0.0
	_xp_bar.offset_top = 0.0
	_xp_bar.offset_bottom = 12.0
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar)

	_timer_label = Label.new()
	_timer_label.text = "00:00"
	_timer_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", SettingsManager.font_size(28))
	_timer_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.88))
	_timer_label.add_theme_color_override("font_outline_color", Color(0.18, 0.12, 0.28))
	_timer_label.add_theme_constant_override("outline_size", 3)
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.offset_top = 16
	_timer_label.offset_left = -60
	_timer_label.offset_right = 60
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_label)

	_hp_bar = _HPBar.new()
	add_child(_hp_bar)

	_spell_panel = Control.new()
	_spell_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spell_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_panel.offset_top = -86
	_spell_panel.offset_bottom = -14
	_spell_panel.offset_left = -250
	_spell_panel.offset_right = 250
	add_child(_spell_panel)

	_currency_label = Label.new()
	_currency_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_currency_label.offset_top = 18.0
	_currency_label.offset_right = -16.0
	_currency_label.offset_left = -120.0
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_currency_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	_currency_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_currency_label.add_theme_constant_override("outline_size", 3)
	_currency_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_currency_label.text = "0"
	add_child(_currency_label)

	_artifact_label = Label.new()
	_artifact_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_artifact_label.offset_top = 44.0
	_artifact_label.offset_right = -16.0
	_artifact_label.offset_left = -120.0
	_artifact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_artifact_label.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_artifact_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.8, 0.85))
	_artifact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_artifact_label.add_theme_constant_override("outline_size", 2)
	_artifact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_artifact_label.text = ""
	add_child(_artifact_label)

	_boss_health_bar = BossHealthBar.new()
	_boss_health_bar.name = "BossHealthBar"
	add_child(_boss_health_bar)

	_fusion_btn = Button.new()
	_fusion_btn.text = SettingsManager.t(&"card_fusion")
	_fusion_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fusion_btn.offset_top = 18.0
	_fusion_btn.offset_left = 16.0
	_fusion_btn.offset_right = 130.0
	_fusion_btn.offset_bottom = 52.0
	_fusion_btn.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_fusion_btn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.2))
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.04, 0.09, 0.9)
	n.border_color = Color(0.55, 0.35, 0.8, 0.7)
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.set_corner_radius_all(4)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 4; n.content_margin_bottom = 4
	_fusion_btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate()
	h.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	h.border_color = Color(0.7, 0.5, 0.9, 0.9)
	_fusion_btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate()
	p.bg_color = Color(0.04, 0.02, 0.06, 0.95)
	p.border_color = Color(0.35, 0.2, 0.55, 0.8)
	_fusion_btn.add_theme_stylebox_override("pressed", p)
	_fusion_btn.pressed.connect(_on_fusion_btn_pressed)
	add_child(_fusion_btn)

	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	_timer_accum += delta
	if _timer_accum >= 0.25:
		_timer_accum = 0.0
		_timer_label.text = GameManager.format_time()
		if GameManager.is_boss_fight():
			var pulse := 0.5 + 0.5 * sin(GameManager.game_time * 6.0)
			_timer_label.add_theme_color_override("font_color", Color(0.9 + pulse * 0.1, 0.15, 0.15, 0.9 + pulse * 0.1))
		else:
			var remaining := GameManager.get_remaining_time()
			if remaining >= 0.0 and remaining < 60.0:
				var pulse2 := 0.5 + 0.5 * sin(GameManager.game_time * 4.0)
				var urgency := 1.0 - remaining / 60.0
				_timer_label.add_theme_color_override("font_color", Color(0.9 + pulse2 * 0.1, 0.3 * (1.0 - urgency), 0.2, 0.8 + pulse2 * 0.2))
			else:
				_timer_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.88))
	for slot in _spell_slots:
		slot.queue_redraw()

func _on_hp_changed(_amount: float = 0.0, _source: Node2D = null) -> void:
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats is PlayerStats:
		var r: float = player.stats.current_hp / maxf(player.stats.max_hp, 1.0)
		_hp_bar.ratio = clampf(r, 0.0, 1.0)

func _on_xp_changed(_amount: float = 0.0) -> void:
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats is PlayerStats:
		var req: float = player.stats.get_xp_required()
		var r: float = player.stats.current_xp / maxf(req, 1.0)
		_xp_bar.ratio = clampf(r, 0.0, 1.0)

func _on_level_up(new_level: int) -> void:
	_on_xp_changed()

func _on_spell_upgraded(_spell_name: StringName, _new_level: int) -> void:
	_update_spell_icons()

func _update_spell_icons() -> void:
	for child in _spell_panel.get_children():
		child.queue_free()
	_spell_slots.clear()
	var manager := _find_level_up_manager()
	if not manager:
		return
	var player := GameManager.get_player()
	var casters: Array = []
	if player:
		var sn := player.get_node_or_null("Spells")
		if sn:
			for ch in sn.get_children():
				if ch is SpellCaster:
					casters.append(ch)
	var spell_count := manager._owned_spells.size()
	var total_w := spell_count * SLOT_SIZE + maxi(spell_count - 1, 0) * SLOT_GAP
	var panel_w := 500.0
	var start_x := (panel_w - total_w) * 0.5
	var idx := 0
	for spell_id in manager._owned_spells:
		var spell: Spell = manager._owned_spells[spell_id]
		var caster: SpellCaster = null
		for c in casters:
			if c.spell == spell:
				caster = c
				break
		var slot := _SpellSlot.new()
		slot.spell_ref = spell
		slot.caster_ref = caster
		slot._setup_icon()
		slot.set_position(Vector2(start_x + idx * (SLOT_SIZE + SLOT_GAP), 0))
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE + 18)
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE + 18)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spell_panel.add_child(slot)
		_spell_slots.append(slot)
		idx += 1

func _find_level_up_manager() -> LevelUpManager:
	var nodes := get_tree().get_nodes_in_group("level_up_manager")
	for n in nodes:
		if n is LevelUpManager:
			return n
	return null

func _on_game_started() -> void:
	_hp_bar.ratio = 1.0
	_xp_bar.ratio = 0.0
	_timer_label.text = "00:00"
	for child in _spell_panel.get_children():
		child.queue_free()
	_spell_slots.clear()
	if _currency_label:
		_currency_label.text = "0"
	if _artifact_label:
		_artifact_label.text = ""
	for ind in _chest_indicators:
		if is_instance_valid(ind):
			ind.queue_free()
	_chest_indicators.clear()
	if _boss_health_bar:
		_boss_health_bar.dismiss()

func _on_currency_changed(_value: int, _rarity: int) -> void:
	if _currency_label:
		_currency_label.text = str(GameManager.currency)

func _on_artifact_equipped(_artifact: Resource) -> void:
	if _artifact_label:
		_artifact_label.text = SettingsManager.t(&"artifacts_label") + " %d" % ArtifactManager.equipped.size()

func _on_chest_spawned(chest: Node2D) -> void:
	var indicator := ChestIndicator.new()
	indicator.setup(chest)
	add_child(indicator)
	_chest_indicators.append(indicator)

func _on_chest_removed(chest: Node2D) -> void:
	for i in range(_chest_indicators.size() - 1, -1, -1):
		var ind: ChestIndicator = _chest_indicators[i]
		if not is_instance_valid(ind) or not is_instance_valid(ind._target_chest) or ind._target_chest == chest:
			if is_instance_valid(ind):
				ind.queue_free()
			_chest_indicators.remove_at(i)

func _on_boss_spawned(boss_name: String, max_hp: float, _pos: Vector2) -> void:
	_boss_health_bar.setup(boss_name, max_hp)

func _on_boss_hp_changed(current_hp: float, max_hp: float) -> void:
	_boss_health_bar.update_hp(current_hp, max_hp)

func _on_boss_defeated(_boss_name: String, _pos: Vector2) -> void:
	_boss_health_bar.dismiss()

func _refresh_texts() -> void:
	_fusion_btn.text = SettingsManager.t(&"card_fusion")

func _on_fusion_btn_pressed() -> void:
	if FusionGrimoire.is_open:
		return
	var grimoire := FusionGrimoire.new()
	get_parent().add_child(grimoire)


class _XPBar extends Control:
	var ratio: float = 0.0
	var _pulse: float = 0.0

	func _process(delta: float) -> void:
		_pulse += delta * 2.0
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.04, 0.02, 0.09, 0.9))
		if ratio > 0.001:
			var fill_w: float = w * ratio
			var pulse := 0.85 + 0.15 * sin(_pulse)
			draw_rect(Rect2(0.0, 0.0, fill_w, h), Color(0.15 * pulse, 0.35 * pulse, 0.85 * pulse, 0.85))
			draw_rect(Rect2(0.0, 0.0, fill_w, h * 0.45), Color(0.3 * pulse, 0.55 * pulse, 1.0 * pulse, 0.4))
		draw_line(Vector2(0.0, h), Vector2(w, h), Color(0.35, 0.25, 0.55, 0.5), 1.0, true)
		if ratio < 0.15:
			var urg := (0.15 - ratio) / 0.15
			var p := 0.5 + 0.5 * sin(_pulse * 3.0)
			draw_rect(Rect2(0.0, 0.0, w, h), Color(0.2, 0.1, 0.5, urg * p * 0.15))


class _HPBar extends Control:
	var ratio: float = 1.0
	var _pulse: float = 0.0
	const BAR_W := 80.0
	const BAR_H := 8.0
	const OFFSET_Y := 73.0

	func _ready() -> void:
		z_index = -5
		size = Vector2(BAR_W, BAR_H)
		custom_minimum_size = Vector2(BAR_W, BAR_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _process(delta: float) -> void:
		_pulse += delta * 2.0
		if not (GameManager.is_playing() or GameManager.current_state == GameManager.GameState.LEVEL_UP or GameManager.current_state == GameManager.GameState.ARTIFACT_SELECT):
			visible = false
			return
		var player := GameManager.get_player()
		if not player or not is_instance_valid(player):
			visible = false
			return
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if not cam:
			visible = false
			return
		visible = true
		var vp_size := get_viewport().get_visible_rect().size
		var diff: Vector2 = player.global_position - cam.global_position
		var screen_pos: Vector2 = diff * cam.zoom + vp_size * 0.5
		position = screen_pos + Vector2(-BAR_W * 0.5, OFFSET_Y)
		queue_redraw()

	func _get_hp_color() -> Color:
		if ratio > 0.6:
			var t: float = (ratio - 0.6) / 0.4
			return Color(0.15 + 0.5 * (1.0 - t), 0.65 + 0.35 * t, 0.1 + 0.08 * t)
		elif ratio > 0.3:
			var t: float = (ratio - 0.3) / 0.3
			return Color(0.8 + 0.15 * t, 0.5 * t + 0.12, 0.03)
		else:
			var p := 0.5 + 0.5 * sin(_pulse * 4.0)
			return Color(0.65 + 0.35 * p, 0.06, 0.04)

	func _draw() -> void:
		if ratio <= 0.001:
			return
		var col := _get_hp_color()
		var border_col := Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.7)
		draw_rect(Rect2(-1.0, -1.0, BAR_W + 2.0, BAR_H + 2.0), Color(0.02, 0.01, 0.04, 0.8))
		draw_rect(Rect2(-1.0, -1.0, BAR_W + 2.0, BAR_H + 2.0), border_col, false, 1.0)
		draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(0.06, 0.03, 0.08, 0.7))
		var fill_w: float = BAR_W * ratio
		draw_rect(Rect2(0.0, 0.0, fill_w, BAR_H), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.9))
		draw_rect(Rect2(0.0, 0.0, fill_w, BAR_H * 0.35), Color(minf(col.r + 0.35, 1.0), minf(col.g + 0.3, 1.0), minf(col.b + 0.25, 1.0), 0.35))
		if ratio < 0.25:
			var urg := (0.25 - ratio) / 0.25
			var p := 0.5 + 0.5 * sin(_pulse * 5.0)
			draw_rect(Rect2(0.0, 0.0, BAR_W, BAR_H), Color(0.5, 0.05, 0.02, urg * p * 0.2))
		if ratio > 0.01:
			var tip_glow: float = 0.4 + 0.2 * sin(_pulse * 1.5)
			draw_rect(Rect2(fill_w - 2.0, 0.0, 2.0, BAR_H), Color(col.r, col.g, col.b, tip_glow))


class _SpellSlot extends Control:
	var spell_ref: Spell = null
	var caster_ref: SpellCaster = null
	var _icon_sprite: Sprite2D = null

	func _draw() -> void:
		if not spell_ref:
			return
		var s: float = 54.0
		var col := spell_ref.color

		draw_rect(Rect2(0.0, 0.0, s, s), Color(0.08, 0.04, 0.12, 0.85))
		draw_rect(Rect2(0.0, 0.0, s, s), Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.6), false, 1.5)

		if not _icon_sprite:
			var font := ThemeDB.fallback_font
			var abbr := spell_ref.spell_name.substr(0, 2).to_upper()
			var fs := 18
			var ts := font.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var tp := Vector2(s * 0.5 - ts.x * 0.5, s * 0.5 + fs * 0.2)
			draw_string(font, tp, abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.9))

		var font := ThemeDB.fallback_font
		var lt := "Lv%d" % spell_ref.current_level
		var ls := 12
		var lts := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, ls)
		var lp := Vector2(s * 0.5 - lts.x * 0.5, s + 14.0)
		draw_string(font, lp, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, col)

		if caster_ref and is_instance_valid(caster_ref) and spell_ref:
			var cd_ratio: float = 0.0
			if spell_ref.behavior:
				var bp: float = spell_ref.behavior.get_cooldown_progress()
				if bp >= 0.0:
					cd_ratio = bp
				else:
					var player := GameManager.get_player()
					var cd_red := 0.0
					if player and "stats" in player and player.stats is PlayerStats:
						cd_red = player.stats.cooldown_reduction
					var cd := spell_ref.get_cooldown(cd_red)
					var remaining := clampf(cd - caster_ref._time_since_cast, 0.0, cd)
					if cd > 0.01 and remaining > 0.01:
						cd_ratio = remaining / cd
			else:
				var player := GameManager.get_player()
				var cd_red := 0.0
				if player and "stats" in player and player.stats is PlayerStats:
					cd_red = player.stats.cooldown_reduction
				var cd := spell_ref.get_cooldown(cd_red)
				var remaining := clampf(cd - caster_ref._time_since_cast, 0.0, cd)
				if cd > 0.01 and remaining > 0.01:
					cd_ratio = remaining / cd
			if cd_ratio > 0.01:
				var oh := s * cd_ratio
				draw_rect(Rect2(0.0, s - oh, s, oh), Color(0.0, 0.0, 0.0, 0.55))

	func _setup_icon() -> void:
		if not spell_ref or not spell_ref.icon:
			return
		var col := spell_ref.color
		_icon_sprite = Sprite2D.new()
		_icon_sprite.texture = spell_ref.icon
		_icon_sprite.modulate = Color(col.r, col.g, col.b, 0.9)
		var icon_s := 54.0 * 0.62
		var tex_size := spell_ref.icon.get_size()
		if tex_size.x > 0.0:
			_icon_sprite.scale = Vector2(icon_s / tex_size.x, icon_s / tex_size.y)
		_icon_sprite.position = Vector2(27.0, 27.0)
		add_child(_icon_sprite)
