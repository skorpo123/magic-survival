class_name PoisonPoolBehavior
extends BaseSpellBehavior

@export var base_radius: float = 85.0
@export var duration: float = 5.0
@export var damage_interval: float = 0.3
@export var spawn_delay: float = 0.3
@export var base_max_pools: int = 1

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _active_pools: Array = []
var _cast_timer: float = 0.0
var _is_toxic_bloom: bool = false
var _toxic_bloom_damage: float = 0.0
var _toxic_bloom_radius: float = 45.0

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
	_cast_timer = 0.5
	_update_toxic_bloom()

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_spell = spell
	_player_stats = player_stats
	_update_toxic_bloom()

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	_disconnect_toxic_bloom()
	for pool in _active_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	_active_pools.clear()

func tick(delta: float) -> void:
	_cleanup_pools()
	_cast_timer -= delta
	if _cast_timer <= 0.0:
		_spawn_pool()
		_cast_timer = _get_cooldown_time()

func get_cooldown_progress() -> float:
	var cd: float = _get_cooldown_time()
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _cast_timer / cd, 0.0, 1.0)

func _get_max_pools() -> int:
	var extra: int = 0
	if _spell:
		extra = _spell.get_projectile_count() - 1
	return base_max_pools + extra

func _spawn_pool() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var max_pools: int = _get_max_pools()
	while _active_pools.size() >= max_pools:
		var oldest = _active_pools.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var dmg_mult := 1.0
	if _player_stats:
		dmg_mult = _player_stats.magic_power
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, player.global_position)
	_toxic_bloom_damage = dmg * 0.5
	var radius := _get_effective_radius()
	var tint := _get_pool_color()
	var eff_duration := duration
	if _spell:
		eff_duration *= _spell.get_duration_multiplier()
	var pool := PoisonPool.new()
	pool.setup(
		player.global_position,
		radius,
		dmg,
		_get_effective_interval(),
		eff_duration,
		tint
	)
	if _caster_ref:
		_caster_ref.get_tree().root.add_child(pool)
	else:
		player.get_tree().root.add_child(pool)
	_active_pools.append(pool)

func _cleanup_pools() -> void:
	for i in range(_active_pools.size() - 1, -1, -1):
		var p = _active_pools[i]
		if not is_instance_valid(p):
			_active_pools.remove_at(i)

func _get_effective_radius() -> float:
	var r := base_radius
	if _spell:
		r *= _spell.get_area_multiplier()
		if _spell.active_modification:
			r *= _spell.active_modification.zone_radius_mult
	return r

func _get_effective_interval() -> float:
	var interval := damage_interval
	if _spell and _spell.active_modification:
		interval *= _spell.active_modification.damage_interval_mult
	return interval

func _get_cooldown_time() -> float:
	if _spell:
		var cd_reduction: float = 0.0
		if _player_stats:
			cd_reduction = _player_stats.cooldown_reduction
		return _spell.get_cooldown(cd_reduction)
	return 4.0

func _get_pool_color() -> Color:
	if _spell is SpellData and _spell.vfx_color_primary != Color.WHITE:
		return _spell.vfx_color_primary
	if _spell and _spell.active_modification and _spell.active_modification.color_tint != Color.WHITE:
		var tint := _spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 1.0)
	return Color(0.4, 1.0, 0.2)

func _update_toxic_bloom() -> void:
	var should_have: bool = _spell != null and _spell.active_modification != null and _spell.active_modification.mod_id == &"poison_pool_bloom"
	if should_have and not _is_toxic_bloom:
		_is_toxic_bloom = true
		if not EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.connect(_on_enemy_died)
	elif not should_have and _is_toxic_bloom:
		_disconnect_toxic_bloom()

func _disconnect_toxic_bloom() -> void:
	_is_toxic_bloom = false
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, _xp: float, _type: StringName) -> void:
	for pool in _active_pools:
		if not is_instance_valid(pool):
			continue
		if pos.distance_to(pool.global_position) <= pool._radius:
			RunTracker.set_current_spell(_spell.spell_id)
			SwarmManager.damage_area(pos, _toxic_bloom_radius, _toxic_bloom_damage)
			EnemyMeshManager.damage_area(pos, _toxic_bloom_radius, _toxic_bloom_damage)
			RunTracker.record_damage(_toxic_bloom_damage * 2.0)
			BurstEffectPool.spawn("poison", pos, Color(0.4, 1.0, 0.2))
			break
