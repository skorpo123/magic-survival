class_name ProjectileBehavior
extends BaseSpellBehavior

enum Pattern { SINGLE, SPREAD, CIRCLE }

@export var pattern: Pattern = Pattern.SINGLE

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	if requires_aim():
		var aim_dir := _get_aim_direction(caster, spell)
		if aim_dir == Vector2.ZERO:
			return
		match pattern:
			Pattern.SINGLE:
				_cast_single(caster, spell, player_stats, aim_dir)
			Pattern.SPREAD:
				_cast_spread(caster, spell, player_stats, aim_dir)
			Pattern.CIRCLE:
				_cast_circle(caster, spell, player_stats)
	else:
		match pattern:
			Pattern.CIRCLE:
				_cast_circle(caster, spell, player_stats)
			_:
				_cast_single(caster, spell, player_stats, Vector2.RIGHT)

func _cast_single(caster: Node2D, spell: Spell, player_stats: PlayerStats, dir: Vector2) -> void:
	var count := spell.get_projectile_count()
	if count <= 1:
		_spawn_projectile(caster, spell, player_stats, dir)
	else:
		var total_spread := 0.15 * (count - 1)
		var start_angle := dir.angle() - total_spread / 2.0
		for i in range(count):
			_spawn_projectile(caster, spell, player_stats, Vector2.RIGHT.rotated(start_angle + 0.15 * i))

func _cast_spread(caster: Node2D, spell: Spell, player_stats: PlayerStats, base_dir: Vector2) -> void:
	var count := spell.get_projectile_count()
	var total_spread := spell.spread_angle * (count - 1)
	var start_angle := base_dir.angle() - total_spread / 2.0
	for i in range(count):
		_spawn_projectile(caster, spell, player_stats, Vector2.RIGHT.rotated(start_angle + spell.spread_angle * i))

func _cast_circle(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var count := spell.get_projectile_count()
	var angle_step := TAU / maxi(count, 1)
	for i in range(count):
		_spawn_projectile(caster, spell, player_stats, Vector2.RIGHT.rotated(angle_step * i))

func _spawn_projectile(caster: Node2D, spell: Spell, player_stats: PlayerStats, dir: Vector2) -> void:
	var proj := PoolManager.spawn(spell.pool_name, caster.global_position)
	if proj:
		if proj.has_method("setup"):
			proj.setup(dir, spell, player_stats)
		if proj.has_method("on_spawn"):
			proj.on_spawn()

func _get_aim_direction(caster: Node2D, spell: Spell) -> Vector2:
	var range := 550.0
	var closest_pos := Vector2.ZERO
	var closest_vel := Vector2.ZERO
	var closest_dist: float = range + 1.0

	var swarm_result: Dictionary = SwarmManager.find_closest_pos_and_velocity(caster.global_position, range)
	if not swarm_result.is_empty():
		closest_pos = swarm_result[&"pos"]
		closest_vel = swarm_result[&"vel"]
		closest_dist = caster.global_position.distance_to(closest_pos)

	var mesh_result: Dictionary = EnemyMeshManager.find_closest_pos_and_velocity(caster.global_position, range)
	if not mesh_result.is_empty():
		var mesh_pos: Vector2 = mesh_result[&"pos"]
		var mesh_dist: float = caster.global_position.distance_to(mesh_pos)
		if mesh_dist < closest_dist:
			closest_pos = mesh_pos
			closest_vel = mesh_result[&"vel"]
			closest_dist = mesh_dist

	if closest_pos == Vector2.ZERO:
		return Vector2.ZERO

	if closest_vel != Vector2.ZERO and spell.get_speed() > 0.0:
		var travel_time: float = closest_dist / spell.get_speed()
		var lead_dist: float = closest_vel.length() * travel_time
		var lead_ratio: float = clampf(lead_dist / closest_dist, 0.0, 0.4)
		var predicted := closest_pos + closest_vel.normalized() * lead_dist * lead_ratio
		return caster.global_position.direction_to(predicted)
	return caster.global_position.direction_to(closest_pos)
