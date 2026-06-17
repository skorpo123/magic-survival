class_name MeteorBehavior
extends BaseSpellBehavior

const FALL_ANGLE_DEG: float = 60.0
const FLIGHT_DISTANCE: float = 500.0
const MIN_RANGE: float = 100.0

var _caster: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _meteor_scene: PackedScene = preload("res://meteor.tscn")
var _active_meteors: Array = []

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return false

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var target_pos := _find_target(caster)
	if target_pos == Vector2.ZERO:
		return

	var go_right: bool = target_pos.x > caster.global_position.x
	var angle_rad := deg_to_rad(FALL_ANGLE_DEG)
	var dir_x: float = cos(angle_rad) * (1.0 if go_right else -1.0)
	var dir_y: float = sin(angle_rad)
	var fall_dir := Vector2(dir_x, dir_y).normalized()

	var start_pos := target_pos - fall_dir * FLIGHT_DISTANCE

	var meteor: MeteorProjectile = _meteor_scene.instantiate() as MeteorProjectile
	if not meteor:
		return

	meteor.global_position = start_pos
	meteor.setup(fall_dir, spell, player_stats)
	meteor.set_target(target_pos, FLIGHT_DISTANCE)

	var tree := Engine.get_main_loop() as SceneTree
	var scene_root := tree.current_scene if tree else null
	if scene_root:
		scene_root.add_child(meteor)
	meteor.on_spawn()
	_active_meteors.append(meteor)

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster = caster
	_spell = spell
	_player_stats = player_stats

func on_spell_upgraded(_caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_spell = spell
	_player_stats = player_stats

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	for m in _active_meteors:
		if is_instance_valid(m):
			m.on_despawn()
			m.queue_free()
	_active_meteors.clear()

func tick(_delta: float) -> void:
	_active_meteors = _active_meteors.filter(func(m) -> bool: return is_instance_valid(m))

func _find_target(caster: Node2D) -> Vector2:
	var origin := caster.global_position
	var best_pos := Vector2.ZERO
	var min_dist := MIN_RANGE

	var swarm_pos := SwarmManager.find_closest_pos(origin, 550.0)
	if swarm_pos != Vector2.ZERO:
		var d := origin.distance_to(swarm_pos)
		if d < 550.0:
			best_pos = swarm_pos
			min_dist = d

	var mesh_pos := EnemyMeshManager.find_closest_pos(origin, 550.0)
	if mesh_pos != Vector2.ZERO:
		var d := origin.distance_to(mesh_pos)
		if d < min_dist:
			best_pos = mesh_pos

	return best_pos
