class_name SpellData
extends Spell

@export_group("Projectile Visual")
@export var projectile_texture: Texture2D = null
@export var projectile_modulate: Color = Color.WHITE
@export var projectile_z_index: int = 3
@export var glow_texture: Texture2D = null
@export var glow_scale: float = 1.0
@export var glow_alpha: float = 1.0

@export_group("Animation")
@export var rotation_speed: float = 0.0
@export var scale_curve: Curve = null
@export var flicker_frequency: float = 0.0
@export var custom_shader_material: ShaderMaterial = null

@export_group("VFX")
@export var vfx_spawn_key: String = ""
@export var vfx_impact_key: String = ""
@export var vfx_death_key: String = ""
@export var vfx_flight_key: String = ""
@export var vfx_color_primary: Color = Color.WHITE
@export var vfx_color_secondary: Color = Color.GRAY
@export var vfx_intensity: float = 1.0

@export_group("Timing")
@export var spawn_delay: float = 0.0
@export var impact_duration: float = 0.5
@export var cycle_pause: float = 0.0
