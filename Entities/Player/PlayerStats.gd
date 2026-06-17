class_name PlayerStats extends Resource

@export_group("Health")
@export var max_hp: float = 100.0
@export var hp_regen: float = 0.0
@export var dodge_chance: float = 0.0
@export var damage_reduction: float = 0.0

@export_group("Movement")
@export var move_speed: float = 150.0

@export_group("Combat")
@export var magic_power: float = 1.0
@export var cooldown_reduction: float = 0.0
@export var spell_duration_mult: float = 1.0
@export var projectile_speed_mult: float = 1.0
@export var area_multiplier: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_damage_mult: float = 2.0
@export var life_steal: float = 0.0

@export_group("Economy")
@export var pickup_range: float = 80.0
@export var mana_gain: float = 1.0

@export_group("Enemy")
@export var enemy_max_hp_mult: float = 1.0

@export_group("Leveling")
@export var xp_to_next_level: float = 15.0
@export var xp_scale_factor: float = 1.15
@export var starting_level: int = 1

var current_hp: float = 100.0
var current_xp: float = 0.0
var current_level: int = 1

func get_max_hp() -> float:
	return max_hp

func get_effective_cooldown(base_cooldown: float) -> float:
	return base_cooldown * (1.0 - clampf(cooldown_reduction, 0.0, 0.75))

func get_xp_required() -> float:
	return xp_to_next_level * pow(xp_scale_factor, current_level - 1)

func get_damage_multiplier() -> float:
	return magic_power

func get_mitigated_damage(amount: float) -> float:
	return amount * (1.0 - clampf(damage_reduction, 0.0, 0.9))
