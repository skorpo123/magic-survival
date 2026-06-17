class_name ThunderboltBehavior
extends BaseSpellBehavior

@export var bolt_range: float = 550.0
@export var chain_count: int = 3

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
	_timer = 0.5

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats

func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_strike()
		var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
		_timer = _spell.get_cooldown(cd_reduction)

func get_cooldown_progress() -> float:
	var cd_reduction: float = _player_stats.cooldown_reduction if _player_stats else 0.0
	var cd: float = _spell.get_cooldown(cd_reduction)
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _timer / cd, 0.0, 1.0)

func _strike() -> void:
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
		var target := SwarmManager.find_closest_pos(pos, bolt_range)
		if target == Vector2.ZERO:
			target = EnemyMeshManager.find_closest_pos(pos, bolt_range)
		if target == Vector2.ZERO:
			continue
		var hit_pos: Vector2 = target
		SwarmManager.damage_area(hit_pos, 25.0, dmg)
		EnemyMeshManager.damage_area(hit_pos, 25.0, dmg)
		RunTracker.record_damage(dmg)
		LightningBehavior.spawn_impact(hit_pos, Color(0.5, 0.8, 1.0), 1.2)

		for _c in range(chain_count):
			var chain_target := SwarmManager.find_closest_pos(hit_pos, bolt_range * 0.3)
			if chain_target != Vector2.ZERO and chain_target != hit_pos:
				SwarmManager.damage_area(chain_target, 20.0, dmg * 0.5)
				LightningBehavior.spawn_impact(chain_target, Color(0.3, 0.5, 1.0), 0.8)
			var mesh_target := EnemyMeshManager.find_closest_pos(hit_pos, bolt_range * 0.3)
			if mesh_target != Vector2.ZERO and mesh_target != hit_pos:
				EnemyMeshManager.damage_area(mesh_target, 20.0, dmg * 0.5)
				LightningBehavior.spawn_impact(mesh_target, Color(0.3, 0.5, 1.0), 0.8)
				hit_pos = mesh_target
	JuiceManager.screen_shake(3.0, 0.08)
