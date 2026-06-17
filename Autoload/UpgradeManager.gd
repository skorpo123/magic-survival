extends Node

const SAVE_PATH := "user://upgrades.save"
const MAX_LEVEL := 5
const COSTS: PackedInt32Array = [50, 150, 350, 700, 1200]

const STAT_DEFS: Array = [
	{"key": "max_hp", "base": 100.0, "bonus": 15.0},
	{"key": "hp_regen", "base": 0.0, "bonus": 0.5},
	{"key": "damage_reduction", "base": 0.0, "bonus": 0.02},
	{"key": "dodge_chance", "base": 0.0, "bonus": 0.03},
	{"key": "move_speed", "base": 150.0, "bonus": 12.0},
	{"key": "magic_power", "base": 1.0, "bonus": 0.12},
	{"key": "crit_chance", "base": 0.0, "bonus": 0.015},
	{"key": "crit_damage_mult", "base": 2.0, "bonus": 0.05},
	{"key": "cooldown_reduction", "base": 0.0, "bonus": 0.04},
	{"key": "spell_duration_mult", "base": 1.0, "bonus": 0.03},
	{"key": "projectile_speed_mult", "base": 1.0, "bonus": 0.08},
	{"key": "area_multiplier", "base": 1.0, "bonus": 0.08},
	{"key": "pickup_range", "base": 80.0, "bonus": 20.0},
	{"key": "mana_gain", "base": 1.0, "bonus": 0.04},
	{"key": "life_steal", "base": 0.0, "bonus": 0.005},
	{"key": "enemy_max_hp_mult", "base": 1.0, "bonus": -0.02},
]

var upgrade_levels: Dictionary = {}
var persistent_currency: int = 0

func _ready() -> void:
	_load()

func get_upgrade_level(key: String) -> int:
	return int(upgrade_levels.get(key, 0))

func get_upgrade_cost(key: String, level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return COSTS[level]

func purchase_upgrade(key: String) -> bool:
	var level: int = get_upgrade_level(key)
	if level >= MAX_LEVEL:
		return false
	var cost: int = get_upgrade_cost(key, level)
	if persistent_currency < cost:
		return false
	persistent_currency -= cost
	upgrade_levels[key] = level + 1
	_save()
	return true

func reset_all_upgrades() -> int:
	var refund: int = 0
	for def: Dictionary in STAT_DEFS:
		var key: String = def["key"]
		var level: int = get_upgrade_level(key)
		for i in range(level):
			refund += COSTS[i]
	upgrade_levels.clear()
	persistent_currency += refund
	_save()
	return refund

func apply_to_player(player: Node2D) -> void:
	if not player or not "stats" in player or not player.stats is PlayerStats:
		return
	var s: PlayerStats = player.stats
	for def: Dictionary in STAT_DEFS:
		var key: String = def["key"]
		var base_val: float = float(def["base"])
		var bonus: float = float(def["bonus"])
		var level: int = get_upgrade_level(key)
		var val: float = base_val + bonus * float(level)
		match key:
			"max_hp":
				s.max_hp = val
			"hp_regen":
				s.hp_regen = val
			"damage_reduction":
				s.damage_reduction = val
			"dodge_chance":
				s.dodge_chance = val
			"move_speed":
				s.move_speed = val
			"magic_power":
				s.magic_power = val
			"crit_chance":
				s.crit_chance = val
			"crit_damage_mult":
				s.crit_damage_mult = val
			"cooldown_reduction":
				s.cooldown_reduction = val
			"spell_duration_mult":
				s.spell_duration_mult = val
			"projectile_speed_mult":
				s.projectile_speed_mult = val
			"area_multiplier":
				s.area_multiplier = val
			"pickup_range":
				s.pickup_range = val
			"mana_gain":
				s.mana_gain = val
			"life_steal":
				s.life_steal = val
			"enemy_max_hp_mult":
				s.enemy_max_hp_mult = val
	s.current_hp = s.max_hp
	player.update_pickup_detector()
	ArtifactManager.recompute_player()

func _save() -> void:
	var data: Dictionary = {
		"upgrade_levels": upgrade_levels,
		"persistent_currency": persistent_currency,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	if not json.data:
		return
	var data: Dictionary = json.data
	upgrade_levels = data.get("upgrade_levels", {})
	persistent_currency = int(data.get("persistent_currency", 0))
