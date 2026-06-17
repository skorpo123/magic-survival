class_name ElectricZoneBehavior
extends BaseSpellBehavior

@export var zone_radius: float = 90.0
@export var damage_interval: float = 0.6
@export var arc_count: int = 3

var _field: ElectricField = null

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_create_field(caster, spell, player_stats)

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	if _field and is_instance_valid(_field):
		var dmg_mult := 1.0
		if player_stats:
			dmg_mult = player_stats.magic_power
		var _dmg := spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
		if spell.was_last_crit(): EventBus.crit_landed.emit(_dmg, caster.global_position)
		_field.update_params(
			_get_effective_radius(spell),
			_dmg,
			_get_effective_interval(spell),
			_get_effective_arc_count(spell),
			_get_chain_count(spell)
		)
		_apply_spell_color(spell)
	else:
		_create_field(caster, spell, player_stats)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	if _field and is_instance_valid(_field):
		_field.cleanup()
		_field.queue_free()
	_field = null

func _create_field(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power
	_field = ElectricField.new()
	var is_shockwave := spell.active_modification and spell.active_modification.mod_id == &"electric_zone_shockwave"
	var is_arc_flash := spell.active_modification and spell.active_modification.mod_id == &"electric_zone_arc"
	var _dmg := spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(_dmg, player.global_position)
	_field.setup(
		player,
		_get_effective_radius(spell),
		_dmg,
		_get_effective_interval(spell),
		_get_effective_arc_count(spell),
		_get_primary_color(spell),
		_get_secondary_color(spell),
		_get_chain_count(spell),
		150.0,
		0.5,
		is_shockwave,
		3.0,
		is_arc_flash
	)
	caster.add_child(_field)

func _apply_spell_color(spell: Spell) -> void:
	if not _field or not is_instance_valid(_field):
		return
	_field.set_colors(_get_primary_color(spell), _get_secondary_color(spell))

func _get_effective_radius(spell: Spell) -> float:
	var r := zone_radius * spell.get_area_multiplier()
	if spell.active_modification:
		r *= spell.active_modification.zone_radius_mult
	return r

func _get_effective_interval(spell: Spell) -> float:
	var interval := damage_interval
	if spell.active_modification:
		interval *= spell.active_modification.damage_interval_mult
	return interval

func _get_effective_arc_count(spell: Spell) -> int:
	var count := arc_count
	if spell.current_level >= 3:
		count += 1
	if spell.current_level >= 5:
		count += 2
	return count

func _get_chain_count(spell: Spell) -> int:
	if spell.active_modification and spell.active_modification.mod_id == &"electric_zone_chain":
		return 3
	return 0

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.6, 0.8, 1.0)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.3, 0.5, 1.0)
