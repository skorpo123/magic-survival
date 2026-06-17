class_name DifficultyManager extends Node2D

func get_difficulty_multiplier() -> float:
	var minute := floori(GameManager.game_time / 60.0)
	var t := float(minute)
	return 1.0 + t * 0.10 + pow(t / 12.0, 2.0) * 2.0

func get_enemy_hp_multiplier() -> float:
	return 1.0 + (get_difficulty_multiplier() - 1.0) * 0.7

func get_enemy_speed_multiplier() -> float:
	return minf(1.0 + (get_difficulty_multiplier() - 1.0) * 0.15, 2.0)

func get_enemy_damage_multiplier() -> float:
	return 1.0 + (get_difficulty_multiplier() - 1.0) * 0.4

func get_tough_enemy_chance() -> float:
	var minute := floori(GameManager.game_time / 60.0)
	var t := float(minute)
	return clampf(t * 0.04, 0.0, 0.6)

func get_xp_multiplier() -> float:
	var minute := floori(GameManager.game_time / 60.0)
	var t := float(minute)
	return clampf(0.4 + t * 0.04, 0.4, 1.5)

func get_special_event_interval() -> float:
	var minute := floori(GameManager.game_time / 60.0)
	var t := float(minute)
	return maxf(45.0 - t * 0.5, 20.0)
