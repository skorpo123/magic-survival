class_name CycloneBehavior
extends BaseSpellBehavior

@export var fly_speed: float = 120.0
@export var start_radius: float = 15.0
@export var max_radius: float = 80.0
@export var grow_time: float = 1.0
@export var sustain_time: float = 1.5
@export var fade_time: float = 0.5
@export var damage_interval: float = 0.5
@export var rotation_speed: float = 3.0
@export var aim_range: float = 600.0

var _active: Array[CycloneVortex] = []
var _inactive: Array[CycloneVortex] = []
var _caster_parent: Node2D = null

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return true

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	if not _caster_parent:
		_caster_parent = caster

	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power

	var vortex_count := _get_vortex_count(spell)
	var target_pos := _get_closest_enemy_pos(caster.global_position, aim_range)
	var direction := Vector2.RIGHT
	if target_pos != Vector2.ZERO:
		direction = caster.global_position.direction_to(target_pos)

	var extra_spread := 0.3
	if vortex_count > 1:
		extra_spread = 0.15

	for i in range(vortex_count):
		var dir := direction
		if i > 0:
			var angle_offset: float = (i - (vortex_count - 1) / 2.0) * extra_spread
			dir = direction.rotated(angle_offset)
		var vortex := _acquire_vortex()
		var params := _build_params(spell, dmg_mult, player_stats)
		vortex.launch(caster.global_position, dir, params)
		vortex.finished.connect(_on_vortex_finished.bind(vortex), CONNECT_ONE_SHOT)
		_active.append(vortex)

func on_spell_added(caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	_caster_parent = caster

func on_spell_upgraded(_caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power
	var params := _build_params(spell, dmg_mult, player_stats)
	for vortex in _active:
		if is_instance_valid(vortex):
			vortex.update_params(params)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	for vortex in _active:
		if is_instance_valid(vortex):
			vortex.finished.disconnect(_on_vortex_finished)
			vortex.queue_free()
	for vortex in _inactive:
		if is_instance_valid(vortex):
			vortex.queue_free()
	_active.clear()
	_inactive.clear()

func _acquire_vortex() -> CycloneVortex:
	if _inactive.size() > 0:
		var v: CycloneVortex = _inactive.pop_back()
		return v
	var v := CycloneVortex.new()
	var tree_node: Node = _caster_parent if _caster_parent else GameManager.get_player()
	if tree_node:
		tree_node.get_parent().add_child(v)
	return v

func _on_vortex_finished(vortex: CycloneVortex) -> void:
	var idx := _active.find(vortex)
	if idx >= 0:
		_active.remove_at(idx)
	_inactive.append(vortex)

func _build_params(spell: Spell, dmg_mult: float, player_stats: PlayerStats) -> Dictionary:
	var eff_radius: float = max_radius * spell.get_area_multiplier()
	var eff_damage: float = spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(eff_damage, GameManager.get_player().global_position)
	var eff_interval: float = damage_interval
	var eff_rotation_speed: float = _get_effective_rotation_speed(spell)
	var eff_fly_speed: float = fly_speed

	if spell.active_modification:
		eff_radius *= spell.active_modification.zone_radius_mult
		eff_interval *= spell.active_modification.damage_interval_mult
		eff_rotation_speed *= spell.active_modification.orbit_speed_mult

	var is_seeking := spell.active_modification and spell.active_modification.mod_id == &"cyclone_gale"
	var is_gravity := spell.active_modification and spell.active_modification.mod_id == &"cyclone_gravity"

	var dur_mult := spell.get_duration_multiplier()
	var eff_pull_strength: float = 80.0
	if is_gravity:
		eff_pull_strength = 400.0
	if is_seeking:
		eff_fly_speed *= spell.active_modification.speed_multiplier

	return {
		&"fly_speed": eff_fly_speed,
		&"start_radius": start_radius,
		&"max_radius": eff_radius,
		&"grow_time": grow_time * dur_mult,
		&"sustain_time": sustain_time * dur_mult,
		&"fade_time": fade_time * dur_mult,
		&"damage": eff_damage,
		&"damage_interval": eff_interval,
		&"rotation_speed": eff_rotation_speed,
		&"seeking": is_seeking,
		&"seek_strength": 3.0,
		&"gravity_pull": is_gravity,
		&"pull_strength": eff_pull_strength,
		&"pull_range": eff_radius,
		&"primary_color": _get_primary_color(spell),
		&"secondary_color": _get_secondary_color(spell),
		&"no_damage": spell.active_modification and spell.active_modification.damage_multiplier <= 0.0,
		&"is_twin": spell.active_modification and spell.active_modification.mod_id == &"cyclone_twin",
	}

func _get_vortex_count(spell: Spell) -> int:
	var count := 1
	if spell.active_modification:
		count += spell.active_modification.projectile_count_add
	return count

func _get_effective_rotation_speed(spell: Spell) -> float:
	var speed := rotation_speed
	if spell.current_level >= 2:
		speed *= 1.2
	if spell.current_level >= 4:
		speed *= 1.3
	return speed

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.6, 0.9, 1.0)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.3, 0.6, 0.9)
