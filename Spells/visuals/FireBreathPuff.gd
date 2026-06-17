class_name FireBreathPuff
extends Node2D

var _alive: bool = false
var _emitting: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _fade_timer: float = 0.0
var _cone_half_angle: float = 0.785
var _cone_range: float = 180.0
var _vel_ratio: float = 1.0
var _visual_range_mult: float = 1.0
var _halo_alpha: float = 0.0
var _halo_tint: Color = Color(0.9, 0.45, 0.12)
var _burst_progress: float = 0.0

var _glow: GPUParticles2D = null
var _core: GPUParticles2D = null
var _body: GPUParticles2D = null
var _tail: GPUParticles2D = null
var _halo: Sprite2D = null

var _base_vels: Array = []
var _base_spreads: PackedFloat32Array = PackedFloat32Array()
var _base_lifetimes: PackedFloat32Array = PackedFloat32Array()
var _active_mod: StringName = &""
var _base_tint: Color = Color(2.0, 1.5, 1.0, 1.0)

const FORWARD_OFFSET: float = 45.0
const FADE_TIME: float = 0.4
const DEFAULT_FIRE_TINT: Color = Color(1.0, 0.5, 0.1)
const DESIGN_RANGE: float = 200.0

static var _blob_tex: Texture2D = null
static var _halo_tex: Texture2D = null
static var _glow_ramp: GradientTexture1D = null
static var _core_ramp: GradientTexture1D = null
static var _body_ramp: GradientTexture1D = null
static var _tail_ramp: GradientTexture1D = null
static var _scale_curve_inner: CurveTexture = null
static var _scale_curve_outer: CurveTexture = null

func _ready() -> void:
	top_level = true
	z_index = 10
	visible = false
	_ensure_shared()
	_build()
	set_process(false)

static func _ensure_shared() -> void:
	if _blob_tex:
		return

	var tw := 24
	var th := 18
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	var cx: float = tw * 0.4
	var cy: float = th * 0.5
	var head_r: float = th * 0.42
	for px in range(tw):
		for py in range(th):
			var dx := float(px) - cx
			var dy := float(py) - cy
			var dist := sqrt(dx * dx + dy * dy)
			if px < cx:
				if dist <= head_r:
					img.set_pixel(px, py, Color.WHITE)
				else:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
			else:
				var t: float = (float(px) - cx) / (float(tw) - cx)
				var tail_r: float = head_r * (1.0 - t * t)
				if absf(dy) <= tail_r and dist <= head_r + (float(px) - cx) * 0.5:
					var fade: float = 1.0 - t * t
					img.set_pixel(px, py, Color(1, 1, 1, fade))
				else:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
	_blob_tex = ImageTexture.create_from_image(img)

	if not _halo_tex:
		var hs: int = 128
		var himg := Image.create(hs, hs, false, Image.FORMAT_RGBA8)
		var hc: float = hs * 0.5
		for px in range(hs):
			for py in range(hs):
				var dx := float(px) - hc
				var dy := float(py) - hc
				var dist := sqrt(dx * dx + dy * dy) / hc
				if dist <= 1.0:
					var fade := 1.0 - dist
					var a: float = fade * fade * fade
					himg.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
				else:
					himg.set_pixel(px, py, Color(0, 0, 0, 0))
		_halo_tex = ImageTexture.create_from_image(himg)

	var gg := Gradient.new()
	gg.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	gg.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gg.colors = PackedColorArray([
		Color(1.0, 0.98, 0.92, 0.85),
		Color(1.0, 0.82, 0.42, 0.35),
		Color(0.9, 0.45, 0.08, 0.0),
	])
	_glow_ramp = GradientTexture1D.new()
	_glow_ramp.gradient = gg

	var cg := Gradient.new()
	cg.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	cg.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
	cg.colors = PackedColorArray([
		Color(1.0, 0.9, 0.48, 0.65),
		Color(1.0, 0.6, 0.22, 0.45),
		Color(0.88, 0.3, 0.05, 0.12),
		Color(0.5, 0.08, 0.0, 0.0),
	])
	_core_ramp = GradientTexture1D.new()
	_core_ramp.gradient = cg

	var bg := Gradient.new()
	bg.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	bg.offsets = PackedFloat32Array([0.0, 0.15, 0.35, 0.6, 0.85, 1.0])
	bg.colors = PackedColorArray([
		Color(1.0, 0.85, 0.32, 1.0),
		Color(1.0, 0.55, 0.08, 1.0),
		Color(0.92, 0.3, 0.04, 0.85),
		Color(0.7, 0.12, 0.02, 0.5),
		Color(0.4, 0.04, 0.0, 0.15),
		Color(0.2, 0.0, 0.0, 0.0),
	])
	_body_ramp = GradientTexture1D.new()
	_body_ramp.gradient = bg

	var tg := Gradient.new()
	tg.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	tg.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	tg.colors = PackedColorArray([
		Color(0.85, 0.2, 0.03, 0.9),
		Color(0.68, 0.1, 0.0, 0.6),
		Color(0.42, 0.04, 0.0, 0.3),
		Color(0.2, 0.0, 0.0, 0.1),
		Color(0.08, 0.0, 0.0, 0.0),
	])
	_tail_ramp = GradientTexture1D.new()
	_tail_ramp.gradient = tg

	var sc_inner := Curve.new()
	sc_inner.add_point(Vector2(0.0, 0.1), 0.0, 6.0)
	sc_inner.add_point(Vector2(0.12, 0.5), 3.0, 3.0)
	sc_inner.add_point(Vector2(0.45, 1.3), 0.0, -2.0)
	sc_inner.add_point(Vector2(1.0, 0.0), -4.0, 0.0)
	_scale_curve_inner = CurveTexture.new()
	_scale_curve_inner.curve = sc_inner

	var sc_outer := Curve.new()
	sc_outer.add_point(Vector2(0.0, 0.1), 0.0, 5.0)
	sc_outer.add_point(Vector2(0.1, 0.4), 2.5, 2.5)
	sc_outer.add_point(Vector2(0.4, 1.4), 0.0, -2.5)
	sc_outer.add_point(Vector2(1.0, 0.0), -4.0, 0.0)
	_scale_curve_outer = CurveTexture.new()
	_scale_curve_outer.curve = sc_outer

func _make_layer(
	amount: int,
	lifetime: float,
	vel_min: float,
	vel_max: float,
	spread: float,
	scale_min: float,
	scale_max: float,
	ramp: GradientTexture1D,
	z: int,
	scale_curve: CurveTexture,
	damp_min: float,
	damp_max: float
) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = false
	p.local_coords = false
	p.explosiveness = 0.0
	p.randomness = 0.15
	p.fixed_fps = 60
	p.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	p.z_index = z
	p.visible = false

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.particle_flag_align_y = true
	mat.angle_min = -15.0
	mat.angle_max = 15.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = spread
	mat.initial_velocity_min = vel_min
	mat.initial_velocity_max = vel_max
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.scale_curve = scale_curve
	mat.color_ramp = ramp
	mat.damping_min = damp_min
	mat.damping_max = damp_max
	mat.gravity = Vector3(0.0, 0.0, 0.0)
	mat.tangential_accel_min = -4.0
	mat.tangential_accel_max = 4.0

	p.process_material = mat
	p.texture = _blob_tex

	var ci_mat := CanvasItemMaterial.new()
	ci_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = ci_mat

	add_child(p)
	return p

func _build() -> void:
	_glow = _make_layer(6, 0.08, 900.0, 1200.0, 5.0, 0.6, 1.0, _glow_ramp, z_index + 3, _scale_curve_inner, 120.0, 200.0)
	_core = _make_layer(28, 0.12, 750.0, 1100.0, 9.0, 0.8, 1.4, _core_ramp, z_index + 2, _scale_curve_inner, 140.0, 230.0)
	_body = _make_layer(200, 0.25, 550.0, 950.0, 38.0, 0.8, 1.8, _body_ramp, z_index + 1, _scale_curve_outer, 160.0, 260.0)
	_tail = _make_layer(120, 0.35, 400.0, 800.0, 54.0, 0.6, 1.4, _tail_ramp, z_index, _scale_curve_outer, 180.0, 280.0)

	_base_vels = [
		{min = 900.0, max = 1200.0},
		{min = 750.0, max = 1100.0},
		{min = 550.0, max = 950.0},
		{min = 400.0, max = 800.0},
	]
	_base_lifetimes = PackedFloat32Array([0.08, 0.12, 0.25, 0.35])
	_base_spreads = PackedFloat32Array([5.0, 9.0, 38.0, 54.0])

	_halo = Sprite2D.new()
	_halo.texture = _halo_tex
	_halo.z_index = z_index + 4
	_halo.visible = false
	var halo_mat := CanvasItemMaterial.new()
	halo_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = halo_mat
	add_child(_halo)

func spawn(pos: Vector2, dir: Vector2, cone_half_angle: float, cone_range: float, mod_tint: Color = Color.WHITE) -> void:
	_direction = dir
	_cone_half_angle = cone_half_angle
	_cone_range = cone_range
	_alive = true
	_emitting = true
	_vel_ratio = 1.0
	_fade_timer = 0.0
	_burst_progress = 0.0
	visible = true

	global_position = pos + dir * FORWARD_OFFSET
	rotation = dir.angle()

	_apply_spread(cone_half_angle)
	_apply_range_ratio(cone_range / DESIGN_RANGE)
	_apply_velocity_ratio(1.0)

	_glow.emitting = true
	_core.emitting = true
	_body.emitting = true
	_tail.emitting = true
	_glow.visible = true
	_core.visible = true
	_body.visible = true
	_tail.visible = true

	_base_tint = Color(2.0, 1.5, 1.0, 1.0)
	if mod_tint != DEFAULT_FIRE_TINT and mod_tint != Color.WHITE:
		_base_tint = Color(mod_tint.r * 2.0, mod_tint.g * 1.5, mod_tint.b * 1.0, 1.0)

	_halo_alpha = 1.0
	_halo_tint = Color(0.9, 0.45, 0.12)
	if mod_tint != DEFAULT_FIRE_TINT and mod_tint != Color.WHITE:
		_halo_tint = Color(mod_tint.r * 0.8, mod_tint.g * 0.4, mod_tint.b * 0.2)
	_halo.modulate = Color(_halo_tint.r * 2.0, _halo_tint.g * 1.5, _halo_tint.b * 1.2, _halo_alpha * 0.5)
	_halo.scale = Vector2(0.01, 0.01)
	_halo.position = Vector2(_cone_range * 0.4, 0.0)
	_halo.visible = true

	_apply_layer_tint()
	set_process(true)

func stop_emitting() -> void:
	_emitting = false
	_glow.emitting = false
	_core.emitting = false
	_body.emitting = false
	_tail.emitting = false
	_fade_timer = 0.0

func kill() -> void:
	_alive = false
	_emitting = false
	visible = false
	set_process(false)
	_glow.emitting = false
	_glow.visible = false
	_core.emitting = false
	_core.visible = false
	_body.emitting = false
	_body.visible = false
	_tail.emitting = false
	_tail.visible = false
	_halo_alpha = 0.0
	_halo.visible = false

func set_burst_progress(p: float) -> void:
	_burst_progress = clampf(p, 0.0, 1.0)
	var vel_r: float = lerp(0.45, 1.0, _burst_progress)
	var spread_r: float = lerp(0.7, 1.0, _burst_progress)
	_apply_velocity_ratio(vel_r)
	_apply_spread_ratio(spread_r)
	_apply_layer_tint()

func update_direction(new_dir: Vector2, snap: bool = false) -> void:
	if new_dir.length_squared() > 0.001:
		_direction = new_dir.normalized()
		rotation = _direction.angle()
		var player := GameManager.get_player()
		if player:
			global_position = player.global_position + _direction * FORWARD_OFFSET

func update_position(pos: Vector2) -> void:
	global_position = pos + _direction * FORWARD_OFFSET

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _emitting and _alive:
		_fade_timer += delta
		_halo_alpha = maxf(0.0, 1.0 - _fade_timer / FADE_TIME)
		_update_halo()
		if _fade_timer >= FADE_TIME:
			kill()
	elif _emitting:
		_update_halo()

func _apply_layer_tint() -> void:
	var tint := _base_tint
	if _active_mod == &"fire_breath_dragon" and _burst_progress > 0.5:
		var blue_t := (_burst_progress - 0.5) * 2.0
		var blue_tint := Color(0.4, 0.6, 2.5, 1.0)
		tint = Color(
			lerpf(_base_tint.r, blue_tint.r, blue_t),
			lerpf(_base_tint.g, blue_tint.g, blue_t),
			lerpf(_base_tint.b, blue_tint.b, blue_t),
			1.0
		)
	for layer in [_glow, _core, _body, _tail]:
		if layer:
			layer.modulate = tint

func _update_halo() -> void:
	if not _halo or not _halo.visible:
		return
	var glow_progress: float = ease(_burst_progress, -2.0)
	var range: float = _cone_range * _vel_ratio * _visual_range_mult * lerp(0.1, 1.0, glow_progress)
	var cone_w: float = range * tan(_cone_half_angle * lerp(0.4, 1.0, glow_progress)) * 2.0
	var size: float = maxf(range, cone_w)
	var s: float = size / 128.0

	var tint := _halo_tint
	if _active_mod == &"fire_breath_dragon" and _burst_progress > 0.5:
		var blue_t := (_burst_progress - 0.5) * 2.0
		var blue_halo := Color(0.2, 0.3, 0.7)
		tint = Color(
			lerpf(_halo_tint.r, blue_halo.r, blue_t),
			lerpf(_halo_tint.g, blue_halo.g, blue_t),
			lerpf(_halo_tint.b, blue_halo.b, blue_t),
			1.0
		)

	_halo.scale = Vector2(s, s * 0.6)
	_halo.position = Vector2(range * 0.45, 0.0)
	_halo.modulate = Color(tint.r * 2.0, tint.g * 1.5, tint.b * 1.2, _halo_alpha * 0.5)

func _apply_spread(cone_half_angle: float) -> void:
	_cone_half_angle = cone_half_angle
	var half_deg: float = rad_to_deg(cone_half_angle)
	var mults := [0.09, 0.17, 0.70, 1.0]
	var layers := [_glow, _core, _body, _tail]
	for i in range(4):
		if layers[i] and layers[i].process_material is ParticleProcessMaterial:
			(layers[i].process_material as ParticleProcessMaterial).spread = half_deg * mults[i]
	_base_spreads = PackedFloat32Array([half_deg * 0.09, half_deg * 0.17, half_deg * 0.70, half_deg * 1.0])

func _apply_spread_ratio(ratio: float) -> void:
	var layers := [_glow, _core, _body, _tail]
	for i in range(4):
		if layers[i] and layers[i].process_material is ParticleProcessMaterial:
			(layers[i].process_material as ParticleProcessMaterial).spread = _base_spreads[i] * ratio

func _apply_range_ratio(ratio: float) -> void:
	var layers := [_glow, _core, _body, _tail]
	for i in range(4):
		if layers[i] and layers[i].process_material is ParticleProcessMaterial:
			layers[i].lifetime = _base_lifetimes[i] * ratio

func _apply_velocity_ratio(ratio: float) -> void:
	_vel_ratio = ratio
	var range_ratio: float = _cone_range / DESIGN_RANGE
	var layers := [_glow, _core, _body, _tail]
	for i in range(4):
		if layers[i] and layers[i].process_material is ParticleProcessMaterial:
			var mat: ParticleProcessMaterial = layers[i].process_material
			mat.initial_velocity_min = _base_vels[i].min * ratio * range_ratio
			mat.initial_velocity_max = _base_vels[i].max * ratio * range_ratio

func apply_modifier(mod_id: StringName) -> void:
	if mod_id == _active_mod:
		return
	_active_mod = mod_id
	var layers := [_glow, _core, _body, _tail]
	var orig_lifetimes := [0.08, 0.12, 0.25, 0.35]
	var orig_vels_min := [900.0, 750.0, 550.0, 400.0]
	var orig_vels_max := [1200.0, 1100.0, 950.0, 800.0]
	var orig_amounts := [6, 28, 200, 120]
	var orig_damp_min := [120.0, 140.0, 160.0, 180.0]
	var orig_damp_max := [200.0, 230.0, 260.0, 280.0]
	for i in range(4):
		if not layers[i] or not layers[i].process_material is ParticleProcessMaterial:
			continue
		var mat: ParticleProcessMaterial = layers[i].process_material
		_base_vels[i] = {min = orig_vels_min[i], max = orig_vels_max[i]}
		_base_lifetimes[i] = orig_lifetimes[i]
		layers[i].amount = orig_amounts[i]
		mat.damping_min = orig_damp_min[i]
		mat.damping_max = orig_damp_max[i]
		mat.tangential_accel_min = -4.0
		mat.tangential_accel_max = 4.0
	_visual_range_mult = 1.0
	_apply_spread(_cone_half_angle)
	_apply_range_ratio(_cone_range / DESIGN_RANGE)
	_apply_velocity_ratio(_vel_ratio)
	if mod_id == &"fire_breath_dragon":
		for i in range(4):
			_base_vels[i] = {min = orig_vels_min[i] * 1.05, max = orig_vels_max[i] * 1.05}
			layers[i].amount = int(orig_amounts[i] * 1.5)
		_visual_range_mult = 1.15
		_apply_range_ratio(_cone_range / DESIGN_RANGE)
		_apply_velocity_ratio(_vel_ratio)
	elif mod_id == &"fire_breath_fan":
		_apply_spread(_cone_half_angle * 1.5)
	elif mod_id == &"fire_breath_ash":
		for i in range(4):
			if not layers[i] or not layers[i].process_material is ParticleProcessMaterial:
				continue
			var mat: ParticleProcessMaterial = layers[i].process_material
			mat.tangential_accel_min = -8.0
			mat.tangential_accel_max = 8.0
