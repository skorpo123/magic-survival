class_name ArcaneRay
extends Node2D

signal finished

var _direction: Vector2 = Vector2.RIGHT
var _damage: float = 12.0
var _half_width: float = 1.0
var _damage_interval: float = 0.1
var _damage_timer: float = 0.0
var _grow_time: float = 0.2
var _sustain_time: float = 0.5
var _fade_time: float = 0.6
var _age: float = 0.0
var _color_primary: Color = Color(1.0, 0.3, 0.2)
var _color_secondary: Color = Color(0.6, 0.1, 0.05)
var _reflect: bool = false
var _is_photon: bool = false
var _player_ref: Node2D = null
var _pulse_phase: float = 0.0
var _prev_positions: PackedVector2Array = PackedVector2Array()
var _reflect_fx_timer: float = 0.0

const ORIGIN_OFFSET: float = 61.5

static var _glow_tex: ImageTexture = null
static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	top_level = true
	z_index = 3
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	material = _get_shared_mat()
	_ensure_textures()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func _ensure_textures() -> void:
	if not _glow_tex:
		var size := 16
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := size / 2.0
		for px in range(size):
			for py in range(size):
				var dx := (px - c) / c
				var dy := (py - c) / c
				var dist := sqrt(dx * dx + dy * dy)
				if dist <= 1.0:
					var fade := 1.0 - dist
					var a: float = fade * fade * fade * fade * 1.5
					img.set_pixel(px, py, Color(1.0, 0.35, 0.15, minf(a, 1.0)))
				else:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
		_glow_tex = ImageTexture.create_from_image(img)

func launch(direction: Vector2, params: Dictionary) -> void:
	_direction = direction.normalized()
	_damage = params.get(&"damage", 12.0)
	_half_width = params.get(&"half_width", 2.8)
	_damage_interval = params.get(&"damage_interval", 0.1)
	_grow_time = params.get(&"grow_time", 0.2)
	_sustain_time = params.get(&"sustain_time", 0.5)
	_fade_time = params.get(&"fade_time", 0.6)
	_color_primary = params.get(&"color_primary", Color(1.0, 0.3, 0.2))
	_color_secondary = params.get(&"color_secondary", Color(0.6, 0.1, 0.05))
	_reflect = params.get(&"reflect", false)
	_is_photon = params.get(&"is_photon", false)
	_age = 0.0
	_damage_timer = 0.0
	_pulse_phase = 0.0
	_prev_positions.clear()
	_player_ref = GameManager.get_player()
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta
	_pulse_phase += delta * 10.0
	if is_instance_valid(_player_ref):
		global_position = _player_ref.global_position

	_prev_positions.append(global_position)
	if _prev_positions.size() > 6:
		_prev_positions.remove_at(0)

	_damage_timer -= delta
	if _reflect_fx_timer > 0.0:
		_reflect_fx_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		_deal_line_damage()

	var total_time := _grow_time + _sustain_time + _fade_time
	if _age >= total_time:
		_prev_positions.clear()
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		finished.emit()
		return
	queue_redraw()

func update_params(params: Dictionary) -> void:
	_damage = params.get(&"damage", _damage)
	_half_width = params.get(&"half_width", _half_width)
	_damage_interval = params.get(&"damage_interval", _damage_interval)
	_color_primary = params.get(&"color_primary", _color_primary)
	_color_secondary = params.get(&"color_secondary", _color_secondary)
	_reflect = params.get(&"reflect", _reflect)
	_is_photon = params.get(&"is_photon", _is_photon)

func update_direction(new_dir: Vector2) -> void:
	_direction = new_dir.normalized()

func restart() -> void:
	_age = 0.0
	_damage_timer = 0.0
	_pulse_phase = 0.0
	_prev_positions.clear()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	queue_redraw()

func _deal_line_damage() -> void:
	var vp := _get_camera_viewport_rect()
	var diag: float = maxf(vp.size.x, vp.size.y) * 1.5
	var origin := global_position + _direction * ORIGIN_OFFSET
	var to := origin + _direction * diag
	SwarmManager.damage_line(origin, to, _half_width, _damage)
	EnemyMeshManager.damage_line(origin, to, _half_width, _damage)
	if _reflect:
		var cur_dir := _direction
		var cur_origin := origin
		var reflect_dmg_mult := 0.6
		for bounce in range(2):
			var hit := _find_viewport_hit(cur_origin, cur_dir, vp)
			if hit.wall < 0:
				break
			var reflected_dir := cur_dir
			if hit.wall == 0:
				reflected_dir = Vector2(-cur_dir.x, cur_dir.y)
			elif hit.wall == 1:
				reflected_dir = Vector2(cur_dir.x, -cur_dir.y)
			var hit_pos: Vector2 = cur_origin + cur_dir * hit.t
			var reflect_to := hit_pos + reflected_dir * diag
			SwarmManager.damage_line(hit_pos, reflect_to, _half_width, _damage * reflect_dmg_mult)
			EnemyMeshManager.damage_line(hit_pos, reflect_to, _half_width, _damage * reflect_dmg_mult)
			cur_dir = reflected_dir
			cur_origin = hit_pos
			reflect_dmg_mult *= 0.6

func _find_viewport_hit(ray_origin: Vector2, ray_dir: Vector2, vp: Rect2) -> Dictionary:
	var min_t: float = 1e20
	var wall := -1
	var left: float = vp.position.x
	var right: float = vp.position.x + vp.size.x
	var top: float = vp.position.y
	var bottom: float = vp.position.y + vp.size.y
	if absf(ray_dir.x) > 0.0001:
		var t_left: float = (left - ray_origin.x) / ray_dir.x
		var t_right: float = (right - ray_origin.x) / ray_dir.x
		if t_left > 0.0 and t_left < min_t:
			var y: float = ray_origin.y + ray_dir.y * t_left
			if y >= top and y <= bottom:
				min_t = t_left
				wall = 0
		if t_right > 0.0 and t_right < min_t:
			var y: float = ray_origin.y + ray_dir.y * t_right
			if y >= top and y <= bottom:
				min_t = t_right
				wall = 0
	if absf(ray_dir.y) > 0.0001:
		var t_top: float = (top - ray_origin.y) / ray_dir.y
		var t_bottom: float = (bottom - ray_origin.y) / ray_dir.y
		if t_top > 0.0 and t_top < min_t:
			var x: float = ray_origin.x + ray_dir.x * t_top
			if x >= left and x <= right:
				min_t = t_top
				wall = 1
		if t_bottom > 0.0 and t_bottom < min_t:
			var x: float = ray_origin.x + ray_dir.x * t_bottom
			if x >= left and x <= right:
				min_t = t_bottom
				wall = 1
	return {t = min_t, wall = wall}

func _get_camera_viewport_rect() -> Rect2:
	var cam: Camera2D = null
	if is_instance_valid(_player_ref):
		cam = _player_ref.get_node_or_null("Camera2D")
	if not cam:
		var vp := get_viewport()
		if vp:
			return vp.get_visible_rect()
		return Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
	var cam_pos: Vector2 = cam.global_position
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom: Vector2 = cam.zoom
	var half_w := vp_size.x / (2.0 * zoom.x)
	var half_h := vp_size.y / (2.0 * zoom.y)
	return Rect2(cam_pos.x - half_w, cam_pos.y - half_h, half_w * 2.0, half_h * 2.0)

func _draw() -> void:
	var alpha: float
	if _age < _grow_time:
		alpha = clampf(_age / _grow_time, 0.0, 1.0)
	elif _age < _grow_time + _sustain_time:
		alpha = 1.0
	else:
		var fade_age: float = _age - _grow_time - _sustain_time
		alpha = 1.0 - clampf(fade_age / _fade_time, 0.0, 1.0)

	if alpha <= 0.01:
		return

	var vp := _get_camera_viewport_rect()
	var diag: float = maxf(vp.size.x, vp.size.y) * 1.5
	var origin_local := _direction * ORIGIN_OFFSET
	var end_local := origin_local + _direction * diag
	var pulse := 1.0 + sin(_pulse_phase) * 0.2
	var photon_mult := 1.5 if _is_photon else 1.0
	var photon_alpha := 1.3 if _is_photon else 1.0

	var hw: float = _half_width

	var col_outer := Color(_color_secondary.r, _color_secondary.g, _color_secondary.b, alpha * 0.8 * photon_alpha)
	var col_mid := Color(_color_primary.r, _color_primary.g, _color_primary.b, alpha * 0.95 * photon_alpha)
	var col_core := Color(1.0, 0.7, 0.5, alpha * 1.5 * pulse * photon_alpha)

	draw_line(origin_local, end_local, col_outer, hw * 1.8 * photon_mult, true)
	draw_line(origin_local, end_local, col_mid, hw * 0.9 * photon_mult, true)
	draw_line(origin_local, end_local, col_core, maxf(hw * 0.3 * photon_mult, 1.0), true)

	if _glow_tex:
		draw_texture(_glow_tex, origin_local - _glow_tex.get_size() * 0.5, Color(_color_primary.r, _color_primary.g, _color_primary.b, alpha * 1.5 * pulse * photon_alpha))

	for i in range(_prev_positions.size()):
		var t := float(i) / float(maxf(_prev_positions.size(), 1))
		var trail_alpha := alpha * 0.25 * t
		var trail_r := hw * 0.8 * (0.3 + 0.7 * t)
		var tp := _prev_positions[i] - global_position
		tp = tp.move_toward(origin_local, ORIGIN_OFFSET)
		draw_circle(tp, trail_r, Color(_color_secondary.r, _color_secondary.g, _color_secondary.b, trail_alpha))

	if _reflect:
		var cur_dir := _direction
		var cur_local := origin_local
		var reflect_alpha_mult := 1.0
		for bounce in range(2):
			var hit := _find_viewport_hit(global_position + cur_local, cur_dir, vp)
			if hit.wall < 0:
				break
			var reflected_dir := cur_dir
			if hit.wall == 0:
				reflected_dir = Vector2(-cur_dir.x, cur_dir.y)
			elif hit.wall == 1:
				reflected_dir = Vector2(cur_dir.x, -cur_dir.y)
			var hit_local: Vector2 = cur_local + cur_dir * hit.t
			var reflect_end := hit_local + reflected_dir * diag
			var ref_alpha := alpha * reflect_alpha_mult
			var ref_outer := Color(_color_secondary.r, _color_secondary.g, _color_secondary.b, ref_alpha * 0.5)
			var ref_mid := Color(_color_primary.r, _color_primary.g, _color_primary.b, ref_alpha * 0.7)
			var ref_core := Color(1.0, 0.7, 0.5, ref_alpha * 1.2 * pulse)
			draw_line(hit_local, reflect_end, ref_outer, hw * 1.5, true)
			draw_line(hit_local, reflect_end, ref_mid, hw * 0.75, true)
			draw_line(hit_local, reflect_end, ref_core, maxf(hw * 0.25, 1.0), true)
			draw_circle(hit_local, hw * 2.5, Color(1.0, 0.8, 0.5, ref_alpha * 0.6))
			cur_dir = reflected_dir
			cur_local = hit_local
			reflect_alpha_mult *= 0.6
		if _reflect_fx_timer <= 0.0:
			var first_hit := _find_viewport_hit(global_position + origin_local, _direction, vp)
			if first_hit.wall >= 0:
				var hit_t: float = first_hit.t
				var hit_world: Vector2 = global_position + origin_local + _direction * hit_t
				BurstEffectPool.spawn("arcane_impact", hit_world, _color_primary)
				_reflect_fx_timer = 0.15
