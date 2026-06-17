class_name AstralSwarmBehavior
extends BaseSpellBehavior

@export var orb_count: int = 3
@export var attack_range: float = 500.0

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _timer: float = 0.0
var _orb_positions: Array[Vector2] = []
var _orb_angles: Array[float] = []

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats
	_timer = 0.0
	var count := _get_orb_count()
	_orb_positions.resize(count)
	_orb_angles.resize(count)
	for i in range(count):
		_orb_angles[i] = TAU * i / count

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats

func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_fire_orbs()
		var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
		_timer = _spell.get_cooldown(cd_reduction)

func get_cooldown_progress() -> float:
	var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
	var cd: float = _spell.get_cooldown(cd_reduction)
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / cd, 0.0, 1.0)

func _fire_orbs() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var pos: Vector2 = player.global_position
	var dmg_mult := _player_stats.magic_power if _player_stats else 1.0
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, pos)
	var count := _get_orb_count()

	RunTracker.set_current_spell(_spell.spell_id)
	for i in range(count):
		var target := SwarmManager.find_closest_pos(pos, attack_range)
		if target == Vector2.ZERO:
			target = EnemyMeshManager.find_closest_pos(pos, attack_range)
		if target == Vector2.ZERO:
			target = pos + Vector2.RIGHT.rotated(TAU * i / count) * attack_range

		var spread := Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		var hit_pos := target + spread
		SwarmManager.damage_area(hit_pos, 20.0, dmg)
		EnemyMeshManager.damage_area(hit_pos, 20.0, dmg)
		RunTracker.record_damage(dmg)
		BurstEffectPool.spawn("spark", hit_pos, Color(0.7, 0.6, 1.0))

func _get_orb_count() -> int:
	var count: int = orb_count
	if _spell:
		count += _spell.get_projectile_count() - 1
	return maxi(count, 1)
