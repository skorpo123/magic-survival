# Shield Dome Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the small procedural ellipse shield visual with a shader-based energy dome that fully covers the player character.

**Architecture:** New SDF shader (`dome_shield.gdshader`) renders a Fresnel-glow dome on a full-viewport ColorRect. ShieldAura.gd is rewritten to use the shader instead of Draw API calls. Thorns spikes remain as Draw API.

**Tech Stack:** Godot 4.6.4, GLSL-like shader language, GDScript

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Shaders/dome_shield.gdshader` | **CREATE** | SDF dome rendering + hit flash |
| `Spells/visuals/ShieldAura.gd` | **REWRITE** | Shader setup, uniform updates, state colors, thorns |

**No changes to:** ShieldBehavior.gd, Player.gd, LevelUpManager.gd

---

### Task 1: Create the dome shader

**Files:**
- Create: `D:\Godot Projects\ms\Shaders\dome_shield.gdshader`

- [ ] **Step 1: Create Shaders directory**

```powershell
New-Item -ItemType Directory -Path "D:\Godot Projects\ms\Shaders" -Force
```

- [ ] **Step 2: Write the shader**

Create `D:\Godot Projects\ms\Shaders\dome_shield.gdshader` with the following content:

```glsl
shader_type canvas_item;

uniform vec2 player_pos : hint_screen_position = vec2(0.0, 0.0);
uniform float shield_radius : hint_range(10.0, 200.0) = 72.0;
uniform vec4 dome_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float alpha_base : hint_range(0.0, 1.0) = 0.10;
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.40;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.5;

// Hit flash
uniform vec2 hit_pos = vec2(-1000.0, -1000.0);
uniform float hit_time = -1.0;
uniform float hit_radius : hint_range(10.0, 200.0) = 80.0;
uniform float hit_duration : hint_range(0.1, 2.0) = 0.35;

void fragment() {
	// Fragment position in screen/world space
	vec2 frag_world = SCREEN_UV * SCREEN_TEXTURE_SIZE;
	
	// Distance from player center
	float d = distance(frag_world, player_pos);
	float t = d / shield_radius;
	
	// Outside dome — fully transparent
	if (t > 1.0) {
		COLOR = vec4(0.0);
		return;
	}
	
	// Base dome alpha with smooth edge
	float dome_alpha = mix(alpha_base, alpha_edge, smoothstep(0.55, 1.0, t));
	
	// Fresnel-like edge glow
	float edge_fresnel = pow(1.0 - t, fresnel_power);
	dome_alpha += edge_fresnel * 0.35;
	
	// Inner brightness (slightly brighter near center)
	float inner_glow = smoothstep(0.8, 0.0, t) * 0.08;
	dome_alpha += inner_glow;
	
	dome_alpha = clamp(dome_alpha, 0.0, 1.0);
	
	// Hit flash ring
	float hit Contribution = 0.0;
	if (hit_time >= 0.0 && hit_time < hit_duration) {
		float progress = hit_time / hit_duration;
		float wave_r = progress * hit_radius;
		float dh = distance(frag_world, hit_pos);
		
		// Ring shape
		float ring_width = 10.0 * (1.0 - progress * 0.5);
		float ring = smoothstep(wave_r - ring_width, wave_r, dh) 
		           - smoothstep(wave_r, wave_r + ring_width, dh);
		
		// Fade out over time
		hit_contribution = ring * (1.0 - progress) * 0.8;
	}
	
	// Final color
	float final_alpha = clamp(dome_alpha + hit_contribution, 0.0, 1.0);
	COLOR = vec4(dome_color.rgb, final_alpha);
}
```

- [ ] **Step 3: Verify shader compiles**

Open Godot editor — check the shader loads without errors in the Shader Editor panel.

- [ ] **Step 4: Commit**

```bash
git add Shaders/dome_shield.gdshader
git commit -m "feat: add SDF dome shield shader with Fresnel glow and hit flash"
```

---

### Task 2: Rewrite ShieldAura.gd — core shader setup

**Files:**
- Modify: `D:\Godot Projects\ms\Spells\visuals\ShieldAura.gd` (full rewrite)

- [ ] **Step 1: Read current ShieldAura.gd**

Read `D:\Godot Projects\ms\Spells\visuals\ShieldAura.gd` to understand the current interface (`setup()`, `set_colors()`, `set_thorns()`, `set_aegis()`, `on_charge_used()`, `_process()`).

- [ ] **Step 2: Write the new ShieldAura.gd**

Replace the entire file with:

```gdscript
extends Node2D

const SHADER_PATH := "res://Shaders/dome_shield.gdshader"

var _player: Node2D = null
var _dome_rect: ColorRect = null
var _shader_mat: ShaderMaterial = null
var _shader: Shader = null

# State
var _charges: int = 0
var _max_charges: int = 2
var _primary_color := Color(0.3, 0.7, 1.0)
var _secondary_color := Color(0.2, 0.4, 0.8)
var _is_aegis := false
var _has_thorns := false

# Hit flash
var _hit_time: float = -1.0
var _hit_duration: float = 0.35

# Spike animation (thorns via Draw API)
var _spike_phase: float = 0.0

func _ready() -> void:
	top_level = true
	z_index = 2
	_shader = load(SHADER_PATH)
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = _shader
	_dome_rect = ColorRect.new()
	_dome_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dome_rect.material = _shader_mat
	add_child(_dome_rect)

func setup(player_node: Node2D) -> void:
	_player = player_node
	_update_dome_size()

func _update_dome_size() -> void:
	if not _player or not is_instance_valid(_player):
		return
	var vp_size := get_viewport_rect().size
	_dome_rect.size = vp_size
	_dome_rect.position = Vector2.ZERO
	# Shield radius: 1.5x player height estimate
	var radius := 72.0
	if "stats" in _player and _player.stats is PlayerStats:
		radius = 72.0
	_shader_mat.set_shader_parameter("shield_radius", radius)

func set_colors(primary: Color, secondary: Color) -> void:
	_primary_color = primary
	_secondary_color = secondary
	_apply_state_visual()

func set_thorns(active: bool) -> void:
	_has_thorns = active
	queue_redraw()

func set_aegis(active: bool) -> void:
	_is_aegis = active
	_apply_state_visual()

func set_charges(charges: int, max_charges: int) -> void:
	_charges = charges
	_max_charges = max_charges
	_apply_state_visual()

func _apply_state_visual() -> void:
	if not _shader_mat:
		return
	var dome_col: Color
	var a_base: float
	var a_edge: float
	var f_power: float
	
	if _is_aegis:
		dome_col = Color(1.0, 0.85, 0.3)
		a_base = 0.14
		a_edge = 0.50
		f_power = 3.0
	elif _charges <= 0:
		dome_col = Color(0.25, 0.25, 0.25)
		a_base = 0.04
		a_edge = 0.10
		f_power = 1.0
	elif _charges < _max_charges:
		dome_col = Color(0.95, 0.3, 0.1)
		a_base = 0.12
		a_edge = 0.45
		f_power = 2.0
	else:
		dome_col = _primary_color
		a_base = 0.10
		a_edge = 0.40
		f_power = 2.5
	
	_shader_mat.set_shader_parameter("dome_color", dome_col)
	_shader_mat.set_shader_parameter("alpha_base", a_base)
	_shader_mat.set_shader_parameter("alpha_edge", a_edge)
	_shader_mat.set_shader_parameter("fresnel_power", f_power)

func on_charge_used(damage_pos: Vector2) -> void:
	_hit_time = 0.0
	_shader_mat.set_shader_parameter("hit_pos", damage_pos)
	_shader_mat.set_shader_parameter("hit_time", 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	global_position = _player.global_position
	
	# Update hit flash
	if _hit_time >= 0.0:
		_hit_time += delta
		_shader_mat.set_shader_parameter("hit_time", _hit_time)
		if _hit_time >= _hit_duration:
			_hit_time = -1.0
			_shader_mat.set_shader_parameter("hit_time", -1.0)
	
	# Thorns spike animation
	if _has_thorns and _charges > 0:
		_spike_phase += delta * 0.3
		queue_redraw()

# --- Thorns via Draw API (drawn on top of shader dome) ---
func _draw() -> void:
	if not _has_thorns or _charges <= 0:
		return
	_draw_spikes()

func _draw_spikes() -> void:
	var spike_count := 8
	var base_len := 10.0
	var base_w := 3.5
	var radius := 72.0
	var col := _primary_color
	
	for i in range(spike_count):
		var angle := (TAU / spike_count) * i + _spike_phase
		var tip_len := base_len + sin(_spike_phase * 2.0 + i * 1.3) * 3.0
		var center := Vector2(cos(angle), sin(angle)) * radius
		var tip := center + Vector2(cos(angle), sin(angle)) * tip_len
		var perp := Vector2(-sin(angle), cos(angle))
		var left := center + perp * base_w * 0.5
		var right := center - perp * base_w * 0.5
		var pts := PackedVector2Array([left, tip, right])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.7))
```

- [ ] **Step 3: Verify no compilation errors**

Check that Godot loads ShieldAura.gd without errors.

- [ ] **Step 4: Commit**

```bash
git add Spells/visuals/ShieldAura.gd
git commit -m "feat: rewrite ShieldAura with shader dome and Fresnel glow"
```

---

### Task 3: Wire ShieldBehavior to new ShieldAura interface

**Files:**
- Modify: `D:\Godot Projects\ms\Spells\behaviors\ShieldBehavior.gd` (minor changes)

- [ ] **Step 1: Read ShieldBehavior.gd**

Read `D:\Godot Projects\ms\Spells\behaviors\ShieldBehavior.gd` to find `_create_aura()` and `intercept_damage()`.

- [ ] **Step 2: Update `_create_aura()` to pass charges**

In `_create_aura()`, after `_aura.setup(caster)`, add:
```gdscript
_aura.set_charges(_charges, _max_charges)
```

- [ ] **Step 3: Update `intercept_damage()` to pass damage position**

In `intercept_damage()`, when calling `_aura.on_charge_used()`, pass the damage source position:
```gdscript
# Before:
_aura.on_charge_used()

# After:
var hit_pos := Vector2.ZERO
if source and source is Node2D:
    hit_pos = source.global_position
_aura.on_charge_used(hit_pos)
```

Also update charges after absorption:
```gdscript
_aura.set_charges(_charges, _max_charges)
```

- [ ] **Step 4: Update tick recharge to sync charges**

In the `tick()` method, after `_charges += 1`, add:
```gdscript
if _aura:
    _aura.set_charges(_charges, _max_charges)
```

- [ ] **Step 5: Verify no compilation errors**

- [ ] **Step 6: Commit**

```bash
git add Spells/behaviors/ShieldBehavior.gd
git commit -m "feat: wire ShieldBehavior to new ShieldAura shader interface"
```

---

### Task 4: Integration test — playtest in editor

- [ ] **Step 1: Run the game in Godot editor**

Play the game, pick the Shield spell, verify:
1. Dome appears around player (blue, semi-transparent, Fresnel glow at edges)
2. Dome follows player smoothly
3. When enemy hits shield → white flash ring at impact point
4. Shield color changes as charges deplete (blue → red → gray)
5. Thorns spikes visible around dome when thorns mod is active

- [ ] **Step 2: Fix any visual issues**

Adjust shader uniforms or ShieldAura parameters as needed.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: shield dome redesign complete — shader-based Fresnel dome"
```
