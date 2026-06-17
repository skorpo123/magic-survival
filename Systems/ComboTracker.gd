extends Node

var combo: int = 0
var _timer: float = 0.0
const COMBO_WINDOW := 2.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.game_started.connect(_on_game_started)

func _process(delta: float) -> void:
	if combo > 0:
		_timer -= delta
		if _timer <= 0.0:
			combo = 0
			EventBus.combo_changed.emit(0)

func get_damage_multiplier() -> float:
	return 1.0 + combo * 0.1

func _on_enemy_died(_pos: Vector2, _xp: float, _type: StringName) -> void:
	combo += 1
	_timer = COMBO_WINDOW
	EventBus.combo_changed.emit(combo)

func _on_game_started() -> void:
	combo = 0
	_timer = 0.0
	EventBus.combo_changed.emit(0)
