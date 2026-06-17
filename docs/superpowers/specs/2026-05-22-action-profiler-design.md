# ActionProfiler — System for Tracking Game Actions and Their Performance Impact

## Purpose

Log every game action (from UI clicks to spell casts to enemy spawns) with Godot performance metrics before and after, to identify which actions actually impact FPS, process time, object count, etc.

## Architecture

```
ActionProfiler (Autoload, PROCESS_MODE_ALWAYS)
├── _snapshot() → Dictionary         # collects 6 Godot metrics
├── probe(category, action)           # static, called from managers
├── _on_eventbus_X(params)           # per-signal handlers, 19 total
├── _flush()                          # writes buffer to CSV every 60 frames
└── _print_summary()                  # console summary on F9 or game_over/victory
```

### Snapshot Format

```python
{
    fps: Engine.get_frames_per_second(),
    process: Performance.get_monitor(Performance.TIME_PROCESS),
    objects: Performance.get_monitor(Performance.OBJECT_COUNT),
    orphans: Performance.get_monitor(Performance.OBJECT_ORPHAN_COUNT),
    draw_calls: Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
    items_drawn: Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
}
```

### CSV Output

File: `user://profiler_{YYYYMMDD_HHMMSS}.csv`

Columns:
```
frame,timestamp,category,action,fps_before,fps_after,delta_fps,process_before,process_after,objects_before,objects_after,orphans_before,orphans_after,draw_calls_before,draw_calls_after,items_drawn_before,items_drawn_after
```

One row per event. Delta fields = after - before.

### Buffering

Events accumulate in a PackedStringArray buffer. Flush to file every 60 frames (~1 second). This avoids file I/O on every event.

### Enable/Disable

- Enabled by default in debug builds (`OS.is_debug_build()`), disabled in release.
- Runtime toggle via F9 key: first press = print summary, second press = toggle on/off.
- `_enabled: bool` flag controls all logging.

## Event Coverage

| Category | Actions | Source |
|----------|---------|--------|
| eventbus | 19 signals (player_damaged, enemy_died, wave_started, etc.) | EventBus connections in `_ready` |
| spawn | swarm, medium, big, mine, overlord, rampage | `ActionProfiler.probe()` from SwarmManager._spawn_unit, EnemyMeshManager._spawn_unit |
| death | swarm_killed, enemy_killed per type | `probe()` from SwarmManager/EnemyMeshManager kill paths |
| spell | cast (by name), upgrade (name+level), modify (name+mod) | EventBus spell_cast/spell_upgraded + probe from SpellCaster |
| vfx | death_effect, explosion, spark, level_up, heal, lightning, burst_pool_spawn | probe from BurstEffectPool.spawn, JuiceManager, VFXManager |
| powerup | activate/deactivate per type | EventBus mega_magnet signals + probe from PowerUpManager |
| ui | game_start, pause, resume, level_up_card, mod_card, settings_change, restart | EventBus signals + probe from UI callbacks |
| wave | phase_start, breather, special_event | probe from WaveManager |

## Probe Integration Points

Managers call `ActionProfiler.probe(category, action)` at key points:

1. **SwarmManager._spawn_unit()**: `probe("spawn", "swarm")` before HP>0 assignment
2. **EnemyMeshManager._spawn_unit()**: `probe("spawn", key)` before alive_indices.append
3. **SwarmManager damage methods** (6 methods): `probe("death", "swarm")` before HP=0
4. **EnemyMeshManager._kill_slot()**: `probe("death", key)` before HP=0
5. **EnemyMeshManager contact kill** (explodes/non-explodes): `probe("death", key)` before HP=0
6. **BurstEffectPool.spawn()**: `probe("vfx", "burst_pool_spawn")` before play()
7. **JuiceManager.spawn_death_effect/spawn_explosion_visual/screen_shake**: `probe("vfx", action)`
8. **VFXManager.spawn_level_up/spawn_heal**: `probe("vfx", action)`
9. **PowerUpManager.activate/deactivate**: `probe("powerup", type_name)`
10. **WaveManager phase transitions**: `probe("wave", phase_name)`

## Console Summary

Triggered by F9 or automatically on game_over/victory signals. Output:

1. **Top-10 actions by average FPS drop** (sorted by delta_fps ascending)
2. **Top-10 actions by peak process time** (sorted by process_after descending)
3. **Top-10 actions by object count increase** (sorted by delta_objects descending)
4. **Per-category aggregates**: avg delta_fps, avg delta_process, event count

Format: ASCII table in console output.

## Autoload Registration

Add to project.godot:
```
[autoload]
ActionProfiler="*res://Systems/ActionProfiler.gd"
```

Must load AFTER EventBus (already first autoload) so signals are available for connection.

## Performance Impact of Profiler Itself

- Snapshot: 6 `Performance.get_monitor()` calls = negligible (~0.001ms)
- CSV buffer append: string concatenation = negligible
- File flush every 60 frames: one file write = ~0.05ms
- Probe calls: one static function call per event = negligible
- Total estimated overhead: <0.1ms/frame, well within budget

## Files to Create/Modify

### Create
- `Systems/ActionProfiler.gd` — main profiler autoload (~200 lines)

### Modify (probe insertion, ~3-5 lines each)
- `Systems/SwarmManager.gd` — spawn + death probes
- `Systems/EnemyMeshManager.gd` — spawn + death probes
- `Systems/BurstEffectPool.gd` — spawn probe
- `Systems/JuiceManager.gd` — vfx probes
- `Systems/VFXManager.gd` — vfx probes
- `Autoload/PowerUpManager.gd` — activate/deactivate probes
- `Systems/Waves/WaveManager.gd` — phase probes
- `project.godot` — autoload registration
