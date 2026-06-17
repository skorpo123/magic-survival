class_name FireBreathBehavior
extends BaseSpellBehavior

enum State { BURST, COOLDOWN }

@export var cone_angle: float = PI * 0.3
@export var cone_range: float = 180.0
@export var damage_interval: float = 0.10
@export var tick_damage: float = 16.0
@export var burst_ticks: int = 22
@export var fan_count: int = 1
@export var fan_spread: float = 0.0

var _state: int = State.BURST
var _burst_time: float = 0.0
var _burst_duration: float = 0.0
var _burst_progress: float = 0.0
var _cooldown_timer: float = 0.0
var _damage_timer: float = 0.0
var _ticks_done: int = 0
var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _smoothed_dir: Vector2 = Vector2.RIGHT
var _last_dir: Vector2 = Vector2.RIGHT
var _dir_smooth_speed: float = 12.0
var _burn_zones: Array = []
var _caster_node: Node2D = null
var _puff: FireBreathPuff = null

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_caster_node = caster
	_spell = spell
	_player_stats = player_stats
	_puff = FireBreathPuff.new()
	caster.add_child(_puff)
	if spell.active_modification:
		_puff.apply_modifier(spell.active_modification.mod_id)
	_start_burst()

func on_spell_upgraded(_caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_spell = spell
	_player_stats = player_stats
	if _puff and is_instance_valid(_puff) and spell.active_modification:
		_puff.apply_modifier(spell.active_modification.mod_id)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	_burn_zones.clear()
	if _puff and is_instance_valid(_puff):
		_puff.kill()
		_puff.queue_free()
		_puff = null

func tick(delta: float) -> void:
	var raw_dir := _get_player_direction()
	if raw_dir.length_squared() > 0.001:
		raw_dir = raw_dir.normalized()
		if _smoothed_dir.length_squared() > 0.001:
			var cur_angle: float = _smoothed_dir.angle()
			var tgt_angle: float = raw_dir.angle()
			var new_angle: float = lerp_angle(cur_angle, tgt_angle, minf(_dir_smooth_speed * delta, 1.0))
			_smoothed_dir = Vector2.from_angle(new_angle)
		else:
			_smoothed_dir = raw_dir

	_tick_burn_zones(delta)

	var player := GameManager.get_player()
	if player and _puff and is_instance_valid(_puff):
		_puff.update_position(player.global_position)
		_puff.update_direction(_smoothed_dir)

	match _state:
		State.BURST:
			_tick_burst(delta)
		State.COOLDOWN:
			_tick_cooldown(delta)

func get_burst_progress() -> float:
	return _burst_progress

func is_breathing() -> bool:
	return _state == State.BURST

func get_cooldown_progress() -> float:
	if _state == State.BURST:
		return 0.0
	var cd_dur := _get_cooldown_duration()
	if cd_dur <= 0.0:
		return 0.0
	return clampf(_cooldown_timer / cd_dur, 0.0, 1.0)

func _start_burst() -> void:
	_state = State.BURST
	_burst_time = 0.0
	_ticks_done = 0
	_damage_timer = 0.0
	_burst_progress = 0.0
	var interval := _get_effective_interval()
	_burst_duration = interval * float(burst_ticks)
	if _spell:
		_burst_duration *= _spell.get_duration_multiplier()
	if _puff and is_instance_valid(_puff):
		var player := GameManager.get_player()
		var pos := player.global_position if player else Vector2.ZERO
		var tint := _get_primary_color(_spell)
		var params := _build_params(_spell)
		var eff_angle: float = params.get(&"cone_angle", cone_angle)
		var eff_range: float = params.get(&"cone_range", cone_range)
		_puff.spawn(pos, _smoothed_dir, eff_angle, eff_range, tint)

func _tick_burst(delta: float) -> void:
	_burst_time += delta
	_burst_progress = ease(_burst_time / _burst_duration, -2.0)
	_burst_progress = clampf(_burst_progress, 0.0, 1.0)

	if _puff and is_instance_valid(_puff):
		_puff.set_burst_progress(_burst_progress)

	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _get_effective_interval()
		_deal_cone_damage()
		_ticks_done += 1

	if _ticks_done >= burst_ticks:
		_start_cooldown()

func _start_cooldown() -> void:
	_state = State.COOLDOWN
	_cooldown_timer = _get_cooldown_duration()
	if _puff and is_instance_valid(_puff):
		_puff.stop_emitting()

func _tick_cooldown(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_start_burst()

func _get_cooldown_duration() -> float:
	if _spell:
		var cd_reduction: float = 0.0
		if _player_stats:
			cd_reduction = _player_stats.cooldown_reduction
		return _spell.get_cooldown(cd_reduction)
	return 4.0

func _deal_cone_damage() -> void:
	if not _spell:
		return
	var player := GameManager.get_player()
	if not player:
		return
	var dmg_mult := 1.0
	if _player_stats:
		dmg_mult = _player_stats.magic_power
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats) * _tick_ratio()
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, player.global_position)
	var params := _build_params(_spell)
	var eff_angle: float = params.get(&"cone_angle", cone_angle) * lerp(0.75, 1.0, _burst_progress)
	var eff_range: float = params.get(&"cone_range", cone_range) * lerp(0.7, 1.0, _burst_progress)
	var eff_fans: int = params.get(&"fan_count", fan_count)
	var eff_spread: float = params.get(&"fan_spread", fan_spread)
	var dot_dur: float = params.get(&"dot_duration", 0.0)
	if dot_dur > 0.0:
		dmg *= 1.3
		var player_pos := player.global_position
		var tip_pos := player_pos + _smoothed_dir * eff_range * 0.7
		var burn_color := _get_primary_color(_spell)
		var visual := _make_burn_visual(tip_pos, burn_color)
		_burn_zones.append({pos = tip_pos, timer = dot_dur, dmg = params.get(&"dot_damage", 0.0), tick_interval = 0.5, tick_timer = 0.0, visual = visual, max_timer = dot_dur})
	for f in range(eff_fans):
			var dir := _smoothed_dir
			if eff_fans > 1:
				var offset: float = (float(f) - (float(eff_fans - 1) / 2.0)) * eff_spread
				dir = _smoothed_dir.rotated(offset)
			var from: Vector2 = player.global_position
			var to: Vector2 = from + dir * eff_range
			RunTracker.set_current_spell(_spell.spell_id)
			SwarmManager.damage_cone(from, to, eff_angle, dmg)
			EnemyMeshManager.damage_cone(from, to, eff_angle, dmg)
			RunTracker.record_damage(dmg * 2.0)

func _tick_ratio() -> float:
	return _get_effective_interval() / damage_interval

func _get_effective_interval() -> float:
	var interval := damage_interval
	if _spell and _spell.active_modification:
		interval *= _spell.active_modification.damage_interval_mult
	return interval

func _get_player_direction() -> Vector2:
	var player := GameManager.get_player()
	if not player:
		return _last_dir
	var vel: Vector2 = player.velocity if "velocity" in player else Vector2.ZERO
	if vel.length_squared() > 4.0:
		_last_dir = vel.normalized()
		return _last_dir
	if is_instance_valid(_caster_ref) and _caster_ref is SpellCaster and "_last_cast_dir" in _caster_ref:
		var ld: Vector2 = _caster_ref._last_cast_dir
		if ld.length_squared() > 0.01:
			return ld
	return _last_dir

func _build_params(spell: Spell) -> Dictionary:
	var eff_angle := cone_angle
	var eff_range := cone_range * spell.get_area_multiplier()
	var eff_fan := fan_count
	var eff_spread := fan_spread
	var eff_dot_dur := 0.0
	var eff_dot_dmg := 0.0

	if spell.active_modification:
		if spell.active_modification.mod_id == &"fire_breath_dragon":
			eff_range *= 1.35
		elif spell.active_modification.mod_id == &"fire_breath_fan":
			eff_angle *= 1.5
		elif spell.active_modification.mod_id == &"fire_breath_ash":
			eff_dot_dur = 2.0
			eff_dot_dmg = dmg_from_spell(spell) * 0.3

	return {
		&"cone_angle": eff_angle,
		&"cone_range": eff_range,
		&"fan_count": eff_fan,
		&"fan_spread": eff_spread,
		&"dot_duration": eff_dot_dur,
		&"dot_damage": eff_dot_dmg,
	}

func dmg_from_spell(spell: Spell) -> float:
	var mult := 1.0
	if _player_stats:
		mult = _player_stats.magic_power
	var _d := spell.get_damage(mult) * spell.roll_crit_mult(_player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(_d, GameManager.get_player().global_position if GameManager.get_player() else Vector2.ZERO)
	return _d

func _make_burn_visual(pos: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.global_position = pos
	p.z_index = -1
	p.color = Color(color.r, color.g * 0.6, color.b * 0.2, 0.6)
	var rx := 28.0
	var ry := 10.0
	var seg := 12
	var pts := PackedVector2Array()
	for i in range(seg):
		var t := float(i) / float(seg) * TAU
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	p.polygon = pts
	var player := GameManager.get_player()
	if player:
		var parent := player.get_parent()
		if parent:
			parent.add_child(p)
	return p

func _tick_burn_zones(delta: float) -> void:
	var still_alive: Array = []
	for zone in _burn_zones:
		zone.timer -= delta
		if zone.timer <= 0.0:
			if zone.has("visual") and is_instance_valid(zone.visual):
				zone.visual.queue_free()
			continue
		zone.tick_timer -= delta
		if zone.tick_timer <= 0.0:
			zone.tick_timer = zone.tick_interval
			RunTracker.set_current_spell(_spell.spell_id)
			SwarmManager.damage_area(zone.pos, 30.0, zone.dmg)
			EnemyMeshManager.damage_area(zone.pos, 30.0, zone.dmg)
			RunTracker.record_damage(zone.dmg * 2.0)
			BurstEffectPool.spawn("explosion", zone.pos, _get_primary_color(_spell), clampf(_spell.get_area_multiplier(), 0.3, 5.0))
		if zone.has("visual") and is_instance_valid(zone.visual):
			var life_ratio: float = maxf(zone.timer / zone.get("max_timer", 2.0), 0.0)
			zone.visual.modulate.a = life_ratio * 0.6
		still_alive.append(zone)
	_burn_zones = still_alive

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell and spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(1.0, 0.5, 0.1)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell and spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.8, 0.2, 0.05)
