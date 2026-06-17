# 8 Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 7 gameplay/visual issues from spec `2026-06-05-8-improvements-design.md` (FireBreath particles, halo sync, Inner Power init, Cyclone Twin, Needle Frost freeze, Magnet filter, Phase colors).

**Architecture:** Minimal-invasive GDScript edits in 14 existing files + 1 scene node addition. No refactors, no new systems — only parameter tuning, group-based filters, and shader fragment additions. Verification by visual inspection in Godot Editor (no unit tests for visual changes).

**Tech Stack:** Godot 4.6.2, GDScript, GPUParticles2D, MultiMesh + custom shader, CanvasModulate.

---

## File Structure

**Modified files (14):**
- `Spells/visuals/FireBreathPuff.gd` — Group A (particles + halo)
- `Autoload/GameManager.gd` — Group B (enter_endless)
- `Entities/Player/Player.gd` — Group B (comment)
- `Spells/visuals/CycloneVortex.gd` — Group C (2-sprite waltz)
- `Systems/LevelUpManager.gd` — Group C (damage_multiplier 1.5→1.7)
- `Entities/Enemies/BaseEnemy.gd` — Group D-A (anim.stop on freeze)
- `Systems/EnemyMeshManager.gd` — Group D-B (custom_data for shader)
- `Systems/SwarmManager.gd` — Group D-D (mirror EnemyMeshManager)
- `Systems/SwarmShader.gdshader` — Group D-C (ice overlay + frozen frame)
- `Entities/Pickups/CurrencyOrb.gd` — Group E (magnet_target)
- `Entities/Pickups/HealthHeart.gd` — Group E (magnet_skip)
- `Entities/Pickups/PowerUpPickup.gd` — Group E (magnet_skip)
- `Main.gd` — Group F (palette + CanvasModulate)
- `Main.tscn` — Group F (CanvasModulate node)

**No new files. No deleted files. No git history exists (project is not a git repo), so commits use message-only convention.**

---

## Task 1: FireBreath Dragon Breath — particles stay on screen + halo sync

**Files:**
- Modify: `Spells/visuals/FireBreathPuff.gd:10` (add field)
- Modify: `Spells/visuals/FireBreathPuff.gd:359` (use field in halo)
- Modify: `Spells/visuals/FireBreathPuff.gd:432-445` (reset + Dragon Breath branch)

- [ ] **Step 1: Add `_visual_range_mult` field near `_vel_ratio` (line 10)**

In `Spells/visuals/FireBreathPuff.gd`, find line 10 (the `_vel_ratio` declaration). Add a new field directly after it:

```gdscript
var _vel_ratio: float = 1.0
var _visual_range_mult: float = 1.0
```

- [ ] **Step 2: Modify `_update_halo()` to use `_visual_range_mult` (line 359)**

Find the line in `_update_halo()`:
```gdscript
var range: float = _cone_range * _vel_ratio * lerp(0.1, 1.0, glow_progress)
```

Replace with:
```gdscript
var range: float = _cone_range * _vel_ratio * _visual_range_mult * lerp(0.1, 1.0, glow_progress)
```

- [ ] **Step 3: Reset `_visual_range_mult` in `apply_modifier()` reset block (line 432-434)**

Find the reset block in `apply_modifier()` (the section that runs before checking mod_name). Add `_visual_range_mult = 1.0` to it. The exact existing code may be:

```gdscript
func apply_modifier(mod_name: String) -> void:
    _vel_ratio = 1.0
    # ... other resets
```

Add this line alongside the other resets:
```gdscript
_vel_ratio = 1.0
_visual_range_mult = 1.0
```

- [ ] **Step 4: Set `_visual_range_mult = 1.4` in Dragon Breath branch (lines 435-445)**

Find the Dragon Breath branch:
```gdscript
if mod_name == "Dragon Breath":
    _base_vels[i] = {min = orig_vels_min[i] * 1.4, max = orig_vels_max[i] * 1.4}
    _base_lifetimes[i] = orig_lifetimes[i] * 1.5
    layers[i].amount = int(orig_amounts[i] * 1.5)
    mat.damping_min/max = orig_damp_min/max[i] * 0.7
```

Replace with (removes lifetime ×1.5 and damping ×0.7 that made particles fly off-screen):
```gdscript
if mod_name == "Dragon Breath":
    _base_vels[i] = {min = orig_vels_min[i] * 1.4, max = orig_vels_max[i] * 1.4}
    layers[i].amount = int(orig_amounts[i] * 1.5)
```

Then add (after the for-loop that processes layers, before the end of the if-block):
```gdscript
    _visual_range_mult = 1.4
```

The exact placement: find the line `if mod_name == "Dragon Breath":` and add `_visual_range_mult = 1.4` as the LAST line inside that if-block (after all layer processing). The structure becomes:

```gdscript
if mod_name == "Dragon Breath":
    for i in range(layers.size()):
        _base_vels[i] = {min = orig_vels_min[i] * 1.4, max = orig_vels_max[i] * 1.4}
        layers[i].amount = int(orig_amounts[i] * 1.5)
    _visual_range_mult = 1.4
```

- [ ] **Step 5: Verify by running Godot**

Open Godot Editor → Project → Reload Current Project (Ctrl+Shift+R). Check the Output panel for any script errors related to `FireBreathPuff.gd`. If no errors, proceed.

- [ ] **Step 6: Manual visual check**

Start a run, get the Fire Breath spell, then pick up the Dragon Breath modification (3rd mod). Cast the breath. Verify:
- Particles stay within ~2× cone_range (not flying off-screen)
- Halo size grows visibly (1.4× larger) and matches where particles end
- Game does not crash

---

## Task 2: Inner Power apply_to_player in enter_endless

**Files:**
- Modify: `Autoload/GameManager.gd:149-152`

- [ ] **Step 1: Add apply_to_player call to enter_endless**

Open `Autoload/GameManager.gd`. Find lines 149-152:
```gdscript
func enter_endless() -> void:
    _endless_mode = true
    current_state = GameState.PLAYING
    get_tree().paused = false
```

Replace with:
```gdscript
func enter_endless() -> void:
    _endless_mode = true
    current_state = GameState.PLAYING
    get_tree().paused = false
    var player := get_player()
    if player:
        UpgradeManager.apply_to_player(player)
```

- [ ] **Step 2: Add comment in Player._ready()**

Open `Entities/Player/Player.gd`. Find lines 22-28:
```gdscript
func _ready() -> void:
    add_to_group("player")
    if not stats:
        stats = PlayerStats.new()
    stats.current_hp = stats.max_hp
    stats.current_level = stats.starting_level
    stats.current_xp = 0.0
```

Replace with (adds explanatory comment):
```gdscript
func _ready() -> void:
    add_to_group("player")
    # NOTE: stats are overwritten in GameManager.start_game() / enter_endless() → apply_to_player()
    # This default init is for first-frame rendering before apply_to_player runs
    if not stats:
        stats = PlayerStats.new()
    stats.current_hp = stats.max_hp
    stats.current_level = stats.starting_level
    stats.current_xp = 0.0
```

- [ ] **Step 3: Verify by running Godot**

Reload project. Check Output for parse errors. Should compile clean.

- [ ] **Step 4: Manual verification (full run cycle)**

1. Start the game
2. Open Inner Power screen (✦ button on main menu)
3. Buy 1-2 upgrades (e.g., max_hp, move_speed)
4. Start a run, note the stat values (HP bar should show higher than 100, movement should be faster)
5. Die or finish the run
6. On Game Over / Victory screen, click "Endless" (if available) or restart
7. Verify Inner Power bonuses still apply on the new run

If the bonuses don't appear after Endless entry, the fix didn't work — re-check step 1.

---

## Task 3: Cyclone Twin Cyclone — 2 vortexes waltzing

**Files:**
- Modify: `Spells/visuals/CycloneVortex.gd:19-50` (sprite pair + orbit fields)
- Modify: `Spells/visuals/CycloneVortex.gd:109-112` (orbit logic in _process)
- Modify: `Spells/visuals/CycloneVortex.gd:157-163` (damage in 2 points)
- Modify: `Spells/visuals/CycloneVortex.gd:189-195` (remove _draw_twin or simplify)
- Modify: `Systems/LevelUpManager.gd:584` (damage_multiplier 1.5→1.7)

- [ ] **Step 1: Replace `_sprite` with `_sprite_a` and `_sprite_b` (lines 19-23)**

Open `Spells/visuals/CycloneVortex.gd`. Find the field declaration block (around lines 19-23):
```gdscript
var _sprite: Sprite2D = null
# (other fields)
```

Replace `_sprite` with two sprite fields. Exact replacement:
```gdscript
var _sprite_a: Sprite2D = null
var _sprite_b: Sprite2D = null
```

- [ ] **Step 2: Add orbit fields (lines 31-33)**

Find:
```gdscript
var _twin_offset: float = 40.0
```

Replace with:
```gdscript
var _twin_orbit_phase: float = 0.0
var _twin_orbit_radius: float = 60.0
```

- [ ] **Step 3: Create 2 sprites in `_ready()` (lines 43-50)**

Find `_ready()` and the existing sprite creation. Typical code:
```gdscript
func _ready() -> void:
    _sprite = Sprite2D.new()
    _sprite.texture = preload("res://Sprites/cyclone_pix.png")
    add_child(_sprite)
```

Replace with:
```gdscript
func _ready() -> void:
    _sprite_a = Sprite2D.new()
    _sprite_a.texture = preload("res://Sprites/cyclone_pix.png")
    add_child(_sprite_a)
    _sprite_b = Sprite2D.new()
    _sprite_b.texture = preload("res://Sprites/cyclone_pix.png")
    _sprite_b.modulate = Color(1.2, 1.2, 1.2, 1.0)
    add_child(_sprite_b)
```

Note: If `_sprite` is referenced elsewhere in `_ready()` (e.g., `_sprite.rotation = 0`), add `_sprite_a.rotation = 0` similarly.

- [ ] **Step 4: Update `_process()` for 2D orbit (lines 109-112)**

Find:
```gdscript
func _process(delta: float) -> void:
    if _is_twin:
        _twin_phase += _rotation_speed * delta
        var perp := Vector2(-_direction.y, _direction.x)
        var off1 := perp * _twin_offset * Vector2(cos(_twin_phase), sin(_twin_phase)).x
```

Replace with:
```gdscript
func _process(delta: float) -> void:
    if _is_twin:
        _twin_orbit_phase += _rotation_speed * delta * 1.5
        var offset_a := Vector2(cos(_twin_orbit_phase), sin(_twin_orbit_phase)) * _twin_orbit_radius
        var offset_b := -offset_a
        _sprite_a.position = offset_a
        _sprite_b.position = offset_b
        _sprite_a.rotation += _rotation_speed * delta
        _sprite_b.rotation -= _rotation_speed * delta
    else:
        if _sprite_a:
            _sprite_a.rotation += _rotation_speed * delta
```

If the existing code continues with `_sprite.position` or similar single-sprite references, remove them.

- [ ] **Step 5: Update `_tick_damage()` for 2 damage points (lines 157-163)**

Find:
```gdscript
func _tick_damage() -> void:
    if _is_twin:
        var perp := Vector2(-_direction.y, _direction.x)
        var off1 := perp * _twin_offset * Vector2(cos(_twin_phase), sin(_twin_phase)).x
        var pos1 := global_position + off1
        var pos2 := global_position - off1
        SwarmManager.damage_area(pos1, _current_radius * 0.5, _damage)
        EnemyMeshManager.damage_area(pos1, _current_radius * 0.5, _damage)
        SwarmManager.damage_area(pos2, _current_radius * 0.5, _damage)
        EnemyMeshManager.damage_area(pos2, _current_radius * 0.5, _damage)
```

Replace with:
```gdscript
func _tick_damage() -> void:
    if _is_twin:
        var pos_a: Vector2 = global_position + _sprite_a.position
        var pos_b: Vector2 = global_position + _sprite_b.position
        var r: float = _current_radius * 0.5
        SwarmManager.damage_area(pos_a, r, _damage)
        EnemyMeshManager.damage_area(pos_a, r, _damage)
        SwarmManager.damage_area(pos_b, r, _damage)
        EnemyMeshManager.damage_area(pos_b, r, _damage)
    else:
        SwarmManager.damage_area(global_position, _current_radius, _damage)
        EnemyMeshManager.damage_area(global_position, _current_radius, _damage)
```

- [ ] **Step 6: Remove or simplify `_draw_twin()` (lines 189-195)**

Find `_draw_twin()` function. The current implementation draws 2 proxy circles. Since we now have 2 actual sprites, remove the entire function:

```gdscript
func _draw_twin() -> void:
    # DELETE THIS FUNCTION
    pass
```

If the function body contains draw_circle calls, delete the entire function. The actual sprites handle rendering now.

- [ ] **Step 7: Update damage_multiplier in LevelUpManager (line 584)**

Open `Systems/LevelUpManager.gd`. Find line 584:
```gdscript
mod_twin.damage_multiplier = 1.5
```

Replace with:
```gdscript
mod_twin.damage_multiplier = 1.7
```

- [ ] **Step 8: Verify by running Godot**

Reload project. Check Output for parse errors. Common issues:
- "Identifier '_sprite' not declared" → missed replacing some reference
- "Identifier '_twin_phase' not declared" → same
- "Identifier '_twin_offset' not declared" → same

If any error, search the file for the old identifier name and replace with new.

- [ ] **Step 9: Manual visual check**

Start a run, get Cyclone spell, pick up Twin Cyclone modification (3rd mod). Cast and verify:
- 2 visible vortex sprites spinning around a common center
- They orbit each other (counter-rotating spirals)
- Damage hits enemies in BOTH vortex positions, not just one
- Single Cyclone (without mod) still works normally

---

## Task 4: Needle Frost — BaseEnemy animation stop on freeze

**Files:**
- Modify: `Entities/Enemies/BaseEnemy.gd:202-220`

- [ ] **Step 1: Update slow block in _physics_process**

Open `Entities/Enemies/BaseEnemy.gd`. Find lines 202-220 (the slow block in `_physics_process`):

```gdscript
if _slow_timer > 0.0:
    _slow_timer -= _delta
    if _slow_timer > 2.0:
        slow_mult = 0.0
    elif _slow_timer > 0.0:
        slow_mult = 1.0 - _slow_timer / 2.0
    if _anim and _hit_flash_timer <= 0.0:
        var freeze: float = minf(_slow_timer / 4.0, 1.0)
        _anim.modulate = Color(
            lerpf(_color_variant.r, 0.65, freeze),
            lerpf(_color_variant.g, 0.85, freeze),
            lerpf(_color_variant.b, 1.0, freeze),
            1.0
        )
        _anim.speed_scale = maxf(1.0 - freeze, 0.0)
elif _anim and _hit_flash_timer <= 0.0:
    _anim.modulate = _color_variant
    _anim.speed_scale = 1.0
```

Replace with:
```gdscript
if _slow_timer > 0.0:
    _slow_timer -= _delta
    if _slow_timer > 2.0:
        slow_mult = 0.0
    elif _slow_timer > 0.0:
        slow_mult = 1.0 - _slow_timer / 2.0
    if _anim and _hit_flash_timer <= 0.0:
        var freeze: float = minf(_slow_timer / 4.0, 1.0)
        if _slow_timer > 2.0:
            if _anim.is_playing():
                _anim.stop()
                _anim.frame = 0
            _anim.speed_scale = 0.0
            _anim.modulate = Color(0.65, 0.85, 1.0, 1.0)
        else:
            _anim.speed_scale = 0.0
            _anim.modulate = Color(
                lerpf(_color_variant.r, 0.65, freeze),
                lerpf(_color_variant.g, 0.85, freeze),
                lerpf(_color_variant.b, 1.0, freeze),
                1.0
            )
elif _anim and _hit_flash_timer <= 0.0:
    if not _anim.is_playing():
        _anim.play("walk")
    _anim.modulate = _color_variant
    _anim.speed_scale = 1.0
```

- [ ] **Step 2: Verify and test**

Reload project. Start a run, get Needle spell, pick up Frost Shard modification. Stab an enemy and verify:
- Enemy animation STOPS completely (no walking animation playing)
- Enemy frame is locked at frame 0
- Enemy has blue tint (Color(0.65, 0.85, 1.0, 1.0))
- After thaw (~2s), animation resumes walking

---

## Task 5: Needle Frost — EnemyMeshManager custom_data

**Files:**
- Modify: `Systems/EnemyMeshManager.gd:107-108` (enable use_custom_data)
- Modify: `Systems/EnemyMeshManager.gd:574-587` (write custom_data in _update_type)

- [ ] **Step 1: Enable use_custom_data on MultiMesh (lines 107-108)**

Open `Systems/EnemyMeshManager.gd`. Find the MultiMesh init block (around lines 107-108):
```gdscript
mm.transform_format = MultiMesh.TRANSFORM_2D
mm.use_colors = true
mm.instance_count = max_count
```

Add `mm.use_custom_data = true`:
```gdscript
mm.transform_format = MultiMesh.TRANSFORM_2D
mm.use_colors = true
mm.use_custom_data = true
mm.instance_count = max_count
```

- [ ] **Step 2: Write custom_data in _update_type (lines 574-587)**

Find `_update_type` (the function that loops over instances and calls `set_instance_color`). After the `set_instance_color` call, add custom_data write:

The existing code likely has:
```gdscript
mm.set_instance_color(write, Color(r, g, b, _phase[i]))
```

After this line, add:
```gdscript
var s_timer: float = d[off + I_SLOW_TIMER]
var freeze_amt: float = 0.0
var frozen_t: float = 0.0
if s_timer > 0.0:
    freeze_amt = minf(s_timer / 4.0, 1.0)
    if s_timer > 2.0 and frozen_t == 0.0:
        frozen_t = _game_time
mm.set_instance_custom_data(write, Color(freeze_amt, frozen_t, 0.0, 0.0))
```

If `_game_time` is not a member variable, use the existing time-tracking variable name in the file (search for `game_time` reference). The EnemyMeshManager tracks frame time somewhere — use the same source.

- [ ] **Step 3: Verify**

Reload. Check for parse errors. The change adds per-instance data, not a new logic path, so no test needed at this stage (visual check happens after shader change in Task 6).

---

## Task 6: Needle Frost — SwarmShader ice overlay

**Files:**
- Modify: `Systems/SwarmShader.gdshader` (fragment section)

- [ ] **Step 1: Read current shader**

Open `Systems/SwarmShader.gdshader`. The current fragment computes frame from global `game_time`:
```glsl
float phase = COLOR.a * frame_count;
float frame = floor(mod(game_time * anim_fps + phase, frame_count));
vec2 uv = UV;
uv.x = (frame + uv.x) / frame_count;
vec4 tex = texture(spritesheet, uv);
if (tex.a < 0.05) discard;

vec2 center = UV - 0.5;
float dist = length(center) * 2.0;
float vignette = 1.0 - dot(center, center) * 8.5;
vignette = clamp(vignette, 0.0, 1.0);
float core_glow = smoothstep(0.55, 0.0, dist) * 0.25;
vec3 base_col = tex.rgb * COLOR.rgb * 3.0 * vignette;
vec3 core_col = mix(vec3(0.8, 0.15, 0.05), COLOR.rgb, 0.4) * core_glow;
vec3 col = base_col + core_col;
COLOR = vec4(col, 1.0);
```

- [ ] **Step 2: Replace with ice-overlay version**

Replace the entire fragment section with:
```glsl
float freeze = INSTANCE_CUSTOM.r;
float frozen_t = INSTANCE_CUSTOM.g;
float phase = COLOR.a * frame_count;
float anim_t = (freeze > 0.99) ? frozen_t : game_time;
float frame = floor(mod(anim_t * anim_fps + phase, frame_count));
vec2 uv = UV;
uv.x = (frame + uv.x) / frame_count;
vec4 tex = texture(spritesheet, uv);
if (tex.a < 0.05) discard;

vec2 center = UV - 0.5;
float dist = length(center) * 2.0;
float vignette = 1.0 - dot(center, center) * 8.5;
vignette = clamp(vignette, 0.0, 1.0);
float core_glow = smoothstep(0.55, 0.0, dist) * 0.25;
vec3 base_col = tex.rgb * COLOR.rgb * 3.0 * vignette;

vec2 ice_uv = UV * 8.0;
float crack = fract(sin(dot(floor(ice_uv), vec2(12.9898, 78.233))) * 43758.5453);
float crack_mask = step(0.95, crack) * freeze;
float frost_edge = smoothstep(0.3, 0.5, dist) * freeze;
vec3 ice_tint = vec3(0.7, 0.9, 1.1);
vec3 ice_color = mix(tex.rgb, ice_tint, frost_edge * 0.4 + crack_mask * 0.8);

vec3 final_col = mix(base_col, ice_color * COLOR.rgb * 3.0 * vignette, freeze);
vec3 core_col = mix(vec3(0.8, 0.15, 0.05), COLOR.rgb, 0.4) * core_glow;
vec3 col = final_col + core_col;
COLOR = vec4(col, 1.0);
```

- [ ] **Step 3: Verify shader compiles**

Reload project. Check Output for shader errors. If error about `INSTANCE_CUSTOM` not available, ensure `use_custom_data = true` is set on the MultiMesh (Task 5 step 1).

- [ ] **Step 4: Manual visual test**

Start a run, get Needle with Frost Shard, stab a mesh enemy (Drone, Golem, etc. — NOT Swarm). Verify:
- Animation freezes (sprite doesn't move frames)
- Blue tint visible
- Procedural ice cracks visible on enemy
- Frost edges visible (lighter blue at sprite borders)

---

## Task 7: Needle Frost — SwarmManager custom_data

**Files:**
- Modify: `Systems/SwarmManager.gd:128` (enable use_custom_data)
- Modify: `Systems/SwarmManager.gd:366` (write custom_data)

- [ ] **Step 1: Enable use_custom_data on SwarmManager MultiMesh (line 128)**

Open `Systems/SwarmManager.gd`. Find the MultiMesh init at line 128 (similar to EnemyMeshManager):
```gdscript
mm.transform_format = MultiMesh.TRANSFORM_2D
mm.use_colors = true
mm.instance_count = max_count
```

Add `use_custom_data`:
```gdscript
mm.transform_format = MultiMesh.TRANSFORM_2D
mm.use_colors = true
mm.use_custom_data = true
mm.instance_count = max_count
```

- [ ] **Step 2: Write custom_data in update loop (line 366)**

Find the loop that calls `set_instance_color` for swarm units. After the color write, add custom_data. The pattern is identical to EnemyMeshManager:

After the existing:
```gdscript
mm.set_instance_color(write, Color(r, g, b, _phase[i]))
```

Add:
```gdscript
var s_timer: float = _slow_timer[i]
var freeze_amt: float = 0.0
var frozen_t: float = 0.0
if s_timer > 0.0:
    freeze_amt = minf(s_timer / 4.0, 1.0)
    if s_timer > 2.0 and frozen_t == 0.0:
        frozen_t = _game_time
mm.set_instance_custom_data(write, Color(freeze_amt, frozen_t, 0.0, 0.0))
```

If SwarmManager uses different field names (e.g., `_slow_timer` is an Array instead of PackedFloat32Array), adapt the access pattern. The shader uses `INSTANCE_CUSTOM` regardless.

- [ ] **Step 3: Verify and test**

Reload. Start run, get Needle + Frost, stab a Swarm enemy. Verify same visual as Task 6 step 4 (animation freeze, blue tint, ice cracks).

---

## Task 8: Magnet filter — Currency, Heart, PowerUp

**Files:**
- Modify: `Entities/Pickups/CurrencyOrb.gd:43-53, ~97` (add group + filter)
- Modify: `Entities/Pickups/HealthHeart.gd:52-73, ~100` (add group + filter)
- Modify: `Entities/Pickups/PowerUpPickup.gd:31-42, ~245` (add group + filter)

- [ ] **Step 1: Add magnet_target group to CurrencyOrb.on_spawn()**

Open `Entities/Pickups/CurrencyOrb.gd`. Find `on_spawn()` (lines 43-53). Add group registration. The function likely looks like:

```gdscript
func on_spawn(pos: Vector2, value: int = 1) -> void:
    global_position = pos
    _value = value
    visible = true
    # ... other init
```

Add at the start of the function body (after the init lines):
```gdscript
if not is_in_group("magnet_target"):
    add_to_group("magnet_target")
```

- [ ] **Step 2: Add magnet filter at start of CurrencyOrb._process()**

Find `_process()` in CurrencyOrb.gd. At the very start, add:
```gdscript
func _process(delta: float) -> void:
    if is_in_group("magnet_skip"):
        return
    # ... existing code
```

Note: CurrencyOrb is in `magnet_target` group, NOT `magnet_skip`, so the early return does NOT fire. The group registration in step 1 is for clarity and future use.

- [ ] **Step 3: Add magnet_skip group to HealthHeart.on_spawn()**

Open `Entities/Pickups/HealthHeart.gd`. Find `on_spawn()` (lines 52-73). Add at start:
```gdscript
if not is_in_group("magnet_skip"):
    add_to_group("magnet_skip")
```

- [ ] **Step 4: Add magnet filter at start of HealthHeart._process()**

Find `_process()` in HealthHeart.gd. At the very start, add:
```gdscript
func _process(delta: float) -> void:
    if is_in_group("magnet_skip"):
        return
    # ... existing code
```

- [ ] **Step 5: Add magnet_skip group to PowerUpPickup.on_spawn()**

Open `Entities/Pickups/PowerUpPickup.gd`. Find `on_spawn()` (lines 31-42). Add at start:
```gdscript
if not is_in_group("magnet_skip"):
    add_to_group("magnet_skip")
```

- [ ] **Step 6: Add magnet filter at start of PowerUpPickup._process()**

Find `_process()` in PowerUpPickup.gd (around line 245). At the very start, add:
```gdscript
func _process(delta: float) -> void:
    if is_in_group("magnet_skip"):
        return
    # ... existing code
```

- [ ] **Step 7: Verify and test**

Reload. Start run with magnet upgrade. Verify:
- XP orbs (small purple) fly to player at distance
- Currency (gold) flies to player at distance
- Hearts (red cross) stay on ground — player must walk to them
- Power-ups (books/chests) stay on ground — player must walk to them
- Without magnet, all pickups stay on ground (existing behavior)
- Mega-magnet (if available) still pulls everything

---

## Task 9: Phase colors — palette + CanvasModulate

**Files:**
- Modify: `Main.gd:10` (add canvas_modulate ref)
- Modify: `Main.gd:17-24` (new palette)
- Modify: `Main.gd:50-62` (apply via CanvasModulate, lerp speed)
- Modify: `Main.tscn` (add CanvasModulate node)

- [ ] **Step 1: Add CanvasModulate node to Main.tscn**

Open `Main.tscn` in Godot Editor. Find the root node (a Control or Node). Add a CanvasModulate node as a direct child:
1. In the Scene dock, right-click the root node
2. Select "Add Child Node"
3. Search for "CanvasModulate"
4. Click "Create"
5. Set the new node's name to "CanvasModulate"

- [ ] **Step 2: Update PHASE_COLORS in Main.gd (lines 17-24)**

Open `Main.gd`. Find lines 17-24:
```gdscript
const PHASE_COLORS: PackedColorArray = [
    Color(1.0, 1.0, 1.0),
    Color(0.92, 0.95, 1.0),
    Color(0.95, 1.0, 0.90),
    Color(1.0, 0.88, 0.72),
    Color(0.92, 0.82, 0.98),
    Color(0.88, 0.75, 0.92),
]
```

Replace with:
```gdscript
const PHASE_COLORS: PackedColorArray = [
    Color(1.00, 1.00, 1.00),
    Color(0.62, 0.78, 0.95),
    Color(0.68, 0.85, 0.42),
    Color(0.78, 0.55, 0.42),
    Color(0.95, 0.42, 0.32),
    Color(0.55, 0.32, 0.72),
    Color(0.28, 0.18, 0.38),
]
```

- [ ] **Step 3: Replace _world_manager_mod reference with _canvas_modulate (line 10)**

Find the onready var for the world manager (around line 10):
```gdscript
@onready var _world_manager_mod: Node2D = $WorldManager
```

Replace with:
```gdscript
@onready var _world_manager_mod: Node2D = $WorldManager
@onready var _canvas_modulate: CanvasModulate = $CanvasModulate
```

(Keep `_world_manager_mod` if other code uses it. Only add the new ref.)

- [ ] **Step 4: Update _update_ambient() to use CanvasModulate (lines 50-62)**

Find `_update_ambient()`:
```gdscript
func _update_ambient(delta: float) -> void:
    if not _world_manager_mod: return
    if GameManager.is_playing() and is_instance_valid(_wave_manager):
        var pi: int = _wave_manager._phase_index
        if pi != _prev_phase_index:
            _prev_phase_index = pi
            if pi >= 0 and pi < PHASE_COLORS.size():
                _target_mod_color = PHASE_COLORS[pi]
    _current_mod_color = _current_mod_color.lerp(_target_mod_color, delta * 0.8)
    _world_manager_mod.modulate = _current_mod_color
```

Replace with:
```gdscript
func _update_ambient(delta: float) -> void:
    if not _canvas_modulate: return
    if GameManager.is_playing() and is_instance_valid(_wave_manager):
        var pi: int = _wave_manager._phase_index
        if pi != _prev_phase_index:
            _prev_phase_index = pi
            if pi >= 0 and pi < PHASE_COLORS.size():
                _target_mod_color = PHASE_COLORS[pi]
    _current_mod_color = _current_mod_color.lerp(_target_mod_color, delta * 1.5)
    _canvas_modulate.color = _current_mod_color
```

- [ ] **Step 5: Verify and test**

Reload. Start a run, observe:
- Initial color: white (Color(1, 1, 1))
- Phase 1 (Drone): noticeable steel blue tint
- Phase 2 (Mine): noticeable toxic green tint
- Phase 3 (Golem): rust brown tint
- Phase 4 (Berserk): red/crimson tint
- Phase 5 (Overlord): purple tint
- Phase 6 (Armageddon): dark violet/abyss tint
- Tint affects player, enemies, projectiles (global atmospheric shift)
- Transition takes ~2s (smooth, not jarring)

---

## Self-Review

**1. Spec coverage:**
- Group A (particles): Task 1 steps 1-4 ✓
- Group A (halo): Task 1 steps 1-2 ✓
- Group B (enter_endless): Task 2 step 1 ✓
- Group B (comment): Task 2 step 2 ✓
- Group C (2 sprites): Task 3 steps 1-3 ✓
- Group C (orbit): Task 3 step 4 ✓
- Group C (damage): Task 3 step 5 ✓
- Group C (remove _draw_twin): Task 3 step 6 ✓
- Group C (damage_multiplier): Task 3 step 7 ✓
- Group D-A (BaseEnemy): Task 4 step 1 ✓
- Group D-B (EnemyMeshManager): Task 5 steps 1-2 ✓
- Group D-C (SwarmShader): Task 6 step 2 ✓
- Group D-D (SwarmManager): Task 7 steps 1-2 ✓
- Group E (CurrencyOrb): Task 8 steps 1-2 ✓
- Group E (HealthHeart): Task 8 steps 3-4 ✓
- Group E (PowerUpPickup): Task 8 steps 5-6 ✓
- Group F (palette): Task 9 step 2 ✓
- Group F (CanvasModulate node): Task 9 step 1 ✓
- Group F (Main.gd ref + apply): Task 9 steps 3-4 ✓

**2. Placeholder scan:** No "TBD", "TODO", "implement later" found. All code shown.

**3. Type consistency:**
- `_visual_range_mult` defined Task 1 step 1, used Task 1 step 2-4 ✓
- `_sprite_a`/`_sprite_b` defined Task 3 step 1, used Task 3 steps 3-5 ✓
- `_twin_orbit_phase`/`_twin_orbit_radius` defined Task 3 step 2, used Task 3 step 4 ✓
- `_canvas_modulate` defined Task 9 step 3, used Task 9 step 4 ✓
- `magnet_target`/`magnet_skip` group names consistent across all 3 files ✓
- `INSTANCE_CUSTOM.r`/`.g` shader params match write side (Task 5/7 writes `Color(freeze_amt, frozen_t, 0, 0)`, Task 6 reads `INSTANCE_CUSTOM.r`/`INSTANCE_CUSTOM.g`) ✓

**4. Gaps found and fixed:** None.

---

## Execution Notes

- **Project is NOT a git repo.** No commit steps. Changes persist in working files.
- **No unit tests for visual changes.** Verification is by manual visual check after each task.
- **Godot Editor: Ctrl+Shift+R reloads the project to clear any stale imports.**
- **If script parse errors appear after edit:** check the Output panel, the error line number will point to the exact issue. Most common: missing comma in const array, or undeclared identifier from incomplete refactor.
- **Order of execution matters for Cyclone (Task 3):** all 4 sprite/orbit changes must be done in one edit pass since they reference each other. If split, the project will have parse errors between steps.
