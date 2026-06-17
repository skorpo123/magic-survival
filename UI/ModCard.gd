class_name ModCard
extends Control

signal card_clicked()

const CARD_W := 260.0
const CARD_H := 360.0
const CORNER_R := 12.0
const TOP_BAR_H := 5.0
const BOT_BAR_H := 3.0
const PAD := 18.0

var _modification: SpellModification
var _spell: Spell
var _index: int
var _hover_t: float = 0.0
var _hover_target: float = 0.0
var _flash_t: float = 0.0
var _shimmer_x: float = -300.0
var _shimmer_speed: float = 180.0
var _is_exiting := false
var _is_selected := false
var _entrance_done := false
var _target_y: float = 0.0
var _pulse_phase: float = 0.0
var _rune_phase: float = 0.0

var _mod_type_label: Label
var _mod_name_label: Label
var _desc_label: Label
var _stat_label: Label
var _spell_name_label: Label
var _icon_rect: TextureRect

const MOD_ICONS: Dictionary = {
	&"magic_bolt_homing": "res://Sprites/Homing Magic Bolt_icon_pix.png",
	&"magic_bolt_chain": "res://Sprites/Chain Lightning mod for Magic Bolt_icon_pix.png",
	&"magic_bolt_storm": "res://Sprites/Magic Bolt Storm mod_icon_pix.png",
	&"fireball_split": "res://Sprites/Split Fireball mod_icon_pix.png",
	&"fireball_meteor": "res://Sprites/Meteor Fireball_icon_pix.png",
	&"fireball_pierce": "res://Sprites/Piercing Blaze_icon_pix.png",
	&"orbiting_arcana_vortex": "res://Sprites/Pulsating Vortex mod_icon_pix.png",
	&"orbiting_arcana_blade": "res://Sprites/Blade Strike mod_icon_pix.png",
	&"orbiting_arcana_cross": "res://Sprites/Cross Storm_icon_pix.png",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	size = Vector2(CARD_W, CARD_H)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_children = Control.CLIP_CHILDREN_ONLY
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void: _hover_target = 0.0)
	_build_labels()

func setup(mod: SpellModification, spell: Spell, index: int) -> void:
	_modification = mod
	_spell = spell
	_index = index
	var accent := mod.color_tint
	if accent == Color.WHITE:
		accent = Color(1.0, 0.75, 0.15)

	var mod_icon_path: String = MOD_ICONS.get(mod.mod_id, "")
	if mod_icon_path != "" and ResourceLoader.exists(mod_icon_path):
		_icon_rect.texture = load(mod_icon_path)
		_icon_rect.visible = true
		_icon_rect.modulate = Color.WHITE
		_mod_type_label.visible = false
	elif spell.icon:
		_icon_rect.texture = spell.icon
		_icon_rect.visible = true
		_icon_rect.modulate = Color.WHITE
		_mod_type_label.visible = false
	else:
		_icon_rect.visible = false
		_mod_type_label.visible = true
		_mod_type_label.text = _get_type_symbol()
		_mod_type_label.add_theme_color_override("font_color", accent)
		_mod_type_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		_mod_type_label.add_theme_constant_override("shadow_offset_x", 2)
		_mod_type_label.add_theme_constant_override("shadow_offset_y", 2)

	_spell_name_label.text = SettingsManager.t(&"spell_" + String(spell.spell_id))
	_spell_name_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75, 0.7))
	_spell_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_spell_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_spell_name_label.add_theme_constant_override("shadow_offset_y", 1)

	_mod_name_label.text = SettingsManager.t(&"mod_" + _mod_key_name(mod))
	_mod_name_label.add_theme_color_override("font_color", accent)
	_mod_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_mod_name_label.add_theme_constant_override("shadow_offset_x", 2)
	_mod_name_label.add_theme_constant_override("shadow_offset_y", 2)

	_desc_label.text = SettingsManager.t(&"mod_desc_" + _mod_key_name(mod))
	_desc_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_desc_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_desc_label.add_theme_constant_override("shadow_offset_x", 1)
	_desc_label.add_theme_constant_override("shadow_offset_y", 1)

	_stat_label.text = ""

func _mod_key_name(mod: SpellModification) -> String:
	var n := mod.mod_name.to_lower().replace(" ", "_")
	match n:
		"chain_lightning":
			if _spell and _spell.spell_id == &"electric_zone":
				return "chain_field"
			return "chain_lightning"
		"refraction":
			if _spell and _spell.spell_id == &"shield":
				return "refraction_shield_mod"
			return "refraction"
		"pulsating_vortex":
			return "wide_orbit"
		"blade_strike":
			return "acceleration"
		"cross_storm":
			return "multiplicity"
		"gravity_well":
			return "tornado"
		"seeking_wind":
			return "gale_force"
		"shockwave":
			return "thunderfield"
		"phantom_legion":
			return "phantom"
		"spectral_pierce":
			return "wraith"
		"thorns":
			return "fortress"
		"twin_cyclone":
			return "tempest"
		"spinning_prism":
			return "prism"
		"phantom_blades":
			return "phantom_blades"
		"rapid_bolt":
			return "thunderstorm"
		"magic_missile_storm":
			return "magic_missile_storm"
		"meteor":
			return "mega_explosion"
		"rapid_bolt":
			return "thunderstorm"
		"needle_volley":
			return "needle_volley"
		"ricochet_needle":
			return "ricochet_needle"
	return n

func _build_labels() -> void:
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.position = Vector2((CARD_W - 96.0) * 0.5, 10.0)
	_icon_rect.size = Vector2(96.0, 72.0)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.visible = false
	add_child(_icon_rect)

	_mod_type_label = Label.new()
	_mod_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mod_type_label.add_theme_font_size_override("font_size", SettingsManager.font_size(44))
	_mod_type_label.position = Vector2(0, 26)
	_mod_type_label.size = Vector2(CARD_W, 55)
	_mod_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mod_type_label)

	_spell_name_label = Label.new()
	_spell_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spell_name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(11))
	_spell_name_label.position = Vector2(0, 78)
	_spell_name_label.size = Vector2(CARD_W, 16)
	_spell_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spell_name_label)

	_mod_name_label = Label.new()
	_mod_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mod_name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_mod_name_label.position = Vector2(PAD, 100)
	_mod_name_label.size = Vector2(CARD_W - PAD * 2, 40)
	_mod_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mod_name_label)

	_desc_label = Label.new()
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_desc_label.position = Vector2(PAD, 160)
	_desc_label.size = Vector2(CARD_W - PAD * 2, 80)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	_stat_label.position = Vector2(PAD, 250)
	_stat_label.size = Vector2(CARD_W - PAD * 2, 70)
	_stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_label)

func _get_type_symbol() -> String:
	if not _modification:
		return "◆"
	match _modification.mod_type:
		SpellModification.ModType.HOMING: return "◎"
		SpellModification.ModType.SPLIT: return "✦"
		SpellModification.ModType.CHAIN: return "⚡"
		SpellModification.ModType.EXPLODE: return "💥"
		SpellModification.ModType.PIERCE_BOOST: return "➤"
		SpellModification.ModType.SPEED_BOOST: return "»"
		SpellModification.ModType.AREA_BOOST: return "◯"
		SpellModification.ModType.TICK_RATE: return "⏱"
	return "◆"

func play_entrance(delay: float) -> void:
	_target_y = position.y
	position.y = _target_y + 50.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", _target_y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.chain()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: _entrance_done = true)

func play_exit(is_selected: bool) -> void:
	_is_exiting = true
	_is_selected = is_selected
	if is_selected:
		_flash_t = 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15).set_ease(Tween.EASE_OUT)
		t.set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.28).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.28).set_ease(Tween.EASE_IN)
	else:
		var dir := -1.0 if _index % 2 == 0 else 1.0
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		t.tween_property(self, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_IN)
		t.tween_property(self, "position:x", position.x + dir * 80.0, 0.22).set_ease(Tween.EASE_IN)
		t.tween_property(self, "scale", Vector2(0.9, 0.9), 0.22).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
	if _hover_t > 0.01:
		_pulse_phase += delta * 5.0
	_rune_phase += delta * 2.0
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 4.0, 0.0)
	if _entrance_done and not _is_exiting:
		_shimmer_x += delta * _shimmer_speed
		if _shimmer_x > CARD_W + 150.0:
			_shimmer_x = -300.0
			_shimmer_speed = randf_range(150.0, 250.0)
	if _icon_rect.visible and _modification:
		var pulse := 1.0 + sin(_pulse_phase) * 0.05 * maxf(_hover_t, 0.4)
		_icon_rect.modulate = Color(1.0, 1.0, 1.0, pulse)
	queue_redraw()

func _get_accent() -> Color:
	if not _modification:
		return Color(1.0, 0.75, 0.15)
	var c := _modification.color_tint
	if c != Color.WHITE:
		return c
	return Color(1.0, 0.75, 0.15)

func _draw() -> void:
	if not _modification:
		return
	var accent := _get_accent()
	var h := _hover_t
	_draw_neon_glow(accent, h)
	_draw_card_bg(accent, h)
	_draw_accent_strips(accent)
	_draw_rune_circle(accent, h)
	_draw_separator(accent)
	_draw_shimmer(h)
	_draw_flash()
	_draw_level_badge(accent)

func _draw_neon_glow(accent: Color, h: float) -> void:
	var pulse := 1.0 + sin(_pulse_phase) * 0.35 * maxf(h, 0.3)
	var base_alpha := (0.35 + h * 0.6) * pulse
	for i in range(6):
		var t := i / 6.0
		var expand := (14.0 + h * 10.0 * pulse) * (1.0 - t)
		var a := base_alpha * (1.0 - t) * 0.2
		_draw_rounded_rect(
			Rect2(-expand, -expand, CARD_W + expand * 2.0, CARD_H + expand * 2.0),
			CORNER_R + expand * 0.4,
			Color(accent.r, accent.g, accent.b, a)
		)
	var bw := 2.0 + h * 3.0
	var ba := 0.5 + h * 0.5
	var bc := Color(
		minf(accent.r * 0.3 + h * 0.7, 1.0),
		minf(accent.g * 0.3 + h * 0.7, 1.0),
		minf(accent.b * 0.3 + h * 0.7, 1.0),
		ba
	)
	_draw_rounded_rect_outline(
		Rect2(-bw * 0.5, -bw * 0.5, CARD_W + bw, CARD_H + bw),
		CORNER_R + bw * 0.5,
		bc, bw
	)

func _draw_card_bg(accent: Color, h: float) -> void:
	var bg := Color(
		0.06 + accent.r * 0.015 + h * accent.r * 0.008,
		0.04 + accent.g * 0.015 + h * accent.g * 0.008,
		0.12 + accent.b * 0.015 + h * accent.b * 0.008,
		0.9
	)
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, bg)
	var cx := CARD_W * 0.5
	var cy := CARD_H * 0.4
	for i in range(4):
		var r := CARD_W * (0.12 + i * 0.1)
		draw_circle(Vector2(cx, cy), r, Color(accent.r, accent.g, accent.b, 0.006 + h * 0.004))
	for i in range(8):
		var t := i / 8.0
		var r2: float = CARD_H * (0.2 + t * 0.8)
		draw_circle(Vector2(CARD_W * 0.5, CARD_H * 0.5), r2, Color(0, 0, 0, 0.012 + t * 0.035))
	var inset := 5.0
	_draw_rounded_rect(
		Rect2(inset, inset, CARD_W - inset * 2.0, CARD_H - inset * 2.0),
		CORNER_R - 2.0,
		Color(0, 0, 0, 0.08)
	)

func _draw_accent_strips(accent: Color) -> void:
	var top_a := 0.7
	_draw_rounded_rect(Rect2(0, 0, CARD_W, TOP_BAR_H + CORNER_R), CORNER_R, Color(accent.r, accent.g, accent.b, top_a))
	draw_rect(Rect2(CORNER_R, CORNER_R, CARD_W - CORNER_R * 2.0, TOP_BAR_H), Color(accent.r, accent.g, accent.b, top_a))
	var bot_a := 0.3
	_draw_rounded_rect(Rect2(0, CARD_H - BOT_BAR_H - CORNER_R, CARD_W, BOT_BAR_H + CORNER_R), CORNER_R, Color(accent.r, accent.g, accent.b, bot_a))
	draw_rect(Rect2(CORNER_R, CARD_H - BOT_BAR_H - CORNER_R, CARD_W - CORNER_R * 2.0, BOT_BAR_H), Color(accent.r, accent.g, accent.b, bot_a))

func _draw_rune_circle(accent: Color, h: float) -> void:
	var cx := CARD_W * 0.5
	var cy := 50.0
	var r := 30.0 + sin(_rune_phase) * 2.0
	var a := 0.08 + h * 0.12
	draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(accent.r, accent.g, accent.b, a), 1.5, true)
	var r2 := r * 0.6
	draw_arc(Vector2(cx, cy), r2, _rune_phase, _rune_phase + PI, 16, Color(accent.r, accent.g, accent.b, a * 0.6), 1.0, true)
	draw_arc(Vector2(cx, cy), r2, _rune_phase + PI, _rune_phase + TAU, 16, Color(accent.r, accent.g, accent.b, a * 0.4), 1.0, true)

func _draw_separator(accent: Color) -> void:
	var y := 150.0
	var w := 60.0 + _hover_t * 25.0
	var x := (CARD_W - w) * 0.5
	draw_line(Vector2(x, y), Vector2(x + w, y), Color(accent.r, accent.g, accent.b, 0.25 + _hover_t * 0.2), 1.5, true)
	var dot_r := 2.0
	draw_circle(Vector2(x - dot_r, y), dot_r, Color(accent.r, accent.g, accent.b, 0.2))
	draw_circle(Vector2(x + w + dot_r, y), dot_r, Color(accent.r, accent.g, accent.b, 0.2))
	draw_circle(Vector2(x + w * 0.5, y), dot_r + 0.5, Color(accent.r, accent.g, accent.b, 0.3 + _hover_t * 0.15))

func _draw_level_badge(accent: Color) -> void:
	var cx := CARD_W * 0.5
	var y := CARD_H - 35.0
	draw_circle(Vector2(cx, y), 10.0, Color(accent.r, accent.g, accent.b, 0.15))
	draw_arc(Vector2(cx, y), 10.0, 0, TAU, 16, Color(accent.r, accent.g, accent.b, 0.4), 1.0, true)

func _draw_shimmer(h: float) -> void:
	if not _entrance_done or _is_exiting:
		return
	if _shimmer_x < -150.0 or _shimmer_x > CARD_W + 150.0:
		return
	var s_w := 90.0
	var pts := PackedVector2Array([
		Vector2(_shimmer_x - s_w, 0),
		Vector2(_shimmer_x - s_w * 0.3, 0),
		Vector2(_shimmer_x + s_w * 0.5, CARD_H),
		Vector2(_shimmer_x - s_w * 0.2, CARD_H),
	])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.015 + h * 0.02))

func _draw_flash() -> void:
	if _flash_t < 0.01:
		return
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, Color(1, 1, 1, _flash_t * 0.6))

func _draw_rounded_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if r < 1.0:
		draw_rect(rect, color)
		return
	var p := rect.position
	var s := rect.size
	draw_circle(p + Vector2(r, r), r, color)
	draw_circle(p + Vector2(s.x - r, r), r, color)
	draw_circle(p + Vector2(r, s.y - r), r, color)
	draw_circle(p + Vector2(s.x - r, s.y - r), r, color)
	draw_rect(Rect2(p.x + r, p.y, s.x - 2.0 * r, s.y), color)
	draw_rect(Rect2(p.x, p.y + r, s.x, s.y - 2.0 * r), color)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var inner_r := minf(radius - width * 0.5, minf(rect.size.x, rect.size.y) * 0.5)
	var outer_r := radius + width * 0.5
	if inner_r < 0.0:
		inner_r = 0.0
	_draw_rounded_rect(rect, outer_r, color)
	var inner_rect := Rect2(
		rect.position.x + width,
		rect.position.y + width,
		rect.size.x - width * 2.0,
		rect.size.y - width * 2.0
	)
	if inner_rect.size.x > 0 and inner_rect.size.y > 0:
		var bg := Color(
			0.06 + (_get_accent().r) * 0.015,
			0.04 + (_get_accent().g) * 0.015,
			0.12 + (_get_accent().b) * 0.015,
			0.9
		)
		_draw_rounded_rect(inner_rect, maxf(inner_r, 0.0), bg)

func _on_gui_input(event: InputEvent) -> void:
	if _is_exiting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()

func _on_click() -> void:
	_flash_t = 1.0
	card_clicked.emit()
