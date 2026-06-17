# 8 Improvements: Brainstorm Design

**Date:** 2026-06-05
**Cycle:** brainstorm → spec → plan → implement (all 8 issues in one iteration by user choice)

## Goals

Fix/enhance 8 gameplay issues in one iteration:

1. FireBreath Dragon Breath particles fly off-screen
2. FireBreath halo not synced with visual flame length
3. Inner Power upgrades not applied in every run (bug in `enter_endless`)
4. Cyclone "Twin Cyclone" mod has 1D oscillation bug instead of 2D waltz
5. Needle Frost does not stop enemy animation, no clear freeze visual
6. Magnet super-bonus attracts all pickups, should only XP + currency
7. Phase background color change barely visible + tied to enemy type
8. Brainstorm skill applied (this document)

## Constraints & Decisions

- **Godot 4.6.2** — `ParticleProcessMaterial.alpha_curve` expects `Texture2D` (CurveTexture), no `fade_enabled`/`fade_curve`
- **No interval between particles** for FireBreath (per user)
- **Halo lighting logic must stay the same** — only geometry (scale/position) changes
- **Phase order already correct** (Drone → Mine → Golem → Rampage → Overlord → Armageddon by difficulty), no reorder
- **All changes minimal-invasive** — no architectural refactors

---

## Group A: FireBreath (Tasks #1, #7)

### Problem
`FireBreathPuff.gd:435-445` — Dragon Breath mod multiplies `lifetime × 1.5` and `damping × 0.7`. Without mod, body layer already flies `v²/(2·d) = 950²/(2·260) ≈ 1736px` (9.6× `cone_range=180`). With Dragon Breath — 5000+ px off-screen.

Halo Sprite2D uses `_cone_range` directly (FireBreathPuff.gd:281, 359, 375), but Dragon Breath particles fly 3× further. Halo at 162px, particles at 1000+ px.

### Solution

**File:** `Spells/visuals/FireBreathPuff.gd`

1. **Lines 437-438** — remove `lifetime × 1.5`:
   - Was: `_base_lifetimes[i] = orig_lifetimes[i] * 1.5`
   - Now: `_base_lifetimes[i] = orig_lifetimes[i]` (lifetime already scaled via `_apply_range_ratio()` line 394 as `_cone_range / DESIGN_RANGE`)

2. **Lines 442-443** — remove damping reduction:
   - Was: `mat.damping_min/max = orig_damp_min/max[i] * 0.7`
   - Now: `mat.damping_min/max = orig_damp_min/max[i] * 1.0` (or remove these lines)

3. **Line 10** (near `_vel_ratio`):
   ```gdscript
   var _visual_range_mult: float = 1.0
   ```

4. **Lines 432-434** (in `apply_modifier`, reset block):
   ```gdscript
   _visual_range_mult = 1.0
   ```

5. **Lines 435-436** (in Dragon Breath branch):
   ```gdscript
   _visual_range_mult = 1.4  # velocity ×1.4 compensation; lifetime already covered
   ```

6. **Line 359** (in `_update_halo`):
   - Was: `var range: float = _cone_range * _vel_ratio * lerp(0.1, 1.0, glow_progress)`
   - Now: `var range: float = _cone_range * _vel_ratio * _visual_range_mult * lerp(0.1, 1.0, glow_progress)`

### Expected Effect
- Dragon Breath particles stop at ~95% of `cone_range × 2.0 = 360px`, not 5000+ px
- Halo grows 1.4× with Dragon Breath, synced to actual particle distance
- Lighting logic unchanged (same Sprite2D, texture 128×128, additive blend, `_halo_alpha` fade)

---

## Group B: Inner Power (Task #2)

### Problem
`GameManager.enter_endless()` (lines 149-152) **does NOT call** `UpgradeManager.apply_to_player()`. Scenario: Victory → buy Inner Power → Endless → bonuses not applied.

### Solution

**File:** `Autoload/GameManager.gd`

**Lines 149-152** (after `_endless_mode = true`):
```gdscript
func enter_endless() -> void:
    _endless_mode = true
    current_state = GameState.PLAYING
    get_tree().paused = false
    var player := get_player()
    if player:
        UpgradeManager.apply_to_player(player)  # <-- ADD
```

**File:** `Entities/Player/Player.gd`

**Lines 22-28** — add comment:
```gdscript
# NOTE: stats are overwritten in GameManager.start_game() → apply_to_player()
# This default init is for first-frame rendering before apply_to_player runs
if not stats:
    stats = PlayerStats.new()
stats.current_hp = stats.max_hp
```

### Expected Effect
Inner Power bonuses apply on ANY run start: Play, Restart, Endless.

---

## Group C: Cyclone Twin Cyclone (Task #3)

### Problem
- `LevelUpManager.gd:581` — mod is called "Twin Cyclone" (NOT "Storm")
- `CycloneVortex.gd:32` — creates 1 object with `_is_twin = true` flag
- `CycloneVortex.gd:159, 191` — **bug**: `Vector2(cos(_twin_phase), sin(_twin_phase)).x` takes only `.x` of 2D vector (1D oscillation along perpendicular, not 2D orbit)
- No second Sprite2D — proxy circles in `_draw_twin()` are flat

### Solution

**File:** `Spells/visuals/CycloneVortex.gd`

1. **Lines 19-23** (replace single `_sprite` with pair):
   ```gdscript
   var _sprite_a: Sprite2D = null
   var _sprite_b: Sprite2D = null
   ```

2. **Lines 31-33** (new fields):
   ```gdscript
   var _twin_orbit_phase: float = 0.0
   var _twin_orbit_radius: float = 60.0  # was _twin_offset = 40.0
   ```

3. **Lines 43-50** (`_ready`, create 2 sprites):
   ```gdscript
   _sprite_a = Sprite2D.new()
   _sprite_a.texture = preload("res://Sprites/cyclone_pix.png")
   add_child(_sprite_a)
   _sprite_b = Sprite2D.new()
   _sprite_b.texture = preload("res://Sprites/cyclone_pix.png")
   _sprite_b.modulate = Color(1.2, 1.2, 1.2, 1.0)
   add_child(_sprite_b)
   ```

4. **Lines 109-112** (in `_process`, after `global_position += _direction * _fly_speed * delta`):
   ```gdscript
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

5. **Lines 157-163** (`_tick_damage`, damage in both points):
   ```gdscript
   if _is_twin:
       var pos_a: Vector2 = global_position + _sprite_a.position
       var pos_b: Vector2 = global_position + _sprite_b.position
       var r: float = _current_radius * 0.5
       SwarmManager.damage_area(pos_a, r, _damage)
       EnemyMeshManager.damage_area(pos_a, r, _damage)
       SwarmManager.damage_area(pos_b, r, _damage)
       EnemyMeshManager.damage_area(pos_b, r, _damage)
   else:
       # ... (current code)
   ```

6. **Lines 189-195** (`_draw_twin`) — remove or simplify (sprites draw themselves).

### Parameters
- `_twin_orbit_radius: 40 → 60`
- `damage_multiplier: 1.5 → 1.7` (`LevelUpManager.gd:584`, 2 damage points)
- `zone_radius_mult: 2.5` keep (pair radius = √2 × r single)

**File:** `Systems/LevelUpManager.gd`, line 584: `mod_twin.damage_multiplier = 1.7`

### Expected Effect
2 vortexes orbit around common center at 60px, phases offset 180°, spirals counter-rotate. Damage in 2 points simultaneously.

---

## Group D: Needle Frost freeze visual (Task #4)

### Problem
2 different render systems, both don't stop animation on freeze:
- **BaseEnemy (AnimatedSprite2D)**: `_anim.speed_scale=0` (not real `_anim.stop()`); visually weak
- **EnemyMeshManager / SwarmManager (MultiMesh + shader)**: `SwarmShader.gdshader` uses **global** `game_time` — per-instance freeze impossible, sprite keeps animating even when enemy logically fully stopped

### Solution

#### A. BaseEnemy (AnimatedSprite2D)
**File:** `Entities/Enemies/BaseEnemy.gd`

**Lines 202-220** (`_physics_process`, slow block):
```gdscript
if _slow_timer > 0.0:
    _slow_timer -= _delta
    if _anim:
        if _slow_timer > 2.0:
            # Full freeze: real stop
            if _anim.is_playing():
                _anim.stop()
                _anim.frame = 0
            _anim.speed_scale = 0.0
            _anim.modulate = Color(0.65, 0.85, 1.0, 1.0)
        else:
            _anim.speed_scale = 0.0
            # (current tint lerp)
elif _anim and _hit_flash_timer <= 0.0:
    if not _anim.is_playing():
        _anim.play("walk")
    _anim.modulate = _color_variant
    _anim.speed_scale = 1.0
```

#### B. EnemyMeshManager (MultiMesh + per-instance custom data)
**File:** `Systems/EnemyMeshManager.gd`

**Lines 107-108** (in `_init`):
```gdscript
mm.use_colors = true
mm.use_custom_data = true  # <-- ADD
```

**Lines 574-587** (in `_update_type`, after `set_instance_color`):
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

#### C. SwarmShader (procedural ice-overlay)
**File:** `Systems/SwarmShader.gdshader`

Add `INSTANCE_CUSTOM` usage:
```glsl
float freeze = INSTANCE_CUSTOM.r;
float frozen_t = INSTANCE_CUSTOM.g;

// Frame: frozen at full freeze, else normal
float anim_t = (freeze > 0.99) ? frozen_t : game_time;
float frame = floor(mod(anim_t * anim_fps + phase, frame_count));

// ... (tex fetch as current)

// Ice overlay: frost edges + random cracks
vec2 ice_uv = UV * 8.0;
float crack = fract(sin(dot(floor(ice_uv), vec2(12.9898, 78.233))) * 43758.5453);
float crack_mask = step(0.95, crack) * freeze;
float frost_edge = smoothstep(0.3, 0.5, dist) * freeze;
vec3 ice_tint = vec3(0.7, 0.9, 1.1);
vec3 ice_color = mix(tex.rgb, ice_tint, frost_edge * 0.4 + crack_mask * 0.8);

// Final mix
vec3 final_col = mix(base_col, ice_color * COLOR.rgb * 3.0 * vignette, freeze);
```

#### D. Repeat for SwarmManager
**File:** `Systems/SwarmManager.gd:128, 366` — same structure (`mm.use_custom_data = true`, custom data in update, shader shared).

### Expected Effect
- BaseEnemy: full animation stop + frame 0 locked
- Mesh enemies: animation frozen via shader (`game_time → frozen_at_time`)
- All enemies: procedural ice-overlay (cracks + frost edges) + blue tint

---

## Group E: Magnet filter (Task #5)

### Problem
4 files with same magnet-logic, no type filter:
- `CurrencyOrb.gd:112-114` (Currency)
- `HealthHeart.gd:137-139` (Heart)
- `PowerUpPickup.gd:253-255` (PowerUp)
- `OrbManager.gd:208-213` (XP, batch)

### Solution (group-based)

#### A. Add groups in `on_spawn()`

**File:** `Entities/Pickups/CurrencyOrb.gd`, lines 43-53:
```gdscript
if not is_in_group("magnet_target"):
    add_to_group("magnet_target")
```

**File:** `Entities/Pickups/HealthHeart.gd`, lines 52-73:
```gdscript
if not is_in_group("magnet_skip"):
    add_to_group("magnet_skip")
```

**File:** `Entities/Pickups/PowerUpPickup.gd`, lines 31-42:
```gdscript
if not is_in_group("magnet_skip"):
    add_to_group("magnet_skip")
```

**OrbManager** (XP) — no changes (always magnetized, batch).

#### B. Filter in magnet-logic

In each of 3 files at start of `_process()` (before distance check):
```gdscript
if is_in_group("magnet_skip"):
    return
```

Mega-magnet override (`pickup_range = maxf(vp.x, vp.y) * 0.8`) stays — collects ALL on super-bonus.

### Expected Effect
- Normal magnet: pulls only XP orbs (OrbManager) + Currency (CurrencyOrb)
- Heart + PowerUp stay on ground until player walks into PickupDetector (radius 80px from player.tscn:8)
- Mega-magnet: as before, pulls all

---

## Group F: Phase colors (Task #6)

### Problem
- `Main.gd:17-24` `PHASE_COLORS` — pastel 0.75-1.0 (delta 0.25)
- Applied via `_world_manager_mod.modulate` (only WorldManager.tilemap)
- Combined with `ChunkGenerator.gd:135` (Color(0.22, 0.20, 0.28)) and ColorFilter (contrast 1.15, sat 1.25) — effective screen delta ≈ 0.055 per channel, nearly invisible

### Solution

#### A. New palette (Main.gd:17-24)
```gdscript
const PHASE_COLORS: PackedColorArray = [
    Color(1.00, 1.00, 1.00),       # Phase 0 init
    Color(0.62, 0.78, 0.95),       # Phase 1: Drone Wave - steel blue
    Color(0.68, 0.85, 0.42),       # Phase 2: Minefield - toxic green
    Color(0.78, 0.55, 0.42),       # Phase 3: Iron Wall - rust
    Color(0.95, 0.42, 0.32),       # Phase 4: Berserk - hot crimson
    Color(0.55, 0.32, 0.72),       # Phase 5: Overlord - dark purple
    Color(0.28, 0.18, 0.38),       # Phase 6: Armageddon - abyss
]
```

#### B. CanvasModulate instead of Node2D.modulate
**File:** `Main.tscn` — add CanvasModulate node as child of root
**File:** `Main.gd`:
- **Line 10**: `@onready var _canvas_modulate: CanvasModulate = $CanvasModulate`
- **Lines 50-62** (`_update_ambient`): replace `_world_manager_mod.modulate = _current_mod_color` with `_canvas_modulate.color = _current_mod_color`
- Lerp speed: `delta * 0.8` → `delta * 1.5` (~2s transition)

### Phase Order
**No change** — current progression (Drone → Mine → Golem → Rampage → Overlord → Armageddon) is logical by difficulty.

### Expected Effect
- Visible delta 0.72 (vs current 0.25)
- Global atmospheric shift: affects player, enemies, VFX, projectiles
- ~2s transition (visible but not jarring)
- Hue rotation + brightness ramp from cold-blue to abyssal-violet

---

## Implementation File List

| # | File | Lines | Action |
|---|------|-------|--------|
| 1 | `Spells/visuals/FireBreathPuff.gd` | 437-438, 442-443 | Remove lifetime ×1.5, remove damping ×0.7 |
| 2 | `Spells/visuals/FireBreathPuff.gd` | 10, 432-434, 359, 435-436 | Add `_visual_range_mult`, use in halo |
| 3 | `Autoload/GameManager.gd` | 149-152 | Add `apply_to_player()` in `enter_endless()` |
| 3 | `Entities/Player/Player.gd` | 22-28 | Add stats overwrite comment |
| 4 | `Spells/visuals/CycloneVortex.gd` | 19-23, 31-33, 43-50, 109-112, 157-163, 189-195 | 2 sprites + 2D orbit + counter rotation + 2-point damage |
| 4 | `Systems/LevelUpManager.gd` | 584 | `damage_multiplier: 1.5 → 1.7` |
| 5 | `Entities/Enemies/BaseEnemy.gd` | 202-220 | `_anim.stop()` + frame=0 at full freeze, play("walk") after thaw |
| 5 | `Systems/EnemyMeshManager.gd` | 107-108, 574-587 | `use_custom_data = true` + custom data with freeze_amount + frozen_at_time |
| 5 | `Systems/SwarmManager.gd` | 128, 366 | Same as EnemyMeshManager (mirror) |
| 5 | `Systems/SwarmShader.gdshader` | fragment | Per-instance frame time + procedural ice-overlay (cracks + frost_edge) |
| 6 | `Entities/Pickups/CurrencyOrb.gd` | 43-53, ~97 | `add_to_group("magnet_target")` + filter in `_process` |
| 6 | `Entities/Pickups/HealthHeart.gd` | 52-73, ~100 | `add_to_group("magnet_skip")` + early return |
| 6 | `Entities/Pickups/PowerUpPickup.gd` | 31-42, ~245 | `add_to_group("magnet_skip")` + early return |
| 7 | `Main.gd` | 17-24 | New palette (6 colors) |
| 7 | `Main.tscn` | - | Add CanvasModulate node |
| 7 | `Main.gd` | 10, 50-62 | `_canvas_modulate` ref, lerp speed 0.8→1.5 |

## Self-Review

- **Placeholder scan:** No TBD/TODO — all 7 groups concrete
- **Internal consistency:** All parameters have file:line, consistent across groups
- **Scope check:** 7 files modified + 1 scene = focused, single plan
- **Ambiguity check:** Sizes/radii/multipliers explicit; no "to taste" without alternatives
