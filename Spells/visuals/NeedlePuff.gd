class_name NeedlePuff
extends Node2D

enum State { FLY_OUT, STABBED, FLY_BACK, DEAD }

var _direction: Vector2 = Vector2.RIGHT
var _range: float = 220.0
var _speed: float = 500.0
var _damage: float = 10.0
var _mod_tint: Color = Color.WHITE
var _start_pos: Vector2 = Vector2.ZERO
var _traveled: float = 0.0
var _alive: bool = false
var _state: int = State.DEAD
var _mod_type: int = 0
var _spell_ref: Spell = null
var _visual_mult: float = 1.0
var _hit_swarm: Dictionary = {}
var _hit_mesh: Dictionary = {}
var _slow_applied: bool = false
var _damage_half_w: float = 6.0
var _stab_timer: float = 0.0
var _stab_pulse_timer: float = 0.0
var _stab_pulse_count: int = 0
var _return_pierced: Dictionary = {}
var _return_pierce_ratio: float = 0.5
var _return_detect_radius: float = 30.0
var _stabbed_duration: float = 0.5
var _stuck_pos: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var _pierce_dmg: float = 0.0
var _hit_enemy: bool = false
var _return_speed_mult: float = 1.3
var _thread_time: float = 0.0
var _ricochet_bounces: int = 0
const MAX_RICOCHET: int = 3

const NEEDLE_LENGTH: float = 70.0
const STAB_PULSE_INTERVAL: float = 0.15
const THREAD_WOBBLE_FREQ: float = 3.0
const THREAD_WOBBLE_AMP: float = 2.0

const STRIPS: int = 10
const _LAYER_COUNT: int = 2
const _L_LENGTH := [1.0, 0.7]
const _L_BASE_HALF_W := [1.8, 5.0]
const _L_ALPHA := [1.0, 0.25]
const _L_CORE_COLOR := [
	Color(0.85, 0.75, 0.95),
	Color(0.5, 0.35, 0.7),
]
const _L_TIP_COLOR := [
	Color(2.2, 2.1, 2.6),
	Color(0.9, 0.8, 1.2),
]

var _mesh_instance: MeshInstance2D = null
var _mesh: ArrayMesh = null
var _sparks: GPUParticles2D = null

static var _shared_mat: CanvasItemMaterial = null

signal returned_to_player

func _ready() -> void:
	top_level = true
	z_index = 2
	visible = false
	material = _get_shared_mat()
	_init_mesh()
	_init_sparks()
	set_process(false)

func _init_mesh() -> void:
	_mesh_instance = MeshInstance2D.new()
	_mesh_instance.material = _shared_mat
	_mesh_instance.z_index = z_index
	add_child(_mesh_instance)
	_mesh = ArrayMesh.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.visible = false

func _init_sparks() -> void:
	var glow_tex := VFXManager._glow_tex
	_sparks = GPUParticles2D.new()
	_sparks.one_shot = false
	_sparks.local_coords = false
	_sparks.z_index = 5
	_sparks.visible = false
	_sparks.texture = glow_tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = mat
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 2.0
	sp.direction = Vector3(1, 0, 0)
	sp.spread = 8.0
	sp.initial_velocity_min = 80.0
	sp.initial_velocity_max = 200.0
	sp.gravity = Vector3(0, 0, 0)
	sp.scale_min = 0.2
	sp.scale_max = 0.5
	sp.color = Color(0.75, 0.6, 0.95, 0.8)
	sp.particle_flag_disable_z = true
	_sparks.process_material = sp
	_sparks.amount = 3
	_sparks.lifetime = 0.08
	add_child(_sparks)

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_mat

func launch(origin: Vector2, dir: Vector2, needle_range: float, speed: float, damage: float, spell: Spell, mod_type: int, tint: Color = Color.WHITE, return_pierce_ratio_val: float = 0.5, return_detect_radius_val: float = 30.0, stabbed_duration_val: float = 0.5) -> void:
	global_position = origin
	_start_pos = origin
	_origin = origin
	_direction = dir.normalized()
	_range = needle_range
	_speed = speed
	_damage = damage
	_pierce_dmg = damage * return_pierce_ratio_val
	_return_pierce_ratio = return_pierce_ratio_val
	_return_detect_radius = return_detect_radius_val
	_stabbed_duration = stabbed_duration_val
	_spell_ref = spell
	_visual_mult = sqrt(spell.get_area_multiplier()) if spell else 1.0
	_mod_type = mod_type
	_mod_tint = tint
	_traveled = 0.0
	_alive = true
	_state = State.FLY_OUT
	_hit_enemy = false
	_hit_swarm.clear()
	_hit_mesh.clear()
	_return_pierced.clear()
	_slow_applied = false
	_stab_timer = 0.0
	_stab_pulse_timer = 0.0
	_stab_pulse_count = 0
	_thread_time = 0.0
	_ricochet_bounces = 0
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	visible = true
	set_process(true)
	_update_sparks(_direction, tint, true)
	_build_mesh(1.0)

func kill() -> void:
	_alive = false
	_state = State.DEAD
	visible = false
	set_process(false)
	_sparks.emitting = false
	_sparks.visible = false
	if _mesh_instance:
		_mesh_instance.visible = false
	if _mesh:
		_mesh.clear_surfaces()
	_hit_swarm.clear()
	_hit_mesh.clear()
	_return_pierced.clear()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _alive:
		return
	_thread_time += delta
	match _state:
		State.FLY_OUT:
			_process_fly_out(delta)
		State.STABBED:
			_process_stabbed(delta)
		State.FLY_BACK:
			_process_fly_back(delta)
	if _state == State.FLY_OUT or _state == State.STABBED:
		queue_redraw()

func _process_fly_out(delta: float) -> void:
	var step := _speed * delta
	global_position += _direction * step
	_traveled += step
	_deal_path_damage()
	if _mod_type == 2 and not _slow_applied and _traveled >= _range * 0.5:
		_apply_frost_slow()
		_slow_applied = true
	if _hit_enemy:
		_begin_stabbed()
		return
	if _traveled >= _range:
		_begin_return()

func _process_stabbed(delta: float) -> void:
	_stab_timer += delta
	_stab_pulse_timer += delta
	if _stab_pulse_timer >= STAB_PULSE_INTERVAL:
		_stab_pulse_timer -= STAB_PULSE_INTERVAL
		_stab_pulse_count += 1
		if _stab_pulse_count <= 3:
			_build_mesh(1.0 + float(_stab_pulse_count) * 0.4)
			BurstEffectPool.spawn("arcane_impact", global_position + _direction * NEEDLE_LENGTH * _visual_mult * 0.5, _mod_tint)
	if _mod_type == 2:
		_apply_frost_at_pos(global_position)
	if _stab_timer >= _stabbed_duration:
		_begin_return()

func _process_fly_back(delta: float) -> void:
	var player := GameManager.get_player()
	if not player:
		kill()
		return
	var to_player := player.global_position - global_position
	var dist_sq := to_player.length_squared()
	if dist_sq < 400.0:
		returned_to_player.emit()
		kill()
		return
	var to_dir := to_player.normalized()
	_direction = to_dir
	global_position += to_dir * _speed * _return_speed_mult * delta
	_deal_return_pierce()
	_build_mesh(1.0)

func _deal_path_damage() -> void:
	var from: Vector2 = _start_pos if _traveled < _range else _start_pos
	var to: Vector2 = global_position
	if from.distance_squared_to(to) < 1.0:
		return
	var hit_s := SwarmManager.damage_rect_filtered(from, to, _damage_half_w, _damage, _hit_swarm)
	var hit_m := EnemyMeshManager.damage_rect_filtered(from, to, _damage_half_w, _damage, _hit_mesh)
	if (hit_s > 0 or hit_m > 0) and not _hit_enemy:
		_hit_enemy = true

func _deal_return_pierce() -> void:
	var closest_s := SwarmManager.find_closest_pos(global_position, _return_detect_radius)
	var closest_m := EnemyMeshManager.find_closest_pos(global_position, _return_detect_radius)
	var best_pos := Vector2.ZERO
	var best_dist_sq := _return_detect_radius * _return_detect_radius
	if closest_s != Vector2.ZERO:
		var ds := global_position.distance_squared_to(closest_s)
		if ds < best_dist_sq and not _return_pierced.has(closest_s):
			best_dist_sq = ds
			best_pos = closest_s
			_return_pierced[closest_s] = true
	if closest_m != Vector2.ZERO:
		var dm := global_position.distance_squared_to(closest_m)
		if dm < best_dist_sq and not _return_pierced.has(closest_m):
			best_dist_sq = dm
			best_pos = closest_m
			_return_pierced[closest_m] = true
	if best_pos != Vector2.ZERO:
		SwarmManager.damage_area(best_pos, _return_detect_radius * 0.5, _pierce_dmg)
		EnemyMeshManager.damage_area(best_pos, _return_detect_radius * 0.5, _pierce_dmg)

func _begin_stabbed() -> void:
	_state = State.STABBED
	_stuck_pos = global_position
	_stab_timer = 0.0
	_stab_pulse_timer = 0.0
	_stab_pulse_count = 0
	_sparks.emitting = false
	_sparks.visible = false
	_build_mesh(1.4)

func _begin_return() -> void:
	_spawn_thread_dissolve()
	if _mod_type == 3 and _ricochet_bounces < MAX_RICOCHET:
		_ricochet_bounces += 1
		var next_pos := _find_ricochet_target()
		if next_pos != Vector2.ZERO:
			_state = State.FLY_OUT
			_direction = (next_pos - global_position).normalized()
			_start_pos = global_position
			_traveled = 0.0
			_hit_enemy = false
			_range = 300.0
			_update_sparks(_direction, _mod_tint, true)
			_build_mesh(1.0)
			return
	_state = State.FLY_BACK
	_update_sparks(-_direction, _mod_tint, true)

func _find_ricochet_target() -> Vector2:
	var search_r: float = 200.0
	var closest_s := SwarmManager.find_closest_pos(global_position, search_r)
	var closest_m := EnemyMeshManager.find_closest_pos(global_position, search_r)
	var best_pos := Vector2.ZERO
	var best_dist_sq := search_r * search_r
	if closest_s != Vector2.ZERO:
		var ds := global_position.distance_squared_to(closest_s)
		if ds > 100.0 and ds < best_dist_sq:
			best_dist_sq = ds
			best_pos = closest_s
	if closest_m != Vector2.ZERO:
		var dm := global_position.distance_squared_to(closest_m)
		if dm > 100.0 and dm < best_dist_sq:
			best_dist_sq = dm
			best_pos = closest_m
	return best_pos

func _spawn_thread_dissolve() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var mid := (player.global_position + global_position) * 0.5
	BurstEffectPool.spawn("arcane_impact", mid, _mod_tint)

func _apply_frost_slow() -> void:
	var tip := global_position
	SwarmManager.apply_slow(tip, _range, 3.5)
	EnemyMeshManager.apply_slow(tip, _range, 3.5)
	var player := GameManager.get_player()
	if player:
		for node in player.get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(node) and node is BaseEnemy and node._is_active:
				if node.global_position.distance_squared_to(tip) <= _range * _range:
					node.apply_slow(3.5)

func _apply_frost_at_pos(pos: Vector2) -> void:
	SwarmManager.apply_slow(pos, 40.0, 3.5)
	EnemyMeshManager.apply_slow(pos, 40.0, 3.5)

func _draw() -> void:
	if not _alive:
		return
	if _state == State.FLY_OUT or _state == State.STABBED:
		var player := GameManager.get_player()
		if not player:
			return
		var ear_pos_local := -_direction * NEEDLE_LENGTH * _visual_mult * 0.1
		var player_pos_local := to_local(player.global_position)
		var perp := Vector2(-_direction.y, _direction.x)
		var segments := 8
		var points := PackedVector2Array()
		for i in range(segments + 1):
			var t: float = float(i) / float(segments)
			var p: Vector2 = player_pos_local.lerp(ear_pos_local, t)
			p += perp * sin(_thread_time * THREAD_WOBBLE_FREQ + t * TAU) * THREAD_WOBBLE_AMP * t
			points.append(p)
		for i in range(segments):
			var alpha: float = 0.6 * (1.0 - float(i) / float(segments) * 0.3)
			var c: Color = Color(0.6, 0.45, 0.85, alpha)
			if _mod_tint != Color.WHITE:
				c = Color(_mod_tint.r * 0.7, _mod_tint.g * 0.6, _mod_tint.b * 0.9, alpha)
			draw_line(points[i], points[i + 1], c, 1.4, true)

func _build_mesh(alpha_mult: float) -> void:
	var perp := Vector2(-_direction.y, _direction.x)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var needle_len := NEEDLE_LENGTH * _visual_mult

	for layer in range(_LAYER_COUNT):
		_build_needle_mesh(layer, needle_len, perp, alpha_mult, vertices, colors)

	if alpha_mult > 0.3:
		var glow_r: float = 4.0 * alpha_mult
		_add_circle(vertices, colors, _direction * needle_len, glow_r, Color(2.5, 2.2, 2.9, 0.5 * alpha_mult), 8)

	_build_ear(vertices, colors, perp, alpha_mult)
	_build_engravings(vertices, colors, perp, alpha_mult)

	if vertices.size() == 0:
		_mesh.clear_surfaces()
		_mesh_instance.visible = false
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.visible = true
	queue_redraw()

func _build_needle_mesh(layer: int, length: float, perp: Vector2, alpha_mult: float, vertices: PackedVector3Array, colors: PackedColorArray) -> void:
	var base_hw: float = _L_BASE_HALF_W[layer]
	var layer_len: float = _L_LENGTH[layer] * length
	var base_alpha: float = _L_ALPHA[layer] * alpha_mult
	if layer == 0:
		base_alpha *= 1.3
	var left_pts := PackedVector2Array()
	var right_pts := PackedVector2Array()

	for s in range(STRIPS + 1):
		var t: float = float(s) / float(STRIPS)
		var hw: float = base_hw * (1.0 - t * t * t)
		var fwd := _direction * layer_len * t
		left_pts.append(fwd + perp * hw)
		right_pts.append(fwd - perp * hw)

	for s in range(STRIPS):
		var a := left_pts[s]
		var b := right_pts[s]
		var c := right_pts[s + 1]
		var d := left_pts[s + 1]
		var seg_t := (float(s) + 0.5) / float(STRIPS)
		var color := _gradient_color(seg_t, layer, base_alpha)
		var area1 := _triangle_area(a, b, c)
		var area2 := _triangle_area(a, c, d)
		if area1 > 0.1:
			_add_tri(vertices, colors, a, b, c, color)
		if area2 > 0.1:
			_add_tri(vertices, colors, a, c, d, color)

func _build_ear(vertices: PackedVector3Array, colors: PackedColorArray, perp: Vector2, alpha_mult: float) -> void:
	var base_center := Vector2.ZERO
	var ear_hw: float = 3.0
	var ear_h: float = 5.0
	var base_alpha := minf(alpha_mult * 0.9, 1.5)
	var c := Color(0.7, 0.6, 0.9, base_alpha * 0.5)
	if _mod_tint != Color.WHITE:
		c = Color(_mod_tint.r * 0.7, _mod_tint.g * 0.6, _mod_tint.b * 0.9, base_alpha * 0.5)
	var tl := base_center + perp * ear_h - _direction * ear_hw
	var tr := base_center + perp * ear_h + _direction * ear_hw
	var bl := base_center - perp * ear_h - _direction * ear_hw
	var br := base_center - perp * ear_h + _direction * ear_hw
	_add_tri(vertices, colors, tl, tr, bl, c)
	_add_tri(vertices, colors, tr, br, bl, c)

func _build_engravings(vertices: PackedVector3Array, colors: PackedColorArray, perp: Vector2, alpha_mult: float) -> void:
	var c := Color(0.6, 0.5, 0.8, alpha_mult * 0.4)
	if _mod_tint != Color.WHITE:
		c = Color(_mod_tint.r * 0.5, _mod_tint.g * 0.4, _mod_tint.b * 0.7, alpha_mult * 0.4)
	for i in range(4):
		var t := 0.2 + float(i) * 0.15
		var pos := _direction * NEEDLE_LENGTH * _visual_mult * t
		var notch_hw := 0.3
		var notch_hh := 2.0
		var a := pos + perp * notch_hh - _direction * notch_hw
		var b := pos + perp * notch_hh + _direction * notch_hw
		var d := pos - perp * notch_hh - _direction * notch_hw
		var e := pos - perp * notch_hh + _direction * notch_hw
		_add_tri(vertices, colors, a, b, d, c)
		_add_tri(vertices, colors, b, e, d, c)

func _add_tri(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	vertices.append(Vector3(a.x, a.y, 0.0))
	vertices.append(Vector3(b.x, b.y, 0.0))
	vertices.append(Vector3(c.x, c.y, 0.0))
	colors.append(color)
	colors.append(color)
	colors.append(color)

func _add_circle(vertices: PackedVector3Array, colors: PackedColorArray, center: Vector2, radius: float, color: Color, segs: int) -> void:
	if radius < 0.5:
		return
	for i in range(segs):
		var a1: float = TAU * float(i) / float(segs)
		var a2: float = TAU * float(i + 1) / float(segs)
		var p1 := center + Vector2(cos(a1), sin(a1)) * radius
		var p2 := center + Vector2(cos(a2), sin(a2)) * radius
		_add_tri(vertices, colors, center, p1, p2, color)

func _gradient_color(t: float, layer: int, alpha: float) -> Color:
	var br: float = _L_CORE_COLOR[layer].r
	var bg: float = _L_CORE_COLOR[layer].g
	var bb: float = _L_CORE_COLOR[layer].b
	var tr: float = _L_TIP_COLOR[layer].r
	var tg: float = _L_TIP_COLOR[layer].g
	var tb: float = _L_TIP_COLOR[layer].b
	if _mod_tint != Color.WHITE:
		br *= _mod_tint.r; bg *= _mod_tint.g; bb *= _mod_tint.b
		tr *= _mod_tint.r; tg *= _mod_tint.g; tb *= _mod_tint.b
	return Color(lerp(br, tr, t), lerp(bg, tg, t), lerp(bb, tb, t), alpha)

func _triangle_area(a: Vector2, b: Vector2, c: Vector2) -> float:
	return absf((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) * 0.5

func _update_sparks(dir: Vector2, tint: Color, emit: bool) -> void:
	var sp := _sparks.process_material as ParticleProcessMaterial
	if sp:
		sp.direction = Vector3(dir.x, dir.y, 0.0)
		if tint != Color.WHITE:
			sp.color = Color(tint.r * 0.75, tint.g * 0.6, tint.b * 0.95, 0.8)
		else:
			sp.color = Color(0.75, 0.6, 0.95, 0.8)
	_sparks.emitting = emit
	_sparks.visible = emit
