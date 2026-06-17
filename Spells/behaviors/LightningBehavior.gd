class_name LightningBehavior
extends BaseSpellBehavior

@export var strike_range: float = 550.0
@export var chain_count: int = 0
@export var chain_range: float = 150.0
@export var chain_damage_mult: float = 0.5
@export var bolt_segments: int = 18
@export var bolt_jitter: float = 20.0

const IMPACT_POOL_SIZE: int = 16
static var _impact_pool: Array[LightningImpact] = []
static var _impact_pool_parent: Node = null

static func _ensure_impact_pool() -> void:
	if _impact_pool.size() >= IMPACT_POOL_SIZE:
		return
	if not _impact_pool_parent or not is_instance_valid(_impact_pool_parent):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			_impact_pool_parent = tree.current_scene
		else:
			return
	for i in range(IMPACT_POOL_SIZE - _impact_pool.size()):
		var imp := LightningImpact.new()
		_impact_pool_parent.add_child(imp)
		_impact_pool.append(imp)

static func _acquire_impact() -> LightningImpact:
	_ensure_impact_pool()
	for imp in _impact_pool:
		if not imp._active:
			return imp
	var imp := LightningImpact.new()
	if _impact_pool_parent and is_instance_valid(_impact_pool_parent):
		_impact_pool_parent.add_child(imp)
	_impact_pool.append(imp)
	return imp

static func spawn_impact(pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	var imp := _acquire_impact()
	imp.activate(pos, color, scale_mult)

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var strike_count := spell.get_projectile_count()
	var strike_targets := _find_nearest_n_positions(caster.global_position, strike_range, strike_count)
	if strike_targets.is_empty():
		return

	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power
	var damage := spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(damage, caster.global_position)

	var viewport := caster.get_viewport()
	var cam := caster.get_node_or_null("Camera2D") as Camera2D
	var sky_y: float
	if cam:
		var half_h := viewport.get_visible_rect().size.y / (2.0 * cam.zoom.y)
		sky_y = cam.global_position.y - half_h - 50.0
	else:
		sky_y = caster.global_position.y - 500.0

	var spell_color := _get_primary_color(spell)

	var is_overcharge := spell.active_modification and spell.active_modification.mod_id == &"lightning_strike_overcharge"
	var has_explode_mod := spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.EXPLODE
	var disable_chains := is_overcharge

	for strike_idx in range(strike_targets.size()):
		var strike_pos: Vector2 = strike_targets[strike_idx]

		var primary_radius: float = 60.0 if is_overcharge else 40.0
		RunTracker.set_current_spell(spell.spell_id)
		SwarmManager.damage_area(strike_pos, primary_radius, damage)
		EnemyMeshManager.damage_area(strike_pos, primary_radius, damage)

		if has_explode_mod:
			var area_mult := spell.get_area_multiplier()
			var explode_radius := 50.0 * area_mult
			var explode_dmg := damage * 0.4
			RunTracker.set_current_spell(spell.spell_id)
			SwarmManager.damage_area(strike_pos, explode_radius, explode_dmg)
			EnemyMeshManager.damage_area(strike_pos, explode_radius, explode_dmg)
			RunTracker.record_damage(explode_dmg * 2.0)
			BurstEffectPool.spawn("explosion", strike_pos, _get_secondary_color(spell), clampf(explode_radius / 50.0, 0.3, 5.0))

		var impact_scale: float = 1.5 if is_overcharge else 1.0
		LightningBehavior.spawn_impact(strike_pos, spell_color, impact_scale)

		var struck_positions: Array[Vector2] = [Vector2(strike_pos.x + randf_range(-20.0, 20.0), sky_y), strike_pos]

		if not disable_chains:
			var chains := _get_chain_count(spell)
			if chains > 0:
				var chain_search_range := _get_chain_range(spell)
				var chain_dmg_mult := _get_chain_damage_mult(spell)
				var current_pos: Vector2 = strike_pos
				for _i in range(chains):
					var chain_pos := _find_next_chain_pos(current_pos, chain_search_range, damage * chain_dmg_mult, spell.spell_id)
					if chain_pos == Vector2.ZERO:
						break
					struck_positions.append(current_pos)
					struck_positions.append(chain_pos)
					current_pos = chain_pos

		_spawn_single_strike_visuals(struck_positions, caster, spell_color, is_overcharge, spell)

	JuiceManager.screen_shake(4.0, 0.12)
	JuiceManager.hitstop(0.06)

func _find_nearest_n_positions(center: Vector2, range_dist: float, count: int) -> Array[Vector2]:
	var all_pos: Array[Vector2] = []
	var range_sq: float = range_dist * range_dist

	var s_px: PackedFloat32Array = SwarmManager._px
	var s_py: PackedFloat32Array = SwarmManager._py
	var s_hp: PackedFloat32Array = SwarmManager._hp
	for i in range(s_px.size()):
		if s_hp[i] <= 0.0:
			continue
		var ddx: float = s_px[i] - center.x
		var ddy: float = s_py[i] - center.y
		if ddx * ddx + ddy * ddy <= range_sq:
			all_pos.append(Vector2(s_px[i], s_py[i]))

	for key in EnemyMeshManager._type_data:
		var td: Dictionary = EnemyMeshManager._type_data[key]
		var d: PackedFloat32Array = td.d
		for j in td.alive_indices:
			var off: int = j * EnemyMeshManager.FIELDS
			var ddx: float = d[off] - center.x
			var ddy: float = d[off + 1] - center.y
			if ddx * ddx + ddy * ddy <= range_sq:
				all_pos.append(Vector2(d[off], d[off + 1]))

	all_pos.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return center.distance_squared_to(a) < center.distance_squared_to(b)
	)

	if all_pos.size() > count:
		all_pos = all_pos.slice(0, count)
	return all_pos

func _get_chain_count(spell: Spell) -> int:
	return spell.get_chain_count(chain_count)

func _get_chain_range(spell: Spell) -> float:
	var r := chain_range
	if spell.active_modification:
		r = maxf(r, spell.active_modification.chain_range)
	return r

func _get_chain_damage_mult(spell: Spell) -> float:
	var mult := chain_damage_mult
	if spell.active_modification:
		mult = maxf(mult, spell.active_modification.chain_damage_mult)
	return mult

func _find_next_chain_pos(source_pos: Vector2, p_range: float, chain_damage: float, spell_id: StringName = &"") -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = p_range
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(source_pos, p_range)
	if swarm_pos != Vector2.ZERO:
		var swarm_dist: float = source_pos.distance_to(swarm_pos)
		if swarm_dist < min_dist:
			min_dist = swarm_dist
			best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(source_pos, p_range)
	if mesh_pos != Vector2.ZERO:
		var mesh_dist: float = source_pos.distance_to(mesh_pos)
		if mesh_dist < min_dist:
			min_dist = mesh_dist
			best_pos = mesh_pos
	if best_pos != Vector2.ZERO:
		RunTracker.set_current_spell(spell_id)
		SwarmManager.damage_area(best_pos, 30.0, chain_damage)
		EnemyMeshManager.damage_area(best_pos, 30.0, chain_damage)
		RunTracker.record_damage(chain_damage)
	return best_pos

func _spawn_single_strike_visuals(segments: Array[Vector2], caster: Node2D, spell_color: Color, is_overcharge: bool, spell: Spell) -> void:
	var parent := caster.get_tree().current_scene
	if not parent:
		return

	var is_chain_amp := spell.active_modification and spell.active_modification.mod_id == &"lightning_strike_chain"
	var is_rapid := spell.active_modification and spell.active_modification.mod_id == &"lightning_strike_rapid"

	for i in range(0, segments.size() - 1, 2):
		var start := segments[i]
		var end := segments[i + 1]
		var is_main_bolt := i == 0
		var is_chain_segment := not is_main_bolt

		var bolt := LightningBolt.acquire()

		if is_main_bolt:
			if is_overcharge:
				bolt._bolt_color = Color(1.4, 1.3, 0.9)
				bolt._glow_color = Color(1.0, 0.95, 0.7, 0.55)
				bolt._core_color = Color(1.6, 1.6, 1.5)
				bolt._lifetime = 0.45
				bolt._glow_width = 22.0
				bolt._bolt_width = 10.0
				bolt._core_width = 3.5
			elif is_rapid:
				bolt._bolt_color = Color(0.4, 1.0, 1.4)
				bolt._glow_color = Color(0.2, 0.5, 0.9, 0.4)
				bolt._core_color = Color(1.2, 1.2, 1.2)
				bolt._lifetime = 0.2
				bolt._glow_width = 10.0
				bolt._bolt_width = 5.0
				bolt._core_width = 1.8
			else:
				bolt._bolt_color = Color(spell_color.r * 0.7 + 0.3, spell_color.g * 0.7 + 0.3, spell_color.b * 0.7 + 0.3)
				bolt._glow_color = Color(spell_color.r * 0.4, spell_color.g * 0.4, spell_color.b, 0.3)
				bolt._core_color = Color(1.4, 1.4, 1.5)
				bolt._lifetime = 0.35
				bolt._glow_width = 14.0
				bolt._bolt_width = 6.0
				bolt._core_width = 2.0
			bolt.setup(start, end, bolt_segments, bolt_jitter)
		else:
			if is_chain_amp:
				bolt._bolt_color = Color(0.3, 1.0, 1.2)
				bolt._glow_color = Color(0.2, 0.6, 0.9, 0.5)
			else:
				bolt._bolt_color = Color(spell_color.r * 0.6 + 0.4, spell_color.g * 0.6 + 0.4, spell_color.b * 0.6 + 0.4, 0.9)
				bolt._glow_color = Color(spell_color.r * 0.3, spell_color.g * 0.3, spell_color.b, 0.2)
			bolt._core_color = Color(1.0, 1.0, 1.1)
			bolt._lifetime = 0.25
			bolt._glow_width = 8.0
			bolt._bolt_width = 3.0
			bolt._core_width = 1.0
			bolt.setup(start, end, 10, bolt_jitter * 0.5)

		if is_chain_amp and is_chain_segment:
			_spawn_chain_arc(start, end)

		var end_impact_scale: float = 1.5 if is_overcharge else 1.0
		LightningBehavior.spawn_impact(end, spell_color, end_impact_scale)

func _spawn_chain_arc(start: Vector2, end: Vector2) -> void:
	var arc := LightningBolt.acquire()
	arc._bolt_color = Color(0.3, 1.0, 1.2, 0.4)
	arc._glow_color = Color(0.3, 1.0, 1.2, 0.0)
	arc._core_color = Color(0.3, 1.0, 1.2, 0.0)
	arc._lifetime = 0.2
	arc._glow_width = 4.0
	arc._bolt_width = 2.0
	arc._core_width = 0.0
	arc.setup(start, end, 6, 12.0)

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.5, 0.8, 1.0)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.3, 0.5, 1.0)
