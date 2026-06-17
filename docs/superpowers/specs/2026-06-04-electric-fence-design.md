# Electric Fence Redesign

## Overview
Replace the current Electric Field visual (random arcs + halo) with an Electric Fence — a circular barrier of 8 glowing node pillars connected by lightning arcs, with visible zap discharges when enemies touch the fence.

## Current Problems
- Random arcs don't convey "barrier" — they float aimlessly inside the zone
- Static halo feels like ambient glow, not a dangerous boundary
- Enemy contact is barely visible (just a faint `_contact_flash_t` alpha boost)
- Cracks (16 radial lines) feel disconnected from the zone concept
- No sense of protection or boundary

## Design

### Visual Layers (inside → outside)

1. **Inner halo** — soft radial glow (Sprite2D, reuse existing `_halo_tex`). Very subtle, gives depth to the interior.

2. **Fence ring** — 3 concentric dashed circles drawn via `_draw()`:
   - Outer: wide (10-12px), very transparent blue, sparse dashes — outer glow
   - Mid: medium (3-4px), semi-transparent cyan-blue, medium dashes — electric field
   - Inner: thin (1.5px), bright white-cyan, dense dashes — sharp electric edge
   - All three rotate slowly via offset animation to create movement

3. **8 Node pillars** — bright white-cyan dots at 45° intervals on the ring:
   - Each node: bright core circle (r=3) + glow circle (r=6)
   - Pulse: nodes oscillate in brightness with `_pulse_t`
   - On contact: nearest nodes flash brighter (flicker effect)

4. **Lightning arcs between adjacent nodes** — polylines connecting each node to its neighbors:
   - 8 arcs total (each node → next node clockwise)
   - Regenerate arc jitter every damage tick (reuse `_regenerate_waves`)
   - Each arc: 6-8 segments with random perpendicular jitter
   - Width: 2px primary, rendered with additive blend

5. **Zap discharge on enemy contact**:
   - When enemy enters fence radius: bright bolt from nearest node to enemy position
   - Bolt: thick (3px) white polyline with 5-6 segments, high jitter
   - Spark burst at enemy position via BurstEffectPool.spawn("electric_spark")
   - Node nearest to enemy flashes extra bright (ripple: adjacent nodes also dimmer flash)

6. **Node flicker on contact** — when `_enemy_contact` is true:
   - Nearest 2-3 nodes get boosted glow radius and brightness
   - Creates a "ripple" effect along the fence

### Removed Elements
- Old `_wave_seeds` arc system (random arcs inside zone)
- Old `_crack_data` radial lines
- Old ring flash on damage tick (`draw_arc` with flash_alpha)

### Data Flow

```
ElectricZoneBehavior.tick() → ElectricField._process()
  ├── Follow player position (existing)
  ├── _pulse_t += delta (existing)
  ├── Damage tick → _deal_zone_damage() + _regenerate_arcs() (modified)
  ├── Enemy contact check (existing, every 3 frames)
  └── queue_redraw() → _draw() (rewritten)
```

### _draw() Implementation

```
1. Draw inner halo (existing _halo Sprite2D — no change)
2. Draw 3-layer fence ring (3x draw_arc with dash patterns via multiple small arcs)
3. For each of 8 nodes:
   a. Compute position: center + Vector2(cos(angle), sin(angle)) * radius
   b. Draw glow circle (filled, alpha based on pulse + contact)
   c. Draw core circle (filled, bright)
4. For each pair of adjacent nodes (8 pairs):
   a. Generate jagged polyline with jitter from _arc_seeds[]
   b. draw_polyline(arc_points, color, width)
5. If _enemy_contact:
   a. Find nearest node to each contacting enemy position
   b. Draw bright zap bolt from node to enemy
   c. Draw spark burst at enemy (via BurstEffectPool)
   d. Boost nearest nodes' glow
6. Draw shockwave rings (existing — unchanged)
```

### Node Structure

```gdscript
const NODE_COUNT := 8
var _node_angles: PackedFloat32Array  # pre-computed TAU/8 * i
var _arc_seeds: Array                  # jitter data, regenerated each tick
var _zap_targets: Array                # [{node_idx, enemy_pos}], cleared each frame
```

### Performance Considerations
- 8 nodes × 2 circles = 16 draw_circle calls (replaces 16 crack lines + 3 arcs + ring)
- 8 arcs × 6 segments = ~48 polyline points (replaces 3 arcs × 12 segments)
- Zap bolts: max 2-3 per frame, only when enemies contact
- No new nodes/instances — all drawn in _draw() on single Node2D
- Total draw calls: ~25-30 per frame (vs ~22 current — similar)

### Modifications Support (unchanged)
- **Shockwave**: expanding ring on interval — keep existing shockwave ring drawing
- **Arc Flash**: 3x tick speed — fence arcs regenerate faster, more crackle
- **Chain Lightning**: bolt from fence to enemy outside zone — keep existing chain logic

## Files Modified
- `Spells/visuals/ElectricField.gd` — complete _draw() rewrite, new node/arc data, zap system
- `Spells/behaviors/ElectricZoneBehavior.gd` — no changes needed (setup params unchanged)
