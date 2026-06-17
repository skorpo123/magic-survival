extends Node

enum GameState { MENU, PLAYING, PAUSED, LEVEL_UP, ARTIFACT_SELECT, GAME_OVER, VICTORY, BOSS_FIGHT }

const SURVIVAL_TIME := 1200.0

var current_state: GameState = GameState.MENU
var game_time: float = 0.0
var difficulty_multiplier: float = 1.0
var enemies_killed: int = 0
var current_level: int = 1
var total_xp_collected: float = 0.0
var currency: int = 0
var _last_run_currency: int = 0
var _endless_mode: bool = false
var selected_class: Dictionary = {}
var _state_before_sub_screen: int = -1
var _pause_saved_state: int = -1

var _player: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.player_xp_gained.connect(_on_player_xp_gained)
	EventBus.currency_collected.connect(_on_currency_collected)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.all_phases_completed.connect(_on_all_phases_completed)
	EventBus.chest_opened.connect(_on_chest_opened)

func _on_player_level_up(new_level: int) -> void:
	current_level = new_level

func _on_player_xp_gained(amount: float) -> void:
	total_xp_collected += amount

func _on_currency_collected(value: int, _rarity: int) -> void:
	currency += value

func _on_boss_defeated(_boss_name: String, _pos: Vector2) -> void:
	pass

func _on_chest_opened(_artifacts: Array, _rarity: int, _is_boss_chest: bool = false) -> void:
	pass

func _on_all_phases_completed() -> void:
	trigger_victory()

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		game_time += delta
		difficulty_multiplier = 1.0 + game_time / 60.0 * 0.5

func get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player

func start_game(class_data: Dictionary = {}) -> void:
	selected_class = class_data
	get_tree().paused = false
	game_time = 0.0
	enemies_killed = 0
	current_level = 1
	total_xp_collected = 0.0
	currency = 0
	difficulty_multiplier = 1.0
	_endless_mode = false
	_cleanup_run()
	current_state = GameState.PLAYING
	EventBus.game_started.emit()
	var player := get_player()
	if player:
		UpgradeManager.apply_to_player(player)

func return_to_menu() -> void:
	_deposit_currency()
	current_state = GameState.MENU
	get_tree().paused = false
	_cleanup_run()

func _cleanup_run() -> void:
	SwarmManager._on_game_started()
	EnemyMeshManager._on_game_started()
	PoolManager.despawn_all(&"MagicBolt")
	PoolManager.despawn_all(&"Fireball")
	PoolManager.despawn_all(&"OrbitArcane")
	PoolManager.despawn_all(&"HealthHeart")
	PoolManager.despawn_all(&"PowerUp")
	PoolManager.despawn_all(&"CurrencyOrb")
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node):
			node.queue_free()
	OrbManager.reset()
	for chest in ChestTracker.active_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	ChestTracker.active_chests.clear()
	RunTracker.snapshot_artifacts()
	ArtifactManager.equipped.clear()
	var player := get_player()
	if player:
		if "_is_dead" in player:
			player._is_dead = false
			player.set_physics_process(true)
		var stats: PlayerStats = null
		if "stats" in player and player.stats is PlayerStats:
			stats = player.stats
		if stats:
			stats.current_xp = 0.0
			stats.current_level = stats.starting_level
		player.global_position = Vector2.ZERO
		player.update_pickup_detector()

func pause_game() -> void:
	if current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT:
		_pause_saved_state = current_state
		current_state = GameState.PAUSED
		get_tree().paused = true
		EventBus.game_paused.emit()

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		if _pause_saved_state >= 0:
			current_state = _pause_saved_state
			_pause_saved_state = -1
		else:
			current_state = GameState.PLAYING
		get_tree().paused = false
		EventBus.game_resumed.emit()

func enter_level_up() -> void:
	_state_before_sub_screen = current_state
	current_state = GameState.LEVEL_UP
	get_tree().paused = true

func exit_level_up() -> void:
	if _state_before_sub_screen == GameState.BOSS_FIGHT:
		current_state = GameState.BOSS_FIGHT
	else:
		current_state = GameState.PLAYING
	_state_before_sub_screen = -1
	get_tree().paused = false

func enter_artifact_select() -> void:
	_state_before_sub_screen = current_state
	current_state = GameState.ARTIFACT_SELECT
	_stop_all_shockwaves()
	get_tree().paused = true

func _stop_all_shockwaves() -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	for child in scene.get_children():
		if child is CanvasLayer:
			for sub in child.get_children():
				if sub is BossShockwave:
					child.queue_free()
					break

func exit_artifact_select() -> void:
	if _state_before_sub_screen == GameState.BOSS_FIGHT:
		current_state = GameState.BOSS_FIGHT
	else:
		current_state = GameState.PLAYING
	_state_before_sub_screen = -1
	get_tree().paused = false

func enter_boss_fight() -> void:
	current_state = GameState.BOSS_FIGHT
	EventBus.boss_fight_started.emit()

func exit_boss_fight() -> void:
	current_state = GameState.PLAYING
	EventBus.boss_fight_ended.emit()

func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	RunTracker.snapshot_artifacts()
	_save_run_stats()
	_deposit_currency()
	EventBus.game_over.emit()

func trigger_victory() -> void:
	current_state = GameState.VICTORY
	get_tree().paused = true
	RunTracker.snapshot_artifacts()
	_save_run_stats()
	_deposit_currency()
	EventBus.victory.emit()

func _deposit_currency() -> void:
	_last_run_currency = currency
	if currency > 0:
		UpgradeManager.persistent_currency += currency
		UpgradeManager._save()
	currency = 0

func enter_endless() -> void:
	_endless_mode = true
	current_state = GameState.PLAYING
	get_tree().paused = false
	var player := get_player()
	if player:
		UpgradeManager.apply_to_player(player)

func get_remaining_time() -> float:
	if _endless_mode:
		return -1.0
	return maxf(SURVIVAL_TIME - game_time, 0.0)

func is_playing() -> bool:
	return current_state == GameState.PLAYING or current_state == GameState.BOSS_FIGHT

func is_boss_fight() -> bool:
	return current_state == GameState.BOSS_FIGHT

func is_menu() -> bool:
	return current_state == GameState.MENU

func format_time() -> String:
	var minutes := int(game_time / 60.0)
	var seconds := int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func _save_run_stats() -> void:
	var path := "user://stats.save"
	var stats: Dictionary = {}

	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			json.parse(file.get_as_text())
			file.close()
			if json.data:
				stats = json.data

	stats["total_kills"] = int(stats.get("total_kills", 0)) + enemies_killed
	stats["total_runs"] = int(stats.get("total_runs", 0)) + 1
	stats["total_xp"] = int(stats.get("total_xp", 0)) + int(total_xp_collected)
	if current_state == GameState.VICTORY:
		stats["victories"] = int(stats.get("victories", 0)) + 1

	var best_time: float = float(stats.get("best_time", 0.0))
	if game_time > best_time:
		stats["best_time"] = game_time

	var best_level: int = int(stats.get("best_level", 0))
	if current_level > best_level:
		stats["best_level"] = current_level

	var save_file := FileAccess.open(path, FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(stats, "  "))
		save_file.close()
