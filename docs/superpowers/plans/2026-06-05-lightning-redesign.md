# Lightning Strike Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Lightning Strike to match Classic Arcane visual style, swap impact to a new BurstParticles2D-based scene, remove base chain mechanic (only mods/artifacts add chains), and refresh per-mod visuals.

**Architecture:** Five focused file changes plus one new scene. Bolt geometry gets end-fork branches and flicker in `LightningBolt.gd` (procedural `_draw()`). Impact gets a dedicated `lightning_impact.tscn` using the existing `BurstParticles2D` addon (3 child node groups: CoreFlash, Forks, Ring). `LightningBehavior.gd` swaps the pool key, applies per-mod visual params, and bumps Overcharge AOE. `LevelUpManager.gd` zeros out `chain_count_add` for L2/L4 and updates the two descriptions. Pool registration in `BurstEffectPool.gd` adds the new key.

**Tech Stack:** Godot 4.6.2, GDScript, BurstParticles2D addon, MultiMesh not affected, no new dependencies.

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `Scenes/lightning_impact.tscn` | **NEW** | BurstParticleGroup2D impact effect (CoreFlash + Forks + Ring) |
| `Systems/BurstEffectPool.gd` | Modify | Register `"lightning_impact"` in `_scene_map` + `_scale_map` |
| `Spells/visuals/LightningBolt.gd` | Modify | Add end-fork geometry, flicker, glow 18→24, lifetime 0.4→0.5 |
| `Spells/behaviors/LightningBehavior.gd` | Modify | `chain_count` 2→0 default, swap impact pool key, Chain Amplifier arc, Overcharge AOE 40→60, per-mod color/width params |
| `Systems/LevelUpManager.gd` | Modify | `lvl2.chain_count_add = 0`, `lvl4.chain_count_add = 0`, update L2/L4 descriptions |
| `Autoload/SettingsManager.gd` | NO CHANGE | (Russian strings unused at runtime) |

---

## Task 1: Create `Scenes/lightning_impact.tscn`

**Files:**
- Create: `Scenes/lightning_impact.tscn`

- [ ] **Step 1: Verify the addon paths are reachable**

Read these to confirm exact UIDs/path of the textures before authoring the scene:
- `res://addons/BurstParticles2D/BurstParticleGroup2D.gd`
- `res://addons/BurstParticles2D/BurstParticles2D.gd`
- `res://addons/BurstParticles2D/BurstParticles2D-demo/orb.png`
- `res://addons/BurstParticles2D/BurstParticles2D-demo/ring.png`

Use the existing `Scenes/death_cold.tscn` as a structural reference (sub_resource pattern, autostart=false, free_when_finished=true, modulate=Color(1,1,1,1)).

- [ ] **Step 2: Write the scene file**

Create `Scenes/lightning_impact.tscn` with this exact content (copy the structure from `Scenes/death_cold.tscn` and replace the per-child config). Three child nodes under one `BurstParticleGroup2D` root:

```ini
[gd_scene load_steps=8 format=3 uid="uid://bl1ghtningimpact"]

[ext_resource type="Script" path="res://addons/BurstParticles2D/BurstParticleGroup2D.gd" id="1_group"]
[ext_resource type="Script" path="res://addons/BurstParticles2D/BurstParticles2D.gd" id="2_burst"]
[ext_resource type="Texture2D" path="res://addons/BurstParticles2D/BurstParticles2D-demo/orb.png" id="3_orb"]
[ext_resource type="Texture2D" path="res://addons/BurstParticles2D/BurstParticles2D-demo/ring.png" id="4_ring"]

[sub_resource type="CanvasItemMaterial" id="Mat_additive"]
blend_mode = 1

[sub_resource type="Gradient" id="Grad_core"]
offsets = PackedFloat32Array(0, 0.4, 1)
colors = PackedColorArray(1, 1, 1, 1, 0.7, 0.85, 1, 0.6, 0.3, 0.5, 1, 0)

[sub_resource type="Curve" id="Curve_core_scale"]
_data = [Vector2(0, 0.4), 0.0, 0.0, 0, 0, Vector2(1, 0), -0.4, 0.0, 0, 0]
point_count = 2

[sub_resource type="Gradient" id="Grad_forks"]
offsets = PackedFloat32Array(0, 0.3, 1)
colors = PackedColorArray(0.6, 0.9, 1, 1, 1, 1, 1, 0.8, 0.3, 0.5, 1, 0)

[sub_resource type="Curve" id="Curve_fork_dist"]
_data = [Vector2(0, 0), 0.0, 80.0, 0, 0, Vector2(1, 35), 20.0, 0.0, 0, 0]
point_count = 2

[sub_resource type="Gradient" id="Grad_ring"]
offsets = PackedFloat32Array(0, 0.5, 1)
colors = PackedColorArray(0.4, 0.7, 1, 0.9, 0.6, 0.85, 1, 0.5, 0.3, 0.5, 1, 0)

[sub_resource type="Curve" id="Curve_ring_scale"]
_data = [Vector2(0, 0.2), 0.0, 0.0, 0, 0, Vector2(1, 0.8), 0.6, 0.0, 0, 0]
point_count = 2

[node name="LightningImpact" type="Node2D"]
script = ExtResource("1_group")
autostart = false
free_when_finished = true

[node name="CoreFlash" type="Node2D" parent="."]
material = SubResource("Mat_additive")
script = ExtResource("2_burst")
num_particles = 1
lifetime = 0.25
repeat = false
autostart = false
texture = ExtResource("3_orb")
image_scale = 0.4
gradient = SubResource("Grad_core")
distance = 0.0
scale_curve = SubResource("Curve_core_scale")

[node name="Forks" type="Node2D" parent="."]
material = SubResource("Mat_additive")
script = ExtResource("2_burst")
num_particles = 8
lifetime = 0.3
lifetime_randomness = 0.5
repeat = false
autostart = false
texture = ExtResource("3_orb")
image_scale = 0.08
image_scale_randomness = 0.4
gradient = SubResource("Grad_forks")
direction_rotation_randomness = 1.0
distance = 35.0
distance_randomness = 0.6
global_offset = true
distance_curve = SubResource("Curve_fork_dist")

[node name="Ring" type="Node2D" parent="."]
material = SubResource("Mat_additive")
script = ExtResource("2_burst")
num_particles = 1
lifetime = 0.35
repeat = false
autostart = false
texture = ExtResource("4_ring")
image_scale = 0.5
gradient = SubResource("Grad_ring")
distance = 0.0
scale_curve = SubResource("Curve_ring_scale")
```

Note: the `uid="uid://bl1ghtningimpact"` placeholder must be regenerated by Godot on first load — Godot will assign a real UID automatically. If the editor warns about the UID, save the scene in Godot to let it write a proper one.

- [ ] **Step 3: Validate scene loads in Godot**

Open Godot, run the project, then in Debugger → Remote → SceneTree verify `Scenes/lightning_impact.tscn` instantiates without errors. If the project reports script path errors, fix the `ext_resource` paths.

- [ ] **Step 4: Commit**

```bash
git add Scenes/lightning_impact.tscn
git commit -m "feat(lightning): add BurstParticles2D-based impact scene (fork burst)"
```

---

## Task 2: Register `lightning_impact` in `BurstEffectPool`

**Files:**
- Modify: `Systems/BurstEffectPool.gd:28` (scene_map) and `:46` (scale_map)

- [ ] **Step 1: Add `"lightning_impact"` to `_scene_map`**

In `Systems/BurstEffectPool.gd`, find the `_scene_map` dictionary (lines 21-38). Add a new entry after the existing `"lightning"` entry (line 28). New content of that block:

```gdscript
		"lightning": preload("res://Scenes/death_cold.tscn"),
		"lightning_impact": preload("res://Scenes/lightning_impact.tscn"),
		"bolt":      preload("res://Scenes/death_cold.tscn"),
```

- [ ] **Step 2: Add `"lightning_impact"` to `_scale_map`**

In `Systems/BurstEffectPool.gd`, find the `_scale_map` dictionary (lines 39-56). Add a new entry after the existing `"lightning"` entry (line 46). New content of that block:

```gdscript
		"lightning": 1.3,
		"lightning_impact": 1.0,
		"bolt":      0.6,
```

- [ ] **Step 3: Verify the cache key is also generated**

The existing `for key in _scene_map: _key_cache[key] = "burst_pool_%s" % key` loop (line 57-58) will automatically register `"burst_pool_lightning_impact"` in `_key_cache`. No additional change needed.

- [ ] **Step 4: Validate**

Run the project in Godot. Check Debugger → Errors for any preload errors. The new key should be usable from any caller.

- [ ] **Step 5: Commit**

```bash
git add Systems/BurstEffectPool.gd
git commit -m "feat(lightning): register lightning_impact in BurstEffectPool"
```

---

## Task 3: Update `LightningBolt.gd` — end forks, flicker, bigger glow, longer lifetime

**Files:**
- Modify: `Spells/visuals/LightningBolt.gd`

- [ ] **Step 1: Add new constants and state fields**

Replace the class header and the existing constants/fields with the new versions. Find lines 4-17 in `LightningBolt.gd` and replace the entire constant + field block:

```gdscript
class_name LightningBolt
extends Node2D

const POOL_SIZE: int = 30
const END_FORK_COUNT: int = 2
const END_FORK_LENGTH_RATIO: float = 0.3
const END_FORK_WIDTH_RATIO: float = 0.5
const FLICKER_TIMES: Array[float] = [0.15, 0.3]

var _points: PackedVector2Array = PackedVector2Array()
var _forks: Array[PackedVector2Array] = []
var _core_color: Color = Color(1.5, 1.5, 1.5)
var _bolt_color: Color = Color(0.5, 0.8, 1.0)
var _glow_color: Color = Color(0.3, 0.5, 1.0, 0.45)
var _lifetime: float = 0.5
var _age: float = 0.0
var _flicker_idx: int = 0
var _next_flicker_at: float = 0.15
var _core_width: float = 3.5
var _bolt_width: float = 10.0
var _glow_width: float = 24.0
var _branch_color: Color = Color(0.4, 0.7, 1.0)
var _branch_width: float = 5.0
var _active: bool = false
```

- [ ] **Step 2: Update `setup()` to generate end forks**

Replace the existing `setup()` method (lines 61-70) with the version below. The end-fork generation picks a "split zone" at the last 20-30% of segments and emits 2 forks branching from random points inside it.

```gdscript
func setup(source: Vector2, target: Vector2, segments: int, jitter: float) -> void:
	_points = PackedVector2Array()
	_points.append(source)
	var step := (target - source) / maxf(segments, 1)
	var perp := Vector2(-step.y, step.x).normalized()
	for i in range(1, segments):
		var p := source + step * i + perp * randf_range(-jitter, jitter)
		_points.append(p)
	_points.append(target)
	_generate_end_forks(source, target, segments, step)
	_flicker_idx = 0
	_next_flicker_at = FLICKER_TIMES[0] if FLICKER_TIMES.size() > 0 else _lifetime + 1.0
	queue_redraw()

func _generate_end_forks(source: Vector2, target: Vector2, segments: int, step: Vector2) -> void:
	_forks.clear()
	if segments < 3:
		return
	var split_start := int(segments * 0.7)
	var fork_length := segments * END_FORK_LENGTH_RATIO
	for _i in range(END_FORK_COUNT):
		var split_at: int = randi_range(split_start, segments - 1)
		var origin: Vector2 = _points[split_at]
		var tangent := (target - source).normalized()
		var sign: float = -1.0 if randf() < 0.5 else 1.0
		var perpendicular := Vector2(-tangent.y, tangent.x) * sign
		var fork_angle := randf_range(0.4, 0.9) * sign
		var fork_dir := (tangent * cos(fork_angle) + perpendicular * sin(fork_angle)).normalized()
		var fork: PackedVector2Array = PackedVector2Array()
		fork.append(origin)
		var fork_segments: int = maxi(int(fork_length), 2)
		for j in range(1, fork_segments + 1):
			var p: Vector2 = origin + fork_dir * step.length() * float(j)
			var perp2 := Vector2(-fork_dir.y, fork_dir.x).normalized()
			p += perp2 * randf_range(-step.length() * 0.4, step.length() * 0.4)
			fork.append(p)
		_forks.append(fork)
```

- [ ] **Step 3: Update `_draw()` to render forks**

Replace `_draw()` (lines 72-79) with:

```gdscript
func _draw() -> void:
	if _points.size() < 2:
		return
	var alpha := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	var flicker := 0.85 + randf() * 0.15
	draw_polyline(_points, Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * alpha), _glow_width, true)
	draw_polyline(_points, Color(_bolt_color.r, _bolt_color.g, _bolt_color.b, alpha * flicker), _bolt_width, true)
	draw_polyline(_points, Color(_core_color.r, _core_color.g, _core_color.b, alpha * flicker), _core_width, true)
	for fork in _forks:
		draw_polyline(fork, Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * alpha * 0.6), _glow_width * END_FORK_WIDTH_RATIO, true)
		draw_polyline(fork, Color(_bolt_color.r, _bolt_color.g, _bolt_color.b, alpha * flicker * 0.7), _bolt_width * END_FORK_WIDTH_RATIO, true)
```

- [ ] **Step 4: Update `_process()` to drive flicker**

Replace `_process()` (lines 81-86) with:

```gdscript
func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		_release()
		return
	if _flicker_idx < FLICKER_TIMES.size() and _age >= _next_flicker_at:
		_apply_flicker()
		_flicker_idx += 1
		if _flicker_idx < FLICKER_TIMES.size():
			_next_flicker_at = FLICKER_TIMES[_flicker_idx]
	queue_redraw()

func _apply_flicker() -> void:
	if _points.size() < 4:
		return
	var start := int(_points.size() * 0.6)
	for i in range(start, _points.size()):
		var prev: Vector2 = _points[i - 1]
		var nxt: Vector2 = _points[i + 1] if i + 1 < _points.size() else _points[i]
		var dir := (nxt - prev).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var jitter_strength: float = 18.0
		_points[i] += perp * randf_range(-jitter_strength, jitter_strength)
```

- [ ] **Step 5: Update `_release()` to clear forks**

Replace `_release()` (lines 88-92) with:

```gdscript
func _release() -> void:
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_points = PackedVector2Array()
	_forks.clear()
```

- [ ] **Step 6: Validate visual**

Run the project. Cast Lightning Strike in-game and verify:
- The bolt has 2 short branches near the impact end (last 30% of the bolt)
- The bolt "jitters" visibly mid-life (1-2 micro-reshuffles)
- Glow is more present than before
- Bolt stays for ~0.5s (slightly longer than before)

If the bolt looks too "noisy", reduce `END_FORK_COUNT` to 1 (line 7 constant) and `FLICKER_TIMES` to just `[0.25]`.

- [ ] **Step 7: Commit**

```bash
git add Spells/visuals/LightningBolt.gd
git commit -m "feat(lightning): end-fork branches, flicker, wider glow, longer lifetime"
```

---

## Task 4: Update `LightningBehavior.gd` — chain_count=0, swap impact, per-mod visuals, Overcharge AOE

**Files:**
- Modify: `Spells/behaviors/LightningBehavior.gd`

This task is larger because it touches many code paths. Sub-steps below.

- [ ] **Step 4.1: Default `chain_count` to 0**

In `LightningBehavior.gd`, find the `@export` declarations at the top of the file (lines 4-9). Change:

```gdscript
@export var strike_range: float = 550.0
@export var chain_count: int = 2
@export var chain_range: float = 150.0
@export var chain_damage_mult: float = 0.5
@export var bolt_segments: int = 12
@export var bolt_jitter: float = 30.0
```

To:

```gdscript
@export var strike_range: float = 550.0
@export var chain_count: int = 0
@export var chain_range: float = 150.0
@export var chain_damage_mult: float = 0.5
@export var bolt_segments: int = 12
@export var bolt_jitter: float = 30.0
```

- [ ] **Step 4.2: Remove the `disable_chains` workaround**

In `LightningBehavior.gd`, find `cast()` (lines 11-75). Replace lines 33-38:

```gdscript
	var is_overcharge := spell.active_modification and spell.active_modification.mod_name == "Overcharge"
	var has_explode_mod := spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.EXPLODE
	var disable_chains := false
	if spell.active_modification and spell.active_modification.damage_multiplier >= 2.0:
		if spell.active_modification.chain_count_add == 0 and not has_explode_mod:
			disable_chains = true
```

With:

```gdscript
	var is_overcharge := spell.active_modification and spell.active_modification.mod_name == "Overcharge"
	var has_explode_mod := spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.EXPLODE
```

- [ ] **Step 4.3: Bump Overcharge AOE radius**

In `LightningBehavior.gd`, find the primary damage call (line 44-45):

```gdscript
		SwarmManager.damage_area(strike_pos, 40.0, damage)
		EnemyMeshManager.damage_area(strike_pos, 40.0, damage)
```

Wrap the radius in an Overcharge check:

```gdscript
		var primary_radius: float = 60.0 if is_overcharge else 40.0
		SwarmManager.damage_area(strike_pos, primary_radius, damage)
		EnemyMeshManager.damage_area(strike_pos, primary_radius, damage)
```

- [ ] **Step 4.4: Swap impact pool key from `"lightning"` to `"lightning_impact"`**

In `LightningBehavior.gd`, find line 55:

```gdscript
		BurstEffectPool.spawn("lightning", strike_pos, spell_color)
```

Replace with:

```gdscript
		var impact_scale: float = 1.5 if is_overcharge else 1.0
		BurstEffectPool.spawn("lightning_impact", strike_pos, spell_color, impact_scale)
```

Note: `BurstEffectPool.spawn` currently does not accept a scale parameter. We must extend the signature. See Step 4.7 below.

- [ ] **Step 4.5: Pass scale into `BurstEffectPool.spawn`**

In `Systems/BurstEffectPool.gd`, find the `spawn()` function signature (line 72):

```gdscript
static func spawn(effect_type: String, pos: Vector2, color: Color = Color.WHITE) -> void:
```

Replace with:

```gdscript
static func spawn(effect_type: String, pos: Vector2, color: Color = Color.WHITE, scale_mult_override: float = 1.0) -> void:
```

Then, in the same function, find the scale application (around line 114):

```gdscript
	player.play(scene, effect_type, pos, scale_mult, color)
```

Replace with:

```gdscript
	var final_scale: float = scale_mult * scale_mult_override
	player.play(scene, effect_type, pos, final_scale, color)
```

- [ ] **Step 4.6: Update end-of-strike impact spawn in `_spawn_single_strike_visuals`**

In `LightningBehavior.gd`, find line 185:

```gdscript
		BurstEffectPool.spawn("lightning", end, spell_color)
```

Replace with:

```gdscript
		var end_impact_scale: float = 1.5 if is_overcharge else 1.0
		BurstEffectPool.spawn("lightning_impact", end, spell_color, end_impact_scale)
```

- [ ] **Step 4.7: Apply per-mod visual parameters in `_spawn_single_strike_visuals`**

In `LightningBehavior.gd`, find `_spawn_single_strike_visuals()` (lines 145-185). We will add three branches based on `spell.active_modification.mod_name` and inject the Chain Amplifier persistent arc.

Replace the function body (everything after `func _spawn_single_strike_visuals(...)` until the end of the function) with:

```gdscript
	var is_chain_amp := spell.active_modification and spell.active_modification.mod_name == "Chain Amplifier"
	var is_rapid := spell.active_modification and spell.active_modification.mod_name == "Rapid Bolt"

	for i in range(0, segments.size() - 1, 2):
		var start := segments[i]
		var end := segments[i + 1]
		var is_main_bolt := i == 0
		var is_chain_segment := not is_main_bolt

		var bolt := LightningBolt.acquire()

		if is_primary and is_main_bolt:
			if is_overcharge:
				bolt._bolt_color = Color(1.4, 1.3, 0.9)
				bolt._glow_color = Color(1.0, 0.95, 0.7, 0.55)
				bolt._core_color = Color(1.6, 1.6, 1.5)
				bolt._lifetime = 0.55
				bolt._glow_width = 34.0
				bolt._bolt_width = 24.0
				bolt._core_width = 8.4
			elif is_rapid:
				bolt._bolt_color = Color(0.4, 1.0, 1.4)
				bolt._glow_color = Color(0.2, 0.5, 0.9, 0.4)
				bolt._core_color = Color(1.2, 1.2, 1.2)
				bolt._lifetime = 0.25
				bolt._glow_width = 14.0
				bolt._bolt_width = 7.0
				bolt._core_width = 2.5
			else:
				bolt._bolt_color = spell_color
				bolt._glow_color = Color(spell_color.r * 0.5, spell_color.g * 0.5, spell_color.b, 0.35)
				bolt._core_color = Color(1.3, 1.3, 1.3)
				bolt._lifetime = 0.4
				bolt._glow_width = 18.0
				bolt._bolt_width = 10.0
				bolt._core_width = 3.5
			bolt.setup(start, end, bolt_segments, bolt_jitter)
		elif is_main_bolt:
			bolt._bolt_color = Color(spell_color.r * 0.8, spell_color.g * 0.8, spell_color.b, 0.95)
			bolt._glow_color = Color(spell_color.r * 0.4, spell_color.g * 0.4, spell_color.b, 0.25)
			bolt._core_color = Color(1.2, 1.2, 1.2)
			bolt._lifetime = 0.35
			bolt._glow_width = 12.0
			bolt._bolt_width = 7.0
			bolt._core_width = 2.5
			bolt.setup(start, end, bolt_segments, bolt_jitter * 0.8)
		else:
			if is_chain_amp:
				bolt._bolt_color = Color(0.3, 1.0, 1.2)
				bolt._glow_color = Color(0.2, 0.6, 0.9, 0.5)
			else:
				bolt._bolt_color = Color(spell_color.r * 0.7, spell_color.g * 0.7, spell_color.b, 0.9)
				bolt._glow_color = Color(spell_color.r * 0.3, spell_color.g * 0.3, spell_color.b, 0.2)
			bolt._core_color = Color(1.0, 1.0, 1.0)
			bolt._lifetime = 0.3
			bolt._glow_width = 14.0
			bolt._bolt_width = 5.0
			bolt._core_width = 1.5
			bolt.setup(start, end, 8, bolt_jitter * 0.6)

		if is_chain_amp and is_chain_segment:
			_spawn_chain_arc(start, end)

		var end_impact_scale: float = 1.5 if is_overcharge else 1.0
		BurstEffectPool.spawn("lightning_impact", end, spell_color, end_impact_scale)
```

- [ ] **Step 4.8: Add the `_spawn_chain_arc` helper**

Append this new method to the bottom of `LightningBehavior.gd` (after `_get_secondary_color`):

```gdscript
func _spawn_chain_arc(start: Vector2, end: Vector2) -> void:
	var arc := LightningBolt.acquire()
	arc._bolt_color = Color(0.3, 1.0, 1.2, 0.4)
	arc._glow_color = Color(0.3, 1.0, 1.2, 0.0)
	arc._core_color = Color(0.3, 1.0, 1.2, 0.0)
	arc._lifetime = 0.2
	arc._glow_width = 4.0
	arc._bolt_width = 2.0
	arc._core_width = 0.0
	arc.setup(start, end, 6, 12.0)
```

- [ ] **Step 4.9: Validate**

Run the project in Godot. Test:
- Cast Lightning Strike without mods → 1 hit, no chains, impact shows white core + forks + ring
- Pick up Chain Amplifier mod → cast lightning → main hit + 8 chain hits, chain bolts are cyan with thin arc connectors
- Pick up Overcharge mod → cast lightning → 1 big hit with AOE 60, no chains, bolt is warm-white + thicker + longer glow
- Pick up Rapid Bolt mod → cast lightning → bright cyan bolt, thin and fast

If the chain arc looks too "thin" or invisible, raise `arc._bolt_width` from 2.0 to 3.0.

- [ ] **Step 4.10: Commit**

```bash
git add Spells/behaviors/LightningBehavior.gd Systems/BurstEffectPool.gd
git commit -m "feat(lightning): per-mod visuals, impact scene swap, AOE bump, chain arcs"
```

---

## Task 5: Update `LevelUpManager.gd` — remove `chain_count_add`, update L2/L4 descriptions

**Files:**
- Modify: `Systems/LevelUpManager.gd` (lines 484, 496, 485, 497)

- [ ] **Step 5.1: Update L2 (`lvl2`)**

In `Systems/LevelUpManager.gd`, find the L2 block (lines 481-485):

```gdscript
	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.chain_count_add = 2
	lvl2.description = "Damage +25%, +2 chain targets"
```

Replace with:

```gdscript
	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.chain_count_add = 0
	lvl2.description = "Damage +25%"
```

- [ ] **Step 5.2: Update L4 (`lvl4`)**

In `Systems/LevelUpManager.gd`, find the L4 block (lines 493-497):

```gdscript
	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.chain_count_add = 3
	lvl4.description = "Damage +80%, +3 chain targets"
```

Replace with:

```gdscript
	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.chain_count_add = 0
	lvl4.description = "Damage +80%"
```

- [ ] **Step 5.3: Validate**

Run the project. Level up Lightning Strike to L2 → description says "Damage +25%" only (no chain mention). Level to L4 → "Damage +80%" only. Cast at L1-L5: only 1 enemy hit (no chains).

- [ ] **Step 5.4: Commit**

```bash
git add Systems/LevelUpManager.gd
git commit -m "feat(lightning): remove base chain from L2/L4, update descriptions"
```

---

## Task 6: End-to-end visual verification

**Files:** none (verification only)

- [ ] **Step 1: Cold start Godot project**

Open Godot, reload the project (Ctrl+Shift+R or Project → Reload Current Project) to ensure no stale references.

- [ ] **Step 2: Smoke test (no mods)**

Start a run, cast Lightning Strike 5+ times. Verify:
- 1 enemy hit per cast (no chain)
- Bolt has 2 small end-fork branches near the target
- Impact shows white core flash + 6-8 short fork particles radiating outward + faint expanding ring
- No errors in Debugger

- [ ] **Step 3: Chain Amplifier test**

Pick up the Chain Amplifier mod. Cast Lightning Strike 5+ times. Verify:
- 1 primary hit + 8 chain hits (to nearest unhit enemies)
- Chain bolts are cyan-electric blue
- Thin persistent arc (200ms) connects the main strike to each chain target
- No errors

- [ ] **Step 4: Overcharge test**

Start a new run, pick up Overcharge. Cast Lightning Strike 5+ times in a crowd. Verify:
- 1 big hit, no chains
- Bolt is thicker (~2×) and warm-white tinted
- Impact is ~1.5× bigger (visible scaling)
- Damage AOE covers ~60px radius (visibly wider than base 40)
- No errors

- [ ] **Step 5: Rapid Bolt test**

Start a new run, pick up Rapid Bolt. Cast Lightning Strike 10+ times. Verify:
- Bolts are bright electric-cyan
- Lifetime is shorter (~0.25s) — feels snappy
- Bolts are thinner than base
- No errors

- [ ] **Step 6: Level progression test**

In a run, level Lightning Strike to L5 without any chain mods. Verify:
- L1-L5 all hit 1 enemy only
- L2 shows "Damage +25%" (no chain mention)
- L4 shows "Damage +80%" (no chain mention)
- L3 and L5 show their original descriptions

- [ ] **Step 7: Artifact cross-check (Storm Capacitor)**

If `Storm Capacitor` artifact is in the run, verify it still adds +1 chain (unchanged behavior). The artifact's effect goes through `ArtifactManager.get_chain_count_add`, which adds to the base — should still work since we only removed `chain_count_add` from level data, not from artifacts.

- [ ] **Step 8: Performance check**

Run the profiler (ActionProfiler CSV in `user://`). Confirm no new red flags:
- `vfx/burst_pool_lightning_impact` should be the new hot entry (not `lightning`)
- Spawn rate should be similar to before (1 impact per strike + chain impacts only when mod active)
- No "max per type per second" rejections

- [ ] **Step 9: Commit any final visual tuning**

If any visual tweak was made (e.g., arc width, fork count, color), commit it:

```bash
git add Spells/visuals/LightningBolt.gd Spells/behaviors/LightningBehavior.gd
git commit -m "tune(lightning): visual adjustments from end-to-end verification"
```

---

## Self-Review

**Spec coverage:**
- ✅ §1 Visual style: Classic Arcane (palette) — applied in Task 3 (bolt colors), Task 4 (per-mod colors)
- ✅ §2 Main Bolt (end forks, flicker, glow 18→24, lifetime 0.4→0.5) — Task 3
- ✅ §3 Impact Effect (new `lightning_impact.tscn`, pool registration) — Task 1, Task 2
- ✅ §4 Chain removal from base (chain_count=0, level_data zeroed, disable_chains removed) — Task 4.1, 4.2, Task 5
- ✅ §5.1 Chain Amplifier (cyan tint, persistent arc) — Task 4.7, 4.8
- ✅ §5.2 Overcharge (AOE 40→60, thicker bolt, warm-white tint, impact ×1.5) — Task 4.3, 4.4, 4.5, 4.6, 4.7
- ✅ §5.3 Rapid Bolt (cyan, thinner, faster) — Task 4.7
- ✅ §6 Localization (no new keys, only English in code) — Task 5
- ✅ §7 File map (all 5 files + 1 new scene) — Tasks 1-5
- ✅ §8 Risks (low geometry, lightweight particles) — design preserved

**Placeholder scan:** No TBDs, no "fill in later". All code blocks complete. Reuses specific constants (`END_FORK_COUNT`, `FLICKER_TIMES`) defined in same task.

**Type consistency:** `_forks` typed as `Array[PackedVector2Array]`; consumed in `_draw()` and cleared in `_release()`. `_spawn_chain_arc` reuses `LightningBolt.acquire()` and the same field setters. `BurstEffectPool.spawn` signature extended (Task 4.5) and all callers updated (Tasks 4.4, 4.6).

No issues found. Plan ready for execution.
