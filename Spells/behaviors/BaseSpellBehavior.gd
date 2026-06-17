class_name BaseSpellBehavior
extends Resource

var _spell_id: StringName = &""

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return true

func on_spell_added(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_upgraded(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	pass

func tick(_delta: float) -> void:
	pass

func get_cooldown_progress() -> float:
	return -1.0

func _track_damage(spell: Spell, amount: float) -> void:
	if amount <= 0.0:
		return
	RunTracker.set_current_spell(spell.spell_id)
	RunTracker.record_damage(amount)

func _get_closest_enemy_pos(pos: Vector2, p_range: float) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = p_range
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(pos, p_range)
	if swarm_pos != Vector2.ZERO:
		min_dist = pos.distance_to(swarm_pos)
		best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(pos, p_range)
	if mesh_pos != Vector2.ZERO:
		var mesh_dist: float = pos.distance_to(mesh_pos)
		if mesh_dist < min_dist:
			best_pos = mesh_pos
	return best_pos
