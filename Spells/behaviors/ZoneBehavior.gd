class_name ZoneBehavior
extends BaseSpellBehavior

@export var zone_radius: float = 80.0
@export var damage_interval: float = 0.5

var _zone: DamageZone = null

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_create_zone(caster, spell, player_stats)

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	if _zone and is_instance_valid(_zone):
		var dmg_mult := 1.0
		if player_stats:
			dmg_mult = player_stats.magic_power
		var _dmg := spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
		if spell.was_last_crit(): EventBus.crit_landed.emit(_dmg, caster.global_position)
		_zone.update_params(
			_get_effective_radius(spell),
			_dmg,
			_get_effective_interval(spell)
		)
	else:
		_create_zone(caster, spell, player_stats)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	if _zone and is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null

func _create_zone(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power
	_zone = DamageZone.new()
	var _dmg := spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(_dmg, player.global_position)
	_zone.setup(
		player,
		_get_effective_radius(spell),
		_dmg,
		_get_effective_interval(spell),
		spell.color,
		spell.spell_id
	)
	caster.add_child(_zone)

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
