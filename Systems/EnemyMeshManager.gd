extends Node2D

const ShadowTexture = preload("res://Systems/ShadowTexture.gd")
const DESPAWN_DIST_SQ: float = 4000000.0
const MAX_DEATH_FX_PER_BATCH: int = 50
const ELITE_COLOR: Color = Color(1.0, 0.85, 0.2)
const CONTACT_COOLDOWN: float = 0.5
const GPU_UPDATE_INTERVAL: int = 3
const BOSS_DAMAGE_DIST_SQ: float = 2500.0
const FIELDS: int = 14

const I_PX: int = 0
const I_PY: int = 1
const I_SPEED: int = 2
const I_HP: int = 3
const I_MAX_HP: int = 4
const I_DAMAGE: int = 5
const I_EXPLOSION_DMG: int = 6
const I_PUSHBACK: int = 7
const I_XP: int = 8
const I_SV: int = 9
const I_PHASE: int = 10
const I_CONTACT_CD: int = 11
const I_EXTRA: int = 12
const I_SLOW_TIMER: int = 13

const GRID_CELL: float = 128.0
const GRID_REBUILD_INTERVAL: int = 3

const SEPARATION_RADIUS: float = 50.0
const BIG_SEPARATION_RADIUS: float = 100.0
const SEPARATION_FORCE: float = 350.0
const BIG_SEPARATION_FORCE: float = 800.0
const SEPARATION_UPDATE_INTERVAL: int = 2
const SEPARATION_MAX_NEIGHBORS: int = 8
const PLAYER_AVOID_FORCE: float = 50.0
const SHADOW_Y_OFFSET: float = 24.0

var BIG_SEP_KEYS: PackedStringArray = PackedStringArray(["big", "overlord", "overlord_rage"])
var SMALL_SEP_KEYS: PackedStringArray = PackedStringArray(["medium", "mine", "rampage", "rampage_enraged"])
var _type_data: Dictionary = {}
var _game_time: float = 0.0
var _speed_mult: float = 1.0
var _prediction_x: float = 0.0
var _prediction_y: float = 0.0
var _prediction_init: bool = false
var _frame_counter: int = 0
var _grid_counter: int = 0
var _sep_counter: int = 0
var _sep_buf: PackedInt32Array = PackedInt32Array()
var _cross_buf: PackedInt32Array = PackedInt32Array()
var _cached_player: Node2D = null
var _player_frame: int = -1

func _boss_dmg_mult(key: String) -> float:
	if key.ends_with("_boss"):
		return ArtifactManager.get_boss_damage_mult()
	return 1.0

func _ready() -> void:
	_setup_type("medium", "_enemy_pix", 6, 8.0, 52.0, 600, 1099.0, 32.5)
	_setup_type("big", "_big_enemy_pix", 6, 6.0, 132.0, 100, 6400.0, 60.0)
	_setup_type("mine", "_mine_enemy_pix", 6, 8.0, 57.6, 400, 1866.0, 36.0)
	_setup_type("overlord", "_overlord_enemy_normal_pix", 6, 6.0, 132.0, 160, 6400.0, 66.0)
	_setup_type("overlord_rage", "_overlord_enemy_rage_pix", 6, 8.0, 132.0, 160, 4356.0, 72.0)
	_setup_type("rampage", "_rampage_enemy_normal_pix", 6, 8.0, 72.8, 400, 1505.3, 33.6)
	_setup_type("rampage_enraged", "_rampage_enemy_rage_pix", 6, 12.0, 72.8, 400, 1505.3, 33.6)
	_setup_type("medium_boss", "_enemy_medium_boss_pix", 6, 8.0, 160.0, 10, 6400.0, 80.0)
	_setup_type("mine_boss", "_enemy_mine_boss_pix", 6, 8.0, 170.0, 10, 7225.0, 85.0)
	_setup_type("big_boss", "_enemy_golem_boss_pix", 6, 6.0, 380.0, 10, 36100.0, 190.0)
	_setup_type("rampage_boss", "_enemy_rampage_boss_pix", 6, 8.0, 240.0, 10, 14400.0, 120.0)
	_setup_type("overlord_boss", "_enemy_overlord_boss_pix", 6, 6.0, 350.0, 10, 30625.0, 175.0)
	_build_type_index_map()
	EventBus.game_started.connect(_on_game_started)

func _setup_type(key: String, suffix: String, frame_count: int, anim_fps: float, base_scale: float, max_count: int, contact_dist_sq: float, hit_radius: float) -> void:
	var images: Array = []
	for i in range(frame_count):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		var tex: Texture2D = load("res://Sprites/%s%s.png" % [num, suffix])
		if tex:
			images.append(tex.get_image())
	if images.size() < frame_count:
		push_warning("EnemyMeshManager: %s got %d/%d frames" % [key, images.size(), frame_count])
		return
	var fw: int = images[0].get_width()
	var fh: int = images[0].get_height()
	var sheet: Image = Image.create(fw * images.size(), fh, false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(0, 0, fw, fh), Vector2i(fw * i, 0))
	var spritesheet: Texture2D = ImageTexture.create_from_image(sheet)

	var mm_instance := MultiMeshInstance2D.new()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = max_count
	mm.visible_instance_count = 0
	var quad := QuadMesh.new()
	if fw > 0 and fh > 0:
		var aspect: float = float(fw) / float(fh)
		if aspect >= 1.0:
			quad.size = Vector2(aspect, 1.0)
		else:
			quad.size = Vector2(1.0, 1.0 / aspect)
	else:
		quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	var sh: Shader = load("res://Systems/SwarmShader.gdshader") as Shader
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = sh
	shader_mat.set_shader_parameter("spritesheet", spritesheet)
	shader_mat.set_shader_parameter("frame_count", float(frame_count))
	shader_mat.set_shader_parameter("anim_fps", anim_fps)
	shader_mat.set_shader_parameter("game_time", 0.0)
	mm_instance.material = shader_mat
	mm_instance.multimesh = mm
	mm_instance.z_index = 1
	add_child(mm_instance)

	var mm_shadow := MultiMeshInstance2D.new()
	var shadow_mm := MultiMesh.new()
	shadow_mm.transform_format = MultiMesh.TRANSFORM_2D
	shadow_mm.instance_count = max_count
	shadow_mm.visible_instance_count = 0
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = Vector2(1.2, 0.6)
	shadow_mm.mesh = shadow_quad
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://Shaders/shadow_oval.gdshader") as Shader
	shadow_mat.set_shader_parameter("shadow_tex", ShadowTexture.get_texture())
	shadow_mat.set_shader_parameter("shadow_color", Color(0.03, 0.03, 0.03, 0.7))
	mm_shadow.material = shadow_mat
	mm_shadow.multimesh = shadow_mm
	mm_shadow.z_index = -1
	mm_shadow.z_as_relative = false
	add_child(mm_shadow)

	var d := PackedFloat32Array()
	d.resize(max_count * FIELDS)
	var free_slots_arr := PackedInt32Array()
	free_slots_arr.resize(max_count)
	for j in range(max_count):
		d[j * FIELDS + I_HP] = 0.0
		free_slots_arr[j] = max_count - 1 - j

	var color_r: PackedFloat32Array = PackedFloat32Array()
	color_r.resize(max_count)
	var color_g: PackedFloat32Array = PackedFloat32Array()
	color_g.resize(max_count)
	var color_b: PackedFloat32Array = PackedFloat32Array()
	color_b.resize(max_count)
	var extra: PackedFloat32Array = PackedFloat32Array()
	extra.resize(max_count * 2)
	for j in range(max_count):
		extra[j * 2] = 0.0
		extra[j * 2 + 1] = 0.0

	var spawn_timer: PackedFloat32Array = PackedFloat32Array()
	spawn_timer.resize(max_count)

	_type_data[key] = {
		mm_instance = mm_instance,
		mm = mm,
		material = shader_mat,
		mm_shadow = mm_shadow,
		shadow_mm = shadow_mm,
		d = d,
		color_r = color_r,
		color_g = color_g,
		color_b = color_b,
		extra = extra,
		spawn_timer = spawn_timer,
		count = 0,
		base_scale = base_scale,
		frame_count = frame_count,
		anim_fps = anim_fps,
		max_count = max_count,
		contact_dist_sq = contact_dist_sq,
		hit_radius = hit_radius,
		type_speed = 0.0,
		alive_indices = PackedInt32Array(),
		free_slots = free_slots_arr,
		grid = SpatialGrid.new(GRID_CELL),
	}

func _on_game_started() -> void:
	_game_time = 0.0
	_cached_player = null
	_player_frame = -1
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		td.count = 0
		td.type_speed = 0.0
		var d: PackedFloat32Array = td.d
		for j in range(td.max_count):
			d[j * FIELDS + I_HP] = 0.0
			d[j * FIELDS + I_SLOW_TIMER] = 0.0
		if td.mm:
			td.mm.visible_instance_count = 0
		if td.shadow_mm:
			td.shadow_mm.visible_instance_count = 0
		td.alive_indices.clear()
		td.free_slots.clear()
		for j in range(td.max_count):
			td.free_slots.append(td.max_count - 1 - j)
		td.grid.clear()

func _get_player() -> Node2D:
	var f: int = Engine.get_process_frames()
	if f == _player_frame and _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = GameManager.get_player()
	_player_frame = f
	return _cached_player

func _alloc_slot(td: Dictionary) -> int:
	if td.free_slots.size() <= 0:
		return -1
	var slot: int = td.free_slots[td.free_slots.size() - 1]
	td.free_slots = td.free_slots.slice(0, td.free_slots.size() - 1)
	return slot

func spawn_medium(pos: Vector2, hp: float, speed: float, damage: float, xp: float, color: Color = Color.WHITE) -> int:
	return _spawn_unit("medium", pos, hp, hp, speed, damage, 0.0, 0.0, xp, color, 0.0, 0.0)

func spawn_big(pos: Vector2, hp: float, speed: float, damage: float, explosion_damage: float, pushback_force: float, xp: float, color: Color = Color.WHITE) -> int:
	return _spawn_unit("big", pos, hp, hp, speed, damage, explosion_damage, pushback_force, xp, color, 0.0, 0.0)

func spawn_mine(pos: Vector2, hp: float, speed: float, damage: float, explosion_damage: float, xp: float, color: Color = Color.WHITE) -> int:
	return _spawn_unit("mine", pos, hp, hp, speed, damage, explosion_damage, 0.0, xp, color, 0.0, 0.0)

func spawn_overlord(pos: Vector2, hp: float, max_hp: float, speed: float, damage: float, explosion_damage: float, xp: float, color: Color = Color.WHITE) -> int:
	return _spawn_unit("overlord", pos, hp, max_hp, speed, damage, explosion_damage, 0.0, xp, color, 0.0, 0.0)

func spawn_rampage(pos: Vector2, hp: float, speed: float, damage: float, xp: float, color: Color = Color.WHITE) -> int:
	return _spawn_unit("rampage", pos, hp, hp, speed, damage, 0.0, 0.0, xp, color, speed, 0.0)

func spawn_boss(pos: Vector2, hp: float, max_hp: float, speed: float, damage: float, explosion_damage: float, pushback_force: float, xp: float, color: Color = Color.WHITE, boss_type: StringName = &"medium") -> int:
	match boss_type:
		&"medium_boss":
			return _spawn_unit("medium_boss", pos, hp, max_hp, speed, damage, 0.0, 0.0, xp, color, 0.0, 0.0)
		&"mine_boss":
			return _spawn_unit("mine_boss", pos, hp, max_hp, speed, damage, explosion_damage, 0.0, xp, color, 0.0, 0.0)
		&"big_boss":
			return _spawn_unit("big_boss", pos, hp, max_hp, speed, damage, explosion_damage, pushback_force, xp, color, 0.0, 0.0)
		&"rampage_boss":
			return _spawn_unit("rampage_boss", pos, hp, max_hp, speed, damage, 0.0, 0.0, xp, color, speed, 0.0)
		&"overlord_boss":
			return _spawn_unit("overlord_boss", pos, hp, max_hp, speed, damage, explosion_damage, 0.0, xp, color, 0.0, 0.0)
		_:
			return _spawn_unit("medium_boss", pos, hp, max_hp, speed, damage, 0.0, 0.0, xp, color, 0.0, 0.0)

func _spawn_unit(key: String, pos: Vector2, hp: float, max_hp: float, speed: float, damage: float, explosion_damage: float, pushback_force: float, xp: float, color: Color, base_speed: float, enrage_timer: float) -> int:
	var td: Dictionary = _type_data[key]
	if td.count >= td.max_count:
		return -1
	var slot: int = _alloc_slot(td)
	if slot < 0:
		return -1
	ActionProfiler.probe("spawn", key)
	if td.type_speed < 0.01:
		td.type_speed = speed
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	d[off + I_PX] = pos.x
	d[off + I_PY] = pos.y
	d[off + I_SPEED] = speed
	d[off + I_HP] = hp
	d[off + I_MAX_HP] = max_hp
	d[off + I_DAMAGE] = damage
	d[off + I_EXPLOSION_DMG] = explosion_damage
	d[off + I_PUSHBACK] = pushback_force
	d[off + I_XP] = xp
	var sv: float = randf_range(0.85, 1.15)
	if key == "overlord_rage":
		sv = randf_range(0.95, 1.25)
	d[off + I_SV] = sv
	d[off + I_PHASE] = 0.0
	d[off + I_CONTACT_CD] = 0.0
	td.color_r[slot] = color.r
	td.color_g[slot] = color.g
	td.color_b[slot] = color.b
	var e: PackedFloat32Array = td.extra
	e[slot * 2] = base_speed
	e[slot * 2 + 1] = enrage_timer
	td.spawn_timer[slot] = 0.0
	td.count += 1
	td.alive_indices.append(slot)
	td.grid.insert(slot, pos.x, pos.y)
	EventBus.enemy_spawned.emit(StringName(key))
	return slot

func _process(delta: float) -> void:
	if get_tree().paused or not GameManager.is_playing():
		return
	_game_time += delta

	var player: Node2D = _get_player()
	if not player or not is_instance_valid(player):
		return
	var ppx: float = player.global_position.x
	var ppy: float = player.global_position.y
	var ppvx: float = player.velocity.x
	var ppvy: float = player.velocity.y

	if not _prediction_init:
		_prediction_x = ppx
		_prediction_y = ppy
		_prediction_init = true
	var pred_tx: float = ppx + ppvx * 1.5
	var pred_ty: float = ppy + ppvy * 1.5
	_prediction_x = lerpf(_prediction_x, pred_tx, delta * 0.5)
	_prediction_y = lerpf(_prediction_y, pred_ty, delta * 0.5)

	_frame_counter = (_frame_counter + 1) % GPU_UPDATE_INTERVAL
	_sep_counter = (_sep_counter + 1) % SEPARATION_UPDATE_INTERVAL
	var full_gpu: bool = (_frame_counter == 0)

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		td.material.set_shader_parameter("game_time", _game_time)
		if td.count <= 0:
			if td.mm.visible_instance_count > 0:
				td.mm.visible_instance_count = 0
			if td.shadow_mm and td.shadow_mm.visible_instance_count > 0:
				td.shadow_mm.visible_instance_count = 0
			continue
		_update_type(key, td, delta, player, ppx, ppy, ppvx, ppvy, full_gpu)

	_grid_counter = (_grid_counter + 1) % GRID_REBUILD_INTERVAL
	if _grid_counter == 0:
		for key in _type_data:
			var td: Dictionary = _type_data[key]
			td.grid.clear()
			var d: PackedFloat32Array = td.d
			for j in td.alive_indices:
				var off: int = j * FIELDS
				td.grid.insert(j, d[off + I_PX], d[off + I_PY])

func _update_type(key: String, td: Dictionary, delta: float, player: Node2D, ppx: float, ppy: float, ppvx: float, ppvy: float, full_gpu: bool) -> void:
	var d: PackedFloat32Array = td.d
	var mm: MultiMesh = td.mm
	var base_scale: float = td.base_scale
	var contact_sq: float = td.contact_dist_sq
	var speed_delta: float = _speed_mult * delta
	var fx_count: int = 0
	var write: int = 0
	var alive: int = 0
	var is_overlord: bool = (key == "overlord")
	var is_overlord_rage: bool = (key == "overlord_rage")
	var is_mine: bool = (key == "mine")
	var is_big: bool = (key == "big")
	var is_rampage_enraged: bool = (key == "rampage_enraged")
	var is_rampage: bool = (key == "rampage")
	var is_boss: bool = key.ends_with("_boss")
	var damage_sq: float = BOSS_DAMAGE_DIST_SQ if is_boss else contact_sq
	var explodes: bool = is_mine or is_overlord or is_overlord_rage
	var vp_size: Vector2 = get_viewport_rect().size
	var near_sq: float = vp_size.x * vp_size.x * 0.06

	var write_idx: int = 0

	for read_idx in range(td.alive_indices.size()):
		var j: int = td.alive_indices[read_idx]
		var off: int = j * FIELDS
		if d[off + I_HP] <= 0.0:
			continue

		var px: float = d[off + I_PX]
		var py: float = d[off + I_PY]
		var speed: float = d[off + I_SPEED]

		var slow_mult: float = 1.0
		var slow_t: float = d[off + I_SLOW_TIMER]
		if slow_t > 0.0:
			slow_t -= delta
			if slow_t > 2.0:
				slow_mult = 0.0
			elif slow_t > 0.0:
				slow_mult = 1.0 - slow_t / 2.0
			d[off + I_SLOW_TIMER] = maxf(slow_t, 0.0)

		var target_x: float = ppx
		var target_y: float = ppy
		if is_big or is_overlord or is_overlord_rage:
			pass
		elif is_mine:
			target_x = _prediction_x
			target_y = _prediction_y
			var sc: int = j * 13 + 7
			sc = sc * 1103515245 + 12345
			target_x += (float(sc & 0x3fff) / 16383.0 - 0.5) * 150.0
			sc = sc * 1103515245 + 12345
			target_y += (float(sc & 0x3fff) / 16383.0 - 0.5) * 150.0
		elif is_rampage or is_rampage_enraged or key == "medium":
			if j % 10 < 7:
				target_x = _prediction_x
				target_y = _prediction_y
				var sc: int = j * 13 + 7
				sc = sc * 1103515245 + 12345
				target_x += (float(sc & 0x7fff) / 32767.0 - 0.5) * 80.0
				sc = sc * 1103515245 + 12345
				target_y += (float(sc & 0x7fff) / 32767.0 - 0.5) * 80.0

		var ddx: float = target_x - px
		var ddy: float = target_y - py
		var dist_sq: float = ddx * ddx + ddy * ddy

		if not is_boss:
			var seek_mult: float = 1.0
			if dist_sq < contact_sq:
				seek_mult = 0.0
				if dist_sq > 1.0:
					var dist: float = sqrt(dist_sq)
					var inv_dist: float = 1.0 / dist
					var contact_dist: float = sqrt(contact_sq)
					var push_ratio: float = 1.0 - dist / contact_dist
					px -= ddx * inv_dist * push_ratio * PLAYER_AVOID_FORCE * delta
					py -= ddy * inv_dist * push_ratio * PLAYER_AVOID_FORCE * delta
					var perp_x: float = -ddy * inv_dist
					var perp_y: float = ddx * inv_dist
					px += perp_x * speed * slow_mult * speed_delta * 0.5
					py += perp_y * speed * slow_mult * speed_delta * 0.5
					d[off + I_PX] = px
					d[off + I_PY] = py
			elif dist_sq > 0.0:
				var inv_dist: float = 1.0 / sqrt(dist_sq)
				px += ddx * inv_dist * speed * slow_mult * speed_delta * seek_mult
				py += ddy * inv_dist * speed * slow_mult * speed_delta * seek_mult
				d[off + I_PX] = px
				d[off + I_PY] = py

			# Lateral drift to break clumps when far from player
			if dist_sq > 250000.0 and seek_mult > 0.0:
				var drift: float = randf_range(-0.08, 0.08)
				var perp_x: float = -ddy
				var perp_y: float = ddx
				var d_len: float = sqrt(dist_sq) if dist_sq > 0.01 else 1.0
				var inv_d: float = 1.0 / d_len
				px += perp_x * inv_d * drift * speed * slow_mult * speed_delta
				py += perp_y * inv_d * drift * speed * slow_mult * speed_delta
				d[off + I_PX] = px
				d[off + I_PY] = py

		# Shield contact kill — enemies die when touching the dome
		if not is_boss and ShieldBehavior.shield_active:
			var sdx: float = ppx - px
			var sdy: float = ppy - py
			var sdist_sq: float = sdx * sdx + sdy * sdy
			var shield_r_sq: float = ShieldBehavior.shield_radius * ShieldBehavior.shield_radius
			if sdist_sq < shield_r_sq and sdist_sq > 1.0:
				var shield := ShieldBehavior.get_instance()
				if shield and shield.intercept_contact(Vector2(px, py)):
					d[off + I_HP] = 0.0
					td.count -= 1
					JuiceManager.spawn_death_effect(Vector2(px, py), Color(td.color_r[j], td.color_g[j], td.color_b[j]), key)
					var xp_val: float = d[off + I_XP]
					if xp_val > 0.0 and is_instance_valid(player):
						player.add_xp(xp_val)
					continue

		# Separation avoidance
		var is_big_sep: bool = (key in BIG_SEP_KEYS)
		var is_small_sep: bool = (key in SMALL_SEP_KEYS)
		var sep_interval: int = 1 if is_big_sep else SEPARATION_UPDATE_INTERVAL
		if is_big_sep or is_small_sep:
			if _sep_counter == j % sep_interval:
				var sep_x: float = 0.0
				var sep_y: float = 0.0
				var neighbors := 0
				var sep_r: float = BIG_SEPARATION_RADIUS if is_big_sep else SEPARATION_RADIUS
				var sep_r_sq: float = sep_r * sep_r
				var sep_f: float = BIG_SEPARATION_FORCE if is_big_sep else SEPARATION_FORCE
				var sep_group: PackedStringArray = BIG_SEP_KEYS if is_big_sep else SMALL_SEP_KEYS
				td.grid.query_nearby_into(Vector2(px, py), sep_r, _sep_buf)
				for ci in range(_sep_buf.size()):
					if neighbors >= SEPARATION_MAX_NEIGHBORS:
						break
					var other: int = _sep_buf[ci]
					if other == j:
						continue
					var ooff: int = other * FIELDS
					if d[ooff + I_HP] <= 0.0:
						continue
					var odx: float = px - d[ooff + I_PX]
					var ody: float = py - d[ooff + I_PY]
					var od_sq: float = odx * odx + ody * ody
					if od_sq < sep_r_sq and od_sq > 0.01:
						var inv_d: float = 1.0 / sqrt(od_sq)
						var weight: float = 1.0 - od_sq / sep_r_sq
						sep_x += odx * inv_d * weight
						sep_y += ody * inv_d * weight
						neighbors += 1
				for cross_key in _type_data:
					if cross_key == key or not (cross_key in sep_group):
						continue
					var cross_td: Dictionary = _type_data[cross_key]
					var cross_d: PackedFloat32Array = cross_td.d
					cross_td.grid.query_nearby_into(Vector2(px, py), sep_r, _cross_buf)
					for cci in range(_cross_buf.size()):
						if neighbors >= SEPARATION_MAX_NEIGHBORS:
							break
						var cother: int = _cross_buf[cci]
						var coff: int = cother * FIELDS
						if cross_d[coff + I_HP] <= 0.0:
							continue
						var codx: float = px - cross_d[coff + I_PX]
						var cody: float = py - cross_d[coff + I_PY]
						var cod_sq: float = codx * codx + cody * cody
						if cod_sq < sep_r_sq and cod_sq > 0.01:
							var cinv_d: float = 1.0 / sqrt(cod_sq)
							var cweight: float = 1.0 - cod_sq / sep_r_sq
							sep_x += codx * cinv_d * cweight
							sep_y += cody * cinv_d * cweight
							neighbors += 1
				if neighbors > 0:
					px += sep_x / float(neighbors) * sep_f * delta
					py += sep_y / float(neighbors) * sep_f * delta
					d[off + I_PX] = px
					d[off + I_PY] = py

		var cd: float = d[off + I_CONTACT_CD]
		if cd > 0.0:
			cd = maxf(cd - delta, 0.0)
			d[off + I_CONTACT_CD] = cd

		if dist_sq < damage_sq and cd <= 0.0:
			if explodes:
				if randf() < 0.5:
					if player.has_method("take_damage"):
						player.take_damage(d[off + I_EXPLOSION_DMG], null)
					SoundManager.play_sound("enemy_explode")
					JuiceManager.spawn_explosion_visual(Vector2(px, py), 60.0, Color(1.0, 0.7, 0.1))
					JuiceManager.screen_shake(6.0, 0.12)
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(px, py), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
					var player_n: Node2D = _get_player()
					if player_n and player_n.has_method("add_xp"):
						player_n.add_xp(d[off + I_XP])
					EventBus.enemy_died.emit(Vector2(px, py), d[off + I_XP], key)
					d[off + I_HP] = 0.0
					td.count -= 1
					fx_count += 1
					continue
				else:
					if player.has_method("take_damage"):
						player.take_damage(d[off + I_DAMAGE], null)
					SoundManager.play_sound("hit_player")
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(px, py), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
					var player_n: Node2D = _get_player()
					if player_n and player_n.has_method("add_xp"):
						player_n.add_xp(d[off + I_XP])
					EventBus.enemy_died.emit(Vector2(px, py), d[off + I_XP], key)
					d[off + I_HP] = 0.0
					td.count -= 1
					continue
			else:
				if player.has_method("take_damage"):
					player.take_damage(d[off + I_DAMAGE], null)
				SoundManager.play_sound("hit_player")
				d[off + I_CONTACT_CD] = CONTACT_COOLDOWN

		if not is_boss and dist_sq > DESPAWN_DIST_SQ:
			d[off + I_HP] = 0.0
			td.count -= 1
			continue

		if is_overlord:
			var hp_val: float = d[off + I_HP]
			var max_hp_val: float = d[off + I_MAX_HP]
			if hp_val < max_hp_val * 0.5:
				var rage_td: Dictionary = _type_data["overlord_rage"]
				if rage_td.count < rage_td.max_count:
					var rslot: int = _alloc_slot(rage_td)
					if rslot >= 0:
						if rage_td.type_speed < 0.01:
							rage_td.type_speed = d[off + I_SPEED]
						var rd: PackedFloat32Array = rage_td.d
						var roff: int = rslot * FIELDS
						rd[roff + I_PX] = d[off + I_PX]
						rd[roff + I_PY] = d[off + I_PY]
						rd[roff + I_SPEED] = rage_td.type_speed
						rd[roff + I_HP] = d[off + I_HP]
						rd[roff + I_MAX_HP] = d[off + I_MAX_HP]
						rd[roff + I_DAMAGE] = d[off + I_DAMAGE]
						rd[roff + I_EXPLOSION_DMG] = d[off + I_EXPLOSION_DMG]
						rd[roff + I_PUSHBACK] = d[off + I_PUSHBACK]
						rd[roff + I_XP] = d[off + I_XP]
						rd[roff + I_SV] = d[off + I_SV]
						rd[roff + I_PHASE] = 0.0
						rd[roff + I_CONTACT_CD] = 0.0
						rage_td.color_r[rslot] = td.color_r[j]
						rage_td.color_g[rslot] = td.color_g[j]
						rage_td.color_b[rslot] = td.color_b[j]
						var re: PackedFloat32Array = rage_td.extra
						re[rslot * 2] = 0.0
						re[rslot * 2 + 1] = 0.0
						rage_td.spawn_timer[rslot] = 0.0
						rage_td.count += 1
						rage_td.alive_indices.append(rslot)
				d[off + I_HP] = 0.0
				td.count -= 1
				continue

		td.alive_indices[write_idx] = j
		write_idx += 1
		alive += 1

		if d[off + I_PHASE] < 1.0:
			d[off + I_PHASE] = minf(d[off + I_PHASE] + delta * 1.8, 1.0)

		td.spawn_timer[j] = minf(td.spawn_timer[j] + delta * 6.0, 1.0)

		var scale: float = base_scale * d[off + I_SV] * td.spawn_timer[j]
		if is_overlord_rage:
			var e: PackedFloat32Array = td.extra
			var rt: float = minf(e[j * 2] + delta * 1.5, 1.0)
			e[j * 2] = rt
			scale *= lerp(1.0, 1.4, rt)
		if is_rampage_enraged:
			scale *= 1.5

		var offscreen_sq: float = vp_size.x * vp_size.x * 2.0
		if dist_sq < offscreen_sq and write < td.max_count:
			mm.set_instance_transform_2d(write, Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), Vector2(px, py)))
			if td.shadow_mm:
				td.shadow_mm.set_instance_transform_2d(write, Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale * 0.5), Vector2(px, py + SHADOW_Y_OFFSET)))
			if full_gpu or dist_sq < near_sq:
				var r: float = td.color_r[j]
				var g: float = td.color_g[j]
				var b: float = td.color_b[j]
				var s_timer: float = d[off + I_SLOW_TIMER]
				if s_timer > 0.0:
					var freeze: float = minf(s_timer / 4.0, 1.0)
					if s_timer > 2.0:
						r = lerpf(r, 0.55, freeze)
						g = lerpf(g, 0.90, freeze)
						b = lerpf(b, 1.10, freeze)
					else:
						r = lerpf(r, 0.65, freeze)
						g = lerpf(g, 0.85, freeze)
						b = lerpf(b, 1.0, freeze)
				mm.set_instance_color(write, Color(r, g, b, d[off + I_PHASE]))
				var freeze_amt: float = 0.0
				var frozen_t: float = 0.0
				if s_timer > 0.0:
					freeze_amt = minf(s_timer / 4.0, 1.0)
					if s_timer > 2.0:
						frozen_t = _game_time
				mm.set_instance_custom_data(write, Color(freeze_amt, frozen_t, 0.0, 0.0))
		if write < td.max_count:
			write += 1

	td.alive_indices.resize(write_idx)
	mm.visible_instance_count = write
	if td.shadow_mm:
		td.shadow_mm.visible_instance_count = write
	td.count = alive

func _kill_slot(td: Dictionary, slot: int, fx_count: int, key: String) -> void:
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	ActionProfiler.probe("death", key)
	if fx_count < MAX_DEATH_FX_PER_BATCH:
		var death_type: String = key
		if death_type == "overlord_rage":
			death_type = "overlord"
		elif death_type == "rampage_enraged":
			death_type = "rampage"
		JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[slot], td.color_g[slot], td.color_b[slot]), death_type)
	var player: Node2D = _get_player()
	if player and player.has_method("add_xp"):
		player.add_xp(d[off + I_XP])
	EventBus.enemy_died.emit(Vector2(d[off + I_PX], d[off + I_PY]), d[off + I_XP], key)
	d[off + I_HP] = 0.0
	td.count -= 1

func _free_slot(td: Dictionary, slot: int) -> void:
	var d: PackedFloat32Array = td.d
	d[slot * FIELDS + I_HP] = 0.0
	td.count -= 1
	td.free_slots.append(slot)
	var ai: PackedInt32Array = td.alive_indices
	var idx: int = ai.find(slot)
	if idx >= 0:
		var last: int = ai.size() - 1
		if idx != last:
			ai[idx] = ai[last]
		ai.resize(last)
	td.grid.remove(slot)

func _enrage_overlord(td: Dictionary, slot: int) -> void:
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	var rage_td: Dictionary = _type_data["overlord_rage"]
	if rage_td.count >= rage_td.max_count:
		_free_slot(td, slot)
		return
	var rslot: int = _alloc_slot(rage_td)
	if rslot < 0:
		_free_slot(td, slot)
		return
	var new_rage_speed: float = d[off + I_SPEED]
	if rage_td.type_speed < 0.01:
		rage_td.type_speed = new_rage_speed
	var rd: PackedFloat32Array = rage_td.d
	var roff: int = rslot * FIELDS
	rd[roff + I_PX] = d[off + I_PX]
	rd[roff + I_PY] = d[off + I_PY]
	rd[roff + I_SPEED] = rage_td.type_speed
	rd[roff + I_HP] = d[off + I_HP]
	rd[roff + I_MAX_HP] = d[off + I_MAX_HP]
	rd[roff + I_DAMAGE] = d[off + I_DAMAGE]
	rd[roff + I_EXPLOSION_DMG] = d[off + I_EXPLOSION_DMG]
	rd[roff + I_PUSHBACK] = d[off + I_PUSHBACK]
	rd[roff + I_XP] = d[off + I_XP]
	rd[roff + I_SV] = d[off + I_SV]
	rd[roff + I_PHASE] = 0.0
	rd[roff + I_CONTACT_CD] = 0.0
	rage_td.color_r[rslot] = td.color_r[slot]
	rage_td.color_g[rslot] = td.color_g[slot]
	rage_td.color_b[rslot] = td.color_b[slot]
	var re: PackedFloat32Array = rage_td.extra
	re[rslot * 2] = 0.0
	re[rslot * 2 + 1] = 0.0
	rage_td.spawn_timer[rslot] = 0.0
	rage_td.count += 1
	rage_td.alive_indices.append(rslot)
	_free_slot(td, slot)

func _trigger_rampage_enrage(td: Dictionary, slot: int) -> void:
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	var new_enraged_speed: float = td.type_speed * 3.0
	var rage_td: Dictionary = _type_data["rampage_enraged"]
	if rage_td.type_speed < 0.01:
		rage_td.type_speed = new_enraged_speed
	if rage_td.count >= rage_td.max_count:
		_free_slot(td, slot)
		return
	var rslot: int = _alloc_slot(rage_td)
	if rslot < 0:
		_free_slot(td, slot)
		return
	var rd: PackedFloat32Array = rage_td.d
	var roff: int = rslot * FIELDS
	rd[roff + I_PX] = d[off + I_PX]
	rd[roff + I_PY] = d[off + I_PY]
	rd[roff + I_SPEED] = rage_td.type_speed
	rd[roff + I_HP] = d[off + I_HP]
	rd[roff + I_MAX_HP] = d[off + I_MAX_HP]
	rd[roff + I_DAMAGE] = d[off + I_DAMAGE]
	rd[roff + I_EXPLOSION_DMG] = 0.0
	rd[roff + I_PUSHBACK] = 0.0
	rd[roff + I_XP] = d[off + I_XP]
	rd[roff + I_SV] = d[off + I_SV]
	rd[roff + I_PHASE] = 0.0
	rd[roff + I_CONTACT_CD] = 0.0
	rage_td.color_r[rslot] = td.color_r[slot]
	rage_td.color_g[rslot] = td.color_g[slot]
	rage_td.color_b[rslot] = td.color_b[slot]
	var re: PackedFloat32Array = rage_td.extra
	re[rslot * 2] = td.type_speed
	re[rslot * 2 + 1] = 0.0
	rage_td.spawn_timer[rslot] = 0.0
	rage_td.count += 1
	rage_td.alive_indices.append(rslot)
	_free_slot(td, slot)

func damage_area(center: Vector2, radius: float, amount: float) -> int:
	var killed: int = 0
	var radius_sq: float = radius * radius
	var player: Node2D = _get_player()
	var aura_mult: float = 1.0
	if player and ArtifactAbilityRunner._has_static_aura and center.distance_squared_to(player.global_position) <= 6400.0:
		aura_mult = 1.15
	var fx_count: int = 0
	var xp_batch: float = 0.0
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var hit_r_sq: float = hit_radius * hit_radius
		var d: PackedFloat32Array = td.d
		var is_rampage: bool = (key == "rampage")
		var candidates: PackedInt32Array = td.grid.query_nearby(center, radius + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - center.x
			var ddy: float = d[off + I_PY] - center.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq <= radius_sq + hit_r_sq:
				d[off + I_HP] -= amount * aura_mult * _boss_dmg_mult(key)
				if d[off + I_HP] <= 0.0:
					killed += 1
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
						fx_count += 1
					xp_batch += d[off + I_XP]
					_free_slot(td, j)
				else:
					if is_rampage:
						_trigger_rampage_enrage(td, j)
	if killed > 0:
		EventBus.enemy_died.emit(center, xp_batch, &"mesh")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func knockback_area(center: Vector2, radius: float, force: float) -> void:
	var radius_sq: float = radius * radius
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var hit_r_sq: float = hit_radius * hit_radius
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(center, radius + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			var off: int = j * FIELDS
			if d[off + I_HP] <= 0.0:
				continue
			var ddx: float = d[off + I_PX] - center.x
			var ddy: float = d[off + I_PY] - center.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq <= radius_sq + hit_r_sq and d_sq > 1.0:
				var dist := sqrt(d_sq)
				var push: float = force * (1.0 - dist / (radius + hit_radius))
				d[off + I_PX] += (ddx / dist) * push
				d[off + I_PY] += (ddy / dist) * push

func damage_nearest(pos: Vector2, radius: float, amount: float) -> bool:
	var best_td: Dictionary = {}
	var best_slot: int = -1
	var best_dist_sq: float = radius * radius
	var best_key: String = ""

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, radius + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			var d_sq: float = ddx * ddx + ddy * ddy
			var effective_sq: float = d_sq - hit_radius * hit_radius
			if effective_sq < best_dist_sq:
				best_dist_sq = effective_sq
				best_td = td
				best_slot = j
				best_key = key

	if best_slot < 0:
		return false

	var d: PackedFloat32Array = best_td.d
	var off: int = best_slot * FIELDS
	d[off + I_HP] -= amount * _boss_dmg_mult(best_key)
	if d[off + I_HP] <= 0.0:
		var death_type: String = best_key
		if death_type == "overlord_rage":
			death_type = "overlord"
		elif death_type == "rampage_enraged":
			death_type = "rampage"
		JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(best_td.color_r[best_slot], best_td.color_g[best_slot], best_td.color_b[best_slot]), death_type)
		var player: Node2D = _get_player()
		if player and player.has_method("add_xp"):
			player.add_xp(d[off + I_XP])
		EventBus.enemy_died.emit(Vector2(d[off + I_PX], d[off + I_PY]), d[off + I_XP], best_key)
		_free_slot(best_td, best_slot)
	else:
		if best_key == "rampage":
			_trigger_rampage_enrage(best_td, best_slot)
	return true

func find_closest_pos(pos: Vector2, max_range: float) -> Vector2:
	var range_sq: float = max_range * max_range
	var best_d_sq: float = range_sq
	var best_pos: Vector2 = Vector2.ZERO
	var found: bool = false

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, max_range + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best_pos = Vector2(d[off + I_PX], d[off + I_PY])
				found = true

	if not found:
		return Vector2.ZERO
	return best_pos

func find_closest_velocity(pos: Vector2, max_range: float) -> Vector2:
	var range_sq: float = max_range * max_range
	var best_vel: Vector2 = Vector2.ZERO
	var found: bool = false
	var player: Node2D = _get_player()

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, max_range + td.hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq < range_sq:
				range_sq = d_sq
				if player and is_instance_valid(player):
					var to_px: float = player.global_position.x - d[off + I_PX]
					var to_py: float = player.global_position.y - d[off + I_PY]
					var to_dist: float = sqrt(to_px * to_px + to_py * to_py)
					if to_dist > 0.0:
						best_vel = Vector2(to_px / to_dist * d[off + I_SPEED], to_py / to_dist * d[off + I_SPEED])
					else:
						best_vel = Vector2.ZERO
				found = true

	if not found:
		return Vector2.ZERO
	return best_vel

func find_closest_pos_and_velocity(pos: Vector2, max_range: float) -> Dictionary:
	var range_sq: float = max_range * max_range
	var best_d_sq: float = range_sq
	var best_pos: Vector2 = Vector2.ZERO
	var best_vel: Vector2 = Vector2.ZERO
	var found: bool = false
	var player: Node2D = _get_player()

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, max_range + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best_pos = Vector2(d[off + I_PX], d[off + I_PY])
				if player and is_instance_valid(player):
					var to_px: float = player.global_position.x - d[off + I_PX]
					var to_py: float = player.global_position.y - d[off + I_PY]
					var to_dist: float = sqrt(to_px * to_px + to_py * to_py)
					if to_dist > 0.0:
						best_vel = Vector2(to_px / to_dist * d[off + I_SPEED], to_py / to_dist * d[off + I_SPEED])
					else:
						best_vel = Vector2.ZERO
				found = true

	if not found:
		return {}
	return {&"pos": best_pos, &"vel": best_vel}

func has_units_in_range(pos: Vector2, max_range: float) -> bool:
	var range_sq: float = max_range * max_range
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_radius: float = td.hit_radius
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, max_range + hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq < range_sq + hit_radius * hit_radius:
				return true
	return false

func get_count(key: String = "") -> int:
	if key == "":
		var total: int = 0
		for k in _type_data:
			total += _type_data[k].count
		return total
	if not _type_data.has(key):
		return 0
	return _type_data[key].count

func get_total_count() -> int:
	return get_count()

func get_slot_hp(key: String, slot: int) -> float:
	var td: Dictionary = _type_data.get(key, {})
	if td.is_empty() or not td.has("d"):
		return 0.0
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	if off + I_HP >= d.size():
		return 0.0
	return d[off + I_HP]

func get_slot_pos(key: String, slot: int) -> Vector2:
	var td: Dictionary = _type_data.get(key, {})
	if td.is_empty() or not td.has("d"):
		return Vector2.ZERO
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	if off + I_PY >= d.size():
		return Vector2.ZERO
	return Vector2(d[off + I_PX], d[off + I_PY])

func set_slot_pos(key: String, slot: int, pos: Vector2) -> void:
	var td: Dictionary = _type_data.get(key, {})
	if td.is_empty() or not td.has("d"):
		return
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	if off + I_PY >= d.size():
		return
	d[off + I_PX] = pos.x
	d[off + I_PY] = pos.y

func is_slot_alive(key: String, slot: int) -> bool:
	var td: Dictionary = _type_data.get(key, {})
	if td.is_empty() or not td.has("alive_indices"):
		return false
	return td.alive_indices.has(slot)

func set_speed_mult(mult: float) -> void:
	_speed_mult = mult

func apply_slow(pos: Vector2, radius: float, duration: float = 4.0) -> void:
	var radius_sq: float = radius * radius
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, radius + td.hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			if ddx * ddx + ddy * ddy <= radius_sq:
				d[off + I_SLOW_TIMER] = maxf(d[off + I_SLOW_TIMER], duration)

func damage_line(from: Vector2, to: Vector2, half_width: float, amount: float) -> Array:
	var killed: int = 0
	var hit: int = 0
	var hw_sq: float = half_width * half_width
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = _get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_r_sq: float = td.hit_radius * td.hit_radius
		var d: PackedFloat32Array = td.d
		var is_rampage: bool = (key == "rampage")
		var min_x: float = minf(from.x, to.x) - half_width - td.hit_radius
		var min_y: float = minf(from.y, to.y) - half_width - td.hit_radius
		var max_x: float = maxf(from.x, to.x) + half_width + td.hit_radius
		var max_y: float = maxf(from.y, to.y) + half_width + td.hit_radius
		var candidates: PackedInt32Array = td.grid.query_aabb(Vector2(min_x, min_y), Vector2(max_x, max_y))
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var px: float = d[off + I_PX] - from.x
			var py: float = d[off + I_PY] - from.y
			var t: float = 0.0
			if line_len_sq > 0.001:
				t = (px * line_dx + py * line_dy) / line_len_sq
				t = clampf(t, 0.0, 1.0)
			var closest_x: float = t * line_dx
			var closest_y: float = t * line_dy
			var ddx: float = px - closest_x
			var ddy: float = py - closest_y
			if ddx * ddx + ddy * ddy <= hw_sq + hit_r_sq:
				d[off + I_HP] -= amount * _boss_dmg_mult(key)
				hit += 1
				if d[off + I_HP] <= 0.0:
					killed += 1
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
						fx_count += 1
					xp_batch += d[off + I_XP]
					_free_slot(td, j)
				else:
					if is_rampage:
						_trigger_rampage_enrage(td, j)
	if killed > 0:
		EventBus.enemy_died.emit(from, xp_batch, &"mesh")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return [killed, hit]

func damage_rect(from: Vector2, to: Vector2, half_width: float, amount: float) -> int:
	var killed: int = 0
	var hw_sq: float = half_width * half_width
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = _get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_r_sq: float = td.hit_radius * td.hit_radius
		var d: PackedFloat32Array = td.d
		var is_rampage: bool = (key == "rampage")
		var min_x: float = minf(from.x, to.x) - half_width - td.hit_radius
		var min_y: float = minf(from.y, to.y) - half_width - td.hit_radius
		var max_x: float = maxf(from.x, to.x) + half_width + td.hit_radius
		var max_y: float = maxf(from.y, to.y) + half_width + td.hit_radius
		var candidates: PackedInt32Array = td.grid.query_aabb(Vector2(min_x, min_y), Vector2(max_x, max_y))
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var px: float = d[off + I_PX] - from.x
			var py: float = d[off + I_PY] - from.y
			var t: float = 0.0
			if line_len_sq > 0.001:
				t = clampf((px * line_dx + py * line_dy) / line_len_sq, 0.0, 1.0)
			var closest_x: float = t * line_dx
			var closest_y: float = t * line_dy
			var ddx: float = px - closest_x
			var ddy: float = py - closest_y
			if ddx * ddx + ddy * ddy <= hw_sq + hit_r_sq:
				d[off + I_HP] -= amount * _boss_dmg_mult(key)
				if d[off + I_HP] <= 0.0:
					killed += 1
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
						fx_count += 1
					xp_batch += d[off + I_XP]
					_free_slot(td, j)
				else:
					if is_rampage:
						_trigger_rampage_enrage(td, j)
	if killed > 0:
		EventBus.enemy_died.emit(from, xp_batch, &"mesh")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func damage_rect_filtered(from: Vector2, to: Vector2, half_width: float, amount: float, hit_filter: Dictionary) -> int:
	var killed: int = 0
	var hw_sq: float = half_width * half_width
	var line_dx: float = to.x - from.x
	var line_dy: float = to.y - from.y
	var line_len_sq: float = line_dx * line_dx + line_dy * line_dy
	var player: Node2D = _get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_r_sq: float = td.hit_radius * td.hit_radius
		var d: PackedFloat32Array = td.d
		var is_rampage: bool = (key == "rampage")
		var min_x: float = minf(from.x, to.x) - half_width - td.hit_radius
		var min_y: float = minf(from.y, to.y) - half_width - td.hit_radius
		var max_x: float = maxf(from.x, to.x) + half_width + td.hit_radius
		var max_y: float = maxf(from.y, to.y) + half_width + td.hit_radius
		var candidates: PackedInt32Array = td.grid.query_aabb(Vector2(min_x, min_y), Vector2(max_x, max_y))
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			var filter_key: String = key + "_" + str(j)
			if hit_filter.has(filter_key):
				continue
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var px: float = d[off + I_PX] - from.x
			var py: float = d[off + I_PY] - from.y
			var t: float = 0.0
			if line_len_sq > 0.001:
				t = clampf((px * line_dx + py * line_dy) / line_len_sq, 0.0, 1.0)
			var closest_x: float = t * line_dx
			var closest_y: float = t * line_dy
			var ddx: float = px - closest_x
			var ddy: float = py - closest_y
			if ddx * ddx + ddy * ddy <= hw_sq + hit_r_sq:
				hit_filter[filter_key] = true
				d[off + I_HP] -= amount * _boss_dmg_mult(key)
				if d[off + I_HP] <= 0.0:
					killed += 1
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
						fx_count += 1
					xp_batch += d[off + I_XP]
					_free_slot(td, j)
				else:
					if is_rampage:
						_trigger_rampage_enrage(td, j)
	if killed > 0:
		EventBus.enemy_died.emit(from, xp_batch, &"mesh")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

func pull_toward(center: Vector2, pull_range: float, strength: float) -> void:
	var range_sq: float = pull_range * pull_range
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(center, pull_range)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = center.x - d[off + I_PX]
			var ddy: float = center.y - d[off + I_PY]
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq < range_sq and d_sq > 1.0:
				var inv_dist: float = 1.0 / sqrt(d_sq)
				d[off + I_PX] += ddx * inv_dist * strength
				d[off + I_PY] += ddy * inv_dist * strength

func damage_cone(origin: Vector2, tip: Vector2, half_angle: float, amount: float) -> int:
	var killed: int = 0
	var dir := tip - origin
	var length_sq: float = dir.length_squared()
	var length := sqrt(length_sq)
	var forward := dir / maxf(length, 0.001)
	var player: Node2D = _get_player()
	var fx_count: int = 0
	var xp_batch: float = 0.0
	var cos_half := cos(half_angle)

	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var hit_r_sq: float = td.hit_radius * td.hit_radius
		var d: PackedFloat32Array = td.d
		var is_rampage: bool = (key == "rampage")
		var candidates: PackedInt32Array = td.grid.query_nearby(origin, length + td.hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			var off: int = j * FIELDS
			if d[off + I_HP] <= 0.0:
				continue
			var ddx: float = d[off + I_PX] - origin.x
			var ddy: float = d[off + I_PY] - origin.y
			var d_sq: float = ddx * ddx + ddy * ddy
			if d_sq > length_sq + hit_r_sq:
				continue
			var dist := sqrt(d_sq)
			var dot: float = 0.0
			if dist > 1.0:
				dot = (ddx * forward.x + ddy * forward.y) / dist
			if dot >= cos_half or dist < 1.0:
				d[off + I_HP] -= amount * _boss_dmg_mult(key)
				if d[off + I_HP] <= 0.0:
					killed += 1
					if fx_count < MAX_DEATH_FX_PER_BATCH:
						var death_type: String = key
						if death_type == "overlord_rage":
							death_type = "overlord"
						elif death_type == "rampage_enraged":
							death_type = "rampage"
						JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[j], td.color_g[j], td.color_b[j]), death_type)
						fx_count += 1
					xp_batch += d[off + I_XP]
					_free_slot(td, j)
				else:
					if is_rampage:
						_trigger_rampage_enrage(td, j)
	if killed > 0:
		EventBus.enemy_died.emit(origin, xp_batch, &"mesh")
		if player and player.has_method("add_xp"):
			player.add_xp(xp_batch)
	return killed

var _type_keys: PackedStringArray = PackedStringArray()
var _type_key_to_idx: Dictionary = {}
var _cross_pos_x: PackedFloat32Array = PackedFloat32Array()
var _cross_pos_y: PackedFloat32Array = PackedFloat32Array()

func query_all_positions_near(pos: Vector2, radius: float) -> int:
	_cross_pos_x.resize(0)
	_cross_pos_y.resize(0)
	var radius_sq: float = radius * radius
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var d: PackedFloat32Array = td.d
		td.grid.query_nearby_into(pos, radius, _cross_buf)
		for ci in range(_cross_buf.size()):
			var j: int = _cross_buf[ci]
			var off: int = j * FIELDS
			if d[off + I_HP] <= 0.0:
				continue
			var sdx: float = d[off + I_PX] - pos.x
			var sdy: float = d[off + I_PY] - pos.y
			if sdx * sdx + sdy * sdy < radius_sq:
				_cross_pos_x.append(d[off + I_PX])
				_cross_pos_y.append(d[off + I_PY])
	return _cross_pos_x.size()

func _build_type_index_map() -> void:
	_type_keys.resize(0)
	_type_key_to_idx.clear()
	var idx: int = 0
	for key in _type_data:
		_type_keys.append(key)
		_type_key_to_idx[key] = idx
		idx += 1

func get_nearby_ids(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var radius_sq: float = radius * radius
	for key in _type_data:
		var td: Dictionary = _type_data[key]
		var type_idx: int = _type_key_to_idx.get(key, 0)
		var d: PackedFloat32Array = td.d
		var candidates: PackedInt32Array = td.grid.query_nearby(pos, radius + td.hit_radius)
		for idx_i in range(candidates.size()):
			var j: int = candidates[idx_i]
			if d[j * FIELDS + I_HP] <= 0.0:
				continue
			var off: int = j * FIELDS
			var ddx: float = d[off + I_PX] - pos.x
			var ddy: float = d[off + I_PY] - pos.y
			if ddx * ddx + ddy * ddy <= radius_sq:
				result.append((type_idx << 16) | j)
	return result

func damage_id(id: int, amount: float) -> int:
	var type_idx: int = (id >> 16) & 0xFFFF
	var slot: int = id & 0xFFFF
	if type_idx < 0 or type_idx >= _type_keys.size():
		return 0
	var key: String = _type_keys[type_idx]
	if not _type_data.has(key):
		return 0
	var td: Dictionary = _type_data[key]
	var d: PackedFloat32Array = td.d
	var off: int = slot * FIELDS
	if off + I_HP >= d.size() or d[off + I_HP] <= 0.0:
		return 0
	d[off + I_HP] -= amount * _boss_dmg_mult(key)
	if d[off + I_HP] <= 0.0:
		var death_type: String = key
		if death_type == "overlord_rage":
			death_type = "overlord"
		elif death_type == "rampage_enraged":
			death_type = "rampage"
		JuiceManager.spawn_death_effect(Vector2(d[off + I_PX], d[off + I_PY]), Color(td.color_r[slot], td.color_g[slot], td.color_b[slot]), death_type)
		var player: Node2D = _get_player()
		if player and player.has_method("add_xp"):
			player.add_xp(d[off + I_XP])
		EventBus.enemy_died.emit(Vector2(d[off + I_PX], d[off + I_PY]), d[off + I_XP], key)
		_free_slot(td, slot)
		return 1
	else:
		if key == "rampage":
			_trigger_rampage_enrage(td, slot)
	return 0
