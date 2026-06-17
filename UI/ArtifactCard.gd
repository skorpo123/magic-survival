class_name ArtifactCard extends Control

signal card_clicked()

const CARD_W := 260.0
const CARD_H := 340.0
const CORNER_R := 10.0
const TOP_BAR_H := 4.0
const BOT_BAR_H := 2.0
const PAD := 14.0

var _artifact: ArtifactData = null
var _index: int = 0
var _hover_t: float = 0.0
var _hover_target: float = 0.0
var _flash_t: float = 0.0
var _shimmer_x: float = -300.0
var _shimmer_speed: float = 200.0
var _is_exiting := false
var _is_selected := false
var _entrance_done := false
var _target_y: float = 0.0
var _pulse_phase: float = 0.0

var _icon_rect: TextureRect
var _name_label: Label
var _rarity_label: Label
var _bonus_container: VBoxContainer
var _debuff_container: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	size = Vector2(CARD_W, CARD_H)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_children = Control.CLIP_CHILDREN_ONLY
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	rotation = 0.0
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void: _hover_target = 0.0)
	_build_card_layout()

func setup(artifact: ArtifactData) -> void:
	_artifact = artifact
	var accent: Color = ItemRarity.COLORS.get(artifact.rarity, Color.GRAY)

	if artifact.icon:
		_icon_rect.texture = artifact.icon
	else:
		_icon_rect.texture = null

	_rarity_label.text = _get_rarity_text()
	_rarity_label.add_theme_color_override("font_color", accent)
	_rarity_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_rarity_label.add_theme_constant_override("shadow_offset_x", 1)
	_rarity_label.add_theme_constant_override("shadow_offset_y", 1)

	_name_label.text = _resolve_name()
	_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_name_label.add_theme_constant_override("outline_size", 3)

	_build_effect_labels()

func _resolve_name() -> String:
	if _artifact.name_key != &"":
		var translated := SettingsManager.t(_artifact.name_key)
		if translated != String(_artifact.name_key):
			return translated
	if _artifact.artifact_name != "":
		return _artifact.artifact_name
	return str(_artifact.name_key)

func _resolve_desc() -> String:
	if _artifact.desc_key != &"":
		var translated := SettingsManager.t(_artifact.desc_key)
		if translated != String(_artifact.desc_key):
			return translated
	if _artifact.description != "":
		return _artifact.description
	return str(_artifact.desc_key)

func _build_card_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAD)
	margin.add_theme_constant_override("margin_right", PAD)
	margin.add_theme_constant_override("margin_top", PAD)
	margin.add_theme_constant_override("margin_bottom", PAD)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_center)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(80, 80)
	_icon_rect.size = Vector2(80, 80)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(16))
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size = Vector2(0, 24)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_rarity_label = Label.new()
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_rarity_label.custom_minimum_size = Vector2(0, 20)
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_rarity_label)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.4, 0.3, 0.5, 0.25))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_bonus_container = VBoxContainer.new()
	_bonus_container.add_theme_constant_override("separation", 2)
	_bonus_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_bonus_container)

	_debuff_container = VBoxContainer.new()
	_debuff_container.add_theme_constant_override("separation", 2)
	_debuff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_debuff_container)

func _build_effect_labels() -> void:
	for c in _bonus_container.get_children():
		c.queue_free()
	for c in _debuff_container.get_children():
		c.queue_free()
	if not _artifact:
		return

	for bonus in _artifact.bonuses:
		var line := Label.new()
		line.text = _format_effect(bonus, true)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(0, 18)
		line.add_theme_color_override("font_color", Color(0.3, 0.92, 0.45))
		line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		line.add_theme_constant_override("shadow_offset_x", 1)
		line.add_theme_constant_override("shadow_offset_y", 1)
		line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		line.add_theme_constant_override("outline_size", 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bonus_container.add_child(line)

	for debuff in _artifact.debuffs:
		var line := Label.new()
		line.text = _format_effect(debuff, false)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(0, 18)
		line.add_theme_color_override("font_color", Color(0.92, 0.28, 0.22))
		line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		line.add_theme_constant_override("shadow_offset_x", 1)
		line.add_theme_constant_override("shadow_offset_y", 1)
		line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		line.add_theme_constant_override("outline_size", 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debuff_container.add_child(line)

func _get_rarity_text() -> String:
	if not _artifact:
		return ""
	match _artifact.rarity:
		ItemRarity.Tier.COMMON: return SettingsManager.t(&"rarity_common")
		ItemRarity.Tier.UNCOMMON: return SettingsManager.t(&"rarity_uncommon")
		ItemRarity.Tier.RARE: return SettingsManager.t(&"rarity_rare")
		ItemRarity.Tier.LEGENDARY: return SettingsManager.t(&"rarity_legendary")
	return "*"

func _format_effect(effect: ArtifactEffect, is_bonus: bool) -> String:
	var pct: float = (effect.value - 1.0) * 100.0 if effect.value > 1.0 else (1.0 - effect.value) * 100.0
	var val_str := ""
	var sign_str := "+" if effect.value > 1.0 else "-"
	match effect.effect_type:
		ArtifactEffect.EffectType.DAMAGE_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_dmg")]
		ArtifactEffect.EffectType.AREA_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_area")]
		ArtifactEffect.EffectType.COOLDOWN_REDUCE:
			val_str = "+%.0f%% %s" % [effect.value * 100.0, SettingsManager.t(&"eff_cast_speed")]
		ArtifactEffect.EffectType.PROJECTILE_SPEED:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_proj_speed")]
		ArtifactEffect.EffectType.EXTRA_PROJECTILE:
			val_str = "+%d %s" % [int(effect.value), SettingsManager.t(&"eff_projectile")]
		ArtifactEffect.EffectType.CHAIN_COUNT:
			val_str = "+%d %s" % [int(effect.value), SettingsManager.t(&"eff_chain")]
		ArtifactEffect.EffectType.DURATION_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_duration")]
		ArtifactEffect.EffectType.CRIT_CHANCE:
			val_str = "+%.0f%% %s" % [effect.value * 100.0, SettingsManager.t(&"eff_crit")]
		ArtifactEffect.EffectType.MOVE_SPEED_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_speed")]
		ArtifactEffect.EffectType.MAX_HP_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_hp")]
		ArtifactEffect.EffectType.PICKUP_RANGE_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_pickup")]
		ArtifactEffect.EffectType.XP_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_xp")]
		ArtifactEffect.EffectType.LIFE_STEAL:
			val_str = "+%.0f%% %s" % [effect.value * 100.0, SettingsManager.t(&"eff_lifesteal")]
		ArtifactEffect.EffectType.REGEN:
			val_str = "+%.1f %s" % [effect.value, SettingsManager.t(&"eff_regen")]
		ArtifactEffect.EffectType.DODGE_CHANCE:
			val_str = "+%.0f%% %s" % [effect.value * 100.0, SettingsManager.t(&"eff_dodge")]
		ArtifactEffect.EffectType.KNOCKBACK:
			val_str = "+%.0f%% %s" % [effect.value * 100.0, SettingsManager.t(&"eff_knockback")]
		ArtifactEffect.EffectType.SECOND_WIND:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.SPELL_ECHO:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.TINY_MENACE:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.STATIC_AURA:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.OVERFLOW:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.CRIT_CASCADE:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.MOVE_TRAIL:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.LOW_HP_EXPLODE:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.SPELL_SPLIT:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.DAMAGE_AURA:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.BOSS_DAMAGE_MULT:
			val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_boss_dmg")]
		ArtifactEffect.EffectType.ON_KILL_REGEN:
			val_str = "+%.1f %s" % [effect.value, SettingsManager.t(&"eff_onkill_regen")]
		ArtifactEffect.EffectType.PIERCE_COUNT:
			val_str = "+%d %s" % [int(effect.value), SettingsManager.t(&"eff_pierce")]
		ArtifactEffect.EffectType.MISSING_HP_DAMAGE:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.TWIN_CAST:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.BERSERKER_OATH:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.GAMBLER_DICE:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.TOXIC_BLOOM:
			val_str = _resolve_desc()
		ArtifactEffect.EffectType.VOLCANIC_GLYPH:
			val_str = _resolve_desc()
	return val_str

func play_entrance(delay: float) -> void:
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.06, 1.06), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	t.chain()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: _entrance_done = true)

func play_exit(is_selected: bool) -> void:
	_is_exiting = true
	_is_selected = is_selected
	if is_selected:
		_flash_t = 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_ease(Tween.EASE_OUT)
		t.set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(1.2, 1.2), 0.22).set_ease(Tween.EASE_IN)
	else:
		var dir := -1.0 if _index % 2 == 0 else 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(0.92, 0.92), 0.18).set_ease(Tween.EASE_IN)
		t.tween_property(self, "rotation", dir * 0.08, 0.18).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
	if _hover_t > 0.01:
		_pulse_phase += delta * 5.0
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 4.0, 0.0)
	if _entrance_done and not _is_exiting:
		_shimmer_x += delta * _shimmer_speed
		if _shimmer_x > CARD_W + 150.0:
			_shimmer_x = -300.0
			_shimmer_speed = randf_range(150.0, 250.0)
	queue_redraw()

func _draw() -> void:
	if not _artifact:
		return
	var accent: Color = ItemRarity.COLORS.get(_artifact.rarity, Color.GRAY)
	var h := _hover_t
	_draw_neon_glow(accent, h)
	_draw_card_bg(accent, h)
	_draw_inner_bevel(accent, h)
	_draw_inner_shadow(accent)
	_draw_icon_backglow(accent)
	_draw_accent_strips(accent)
	if not _artifact.icon:
		_draw_fallback_icon(accent)
	_draw_shimmer(h)
	_draw_flash()

func _draw_neon_glow(accent: Color, h: float) -> void:
	var pulse := 1.0 + sin(_pulse_phase) * 0.35 * maxf(h, 0.3)
	var base_alpha := (0.6 + h * 0.4) * pulse
	for i in range(3):
		var t := i / 3.0
		var expand := (16.0 + h * 12.0 * pulse) * (1.0 - t)
		var a := base_alpha * (1.0 - t) * 0.35
		draw_rect(Rect2(-expand, -expand, CARD_W + expand * 2.0, CARD_H + expand * 2.0), Color(accent.r, accent.g, accent.b, a))
	var bw := 2.0 + h * 3.0
	var ba := 0.85 + h * 0.15
	var bc := Color(
		minf(accent.r * 0.3 + h * 0.7, 1.0),
		minf(accent.g * 0.3 + h * 0.7, 1.0),
		minf(accent.b * 0.3 + h * 0.7, 1.0),
		ba
	)
	draw_rect(Rect2(-bw * 0.5, -bw * 0.5, CARD_W + bw, CARD_H + bw), bc)

func _draw_card_bg(accent: Color, h: float) -> void:
	var bg := Color(
		0.018 + accent.r * 0.003 + h * accent.r * 0.002,
		0.010 + accent.g * 0.003 + h * accent.g * 0.002,
		0.035 + accent.b * 0.003 + h * accent.b * 0.002,
		1.0
	)
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, bg)

func _draw_inner_bevel(accent: Color, h: float) -> void:
	var bevel_h := 6.0
	var a := 0.06 + h * 0.04
	draw_rect(Rect2(CORNER_R, CORNER_R, CARD_W - CORNER_R * 2.0, bevel_h), Color(1, 1, 1, a))
	draw_rect(Rect2(CORNER_R, CORNER_R, 2.0, CARD_H - CORNER_R * 2.0), Color(1, 1, 1, a * 0.5))

func _draw_inner_shadow(accent: Color) -> void:
	var shadow_w := 5.0
	draw_rect(Rect2(CARD_W - CORNER_R - shadow_w, CORNER_R, shadow_w + CORNER_R, CARD_H - CORNER_R * 2.0), Color(0, 0, 0, 0.12))
	draw_rect(Rect2(CORNER_R, CARD_H - CORNER_R - shadow_w, CARD_W - CORNER_R * 2.0, shadow_w + CORNER_R), Color(0, 0, 0, 0.12))

func _draw_accent_strips(accent: Color) -> void:
	draw_rect(Rect2(0, 0, CARD_W, TOP_BAR_H + CORNER_R), Color(accent.r, accent.g, accent.b, 0.7))
	draw_rect(Rect2(0, CARD_H - BOT_BAR_H - CORNER_R, CARD_W, BOT_BAR_H + CORNER_R), Color(accent.r, accent.g, accent.b, 0.3))

func _draw_shimmer(h: float) -> void:
	if not _entrance_done or _is_exiting:
		return
	if _shimmer_x < -150.0 or _shimmer_x > CARD_W + 150.0:
		return
	var s_w := 80.0
	var pts := PackedVector2Array([
		Vector2(_shimmer_x - s_w, 0),
		Vector2(_shimmer_x - s_w * 0.3, 0),
		Vector2(_shimmer_x + s_w * 0.5, CARD_H),
		Vector2(_shimmer_x - s_w * 0.2, CARD_H),
	])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.012 + h * 0.018))

func _draw_flash() -> void:
	if _flash_t < 0.01:
		return
	draw_rect(Rect2(0, 0, CARD_W, CARD_H), Color(1, 1, 1, _flash_t * 0.55))

func _draw_icon_backglow(accent: Color) -> void:
	var cx := CARD_W * 0.5
	var icon_top := PAD + 8.0
	var cy := icon_top + 96.0 * 0.5
	for i in range(3):
		var t := i / 3.0
		var r := (96.0 * 0.6 + 12.0) * (1.0 + t * 0.5)
		var a := 0.08 * (1.0 - t)
		draw_circle(Vector2(cx, cy), r, Color(accent.r, accent.g, accent.b, a))

func _draw_fallback_icon(accent: Color) -> void:
	var icon_size := Vector2(96, 96)
	var icon_pos := Vector2((CARD_W - icon_size.x) * 0.5, PAD + 8)
	var bg_color := Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.12, 0.9)
	_draw_rounded_rect(Rect2(icon_pos, icon_size), 8, bg_color)
	var pulse_a := 0.5 + 0.3 * (0.5 + 0.5 * sin(_pulse_phase))
	var border := Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.6, pulse_a)
	_draw_rounded_rect(Rect2(icon_pos, icon_size), 8, border, false, 2.0)
	var cx := icon_pos.x + icon_size.x * 0.5
	var cy := icon_pos.y + icon_size.y * 0.5
	var r := icon_size.x * 0.3
	var pts := PackedVector2Array([
		Vector2(cx, cy - r),
		Vector2(cx + r * 0.7, cy),
		Vector2(cx, cy + r),
		Vector2(cx - r * 0.7, cy),
	])
	draw_colored_polygon(pts, Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.35))
	draw_polyline(pts, Color(accent.r * 0.7, accent.g * 0.7, accent.b * 0.8, 0.6), 2.0, true)
	draw_circle(Vector2(cx, cy), icon_size.x * 0.08, Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.8, 0.7))

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color, filled: bool = true, line_width: float = 1.0) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r < 1.0:
		if filled:
			draw_rect(rect, color)
		else:
			draw_rect(rect, color, false, line_width)
		return
	var p := rect.position
	var s := rect.size
	if filled:
		draw_circle(p + Vector2(r, r), r, color)
		draw_circle(p + Vector2(s.x - r, r), r, color)
		draw_circle(p + Vector2(r, s.y - r), r, color)
		draw_circle(p + Vector2(s.x - r, s.y - r), r, color)
		draw_rect(Rect2(p.x + r, p.y, s.x - 2.0 * r, s.y), color)
		draw_rect(Rect2(p.x, p.y + r, s.x, s.y - 2.0 * r), color)
	else:
		var pts := PackedVector2Array()
		pts.append(p + Vector2(r, 0))
		pts.append(p + Vector2(s.x - r, 0))
		pts.append(p + Vector2(s.x, r))
		pts.append(p + Vector2(s.x, s.y - r))
		pts.append(p + Vector2(s.x - r, s.y))
		pts.append(p + Vector2(r, s.y))
		pts.append(p + Vector2(0, s.y - r))
		pts.append(p + Vector2(0, r))
		pts.append(p + Vector2(r, 0))
		draw_polyline(pts, color, line_width, true)

func _on_gui_input(event: InputEvent) -> void:
	if _is_exiting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_flash_t = 1.0
		card_clicked.emit()
