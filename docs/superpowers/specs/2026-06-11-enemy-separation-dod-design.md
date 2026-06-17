# DOD Enemy Separation — Data-Oriented Design

## Problem

SwarmManager (`small_fast` enemies) uses Area2D-free DOD with PackedFloat32 arrays. The existing separation (lines 266-305) has:
1. **Double `sqrt`** per neighbor (lines 284, 285)
2. **Linear weight** `1 - d/r` → weak separation at medium distances, enemies still clump
3. **Cross-type only against SMALL_SEP_KEYS** (medium, mine, rampage) — misses big/overlord
4. **BOSS_FIGHT gate** (line 219) — `_process` returns early, swarm freezes during bosses
5. **No external displacement readout** — can't debug or visualize separation forces

## Design

### 1. SwarmManager — refactored separation

- Remove `if GameManager.is_boss_fight(): return`
- Add `_sep_dx: PackedFloat32Array`, `_sep_dy: PackedFloat32Array` — per-entity displacement, resized in `_resize_arrays()`
- Extract separation into `_compute_swarm_separation(i: int, delta: float) -> void`
- Quadratic weight: `weight = 1.0 - d²/r²` (one sqrt only: `inv_d = 1/sqrt(d_sq)`)
- Cross-type: call `EnemyMeshManager.query_all_positions_near()` covering ALL `_type_data` keys
- Store result in `_sep_dx[i]`, `_sep_dy[i]`
- Apply after computation: `_px[i] += _sep_dx[i]`, `_py[i] += _sep_dy[i]`

### 2. EnemyMeshManager — cross-type query + weight fix

- Rename `_small_pos_x/y` → `_cross_pos_x/y`
- Rename `query_small_positions_near` → `query_all_positions_near`
- Iterate ALL `_type_data` keys instead of only `SMALL_SEP_KEYS`
- Fix double sqrt → same quadratic weight in both separation blocks

### Math

```
For each neighbor j within radius r:
    dx = x_i - x_j,  dy = y_i - y_j
    d² = dx² + dy²
    if d² < r² and d² > ε:
        inv_d = 1/√d²
        weight = 1 - d²/r²       # quadratic: stronger near, smooth falloff
        sx += dx · inv_d · weight
        sy += dy · inv_d · weight
        nc += 1

if nc > 0:
    sep_dx = sx/nc · force · dt
    sep_dy = sy/nc · force · dt
```

### Constants (unchanged)

- SWARM_SEP_RADIUS = 30.0
- SWARM_SEP_FORCE = 120.0
- SWARM_SEP_INTERVAL = 2
- SWARM_SEP_MAX_NEIGHBORS = 8

### Files Changed

| File | Change |
|------|--------|
| `Systems/SwarmManager.gd` | Add `_sep_dx`, `_sep_dy` arrays + resize |
| | Remove BOSS_FIGHT gate (line 219-220) |
| | Extract `_compute_swarm_separation(i, delta)` |
| | Quadratic weight `1 - d²/r²` |
| | Cross-type via `query_all_positions_near` + `_cross_pos_x/y` |
| `Systems/EnemyMeshManager.gd` | `_small_pos_x/y` → `_cross_pos_x/y` |
| | `query_small_positions_near` → `query_all_positions_near` (all type_data keys) |
| | Fix double sqrt, quadratic weight in both separation blocks |
