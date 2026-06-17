# MS (Magic Survival clone) — AGENTS.md

## Goal
Create a complete Magic Survival–style game in Godot 4.6.4 (GDScript). This file is the persistent project summary used by AI coding agents for cross-session continuity.

## Active / Just Done
- **Fusion Grimoire pause/resume during BOSS_FIGHT**: DONE ✅ — `GameManager.pause_game()` now accepts `BOSS_FIGHT` (saves state in `_pause_saved_state`), `resume_game()` restores it. Fusion menu now properly pauses game during boss fight.
- **mod_name→mod_id migration**: DONE ✅ — All 4 files (SpiritBehavior, CycloneBehavior, RayBehavior, NeedleBehavior) already use `mod_id == &"..."`. No `mod_name ==` comparisons remain anywhere.
- **PoisonPoolBehavior mod_type fix**: DONE ✅ — `mod_bloom`→`ON_KILL_EXPLODE`, `mod_miasma`→`AREA_BOOST`, `mod_plague`→`TICK_RATE` (was already correct)
- **VFX death differentiation + leak removal**: DONE ✅ — `BaseEnemy.gd:_get_death_type()` now handles RAMPAGE→"rampage". `JuiceManager.spawn_death_effect()` no longer calls leaking `VFXCatalog.play_effect()`. All death effects use pooled BurstEffectPool only.

## Constraints & Preferences
- Godot 4.6.2+, GDScript ONLY
- No `.tscn` files for UI — all UI built programmatically
- FusionSpell.max_level = 1, extends Spell (NOT SpellData)
- `class_name` NOT used in autoloads
- StyleBoxFlat: use `set_corner_radius_all(n)`, NOT property assignment
- Buffs: green (+ prefix), Debuffs: red (- prefix). No emojis.
- Use `hint_screen_texture` uniform in shaders, NOT `SCREEN_TEXTURE`
- `.mod_name ==` string comparisons → convert to `.mod_id == &"..."` (StringName)
- Bosses: Color.WHITE body, NO projectile attacks, ×2–2.67 size of regular enemies
- Spawn: pulse waves, ~70% from behind player, gentle first 30s

## Completed Work
- **Project scaffolding**: main.tscn, GameManager autoload with state machine, Player (WASD+鼠标), basic EnemyEmitter, Camera
- **Spell system**: 6 base spells (fireball, lightning, ice shard, arcane orb, spirit orb, blade), casting with cooldown, auto-targeting, 5 modifications each (30 total mods with unique mod_id), 10 mod slots via LevelUpManager
- **Fusion system**: SpellFusionManager autoload, 19 fusion recipes with mod_id keys, FusionSpell extends Spell, FusionGrimoire UI (two-level: mini cards + detail overlay), fusion hints in ModificationScreen
- **Enemy system**: SwarmManager (GDSpawner-based), 6 types with varied prediction (chaser/interceptor), Target Prediction with distance/angle weighting, 2-phase interpolation, EnemyMeshManager with mesh variety 0-3, hit effect/arm flash, BurstEffectPool (500 pool, 30/sec throttle, 60 frame limit), **spawn fade-in** (scale 0→1 over 0.17s on all enemies)
- **Boss system**: BossManager with 5 boss types, 5-phase arena (4 min each with ShaderMaterial overlay + invisible walls), Color.WHITE body (no phase tint), per-boss tuning (attack/minion intervals), enrage phase at <30% HP (1.5× damage, 1.3× range, EventBus.boss_enraged signal), NO projectile attacks (all replaced with AoE/charge/summon), boss death detection + artifact pickup → game win
- **Difficulty**: DifficultyManager with `1 + minute×0.10 + (minute/15)²×1.8` formula
- **Player**: movement (WASD/arrows), dash (Space), dodge mechanics (cyan visual), shield (1s invuln), PLAYER_AVOID_FORCE=50, size -15%
- **UI**: HUD (spell cards + fusions button + minimap), LevelUpScreen (3-level card layout with rarity colors), FusionGrimoire, ModificationScreen (fusion hints), SettingsScreen (translations), ArtifactSlotsScreen (7 columns × 30 slots), GameOverScreen (clip_contents + size_flags fix), PauseScreen, MainMenu
- **XP/Chests**: full XP curve, chest spawns every 40s (max 3, retry on limit), artifacts from bosses
- **VFX**: 5 death scenes (default/fire/cold/arcane/rage), shockwave shader, BurstEffectPool (500 pool)
- **Bug fixes**: BossShockwave.gd reparent (remove_child before add_child) ✅, shockwave.gdshader `SCREEN_TEXTURE`→`hint_screen_texture` ✅, BurstParticles2D null RID guard ✅, VFXCatalog critical leak (repeat=false — was spawning 12697 orphan objects) ✅

## Key Architecture Decisions
- **FusionSpell extends Spell** (runtime object with behavior, NOT SpellData)
- **Recipes keyed by StringName mod_id**: `_make_key(a, b)` with lexicographic order
- **Fusion cards = EPIC rarity** (orange)
- **Fusion Grimoire pauses game** on open via `pause_game()`/`resume_game()`
- **19 fusions**: InfernoNova, Thunderbolt, AstralSwarm, Firenado, ToxicNeedles, ArcanePrison, PhotonStorm, PhaseBolt, GalvanicChain, ArcOverload, SeismicPulse, PhantomOrbit, SoulBurst, BladeVortex, CrystalAegis, FlameWard, MirrorShards, FrostLance, ToxicBloom
- **Boss modulate = Color.WHITE**: vignette (edge darkening) via SwarmShader, no color tint
- **Bosses don't shoot**: replaced `_fire_projectiles` with `_explode_nearby` (medium), `_ground_slam` (big/overlord), `_charge_attack` (rampage), `_summon_boss_minions` (overlord)
- **Boss HP**: `500 + player.max_hp × 2`
- **Boss sizes (new)**: medium_boss=160, mine_boss=170, big_boss=380, rampage_boss=240, overlord_boss=350
- **Spawn system**: pulse waves with rear-bias replacing continuous trickle + edge wave
- **BossArena**: CanvasLayer overlay (layer 10), FRAGCOORD shader, dynamic radius = 2.0× screen max(half_w, half_h), 24 perimeter segments as wall (not CircleShape — was pushing player outward)
- **Boss fight → chest → exit flow**: Boss dies → chest spawns → arena stays active, everything paused → player picks up chest → exit_boss_fight() → arena deactivates → spawns resume
- **Pull mechanics**: CycloneVortex HAS gravity pull (`_gravity_pull`, `_pull_strength`, `_pull_range`, calls SwarmManager/EnemyMeshManager pull_toward)
- **Reflect mechanics**: ArcaneRay HAS reflect (`_reflect` flag, bounce from viewport edges)
- **Boss HP check**: `500 + player.max_hp × 2`
- **BurstEffectPool**: pool 500, throttle 30/sec, frame limit 60

## Pending Work (Priority Order)
- (all items complete — no pending work remaining)

## Relevant Files
- `WaveManager.gd`: fixed ✅ — pulse spawn system (no trickle, no edge wave, rear-bias)
- `BossManager.gd`: fixed ✅ — no projectiles, per-boss tuning, enrage
- `EnemyMeshManager.gd`: fixed ✅ — boss sizes increased, spawn_fade
- `BossArena.gd`: fixed ✅ — CanvasLayer overlay, FRAGCOORD shader, dynamic radius
- `EventBus.gd`: `boss_enraged` signal added ✅
- `VFXCatalog.gd`: **REMOVED** — dead code, no callers. Cleaned up autoload ✅
- `BurstParticles2D.gd`: null RID guard ✅
- `BossShockwave.gd` / `shockwave.gdshader`: fixed ✅
- `SpellFusionManager.gd`: 19 recipes, find_recipes helpers ✅
- `ModificationScreen.gd`: fusion hints ✅
- `SettingsManager.gd`: translations ✅
- `DifficultyManager.gd`: needs special_event_interval fix ✅ — dynamic 45→20s
- `BurstEffectPool.gd`: death VFX differentiation — 5 scenes already mapped, RAMPAGE fix applied ✅
- `GameManager.gd`: pause_game/resume_game handles BOSS_FIGHT with _pause_saved_state ✅
- `BaseEnemy.gd`: _get_death_type() handles RAMPAGE → "rampage" ✅
- `JuiceManager.gd`: spawn_death_effect no longer calls VFXCatalog.play_effect() ✅
