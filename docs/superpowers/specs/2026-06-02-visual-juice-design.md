# Visual Juice & Contrast Design Spec

**Date:** 2026-06-02
**Status:** Approved (user said "приступай" 2026-06-02)
**Scope:** Single coherent PR covering 4 visual systems

## Goal

Make the game "сочнее" (juicier), more контрастной (contrasty) and visually "объёмной" (voluminous) **without dropping FPS**. Since the game already uses MultiMesh for enemies and a centralized shared CanvasItemMaterial pattern for spell visuals, all four visual systems are layered on top of existing infrastructure.

## Constraints & Decisions

- **CanvasModulate tint:** Gothic blue `Color(0.239, 0.290, 0.361)` (#3d4a5c). Cold, deep, balances warm spells (fire/magic) and cold spells (ice/lightning).
- **Scope:** One PR, all 4 parts cohesive. They are interdependent: Glow needs HDR colors to show, CanvasModulate needs Unshaded + HDR to exempt spells, shadow MultiMesh updates share the same per-frame loop as the main MultiMesh.
- **Shadow coverage:** All enemies + orbs. One shadow draw call per enemy type.
- **Performance budget:** < 1 ms/frame additional cost on integrated GPU at 1080p. Measured via Godot 4.6.2 profiler in main scene with 200 swarm + 50 medium + 8 big enemies active.

## Architecture (Approach A)

Four layers, all co-existing:

```
main.tscn (root)
├── WorldManager
├── Player
├── Systems/
│   ├── SwarmManager ── _mm_instance (main) + _mm_shadow (NEW, ovals)
│   ├── EnemyMeshManager ── per-type main MM + per-type shadow MM (NEW)
│   ├── OrbManager ── _mm_instance + _glow_mm_instance + _mm_shadow (NEW)
│   └── ...
├── WorldEnvironment  ← NEW
│   └── Environment (.tres with glow + tonemap)
├── CanvasModulate  ← NEW (color = #3d4a5c)
└── UI/ (CanvasLayer)
    ├── HUD
    └── ColorFilter  ← NEW (ColorRect with color_correction.gdshader)
```

### 1. WorldEnvironment + Glow (post-process)

`Scenes/default_env.tres`:
- `glow_enabled = true`
- `glow_blend_mode = GLOW_BLEND_MODE_ADDITIVE` (was: `additive`)
- `glow_hdr_threshold = 1.0` (only HDR pixels glow)
- `glow_hdr_scale = 2.0` (boost HDR)
- `glow_intensity = 0.8`
- `glow_strength = 1.0`
- `glow_bloom = 0.0`
- `tonemap_mode = TONEMAP_FILMIC` (ACES-like)
- `tonemap_exposure = 1.0`

Add as child of root: `WorldEnvironment` node with `environment = load("res://Scenes/default_env.tres")`.

### 2. Color correction (UI overlay)

`Shaders/color_correction.gdshader`:
```glsl
shader_type canvas_item;
uniform float contrast : hint_range(0.0, 2.0) = 1.15;
uniform float saturation : hint_range(0.0, 2.0) = 1.25;
void fragment() {
    vec4 color = texture(TEXTURE, UV);
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(vec3(luma), color.rgb, saturation);
    COLOR = color;
}
```

`UI/ColorFilter` (ColorRect, anchor=15, mouse_filter=IGNORE, z_index above HUD but ColorRect uses additive blend, NOT mod).

### 3. CanvasModulate (world tint)

Single node `CanvasModulate` as child of root. `color = Color(0.239, 0.290, 0.361)`.

### 4. Shadow MultiMesh (in-place, in each manager)

`Scenes/shadow_oval.png` — 16×16 procedural texture, soft elliptical falloff. Generated via code (similar to `VFXManager._ensure_glow_texture()`).

Shared shadow material:
- `CanvasItemMaterial`
- `blend_mode = BLEND_MODE_MIX` (normal alpha blending)
- `light_mode = LIGHT_MODE_NORMAL` (shadow IS affected by CanvasModulate, which is what we want)
- `modulate` set to `Color(0, 0, 0, 0.45)` on the MultiMeshInstance2D itself

Each manager adds:
- `_mm_shadow: MultiMeshInstance2D` field
- `SHADOW_OFFSET := Vector2(0, 8)` constant
- In `_process`, after updating main MM transforms, mirror positions into `_mm_shadow` with offset
- Z-index: 0 (below enemies which are z=1, but above world)
- Texture: shadow_oval.png (shared)

**Exempt from CanvasModulate (use Unshaded + HDR):**

All 14 spell material singletons get:
- `light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED`
- (HDR colors already partially present in SwarmShader, Projectile.gd; we add multiplier helper in shared `_apply_hdr_boost` static method)

Spell visuals updated:
- `Spells/visuals/NeedlePuff.gd:84`
- `Spells/visuals/ArcaneRay.gd:39`
- `Spells/visuals/SpiritOrb.gd:54`
- `Spells/visuals/CycloneVortex.gd:52`
- `Spells/visuals/RefractionBolt.gd:22`
- `Spells/visuals/ElectricField.gd:38`
- `Spells/visuals/ShieldAura.gd:27`
- `Spells/visuals/RefractionBurst.gd:19`
- `Spells/visuals/SpiritBolt.gd:53`
- `Spells/visuals/HealFlashEffect.gd:15`
- `Spells/visuals/LevelUpBurst.gd:15`
- `Entities/Projectiles/Projectile.gd:39` (`_shared_material`)
- `Entities/Projectiles/FireballProjectile.gd` (check for shared mat)
- `Spells/visuals/FireBreathPuff.gd:190` (local `ci_mat` per puff)

Shaders:
- `Systems/SwarmShader.gdshader` — add `render_mode unshaded;` (the shader is canvas_item, defaults to affected by 2D lights; this exempts it)
- `Shaders/fire_particle.gdshader` — already `unshaded + blend_add`, no change

## Testing & Verification

1. **Headless parse** with `godot --headless --check-only --path D:\Godot\Projects\ms`
2. **Visual sanity** (manual in editor):
   - Spells visibly glow against dark-blue world
   - Shadows visible under all enemy types
   - HUD readable
   - No z-fighting between shadows and enemies
3. **Performance** (manual in editor with 200+ enemies):
   - Frame time delta < 1 ms vs baseline
4. **Customization doc updated** with new visual knobs

## Out of Scope (deliberate)

- Per-modifier visual overrides (deferred to "visual modifier presets" project)
- 2D light nodes (PointLight2D) — explicitly avoided per TЗ (perf risk)
- Shadow direction based on sun position — shadow is purely decorative blob below enemy
- Animated shadow scaling on enemy movement (constant offset + scale is sufficient)

## Risk & Mitigations

| Risk | Mitigation |
|---|---|
| Glow over-saturates the screen | `glow_intensity = 0.8` (not 1.5+); tonemap filimc clamps |
| Shadow MultiMesh doubles GPU work | Only big/rampage/overlord/mine in EnemyMeshManager + swarm + orbs; max 10 draw calls extra (we have 9 main enemy MMs + 1 swarm + 1 orb = 11 main + 10 shadow = 21 total draw calls, manageable) |
| Color correction dim color rect causes perf | `ColorRect` at 1× viewport size, single quad, single fragment per pixel; with `unshaded` skip lighting calc; cost ≈ < 0.3 ms |
| CanvasModulate breaks existing colors | `modulate` of all sprites already works through CanvasModulate; HDR > 1.0 keeps spells bright |

## Relevant Files

**Create:**
- `Scenes/default_env.tres`
- `Shaders/color_correction.gdshader`
- `Systems/ShadowTexture.gd` (autoload OR static utility for procedural shadow texture)
- `docs/superpowers/plans/2026-06-02-visual-juice.md` (this plan)

**Modify:**
- `main.tscn` (add WorldEnvironment, CanvasModulate, UI/ColorFilter)
- `Systems/SwarmManager.gd` (add shadow MM)
- `Systems/EnemyMeshManager.gd` (add shadow MM per type)
- `Systems/OrbManager.gd` (add shadow MM)
- `Systems/SwarmShader.gdshader` (add `render_mode unshaded`)
- 14 spell visual files (add `light_mode = LIGHT_MODE_UNSHADED`)
- `docs/CUSTOMIZATION.md` (add Visual System section)
