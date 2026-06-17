extends Node

const CURRENCY_INTERVAL_BASE := 18.0
const CHEST_INTERVAL_BASE := 40.0
const MAX_REGULAR_CHESTS := 3

var _currency_timer: float = 0.0
var _chest_timer: float = 0.0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_currency_timer = CURRENCY_INTERVAL_BASE
	_chest_timer = CHEST_INTERVAL_BASE

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_currency_timer -= delta
	if _currency_timer <= 0.0:
		_spawn_currency_cluster()
		_currency_timer = CURRENCY_INTERVAL_BASE

	_chest_timer -= delta
	if _chest_timer <= 0.0:
		if ChestTracker.get_regular_count() < MAX_REGULAR_CHESTS:
			_spawn_chest()
			_chest_timer = CHEST_INTERVAL_BASE
		else:
			_chest_timer = 1.0

func _spawn_currency_cluster() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := randi_range(3, 6)
	for _i in range(count):
		var angle := randf() * TAU
		var dist := randf_range(150.0, 400.0)
		var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
		var tier := ItemRarity.roll()
		var orb := PoolManager.spawn(&"CurrencyOrb", pos)
		if orb and orb.has_method("setup"):
			orb.setup(tier)
		if orb and orb.has_method("on_spawn"):
			orb.on_spawn()

func _spawn_chest() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var angle := randf() * TAU
	var dist := randf_range(700.0, 1100.0)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	var chest_scene := preload("res://Entities/Chest/Chest.tscn")
	var chest := chest_scene.instantiate()
	chest.rarity = ItemRarity.roll()
	chest.global_position = pos
	get_tree().current_scene.add_child(chest)
