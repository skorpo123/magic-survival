class_name ToxicNeedlesBehavior
extends BaseSpellBehavior

@export var needle_speed: float = 300.0
@export var pool_radius: float = 40.0

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _timer: float = 0.0

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

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats

func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_fire_volley()
		var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
		_timer = _spell.get_cooldown(cd_reduction)

func get_cooldown_progress() -> float:
	var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
	var cd: float = _spell.get_cooldown(cd_reduction)
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / cd, 0.0, 1.0)

func _fire_volley() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var pos: Vector2 = player.global_position
	var dmg_mult := _player_stats.magic_power if _player_stats else 1.0
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, pos)
	var count := _spell.get_projectile_count()

	RunTracker.set_current_spell(_spell.spell_id)
	for i in range(count):
		var angle := TAU * i / count + randf_range(-0.1, 0.1)
		var dir := Vector2.RIGHT.rotated(angle)
		var hit_pos := pos + dir * 200.0

		var hit_area := 15.0 * _spell.get_area_multiplier()
		SwarmManager.damage_area(hit_pos, hit_area, dmg)
		EnemyMeshManager.damage_area(hit_pos, hit_area, dmg)
		RunTracker.record_damage(dmg)
		BurstEffectPool.spawn("spark", hit_pos, Color(0.3, 0.8, 0.3))

		var pool_pos := hit_pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		var pool_area := pool_radius * _spell.get_area_multiplier()
		SwarmManager.damage_area(pool_pos, pool_area, dmg * 0.3)
		EnemyMeshManager.damage_area(pool_pos, pool_area, dmg * 0.3)
		RunTracker.record_damage(dmg * 0.3)
		BurstEffectPool.spawn("spark", pool_pos, Color(0.6, 0.9, 0.2))
