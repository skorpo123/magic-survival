class_name FirenadoBehavior
extends BaseSpellBehavior

@export var tornado_speed: float = 150.0
@export var tornado_radius: float = 80.0

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _timer: float = 0.0
var _tornado_pos: Vector2 = Vector2.ZERO
var _tornado_active: bool = false
var _tornado_dir: Vector2 = Vector2.RIGHT
var _tornado_lifetime: float = 0.0

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
	if _tornado_active:
		_tornado_lifetime -= delta
		_tornado_pos += _tornado_dir * tornado_speed * delta
		var dmg_mult := _player_stats.magic_power if _player_stats else 1.0
		var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats) * delta * 1.5
		if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, _tornado_pos)
		RunTracker.set_current_spell(_spell.spell_id)
		var area := tornado_radius * _spell.get_area_multiplier()
		SwarmManager.damage_area(_tornado_pos, area, dmg)
		EnemyMeshManager.damage_area(_tornado_pos, area, dmg)
		RunTracker.record_damage(dmg)
		BurstEffectPool.spawn("spark", _tornado_pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)), Color(1.0, 0.5, 0.1))
		if _tornado_lifetime <= 0.0:
			_tornado_active = false
		return

	_timer -= delta
	if _timer <= 0.0:
		_spawn_tornado()
		var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
		_timer = _spell.get_cooldown(cd_reduction)

func get_cooldown_progress() -> float:
	if _tornado_active:
		return 0.0
	var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
	var cd: float = _spell.get_cooldown(cd_reduction)
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / cd, 0.0, 1.0)

func _spawn_tornado() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	_tornado_pos = player.global_position
	var dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	_tornado_dir = dirs[randi() % dirs.size()]
	_tornado_lifetime = 3.0
	_tornado_active = true
	JuiceManager.screen_shake(2.0, 0.05)
