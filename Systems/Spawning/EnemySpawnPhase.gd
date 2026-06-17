class_name EnemySpawnPhase extends Resource

@export var phase_number: int = 1
@export var min_time: float = 0.0
@export var max_time: float = 240.0

@export_group("Enemy Weights")
@export var small_weight: float = 1.0
@export var medium_weight: float = 0.0
@export var big_weight: float = 0.0

@export_group("Trickle Spawn (between waves)")
@export var trickle_enemies_per_minute: float = 12.0
@export var trickle_small_only: bool = true

@export_group("Wave Config")
@export var wave_interval_min: float = 90.0
@export var wave_interval_max: float = 150.0
@export var wave_enemy_count_base: int = 10
@export var wave_enemy_count_per_wave: int = 5
@export var wave_max_enemies: int = 60

@export_group("Difficulty Scaling")
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var elite_chance: float = 0.0

@export_group("Hard Caps")
@export var max_active_enemies: int = 150
@export var despawn_distance: float = 1500.0
