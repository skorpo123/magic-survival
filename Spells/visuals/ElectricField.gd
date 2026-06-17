class_name ElectricField
extends Node2D

const NODE_COUNT := 8

var _radius: float = 90.0
var _damage: float = 6.0
var _damage_interval: float = 0.6
var _damage_timer: float = 0.0
var _center: Node2D = null
var _arc_count: int = 3
var _pulse_t: float = 0.0
var _flash_t: float = 0.0
var _color_primary: Color = Color(0.6, 0.8, 1.0)
var _color_secondary: Color = Color(0.3, 0.5, 1.0)
var _chain_count: int = 0
var _chain_range: float = 150.0
var _chain_damage_mult: float = 0.5
var _enemy_contact: bool = false
var _contact_flash_t: float = 0.0
var _shockwave_active: bool = false
var _shockwave_timer: float = 0.0
var _shockwave_interval: float = 2.0
var _shockwave_rings: Array = []
var _shockwave_damage: float = 0.0
var _is_arc_flash: bool = false
var _contact_check_frame: int = 0

var _node_angles: PackedFloat32Array = PackedFloat32Array()
var _arc_jitter: Array = []
var _zap_targets: Array = []
var _zap_jitter: Array = []
var _zap_spark_frame: int = 0
var _ring_offset: float = 0.0
var _node_flash: PackedFloat32Array = PackedFloat32Array()

static var _shared_mat: CanvasItemMaterial = null
static var _halo_tex: Texture2D = null
var _halo: Sprite2D = null

func _ready() -> void:
	z_index = 2
	material = _get_shared_mat()
	_ensure_halo_tex()
	_halo = Sprite2D.new()
	_halo.texture = _halo_tex
	_halo.z_index = z_index + 1
	_halo.visible = false
	add_child(_halo)
	_init_nodes()

static func _ensure_halo_tex() -> void:
	if _halo_tex:
		return
	var s: int = 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c: float = s * 0.5
	for px in range(s):
		for py in range(s):
			var dx := float(px) - c
			var dy := float(py) - c
			var dist := sqrt(dx * dx + dy * dy) / c
			if dist <= 1.0:
				var fade := 1.0 - dist
				var a: float = fade * fade * fade
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
			else:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
	_halo_tex = ImageTexture.create_from_image(img)

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_mat

func _init_nodes() -> void:
	_node_angles.resize(NODE_COUNT)
	_node_flash.resize(NODE_COUNT)
	for i in range(NODE_COUNT):
		_node_angles[i] = TAU / NODE_COUNT * i
		_node_flash[i] = 0.0
	_regenerate_arcs()

func _regenerate_arcs() -> void:
	_arc_jitter.clear()
	for i in range(NODE_COUNT):
		var segs: Array = []
		var seg_count := 6
		for s in range(seg_count):
			segs.append(randf_range(-1.0, 1.0))
		_arc_jitter.append(segs)

func setup(center: Node2D, radius: float, damage: float, damage_interval: float, arc_count: int, color_primary: Color, color_secondary: Color, chain_count: int = 0, chain_range: float = 150.0, chain_damage_mult: float = 0.5, shockwave: bool = false, shockwave_interval: float = 2.0, arc_flash: bool = false) -> void:
	_center = center
	_radius = radius
	_damage = damage
	_damage_interval = damage_interval
	_arc_count = arc_count
	_color_primary = color_primary
	_color_secondary = color_secondary
	_chain_count = chain_count
	_chain_range = chain_range
	_chain_damage_mult = chain_damage_mult
	_shockwave_active = shockwave
	_shockwave_interval = shockwave_interval
	_shockwave_damage = damage * 0.6
	_is_arc_flash = arc_flash
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	_init_nodes()
	if _halo:
		_halo.visible = true

func update_params(radius: float, damage: float, damage_interval: float, arc_count: int, chain_count: int = 0) -> void:
	_radius = radius
	_damage = damage
	_damage_interval = damage_interval
	_arc_count = arc_count
	_chain_count = chain_count
	_regenerate_arcs()

func set_colors(primary: Color, secondary: Color) -> void:
	_color_primary = primary
	_color_secondary = secondary

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not is_instance_valid(_center):
		return
	global_position = _center.global_position
	_pulse_t += delta
	_ring_offset += delta * 30.0
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 5.0, 0.0)
	for i in range(NODE_COUNT):
		if _node_flash[i] > 0.0:
			_node_flash[i] = maxf(_node_flash[i] - delta * 4.0, 0.0)
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		_deal_zone_damage()
		_flash_t = 1.0
		if _chain_count > 0:
			_do_chain_damage()
		_regenerate_arcs()
	var frame: int = Engine.get_process_frames()
	if frame - _contact_check_frame >= 3:
		_contact_check_frame = frame
		_enemy_contact = SwarmManager.has_units_in_range(global_position, _radius) or EnemyMeshManager.has_units_in_range(global_position, _radius)
	if _enemy_contact:
		_contact_flash_t = minf(_contact_flash_t + delta * 6.0, 1.0)
	else:
		_contact_flash_t = maxf(_contact_flash_t - delta * 3.0, 0.0)
	_update_zap_targets()
	if _shockwave_active:
		_shockwave_timer -= delta
		if _shockwave_timer <= 0.0:
			_shockwave_timer = _shockwave_interval
			var burst_radius := _radius * 2.5
			SwarmManager.damage_area(global_position, burst_radius, _shockwave_damage)
			EnemyMeshManager.damage_area(global_position, burst_radius, _shockwave_damage)
			SwarmManager.knockback_area(global_position, burst_radius, 80.0)
			EnemyMeshManager.knockback_area(global_position, burst_radius, 80.0)
			_shockwave_rings.append({start_radius = _radius, max_radius = burst_radius, age = 0.0, max_age = 0.8})
		var still_alive: Array = []
		for ring in _shockwave_rings:
			ring.age += delta
			if ring.age < ring.max_age:
				still_alive.append(ring)
		_shockwave_rings = still_alive
	_update_halo()
	queue_redraw()

func _update_zap_targets() -> void:
	_zap_targets.clear()
	_zap_jitter.clear()
	if not _enemy_contact:
		return
	var closest: Vector2 = SwarmManager.find_closest_pos(global_position, _radius)
	if closest == Vector2.ZERO:
		closest = EnemyMeshManager.find_closest_pos(global_position, _radius)
	if closest == Vector2.ZERO:
		return
	var local_pos := closest - global_position
	var best_idx: int = 0
	var best_dist: float = INF
	for n in range(NODE_COUNT):
		var npos := _get_node_pos(n)
		var d: float = npos.distance_to(local_pos)
		if d < best_dist:
			best_dist = d
			best_idx = n
	_zap_targets.append({node_idx = best_idx, enemy_pos = local_pos})
	_zap_jitter.clear()
	var segs := 5
	for s in range(segs):
		_zap_jitter.append(randf_range(-1.0, 1.0))
	_node_flash[best_idx] = 1.0
	_node_flash[(best_idx + 1) % NODE_COUNT] = maxf(_node_flash[(best_idx + 1) % NODE_COUNT], 0.5)
	_node_flash[(best_idx + NODE_COUNT - 1) % NODE_COUNT] = maxf(_node_flash[(best_idx + NODE_COUNT - 1) % NODE_COUNT], 0.5)

func _get_node_pos(idx: int) -> Vector2:
	var a: float = _node_angles[idx]
	return Vector2(cos(a), sin(a)) * _radius

func _deal_zone_damage() -> void:
	SwarmManager.damage_area(global_position, _radius, _damage)
	EnemyMeshManager.damage_area(global_position, _radius, _damage)

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 4.0)
	var flash_alpha := _flash_t
	var contact_alpha := _contact_flash_t

	_draw_fence_ring(pulse, flash_alpha, contact_alpha)
	_draw_node_arcs(pulse, flash_alpha)
	_draw_nodes(pulse, contact_alpha)
	_draw_zaps(contact_alpha)

	for ring in _shockwave_rings:
		var t: float = ring.age / ring.max_age
		var r: float = lerp(ring.start_radius, ring.max_radius, ease(t, -2.0))
		var alpha := (1.0 - t) * 0.7
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(_color_secondary.r * 1.5, _color_secondary.g * 1.5, _color_secondary.b * 1.5, alpha), 4.0 * (1.0 - t))

func _draw_fence_ring(pulse: float, flash_alpha: float, contact_alpha: float) -> void:
	var base_alpha := 0.15 * pulse + 0.3 * flash_alpha + 0.2 * contact_alpha
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 64, Color(_color_secondary.r * 0.4, _color_secondary.g * 0.4, _color_secondary.b * 0.4, base_alpha * 0.5), 10.0)
	draw_arc(Vector2.ZERO, _radius, _ring_offset * 0.01, _ring_offset * 0.01 + TAU, 64, Color(_color_secondary.r, _color_secondary.g, _color_secondary.b, base_alpha), 3.5)
	draw_arc(Vector2.ZERO, _radius, -_ring_offset * 0.015, -_ring_offset * 0.015 + TAU, 64, Color(_color_primary.r, _color_primary.g, _color_primary.b, base_alpha * 1.5 + 0.2 * pulse), 1.5)

func _draw_nodes(pulse: float, contact_alpha: float) -> void:
	for i in range(NODE_COUNT):
		var pos := _get_node_pos(i)
		var node_flash: float = _node_flash[i]
		var glow_r := 6.0 + 4.0 * node_flash
		var glow_alpha := 0.35 * pulse + 0.4 * contact_alpha + 0.6 * node_flash
		draw_circle(pos, glow_r, Color(_color_primary.r, _color_primary.g, _color_primary.b, glow_alpha * 0.5))
		var core_alpha := 0.7 * pulse + 0.3 + 0.5 * node_flash
		draw_circle(pos, 3.0, Color(minf(_color_primary.r + 0.4, 1.0), minf(_color_primary.g + 0.4, 1.0), minf(_color_primary.b + 0.3, 1.0), core_alpha))
		draw_circle(pos, 1.5, Color(1.0, 1.0, 1.0, 0.5 + 0.5 * node_flash))

func _draw_node_arcs(pulse: float, flash_alpha: float) -> void:
	for i in range(NODE_COUNT):
		var next_i: int = (i + 1) % NODE_COUNT
		var from := _get_node_pos(i)
		var to := _get_node_pos(next_i)
		var jitter: Array = _arc_jitter[i] if i < _arc_jitter.size() else []
		var seg_count: int = jitter.size() if not jitter.is_empty() else 6
		var points := PackedVector2Array()
		points.append(from)
		var direction := to - from
		var perp := Vector2(-direction.y, direction.x).normalized()
		for s in range(1, seg_count):
			var t: float = float(s) / float(seg_count)
			var mid := from + direction * t
			var j: float = 8.0 * pulse * (jitter[s] if s < jitter.size() else 0.0)
			points.append(mid + perp * j)
		points.append(to)
		var arc_alpha := 0.4 * pulse + 0.4 * flash_alpha
		draw_polyline(points, Color(_color_secondary.r, _color_secondary.g, _color_secondary.b, arc_alpha), 2.0 + flash_alpha * 1.5)

func _draw_zaps(contact_alpha: float) -> void:
	for zap_idx in range(_zap_targets.size()):
		var zap: Dictionary = _zap_targets[zap_idx]
		var node_pos := _get_node_pos(zap.node_idx)
		var enemy_pos: Vector2 = zap.enemy_pos
		var direction := enemy_pos - node_pos
		var perp := Vector2(-direction.y, direction.x).normalized()
		var points := PackedVector2Array()
		points.append(node_pos)
		var segs := 5
		for s in range(1, segs):
			var t: float = float(s) / float(segs)
			var mid := node_pos + direction * t
			var j: float = 12.0 * (_zap_jitter[s] if s < _zap_jitter.size() else 0.0) * contact_alpha
			points.append(mid + perp * j)
		points.append(enemy_pos)
		draw_polyline(points, Color(_color_primary.r, _color_primary.g, _color_primary.b, 0.7 * contact_alpha), 5.0)
		draw_polyline(points, Color(1.0, 1.0, 1.0, 0.9 * contact_alpha), 2.5)

func _do_chain_damage() -> void:
	var chain_dmg := _damage * _chain_damage_mult
	for _c in range(_chain_count):
		var offset := Vector2(randf_range(-_radius, _radius), randf_range(-_radius, _radius)) * 0.5
		var search_pos := global_position + offset
		var chain_pos: Vector2 = SwarmManager.find_closest_pos(search_pos, _chain_range)
		if chain_pos == Vector2.ZERO:
			chain_pos = EnemyMeshManager.find_closest_pos(search_pos, _chain_range)
		if chain_pos != Vector2.ZERO:
			SwarmManager.damage_area(chain_pos, 30.0, chain_dmg)
			EnemyMeshManager.damage_area(chain_pos, 30.0, chain_dmg)
			var parent := get_tree().current_scene
			if parent:
				var arc := LightningBolt.acquire()
				arc._bolt_color = Color(_color_primary.r * 0.7, _color_primary.g * 0.7, _color_primary.b, 0.9)
				arc._glow_color = Color(_color_secondary.r * 0.3, _color_secondary.g * 0.3, _color_secondary.b, 0.2)
				arc._core_color = Color(1.0, 1.0, 1.0)
				arc._lifetime = 0.25
				arc._glow_width = 10.0
				arc._bolt_width = 4.0
				arc._core_width = 1.5
				arc.setup(global_position, chain_pos, 6, 12.0)

func _update_halo() -> void:
	if not _halo:
		return
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 4.0)
	var flash_alpha := _flash_t
	var contact_alpha := _contact_flash_t
	var halo_alpha := 0.12 * pulse + 0.2 * flash_alpha + 0.1 * contact_alpha
	if halo_alpha < 0.02:
		_halo.visible = false
		return
	_halo.visible = true
	var scale_f := _radius / 64.0
	_halo.scale = Vector2(scale_f, scale_f)
	_halo.modulate = Color(_color_primary.r * 2.0, _color_primary.g * 2.0, _color_primary.b * 2.0, halo_alpha)

func cleanup() -> void:
	pass
