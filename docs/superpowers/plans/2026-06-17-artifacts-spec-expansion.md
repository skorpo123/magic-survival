# Artifacts Spec Expansion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ~28 new artifacts with 3 new effect types (BOSS_DAMAGE_MULT, ON_KILL_REGEN, PIERCE_COUNT, MISSING_HP_DAMAGE), spell-ID targeting, and wire all mechanics into the existing systems.

**Architecture:** Extend existing ArtifactManager with a shared `_matches()` predicate, new cached/dynamic accessors, and a 7th `target_spell_ids` param on `_add_artifact()`. Hook boss damage in EnemyMeshManager, pierce/missing-HP in Spell.gd, regen-disable/on-kill in Player.gd, special artifact flags in ArtifactAbilityRunner, formatting in ArtifactCard, and translations in SettingsManager. All existing artifacts keep working — `target_spell_ids` is additive.

**Tech Stack:** GDScript, Godot 4.6.2+

---

## File Map

| File | Change |
|------|--------|
| `Autoload/ArtifactManager.gd` | Cache vars, `_matches()`, `_add_artifact()` 7th param, new accessors, catalog |
| `Spells/Resources/Spell.gd` | `get_pierce()` + artifact pierce; `get_damage()` + missing HP mult |
| `Systems/EnemyMeshManager.gd` | Boss damage mult in 6 damage functions |
| `Entities/Player/Player.gd` | Regen disable guard, ON_KILL_REGEN heal |
| `Autoload/ArtifactAbilityRunner.gd` | Twin Cast, Gambler's Dice, Berserker's Oath, on-kill zones |
| `UI/ArtifactCard.gd` | Format cases for 4 new effect types |
| `Autoload/SettingsManager.gd` | Translation keys for 28 artifacts + 4 new effect labels |

---

## Task 1: ArtifactManager Core System Wiring

**Files:**
- Modify: `Autoload/ArtifactManager.gd`

**Steps:**

- [ ] **Step 1: Add cache vars for new effects**

Add after line 19 (`_cached_duration_mult`):
```gdscript
var _cached_boss_damage_mult: float = 1.0
var _cached_on_kill_regen: float = 0.0
var _cached_pierce_add: int = 0
var _cached_missing_hp_damage_mult: float = 1.0
```

- [ ] **Step 2: Add to `_reset_cache()`**

Add inside `_reset_cache()` after line 58:
```gdscript
_cached_boss_damage_mult = 1.0
_cached_on_kill_regen = 0.0
_cached_pierce_add = 0
_cached_missing_hp_damage_mult = 1.0
```

- [ ] **Step 3: Add shared `_matches()` predicate**

Add after `_is_global_artifact()` (line 61):
```gdscript
func _matches(artifact: ArtifactData, spell_name: StringName, spell_type: StringName) -> bool:
	if artifact.target_spell_ids.size() > 0:
		return spell_name in artifact.target_spell_ids
	return (artifact.target_spell_name == &"" or artifact.target_spell_name == spell_name) and (artifact.target_spell_type == &"" or artifact.target_spell_type == spell_type)
```

- [ ] **Step 4: Update `_apply_cache_delta()` for new effect types**

Add before the `_:` default case in `_apply_cache_delta()` (before line 510):
```gdscript
ArtifactEffect.EffectType.BOSS_DAMAGE_MULT:
	if sign > 0:
		_cached_boss_damage_mult *= eff.value
	else:
		_cached_boss_damage_mult /= eff.value
ArtifactEffect.EffectType.ON_KILL_REGEN:
	_cached_on_kill_regen += eff.value * sign
ArtifactEffect.EffectType.PIERCE_COUNT:
	_cached_pierce_add += int(eff.value) * int(sign)
ArtifactEffect.EffectType.MISSING_HP_DAMAGE:
	if sign > 0:
		_cached_missing_hp_damage_mult *= eff.value
	else:
		_cached_missing_hp_damage_mult /= eff.value
```

- [ ] **Step 5: Update all 3 spell-specific helpers to use `_matches()`**

Replace the inline matching in `get_spell_multiplier()` (line 574), `get_chain_count_add()` (line 585), and `get_extra_projectile_count()` (line 596) with calls to `_matches(artifact, spell_name, spell_type)`.

- [ ] **Step 6: Add new public API accessors**

Add after `get_duration_mult()` (line 552):
```gdscript
func get_boss_damage_mult() -> float:
	return _cached_boss_damage_mult

func get_on_kill_regen() -> float:
	return _cached_on_kill_regen

func get_pierce_add(spell_name: StringName, spell_type: StringName) -> int:
	var add := 0
	for artifact in equipped:
		if not _matches(artifact, spell_name, spell_type):
			continue
		for bonus in artifact.bonuses:
			if bonus.effect_type == ArtifactEffect.EffectType.PIERCE_COUNT:
				add += int(bonus.value)
	return add

func get_missing_hp_damage_mult() -> float:
	return _cached_missing_hp_damage_mult

func regen_disabled() -> bool:
	for artifact in equipped:
		for bonus in artifact.bonuses:
			if bonus.effect_type == ArtifactEffect.EffectType.BERSERKER_OATH:
				return true
	return false
```

- [ ] **Step 7: Add dynamic bonus to `get_cooldown_reduce()`**

Update `get_cooldown_reduce()` to include Clockwork Cog scaling:
```gdscript
func get_cooldown_reduce() -> float:
	var extra := 0.0
	if has_artifact("Clockwork Cog"):
		extra = floorf(float(GameManager.enemies_killed) / 100.0) * 0.05
		extra = minf(extra, 0.15)
	return clampf(_cached_cooldown_reduce + extra, 0.0, 0.75)
```

- [ ] **Step 8: Add dynamic bonus to `get_damage_mult()`**

Update `get_damage_mult()` to include Scholar's Monocle and Gambler's Dice:
```gdscript
func get_damage_mult() -> float:
	var extra := 1.0
	if has_artifact("Scholar's Monocle"):
		extra *= (1.0 + floorf(float(GameManager.current_level) / 5.0) * 0.05)
	if has_artifact("Gambler's Dice"):
		extra *= ArtifactAbilityRunner.get_gambler_damage_mult()
	return _cached_damage_mult * extra
```

- [ ] **Step 9: Update `_add_artifact()` signature to accept target_spell_ids**

Change signature from:
```gdscript
func _add_artifact(en_name: String, ru_name: String, en_desc: String, ru_desc: String,
		rarity: int, target_type: StringName,
		bonuses: Array[ArtifactEffect], debuffs: Array[ArtifactEffect]) -> void:
```
to:
```gdscript
func _add_artifact(en_name: String, ru_name: String, en_desc: String, ru_desc: String,
		rarity: int, target_type: StringName,
		bonuses: Array[ArtifactEffect], debuffs: Array[ArtifactEffect],
		target_ids: Array[StringName] = []) -> void:
```

Add `a.target_spell_ids = target_ids` after line 81 (`a.debuffs = debuffs`).

---

## Task 2: Spell.gd — Pierce + Missing HP Damage

**Files:**
- Modify: `Spells/Resources/Spell.gd`

**Steps:**

- [ ] **Step 1: Add artifact pierce to `get_pierce()`**

Update `get_pierce()` (line 73):
```gdscript
func get_pierce() -> int:
	var p: int = pierce
	if current_level > 1 and level_data.size() >= current_level - 1:
		p += level_data[current_level - 2].pierce_add
	if active_modification:
		p += active_modification.pierce_add
	var t := _get_spell_type_static()
	p += ArtifactManager.get_pierce_add(spell_id, t)
	return p
```

- [ ] **Step 2: Add missing HP damage mult to `get_damage()`**

Update `get_damage()` (line 41) — add after the existing multiplier line (line 48):
```gdscript
func get_damage(player_magic_power: float = 1.0) -> float:
	var dmg: float = base_damage * player_magic_power
	if current_level > 1 and level_data.size() >= current_level - 1:
		dmg *= level_data[current_level - 2].damage_multiplier
	if active_modification:
		dmg *= active_modification.damage_multiplier
	var t := _get_spell_type_static()
	dmg *= ArtifactManager.get_spell_multiplier(spell_id, t, ArtifactEffect.EffectType.DAMAGE_MULT)
	# Martyr's Brand: damage scales with missing HP
	var mmult := ArtifactManager.get_missing_hp_damage_mult()
	if mmult > 1.0:
		var player := GameManager.get_player()
		if player and "stats" in player and player.stats:
			var stats: PlayerStats = player.stats
			var missing_pct := 1.0 - (stats.current_hp / stats.max_hp)
			dmg *= 1.0 + (mmult - 1.0) * missing_pct
	return dmg
```

---

## Task 3: EnemyMeshManager Boss Damage Hook

**Files:**
- Modify: `Systems/EnemyMeshManager.gd`

**Steps:**

- [ ] **Step 1: Add boss damage mult helper**

Add at top of file (after existing vars, before first function):
```gdscript
func _boss_dmg_mult(key: String) -> float:
	if key.ends_with("_boss"):
		return ArtifactManager.get_boss_damage_mult()
	return 1.0
```

- [ ] **Step 2: Apply in `damage_area()`**

In `damage_area()`, change line 803 from:
```gdscript
d[off + I_HP] -= amount * aura_mult
```
to:
```gdscript
d[off + I_HP] -= amount * aura_mult * _boss_dmg_mult(key)
```

- [ ] **Step 3: Apply in `damage_nearest()`**

In `damage_nearest()`, change line 878 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(best_key)
```

- [ ] **Step 4: Apply in `damage_line()`**

In `damage_line()`, change line 1121 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 5: Apply in `damage_rect()`**

In `damage_rect()`, change line 1179 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 6: Apply in `damage_rect_filtered()`**

In `damage_rect_filtered()`, change line 1240 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 7: Apply in `damage_cone()`**

In `damage_cone()`, change line 1313 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 8: Apply in `damage_id()`**

In `damage_id()`, change line 1401 from:
```gdscript
d[off + I_HP] -= amount
```
to:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

---

## Task 4: Player.gd — Regen Disable + On-Kill Regen

**Files:**
- Modify: `Entities/Player/Player.gd`

**Steps:**

- [ ] **Step 1: Guard regen with Berserker's Oath check**

In `_process()`, change line 168 from:
```gdscript
if stats.hp_regen > 0.0:
```
to:
```gdscript
if stats.hp_regen > 0.0 and not ArtifactManager.regen_disabled():
```

- [ ] **Step 2: Add ON_KILL_REGEN heal in `_on_enemy_died_event()`**

In `_on_enemy_died_event()` (line 258), add after the Soul Harvest check (line 260):
```gdscript
func _on_enemy_died_event(_pos: Vector2, xp_value: float, _enemy_type: StringName) -> void:
	if ArtifactManager.has_artifact("Soul Harvest"):
		heal(1.0)
	var on_kill_regen := ArtifactManager.get_on_kill_regen()
	if on_kill_regen > 0.0:
		heal(on_kill_regen)
	var life_steal: float = 0.0
	if stats:
		life_steal = stats.life_steal
	if life_steal > 0.0:
		heal(xp_value * life_steal * 2.0)
```

---

## Task 5: ArtifactAbilityRunner — Special Artifact Wiring

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

**Steps:**

- [ ] **Step 1: Add new flags and state vars**

Add after line 14 (`var _trail_timer: float = 0.0`):
```gdscript
var _twin_cast_chance: float = 0.0
var _berserker_oath: bool = false
var _gambler_timer: float = 0.0
var _gambler_active: bool = false
var _gambler_mult: float = 1.0
var _gambler_is_double: bool = false
```

Add after line 26 (`var _has_damage_aura: bool = false`):
```gdscript
var _has_twin_cast: bool = false
var _has_berserker_oath: bool = false
var _has_gambler_dice: bool = false
var _has_toxic_bloom: bool = false
var _has_volcanic_glyph: bool = false
```

- [ ] **Step 2: Reset new state in `_on_game_started()`**

Add inside `_on_game_started()` after line 45 (`_trail_timer = 0.0`):
```gdscript
_gambler_timer = 0.0
_gambler_active = false
_gambler_mult = 1.0
_twin_cast_chance = 0.0
```

Add after line 58 (`_has_spell_split = false`):
```gdscript
_has_twin_cast = false
_has_berserker_oath = false
_has_gambler_dice = false
_has_toxic_bloom = false
_has_volcanic_glyph = false
```

- [ ] **Step 3: Handle new effects in `_on_artifact_equipped()`**

Add new cases inside the match block in `_on_artifact_equipped()` (after line 93):
```gdscript
ArtifactEffect.EffectType.TWIN_CAST:
	_has_twin_cast = true
	_twin_cast_chance = maxf(_twin_cast_chance, bonus.value)
ArtifactEffect.EffectType.BERSERKER_OATH:
	_has_berserker_oath = true
ArtifactEffect.EffectType.GAMBLER_DICE:
	_has_gambler_dice = true
	_gambler_timer = 30.0
ArtifactEffect.EffectType.TOXIC_BLOOM:
	_has_toxic_bloom = true
ArtifactEffect.EffectType.VOLCANIC_GLYPH:
	_has_volcanic_glyph = true
```

- [ ] **Step 4: Add Twin Cast to `_on_spell_cast()`**

Add before line 126 (`if _has_spell_split`):
```gdscript
if _has_twin_cast and not _is_echoing:
	if randf() < _twin_cast_chance:
		_trigger_twin_cast(spell_name)
```

Add the `_trigger_twin_cast()` function (copy pattern from `_trigger_echo`):
```gdscript
func _trigger_twin_cast(spell_name: StringName) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	for child in player.get_children():
		if child is Node2D and child.has_method("notify_spell_upgraded") and "spell" in child:
			if child.spell and child.spell.spell_id == spell_name:
				_is_echoing = true
				var ps: PlayerStats = null
				if "stats" in player and player.stats is PlayerStats:
					ps = player.stats
				child.spell.behavior.cast(child, child.spell, ps)
				_is_echoing = false
				BurstEffectPool.spawn("explosion", player.global_position, Color(0.6, 0.3, 1.0))
				return
```

- [ ] **Step 5: Add Gambler's Dice timer to `_process()`**

Add inside `_process()` before the final `if _has_move_trail`:
```gdscript
if _has_gambler_dice:
	_process_gambler_dice(delta)
```

Add the processing function:
```gdscript
func _process_gambler_dice(delta: float) -> void:
	if _gambler_active:
		_gambler_timer -= delta
		if _gambler_timer <= 0.0:
			_gambler_active = false
			_gambler_mult = 1.0
			_gambler_timer = 30.0
	else:
		_gambler_timer -= delta
		if _gambler_timer <= 0.0:
			_gambler_active = true
			_gambler_is_double = randf() > 0.5
			_gambler_mult = 2.0 if _gambler_is_double else 0.5
			_gambler_timer = 5.0

func get_gambler_damage_mult() -> float:
	if _gambler_active:
		return _gambler_mult
	return 1.0
```

- [ ] **Step 6: Add on-kill zones for Toxic Bloom and Volcanic Glyph**

Update `_on_enemy_died()` (line 210):
```gdscript
func _on_enemy_died(pos: Vector2, _xp: float, _type: StringName) -> void:
	if _has_low_hp_explode:
		var player := GameManager.get_player()
		if player:
			var mp: float = 1.0
			if "stats" in player and player.stats is PlayerStats:
				mp = player.stats.magic_power
			var explode_dmg := 15.0 * mp
			SwarmManager.damage_area(pos, 70.0, explode_dmg)
			EnemyMeshManager.damage_area(pos, 70.0, explode_dmg)
			BurstEffectPool.spawn("explosion", pos, Color(1.0, 0.5, 0.1))
	if _has_toxic_bloom and randf() < 0.20:
		_spawn_toxic_bloom_zone(pos)
	if _has_volcanic_glyph:
		_spawn_volcanic_trail(pos)
```

Add helper functions:
```gdscript
func _spawn_toxic_bloom_zone(pos: Vector2) -> void:
	var zone := DamageZone.new()
	zone.damage = 8.0
	zone.radius = 60.0
	zone.tick_interval = 0.5
	zone.duration = 2.0
	zone.damage_type = &"cold"
	var player := GameManager.get_player()
	if player:
		player.get_parent().add_child(zone)
		zone.global_position = pos
		BurstEffectPool.spawn("explosion", pos, Color(0.2, 0.8, 0.2, 0.4))

func _spawn_volcanic_trail(pos: Vector2) -> void:
	var zone := DamageZone.new()
	zone.damage = 5.0
	zone.radius = 40.0
	zone.tick_interval = 0.5
	zone.duration = 1.5
	zone.damage_type = &"fire"
	var player := GameManager.get_player()
	if player:
		player.get_parent().add_child(zone)
		zone.global_position = pos
```

---

## Task 6: ArtifactCard.gd — Format New Effect Types

**Files:**
- Modify: `UI/ArtifactCard.gd`

**Steps:**

- [ ] **Step 1: Add format cases for new effect types**

Add after line 252 (`ArtifactEffect.EffectType.DAMAGE_AURA:`):
```gdscript
ArtifactEffect.EffectType.BOSS_DAMAGE_MULT:
	val_str = "%s%.0f%% %s" % [sign_str, absf(pct), SettingsManager.t(&"eff_boss_dmg")]
ArtifactEffect.EffectType.ON_KILL_REGEN:
	val_str = "+%.1f %s" % [effect.value, SettingsManager.t(&"eff_onkill_regen")]
ArtifactEffect.EffectType.PIERCE_COUNT:
	val_str = "+%d %s" % [int(effect.value), SettingsManager.t(&"eff_pierce")]
ArtifactEffect.EffectType.MISSING_HP_DAMAGE:
	val_str = _resolve_desc()
```

Also add these special effect types that use `_resolve_desc()` (for artifacts whose description IS the effect text):
```gdscript
ArtifactEffect.EffectType.TWIN_CAST:
	val_str = _resolve_desc()
ArtifactEffect.EffectType.BERSERKER_OATH:
	val_str = _resolve_desc()
ArtifactEffect.EffectType.GAMBLER_DICE:
	val_str = _resolve_desc()
ArtifactEffect.EffectType.TOXIC_BLOOM:
	val_str = _resolve_desc()
ArtifactEffect.EffectType.VOLCANIC_GLYPH:
	val_str = _resolve_desc()
```

---

## Task 7: SettingsManager — Translations

**Files:**
- Modify: `Autoload/SettingsManager.gd`

**Steps:**

- [ ] **Step 1: Add new effect label translations**

Add after line 379 (`eff_damage_aura`):
```gdscript
_add(&"eff_boss_dmg", "boss dmg", "урон боссам")
_add(&"eff_onkill_regen", "HP/kill", "HP/убийство")
_add(&"eff_pierce", "pierce", "пробитие")
_add(&"eff_twin_cast", "20% double cast", "20% двойной каст")
_add(&"eff_berserker_oath", "No regen, x1.5 dmg", "Без регена, x1.5 урон")
_add(&"eff_gambler_dice", "Random x0.5/x2 every 30s", "Случайно x0.5/x2 каждые 30с")
_add(&"eff_toxic_bloom", "Kill → poison zone", "Убийство → ядовитая зона")
_add(&"eff_volcanic_glyph", "Kill → fire trail", "Убийство → огненный след")
```

- [ ] **Step 2: Add all 28 artifact translation entries**

Add each artifact's `art_*` and `art_desc_*` keys. The pattern is:
```gdscript
_add(&"art_<snake_name>", "English Name", "Русское название")
_add(&"art_desc_<snake_name>", "English description", "Русское описание")
```

Full list of artifacts to add (28 total):

**POISON (4):**
- plague_sigil: "Plague Sigil" / "Печать чумы"
- venom_codex: "Venom Codex" / "Ядовитый кодекс"
- toxic_bloom_art: "Toxic Bloom" / "Токсичный цветок"
- miasma_flask: "Miasma Flask" / "Фляга миазмов"

**SPIRIT (4):**
- soul_lantern: "Soul Lantern" / "Фонарь душ"
- wraith_mantle: "Wraith Mantle" / "Плащ призрака"
- phantom_seal: "Phantom Seal" / "Печать призрака"
- haunt_essence: "Haunt Essence" / "Эссенция проклятия"

**PHYSICAL (3):**
- whetstone: "Whetstone" / "Точильный камень"
- blade_rune: "Blade Rune" / "Руна клинка"
- executioner_s_brand: "Executioner's Brand" / "Клеймо палача"

**GLOBAL (10):**
- orbweaver_s_thread: "Orbweaver's Thread" / "Нить орбиты"
- clockwork_cog: "Clockwork Cog" / "Шестерёнка"
- focus_gem: "Focus Gem" / "Камень фокуса"
- scholar_s_monocle: "Scholar's Monocle" / "Монокль учёного"
- echo_sigil: "Echo Sigil" / "Печать эха"
- wind_totem: "Wind Totem" / "Тотем ветра"
- death_bell: "Death Bell" / "Колокол смерти"
- iron_aegis: "Iron Aegis" / "Железный аegis"
- abyssal_lens: "Abyssal Lens" / "Бездонная линза"
- arcane_amplifier: "Arcane Amplifier" / "Тайный усилитель"

**ELEMENT (3):**
- glacial_core: "Glacial Core" / "Ледяное ядро"
- conductor_s_rod: "Conductor's Rod" / "Стержень проводника"
- volcanic_glyph: "Volcanic Glyph" / "Вулканический glyph"

**RISKY (5):**
- martyr_s_brand: "Martyr's Brand" / "Клеймо мученика"
- twin_cast: "Twin Cast" / "Двойной каст"
- berserker_s_oath: "Berserker's Oath" / "Клятва берсерка"
- arcane_overload: "Arcane Overload" / "Перегрузка магии"
- gambler_s_dice: "Gambler's Dice" / "Кости игрока"

**LEGENDARY (3):**
- void_codex: "Void Codex" / "Кодекс пустоты"
- inferno_grimoire: "Inferno Grimoire" / "Гrimуар инферно"
- absolute_zero: "Absolute Zero" / "Абсолютный ноль"

**FUSION (3):**
- firenado_lens: "Firenado Lens" / "Линза Огненного вихря"
- thunderbolt_coil: "Thunderbolt Coil" / "Катушка молнии"
- crystal_aegis_shard: "Crystal Aegis Shard" / "Осколок Кристального аegis"

---

## Task 8: ArtifactManager — Full Catalog

**Files:**
- Modify: `Autoload/ArtifactManager.gd`

**Steps:**

- [ ] **Step 1: Define spell-ID group constants**

Add at top of `_build_catalog()` after `_catalog.clear()`:
```gdscript
var POISON_IDS: Array[StringName] = [&"poison_pool"]
var SPIRIT_IDS: Array[StringName] = [&"spirit"]
var PHYSICAL_IDS: Array[StringName] = [&"needle", &"orbiting_arcana", &"cyclone"]
var FIRE_IDS: Array[StringName] = [&"fireball", &"fire_breath"]
var LIGHTNING_IDS: Array[StringName] = [&"lightning_strike", &"electric_zone"]
var COLD_IDS: Array[StringName] = [&"frost_nova", &"needle"]
var ARCANE_IDS: Array[StringName] = [&"magic_bolt", &"arcane_ray", &"cyclone", &"orbiting_arcana"]
```

- [ ] **Step 2: Append all 28 new artifacts**

Add after the existing catalog entries (after the `SPELL_WEAVER` entry). Each uses the updated 7-param `_add_artifact()`.

**POISON group:**
```gdscript
_add_artifact("Plague Sigil", "Печать чумы",
	"+30% poison damage, poison zones tick 25% faster", "+30% урон яда, ядовитые зоны тикают на 25% чаще",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.25)],
	[], POISON_IDS)

_add_artifact("Venom Codex", "Ядовитый кодекс",
	"+40% poison damage, +35% poison area, -10% move speed", "+40% урон яда, +35% область яда, -10% скорость",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.AREA_MULT, 1.35)],
	[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)], POISON_IDS)

_add_artifact("Toxic Bloom", "Токсичный цветок",
	"On kill: 20% chance to create small poison zone (2s)", "При убийстве: 20% шанс создать малую ядовитую зону (2с)",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.TOXIC_BLOOM, 0.2)],
	[], POISON_IDS)

_add_artifact("Miasma Flask", "Фляга миазмов",
	"+50% poison duration, poison slows enemies 20%", "+50% длительность яда, яд замедляет врагов на 20%",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DURATION_MULT, 1.5)],
	[], POISON_IDS)
```

**SPIRIT group:**
```gdscript
_add_artifact("Soul Lantern", "Фонарь душ",
	"+30% spirit damage, spirit projectiles leave damage trails (1s)", "+30% урон духа, духи оставляют следы урона (1с)",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3)],
	[], SPIRIT_IDS)

_add_artifact("Wraith Mantle", "Плащ призрака",
	"+25% spirit damage, +20% projectile speed, +1 spirit projectile", "+25% урон духа, +20% скорость снарядов, +1 дух",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.2), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)],
	[], SPIRIT_IDS)

_add_artifact("Phantom Seal", "Печать призрака",
	"Spirit projectiles crit on first hit, +10% global crit", "Духи критят при первом ударе, +10% глобальный крит",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.1)],
	[], SPIRIT_IDS)

_add_artifact("Haunt Essence", "Эссенция проклятия",
	"+40% spirit damage vs bosses, +0.1 HP per spirit kill", "+40% урон духа по боссам, +0.1 ОЗ за убийство духом",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.ON_KILL_REGEN, 0.1)],
	[], SPIRIT_IDS)
```

**PHYSICAL group:**
```gdscript
_add_artifact("Whetstone", "Точильный камень",
	"+15% physical spell damage (Needle, Orbiting Arcana, Cyclone)", "+15% урон физических заклинаний",
	ItemRarity.Tier.COMMON, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15)],
	[], PHYSICAL_IDS)

_add_artifact("Blade Rune", "Руна клинка",
	"+25% physical damage, +1 pierce", "+25% урон физических, +1 пробитие",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.PIERCE_COUNT, 1.0)],
	[], PHYSICAL_IDS)

_add_artifact("Executioner's Brand", "Клеймо палача",
	"+50% damage to enemies below 30% HP", "+50% урон по врагам с HP < 30%",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.5)],
	[], PHYSICAL_IDS)
```

**GLOBAL group:**
```gdscript
_add_artifact("Orbweaver's Thread", "Нить орбиты",
	"+20% orbit speed (Orbiting Arcana), orbits deal damage on contact faster", "+20% скорость орбит, орбиты наносят урон чаще",
	ItemRarity.Tier.COMMON, &"orbiting_arcana",
	[ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.2)], [])

_add_artifact("Clockwork Cog", "Шестерёнка",
	"-10% cooldown, every 100 kills: -5% more (max -25% total)", "-10% перезарядка, каждые 100 убийств: -5% ещё (макс -25%)",
	ItemRarity.Tier.COMMON, &"",
	[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.1)], [])

_add_artifact("Focus Gem", "Камень фокуса",
	"+20% damage to single-target spells", "+20% урон заклинаниям с одной целью",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)], [])

_add_artifact("Scholar's Monocle", "Монокль учёного",
	"+30% XP, every 5 levels: +5% all damage (permanent)", "+30% опыта, каждые 5 уровней: +5% урон всем",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.XP_MULT, 1.3)], [])

_add_artifact("Echo Sigil", "Печать эха",
	"+15% AoE radius for all spells", "+15% радиус AoE всех заклинаний",
	ItemRarity.Tier.COMMON, &"",
	[ae(ArtifactEffect.EffectType.AREA_MULT, 1.15)], [])

_add_artifact("Wind Totem", "Тотем ветра",
	"+20% move speed, +10% projectile speed", "+20% скорость передвижения, +10% скорость снарядов",
	ItemRarity.Tier.COMMON, &"",
	[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 1.2), ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.1)], [])

_add_artifact("Death Bell", "Колокол смерти",
	"+0.3 HP per enemy killed, stacks with Life Steal", "+0.3 ОЗ за убитого врага, стакается с вампиризмом",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.ON_KILL_REGEN, 0.3)], [])

_add_artifact("Iron Aegis", "Железный аegis",
	"+10% dodge, +20% max HP", "+10% уклонение, +20% макс. ОЗ",
	ItemRarity.Tier.UNCOMMON, &"",
	[ae(ArtifactEffect.EffectType.DODGE_CHANCE, 0.1), ae(ArtifactEffect.EffectType.MAX_HP_MULT, 1.2)], [])

_add_artifact("Abyssal Lens", "Бездонная линза",
	"+20% boss damage, +10% projectile speed", "+20% урон боссам, +10% скорость снарядов",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.BOSS_DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.1)], [])

_add_artifact("Arcane Amplifier", "Тайный усилитель",
	"+15% arcane damage, +1 arcane projectile, -15% arcane cooldown", "+15% тайный урон, +1 снаряд, -15% перезарядка",
	ItemRarity.Tier.RARE, &"arcane",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0), ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.15)], [])
```

**ELEMENT group:**
```gdscript
_add_artifact("Glacial Core", "Ледяное ядро",
	"+40% cold duration, +20% cold damage, -10% move speed", "+40% длительность холода, +20% урон холода, -10% скорость",
	ItemRarity.Tier.RARE, &"cold",
	[ae(ArtifactEffect.EffectType.DURATION_MULT, 1.4), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)],
	[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)])

_add_artifact("Conductor's Rod", "Стержень проводника",
	"+30% lightning damage, lightning always chains at least 1 time", "+30% урон молнией, молния всегда передаётся 1 раз",
	ItemRarity.Tier.RARE, &"lightning",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0)], [])

_add_artifact("Volcanic Glyph", "Вулканический glyph",
	"+20% fire damage, fire kills leave burning trail (1.5s)", "+20% огненный урон, убийства огнём оставляют горящий след (1.5с)",
	ItemRarity.Tier.UNCOMMON, &"fire",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.VOLCANIC_GLYPH, 0.0)], [])
```

**RISKY group:**
```gdscript
_add_artifact("Martyr's Brand", "Клеймо мученика",
	"+1% damage per 1% missing HP (max +90% at 10% HP), -20% max HP", "+1% урон за каждый % потерянного HP, -20% макс. ОЗ",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.MISSING_HP_DAMAGE, 1.9)],
	[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.8)])

_add_artifact("Twin Cast", "Двойной каст",
	"20% chance to cast spell twice, +25% cooldown", "20% шанс каста дважды, +25% перезарядка",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.TWIN_CAST, 0.2)],
	[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, -0.25)])

_add_artifact("Berserker's Oath", "Клятва берсерка",
	"x1.5 damage to all spells, regen disabled, life steal x2", "x1.5 урон ко всем заклинаниям, реген отключен, вампиризм x2",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.5), ae(ArtifactEffect.EffectType.BERSERKER_OATH, 0.0), ae(ArtifactEffect.EffectType.LIFE_STEAL, 0.04)],
	[])

_add_artifact("Arcane Overload", "Перегрузка магии",
	"+40% arcane damage", "+40% тайный урон",
	ItemRarity.Tier.UNCOMMON, &"arcane",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4)], [])

_add_artifact("Gambler's Dice", "Кости игрока",
	"Every 30s: random x0.5 or x2 damage for 5s", "Каждые 30с: случайно x0.5 или x2 урон на 5с",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.GAMBLER_DICE, 0.0)], [])
```

**LEGENDARY group:**
```gdscript
_add_artifact("Void Codex", "Кодекс пустоты",
	"+20% all damage, every 5th shot auto-crits, +10% pickup range", "+20% урон, каждое 5-е попадание крит, +10% сбор",
	ItemRarity.Tier.LEGENDARY, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.5), ae(ArtifactEffect.EffectType.PICKUP_RANGE_MULT, 1.1)], [])

_add_artifact("Inferno Grimoire", "Гrimуар инферно",
	"+35% fire, poison, lightning damage", "+35% урон огня, яда, молнии",
	ItemRarity.Tier.LEGENDARY, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.35)],
	[], FIRE_IDS + POISON_IDS + LIGHTNING_IDS)

_add_artifact("Absolute Zero", "Абсолютный ноль",
	"+60% cold damage, +50% cold area", "+60% урон холода, +50% область холода",
	ItemRarity.Tier.LEGENDARY, &"cold",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.6), ae(ArtifactEffect.EffectType.AREA_MULT, 1.5)],
	[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.85)])
```

**FUSION group (target by spell_name = spell_id of fusion spell):**
```gdscript
_add_artifact("Firenado Lens", "Линза Огненного вихря",
	"Firenado: +40% damage, +25% area", "Огненный вихрь: +40% урон, +25% область",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.AREA_MULT, 1.25)],
	[], [], &"firenado")

_add_artifact("Thunderbolt Coil", "Катушка молнии",
	"Thunderbolt: +2 chain jumps, +30% damage", "Thunderbolt: +2 прыжка цепи, +30% урон",
	ItemRarity.Tier.RARE, &"",
	[ae(ArtifactEffect.EffectType.CHAIN_COUNT, 2.0), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3)],
	[], [], &"thunderbolt")

_add_artifact("Crystal Aegis Shard", "Осколок Кристального aegis",
	"Crystal Aegis: +40% shield absorb, +120% shard damage", "Кристальный aegis: +40% поглощение, +120% урон осколков",
	ItemRarity.Tier.RARE, &"cold",
	[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)],
	[], [], &"crystal_aegis")
```

---

## Verification

After implementation:
1. Run `godot --headless --check-only` to verify no parse errors
2. Playtest: open chests → verify artifact cards render with readable text
3. Verify Boss damage with Abyssal Lens equipped deals bonus damage
4. Verify Berserker's Oath disables regen
5. Verify Twin Cast triggers occasionally
6. Verify Gambler's Dice cycles between x0.5 and x2
7. Verify ON_KILL_REGEN (Death Bell, Haunt Essence) heals on kill
8. Verify Martyr's Brand damage increases as HP drops
9. Verify spell-ID targeted artifacts only affect matching spells
