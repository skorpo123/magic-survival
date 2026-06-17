# Phase Color Transformation + Inner Power Upgrade Shop

## Overview

Three subsystems:
1. **Phase color transformation** -- CanvasModulate transitions through unique color palettes per phase instead of simple darkening
2. **Inner Power upgrade shop** -- main menu screen for spending persistent currency on passive stat upgrades (max level 5)
3. **Chunk seam fix** -- eliminate visible tilemap chunk boundary squares

---

## A. Phase Color Transformation

### Problem
6 phases use monotonically darkening gray colors (0.65 to 0.34). No atmosphere change. Square artifacts visible at chunk boundaries.

### Solution

#### PHASE_COLORS replacement (Main.gd)
Phase 1 Lavand:    Color(0.55, 0.50, 0.70)
Phase 2 Blue:      Color(0.40, 0.45, 0.60)
Phase 3 Swamp:     Color(0.35, 0.45, 0.30)
Phase 4 Fire:      Color(0.55, 0.30, 0.10)
Phase 5 Violet:    Color(0.30, 0.10, 0.45)
Phase 6 Abyss:     Color(0.08, 0.02, 0.12)

Existing lerp mechanism (_current_mod_color.lerp(_target_mod_color, delta * 0.8)) works unchanged.

#### Dead file cleanup
- Delete world.tscn -- ParallaxBackground with null Sprite2D texture, never instanced anywhere

#### Chunk seam fix (ChunkGenerator.gd)
In get_or_create_chunk(), add chunk.texture_padding = 2 to each TileMapLayer. This adds 2px padding on all sides of the atlas tiles, eliminating visible seams at chunk boundaries.

---

## B. Inner Power Upgrade Shop

### Architecture

#### UpgradeManager (autoload)
- upgrade_levels: Dictionary -- 9 string keys to int (0..5)
- persistent_currency: int -- currency that persists between runs
- get_upgrade_cost(key: String, level: int) -> int -- quadratic: [50, 150, 350, 700, 1200][level]
- purchase_upgrade(key: String) -> bool -- deducts persistent_currency, increments level, returns success
- apply_to_player(player: Node2D) -- modifies PlayerStats based on upgrade_levels (called at start_game)
- _save() / _load() -- user://upgrades.save (JSON file)

#### Currency flow change (GameManager.gd)
- currency: int (existing) = in-run currency, reset to 0 at start_game()
- At game_over/victory: UpgradeManager.persistent_currency += GameManager.currency
- start_game() resets currency = 0 but does NOT touch persistent_currency
- start_game() calls UpgradeManager.apply_to_player(player)

#### 9 Upgradable Stats

| Key | Name Key | Base | Bonus Per Level | Max (Lv5) |
|-----|----------|------|----------------|-----------|
| max_hp | stat_max_hp | 100 | +15 | 175 |
| hp_regen | stat_hp_regen | 0 | +0.5/s | 2.5/s |
| armor | stat_armor | 0 | +3 | 15 |
| move_speed | stat_speed | 150 | +12 | 210 |
| magic_power | stat_magic | 1.0 | +12% (x0.12) | 1.60 |
| cooldown_reduction | stat_cd | 0 | +4% | 20% |
| projectile_speed_mult | stat_proj_speed | 1.0 | +8% (x0.08) | 1.40 |
| area_multiplier | stat_area | 1.0 | +8% (x0.08) | 1.40 |
| pickup_range | stat_pickup | 80 | +20 | 180 |

Cost per level (quadratic): 50 -> 150 -> 350 -> 700 -> 1200 (total for max: 2450)

#### UpgradeManager.apply_to_player()
Sets each PlayerStats field to base + level * bonus. Resets current_hp to new max_hp. Calls player.update_pickup_detector().

#### InnerPowerScreen (UI/InnerPowerScreen.gd)
- Style: matches SettingsMenu/StatsMenu (BG_COLOR bg, vignette, ornament line, gold title)
- Title: SettingsManager.t(inner_power_title)
- Persistent currency display at top (gold label)
- 9 rows: stat color icon -> stat name -> 5 stars (filled gold / empty gray) -> cost label -> upgrade button
- Upgrade button: gold accent if affordable and not max, gray if not affordable or max level
- Back button: SettingsManager.t(btn_return)
- Signal: close_requested
- Opens from MainMenu button

#### MainMenu.gd changes
- Add _inner_power_btn between Play and Settings
- Accent: Color(0.4, 0.85, 0.6) (emerald green)
- Text: SettingsManager.t(btn_inner_power)
- On pressed: show InnerPowerScreen child node
- Small persistent currency label next to button

#### main.tscn changes
- Add InnerPowerScreen node under UI (same pattern as ArtifactSelectScreen)

#### GameManager._cleanup_run() changes
- Remove hardcoded stat resets (lines 90-101) -- replaced by UpgradeManager.apply_to_player()

#### SettingsManager translations to add
- inner_power_title: EN/RU
- btn_inner_power: EN/RU

---

## C. Level 5 Cap

Covered by upgrade_levels[key] max of 5. UI shows 5 stars (filled=level, empty=remaining). Button disabled at level 5.

---

## Files to Create
- Autoload/UpgradeManager.gd -- persistent upgrade data + save/load
- UI/InnerPowerScreen.gd -- upgrade shop screen

## Files to Modify
- Main.gd -- PHASE_COLORS replacement
- World/Procedural/ChunkGenerator.gd -- add texture_padding=2
- UI/MainMenu.gd -- add Inner Power button + InnerPowerScreen child
- Autoload/GameManager.gd -- persistent currency flow, call UpgradeManager.apply_to_player, remove hardcoded stat resets
- Autoload/SettingsManager.gd -- add translations
- main.tscn -- add InnerPowerScreen node
- project.godot -- add UpgradeManager autoload

## Files to Delete
- world.tscn -- dead ParallaxBackground
