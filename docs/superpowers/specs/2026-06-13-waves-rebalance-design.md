# Wave System Rebalance — Magic Survival Pressure

## Goal
Make wave spawning feel like Magic Survival: constant pressure, massive waves, one dominant enemy type per phase, breather = swarm of small enemies.

## Changes

### 1. Phase Schedule (`_build_phase_schedule`)
Each phase = 3 sub-phases (Light→Medium→Burst) + Boss + Breather.
Durations shortened, rates increased.

| Phase | Main Type | Light (s) | Medium (s) | Burst (s) | Rate Mult | Batch |
|-------|-----------|-----------|------------|-----------|-----------|-------|
| 1 Drone | medium 75% | 30 | 30 | 20 | 2→3.5→5 | 2→3→5 |
| Breather | small 85% | 20 | – | – | 6 | 5 |
| 2 Mine | mine 70% | 25 | 25 | 15 | 2→3.5→5 | 2→3→5 |
| Breather | small 85% | 20 | – | – | 7 | 6 |
| 3 Iron | big 60% | 25 | 25 | 15 | 2→3.5→5 | 2→3→5 |
| Breather | small 80% | 20 | – | – | 7 | 6 |
| 4 Berserk | rampage 70% | 20 | 20 | 15 | 2→4→6 | 2→3→5 |
| Breather | small 85% | 15 | – | – | 8 | 6 |
| 5 Overlord | overlord 60% | 20 | 20 | 15 | 2→4→6 | 2→3→5 |

Composition per phase: main type 60-75% + small (swarm) 20-30% + secondary 5-10%.
Breather: swarm 80-85% + phase main type 15-20%.

### 2. Base Spawn Rate (`_get_trickle_spawn_rate`)
Time-based scaling:
- 0-60s: 3.0 enemies/sec
- 60-180s: 4.0 enemies/sec
- 180-300s: 5.0 enemies/sec
- 300s+: 6.0 enemies/sec

### 3. Max Enemies Cap
`300 + phase_index * 200` (capped at 1300).

### 4. Edge Waves
Interval: `randf_range(2.0, 4.0)` seconds.
Per side: `randi_range(5, 8)` enemies.
Spawn from composition (like trickle).
Disabled during BOSS_SPAWN sub-phase.

### 5. Breather Sub-Phase
- rate_mult: 6-8 (scales with phase)
- batch: 5-6
- composition: 80-85% small (swarm), rest = phase's main type
- Edge waves enabled during breather (more pressure)

### 6. DifficultyManager tweaks
- Difficulty multiplier: `1.0 + t*0.10 + pow(t/12.0, 2.0)*2.0` (faster ramp)
- HP mult cap: 6.0
- Speed mult cap: 2.0
- Special event interval: `maxf(45.0 - t*0.2, 20.0)`

### 7. Boss Attacks (no changes needed)
Already working with enrage, unique patterns per type.

## Files to Modify
- `Systems/Waves/WaveManager.gd` — phase schedule, spawn rate, caps, edge waves
- `Systems/Waves/DifficultyManager.gd` — ramp curve, special event interval
