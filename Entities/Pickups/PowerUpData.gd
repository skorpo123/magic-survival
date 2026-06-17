class_name PowerUpData extends Resource

enum PowerUpType {
	INVULNERABILITY,
	DAMAGE_MULTIPLIER,
	SPEED_BOOST,
	FREEZE_ENEMIES,
	FIRE_RATE_BOOST,
	MEGA_MAGNET,
}

@export var power_up_type: PowerUpType = PowerUpType.INVULNERABILITY
@export var duration: float = 10.0
@export var value: float = 1.0
@export var color: Color = Color.WHITE
@export var label: String = ""
@export var pool_name: StringName = &"PowerUp"

func _init() -> void:
	match power_up_type:
		PowerUpType.INVULNERABILITY:
			duration = 8.0
			value = 1.0
			color = Color(0.3, 0.7, 1.0)
			label = "Shield"
		PowerUpType.DAMAGE_MULTIPLIER:
			duration = 10.0
			value = 2.0
			color = Color(1.0, 0.3, 0.15)
			label = "2x Damage"
		PowerUpType.SPEED_BOOST:
			duration = 12.0
			value = 1.8
			color = Color(0.2, 1.0, 0.5)
			label = "Speed"
		PowerUpType.FREEZE_ENEMIES:
			duration = 6.0
			value = 0.15
			color = Color(0.5, 0.85, 1.0)
			label = "Freeze"
		PowerUpType.FIRE_RATE_BOOST:
			duration = 10.0
			value = 2.0
			color = Color(1.0, 0.85, 0.2)
			label = "Rapid Fire"
		PowerUpType.MEGA_MAGNET:
			duration = 5.0
			value = 1.0
			color = Color(0.9, 0.4, 1.0)
			label = "Mega Magnet"
