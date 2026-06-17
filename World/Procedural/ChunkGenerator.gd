class_name ChunkGenerator extends Node2D

@export var chunk_size: int = 32
@export var tile_size: int = 16

var _chunks: Dictionary = {}
var _tile_set: TileSet = null
var _tile_map: TileMapLayer = null
var _base_noise: FastNoiseLite = null
var _detail_noise: FastNoiseLite = null
var _speckle_noise: FastNoiseLite = null
var _crack_noise: FastNoiseLite = null
var _scatter_noise: FastNoiseLite = null
var _scatter_type_noise: FastNoiseLite = null

const TILE_BASE := 0
const TILE_SPECKLE_LIGHT := 1
const TILE_SPECKLE_DARK := 2
const TILE_RUNE := 3
const TILE_CRACK := 4
const TILE_CRYSTAL := 5
const TILE_RUIN := 6
const TILE_ASH := 7
const TILE_COUNT := 8

func _ready() -> void:
	_base_noise = FastNoiseLite.new()
	_base_noise.seed = randi()
	_base_noise.fractal_octaves = 4
	_base_noise.frequency = 0.035
	_base_noise.fractal_lacunarity = 2.2

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = randi() + 100
	_detail_noise.fractal_octaves = 2
	_detail_noise.frequency = 0.12

	_speckle_noise = FastNoiseLite.new()
	_speckle_noise.seed = randi() + 300
	_speckle_noise.fractal_octaves = 1
	_speckle_noise.frequency = 0.45

	_crack_noise = FastNoiseLite.new()
	_crack_noise.seed = randi() + 400
	_crack_noise.fractal_octaves = 3
	_crack_noise.frequency = 0.08

	_scatter_noise = FastNoiseLite.new()
	_scatter_noise.seed = randi() + 500
	_scatter_noise.fractal_octaves = 2
	_scatter_noise.frequency = 0.04

	_scatter_type_noise = FastNoiseLite.new()
	_scatter_type_noise.seed = randi() + 600
	_scatter_type_noise.fractal_octaves = 2
	_scatter_type_noise.frequency = 0.07

	_tile_map = TileMapLayer.new()
	_tile_map.name = "TileMap"
	_tile_map.z_index = -1
	add_child(_tile_map)

func get_or_create_chunk(chunk_coord: Vector2i) -> TileMapLayer:
	if _chunks.has(chunk_coord):
		return _tile_map
	_generate_tiles(chunk_coord)
	_chunks[chunk_coord] = true
	return _tile_map

func _generate_tiles(chunk_coord: Vector2i) -> void:
	_tile_map.tile_set = _get_tile_set()

	for x in range(chunk_size):
		for y in range(chunk_size):
			var world_x := chunk_coord.x * chunk_size + x
			var world_y := chunk_coord.y * chunk_size + y
			var tile_id := _pick_tile(world_x, world_y)
			_tile_map.set_cell(Vector2i(world_x, world_y), 0, Vector2i(tile_id, 0))

func _pick_tile(wx: int, wy: int) -> int:
	var scatter_val := _scatter_noise.get_noise_2d(wx, wy)
	if scatter_val > 0.65:
		var type_val := _scatter_type_noise.get_noise_2d(wx + 999, wy + 777)
		if type_val > 0.3:
			return TILE_CRYSTAL
		elif type_val > -0.1:
			return TILE_RUIN
		else:
			return TILE_ASH

	var rune_val := _detail_noise.get_noise_2d(wx, wy)
	if rune_val > 0.75:
		return TILE_RUNE

	var crack_val := _crack_noise.get_noise_2d(wx * 1.5, wy * 1.5)
	if crack_val > 0.6:
		return TILE_CRACK

	var speckle_val := _speckle_noise.get_noise_2d(wx, wy)
	if speckle_val > 0.35:
		return TILE_SPECKLE_LIGHT
	elif speckle_val < -0.35:
		return TILE_SPECKLE_DARK

	return TILE_BASE

func _get_tile_set() -> TileSet:
	if _tile_set:
		return _tile_set

	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(tile_size, tile_size)

	var source := TileSetAtlasSource.new()
	var tex := _create_atlas_texture()
	source.texture = tex
	source.texture_region_size = Vector2i(tile_size, tile_size)

	for i in range(TILE_COUNT):
		source.create_tile(Vector2i(i, 0), Vector2i(1, 1))

	_tile_set.add_source(source)
	return _tile_set

func _create_atlas_texture() -> ImageTexture:
	var img := Image.create(tile_size * TILE_COUNT, tile_size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var fine_noise := FastNoiseLite.new()
	fine_noise.seed = 777
	fine_noise.fractal_octaves = 2
	fine_noise.frequency = 0.25

	var base_color := Color(0.22, 0.20, 0.28)

	for i in range(TILE_COUNT):
		match i:
			TILE_BASE:
				_draw_base_tile(img, i, base_color, fine_noise, rng)
			TILE_SPECKLE_LIGHT:
				_draw_speckle_tile(img, i, base_color, fine_noise, rng, 0.04, 0.06)
			TILE_SPECKLE_DARK:
				_draw_speckle_tile(img, i, base_color, fine_noise, rng, -0.03, -0.04)
			TILE_RUNE:
				_draw_rune_tile(img, i, base_color, fine_noise, rng)
			TILE_CRACK:
				_draw_crack_tile(img, i, base_color, fine_noise, rng)
			TILE_CRYSTAL:
				_draw_crystal_tile(img, i, base_color, fine_noise, rng)
			TILE_RUIN:
				_draw_ruin_tile(img, i, base_color, fine_noise, rng)
			TILE_ASH:
				_draw_ash_tile(img, i, base_color, fine_noise, rng)

	return ImageTexture.create_from_image(img)

func _draw_base_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var r := clampf(base.r + v, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

func _draw_speckle_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator, r_off: float, b_off: float) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var is_speckle: bool = (rng.randf() < 0.12)
			var r: float
			var g: float
			var b: float
			if is_speckle:
				var sv := rng.randf() * 0.6 + 0.2
				r = clampf(base.r + v + r_off * sv + rng.randf_range(-0.01, 0.01), 0.0, 1.0)
				g = clampf(base.g + v * 0.8 + r_off * sv * 0.3, 0.0, 1.0)
				b = clampf(base.b + v * 1.2 + b_off * sv + rng.randf_range(-0.01, 0.01), 0.0, 1.0)
			else:
				r = clampf(base.r + v, 0.0, 1.0)
				g = clampf(base.g + v * 0.8, 0.0, 1.0)
				b = clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

func _draw_rune_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var dx := px - tile_size * 0.5
			var dy := py - tile_size * 0.5
			var dist := sqrt(dx * dx + dy * dy) / (tile_size * 0.5)
			var glow := maxf(1.0 - dist, 0.0)
			var r := clampf(base.r + v + glow * 0.08, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8 + glow * 0.03, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2 + glow * 0.14, 0.0, 1.0)
			var a := 0.6 + glow * 0.4
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, a))

func _draw_crack_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var r := clampf(base.r + v, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

	var cx := tile_size / 2
	var cy := tile_size / 2
	var crack_x := cx
	var crack_y := cy
	for step in range(8):
		var dir := rng.randi() % 4
		match dir:
			0: crack_x = mini(crack_x + 1, tile_size - 1)
			1: crack_x = maxi(crack_x - 1, 0)
			2: crack_y = mini(crack_y + 1, tile_size - 1)
			3: crack_y = maxi(crack_y - 1, 0)
		_set_atlas_pixel(img, idx, crack_x, crack_y, Color(base.r * 0.5, base.g * 0.4, base.b * 0.55, 1.0))
		if crack_x > 0:
			_set_atlas_pixel(img, idx, crack_x - 1, crack_y, Color(base.r * 0.6, base.g * 0.5, base.b * 0.65, 1.0))
		if crack_y > 0:
			_set_atlas_pixel(img, idx, crack_x, crack_y - 1, Color(base.r * 0.6, base.g * 0.5, base.b * 0.65, 1.0))

func _draw_crystal_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var r := clampf(base.r + v, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

	var cx := tile_size / 2
	var cy := tile_size / 2
	var crystal_h := rng.randi_range(4, 8)
	var crystal_w := rng.randi_range(2, 3)
	var tint_r := 0.35 + rng.randf() * 0.15
	var tint_g := 0.15 + rng.randf() * 0.1
	var tint_b := 0.50 + rng.randf() * 0.2
	for dy in range(crystal_h):
		var y_pos := cy - crystal_h / 2 + dy
		if y_pos < 0 or y_pos >= tile_size:
			continue
		var taper := 1.0 - absf(dy - crystal_h * 0.3) / (crystal_h * 0.7)
		taper = maxf(taper, 0.3)
		var half_w := int(crystal_w * taper * 0.5) + 1
		for dx in range(-half_w, half_w + 1):
			var x_pos := cx + dx
			if x_pos < 0 or x_pos >= tile_size:
				continue
			var edge_fade := 1.0 - absf(dx) / maxf(half_w, 1.0)
			var glow := edge_fade * taper
			var r := clampf(base.r * 0.3 + tint_r * glow, 0.0, 1.0)
			var g := clampf(base.g * 0.2 + tint_g * glow, 0.0, 1.0)
			var b := clampf(base.b * 0.4 + tint_b * glow, 0.0, 1.0)
			_set_atlas_pixel(img, idx, x_pos, y_pos, Color(r, g, b, 0.85 + glow * 0.15))

func _draw_ruin_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var r := clampf(base.r + v, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

	var bx := rng.randi_range(2, 6)
	var by := rng.randi_range(4, 10)
	var bw := rng.randi_range(4, 10)
	var bh := rng.randi_range(3, 6)
	var stone_r := base.r * 0.35 + 0.05
	var stone_g := base.g * 0.3 + 0.04
	var stone_b := base.b * 0.4 + 0.06
	for dy in range(bh):
		for dx in range(bw):
			if rng.randf() < 0.2:
				continue
			var x_pos := bx + dx
			var y_pos := by + dy
			if x_pos >= tile_size or y_pos >= tile_size:
				continue
			var nv := rng.randf() * 0.04 - 0.02
			_set_atlas_pixel(img, idx, x_pos, y_pos, Color(stone_r + nv, stone_g + nv * 0.8, stone_b + nv * 1.2, 1.0))

	if bw > 2 and bh > 1:
		var cx2 := bx + bw / 2
		var cy2 := by + bh / 2
		var hole_r := 2
		for dy in range(-hole_r, hole_r + 1):
			for dx in range(-hole_r, hole_r + 1):
				if dx * dx + dy * dy <= hole_r * hole_r:
					var x_pos := cx2 + dx
					var y_pos := cy2 + dy
					if x_pos >= 0 and x_pos < tile_size and y_pos >= 0 and y_pos < tile_size:
						var depth_v := rng.randf() * 0.03
						_set_atlas_pixel(img, idx, x_pos, y_pos, Color(base.r * 0.2 + depth_v, base.g * 0.15 + depth_v, base.b * 0.25 + depth_v, 1.0))

func _draw_ash_tile(img: Image, idx: int, base: Color, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	for px in range(tile_size):
		for py in range(tile_size):
			var n := noise.get_noise_2d(idx * tile_size + px, py) * 0.5 + 0.5
			var v := n * 0.02 - 0.01
			var r := clampf(base.r + v, 0.0, 1.0)
			var g := clampf(base.g + v * 0.8, 0.0, 1.0)
			var b := clampf(base.b + v * 1.2, 0.0, 1.0)
			_set_atlas_pixel(img, idx, px, py, Color(r, g, b, 1.0))

	var ash_count := rng.randi_range(8, 20)
	for _a in range(ash_count):
		var ax := rng.randi_range(0, tile_size - 1)
		var ay := rng.randi_range(0, tile_size - 1)
		var ash_r := 0.45 + rng.randf() * 0.15
		var ash_g := 0.20 + rng.randf() * 0.08
		var ash_b := 0.12 + rng.randf() * 0.06
		_set_atlas_pixel(img, idx, ax, ay, Color(ash_r, ash_g, ash_b, 0.6 + rng.randf() * 0.3))

func _set_atlas_pixel(img: Image, tile_idx: int, px: int, py: int, color: Color) -> void:
	img.set_pixel(tile_idx * tile_size + px, py, color)

func unload_chunk(chunk_coord: Vector2i) -> void:
	if not _chunks.has(chunk_coord):
		return
	var ox: int = chunk_coord.x * chunk_size
	var oy: int = chunk_coord.y * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			_tile_map.erase_cell(Vector2i(ox + x, oy + y))
	_chunks.erase(chunk_coord)

func unload_far_chunks(center: Vector2, radius_chunks: int) -> void:
	var center_chunk := world_to_chunk(center)
	var to_remove: Array[Vector2i] = []
	for coord: Vector2i in _chunks:
		if absi(coord.x - center_chunk.x) > radius_chunks or absi(coord.y - center_chunk.y) > radius_chunks:
			to_remove.append(coord)
	for coord in to_remove:
		unload_chunk(coord)

func world_to_chunk(world_pos: Vector2) -> Vector2i:
	var pixel_chunk := float(chunk_size * tile_size)
	return Vector2i(
		int(floor(world_pos.x / pixel_chunk)),
		int(floor(world_pos.y / pixel_chunk))
	)

func load_chunks_around(center: Vector2, radius_chunks: int) -> void:
	var center_chunk := world_to_chunk(center)
	for x in range(center_chunk.x - radius_chunks, center_chunk.x + radius_chunks + 1):
		for y in range(center_chunk.y - radius_chunks, center_chunk.y + radius_chunks + 1):
			get_or_create_chunk(Vector2i(x, y))
