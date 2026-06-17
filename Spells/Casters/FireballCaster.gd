class_name FireballCaster extends SpellCaster

func _cast_single(dir: Vector2, player_stats: PlayerStats) -> void:
	var proj := PoolManager.spawn(spell.pool_name, global_position)
	if proj:
		if proj.has_method("setup"):
			proj.setup(dir, spell, player_stats)
		if proj.has_method("on_spawn"):
			proj.on_spawn()
