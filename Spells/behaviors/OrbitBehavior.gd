class_name OrbitBehavior
extends BaseSpellBehavior

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var count := spell.get_projectile_count()
	var angle_step := TAU / maxi(count, 1)
	var scene := load("res://orbit_arcane.tscn") as PackedScene
	if not scene:
		return

	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power

	var pool_name: StringName = &"OrbitArcane"
	if PoolManager.get_available_count(pool_name) == 0 and PoolManager.get_active_count(pool_name) == 0:
		PoolManager.register_pool(pool_name, scene, count)

	var base_radius := 120.0 * spell.get_area_multiplier()
	var base_speed := 2.5
	if spell.active_modification:
		base_radius *= spell.active_modification.orbit_radius_mult
		base_speed *= spell.active_modification.orbit_speed_mult

	var is_cross_storm := spell.active_modification and spell.active_modification.mod_id == &"orbiting_arcana_cross"

	for i in range(count):
		var angle: float
		var reverse := false
		var radius_offset: float
		if is_cross_storm:
			var half := maxi(count / 2, 1)
			if i < half:
				angle = TAU / float(half) * i
				radius_offset = float(i) * 10.0
			else:
				reverse = true
				var rev_count := count - half
				angle = TAU / float(rev_count) * (i - half) + PI / float(maxi(rev_count, 1))
				radius_offset = float(i - half) * 10.0 + 15.0
		else:
			angle = angle_step * i
			radius_offset = float(i) * 10.0
		var proj := PoolManager.spawn(pool_name, caster.global_position)
		if proj:
			if proj.has_method("setup"):
				proj.setup(spell, angle, base_radius + radius_offset, base_speed, reverse, dmg_mult, spell.spell_id)
			if proj.has_method("on_spawn"):
				proj.on_spawn()

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	cast(caster, spell, player_stats)

func on_spell_upgraded(caster: Node2D, spell: Spell, _player_stats: PlayerStats) -> void:
	var pool_name: StringName = &"OrbitArcane"
	PoolManager.despawn_all(pool_name)
	cast(caster, spell, _player_stats)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	PoolManager.despawn_all(&"OrbitArcane")
