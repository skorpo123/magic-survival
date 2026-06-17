# Level-Up UI Redesign — Magic Survival Style

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign LevelUpScreen, SpellCard, ModificationScreen, and FusionGrimoire to match the Magic Survival visual style at 1920×1080.

**Architecture:** Modify 4 existing GDScript files. SpellCard gets rough border drawing and MS-style layout. LevelUpScreen gets black background, cyan/green labels, and pentagram fusion button. ModificationScreen scales orbs to 100px. FusionGrimoire updates card sizes.

**Tech Stack:** Godot 4.6 GDScript, `_draw()` API, CanvasItem rendering

---

### Task 1: SpellCard — Resize and MS-Style Layout

**Files:**
- Modify: `D:\Godot Projects\ms\UI\SpellCard.gd`

- [ ] **Step 1: Update constants**

In `SpellCard.gd`, change the constants block (lines 6-10):

```gdscript
const CARD_W := 660.0
const CARD_H := 120.0
const CORNER_R := 16.0
const ICON_SIZE := 80.0
const PAD := 20.0
```

- [ ] **Step 2: Update UI element positions in `_build_ui()`**

Replace the `_build_ui()` method. Key changes: icon at `x=PAD, y=(CARD_H-ICON_SIZE)*0.5`, title at `x=PAD+ICON_SIZE+14, y=12`, level at `x=CARD_W-PAD-80, y=12`, desc at `x=PAD+ICON_SIZE+14, y=44`, mod_label at `x=PAD+ICON_SIZE+14, y=80`.

```gdscript
func _build_ui() -> void:
	_icon_container = Control.new()
	_icon_container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_container.position = Vector2(PAD, (CARD_H - ICON_SIZE) * 0.5)
	_icon_container.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_container)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
	_title_label.position = Vector2(PAD + ICON_SIZE + 14.0, 12.0)
	_title_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 100.0, 28.0)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_level_label.position = Vector2(CARD_W - PAD - 80.0, 14.0)
	_level_label.size = Vector2(80.0, 24.0)
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", SettingsManager.font_size(13))
	_desc_label.position = Vector2(PAD + ICON_SIZE + 14.0, 44.0)
	_desc_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 20.0, 36.0)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)

	_mod_label = Label.new()
	_mod_label.add_theme_font_size_override("font_size", SettingsManager.font_size(12))
	_mod_label.position = Vector2(PAD + ICON_SIZE + 14.0, 80.0)
	_mod_label.size = Vector2(CARD_W - PAD * 2 - ICON_SIZE - 20.0, 22.0)
	_mod_label.visible = false
	_mod_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mod_label)
```

- [ ] **Step 3: Replace `_draw_border` with rough border**

Replace the `_draw_border` method with a rough/painted border style:

```gdscript
func _draw_border(accent: Color, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var points := PackedVector2Array()
	var step := 8.0
	var x := 0.0
	while x < CARD_W:
		points.append(Vector2(x, rng.randf_range(-1.5, 1.5)))
		x += step
	var y := 0.0
	while y < CARD_H:
		points.append(Vector2(CARD_W + rng.randf_range(-1.5, 1.5), y))
		y += step
	x = CARD_W
	while x > 0:
		points.append(Vector2(x, CARD_H + rng.randf_range(-1.5, 1.5)))
		x -= step
	y = CARD_H
	while y > 0:
		points.append(Vector2(rng.randf_range(-1.5, 1.5), y))
		y -= step
	points.append(points[0])
	var col := Color(
		minf(accent.r * 0.4 + h * 0.5, 1.0),
		minf(accent.g * 0.4 + h * 0.5, 1.0),
		minf(accent.b * 0.4 + h * 0.5, 1.0),
		0.4 + h * 0.4
	)
	draw_polyline(points, col, 2.0 + h, true)
```

- [ ] **Step 4: Update `_draw_bg` for darker MS-style background**

Replace `_draw_bg`:

```gdscript
func _draw_bg(accent: Color, h: float) -> void:
	var bg := Color(
		0.03 + h * 0.01,
		0.025 + h * 0.01,
		0.05 + h * 0.01,
		0.92
	)
	_draw_rounded_rect(Rect2(0, 0, CARD_W, CARD_H), CORNER_R, bg)
	var inner := Color(1, 1, 1, 0.015 + h * 0.01)
	_draw_rounded_rect(Rect2(2, 2, CARD_W - 4, CARD_H - 4), CORNER_R - 1, inner)
```

- [ ] **Step 5: Update icon fallback for MS-style**

In `_setup_icon()`, change the fallback symbol to use a spell-type icon instead of diamond. Update `_get_type_symbol()`:

```gdscript
func _get_type_symbol() -> String:
	if not _data:
		return ""
	match _data.card_type:
		LevelUpCard.CardType.NEW_SPELL:
			return "✦"
		LevelUpCard.CardType.SPELL_UPGRADE:
			return "▲"
		LevelUpCard.CardType.SPELL_MODIFICATION:
			return "◆"
		LevelUpCard.CardType.STAT_BOOST:
			return "✧"
		LevelUpCard.CardType.SPELL_FUSION:
			return "★"
	return ""
```

- [ ] **Step 6: Test card rendering**

Run the game, level up, and verify:
- Cards are 660×120 pixels
- Rough borders are visible
- Icons display on the left
- Name, level, description positioned correctly
- Fusion card has star icon and red border

---

### Task 2: LevelUpScreen — Black Background + Fusion Button

**Files:**
- Modify: `D:\Godot Projects\ms\UI\LevelUpScreen.gd`

- [ ] **Step 1: Update background color constant**

Change the `BG` constant (line 5):

```gdscript
const BG := Color(0.0, 0.0, 0.0, 0.95)
```

- [ ] **Step 2: Update title and level label colors**

In `_build_ui()`, update the level label color (line 59):

```gdscript
_level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
```

Update the title label color (line 70):

```gdscript
_title_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.9))
```

- [ ] **Step 3: Update title label font size**

Change the title font size (line 69):

```gdscript
_title_label.add_theme_font_size_override("font_size", SettingsManager.font_size(36))
```

- [ ] **Step 4: Update level label font size**

Change the level font size (line 58):

```gdscript
_level_label.add_theme_font_size_override("font_size", SettingsManager.font_size(20))
```

- [ ] **Step 5: Update card spacing**

Change `CARD_SPACING` constant (line 3):

```gdscript
const CARD_SPACING := 16.0
```

- [ ] **Step 6: Add pentagram fusion button**

After the `_ornament` setup (line 82), add the pentagram button. Add a new member variable at the top of the class:

```gdscript
var _fusion_pentagram: _PentagramButton
```

In `_build_ui()`, after `_vbox.add_child(_ornament)`, add:

```gdscript
_fusion_pentagram = _PentagramButton.new()
_fusion_pentagram.position = Vector2(560, -20)
_fusion_pentagram.mouse_filter = Control.MOUSE_FILTER_STOP
_fusion_pentagram.pentagram_clicked.connect(_on_fusion_pentagram_clicked)
_vbox.add_child(_fusion_pentagram)
```

- [ ] **Step 7: Add pentagram click handler**

Add a new method:

```gdscript
func _on_fusion_pentagram_clicked() -> void:
	if _is_selecting:
		return
	var fusion_card := _find_fusion_card()
	if fusion_card:
		var fusion_screen := FusionDetailScreen.new()
		fusion_screen.setup(fusion_card)
		get_parent().add_child(fusion_screen)
	else:
		if FusionGrimoire.is_open:
			return
		var grimoire := FusionGrimoire.new()
		get_parent().add_child(grimoire)
```

Add helper method:

```gdscript
func _find_fusion_card() -> LevelUpCard:
	for card in _current_cards:
		if card.card_type == LevelUpCard.CardType.SPELL_FUSION:
			return card
	return null
```

- [ ] **Step 8: Update pentagram availability in `show_cards()`**

In `show_cards()`, after setting up cards, add:

```gdscript
var has_fusion := false
for card in cards:
	if card.card_type == LevelUpCard.CardType.SPELL_FUSION:
		has_fusion = true
		break
if _fusion_pentagram:
	_fusion_pentagram.set_available(has_fusion)
```

- [ ] **Step 9: Update reroll button style**

Update the reroll button style to match MS dark theme. Change `reroll_style` (line 101):

```gdscript
var reroll_style := StyleBoxFlat.new()
reroll_style.bg_color = Color(0.04, 0.03, 0.06, 0.9)
reroll_style.set_corner_radius_all(6)
reroll_style.set_border_width_all(1)
reroll_style.border_color = Color(0.3, 0.25, 0.4, 0.5)
```

- [ ] **Step 10: Test level-up screen**

Run the game, level up, and verify:
- Black background covers full screen
- Cyan title, green level label
- Cards are 660×120 with rough borders
- Pentagram appears to the right of title
- Reroll button works

---

### Task 3: PentagramButton Inner Class

**Files:**
- Modify: `D:\Godot Projects\ms\UI\LevelUpScreen.gd`

- [ ] **Step 1: Add PentagramButton class**

Add at the end of `LevelUpScreen.gd`, after the `_OrnamentLine` class:

```gdscript
class _PentagramButton extends Control:
	signal pentagram_clicked()

	const SIZE := 60.0

	var _available: bool = false
	var _pulse_t: float = 0.0
	var _hover_t: float = 0.0
	var _hover_target: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size = Vector2(SIZE, SIZE)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		mouse_entered.connect(func() -> void: _hover_target = 1.0)
		mouse_exited.connect(func() -> void: _hover_target = 0.0)

	func set_available(val: bool) -> void:
		_available = val
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse_t += delta * 3.0
		_hover_t = lerpf(_hover_t, _hover_target, delta * 12.0)
		queue_redraw()

	func _draw() -> void:
		var cx := SIZE * 0.5
		var cy := SIZE * 0.5
		var r := SIZE * 0.42
		var col: Color
		if _available:
			var pulse := 0.7 + 0.3 * sin(_pulse_t * 2.0)
			col = Color(0.2 * pulse, 0.9 * pulse, 1.0, 0.8 + _hover_t * 0.2)
			for i in range(3):
				var expand := (4.0 + _hover_t * 6.0) * (1.0 - i / 3.0)
				var a := 0.15 * (1.0 - i / 3.0)
				draw_circle(Vector2(cx, cy), r + expand, Color(0.2, 0.9, 1.0, a))
		else:
			col = Color(0.6, 0.15, 0.3, 0.6 + _hover_t * 0.2)

		var star_points := PackedVector2Array()
		for i in range(10):
			var angle := -PI / 2.0 + i * PI / 5.0
			var dist := r if i % 2 == 0 else r * 0.4
			star_points.append(Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist))
		star_points.append(star_points[0])
		draw_polyline(star_points, col, 2.0 + _hover_t, true)
		draw_circle(Vector2(cx, cy), 3.0, col)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pentagram_clicked.emit()
```

- [ ] **Step 2: Test pentagram rendering**

Run the game, verify:
- Pentagram appears to the right of title
- When no fusion available: dim red color
- When fusion available: cyan pulse glow
- Hover effect works
- Click triggers fusion flow

---

### Task 4: ModificationScreen — Scale Orbs for 1920×1080

**Files:**
- Modify: `D:\Godot Projects\ms\UI\ModificationScreen.gd`

- [ ] **Step 1: Update orb size constants**

Change the constants (lines 6-9):

```gdscript
const ORB_SIZE := 100.0
const TRIANGLE_TOP_Y := 160.0
const TRIANGLE_BOTTOM_Y := 340.0
const TRIANGLE_SPREAD := 160.0
```

- [ ] **Step 2: Update orbs_host size**

Change the orbs_host setup (lines 71-72):

```gdscript
_orbs_host.custom_minimum_size = Vector2(500, 420)
_orbs_host.size = Vector2(500, 420)
```

- [ ] **Step 3: Update _ModOrb constants**

In the `_ModOrb` inner class, change the constants (lines 299-300):

```gdscript
const SIZE := 100.0
const RADIUS := 50.0
```

- [ ] **Step 4: Update triangle position calculation**

In `_get_triangle_positions()`, update `center_x` to match new host width (line 185):

```gdscript
var center_x := 250.0
```

- [ ] **Step 5: Update description container width**

Change the description container minimum size (line 79):

```gdscript
_desc_container.custom_minimum_size = Vector2(500, 0)
```

- [ ] **Step 6: Update study button size**

Change the study button size (line 101):

```gdscript
_study_btn.custom_minimum_size = Vector2(280, 52)
```

- [ ] **Step 7: Update fusion button size**

Change the fusion button size (line 133):

```gdscript
fusion_btn.custom_minimum_size = Vector2(240, 40)
```

- [ ] **Step 8: Test modification screen**

Run the game, level a spell to max, verify:
- Orbs are 100×100 pixels
- Triangle layout is properly centered
- Description appears correctly below orbs
- Buttons are properly sized

---

### Task 5: FusionGrimoire — Update Card Sizes

**Files:**
- Modify: `D:\Godot Projects\ms\UI\FusionGrimoire.gd`

- [ ] **Step 1: Update card constants**

Change the card size constants (lines 15-16):

```gdscript
const CARD_W := 280.0
const CARD_H := 420.0
```

Change the gap constant (line 17):

```gdscript
const CARD_GAP := 20.0
```

- [ ] **Step 2: Test fusion grimoire**

Run the game, open FusionGrimoire, verify:
- Cards are 280×420
- 4 columns at 1920px width
- Proper spacing between cards
- Scroll works correctly

---

### Task 6: Final Integration Test

- [ ] **Step 1: Full flow test**

Run the game and test the complete flow:
1. Play until level up → verify LevelUpScreen shows with MS style
2. Check card rendering (rough borders, icons, text positioning)
3. Check pentagram button (dim when no fusion)
4. Select a spell → verify animation works
5. Level up again → check reroll button
6. Level a spell to max → verify ModificationScreen opens
7. Check orb sizing and triangle layout
8. Select an orb → verify description appears
9. Click study → verify modification applies
10. Check FusionGrimoire opens correctly
11. Check fusion detail screen

- [ ] **Step 2: Resolution test**

Verify all screens look correct at 1920×1080:
- No overflow
- Proper centering
- Text readable
- Buttons clickable
