# Shield Dome Redesign — Design Spec

## Goal

Redesign the Shield spell visual from a small procedural ellipse (46×69px) to a clean energy dome (bubble) that fully covers the character using a shader-based SDF approach.

## Requirements

- **Shape:** Clean semi-transparent dome (circle in 2D), fully enclosing the player
- **Size:** 1.5× player height (~72px radius for 48px player)
- **Visibility:** Always visible while charges remain, no pulsation — steady constant shield
- **Texture:** Clean dome with soft Fresnel glow at edges. No hex网格, no waves
- **Hit reaction:** Local flash at impact point — expanding ring that fades over 0.35s
- **States:** Color-coded by charge state (blue/red/gray/gold)
- **Thorns:**保留 Draw API for 8 spikes around dome perimeter

## Architecture

### New file: `Shaders/dome_shield.gdshader`

SDF-based shader on a full-viewport ColorRect. Draws dome as a circle in world coordinates with Fresnel edge glow and optional hit flash ring.

### Modified file: `Spells/visuals/ShieldAura.gd`

Replace all `draw_*` calls with:
- `ColorRect` (full viewport, z_index=2)
- `ShaderMaterial` with `dome_shield.gdshader`
- Keep: `top_level=true`, player tracking, state color logic, thorns Draw API

Scene structure (programmatic):
```
ShieldAura (Node2D)
  └── DomeRect (ColorRect, full viewport)
        └── ShaderMaterial → dome_shield.gdshader
```

## Shader Design

### Uniforms

| Uniform | Type | Description |
|---|---|---|
| `player_pos` | `vec2` | World coordinates of player |
| `shield_radius` | `float` | Dome radius in pixels (72px) |
| `dome_color` | `vec4` | Dome color (state-dependent) |
| `alpha_base` | `float` | Base transparency (0.10-0.14) |
| `alpha_edge` | `float` | Edge transparency (0.40-0.50) |
| `fresnel_power` | `float` | Fresnel strength (2.5) |
| `hit_pos` | `vec2` | World coordinates of damage source |
| `hit_time` | `float` | Time since hit in seconds (-1 = no hit) |
| `hit_radius` | `float` | Max wave radius (80px) |
| `hit_duration` | `float` | Flash duration (0.35s) |

### Shader logic

1. Convert fragment position → world coordinates
2. Distance to player: `d = distance(world_pos, player_pos)`
3. Normalized: `t = d / shield_radius`
4. Dome alpha: `lerp(alpha_base, alpha_edge, smoothstep(0.6, 1.0, t))`
5. Fresnel: `pow(1.0 - abs(dot(normal, view)), fresnel_power)`
6. Final dome alpha: `clamp(dome_alpha + fresnel, 0.0, 1.0)`
7. Hit flash (if `hit_time >= 0`):
   - `wave_r = (hit_time / hit_duration) * hit_radius`
   - `ring = smoothstep(wave_r - 8, wave_r, dh) - smoothstep(wave_r, wave_r + 8, dh)`
   - Brightness: `ring * (1.0 - hit_time / hit_duration)` — fades out
8. Outside dome (`t > 1.0`): alpha = 0.0

### Color table by state

| State | dome_color | alpha_base | alpha_edge | fresnel_power |
|---|---|---|---|---|
| Full charges | `(0.3, 0.7, 1.0)` | 0.10 | 0.40 | 2.5 |
| Partial charges | `(0.95, 0.3, 0.1)` | 0.12 | 0.45 | 2.0 |
| Empty (ghost) | `(0.25, 0.25, 0.25)` | 0.04 | 0.10 | 1.0 |
| Aegis mode | `(1.0, 0.85, 0.3)` | 0.14 | 0.50 | 3.0 |

## ShieldAura.gd Interface

```gdscript
func setup(player_node: Node2D) -> void
func set_colors(primary: Color, secondary: Color) -> void
func set_thorns(active: bool) -> void
func set_aegis(active: bool) → void
func on_charge_used(damage_pos: Vector2) → void
```

## Removed from ShieldAura.gd

- All `draw_*` calls (~150 lines)
- `_draw_ellipse()`, `_draw_ellipse_outline()`, `_draw_spikes()`, `_draw_cracks()`, `_draw_thorn_particles()`
- Constants: `RADIUS_X`, `RADIUS_Y`
- Hit flash variables: `_flash_t`, `_flash_pos` (replaced by shader uniforms)

## Preserved in ShieldAura.gd

- `top_level = true` + player position tracking
- State color logic → updates shader uniforms
- Thorns: Draw API for 8 spikes (separate from shader)
- `on_charge_used()` → sets hit uniforms

## Integration

**ShieldBehavior.gd:** No changes. Interface unchanged.
- `_create_aura()` → creates ShieldAura, passes player
- `intercept_damage()` → calls `_aura.on_charge_used(damage_pos)`
- `_apply_modifications()` → calls `set_colors()`, `set_thorns()`, `set_aegis()`

**Player.gd:** No changes. `take_damage()` calls `intercept_damage()` which triggers visual.

## Files to modify

| File | Action |
|---|---|
| `Shaders/dome_shield.gdshader` | **NEW** — SDF dome shader |
| `Spells/visuals/ShieldAura.gd` | **REWRITE** — replace Draw API with shader |
| `Spells/behaviors/ShieldBehavior.gd` | No changes |
| `Entities/Player/Player.gd` | No changes |
