# Artifact Unique Effects + Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace 6 existing artifacts with triggered passive abilities and improve artifact card/screen visuals.

**Architecture:** New `ArtifactAbilityRunner` autoload manages triggered effects. Effects listen to `EventBus` signals + `_process` timers. Visual overhaul uses the existing `_draw` pattern with enhanced glow, animations, and layout.

**Tech Stack:** Godot 4.6 GDScript, custom `_draw()` UI

---

### Task 1: Add new EffectTypes + ArtifactData config field

**Files:**
- Modify: `Systems/Artifacts/ArtifactEffect.gd`
- Modify: `Systems/Artifacts/ArtifactData.gd`

- [ ] **Step 1: Add new EffectType values**

In `ArtifactEffect.gd`:
```gdscript
enum EffectType {
	...
	SECOND_WIND,
	SPELL_ECHO,
	TINY_MENACE,
	STATIC_AURA,
	OVERFLOW,
	CRIT_CASCADE,
}
```

- [ ] **Step 2: Add extra_value field to ArtifactData**

In `ArtifactData.gd`, add:
```gdscript
@export var extra_value: float = 0.0
```

- [ ] **Step 3: Add spell_cast emission to SpellCaster**

In `SpellCaster.gd`, line 68-69:
```gdscript
	_time_since_cast = 0.0
	EventBus.spell_cast.emit(spell.spell_id, global_position, _last_cast_dir)
	spell.behavior.cast(self, spell, player_stats)
```

- [ ] **Step 4: Add crit_landed signal to EventBus**

In `EventBus.gd`:
```gdscript
signal crit_landed(damage: float, position: Vector2)
```

---

### Task 2: Create ArtifactAbilityRunner autoload

**Files:**
- Create: `Autoload/ArtifactAbilityRunner.gd`
- Modify: `project.godot` (register autoload)

- [ ] **Step 1: Create ArtifactAbilityRunner.gd**

```gdscript
extends Node

# Per-effect state
var _sw_cooldown: float = 0.0
var _sw_active: bool = false
var _sw_heal_timer: float = 0.0
var _echo_count: int = 0
var _echo_spell_name: StringName
var _is_echoing: bool = false
var _static_aura_area: Area2D = null
var _cascade_cooldown: float = 0.0
var _overflow_hp: float = 0.0

# Equipped flags
var _has_second_wind: bool = false
var _has_spell_echo: bool = false
var _has_tiny_menace: bool = false
var _has_static_aura: bool = false
var _has_overflow: bool = false
var _has_cascade: bool = false

func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.player_xp_gained.connect(_on_player_xp_gained)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
	EventBus.crit_landed.connect(_on_crit_landed)
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_sw_cooldown = 0.0
	_sw_active = false
	_echo_count = 0
	_cascade_cooldown = 0.0
	_overflow_hp = 0.0
	if _static_aura_area and is_instance_valid(_static_aura_area):
		_static_aura_area.queue_free()
		_static_aura_area = null

func register_effect(effect_type: int) -> void:
	match effect_type:
		ArtifactEffect.EffectType.SECOND_WIND:
			_has_second_wind = true
		ArtifactEffect.EffectType.SPELL_ECHO:
			_has_spell_echo = true
		ArtifactEffect.EffectType.TINY_MENACE:
			_has_tiny_menace = true
			_apply_tiny_menace()
		ArtifactEffect.EffectType.STATIC_AURA:
			_has_static_aura = true
			_create_static_aura()
		ArtifactEffect.EffectType.OVERFLOW:
			_has_overflow = true
		ArtifactEffect.EffectType.CRIT_CASCADE:
			_has_cascade = true
```

- [ ] **Step 2: Register autoload**

In `project.godot`, add:
```
ArtifactAbilityRunner="*res://Autoload/ArtifactAbilityRunner.gd"
```

---

### Task 3: Second Wind implementation

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

- [ ] **Step 1: Add Second Wind handlers**

In `ArtifactAbilityRunner.gd`, add these methods:

```gdscript
func _on_player_damaged(amount: float, _source: Node2D) -> void:
	if not _has_second_wind:
		return
	if _sw_cooldown > 0.0 or _sw_active:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	if stats.current_hp / stats.max_hp < 0.25:
		_sw_active = true
		_sw_heal_timer = 3.0
		_trigger_second_wind_vfx(player)

func _trigger_second_wind_vfx(player: Node2D) -> void:
	BurstEffectPool.spawn("explosion", player.global_position, Color(0.2, 1.0, 0.3))

func _process_second_wind(delta: float) -> void:
	if not _sw_active:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	_sw_heal_timer -= delta
	if _sw_heal_timer <= 0.0:
		_sw_active = false
		_sw_cooldown = 60.0
		return
	var heal_per_sec := stats.max_hp * 0.50 / 3.0
	stats.current_hp = minf(stats.current_hp + heal_per_sec * delta, stats.max_hp)
	EventBus.player_healed.emit(heal_per_sec * delta)

func _process(delta: float) -> void:
	if _sw_active:
		_process_second_wind(delta)
	if _sw_cooldown > 0.0:
		_sw_cooldown -= delta
	if _cascade_cooldown > 0.0:
		_cascade_cooldown -= delta
	if _has_overflow and _overflow_hp > 0.0:
		_process_overflow(delta)
	if _has_static_aura:
		_process_static_aura(delta)
```

---

### Task 4: Spell Echo implementation

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

- [ ] **Step 1: Add Spell Echo handlers**

```gdscript
func _on_spell_cast(spell_name: StringName, _pos: Vector2, _dir: Vector2) -> void:
	if not _has_spell_echo or _is_echoing:
		return
	_echo_count += 1
	if _echo_count >= 10:
		_echo_count = 0
		_trigger_echo(spell_name)

func _trigger_echo(spell_name: StringName) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	# Find the SpellCaster for this spell
	for child in player.get_children():
		if child is SpellCaster and child.spell and child.spell.spell_id == spell_name:
			_is_echoing = true
			var ps: PlayerStats = null
			if "stats" in player and player.stats is PlayerStats:
				ps = player.stats
			child.spell.behavior.cast(child, child.spell, ps)
			_is_echoing = false
			BurstEffectPool.spawn("explosion", player.global_position, Color(1.0, 0.4, 0.8))
			return
```

---

### Task 5: Tiny Menace implementation

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

- [ ] **Step 1: Add Tiny Menace handler**

```gdscript
func _apply_tiny_menace() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	player.set_meta(&"original_scale", player.scale)
	player.scale *= 0.75
```

In `_on_game_started`, add:
```gdscript
	var player := GameManager.get_player()
	if player and player.has_meta(&"original_scale"):
		player.scale = player.get_meta(&"original_scale")
		player.remove_meta(&"original_scale")
```

---

### Task 6: Static Aura implementation

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

- [ ] **Step 1: Add Static Aura handlers**

```gdscript
func _create_static_aura() -> void:
	if _static_aura_area and is_instance_valid(_static_aura_area):
		return
	var player := GameManager.get_player()
	if not player:
		return
	_static_aura_area = Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 80.0
	collision.shape = shape
	_static_aura_area.add_child(collision)
	_static_aura_area.collision_layer = 0
	_static_aura_area.collision_mask = 0  # detection only
	player.add_child(_static_aura_area)

func _process_static_aura(delta: float) -> void:
	if not _static_aura_area or not is_instance_valid(_static_aura_area):
		return
	var player := GameManager.get_player()
	if not player:
		return
	_static_aura_area.global_position = player.global_position
```

Add `vulnerable` meta to enemies inside aura (in `_process_static_aura`):
```gdscript
	if Engine.get_process_frames() % 6 != 0:  # every ~0.1s at 60fps
		return
	for body in _static_aura_area.get_overlapping_bodies():
		if body.is_in_group("enemy") or body.has_method("take_damage"):
			body.set_meta(&"static_aura_vuln", true)

func is_static_aura_active(body: Node2D) -> bool:
	return body.has_meta(&"static_aura_vuln")
```

- [ ] **Step 2: Apply damage multiplier in damage_area functions**

In `SwarmManager.gd` and `EnemyMeshManager.gd`, in `damage_area` (or wherever damage is applied to individual enemies):
```gdscript
	if ArtifactAbilityRunner._has_static_aura and ArtifactAbilityRunner.is_static_aura_active(enemy):
		damage *= 1.15
```

Also clear the meta when leaving:
```gdscript
	body.remove_meta(&"static_aura_vuln")
```
Add this at the start of `_process_static_aura` to clear stale marks.

---

### Task 7: Overflow implementation

**Files:**
- Modify: `Autoload/ArtifactAbilityRunner.gd`

- [ ] **Step 1: Add Overflow handlers**

```gdscript
func _on_player_xp_gained(amount: float) -> void:
	if not _has_overflow:
		return
	_overflow_hp += amount * 0.25
	var player := GameManager.get_player()
	if player and "stats" in player:
		var stats: PlayerStats = player.stats
		stats.current_hp = minf(stats.current_hp + amount * 0.25, stats.max_hp + _overflow_hp)

func _process_overflow(delta: float) -> void:
	if _overflow_hp <= 0.0:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	if stats.current_hp <= stats.max_hp:
		_overflow_hp = maxf(_overflow_hp - delta, 0.0)
		return
	var decay := 1.0 * delta
	stats.current_hp -= decay
	_overflow_hp -= decay
	if stats.current_hp < stats.max_hp:
		stats.current_hp = stats.max_hp
```

---

### Task 8: Cascade + crit tracking throughout behaviors

**Files:**
- Modify: `Spells/Resources/Spell.gd`
- Modify: `Autoload/ArtifactAbilityRunner.gd`
- Modify: 33+ behavior files (one-line addition each)

- [ ] **Step 1: Add crit tracking to Spell.gd**

```gdscript
var _last_crit_rolled: bool = false

func roll_crit_mult(stats: PlayerStats) -> float:
	_last_crit_rolled = false
	if not stats or stats.crit_chance <= 0.0:
		return 1.0
	if randf() < stats.crit_chance:
		_last_crit_rolled = true
		return stats.crit_damage_mult if stats.crit_damage_mult > 1.0 else stats.crit_damage_mult_bonus + 1.0
	return 1.0

func was_last_crit() -> bool:
	return _last_crit_rolled
```

- [ ] **Step 2: Add Cascade handler**

```gdscript
func _on_crit_landed(damage: float, position: Vector2) -> void:
	if not _has_cascade:
		return
	if _cascade_cooldown > 0.0:
		return
	_cascade_cooldown = 0.5
	var wave_dmg := damage * 0.5
	SwarmManager.damage_area(position, 100.0, wave_dmg)
	EnemyMeshManager.damage_area(position, 100.0, wave_dmg)
	BurstEffectPool.spawn("shockwave", position, Color(1.0, 0.6, 0.2))
	JuiceManager.screen_shake(3.0, 0.06)
```

- [ ] **Step 3: Add one-liner to all behavior files**

In every file where `roll_crit_mult` is called, add after the damage computation:
```gdscript
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, pos)
```

Where `pos` is the position where damage was dealt (player position or target position). Each file may need a small context adjustment.

Files to modify (33 total):
- InfernoNovaBehavior, CrystalAegisBehavior, ArcanePrisonBehavior, ArcOverloadBehavior, BladeVortexBehavior
- SoulBurstBehavior, SeismicPulseBehavior, FlameWardBehavior, ToxicBloomBehavior, ToxicNeedlesBehavior
- FirenadoBehavior, PhotonStormBehavior, MirrorShardsBehavior, FrostLanceBehavior, ThunderboltBehavior
- AstralSwarmBehavior, PhaseBoltBehavior, GalvanicChainBehavior, PhantomOrbitBehavior
- LightningBehavior, ElectricZoneBehavior, ZoneBehavior, FrostNovaBehavior, FireBreathBehavior
- PoisonPoolBehavior, NeedleBehavior, SpiritBehavior, CycloneBehavior, RayBehavior, ShieldBehavior
- MeteorProjectile, OrbitProjectile

---

### Task 9: Replace artifact catalog entries

**Files:**
- Modify: `Autoload/ArtifactManager.gd`

- [ ] **Step 1: Register trigger effects on equip**

In `ArtifactManager._apply()`, after calling `_update_cache_for_artifact`, add:
```gdscript
	for bonus in artifact.bonuses:
		match bonus.effect_type:
			ArtifactEffect.EffectType.SECOND_WIND, \
			ArtifactEffect.EffectType.SPELL_ECHO, \
			ArtifactEffect.EffectType.TINY_MENACE, \
			ArtifactEffect.EffectType.STATIC_AURA, \
			ArtifactEffect.EffectType.OVERFLOW, \
			ArtifactEffect.EffectType.CRIT_CASCADE:
				ArtifactAbilityRunner.register_effect(bonus.effect_type)
```

- [ ] **Step 2: Replace artifact entries**

Replace these entries in `_build_catalog()`:

| Old | New | Code |
|-----|-----|------|
| Warden's Oath (Uncommon) | **Tiny Menace** | `+5% dodge, -25% size` — `TINY_MENACE + DODGE_CHANCE(0.05)` |
| Celestial Orb (Legendary) | **Spell Echo** | `+20% damage, every 10th cast duplicates` — `SPELL_ECHO + DAMAGE_MULT(1.2)` |
| Soul Harvest (Legendary) | **Overflow** | `25% of XP gained as overheal, decays 1/s` — `OVERFLOW` |
| Tempest Crown (Legendary) | **Static Aura** | `Enemies within 80 take 15% more damage` — `STATIC_AURA` |
| Blood Crown (Legendary) | **Cascade** | `Critical hits create shockwaves (50% dmg, 100 radius)` — `CRIT_CASCADE` |

Add new Warden's Oath as **Second Wind** (Rare):
```gdscript
_add_artifact("Second Wind", ...,
	"Below 25% HP: heal 50% over 3s (60s cd)",
	ArtifactEffect.EffectType.SECOND_WIND, ...)
```

---

### Task 10: Visual overhaul — ArtifactCard.gd

**Files:**
- Modify: `UI/ArtifactCard.gd`

- [ ] **Step 1: Increase card and icon size**

```gdscript
const CARD_W := 248.0   # was 224
const CARD_H := 340.0   # was 310
const ICON_SIZE := 96.0 # was 64
```

- [ ] **Step 2: Enhance icon area — add rarity-colored circular glow behind icon**

In `_draw()`, before `_draw_fallback_icon`:
```gdscript
func _draw_icon_backglow(accent: Color) -> void:
	var cx := CARD_W * 0.5
	var icon_top := PAD + 8.0
	var cy := icon_top + ICON_SIZE * 0.5
	# Outer glow circles
	for i in range(3):
		var t := i / 3.0
		var r := (ICON_SIZE * 0.6 + 12.0) * (1.0 + t * 0.5)
		var a := 0.08 * (1.0 - t)
		draw_circle(Vector2(cx, cy), r, Color(accent.r, accent.g, accent.b, a))
```

- [ ] **Step 3: Enhance fallback icon — make diamond larger + add pulsing**

Replace `_draw_fallback_icon` with enhanced version:
```gdscript
func _draw_fallback_icon(accent: Color) -> void:
	var icon_pos := Vector2((CARD_W - ICON_SIZE) * 0.5, PAD + 8)
	var bg_color := Color(accent.r * 0.08, accent.g * 0.08, accent.b * 0.12, 0.9)
	draw_rounded_rect(Rect2(icon_pos, Vector2(ICON_SIZE, ICON_SIZE)), 8, bg_color)
	var border := Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.6, 0.5 + 0.3 * (0.5 + 0.5 * sin(_pulse_phase)))
	draw_rounded_rect(Rect2(icon_pos, Vector2(ICON_SIZE, ICON_SIZE)), 8, border, false, 2.0)
	# Diamond
	var cx := icon_pos.x + ICON_SIZE * 0.5
	var cy := icon_pos.y + ICON_SIZE * 0.5
	var r := ICON_SIZE * 0.3
	var pts := PackedVector2Array([
		Vector2(cx, cy - r), Vector2(cx + r * 0.7, cy),
		Vector2(cx, cy + r), Vector2(cx - r * 0.7, cy),
	])
	draw_colored_polygon(pts, Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.35))
	draw_polyline(pts, Color(accent.r * 0.7, accent.g * 0.7, accent.b * 0.8, 0.6), 2.0, true)
	draw_circle(Vector2(cx, cy), ICON_SIZE * 0.08, Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.8, 0.7))
```

- [ ] **Step 4: Improve rarity label display**

Replace star-rating with colored text:
```gdscript
func _get_rarity_text() -> String:
	match _artifact.rarity:
		ItemRarity.Tier.COMMON: return SettingsManager.t(&"rarity_common")
		ItemRarity.Tier.UNCOMMON: return SettingsManager.t(&"rarity_uncommon")
		ItemRarity.Tier.RARE: return SettingsManager.t(&"rarity_rare")
		ItemRarity.Tier.LEGENDARY: return SettingsManager.t(&"rarity_legendary")
```

- [ ] **Step 5: Add entrance particle burst**

In `play_entrance()`:
```gdscript
func play_entrance(delay: float) -> void:
	...existing code...
	# After delay, spawn small particle burst
	if _artifact:
		var accent: Color = ItemRarity.COLORS.get(_artifact.rarity, Color.GRAY)
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			BurstEffectPool.spawn("sparkle", get_global_mouse_position(), accent))
```

- [ ] **Step 6: Enhance description layout for unique effects**

Make `_format_effect` handle the new EffectTypes:
```gdscript
		ArtifactEffect.EffectType.SECOND_WIND:
			val_str = SettingsManager.t(&"eff_second_wind")
		ArtifactEffect.EffectType.SPELL_ECHO:
			val_str = SettingsManager.t(&"eff_spell_echo")
		...
```

---

### Task 11: Visual overhaul — ArtifactSelectScreen.gd

**Files:**
- Modify: `UI/ArtifactSelectScreen.gd`

- [ ] **Step 1: Add animated particle background**

In `_build_ui()`:
```gdscript
# Add starfield background
var stars := _StarField.new()
stars.set_anchors_preset(Control.PRESET_FULL_RECT)
stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(stars)  # below overlay
```

Add `_StarField` inner class:
```gdscript
class _StarField extends Control:
	var _stars: Array[Dictionary] = []
	func _ready() -> void:
		for i in range(40):
			_stars.append({
				"pos": Vector2(randf() * 2000, randf() * 1200),
				"size": randf_range(0.5, 2.0),
				"speed": randf_range(0.1, 0.4),
				"alpha": randf_range(0.15, 0.5)
			})
	func _process(delta: float) -> void:
		for s in _stars:
			s["pos"].y -= s["speed"] * delta * 60.0
			if s["pos"].y < -10:
				s["pos"].y = 1200 + 10
				s["pos"].x = randf() * 2000
		queue_redraw()
	func _draw() -> void:
		for s in _stars:
			var a := s["alpha"] * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.001 * s["speed"] * 3.0))
			draw_circle(s["pos"], s["size"], Color(0.6, 0.5, 0.8, a))
```

- [ ] **Step 2: Change card layout to 2×2 grid**

Replace horizontal card layout with a GridContainer:
```gdscript
var _grid: GridContainer

# In _build_ui():
_grid = GridContainer.new()
_grid.columns = 2
_grid.add_theme_constant_override("h_separation", 24)
_grid.add_theme_constant_override("v_separation", 24)
_grid.mouse_filter = Control.MOUSE_FILTER_PASS
# Center it
var grid_center := CenterContainer.new()
grid_center.add_child(_grid)
_vbox.add_child(grid_center)
```

Update `_show_offer()` to add cards to `_grid` instead of positioning via x:
```gdscript
	for i in _current_artifacts.size():
		var card := ArtifactCard.new()
		_grid.add_child(card)
		card.setup(artifact)
		...
```

- [ ] **Step 3: Enhance entrance animation — cascading per card + background fade-in**

Add overlay fade-in from 0→1 in `_show_offer()`:
```gdscript
	_overlay.modulate.a = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_overlay, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
```

---

### Task 12: Update ArtifactSlotsScreen to match new card style

**Files:**
- Modify: `UI/ArtifactSlotsScreen.gd`

- [ ] **Step 1: Update slot card styling**

In `_make_artifact_card()`, update style to match:
```gdscript
	style.border_color = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.7)
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.border_width_bottom = 2
```

Add glow to the panel:
```gdscript
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(col.r * 0.05, col.g * 0.05, col.b * 0.08, 0.3)
	panel.add_child(glow)
	panel.move_child(glow, 0)
```

---

### Task 13: Update translations

**Files:**
- Modify: `Autoload/SettingsManager.gd`

- [ ] **Step 1: Add translation keys for new effect descriptions**

```gdscript
# Effect descriptions for new artifacts
&"eff_second_wind": { "en": "When HP < 25%: heal 50% over 3s (60s cd)", "ru": "При HP < 25%: лечение 50% за 3с (60с кд)" },
&"eff_spell_echo": { "en": "Every 10th cast: spell duplicates", "ru": "Каждое 10-е заклинание: дублируется" },
&"eff_tiny_menace": { "en": "25% smaller, +5% dodge", "ru": "На 25% меньше, +5% уворот" },
&"eff_static_aura": { "en": "Enemies within 80 take 15% more damage", "ru": "Враги в радиусе 80 получают +15% урона" },
&"eff_overflow": { "en": "25% of XP → temporary HP (decays 1/s)", "ru": "25% опыта → временные ОЗ (1/с распад)" },
&"eff_cascade": { "en": "Crits create shockwaves (50% dmg, 0.5s cd)", "ru": "Криты создают волну (50% урона, 0.5с кд)" },
```

