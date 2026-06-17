extends Node2D

var _pool: Dictionary = {}
var _pool_busy: Dictionary = {}
var _pool_sizes: Dictionary = {}
var _type_config: Dictionary = {}

static var _glow_tex: ImageTexture = null

func _ready() -> void:
	z_index = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_glow_texture()
	_type_config = {
		"level_up": { count = 26, color = Color(1.4, 1.0, 2.0, 0.75), v_min = 55.0, v_max = 200.0, life = 0.65, pool = 2 },
		"heal":     { count = 18, color = Color(0.8, 2.0, 1.0, 0.75), v_min = 35.0, v_max = 110.0, life = 0.4, pool = 3 },
	}
	_create_pools()

static func _ensure_glow_texture() -> void:
	if _glow_tex:
		return
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
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, fade * fade * fade * fade))
			else:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
	_glow_tex = ImageTexture.create_from_image(img)

func _create_pools() -> void:
	for key in _type_config:
		var cfg: Dictionary = _type_config[key]
		var pool_size: int = cfg.pool
		var arr: Array[GPUParticles2D] = []
		arr.resize(pool_size)
		var busy: PackedFloat32Array = []
		busy.resize(pool_size)
		busy.fill(-1.0)
		for i in range(pool_size):
			arr[i] = _make_gpu(cfg.count, cfg.color, cfg.v_min, cfg.v_max, cfg.life)
		_pool[key] = arr
		_pool_busy[key] = busy

func _make_gpu(count: int, color: Color, min_spread: float, max_spread: float, lifetime: float) -> GPUParticles2D:
	var gp := GPUParticles2D.new()
	gp.amount = count
	gp.lifetime = lifetime
	gp.one_shot = true
	gp.explosiveness = 0.9
	gp.texture = _glow_tex
	gp.process_material = ParticleProcessMaterial.new()
	gp.process_material.particle_flag_disable_z = true
	gp.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	gp.process_material.direction = Vector3(0, -1, 0)
	gp.process_material.spread = 180.0
	gp.process_material.initial_velocity_min = min_spread
	gp.process_material.initial_velocity_max = max_spread
	gp.process_material.gravity = Vector3.ZERO
	gp.process_material.scale_min = 2.0
	gp.process_material.scale_max = 4.0
	gp.process_material.color = color
	gp.local_coords = false
	gp.z_index = 5
	gp.visible = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	gp.material = mat
	add_child(gp)
	return gp

func register(key: String, pos: Vector2, max_lifetime: float, color: Color = Color.WHITE, radius: float = 0.0) -> void:
	if not _pool.has(key):
		return
	ActionProfiler.probe("vfx", "gpu_%s" % key)
	var cfg: Dictionary = _type_config[key]
	var pool: Array[GPUParticles2D] = _pool[key]
	var busy: PackedFloat32Array = _pool_busy[key]
	var now: float = Time.get_ticks_msec() * 0.001
	var best_idx: int = -1
	var oldest_time: float = INF
	for i in range(pool.size()):
		if busy[i] < 0.0 or now >= busy[i]:
			best_idx = i
			break
		if busy[i] < oldest_time:
			oldest_time = busy[i]
			best_idx = i
	var gp: GPUParticles2D = pool[best_idx]
	gp.emitting = false
	gp.global_position = pos
	gp.visible = true
	if color != Color.WHITE:
		gp.process_material.color = color
	if radius > 0.0:
		gp.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		gp.process_material.emission_sphere_radius = radius
	gp.emitting = true
	busy[best_idx] = now + cfg.life
	set_process(true)

func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() * 0.001
	var any_active: bool = false
	for key in _pool:
		var pool: Array[GPUParticles2D] = _pool[key]
		var busy: PackedFloat32Array = _pool_busy[key]
		for i in range(pool.size()):
			if busy[i] > 0.0 and now >= busy[i]:
				busy[i] = -1.0
				pool[i].emitting = false
				pool[i].visible = false
				pool[i].process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
				pool[i].process_material.color = _type_config[key].color
			if busy[i] > 0.0:
				any_active = true
	if not any_active:
		set_process(false)
