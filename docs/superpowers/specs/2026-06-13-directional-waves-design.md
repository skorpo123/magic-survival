# Directional Waves — Design Spec

## Goal
Replace the current pulse-spawn system with Magic Survival–style directional waves: enemies spawn from specific screen-edge directions in spreading arcs, with continuous background trickle between waves.

## Architecture

### Wave Config (per wave)
- **type**: `SURROUND | DIRECTIONAL | AMBUSH`
- **groups**: array of `{angle: float, arc_deg: float, count: int}`
- Spawned all at once — each group spawns `count` enemies at the screen edge within `[angle - arc/2, angle + arc/2]`

### Wave Timer
- `_wave_timer` counts up each frame
- When `>= wave_interval`, spawn a wave, reset timer
- `wave_interval` ramps: 5s → 2s over 300s (lerp)

### Trickle Timer
- `_trickle_timer` counts up each frame
- When `>= trickle_interval`, spawn 1-2 enemies from a random direction
- `trickle_interval` ramps: 2s → 0.33s (0.5→3.0 enemies/sec)

### Direction Picking
- `_pick_wave_config(type) → Array[DirectionGroup]`
- **SURROUND**: 4 groups at 0°, 90°, 180°, 270° with full arc
- **DIRECTIONAL**: `randi_range(1, max_groups)` groups at random angles, player front excluded (±45°)
- **AMBUSH**: 1-2 groups at `player_moving_away_angle ± randf_range(-60°, 60°)`

### Spawn Position
- `_get_directional_spawn_pos(angle, arc_deg) → Vector2`
- Picks a random angle within `angle ± arc/2`
- Calculates intersection of that ray with the camera frustum edge (viewport_size / camera_zoom)
- Offsets outward by 20-40px so enemies are just off-screen
- If rear-bias wave: apply 70% rear-bias within the directional arc

### Wave Types & Weights
- **SURROUND (40%)** — 4 groups all around
- **DIRECTIONAL (35%)** — 1-3 groups, random directions
- **AMBUSH (25%)** — 1-2 groups from behind

## Parameters (time-based ramp)

| Parameter | 0s | 60s | 120s | 300s+ |
|---|---|---|---|---|
| Wave interval | 5s | 4s | 3s | 2s |
| Groups per wave | 1 | 1-2 | 2 | 2-3 |
| Enemies per group | 3-4 | 5-7 | 8-12 | 12-18 |
| Arc spread | 80° | 90° | 100° | 120° |
| Trickle enemies/sec | 0.5 | 1.0 | 2.0 | 3.0 |
| Max directions (directional type) | 1 | 2 | 2 | 3 |

## Implementation

### Files to modify
- `Systems/Waves/WaveManager.gd` — main changes
- Optionally remove unused `SubPhase` values if no longer referenced

### New functions in WaveManager
```
func _pick_wave_config() -> Dictionary
    # picks type by weight, builds group array with params

func _spawn_directional_wave(config: Dictionary) -> void
    # iterates groups, spawns enemies via _spawn_single_enemy

func _get_directional_spawn_pos(angle: float, arc: float) -> Vector2
    # returns off-screen spawn position within arc

func _trickle_spawn() -> void
    # spawns 1-2 enemies from random direction

func _get_groups_per_wave() -> int
func _get_enemies_per_group() -> int
func _get_arc_spread() -> float
func _get_trickle_rate() -> float
    # all ramp with game_time
```

### Changed functions
```
_process(delta) — remove pulse logic, add wave_timer + trickle_timer
_get_ring_spawn_pos — converted to _get_directional_spawn_pos
_pulse_timer, _pulse_first_spawn, _get_pulse_interval, _get_pulse_size — REMOVED
```

### Enemy scaling / composition
- `_get_current_composition()` unchanged (phase-based)
- `_pick_from_composition()` unchanged
- `_apply_difficulty_scaling()` unchanged
- Composition picked per-group, not per-wave — each group independently picks from current composition

## Edge cases
- **First 30s gentle start**: first wave interval forced to 6s, group count = 1, enemies per group = 3-4
- **Pause/resume**: timers use raw delta (respects tree pause)
- **Phase transitions**: waves continue across phases; phase schedule controls composition only
- **Boss fights**: WaveManager._process returns early during boss fights (already implemented)

## Migration
- Old `_get_pulse_*` functions and vars (`_pulse_timer`, `_pulse_first_spawn`, `_get_pulse_size`, `_get_pulse_interval`) — removed
- `_get_ring_spawn_pos` — replaced by `_get_directional_spawn_pos`
- `_spawn_pulse` — replaced by `_spawn_directional_wave`
- Phase schedule sub-phases remain the same (BOSS_SPAWN/BREATHER/etc)
