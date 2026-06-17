class_name FrostLanceBehavior
extends BaseSpellBehavior

@export var lance_range: float = 200.0
@export var lance_count: int = 2

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _timer: float = 0.0

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return true

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats
	_timer = 0.0

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats

func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_throw_lance()
		var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
		_timer = _spell.get_cooldown(cd_reduction)

func get_cooldown_progress() -> float:
	var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
	var cd: float = _spell.get_cooldown(cd_reduction)
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / cd, 0.0, 1.0)

func _throw_lance() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var pos: Vector2 = player.global_position
	var dmg_mult := _player_stats.magic_power if _player_stats else 1.0
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, pos)

	RunTracker.set_current_spell(_spell.spell_id)
	for _i in range(lance_count):
		var target := SwarmManager.find_closest_pos(pos, lance_range)
		if target == Vector2.ZERO:
			target = EnemyMeshManager.find_closest_pos(pos, lance_range)
		if target == Vector2.ZERO:
			continue
		SwarmManager.damage_area(target, 25.0, dmg)
		EnemyMeshManager.damage_area(target, 25.0, dmg)
		RunTracker.record_damage(dmg)
		BurstEffectPool.spawn("impact", target, Color(0.4, 0.7, 0.9))
	JuiceManager.screen_shake(3.0, 0.08)
