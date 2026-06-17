# Artifact Unique Passive Effects — Design Spec

## Goal
Replace some existing artifacts with ones that have triggered/circumstantial passive abilities instead of (or in addition to) flat stat bonuses.

## Architecture
- **New file**: `Systems/Artifacts/ArtifactAbilityRunner.gd` — autoload that manages all triggered artifact effects
- **New EffectTypes** in `ArtifactEffect.gd`: `SECOND_WIND`, `SPELL_ECHO`, `TINY_MENACE`, `STATIC_AURA`, `OVERFLOW`, `CRIT_CASCADE`
- **Modified**: `ArtifactManager.gd` — on equip, registers triggered effects in ArtifactAbilityRunner
- **Modified**: `ArtifactData.gd` — stores optional `extra_value: float` for effect configuration (cooldowns, radii, etc.)
- **Modified**: `Spell.gd` — `roll_crit_mult()` tracks `_last_crit_rolled` + getter `was_last_crit()`
- **Modified**: `RunTracker.gd` — `record_damage(dmg, is_crit=false)` emits `EventBus.crit_landed`
- **Modified**: `SpellCaster.gd` — emits `EventBus.spell_cast` on each cast
- **33+ behavior files**: add `if _spell.was_last_crit(): ArtifactAbilityRunner.notify_crit(pos, dmg)` after each damage variable assignment

## Effects Detail

### 1. SECOND_WIND (Replaces Warden's Oath, Rare)
- **Trigger**: `player_damaged` → check `current_hp / max_hp < 0.25`
- **Effect**: Heal 50% max HP over 3s (linear regen)
- **Cooldown**: 60s
- **State**: `_sw_cooldown: float`, `_sw_timer: float`, `_sw_active: bool`
- **VFX**: Green burst on trigger + shimmer during heal

### 2. SPELL_ECHO (Replaces Celestial Orb, Legendary)
- **Trigger**: `EventBus.spell_cast` (emitted from SpellCaster on each cast)
- **Counter**: `_echo_count: int` 1→10, resets on 10
- **Effect**: On 10th cast, re-call `SpellCaster.cast()` for the same spell
- **Guard**: `_is_echoing: bool` prevents recursive echo
- **Edge**: Counter is global (not per-spell), echo cast does NOT increment counter

### 3. TINY_MENACE (Replaces Shadow Step, Uncommon → Rare)
- **Bonus**: +5% dodge chance (existing `bonuses`)
- **Effect**: `player.scale = Vector3(0.75, 0.75, 0.75)` on equip, reset on game start
- **Impl**: Stored as meta `original_scale`, restored on game restart

### 4. STATIC_AURA (Replaces Tempest Crown, Legendary)
- **Effect**: Enemies within 80 units take 15% more damage
- **Impl**: Area2D child (CircleShape2D, radius 80) created on `artifact_equipped`
- **Method A (simple)**: `_process` checks enemies in radius → sets `meta("statik_aura_vuln", true)`; `damage_area()` reads meta for each enemy
- **Method B (simpler)**: `_process` each 0.25s marks enemies in SwarmManager/EnemyMeshManager; `damage_area()` multiplies damage for marked enemies

### 5. OVERFLOW (Replaces Soul Harvest, Legendary)
- **Mechanic**: Each XP pickup converts `amount * 0.25` HP as overheal (HP above max)
- **Decay**: While `current_hp > max_hp`, lose 1 HP/s
- **State**: `_overflow_active: bool`, `_overflow_amount: float`
- **VFX**: Blue sparkle on XP pick up, subtle glow while overhealed
- **Data**: store in `player.stats` as meta `overflow_hp`

### 6. CRIT_CASCADE (Replaces Blood Crown, Legendary)
- **Mechanic**: Every critical hit spawns a shockwave (100 radius, 50% crit damage)
- **Cooldown**: 0.5s between waves
- **Crit detection**: `Spell.roll_crit_mult()` saves to `_last_crit_rolled`; `was_last_crit()` getter
- **One-liner**: After each `roll_crit_mult()` call in behaviors, add `if _spell.was_last_crit(): ArtifactAbilityRunner.notify_crit(pos, dmg)`
- **RunTracker**: `record_damage(dmg, is_crit=false)` emits `EventBus.crit_landed` if `is_crit`

## Artifacts Replaced
| Old Artifact | Rarity | New Artifact | Effect Type |
|---|---|---|---|
| Warden's Oath | Uncommon | Tiny Menace | TINY_MENACE + DODGE_CHANCE |
| Shadow Step | Uncommon | *(merge into Iron Will?)* | — |
| Celestial Orb | Legendary | Spell Echo | SPELL_ECHO + DAMAGE_MULT |
| Soul Harvest | Legendary | Overflow | OVERFLOW |
| Tempest Crown | Legendary | Static Aura | STATIC_AURA |
| Blood Crown | Legendary | Cascade | CRIT_CASCADE |
| Warden's Oath | Uncommon | *(replace with new)* | SECOND_WIND |

## Files Changed
- NEW: `Systems/Artifacts/ArtifactAbilityRunner.gd`
- MOD: `Systems/Artifacts/ArtifactEffect.gd` — +6 EffectTypes
- MOD: `Systems/Artifacts/ArtifactData.gd` — +`extra_value: float`
- MOD: `Autoload/ArtifactManager.gd` — register triggers on equip; replace artifact entries
- MOD: `Spells/Resources/Spell.gd` — `_last_crit_rolled` + `was_last_crit()`
- MOD: `Autoload/RunTracker.gd` — `record_damage(dmg, is_crit=false)`
- MOD: `Spells/Casters/SpellCaster.gd` — emit `spell_cast` on cast
- MOD: 33+ behavior files — one-liner crit check
- MOD: `Autoload/EventBus.gd` — +`crit_landed` signal
