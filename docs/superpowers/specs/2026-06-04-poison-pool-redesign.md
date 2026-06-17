# Poison Pool Redesign — Stationary Trap Design Spec

**Date:** 2026-06-04
**Status:** Approved

## Summary

Redesign Poison Cloud (renamed to **Poison Pool**) from "follows player" to **stationary acid puddle trap**. Player casts auto (under themselves), pool materializes in 0.3s at that location, stays for 5 seconds, damages enemies in radius.

## Design Decisions

### 1. Cast Behavior
- **Auto-cast under player** (option B)
- 0.3s delay before pool materializes — player can move away
- Cast happens automatically on cooldown (no aiming required)

### 2. Pool Parameters
| Param | Value | Notes |
|-------|-------|-------|
| Initial count | 1 pool | Level 1 |
| Max count | 3 pools | Lv3 upgrade +1; Lv5 another +1 |
| Duration | 5 seconds | Lifetime per pool |
| Damage interval | 0.3s | Same as before |
| Spawn delay | 0.3s | Visual materialize animation |
| Base radius | 85 px | Same as before |
| Materialize anim | scale 0→1 | 0.3s ease-out |
| Despawn anim | alpha 1→0 + scale 1→1.2 | 0.4s ease-in |

### 3. Visual: Acid Puddle
- **Horizontal ellipse** with depth gradient (vertex colors: dark bottom → bright top)
- **Rising bubbles**: 8 GPUParticles2D, bright green, rise and fade
- **Splash drops**: 4 small parallelograms at pool edges
- **Halo above pool**: radial gradient sprite with low alpha
- **Pulse on damage tick**: modulate brightness 1.3 → tint over damage_interval * 0.5
- **Color**: bright green palette Color(0.4, 1.0, 0.2) (toxic acid)

### 4. Multi-Pool Management
- Pool of max 3 pool instances (configurable)
- Each pool independent (own position, lifetime, damage timer)
- Oldest pool despawns when limit reached (queue logic)
- No overlap limit — can cluster pools if desired

### 5. Modifications (Level 5)
- **Toxic Bloom**: enemy killed in pool → spawn mini-explosion (current behavior preserved)
- **Miasma**: 2.5x radius, -40% dmg per tick
- **Plague**: 3x tick speed, -25% dmg each

### 6. Upgrades (per level)
| Level | Effect |
|-------|--------|
| 1 | 1 pool, 85px radius, 5s duration |
| 2 | +25% dmg, +20% area (1 pool) |
| 3 | +50% dmg, +30% area, **+1 pool** (2 total) |
| 4 | +80% dmg, +40% area (2 pools) |
| 5 | +120% dmg, +60% area, **+1 pool** (3 total) |

## New Class: `PoisonPool.gd`

```gdscript
class_name PoisonPool extends Node2D
```

**Properties:**
- `global_position: Vector2` (fixed, set on spawn)
- `_lifetime: float` (5s)
- `_damage: float`
- `_damage_interval: float` (0.3s)
- `_damage_timer: float`
- `_radius: float`
- `_tint: Color`
- `_age: float` (time alive)
- `_spawn_delay: float` (0.3s)
- `_state: enum FORMING, ACTIVE, FADING`
- `_pool: Polygon2D` (acid puddle with vertex_color gradient)
- `_bubbles: GPUParticles2D`
- `_splash: Array[Polygon2D]`
- `_halo: Sprite2D`

**Signals:**
- `expired` (when lifetime ends and despawn starts)

**State machine:**
- FORMING (0.3s): scale 0→1 ease-out
- ACTIVE (4.7s): deal damage on interval, run bubble animation
- FADING (0.4s): alpha 1→0 + scale 1→1.2, then queue_free

## Files to Create/Modify

1. **Create** `Spells/visuals/PoisonPool.gd` — new class
2. **Create** `Spells/behaviors/PoisonPoolBehavior.gd` — full new logic
3. **Modify** `Systems/LevelUpManager.gd` — new factory `_create_poison_pool`
4. **Modify** `Autoload/SettingsManager.gd` — settings key `spell_poison_pool` with "Poison Pool" / "Ядовитая лужа"
5. **Modify** `Entities/Projectiles/Projectile.gd` and `FireballProjectile.gd` — spell_id mapping
6. **Asset** `Sprites/poison_puddle_icon_pix.png` — new icon

## Behavior Logic

```gdscript
class_name PoisonPoolBehavior extends BaseSpellBehavior

@export var base_radius: float = 85.0
@export var duration: float = 5.0
@export var damage_interval: float = 0.3
@export var spawn_delay: float = 0.3
@export var base_max_pools: int = 1  # changes per upgrade

var _active_pools: Array[PoisonPool] = []
var _caster_ref: Node2D
var _spell: Spell
var _player_stats: PlayerStats

func on_spell_added(caster, spell, player_stats):
    _caster_ref = caster
    _spell = spell
    _player_stats = player_stats
    _update_toxic_bloom()
    _cast_timer = 0.5

func tick(delta):
    _cast_timer -= delta
    if _cast_timer <= 0.0:
        _spawn_pool()
        _cast_timer = _get_cooldown_time()
    _cleanup_pools()
```

## Performance
- Each pool is a Node2D with 1 Polygon2D + 1 GPUParticles2D + 1 Sprite2D
- 3 pools max = ~12 draw calls total
- GPUParticles2D with `amount=8` per pool
- Total particles: 24 max — negligible

## No Regressions
- Toxic Bloom mod still works (enemy_died signal still subscribed)
- Miasma/Plague stat multipliers still apply via existing mod system
- ComboTracker integration (already in damage flow)
