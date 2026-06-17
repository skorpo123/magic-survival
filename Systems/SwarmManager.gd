extends Node2D

const ShadowTexture = preload("res://Systems/ShadowTexture.gd")
const MAX_SWARM: int = 2000
const HIT_RADIUS_SQ: float = 225.0
const CONTACT_DIST_SQ: float = 900.0
const MAX_DEATH_FX_PER_BATCH: int = 50
const FRAME_COUNT: int = 6
const ANIM_FPS: float = 10.0
const GRACE_TIME: float = 2.0
const GPU_UPDATE_INTERVAL: int = 3

const SHADOW_Y_OFFSET: float = 24.0

var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _dx: PackedFloat32Array = PackedFloat32Array()
var _dy: PackedFloat32Array = PackedFloat32Array()
var _speed: PackedFloat32Array = PackedFloat32Array()
var _hp: PackedFloat32Array = PackedFloat32Array()
var _damage: PackedFloat32Array = PackedFloat32Array()
var _xp: PackedFloat32Array = PackedFloat32Array()
var _sv: PackedFloat32Array = PackedFloat32Array()
var _cr: PackedFloat32Array = PackedFloat32Array()
var _cg: PackedFloat32Array = PackedFloat32Array()
var _cb: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _lifetime: PackedFloat32Array = PackedFloat32Array()
var _slow_timer: PackedFloat32Array = PackedFloat32Array()
var _spawn_fade: PackedFloat32Array = PackedFloat32Array()
var _mm_instance: MultiMeshInstance2D
var _mm_shadow: MultiMeshInstance2D
var _frame_width: int = 0
var _frame_height: int = 0
var _game_time: float = 0.0
var _speed_mult: float = 1.0
var _type_speed: float = 0.0
var _frame_counter: int = 0
var _alive: PackedInt32Array = PackedInt32Array()
var _killed_batch: PackedInt32Array = PackedInt32Array()
var _grid: SpatialGrid = SpatialGrid.new(128.0)
var _grid_counter: int = 0
const GRID_REBUILD_INTERVAL: int = 3
var _count: int = 0

static var _spritesheet: Texture2D = null
static var _sheet_fw: int = 0
static var _sheet_fh: int = 0

func _ready() -> void:
	_build_spritesheet()
	_setup_multimesh()
	_resize_arrays(MAX_SWARM)
	EventBus.game_started.connect(_on_game_started)

func _resize_arrays(size: int) -> void:
	_px.resize(size)
	_py.resize(size)
	_dx.resize(size)
	_dy.resize(size)
	_speed.resize(size)
	_hp.resize(size)
	_damage.resize(size)
	_xp.resize(size)
	_sv.resize(size)
	_cr.resize(size)
	_cg.resize(size)
	_cb.resize(size)
	_phase.resize(size)
	_lifetime.resize(size)
	_slow_timer.resize(size)
	_spawn_fade.resize(size)

func _build_spritesheet() -> void:
	if _spritesheet:
		_frame_width = _sheet_fw
		_frame_height = _sheet_fh
		return
	var images: Array = []
	for i in range(FRAME_COUNT):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		var tex: Texture2D = load("res://Sprites/%s_small_fast_enemy_pix.png" % num)
		if tex:
			images.append(tex.get_image())
	if images.size() < FRAME_COUNT:
		push_warning("SwarmManager: got %d/%d frames" % [images.size(), FRAME_COUNT])
		return
	var fw: int = images[0].get_width()
	var fh: int = images[0].get_height()
	var sheet: Image = Image.create(fw * images.size(), fh, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(0, 0, fw, fh), Vector2i(fw * i, 0))
	_spritesheet = ImageTexture.create_from_image(sheet)
	_sheet_fw = fw
	_sheet_fh = fh
	_frame_width = fw
	_frame_height = fh

func _setup_multimesh() -> void:
	_mm_instance = MultiMeshInstance2D.new()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = MAX_SWARM
	mm.visible_instance_count = 0

	var quad: QuadMesh = QuadMesh.new()
	if _frame_width > 0 and _frame_height > 0:
		var aspect: float = float(_frame_width) / float(_frame_height)
		if aspect >= 1.0:
			quad.size = Vector2(aspect, 1.0)
		else:
			quad.size = Vector2(1.0, 1.0 / aspect)
	else:
		quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad

	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	var sh: Shader = load("res://Systems/SwarmShader.gdshader") as Shader
	shader_mat.shader = sh
	if _spritesheet:
		shader_mat.set_shader_parameter("spritesheet", _spritesheet)
		shader_mat.set_shader_parameter("frame_count", float(FRAME_COUNT))
		shader_mat.set_shader_parameter("anim_fps", ANIM_FPS)
		shader_mat.set_shader_parameter("game_time", 0.0)
	_mm_instance.material = shader_mat

	_mm_instance.multimesh = mm
	z_index = 1
	add_child(_mm_instance)
	_setup_shadow_multimesh()

func _setup_shadow_multimesh() -> void:
	_mm_shadow = MultiMeshInstance2D.new()
	var shadow_mm: MultiMesh = MultiMesh.new()
	shadow_mm.transform_format = MultiMesh.TRANSFORM_2D
	shadow_mm.instance_count = MAX_SWARM
	shadow_mm.visible_instance_count = 0
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(1.2, 0.6)
	shadow_mm.mesh = shadow_quad
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://Shaders/shadow_oval.gdshader") as Shader
	shadow_mat.set_shader_parameter("shadow_tex", ShadowTexture.get_texture())
	shadow_mat.set_shader_parameter("shadow_color", Color(0.03, 0.03, 0.03, 0.7))
	_mm_shadow.material = shadow_mat
	_mm_shadow.multimesh = shadow_mm
	_mm_shadow.z_index = -1
	_mm_shadow.z_as_relative = false
	add_child(_mm_shadow)

func _on_game_started() -> void:
	_clear_units()
	_game_time = 0.0
	_type_speed = 0.0
	_count = 0
	_alive.clear()
	_grid.clear()
	for i in range(_slow_timer.size()):
		_slow_timer[i] = 0.0
	if _mm_instance and _mm_instance.multimesh:
		_mm_instance.multimesh.visible_instance_count = 0
	if _mm_shadow and _mm_shadow.multimesh:
		_mm_shadow.multimesh.visible_instance_count = 0

func _clear_units() -> void:
	for i in range(_px.size()):
		_hp[i] = 0.0
	_count = 0

func get_count() -> int:
	return _count

var _spawn_idx: int = 0

func spawn(pos: Vector2, direction: Vector2, hp: float, speed: float, damage: float, xp: float, color: Color = Color.WHITE) -> void:
	if _count >= MAX_SWARM:
		return
	if _type_speed < 0.01:
		_type_speed = speed
	var found: bool = false
	var start: int = _spawn_idx
	while true:
		if _hp[_spawn_idx] <= 0.0:
			found = true
			break
		_spawn_idx = (_spawn_idx + 1) % MAX_SWARM
		if _spawn_idx == start:
			break
	if not found:
		return
	ActionProfiler.probe("spawn", "swarm")
	_px[_spawn_idx] = pos.x
	_py[_spawn_idx] = pos.y
	_dx[_spawn_idx] = direction.x
	_dy[_spawn_idx] = direction.y
	_speed[_spawn_idx] = speed
	_hp[_spawn_idx] = hp
	_damage[_spawn_idx] = damage
	_xp[_spawn_idx] = xp
	_sv[_spawn_idx] = randf_range(0.8, 1.2)
	_cr[_spawn_idx] = color.r
	_cg[_spawn_idx] = color.g
	_cb[_spawn_idx] = color.b
	_phase[_spawn_idx] = 0.0
	_lifetime[_spawn_idx] = 0.0
	_spawn_fade[_spawn_idx] = 0.0
	_count += 1
	_alive.append(_spawn_idx)
	_grid.insert(_spawn_idx, pos.x, pos.y)
	_spawn_idx = (_spawn_idx + 1) % MAX_SWARM

func _process(delta: float) -> void:
	if get_tree().paused or not GameManager.is_playing():
		return
	_game_time += delta
	if _mm_instance and _mm_instance.material:
		_mm_instance.material.set_shader_parameter("game_time", _game_time)

	_frame_counter = (_frame_counter + 1) % GPU_UPDATE_INTERVAL
	var full_gpu: bool = (_frame_counter == 0)

	var player: Node2D = GameManager.get_player()
	if not player or not is_instance_valid(player):
		return

	var ppx: float = player.global_position.x
	var ppy: float = player.global_position.y
	var mm: MultiMesh = _mm_instance.multimesh
	var write: int = 0
	var fx_count: int = 0
	var speed_delta: float = _speed_mult * delta
	var vp_size: Vector2 = get_viewport_rect().size
	var half_w: float = vp_size.x * 0.5 + 60.0
	var half_h: float = vp_size.y * 0.5 + 60.0
	var near_sq: float = half_w * half_w * 0.25
	var contact_xp: float = 0.0
	var contact_count: int = 0
	var killed: int = 0

	var rebuild_grid: bool = (_frame_counter == 0)
	if rebuild_grid:
		_grid.clear()
	for i in _alive:
		if _hp[i] <= 0.0:
			continue

		var slow_mult: float = 1.0
		if _slow_timer[i] > 0.0:
			_slow_timer[i] -= delta
			if _slow_timer[i] > 2.0:
				slow_mult = 0.0
			elif _slow_timer[i] > 0.0:
				slow_mult = 1.0 - _slow_timer[i] / 2.0

		_px[i] += _dx[i] * _speed[i] * slow_mult * speed_delta
		_py[i] += _dy[i] * _speed[i] * slow_mult * speed_delta
		_lifetime[i] += delta
		_spawn_fade[i] = minf(_spawn_fade[i] + delta * 6.0, 1.0)
		_phase[i] = minf(_phase[i] + delta * 1.8, 1.0)

		var ddx: float = _px[i] - ppx
		var ddy: float = _py[i] - ppy
		var dist_sq: float = ddx * ddx + ddy * ddy

		if dist_sq < CONTACT_DIST_SQ:
			var boom_pos := Vector2(_px[i], _py[i])
			if ShieldBehavior.shield_active and ShieldBehavior.is_in_shield(boom_pos):
				var shield := ShieldBehavior.get_instance()
				if shield and shield.intercept_contact(boom_pos):
					if fx_count < MAX_DEATH_FX_PER_BATCH - 1:
						JuiceManager.spawn_death_effect(boom_pos, Color(_cr[i], _cg[i], _cb[i]), "small")
						JuiceManager.spawn_explosion_visual(boom_pos, 30.0, Color(_cr[i] * 0.5 + 0.5, _cg[i] * 0.3 + 0.3, _cb[i] * 0.3 + 0.3))
						fx_count += 2
					contact_xp += _xp[i]
					contact_count += 1
					_hp[i] = 0.0
					killed += 1
					continue
			if player.has_method("take_damage"):
				player.take_damage(_damage[i], null)
			if fx_count < MAX_DEATH_FX_PER_BATCH - 1:
				JuiceManager.spawn_death_effect(boom_pos, Color(_cr[i], _cg[i], _cb[i]), "small")
				JuiceManager.spawn_explosion_visual(boom_pos, 30.0, Color(_cr[i] * 0.5 + 0.5, _cg[i] * 0.3 + 0.3, _cb[i] * 0.3 + 0.3))
				fx_count += 2
			ActionProfiler.probe("death", "swarm_contact")
			contact_xp += _xp[i]
			contact_count += 1
			_hp[i] = 0.0
			killed += 1
			continue

		if _lifetime[i] >= GRACE_TIME:
			if absf(ddx) > half_w or absf(ddy) > half_h:
				_hp[i] = 0.0
				killed += 1
				continue

		var s: float = 40.0 * _sv[i] * _spawn_fade[i]
		var offscreen_sq: float = half_w * half_w * 4.0
		if dist_sq < offscreen_sq:
			mm.set_instance_transform_2d(write, Transform2D(Vector2(s, 0.0), Vector2(0.0, s), Vector2(_px[i], _py[i])))
			if _mm_shadow and _mm_shadow.multimesh:
				_mm_shadow.multimesh.set_instance_transform_2d(write, Transform2D(Vector2(s, 0.0), Vector2(0.0, s * 0.5), Vector2(_px[i], _py[i] + SHADOW_Y_OFFSET)))
			if full_gpu or dist_sq < near_sq:
				var r: float = _cr[i]
				var g: float = _cg[i]
				var b: float = _cb[i]
				if _slow_timer[i] > 0.0:
					var freeze: float = _slow_timer[i] / 4.0
					freeze = minf(freeze, 1.0)
					if _slow_timer[i] > 2.0:
						r = lerpf(r, 0.55, freeze)
						g = lerpf(g, 0.90, freeze)
						b = lerpf(b, 1.10, freeze)
					else:
						r = lerpf(r, 0.65, freeze)
						g = lerpf(g, 0.85, freeze)
						b = lerpf(b, 1.0, freeze)
				mm.set_instance_color(write, Color(r, g, b, _phase[i]))
				var freeze_amt: float = 0.0
				var frozen_t: float = 0.0
				if _slow_timer[i] > 0.0:
					freeze_amt = minf(_slow_timer[i] / 4.0, 1.0)
					if _slow_timer[i] > 2.0:
						frozen_t = _game_time
				mm.set_instance_custom_data(write, Color(freeze_amt, frozen_t, 0.0, 0.0))
		if rebuild_grid:
			_grid.insert(i, _px[i], _py[i])
		write += 1

	mm.visible_instance_count = write
	if _mm_shadow and _mm_shadow.multimesh:
		_mm_shadow.multimesh.visible_instance_count = write
	_count -= killed
	_grid_counter = (_grid_counter + 1) % GRID_REBUILD_INTERVAL
	var write_idx: int = 0
	for read_idx in range(_alive.size()):
		if _hp[_alive[read_idx]] > 0.0:
			_alive[write_idx] = _alive[read_idx]
			write_idx += 1
	_alive.resize(write_idx)

	if contact_count > 0:
		EventBus.enemy_died.emit(Vector2(ppx, ppy), contact_xp, &"Swarm")
		if player.has_method("add_xp"):
			player.add_xp(contact_xp)
		SoundManager.play_sound("enemy_explode")

func _batch_remove_alive() -> void:
	var alive := _alive
	var n := alive.size()
	for id in _killed_batch:
		var idx: int = alive.find(id)
		if idx >= 0:
			alive[idx] = alive[n - 1]
			n -= 1
	alive.resize(n)
	_killed_batch.clear()

func damage_area(center: Vector2, radius: float, amount: float) -> int:
	var killed: int = 0
	var effective_sq: float = radius * radius + HIT_RADIUS_SQ
	var player: Node2D = GameManager.get_player()
	var aura_mult: float = 1.0
	if player and ArtifactAbilityRunner._has_static_aura and center.distance_squared_to(player.global_position) <= 6400.0:
		aura_mult = 1.15
	var fx_count: int = 0
	var xp_batch: float = 0.0
	var candidates: PackedInt32Array = _grid.query_nearby(center, radius + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - center.x
		var ddy: float = _py[i] - center.y
		if ddx * ddx + ddy * ddy <= effective_sq:
			_hp[i] -= amount * aura_mult
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_grid.remove(i)
				_killed_batch.append(i)
	_batch_remove_alive()
	if killed > 0:
		_count -= killed
		ActionProfiler.probe("death", "swarm_area_k%d" % killed)
		EventBus.enemy_died.emit(center, xp_batch, &"Swarm")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func knockback_area(center: Vector2, radius: float, force: float) -> void:
	var effective_sq: float = radius * radius + HIT_RADIUS_SQ
	var candidates: PackedInt32Array = _grid.query_nearby(center, radius + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - center.x
		var ddy: float = _py[i] - center.y
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq <= effective_sq and d_sq > 1.0:
			var dist := sqrt(d_sq)
			var push: float = force * (1.0 - dist / (radius + 15.0))
			_px[i] += (ddx / dist) * push
			_py[i] += (ddy / dist) * push

func damage_nearest(pos: Vector2, radius: float, amount: float) -> bool:
	var radius_sq: float = radius * radius
	var best_i: int = -1
	var best_dist_sq: float = radius_sq
	var candidates: PackedInt32Array = _grid.query_nearby(pos, radius + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		var d_sq: float = ddx * ddx + ddy * ddy
		var effective_sq: float = d_sq - HIT_RADIUS_SQ
		if effective_sq < best_dist_sq:
			best_dist_sq = effective_sq
			best_i = i
	if best_i < 0:
		return false
	_hp[best_i] -= amount
	if _hp[best_i] <= 0.0:
		_count -= 1
		JuiceManager.spawn_death_effect(Vector2(_px[best_i], _py[best_i]), Color(_cr[best_i], _cg[best_i], _cb[best_i]), "small")
		_grid.remove(best_i)
		_killed_batch.append(best_i)
		_batch_remove_alive()
		var player: Node2D = GameManager.get_player()
		if player and player.has_method("add_xp"):
			player.add_xp(_xp[best_i])
		EventBus.enemy_died.emit(Vector2(_px[best_i], _py[best_i]), _xp[best_i], &"Swarm")
	return true

func find_closest_pos(pos: Vector2, max_range: float) -> Vector2:
	var range_sq: float = max_range * max_range
	var best_pos: Vector2 = Vector2.ZERO
	var found: bool = false
	var candidates: PackedInt32Array = _grid.query_nearby(pos, max_range + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq < range_sq:
			range_sq = d_sq
			best_pos = Vector2(_px[i], _py[i])
			found = true
	if not found:
		return Vector2.ZERO
	return best_pos

func find_closest_velocity(pos: Vector2, max_range: float) -> Vector2:
	var range_sq: float = max_range * max_range
	var best_vel: Vector2 = Vector2.ZERO
	var found: bool = false
	var candidates: PackedInt32Array = _grid.query_nearby(pos, max_range + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq < range_sq:
			range_sq = d_sq
			best_vel = Vector2(_dx[i] * _speed[i], _dy[i] * _speed[i])
			found = true
	if not found:
		return Vector2.ZERO
	return best_vel

func find_closest_pos_and_velocity(pos: Vector2, max_range: float) -> Dictionary:
	var range_sq: float = max_range * max_range
	var best_pos: Vector2 = Vector2.ZERO
	var best_vel: Vector2 = Vector2.ZERO
	var found: bool = false
	var candidates: PackedInt32Array = _grid.query_nearby(pos, max_range + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq < range_sq:
			range_sq = d_sq
			best_pos = Vector2(_px[i], _py[i])
			best_vel = Vector2(_dx[i] * _speed[i], _dy[i] * _speed[i])
			found = true
	if not found:
		return {}
	return {&"pos": best_pos, &"vel": best_vel}

func has_units_in_range(pos: Vector2, max_range: float) -> bool:
	var range_sq: float = max_range * max_range
	var candidates: PackedInt32Array = _grid.query_nearby(pos, max_range + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		if ddx * ddx + ddy * ddy < range_sq:
			return true
	return false

func set_speed_mult(mult: float) -> void:
	_speed_mult = mult

func apply_slow(pos: Vector2, radius: float, duration: float = 4.0) -> void:
	var radius_sq: float = radius * radius
	var candidates: PackedInt32Array = _grid.query_nearby(pos, radius + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		if ddx * ddx + ddy * ddy <= radius_sq:
			_slow_timer[i] = maxf(_slow_timer[i], duration)

func damage_line(from: Vector2, to: Vector2, half_width: float, amount: float) -> Array:
	var killed: int = 0
	var hit: int = 0
	var hw_sq: float = half_width * half_width + HIT_RADIUS_SQ
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = GameManager.get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0
	var margin: float = half_width + 15.0
	var min_pos := Vector2(minf(from.x, to.x) - margin, minf(from.y, to.y) - margin)
	var max_pos := Vector2(maxf(from.x, to.x) + margin, maxf(from.y, to.y) + margin)
	var candidates: PackedInt32Array = _grid.query_aabb(min_pos, max_pos)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var px: float = _px[i] - from.x
		var py: float = _py[i] - from.y
		var t: float = 0.0
		if line_len_sq > 0.001:
			t = (px * line_dx + py * line_dy) / line_len_sq
			t = clampf(t, 0.0, 1.0)
		var closest_x: float = t * line_dx
		var closest_y: float = t * line_dy
		var ddx: float = px - closest_x
		var ddy: float = py - closest_y
		if ddx * ddx + ddy * ddy <= hw_sq:
			_hp[i] -= amount
			hit += 1
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_grid.remove(i)
				_killed_batch.append(i)
	_batch_remove_alive()
	if killed > 0:
		_count -= killed
		EventBus.enemy_died.emit(from, xp_batch, &"Swarm")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return [killed, hit]

func damage_rect(from: Vector2, to: Vector2, half_width: float, amount: float) -> int:
	var killed: int = 0
	var hw_sq: float = half_width * half_width
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = GameManager.get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0

	var min_x: float = minf(from.x, to.x) - half_width
	var min_y: float = minf(from.y, to.y) - half_width
	var max_x: float = maxf(from.x, to.x) + half_width
	var max_y: float = maxf(from.y, to.y) + half_width
	var candidates: PackedInt32Array = _grid.query_aabb(Vector2(min_x, min_y), Vector2(max_x, max_y))
	for idx_i in range(candidates.size()):
		var i: int = candidates[idx_i]
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var px: float = _px[i] - from.x
		var py: float = _py[i] - from.y
		var t: float = 0.0
		if line_len_sq > 0.001:
			t = clampf((px * line_dx + py * line_dy) / line_len_sq, 0.0, 1.0)
		var closest_x: float = t * line_dx
		var closest_y: float = t * line_dy
		var ddx: float = px - closest_x
		var ddy: float = py - closest_y
		if ddx * ddx + ddy * ddy <= hw_sq + HIT_RADIUS_SQ:
			_hp[i] -= amount
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_hp[i] = 0.0
				_grid.remove(i)
				_killed_batch.append(i)
	_batch_remove_alive()
	if killed > 0:
		_count -= killed
		EventBus.enemy_died.emit(from, xp_batch, &"Swarm")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func damage_rect_filtered(from: Vector2, to: Vector2, half_width: float, amount: float, hit_filter: Dictionary) -> int:
	var killed: int = 0
	var hw_sq: float = half_width * half_width
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = GameManager.get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0

	var min_x: float = minf(from.x, to.x) - half_width
	var min_y: float = minf(from.y, to.y) - half_width
	var max_x: float = maxf(from.x, to.x) + half_width
	var max_y: float = maxf(from.y, to.y) + half_width
	var candidates: PackedInt32Array = _grid.query_aabb(Vector2(min_x, min_y), Vector2(max_x, max_y))
	for idx_i in range(candidates.size()):
		var i: int = candidates[idx_i]
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		if hit_filter.has(i):
			continue
		var px: float = _px[i] - from.x
		var py: float = _py[i] - from.y
		var t: float = 0.0
		if line_len_sq > 0.001:
			t = clampf((px * line_dx + py * line_dy) / line_len_sq, 0.0, 1.0)
		var closest_x: float = t * line_dx
		var closest_y: float = t * line_dy
		var ddx: float = px - closest_x
		var ddy: float = py - closest_y
		if ddx * ddx + ddy * ddy <= hw_sq + HIT_RADIUS_SQ:
			hit_filter[i] = true
			_hp[i] -= amount
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_hp[i] = 0.0
				_grid.remove(i)
				_killed_batch.append(i)
	_batch_remove_alive()
	if killed > 0:
		_count -= killed
		EventBus.enemy_died.emit(from, xp_batch, &"Swarm")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func pull_toward(center: Vector2, pull_range: float, strength: float) -> void:
	var range_sq: float = pull_range * pull_range
	var candidates: PackedInt32Array = _grid.query_nearby(center, pull_range + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = center.x - _px[i]
		var ddy: float = center.y - _py[i]
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq < range_sq and d_sq > 1.0:
			var inv_dist: float = 1.0 / sqrt(d_sq)
			_px[i] += ddx * inv_dist * strength
			_py[i] += ddy * inv_dist * strength

func damage_cone(origin: Vector2, tip: Vector2, half_angle: float, amount: float) -> int:
	var killed: int = 0
	var dir := (tip - origin)
	var length_sq: float = dir.length_squared() + HIT_RADIUS_SQ
	var length := sqrt(length_sq)
	var forward := dir / maxf(length, 0.001)
	var player: Node2D = GameManager.get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0
	var cos_half := cos(half_angle)
	var query_radius: float = length + 15.0
	var candidates: PackedInt32Array = _grid.query_nearby(origin, query_radius)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - origin.x
		var ddy: float = _py[i] - origin.y
		var d_sq: float = ddx * ddx + ddy * ddy
		if d_sq > length_sq:
			continue
		var dist := sqrt(d_sq)
		if dist < 1.0:
			_hp[i] -= amount
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_grid.remove(i)
				_killed_batch.append(i)
			continue
		var dot: float = (ddx * forward.x + ddy * forward.y) / dist
		if dot >= cos_half:
			_hp[i] -= amount
			if _hp[i] <= 0.0:
				killed += 1
				if fx_count < MAX_DEATH_FX_PER_BATCH:
					JuiceManager.spawn_death_effect(Vector2(_px[i], _py[i]), Color(_cr[i], _cg[i], _cb[i]), "small")
					fx_count += 1
				xp_batch += _xp[i]
				_grid.remove(i)
				_killed_batch.append(i)
	_batch_remove_alive()
	if killed > 0:
		_count -= killed
		EventBus.enemy_died.emit(origin, xp_batch, &"Swarm")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func get_nearby_ids(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius
	var candidates: PackedInt32Array = _grid.query_nearby(pos, radius + 15.0)
	for i in candidates:
		if i < 0 or i >= _hp.size() or _hp[i] <= 0.0:
			continue
		var ddx: float = _px[i] - pos.x
		var ddy: float = _py[i] - pos.y
		if ddx * ddx + ddy * ddy <= radius_sq:
			result.append(i)
	return result

func damage_id(id: int, amount: float) -> int:
	if id < 0 or id >= _hp.size() or _hp[id] <= 0.0:
		return 0
	_hp[id] -= amount
	if _hp[id] <= 0.0:
		_count -= 1
		JuiceManager.spawn_death_effect(Vector2(_px[id], _py[id]), Color(_cr[id], _cg[id], _cb[id]), "small")
		_grid.remove(id)
		_killed_batch.append(id)
		_batch_remove_alive()
		var player: Node2D = GameManager.get_player()
		if player and player.has_method("add_xp"):
			player.add_xp(_xp[id])
		EventBus.enemy_died.emit(Vector2(_px[id], _py[id]), _xp[id], &"Swarm")
		return 1
	return 0
