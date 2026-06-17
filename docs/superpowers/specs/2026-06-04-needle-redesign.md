# Needle Spell Redesign — Design Spec

**Date:** 2026-06-04
**Status:** Approved

## Summary

Redesign the Needle spell from a fast, short projectile into a ritual bone needle with stabbing/stitching behavior, a magical thread, and a satisfying puncture-pulse-return cycle.

## Current Problems

- NeedlePuff is a 40px-long, 1800 px/s projectile — too fast to see, too short to read as a "needle"
- No stabbing/stitching feeling — just flies through and fades
- stab_count=3 fires in rapid burst with 0.1s pause — feels like a machine gun, not a needle
- No thread/visual connection between player and needle
- needle_speed=1800 makes the needle almost invisible in flight

## Design Decisions

### 1. Behavior Cycle: Stab → Pulse → Return

The needle follows a distinct 4-phase cycle:

| Phase | Duration | Description |
|-------|----------|-------------|
| **FLY_OUT** | ~0.4s (range/speed) | Needle flies from player toward target direction |
| **STABBED** | 0.5s | Needle is embedded in enemy, pulsates with light (primary damage) |
| **FLY_BACK** | ~0.3s | Needle returns to player, pierces closest enemy on return path (50% bonus damage) |
| **COOLDOWN** | varies | Wait before next cycle begins |

- On FLY_OUT: deals path damage (like current `_deal_path_damage`)
- On STABBED: primary hit damage + pulsing glow VFX
- On FLY_BACK: pierce damage (50% of primary) to nearest enemy within a detection radius from the return path
- Thread snaps with dissolve particles when FLY_BACK begins

### 2. Visual: Bone Ritual Needle + Magical Thread

**Needle body:**
- Length: 70px (up from 40px)
- Core width: 1.2px with taper to 0.3px at tip
- Outer glow width: 3px
- Shape: slightly wider at base (ear/ушко area), tapers to sharp point
- Color: bone/cream base Color(0.85, 0.82, 0.78) with purple magical tint Color(0.6, 0.45, 0.75)
- Engravings: 4 notch marks along the body (thin perpendicular lines)
- Eye (ушко): elliptical widening at base, ~5px wide, 3px tall
- Tip: bright white glow, radius 2px, core 1px

**Thread (нить):**
- Drawn as a thin line from player position to needle ear (ушко)
- Semi-transparent: alpha 0.5-0.7
- Color: pale purple/magical Color(0.5, 0.35, 0.7, 0.6)
- Slight sinusoidal wobble (not perfectly straight) — animated offset
- On thread snap: dissolve into 4-6 small particles that drift and fade

**Stab pulsation (STABBED phase):**
- Needle glows brighter every 0.15s (3 pulses in 0.5s)
- Each pulse: tip flash white + body brightness spike
- Small spark burst at tip on first pulse

**Mesh construction (2 layers, like current):**
- Layer 0 (core): thin bright body + tip
- Layer 1 (outer glow): wider, lower alpha
- Ear detail: small ellipse drawn at base
- Engravings: thin lines perpendicular to body at 4 positions along length

### 3. Thread Behavior

- Visible during FLY_OUT and STABBED phases
- Wobbles slightly (sinusoidal offset, amplitude 2px, frequency ~3Hz)
- On FLY_BACK start: thread snaps — line disappears, 4-6 small particles spawn at midpoint, drift outward, fade over 0.3s
- Particles use existing BurstEffectPool type (or new "thread_dissolve" type)
- No thread during FLY_BACK (needle returns solo)

### 4. Stab Feel (Hybrid: Stab + Pierce on Return)

**Primary stab (STABBED phase):**
- Needle stops on contact with first enemy hit
- Remains embedded for 0.5s
- 3 light pulses at 0.15s intervals
- Primary damage applied on impact
- Small spark burst at tip on first pulse

**Return pierce (FLY_BACK phase):**
- Needle flies back toward player
- On return path, detects nearest enemy within 30px of path
- Deals 50% of primary damage to that enemy
- No stopping — continues to player

### 5. Multi-Needle: Chain/Cascade

| Spell Level | Needle Count | Behavior |
|-------------|-------------|----------|
| 1 | 1 | Single needle cycle |
| 2 | 1 | Same, more damage/range |
| 3 | 2 | Second needle launches 0.1s after first, slight angle offset |
| 4 | 2 | Same, more damage/range |
| 5 | 3 | Third needle launches 0.1s after second, slight angle offset |

- Each needle operates independently (own state machine)
- Cascade delay: 0.1s between launches
- Angle spread: ±8° per additional needle (so 3 needles = center, -8°, +8°)
- All needles share same cooldown — once all have returned, cooldown starts

### 6. Speed: 500 px/s

- Current: 1800 px/s → new: 500 px/s
- Flight time to max range (220px): ~0.44s
- Return flight: ~0.44s
- Total cycle (fly + stab + return): ~1.4s before cooldown
- Needle is clearly visible during flight, thread is readable

## State Machine

```
COOLDOWN → FLY_OUT → STABBED → FLY_BACK → COOLDOWN
                ↑                                 │
                └─────────────────────────────────┘
```

Each NeedlePuff has its own state. NeedleBehavior manages cascade timing and shared cooldown.

## New/Modified Exports in NeedleBehavior

| Export | Old Value | New Value | Notes |
|--------|-----------|-----------|-------|
| needle_speed | 1800.0 | 500.0 | Slower, readable flight |
| stab_count | 3 | (removed) | Replaced by STABBED phase |
| pause_time | 0.1 | (removed) | Replaced by stabbed_duration |
| needle_range | 220.0 | 220.0 | Unchanged |
| needle_count | 1 | 1 | Unchanged (upgrades add more) |
| cooldown_time | 0.8 | 1.2 | Longer to compensate for pierce-on-return |
| dir_smooth_speed | 3.5 | 4.0 | Unchanged |
| spawn_offset | 15.0 | 15.0 | Unchanged |

New exports:
- `stabbed_duration: float = 0.5` — time needle stays embedded
- `return_pierce_ratio: float = 0.5` — damage ratio for return pierce
- `cascade_delay: float = 0.1` — delay between multi-needle launches
- `cascade_spread: float = 8.0` — degrees of spread per additional needle
- `return_detect_radius: float = 30.0` — detection radius for return pierce

## NeedlePuff Changes

**New states:**
```
enum State { FLY_OUT, STABBED, FLY_BACK, DEAD }
```

**New properties:**
- `_stab_timer: float` — counts up during STABBED
- `_stab_pulse_count: int` — tracks pulses
- `_thread_particles: Array` — dissolve particles when thread snaps
- `_return_pierced: Dictionary` — tracks enemies hit on return (prevent double-hit)
- `_origin: Vector2` — player position at launch (for return target)

**Removed properties:**
- `_fading`, `_fade_timer` — replaced by FLY_BACK state
- `_bounce_count` — ricochet mod handles this differently now

**FLY_OUT phase:**
- Move along `_direction` at `_speed`
- Deal path damage via SwarmManager/EnemyMeshManager
- Draw thread from current player pos to needle ear
- When hitting an enemy → transition to STABBED
- When reaching max range without hitting → skip STABBED, transition directly to FLY_BACK (no pulse, no pierce)

**STABBED phase:**
- Needle stays at current position (attached to enemy if enemy is alive, or stays in place)
- Pulse glow every 0.15s (3 pulses)
- Primary damage already applied on impact
- After `stabbed_duration` → transition to FLY_BACK

**FLY_BACK phase:**
- Snap thread (spawn dissolve particles)
- Fly toward player current position at `_speed * 1.3` (slightly faster return)
- Detect nearest enemy within `return_detect_radius` of path, deal pierce damage
- On reaching player → transition to DEAD, notify behavior

**Thread drawing:**
- During FLY_OUT and STABBED: draw thin line from player to needle ear position
- Wobble: `sin(time * frequency) * amplitude` perpendicular offset
- Color: pale purple, alpha 0.6

## Modifications (Level 5)

**Needle Volley:**
- 7 needles in 45° cone burst (unchanged concept)
- Cascade delay removed for volley — all fire simultaneously
- Each needle still follows stab→pulse→return cycle

**Frost Shard:**
- 8 needles in radial burst (unchanged concept)
- Stabbed phase applies slow effect (3.5s) to hit enemy
- Return pierce also applies slow

**Ricochet Needle:**
- Single needle with bounce on return
- On FLY_BACK, instead of returning to player, bounces to next enemy (up to 3 times)
- Each bounce: needle flies to nearest unhit enemy, stabs (short stabbed 0.3s), then bounces again
- After max bounces or no target → returns to player

## LevelUpManager Changes

Update Needle factory:
- `needle_speed = 500.0` (was 1800.0)
- `cooldown_time = 1.2` (was 0.8)
- `stabbed_duration = 0.5` (new)
- `return_pierce_ratio = 0.5` (new)
- `cascade_delay = 0.1` (new)
- `cascade_spread = 8.0` (new)
- Remove: `stab_count`, `pause_time`

## Performance Notes

- Thread drawing: simple line in `_draw()` — negligible cost
- Thread dissolve: 4-6 particles, reuse BurstEffectPool if possible (new "thread_dissolve" type with pale purple color)
- Each needle has its own state machine — no cross-needle coordination overhead
- Pool size: 24 (unchanged, sufficient for 3 needles × volley worst case)
- Stab pulse: brightness modulation only, no extra draw calls
- Return pierce detection: single `find_closest_pos` call per frame per active FLY_BACK needle

## Files to Modify

1. `Spells/behaviors/NeedleBehavior.gd` — rewrite state machine, add cascade logic, new exports
2. `Spells/visuals/NeedlePuff.gd` — new state machine (FLY_OUT/STABBED/FLY_BACK/DEAD), thread drawing, bone needle mesh, stab pulse, return pierce
3. `Systems/LevelUpManager.gd` — update Needle factory exports, remove stab_count/pause_time
4. `Systems/BurstEffectPool.gd` — add "thread_dissolve" particle type (if needed)
