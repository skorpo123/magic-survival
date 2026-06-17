extends Node

var _pools: Dictionary = {}

func register_pool(pool_name: StringName, scene: PackedScene, initial_size: int = 0, auto_grow: int = 5, container: Node = null) -> void:
	if _pools.has(pool_name):
		return

	if not container:
		container = Node2D.new()
		container.name = String(pool_name) + "Pool"
		container.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(container)

	_pools[pool_name] = {
		"container": container,
		"scene": scene,
		"available": [],
		"active": {},
		"auto_grow": auto_grow
	}

	for i in range(initial_size):
		_create_instance(pool_name)

func _create_instance(pool_name: StringName) -> Node:
	var pool: Dictionary = _pools[pool_name]
	var inst: Node = pool["scene"].instantiate()
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	inst.visible = false
	inst.global_position = Vector2(-100000, -100000)
	pool["container"].add_child(inst)
	pool["available"].append(inst)
	return inst

func spawn(pool_name: StringName, spawn_position: Vector2) -> Node:
	if not _pools.has(pool_name):
		push_error("PoolManager: pool '%s' not registered" % pool_name)
		return null

	var pool: Dictionary = _pools[pool_name]
	var inst: Node

	if pool["available"].size() > 0:
		inst = pool["available"].pop_back()
	else:
		for i in range(pool["auto_grow"]):
			_create_instance(pool_name)
		if pool["available"].size() == 0:
			push_error("PoolManager: failed to grow pool '%s'" % pool_name)
			return null
		inst = pool["available"].pop_back()

	if not inst:
		return null

	pool["active"][inst.get_instance_id()] = inst
	inst.global_position = spawn_position
	inst.process_mode = Node.PROCESS_MODE_PAUSABLE
	inst.visible = true
	_enable_collisions(inst)

	return inst

func despawn(pool_name: StringName, inst: Node) -> void:
	if not _pools.has(pool_name) or not is_instance_valid(inst):
		return

	var pool: Dictionary = _pools[pool_name]
	var id: int = inst.get_instance_id()

	if not pool["active"].has(id):
		return

	pool["active"].erase(id)
	pool["available"].append(inst)

	if inst.has_method("on_despawn"):
		inst.on_despawn()

	inst.process_mode = Node.PROCESS_MODE_DISABLED
	inst.visible = false
	inst.global_position = Vector2(-100000, -100000)
	_disable_collisions(inst)

func despawn_all(pool_name: StringName) -> void:
	if not _pools.has(pool_name):
		return

	var pool: Dictionary = _pools[pool_name]
	var active_ids: Array = pool["active"].keys()
	for id in active_ids:
		var inst: Node = pool["active"][id]
		if is_instance_valid(inst):
			despawn(pool_name, inst)
		else:
			pool["active"].erase(id)

func get_active_count(pool_name: StringName) -> int:
	if not _pools.has(pool_name):
		return 0
	return _pools[pool_name]["active"].size()

func get_available_count(pool_name: StringName) -> int:
	if not _pools.has(pool_name):
		return 0
	return _pools[pool_name]["available"].size()

func _disable_collisions(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true
		elif child is CollisionPolygon2D:
			child.disabled = true
		if child is Area2D or child is PhysicsBody2D:
			_disable_collisions(child)

func _enable_collisions(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = false
		elif child is CollisionPolygon2D:
			child.disabled = false
		if child is Area2D or child is PhysicsBody2D:
			_enable_collisions(child)
