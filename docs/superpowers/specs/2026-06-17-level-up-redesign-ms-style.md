# Level-Up UI Redesign — Magic Survival Style

## Goal

Redesign the Level-Up screen, Modification screen, and Fusion flow to match the Magic Survival visual style, adapted for 1920×1080 resolution.

## Target Resolution

1920×1080, `canvas_items` stretch mode, `expand` aspect. All sizing designed for this viewport.

---

## 1. Level-Up Screen (`LevelUpScreen.gd`)

### Layout (1920×1080)

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│          Текущий уровень : 20                        │  green 20pt, y=200
│          Выбор заклинания                            │  cyan 36pt, y=240
│                                        [✦]           │  pentagram 60×60
│                                                      │
│     ┌──────────────────────────────────────┐         │
│     │ [icon 80×80]  Название заклинания Lv1│         │  Card: 660×120
│     │               Описание эффекта...    │         │
│     └──────────────────────────────────────┘         │
│                         gap 16px                     │
│     ┌──────────────────────────────────────┐         │
│     │ [icon 80×80]  Название заклинания Lv2│         │
│     │               Описание эффекта...    │         │
│     └──────────────────────────────────────┘         │
│                         gap 16px                     │
│     ┌──────────────────────────────────────┐         │
│     │ [icon 80×80]  Название   ★ ФЬЮЖН    │         │  red border
│     │  Вы можете изучить свойство          │         │  cyan text
│     └──────────────────────────────────────┘         │
│                                                      │
│              [ Вернуть 40% маны ]                    │  reroll button
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Visual Style

- **Background**: `Color(0.0, 0.0, 0.0, 0.95)` — full black overlay
- **Title "Выбор заклинания"**: cyan `Color(0.2, 0.85, 0.9)`, 36pt, shadow + outline
- **Level label**: green `Color(0.3, 0.9, 0.4)`, 20pt
- **Fusion button (pentagram)**: positioned at `x=1150, y=210` (right of title)
  - Unavailable: `Color(0.6, 0.15, 0.3)` with gray outline
  - Available: cyan pulse `Color(0.2, 0.9, 1.0)` with glow
  - Draws a 5-pointed star via `_draw()`
- **Reroll button**: "Вернуть 40% маны", 280×48, dark bg with gray border

### SpellCard Redesign

| Property | Old | New |
|----------|-----|-----|
| CARD_W | 480 | 660 |
| CARD_H | 100 | 120 |
| ICON_SIZE | 72 | 80 |
| CORNER_R | 12 | 16 |
| PAD | 14 | 20 |

**Card visual style (MS-style):**
- **Background**: `Color(0.04, 0.03, 0.06, 0.92)` — near-black with slight purple tint
- **Border**: rough/painted style — use `_draw()` to create irregular edge with small random offsets
- **Icon area**: 80×80, white/gray monochrome (current fallback diamond → change to spell-type symbol)
- **Name**: 20pt white, position `x=PAD+ICON_SIZE+14, y=12`
- **Level "Lv X"**: 14pt green (rarity color), position `x=CARD_W-PAD-80, y=12`, right-aligned
- **Description**: 13pt gray `Color(0.7, 0.68, 0.8)`, position `x=PAD+ICON_SIZE+14, y=44`, autowrap
- **Fusion indicator**: If `card_type == SPELL_FUSION`:
  - Border color: `Color(0.8, 0.2, 0.3)` (red)
  - Star icon instead of spell icon
  - Cyan text "Вы можете изучить свойство" at `y=78`

**Rough border drawing:**
```gdscript
func _draw_rough_border(accent: Color, h: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 42  # deterministic
    var points := PackedVector2Array()
    var step := 8.0
    # Top edge
    var x := 0.0
    while x < CARD_W:
        points.append(Vector2(x, rng.randf_range(-1.5, 1.5)))
        x += step
    # Right edge
    var y := 0.0
    while y < CARD_H:
        points.append(Vector2(CARD_W + rng.randf_range(-1.5, 1.5), y))
        y += step
    # Bottom edge (reverse)
    x = CARD_W
    while x > 0:
        points.append(Vector2(x, CARD_H + rng.randf_range(-1.5, 1.5)))
        x -= step
    # Left edge (reverse)
    y = CARD_H
    while y > 0:
        points.append(Vector2(rng.randf_range(-1.5, 1.5), y))
        y -= step
    points.append(points[0])  # close
    var col := Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.6, 0.5 + h * 0.3)
    draw_polyline(points, col, 2.0 + h, true)
```

### Animations

- **Card entrance**: slide up from +30px, fade in 0.18s, stagger 0.1s between cards
- **Title entrance**: fade in 0.4s
- **Card exit (selected)**: scale up to 1.15, fade out 0.2s
- **Card exit (not selected)**: slide left/right alternately, fade out 0.15s

---

## 2. Modification Screen (`ModificationScreen.gd`)

### Layout (1920×1080)

Keep triangle layout. Scale up for 1920×1080:

| Property | Old | New |
|----------|-----|-----|
| ORB_SIZE | 80 | 100 |
| RADIUS | 40 | 50 |
| TRIANGLE_TOP_Y | 140 | 160 |
| TRIANGLE_BOTTOM_Y | 300 | 340 |
| TRIANGLE_SPREAD | 130 | 160 |
| orbs_host size | 400×380 | 500×420 |

**Visual style:**
- Background: `Color(0.0, 0.0, 0.0, 1.0)` — pure black
- Title: cyan `Color(1.0, 0.85, 0.35)`, 36pt
- Orb colors per ModType (unchanged):
  - CHAIN: `Color(0.4, 0.7, 1.0)` blue
  - EXPLODE: `Color(1.0, 0.5, 0.2)` orange
  - SPEED_BOOST: `Color(1.0, 0.3, 0.3)` red
  - PIERCE_BOOST: `Color(0.3, 0.9, 0.6)` green
  - SPLIT: `Color(0.8, 0.5, 1.0)` purple
  - default: `Color(0.6, 0.4, 0.9)` violet
- Orb glow: 3 concentric circles with fading alpha
- Selected orb: additional outer ring

**Description area:**
- Mod name: 22pt white, centered
- Effects: 14pt, green `#4ADE80` for positive, red `#F87171` for negative
- Positioned below orbs with 20px gap

**Buttons:**
- "Изучить": 280×52, dark bg, white text, enabled when orb selected
- "Фьюжн": 240×40, dark bg, orange text

---

## 3. Fusion Grid (FusionGrimoire.gd)

Already adaptive. Adjust card sizes for 1920×1080:

| Property | Old | New |
|----------|-----|-----|
| CARD_W | 250 | 280 |
| CARD_H | 450 | 420 |
| CARD_GAP | 16 | 20 |

At 1920px width with 80px margins: `(1920-160) / (280+20) = 6.1` → 4 columns max.

---

## 4. Fusion Detail Screen

### Layout (1920×1080)

```
┌──────────────────────────────────────────────────────┐
│                                              [X]     │  close button
│                                                      │
│              [ big visual preview ]                  │  400×400
│                                                      │
│              Название фьюжны                         │  white 28pt
│              Компонент1 + Компонент2                 │  colored text
│              ─────────────────────                   │  divider line
│              Описание эффекта...                     │  gray 14pt
│              +30% урон                               │  green
│              -10% скорость                           │  red
│                                                      │
│              [ Изучить ]                             │  button 280×52
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 5. Files to Modify

| File | Changes |
|------|---------|
| `UI/SpellCard.gd` | Resize to 660×120, rough border drawing, MS-style layout |
| `UI/LevelUpScreen.gd` | Black bg, cyan/green labels, pentagram fusion button, 16px spacing |
| `UI/ModificationScreen.gd` | Scale orbs to 100px, resize host to 500×420, update triangle positions |
| `UI/FusionGrimoire.gd` | Update CARD_W=280, CARD_H=420, CARD_GAP=20 |

---

## 6. Color Reference

| Element | Color |
|---------|-------|
| Background (level-up) | `Color(0.0, 0.0, 0.0, 0.95)` |
| Background (modification) | `Color(0.0, 0.0, 0.0, 1.0)` |
| Title cyan | `Color(0.2, 0.85, 0.9)` |
| Level green | `Color(0.3, 0.9, 0.4)` |
| Card bg | `Color(0.04, 0.03, 0.06, 0.92)` |
| Card border (normal) | `Color(accent * 0.4, 0.4 + h*0.4)` |
| Card border (fusion) | `Color(0.8, 0.2, 0.3)` |
| Fusion text cyan | `Color(0.3, 0.85, 0.95)` |
| Pentagram unavailable | `Color(0.6, 0.15, 0.3)` |
| Pentagram available | `Color(0.2, 0.9, 1.0)` pulse |
| Positive effect | `#4ADE80` green |
| Negative effect | `#F87171` red |
| Description gray | `Color(0.7, 0.68, 0.8)` |
