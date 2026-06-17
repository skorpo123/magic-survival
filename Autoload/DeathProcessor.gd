extends Node

var _on_kill_explode_chance: float = 0.0
var _on_kill_explode_radius: float = 80.0
var _on_kill_explode_damage: float = 15.0
var _instant_kill_chance: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_on_kill_explode_chance = 0.0
	_on_kill_explode_radius = 80.0
	_on_kill_explode_damage = 15.0
	_instant_kill_chance = 0.0

func set_iron_maiden(chance: float, radius: float, damage: float) -> void:
	_on_kill_explode_chance = chance
	_on_kill_explode_radius = radius
	_on_kill_explode_damage = damage

func set_reaper_scythe(chance: float) -> void:
	_instant_kill_chance = chance

func should_instant_kill() -> bool:
	if _instant_kill_chance <= 0.0:
		return false
	return randf() < _instant_kill_chance

func _on_enemy_died(pos: Vector2, _xp_value: float, _enemy_type: StringName) -> void:
	if _on_kill_explode_chance <= 0.0:
		return
	if randf() >= _on_kill_explode_chance:
		return
	var player := GameManager.get_player()
	var dmg := _on_kill_explode_damage
	if player and player.stats:
		dmg *= player.stats.magic_power
	SwarmManager.damage_area(pos, _on_kill_explode_radius, dmg)
	EnemyMeshManager.damage_area(pos, _on_kill_explode_radius, dmg)
	JuiceManager.spawn_explosion_visual(pos, _on_kill_explode_radius, Color(1.0, 0.4, 0.15))
