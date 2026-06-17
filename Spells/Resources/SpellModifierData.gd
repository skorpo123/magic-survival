class_name SpellModifierData
extends SpellModification

@export_group("Visual Overrides")
@export var override_projectile_texture: Texture2D = null
@export var override_projectile_modulate: Color = Color.WHITE
@export var override_glow_scale: float = -1.0
@export var override_glow_alpha: float = -1.0
@export var override_vfx_spawn_key: String = ""
@export var override_vfx_impact_key: String = ""
@export var override_vfx_color_primary: Color = Color.WHITE
@export var override_vfx_color_secondary: Color = Color.GRAY
@export var override_custom_shader: ShaderMaterial = null
