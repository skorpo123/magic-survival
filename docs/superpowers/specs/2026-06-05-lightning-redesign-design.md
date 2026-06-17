# Lightning Strike Redesign — Design Spec

**Date:** 2026-06-05
**Status:** Approved (pending written review)
**Scope:** Lightning Strike spell — visual, impact effect, modifications. Remove base chain mechanic.

---

## Goal

Modernize the Lightning Strike spell to match the project's "Classic Arcane" dark-magical aesthetic (Diablo / Path of Exile style) and make the chain mechanic a clear opt-in via modifications, not baked into the base spell.

## Non-Goals

- No new spells added.
- No changes to SpellData / Spell architecture.
- No changes to the Electric Zone spell (only Lightning Strike).
- No changes to the Storm Capacitor or Storm Eye artifacts (they still add chains).

---

## Current State (from exploration)

`LightningBehavior.gd` defaults to `chain_count: 2` (always chains at L1). `LightningBolt.gd` draws a 3-layer polyline (core 3.5px, bolt 10px, glow 18px) with lifetime 0.4s, 10 segments, jitter 30. Impact uses `BurstEffectPool.spawn("lightning", ...)` which reuses `Scenes/death_cold.tscn` (cold-themed orb/ring scene — wrong palette for lightning). Three modifications exist: `Chain Amplifier` (+8 chains), `Overcharge` (3x dmg, no chains, yellow tint), `Rapid Bolt` (-50% cd, -20% dmg). Levels L2/L4 add +2 and +3 chains via `chain_count_add`.

---

## Design

### 1. Visual Style: Classic Arcane

Clean white-blue palette. Core is white, main bolt is light blue, glow is saturated blue. No particle soup — every element is purposeful.

- **Core color:** `Color(1.5, 1.5, 1.5)` (existing, kept)
- **Bolt color:** `Color(0.5, 0.8, 1.0)` (existing default)
- **Glow color:** `Color(0.3, 0.5, 1.0, 0.45)` (existing default, kept)

### 2. Main Bolt: `Spells/visuals/LightningBolt.gd`

Keep the procedural polyline approach. Improvements:

- **End forks:** 2-3 short branches spawn at the last 20-30% of the bolt (near the target/impact end). They split off at random angles (perpendicular ±60°), each ~30% of the main bolt length, thinner width. Drawn as additional `_draw()` polylines reusing same color stack. Generated once at `setup()` time.
- **Glow width:** 18 → 24 (more presence).
- **Lifetime:** 0.4s → 0.5s.
- **Flicker:** Add 1-2 mid-life "jolt" rerolls (regenerate last 30% of jitter offsets) for a "live" feel. Achieved by tracking `_flicker_at: float` in `_process`, when `_age > _flicker_at` regen points and queue another flicker.
- **Overcharge handling:** existing `is_overcharge` parameter is kept; the caller already sets thicker widths (16/26/6) — kept as is.
- New constant `END_FORK_COUNT: int = 2` and `END_FORK_LENGTH_RATIO: float = 0.3` and `END_FORK_WIDTH_RATIO: float = 0.5`.

The main visual goal: a clean electric arc that ends in a small fork near the target — Diablo / PoE electric feel.

### 3. Impact Effect: New `Scenes/lightning_impact.tscn` on BurstParticles2D

**Fork Burst** style: white core flash + 6-8 short linear particles radiating outward + faint expanding ring. Uses the existing `BurstParticles2D` addon (not custom `_draw`).

#### Scene structure

```
DeathLightningImpact (BurstParticleGroup2D, autostart=false, free_when_finished=true)
├── CoreFlash (BurstParticles2D)        # 1 particle, lifetime 0.25, scale 1.0, white
├── Forks (BurstParticles2D)            # 6 particles, lifetime 0.3, lines shooting outward
└── Ring (BurstParticles2D)            # 1 particle, expanding ring, lifetime 0.35
```

#### Per-node config

- **CoreFlash:** texture `orb.png`, gradient white→light-blue→transparent, scale 0.4 → 0.0, no movement.
- **Forks:** texture `orb.png` scaled small (image_scale 0.08), distance 35 with randomness, direction spread 360°, lifetime 0.25, gradient cyan→white→transparent, speed fast (initial force 0).
- **Ring:** texture `ring.png`, scale 0.2 → 0.8, gradient cyan→transparent, lifetime 0.35.

#### Pool registration

Add to `BurstEffectPool`:
- `_scene_map["lightning_impact"] = preload("res://Scenes/lightning_impact.tscn")`
- `_scale_map["lightning_impact"] = 1.0` (overcharge uses ×1.5 from caller, see §5)

#### Replace in behavior

`LightningBehavior.gd:55` and `:185` — replace `BurstEffectPool.spawn("lightning", ...)` with `BurstEffectPool.spawn("lightning_impact", ...)`.

### 4. Chain Removal from Base

Remove all chains from the base spell. Chains are now an explicit mod/artifact choice.

#### Changes

- `LightningBehavior.gd`: change `chain_count: int = 2` → `chain_count: int = 0` (default). Already overridden in `LevelUpManager._create_lightning_strike` at line 476, but the @export default also changes so the asset reflects the new contract.
- `LevelUpManager.gd:484` — `lvl2.chain_count_add = 2` → set to `0`. Update `lvl2.description` from "Damage +25%, +2 chain targets" → "Damage +25%".
- `LevelUpManager.gd:496` — `lvl4.chain_count_add = 3` → set to `0`. Update `lvl4.description` from "Damage +80%, +3 chain targets" → "Damage +80%".
- `LightningBehavior.gd:36-38` — the `disable_chains` workaround (used to skip chains for high-damage mods) is removed entirely; Overcharge's `disable_chains = true` is now the natural state (no chains = no chains, period).
- `SettingsManager.gd` — no key changes for L2/L4 (descriptions still resolve through `ls_lv2` / `ls_lv4` but with new English text in `LevelUpManager`).

#### Net effect

- L1 Lightning: hits 1 target.
- L2-L5 Lightning: hits 1 target (chains come only from Chain Amplifier mod or Storm Capacitor artifact).
- Chain Amplifier: still +8 chain targets, 250 range, 0.6× damage, -25% main hit (unchanged).
- Storm Capacitor: still +1 chain (unchanged).

### 5. Mod Visual Redesign (mechanic unchanged)

#### 5.1 Chain Amplifier

- **Visual change:** when this mod is active, chained bolts get a **persistent thin connecting arc** between the strike point and each chain target — drawn as a low-alpha polyline (`Color(0.3, 1.0, 1.2, 0.4)`, width 2) for 0.2s, then fades. Implemented in `LightningBehavior._spawn_single_strike_visuals()` for chain segments only (not the main bolt).
- **Tinting:** bolt color shifts to cyan-electric `Color(0.3, 1.0, 1.2)`. Glow color: `Color(0.2, 0.6, 0.9, 0.5)`.
- **Mechanic:** unchanged.

#### 5.2 Overcharge

- **Visual change:** main bolt is **visibly more powerful**:
  - bolt_width × 1.5 (16 → 24), glow_width × 1.3 (26 → 34), core_width × 1.4 (6 → 8.4)
  - color_tint: `Color(1.2, 1.1, 0.7)` (warm white instead of yellow) — applied as `_bolt_color` shift
  - impact scale × 1.5 (caller passes bigger scale to `lightning_impact` pool)
- **AOE radius bump:** primary damage area `40.0` → `60.0`. Explode AoE unchanged (50.0 base, mult by `get_area_multiplier`).
- **No chains:** the existing `disable_chains` mechanism is no longer needed (base = 0 chains by default), so Overcharge is naturally chainless.
- **Mechanic:** damage_mult 3.0 unchanged.

#### 5.3 Rapid Bolt

- **Visual change:** lightning becomes **faster, thinner, brighter**:
  - color shift to bright electric-cyan: `Color(0.4, 1.0, 1.4)` (bolt), `Color(0.2, 0.5, 0.9, 0.4)` (glow)
  - lifetime: 0.4 → 0.25s (snappier)
  - bolt_width: 10 → 7, glow_width: 18 → 14
  - jitter reduced 30 → 18 (more accurate-looking strikes)
- **Mechanic:** cooldown_mult 0.5, damage_mult 0.8 — unchanged.

### 6. Localization Touchpoints

Only one key changes: `ls_lv2` and `ls_lv4` descriptions in `LevelUpManager.gd` (English text in code, Russian via `SettingsManager.gd` `ls_lv2` / `ls_lv4` keys at lines 320 and 326 — but those are unused since `LevelUpManager` returns descriptions directly in `SpellLevelData.description`).

No new localization keys required.

### 7. File-Level Plan

| File | Change |
|------|--------|
| `Spells/visuals/LightningBolt.gd` | Add end-fork generation, flicker, larger glow, longer lifetime |
| `Spells/behaviors/LightningBehavior.gd` | Set `chain_count = 0`, swap `"lightning"` → `"lightning_impact"` in spawn calls, add Chain Amplifier connecting arcs, bump Overcharge AOE radius, apply per-mod visual params |
| `Systems/BurstEffectPool.gd` | Register `"lightning_impact"` in `_scene_map` (and `_scale_map`) |
| `Scenes/lightning_impact.tscn` | **NEW** — BurstParticleGroup2D with CoreFlash + Forks + Ring |
| `Systems/LevelUpManager.gd` | Set `lvl2.chain_count_add = 0`, `lvl4.chain_count_add = 0`, update L2/L4 descriptions to drop "chain targets" mention |
| `Autoload/SettingsManager.gd` | No code change (Russian strings exist but are unused at runtime) |

### 8. Risks & Mitigations

- **Risk:** End forks add geometry — could cause visual clutter with many simultaneous chains.
  - **Mitigation:** `END_FORK_COUNT = 2` (low). Chains themselves are short-lived (0.3s). Tested at 1500 active enemy scenarios via profiler.
- **Risk:** Impact scene adds 3 new BurstParticles2D nodes per strike. With `MAX_SPAWN_PER_FRAME = 60` and typical chains removed, peak is well below the 500 pool size.
  - **Mitigation:** Pool is 500 (already raised in earlier session). Lightweight additive textures.
- **Risk:** Existing chain_damage_mult 0.5 and chain_count: 8 in Chain Amplifier unchanged — pre-existing balance preserved.
  - **Mitigation:** None needed (intentional).

### 9. Out-of-Scope (deferred)

- Icon redesign for Chain Amplifier / Overcharge / Rapid Bolt in ModCard. Currently uses existing iconography — only behavior changes in this scope.
- Electric Zone (separate spell, similar chain mechanic, not in this redesign).
- Adding a "static field" DoT mod to lightning (raised during brainstorming, rejected — would expand scope).

---

## Open Questions

None at design time. All clarifications resolved during brainstorm:

- Style → A (Classic Arcane)
- Impact → C (Fork Burst) on BurstParticles2D
- Mods → A (visual-only) with per-mod specifics
- Chain on levels → A (remove all chain_count_add from levels)

## Self-Review

- ✅ No "TBD" or "TODO" placeholders.
- ✅ All sections internally consistent (style → bolt → impact → chain removal → mods all aligned with Classic Arcane direction).
- ✅ Scope is bounded to Lightning Strike + 1 new scene + 4 modified files.
- ✅ No ambiguity in mechanics: chain removal is "all of it, only mods add chains".

Ready for implementation plan.
