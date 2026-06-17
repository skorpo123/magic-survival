# Directional Waves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace pulse-spawn with Magic Survival–style directional waves + continuous trickle

**Architecture:** WaveManager.gd gets new directional-spawn functions, ramp functions, and timer logic. Old pulse variables/functions removed. Wave types: SURROUND (all sides), DIRECTIONAL (1-3 random directions), AMBUSH (from behind). Trickle between waves.

**Tech Stack:** Godot 4.6.4, GDScript

---

### Task 1: Add new enums, constants, and state variables

**Files:**
- Modify: `Systems/Waves/WaveManager.gd:1-66`

- [ ] **Add WaveType enum and new vars**

Add after the existing `enum SubPhase` block:

```gdscript
enum WaveType {
	SURROUND,
	DIRECTIONAL,
	AMBUSH,
}
```

Add after existing `_boss_chest_collected` variable:

```gdscript
var _wave_timer: float = 0.0
var _trickle_accumulator: float = 0.0
var _first_wave: bool = true
```

Add after existing `_spawn_delay` variable:
(No change — `_spawn_delay` stays for initial 1.5s pause)

- [ ] **Verify**: read lines 1-66 of WaveManager.gd to confirm no conflicts

---

### Task 2: Add ramp functions for wave parameters

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` — add after `_get_pulse_interval()` (or after existing ramp functions)

- [ ] **Add `_get_wave_interval()`**

Replace existing `_get_pulse_interval()`:

```gdscript
func _get_wave_interval() -> float:
	if _first_wave:
		return 6.0
	var elapsed := GameManager.game_time
	var t := clampf(elapsed / 300.0, 0.0, 1.0)
	return lerpf(5.0, 2.0, t)
```

- [ ] **Add `_get_enemies_per_group()`**

```gdscript
func _get_enemies_per_group() -> int:
	var elapsed := GameManager.game_time
	if elapsed < 30.0:
		return randi_range(3, 4)
	elif elapsed < 60.0:
		return randi_range(5, 7)
	elif elapsed < 120.0:
		return randi_range(8, 12)
	else:
		return randi_range(12, 18)
```

- [ ] **Add `_get_groups_per_wave()`**

```gdscript
func _get_groups_per_wave() -> int:
	var elapsed := GameManager.game_time
	if elapsed < 30.0:
		return 1
	elif elapsed < 120.0:
		return 2 if randf() > 0.5 else 1
	else:
		return randi_range(2, 3)
```

- [ ] **Add `_get_arc_spread()`**

```gdscript
func _get_arc_spread() -> float:
	var elapsed := GameManager.game_time
	if elapsed < 60.0:
		return 80.0
	elif elapsed < 120.0:
		return 90.0
	elif elapsed < 180.0:
		return 100.0
	else:
		return 120.0
```

- [ ] **Add `_get_trickle_rate()`**

```gdscript
func _get_trickle_rate() -> float:
	var elapsed := GameManager.game_time
	if elapsed < 60.0:
		return 0.5
	elif elapsed < 120.0:
		return 1.0
	elif elapsed < 180.0:
		return 2.0
	else:
		return 3.0
```

---

### Task 3: Add directional spawn position function

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` — add new function, keep old `_get_ring_spawn_pos` for now (remove after migration)

- [ ] **Add `_get_directional_spawn_pos()`**

Add after `_get_ring_spawn_pos`:

```gdscript
func _get_directional_spawn_pos(angle: float, arc_deg: float) -> Vector2:
	var player := GameManager.get_player()
	if not player:
		return Vector2.ZERO

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var viewport_size := get_viewport_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		viewport_size = Vector2(1152.0, 648.0)
	var cam_zoom := Vector2(1.5, 1.5)
	if cam:
		cam_zoom = cam.zoom

	var half_arc := deg_to_rad(arc_deg) * 0.5
	var spawn_angle := angle + randf_range(-half_arc, half_arc)

	var half_size := viewport_size / (2.0 * cam_zoom)
	var dir := Vector2.RIGHT.rotated(spawn_angle)
	var abs_dir := Vector2(abs(dir.x), abs(dir.y))
	var t: float
	if abs_dir.x > 0.001 and abs_dir.y > 0.001:
		t = minf(half_size.x / abs_dir.x, half_size.y / abs_dir.y)
	elif abs_dir.x > 0.001:
		t = half_size.x / abs_dir.x
	else:
		t = half_size.y / abs_dir.y

	return player.global_position + dir * (t + 60.0)
```

---

### Task 4: Add wave config builder and spawner

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` — add after `_get_directional_spawn_pos`

- [ ] **Add `_build_wave_groups()`**

```gdscript
func _build_wave_groups(wave_type: int) -> Array:
	var n_groups := _get_groups_per_wave()
	var enemies_per_group := _get_enemies_per_group()
	var arc := _get_arc_spread()
	var groups: Array = []

	match wave_type:
		WaveType.SURROUND:
			for angle in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
				groups.append({"angle": angle, "arc": arc, "count": enemies_per_group})

		WaveType.DIRECTIONAL:
			var player_angle := _player_last_dir.angle()
			for i in range(n_groups):
				var angle: float
				for _attempt in range(10):
					angle = randf_range(0, TAU)
					var diff := absf(angle - player_angle)
					diff = minf(diff, TAU - diff)
					if diff > deg_to_rad(45.0):
						break
				groups.append({"angle": angle, "arc": arc, "count": enemies_per_group})

		WaveType.AMBUSH:
			var rear_angle := _player_last_dir.angle() + PI
			for i in range(n_groups):
				var angle := rear_angle + randf_range(-deg_to_rad(60.0), deg_to_rad(60.0))
				groups.append({"angle": angle, "arc": arc * 0.8, "count": enemies_per_group})

	return groups
```

- [ ] **Add `_pick_wave_config()`**

```gdscript
func _pick_wave_config() -> Dictionary:
	var roll := randf()
	var wave_type: int
	if roll < 0.4:
		wave_type = WaveType.SURROUND
	elif roll < 0.75:
		wave_type = WaveType.DIRECTIONAL
	else:
		wave_type = WaveType.AMBUSH

	return {"type": wave_type, "groups": _build_wave_groups(wave_type)}
```

- [ ] **Add `_spawn_directional_wave()`**

```gdscript
func _spawn_directional_wave(config: Dictionary) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var groups: Array = config["groups"]
	for group in groups:
		var count: int = group["count"]
		var angle: float = group["angle"]
		var arc: float = group["arc"]
		for i in range(count):
			var effective_count := SwarmManager.get_count() + EnemyMeshManager.get_total_count()
			if effective_count >= max_enemies_on_screen:
				return
			var spawn_pos := _get_directional_spawn_pos(angle, arc)
			var data := _pick_from_composition(_cached_comp)
			var scaled_data := _apply_difficulty_scaling(data)
			_spawn_single_enemy(spawn_pos, scaled_data)
```

---

### Task 5: Add trickle spawn

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` — add after `_spawn_directional_wave`

- [ ] **Add `_trickle_spawn()`**

```gdscript
func _trickle_spawn() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var angle := randf_range(0, TAU)
	var spawn_pos := _get_directional_spawn_pos(angle, 40.0)
	var data := _pick_from_composition(_cached_comp)
	var scaled_data := _apply_difficulty_scaling(data)
	_spawn_single_enemy(spawn_pos, scaled_data)
```

---

### Task 6: Rewrite `_process()` to use directional waves + trickle

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` lines ~308-365 (the `_process()` body)

- [ ] **Replace `_process()` body**

Replace the entire `_process(delta)` function body (from `if not _initialized` to end of `_orb_spawn_timer` section):

```gdscript
func _process(delta: float) -> void:
	if not _initialized or not GameManager.is_playing():
		return

	if GameManager.is_boss_fight():
		return

	var phase_limit: int = 300 + _phase_index * 200
	max_enemies_on_screen = mini(phase_limit, 1300)

	if _spawn_delay > 0.0:
		_spawn_delay -= delta
		return

	_update_player_direction()

	var prev_sub := _sub_phase_index
	_advance_sub_phase(delta)
	if _sub_phase_index != prev_sub:
		_cached_dirty = true

	if _cached_dirty:
		_cached_comp = _get_current_composition()
		_cached_hp_mult = difficulty_manager.get_enemy_hp_multiplier()
		_cached_speed_mult = difficulty_manager.get_enemy_speed_multiplier()
		_cached_dmg_mult = difficulty_manager.get_enemy_damage_multiplier()
		_cached_scaled.clear()
		_cached_dirty = false

	var effective_count: int = SwarmManager.get_count() + EnemyMeshManager.get_total_count()
	if effective_count < max_enemies_on_screen:
		_wave_timer += delta
		var interval := _get_wave_interval()
		if _wave_timer >= interval:
			_wave_timer = 0.0
			_first_wave = false
			var config := _pick_wave_config()
			_spawn_directional_wave(config)

		_trickle_accumulator += delta * _get_trickle_rate()
		while _trickle_accumulator >= 1.0:
			_trickle_spawn()
			_trickle_accumulator -= 1.0
	else:
		_wave_timer = 0.0

	_special_event_timer -= delta
	if _special_event_timer <= 0.0:
		_special_event_timer = difficulty_manager.get_special_event_interval()
		_trigger_special_event()

	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = randf_range(25.0, 45.0)
		_spawn_heart()

	_power_up_timer -= delta
	if _power_up_timer <= 0.0:
		_power_up_timer = randf_range(45.0, 90.0)
		_spawn_power_up()

	_orb_spawn_timer -= delta
	if _orb_spawn_timer <= 0.0:
		_orb_spawn_timer = randf_range(1.5, 3.5)
		_spawn_ambient_orb()
```

---

### Task 7: Remove old pulse functions and vars

**Files:**
- Modify: `Systems/Waves/WaveManager.gd`

- [ ] **Remove old vars from `_on_game_started()`**

In `_on_game_started()`, remove these lines:
```gdscript
_pulse_timer = 0.0      # REMOVE
_wave_burst_timer = 0.0  # REMOVE
_wave_active = false     # REMOVE
_wave_enemy_target = 0   # REMOVE
_enemies_spawned_this_wave = 0  # REMOVE
```

And set new vars:
```gdscript
_wave_timer = 0.0
_trickle_accumulator = 0.0
_first_wave = true
```

Add these to the existing reset section (around line 282-304).

- [ ] **Remove old var declarations**

Find and remove these lines from the var declarations section (around lines 24-65):
```gdscript
var _pulse_timer: float = 0.0           # REMOVE
var _wave_burst_timer: float = 0.0       # REMOVE
var _wave_active: bool = false           # REMOVE
var _enemies_spawned_this_wave: int = 0  # REMOVE
var _wave_enemy_target: int = 0          # REMOVE
var _pulse_first_spawn: bool = true      # REMOVE
```

- [ ] **Remove `_get_pulse_interval()`**

Delete the entire `_get_pulse_interval()` function.

- [ ] **Remove `_get_pulse_size()`**

Delete the entire `_get_pulse_size()` function.

- [ ] **Remove `_spawn_pulse()`**

Delete the entire `_spawn_pulse()` function.

- [ ] **Remove unused `_wave_timer`?**

The old `_wave_timer` was used differently. Verify the new `_wave_timer` declaration doesn't conflict — it was already removed above.

---

### Task 8: Update special events to use directional spawn

**Files:**
- Modify: `Systems/Waves/WaveManager.gd` — special event functions

- [ ] **Update `_event_swarm_rush()`**

Replace `_get_ring_spawn_pos(player)` calls with directional spawns from surround pattern:

```gdscript
func _event_swarm_rush() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 25 + int(difficulty_manager.get_difficulty_multiplier() * 10)
	var comp := _cached_comp
	var arc := _get_arc_spread()
	for i in range(count):
		var dir_angle := randf_range(0, TAU)
		var spawn_pos := _get_directional_spawn_pos(dir_angle, arc)
		var data := _pick_from_composition(comp)
		var scaled_data := _apply_difficulty_scaling(data)
		if data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
			var direction := spawn_pos.direction_to(player.global_position)
			SwarmManager.spawn(spawn_pos, direction, scaled_data.max_hp, scaled_data.speed, scaled_data.explosion_damage, scaled_data.xp_value)
		else:
			match data.enemy_class:
				EnemyData.EnemyClass.MEDIUM:
					EnemyMeshManager.spawn_medium(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)
				EnemyData.EnemyClass.MINE:
					EnemyMeshManager.spawn_mine(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
				EnemyData.EnemyClass.BIG_TANK:
					EnemyMeshManager.spawn_big(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, data.pushback_force, scaled_data.xp_value)
				EnemyData.EnemyClass.OVERLORD:
					EnemyMeshManager.spawn_overlord(spawn_pos, scaled_data.max_hp, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
				EnemyData.EnemyClass.RAMPAGE:
					EnemyMeshManager.spawn_rampage(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)
```

- [ ] **Update `_event_tank_column()`**

Replace `_get_ring_spawn_pos` with directional spawn:

```gdscript
func _event_tank_column() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 4 + int(difficulty_manager.get_difficulty_multiplier() * 2)
	var base_angle := _player_last_dir.angle()
	var arc := _get_arc_spread() * 0.3
	for i in range(count):
		var spawn_pos := _get_directional_spawn_pos(base_angle, arc)
		var data := _big_data if randf() > 0.3 else _overlord_data
		var scaled_data := _apply_difficulty_scaling(data)
		if data.enemy_class == EnemyData.EnemyClass.BIG_TANK:
			EnemyMeshManager.spawn_big(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, data.pushback_force, scaled_data.xp_value)
		else:
			EnemyMeshManager.spawn_overlord(spawn_pos, scaled_data.max_hp, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
```

- [ ] **Update `_event_elite_wave()`**

Replace like swarm_rush — change `_get_ring_spawn_pos(player)` to `_get_directional_spawn_pos(randf_range(0, TAU), _get_arc_spread())`.

---

### Task 9: Clean up old `_get_ring_spawn_pos`

**Files:**
- Modify: `Systems/Waves/WaveManager.gd`

- [ ] **Verify no remaining callers of `_get_ring_spawn_pos()`**

Search all files for `_get_ring_spawn_pos`. After removing all references above, delete the function entirely.

- [ ] **Delete `_get_ring_spawn_pos()`**

Remove the entire `_get_ring_spawn_pos` function (approximately lines 510-541 in the original file).
