class_name WorldManager extends Node2D

@export var chunk_load_radius: int = 3
@export var chunk_unload_radius: int = 5
@export var update_interval: float = 0.5

var _chunk_generator: ChunkGenerator
var _update_timer: float = 0.0
var _dust_particles: Array[Dictionary] = []
var _dust_phase: float = 0.0

const DUST_COUNT: int = 60
const DUST_SPREAD: float = 700.0

func _ready() -> void:
	z_index = -2
	z_as_relative = false
	_chunk_generator = ChunkGenerator.new()
	add_child(_chunk_generator)
	_generate_dust()
	_initial_load()

func _generate_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	for i in range(DUST_COUNT):
		var angle := rng.randf() * TAU
		var dist := rng.randf() * DUST_SPREAD
		var base_pos := Vector2.RIGHT.rotated(angle) * dist
		_dust_particles.append({
			pos = base_pos,
			drift_speed = rng.randf_range(3.0, 12.0),
			drift_angle = rng.randf() * TAU,
			wobble_phase = rng.randf() * TAU,
			wobble_amp = rng.randf_range(2.0, 6.0),
			wobble_freq = rng.randf_range(0.5, 2.0),
			size = rng.randf_range(1.0, 3.0),
			alpha = rng.randf_range(0.08, 0.25),
			is_ash = rng.randf() < 0.3,
		})

func _initial_load() -> void:
	var center := _get_world_center()
	_chunk_generator.load_chunks_around(center, chunk_load_radius)

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0
	_dust_phase += delta

	var center := _get_world_center()
	_chunk_generator.load_chunks_around(center, chunk_load_radius)
	_chunk_generator.unload_far_chunks(center, chunk_unload_radius)

	for p in _dust_particles:
		var p_pos: Vector2 = p.pos
		p_pos += Vector2(cos(p.drift_angle) * p.drift_speed * delta, sin(p.drift_angle) * p.drift_speed * delta)
		p.pos = p_pos
		p.wobble_phase += p.wobble_freq * delta
		var d: float = p_pos.length()
		if d > DUST_SPREAD:
			p.pos = p_pos.normalized() * -DUST_SPREAD * 0.5

	queue_redraw()

func _draw() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var ppos := player.global_position - global_position

	for p in _dust_particles:
		var p_pos: Vector2 = p.pos
		var wobble := Vector2(cos(p.wobble_phase) * p.wobble_amp, sin(p.wobble_phase * 1.3) * p.wobble_amp)
		var draw_pos: Vector2 = ppos + p_pos + wobble
		if p.is_ash:
			draw_circle(draw_pos, p.size, Color(0.5, 0.25, 0.12, p.alpha))
		else:
			draw_circle(draw_pos, p.size, Color(0.35, 0.30, 0.45, p.alpha))
		if p.size > 2.0:
			draw_circle(draw_pos, p.size * 0.5, Color(0.5, 0.45, 0.6, p.alpha * 1.5))

func _get_world_center() -> Vector2:
	var player := GameManager.get_player()
	if player:
		return player.global_position
	return Vector2.ZERO
