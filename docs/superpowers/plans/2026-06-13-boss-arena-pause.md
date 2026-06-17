# Boss Arena + Pause Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a boss spawns, activate a circular arena (visible inside, darkness outside, invisible walls), pause ALL game systems, keep everything paused until the boss is defeated AND the chest is collected.

**Architecture:** BossArena.gd already exists (130 lines) with shader overlay + StaticBody2D wall, but has bugs preventing it from working. Fix: add `process_mode = PROCESS_MODE_ALWAYS`, pause tree on boss fight entry, delay arena deactivation until chest pickup via `artifact_equipped` signal.

**Tech Stack:** Godot 4.6.2, GDScript, ShaderMaterial (canvas_item), StaticBody2D/CircleShape2D

---

### Task 1: Fix BossArena process_mode and signal wiring

**Files:**
- Modify: `Systems/BossArena.gd:37-61`

The arena overlay uses `_process()` to update shader camera tracking. If tree is paused, `_process()` stops and the overlay freezes/disappears. Also needs to deactivate on `artifact_equipped` (chest pickup) instead of `boss_fight_ended`.

- [ ] **Step 1: Add process_mode and fix signal wiring in BossArena.gd**

In `_ready()`, add `process_mode = Node.PROCESS_MODE_ALWAYS` before overlay creation, and connect to `artifact_equipped` for deactivation:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 150
	_overlay.visible = false
	_overlay.color = Color(0, 0, 0, 1)
	add_child(_overlay)

	_wall_body = StaticBody2D.new()
	_wall_body.collision_layer = 0
	_wall_body.collision_mask = 1
	add_child(_wall_body)

	_circle_shape = CircleShape2D.new()
	_circle_shape.radius = _radius

	_wall_collision = CollisionShape2D.new()
	_wall_collision.shape = _circle_shape
	_wall_body.add_child(_wall_collision)

	_apply_overlay_size()

	EventBus.boss_fight_started.connect(_on_boss_fight_started)
	EventBus.boss_fight_ended.connect(_on_boss_fight_ended)
	EventBus.game_started.connect(_on_game_started)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
```

- [ ] **Step 2: Add _on_artifact_equipped handler**

Add this method after `_on_boss_fight_ended`:

```gdscript
func _on_artifact_equipped(_artifact: Resource) -> void:
	if _arena_active:
		deactivate()
```

- [ ] **Step 3: Verify BossArena node type**

The arena is created as `Node2D` in Main.gd:52-56. `process_mode` is a Node property, so it works on Node2D. No change needed in Main.gd.

---

### Task 2: Pause tree on boss fight, unpause on exit

**Files:**
- Modify: `Autoload/GameManager.gd:138-144`

Currently `enter_boss_fight()` only sets state + emits signal. Need to also pause the tree so all default-process_mode systems freeze.

- [ ] **Step 1: Pause tree in enter_boss_fight()**

```gdscript
func enter_boss_fight() -> void:
	current_state = GameState.BOSS_FIGHT
	get_tree().paused = true
	EventBus.boss_fight_started.emit()
```

- [ ] **Step 2: Unpause tree in exit_boss_fight()**

```gdscript
func exit_boss_fight() -> void:
	current_state = GameState.PLAYING
	get_tree().paused = false
	EventBus.boss_fight_ended.emit()
```

---

### Task 3: Ensure boss systems keep processing during pause

**Files:**
- Verify: `Systems/BossManager.gd` — already has `set_process(true)` at spawn, but needs `process_mode = PROCESS_MODE_ALWAYS`
- Verify: `Entities/Player/Player.gd` — needs `process_mode = PROCESS_MODE_ALWAYS`
- Verify: `UI/HUD.gd` — needs `process_mode = PROCESS_MODE_ALWAYS`
- Verify: `UI/BossHealthBar.gd` — needs `process_mode = PROCESS_MODE_ALWAYS`

During boss fight, tree is paused. Only nodes with `process_mode = PROCESS_MODE_ALWAYS` continue processing.

- [ ] **Step 1: Add process_mode to BossManager**

In `BossManager._ready()` (line 50-52), add before `set_process(false)`:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.boss_spawned.connect(_on_boss_spawned)
```

- [ ] **Step 2: Add process_mode to Player**

In `Player._ready()`, add at the top:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ... rest of existing _ready()
```

- [ ] **Step 3: Add process_mode to HUD**

In `HUD._ready()`, add at the top:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ... rest of existing _ready()
```

- [ ] **Step 4: Add process_mode to BossHealthBar**

In `BossHealthBar._ready()` (or constructor), add:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ... rest of existing _ready()
```

- [ ] **Step 5: Verify other UI screens work during pause**

These already have `process_mode = PROCESS_MODE_WHEN_PAUSED`:
- PauseMenu (line 26)
- LevelUpScreen
- ArtifactSelectScreen (line 23)
- FusionGrimoire

These will continue processing when tree is paused. No changes needed.

---

### Task 4: Fix arena deactivation timing

**Files:**
- Modify: `Systems/BossArena.gd:72-73`
- Modify: `Autoload/GameManager.gd:138-144`

Currently: `boss_fight_ended` → BossArena.deactivate(). This fires when `exit_boss_fight()` is called, which happens on `artifact_equipped`. But we need the arena to stay until AFTER the chest is collected.

The flow should be:
1. Boss dies → `boss_defeated` → chest spawned
2. Player collects chest → `chest_opened` → ArtifactSelectScreen shown (tree still paused)
3. Player selects artifact → `artifact_equipped` → `exit_boss_fight()` → tree unpaused + `boss_fight_ended`
4. BossArena deactivates on `artifact_equipped` (one-shot)

- [ ] **Step 1: Disconnect boss_fight_ended from arena deactivation**

In BossArena `_ready()`, remove the `boss_fight_ended` connection:

```gdscript
	EventBus.boss_fight_started.connect(_on_boss_fight_started)
	# REMOVED: EventBus.boss_fight_ended.connect(_on_boss_fight_ended)
	EventBus.game_started.connect(_on_game_started)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
```

Keep `_on_boss_fight_ended()` method but it's now unused (can leave for safety).

- [ ] **Step 2: Verify GameManager._on_artifact_equipped still calls exit_boss_fight()**

Already exists at line 38-39:
```gdscript
func _on_artifact_equipped(_artifact: Resource) -> void:
	if current_state == GameState.BOSS_FIGHT:
		exit_boss_fight()
```

This will call `exit_boss_fight()` → `get_tree().paused = false` + `boss_fight_ended.emit()`.

The order in `_on_artifact_equipped` for BossArena:
1. `artifact_equipped` signal fires
2. BossArena._on_artifact_equipped() → deactivate()
3. GameManager._on_artifact_equipped() → exit_boss_fight() → unpause

This is correct — arena deactivates before tree unpauses.

---

### Task 5: Verify wave system doesn't interfere during pause

**Files:**
- Verify: `Systems/Waves/WaveManager.gd:319-320`

During boss fight, tree is paused → WaveManager._process() stops → no spawns. When boss dies, `_boss_active = false` but tree stays paused → WaveManager still frozen. Only when tree unpauses (after chest pickup) does WaveManager resume and detect `_boss_dead`.

- [ ] **Step 1: Verify WaveManager._on_boss_defeated sets _boss_dead**

Line 762-764:
```gdscript
func _on_boss_defeated(_boss_name: String, _pos: Vector2) -> void:
	_boss_active = false
	_boss_dead = true
```

This fires during pause (BossManager has PROCESS_MODE_ALWAYS). WaveManager stores the state. When tree unpauses, `_process()` resumes, detects `_boss_dead`, advances sub_phase.

No changes needed.

---

### Task 6: Verify chest works during pause

**Files:**
- Verify: `Entities/Chest/Chest.gd`
- Modify: `Entities/Chest/Chest.gd` — may need `process_mode = PROCESS_MODE_ALWAYS`

Chest is spawned by `BossManager._defeat_boss()` → `ChestTracker.spawn_legendary_chest()`. At this point tree is paused. Chest needs to:
1. Be visible and collectible (body_entered signal)
2. Tween animation on open

Area2D `body_entered` signal fires during pause only if both bodies have process_mode that allows processing. Player has PROCESS_MODE_ALWAYS, but Chest has default process_mode → signal won't fire.

- [ ] **Step 1: Add process_mode to Chest**

In `Chest._ready()`, add at the top:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 16
	# ... rest of existing _ready()
```

This allows the chest to detect player collision and play its open tween during pause.

---

### Task 7: Ensure EnemyMeshManager stops during boss fight

**Files:**
- Verify: `Systems/EnemyMeshManager.gd:286`

During boss fight, tree is paused → EnemyMeshManager._process() stops → no enemy movement/spawning. Boss is rendered via GPU MultiMesh but its position is updated by BossManager (PROCESS_MODE_ALWAYS).

- [ ] **Step 1: Verify EnemyMeshManager does NOT have PROCESS_MODE_ALWAYS**

EnemyMeshManager should have default process_mode so it freezes during pause. Check that no code sets `process_mode = PROCESS_MODE_ALWAYS` on it.

The boss slot position update happens in BossManager._process() via `EnemyMeshManager.get_slot_pos()` — this is a READ, not a write. The boss movement is handled by... let me check.

Actually, looking at BossManager, it doesn't move the boss. The boss movement is handled by EnemyMeshManager._process() which moves all enemies including boss. If EnemyMeshManager is paused, the boss won't move.

We need the boss to keep moving during the fight. Solution: BossManager should update boss position directly, OR EnemyMeshManager boss slot should be updated separately.

- [ ] **Step 2: Add boss position update to BossManager._process()**

After `_check_boss_hp()`, add boss movement:

```gdscript
func _process(delta: float) -> void:
	if not _boss_active:
		return

	_boss_timer += delta

	_check_boss_hp()

	# Move boss toward player (since EnemyMeshManager is paused)
	var emm: EnemyMeshManager = EnemyMeshManager
	if _boss_slot_idx >= 0 and emm.is_slot_alive(_boss_mesh_key, _boss_slot_idx):
		var player := GameManager.get_player()
		if player:
			var boss_pos: Vector2 = emm.get_slot_pos(_boss_mesh_key, _boss_slot_idx)
			var dir: Vector2 = (player.global_position - boss_pos).normalized()
			var new_pos: Vector2 = boss_pos + dir * _boss_speed * delta
			emm.set_slot_pos(_boss_mesh_key, _boss_slot_idx, new_pos)
			_boss_pos = new_pos

	_boss_attack_timer -= delta
	if _boss_attack_timer <= 0.0:
		_boss_attack_timer = _cur_attack_interval
		_perform_boss_attack()

	_boss_minion_timer -= delta
	if _boss_minion_timer <= 0.0:
		_boss_minion_timer = _cur_minion_interval
		_spawn_boss_minions()
```

- [ ] **Step 3: Verify EnemyMeshManager has set_slot_pos() method**

If not, add it:

```gdscript
func set_slot_pos(mesh_key: StringName, idx: int, pos: Vector2) -> void:
	if not _slots.has(mesh_key):
		return
	var arr: Array = _slots[mesh_key]
	if idx < 0 or idx >= arr.size():
		return
	arr[idx]["pos"] = pos
```

---

### Task 8: Verify all enemy types freeze during boss fight

**Files:**
- Verify: `Systems/SwarmManager.gd:222`

SwarmManager and EnemyMeshManager both check `get_tree().paused` in `_process()`. When tree is paused, they freeze. Small/medium/big enemies all stop moving.

- [ ] **Step 1: Verify SwarmManager check**

Line 222: `if get_tree().paused or not GameManager.is_playing():` — this correctly freezes all SwarmManager enemies.

- [ ] **Step 2: Verify EnemyMeshManager check**

Line 286: `if get_tree().paused or not GameManager.is_playing()` — same, correct.

No changes needed for enemy freezing.

---

### Task 9: Verify spell systems freeze during boss fight

**Files:**
- Verify: spell behavior scripts

All spell behaviors check `get_tree().paused`:
- ElectricField, CycloneVortex, PoisonPool, RefractionBolt, SpiritOrb — all check paused
- OrbManager — checks paused

Player spells should still work (player has PROCESS_MODE_ALWAYS). Let me verify spell casting still works.

- [ ] **Step 1: Verify player spell casting works during pause**

Player._process() has PROCESS_MODE_ALWAYS → continues. Spell casting is triggered by player input → continues. Spell behaviors are child nodes of Player → their process_mode inherits from parent.

Wait — spell behaviors are added to `player.Spells` node. If Spells node has default process_mode, spell behaviors freeze. Need to check.

- [ ] **Step 2: Add process_mode to Spells node or spell behaviors**

Check if the Spells node (child of Player) has process_mode set. If not, spells will freeze during boss fight.

In Player._ready(), after setting process_mode, ensure Spells node also has it:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ... existing code ...
	if has_node("Spells"):
		$Spells.process_mode = Node.PROCESS_MODE_ALWAYS
```

Or alternatively, set process_mode on each spell behavior when it's added.

---

### Task 10: Test and verify complete flow

- [ ] **Step 1: Verify arena appears on boss spawn**

Start game → reach boss wave → verify:
- Dark circle overlay appears (visible inside, dark outside)
- Invisible wall blocks player from leaving
- Boss health bar appears
- All enemies freeze (except boss)
- Player can move and cast spells
- Boss moves toward player and attacks

- [ ] **Step 2: Verify boss defeat flow**

Kill boss → verify:
- Shockwave + flash effect
- Chest spawns at boss death position
- Arena stays active (dark overlay + wall still present)
- Enemies remain frozen
- Boss health bar dismisses

- [ ] **Step 3: Verify chest collection flow**

Walk to chest → verify:
- Artifact selection screen appears
- Arena still visible behind artifact screen
- Select artifact → artifact equipped
- Arena disappears
- Game unpauses
- All enemies resume movement
- Wave system resumes spawning

---

## File Change Summary

| File | Change | Lines |
|------|--------|-------|
| `Systems/BossArena.gd` | Add `process_mode`, connect `artifact_equipped`, disconnect `boss_fight_ended` | ~5 lines |
| `Autoload/GameManager.gd` | Pause/unpause tree in enter/exit_boss_fight | 2 lines |
| `Systems/BossManager.gd` | Add `process_mode`, add boss movement in `_process` | ~15 lines |
| `Entities/Player/Player.gd` | Add `process_mode` | 1 line |
| `UI/HUD.gd` | Add `process_mode` | 1 line |
| `UI/BossHealthBar.gd` | Add `process_mode` | 1 line |
| `Entities/Chest/Chest.gd` | Add `process_mode` | 1 line |
| `Systems/EnemyMeshManager.gd` | Add `set_slot_pos()` if missing | ~5 lines |
