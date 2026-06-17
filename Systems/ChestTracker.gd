extends Node

var active_chests: Array = []
var boss_chests: Array = []

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)

func register(chest: Node2D) -> void:
	if not active_chests.has(chest):
		active_chests.append(chest)
		EventBus.chest_spawned.emit(chest)

func register_boss(chest: Node2D) -> void:
	if not boss_chests.has(chest):
		boss_chests.append(chest)
	if not active_chests.has(chest):
		active_chests.append(chest)
		EventBus.chest_spawned.emit(chest)

func unregister(chest: Node2D) -> void:
	active_chests.erase(chest)
	boss_chests.erase(chest)
	EventBus.chest_removed.emit(chest)

func get_regular_count() -> int:
	return active_chests.size() - boss_chests.size()

func spawn_legendary_chest(pos: Vector2) -> void:
	var chest_scene := preload("res://Entities/Chest/Chest.tscn") as PackedScene
	if not chest_scene:
		return
	var chest := chest_scene.instantiate() as Chest
	if not chest:
		return
	chest.rarity = ItemRarity.Tier.LEGENDARY
	chest.is_boss_chest = true
	chest.global_position = pos
	var main := get_tree().current_scene
	if main:
		main.add_child(chest)
	register_boss(chest)

func _on_game_started() -> void:
	for chest in active_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	active_chests.clear()
	boss_chests.clear()
