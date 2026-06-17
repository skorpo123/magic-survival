class_name SpatialGrid extends RefCounted

var _inv_cell: float
var _cells: Dictionary = {}
var _used_keys: Array = []
var _prune_counter: int = 0

func _init(cell_size: float = 128.0) -> void:
	_inv_cell = 1.0 / cell_size

func _key(x: float, y: float) -> Vector2i:
	return Vector2i(floori(x * _inv_cell), floori(y * _inv_cell))

func clear() -> void:
	for key in _used_keys:
		if _cells.has(key):
			_cells[key].resize(0)
	_used_keys.clear()
	_prune_counter += 1
	if _prune_counter >= 30:
		_prune_counter = 0
		var active_keys: Array = []
		for key in _cells:
			if _cells[key].size() > 0:
				active_keys.append(key)
			else:
				_cells.erase(key)

func insert(id: int, x: float, y: float) -> void:
	var key := _key(x, y)
	if not _cells.has(key):
		_cells[key] = PackedInt32Array()
		_used_keys.append(key)
	elif _cells[key].size() == 0:
		_used_keys.append(key)
	_cells[key].append(id)

func remove(id: int) -> void:
	for key in _used_keys:
		if not _cells.has(key):
			continue
		var arr: PackedInt32Array = _cells[key]
		var idx := arr.find(id)
		if idx >= 0:
			arr.remove_at(idx)
			return

func query_nearby(pos: Vector2, radius: float) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	query_nearby_into(pos, radius, result)
	return result

func query_nearby_into(pos: Vector2, radius: float, buf: PackedInt32Array) -> void:
	buf.resize(0)
	var min_cx: int = floori((pos.x - radius) * _inv_cell)
	var min_cy: int = floori((pos.y - radius) * _inv_cell)
	var max_cx: int = floori((pos.x + radius) * _inv_cell)
	var max_cy: int = floori((pos.y + radius) * _inv_cell)
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				buf.append_array(_cells[key])

func query_aabb(min_pos: Vector2, max_pos: Vector2) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	query_aabb_into(min_pos, max_pos, result)
	return result

func query_aabb_into(min_pos: Vector2, max_pos: Vector2, buf: PackedInt32Array) -> void:
	buf.resize(0)
	var min_cx: int = floori(min_pos.x * _inv_cell)
	var min_cy: int = floori(min_pos.y * _inv_cell)
	var max_cx: int = floori(max_pos.x * _inv_cell)
	var max_cy: int = floori(max_pos.y * _inv_cell)
	for cx in range(min_cx, max_cx + 1):
		for cy in range(min_cy, max_cy + 1):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				buf.append_array(_cells[key])
