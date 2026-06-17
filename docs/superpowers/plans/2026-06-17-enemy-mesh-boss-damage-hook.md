# EnemyMeshManager Boss Damage Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a boss damage multiplier to all 7 damage functions in EnemyMeshManager.gd, keyed on `ArtifactManager.get_boss_damage_mult()` when the enemy key ends with `_boss`.

**Architecture:** A single helper function `_boss_dmg_mult(key: String) -> float` returns `ArtifactManager.get_boss_damage_mult()` for boss keys, else `1.0`. All damage functions multiply their `amount` by this helper at the point of HP subtraction.

**Tech Stack:** GDScript, Godot 4.6.2+

---

### Task 1: Add `_boss_dmg_mult` helper + apply to all 7 damage functions

**Files:**
- Modify: `D:\Godot Projects\ms\Systems\EnemyMeshManager.gd`

- [ ] **Step 1: Add helper function after variable declarations (after line 50, before first function)**

Insert at line 51 (before the existing `func _process` or first function):

```gdscript
func _boss_dmg_mult(key: String) -> float:
	if key.ends_with("_boss"):
		return ArtifactManager.get_boss_damage_mult()
	return 1.0
```

- [ ] **Step 2: Apply in `damage_area()` — line 803**

Change:
```gdscript
d[off + I_HP] -= amount * aura_mult
```
To:
```gdscript
d[off + I_HP] -= amount * aura_mult * _boss_dmg_mult(key)
```

- [ ] **Step 3: Apply in `damage_nearest()` — line 878**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(best_key)
```

- [ ] **Step 4: Apply in `damage_line()` — line 1121**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 5: Apply in `damage_rect()` — line 1179**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 6: Apply in `damage_rect_filtered()` — line 1240**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 7: Apply in `damage_cone()` — line 1313**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 8: Apply in `damage_id()` — line 1401**

Change:
```gdscript
d[off + I_HP] -= amount
```
To:
```gdscript
d[off + I_HP] -= amount * _boss_dmg_mult(key)
```

- [ ] **Step 9: Verify no syntax errors**

Run the Godot project or check GDScript syntax. Confirm no parse errors.

- [ ] **Step 10: Self-review**

Verify:
1. All 7 damage functions use `_boss_dmg_mult`
2. `damage_area` passes `key`, `damage_nearest` passes `best_key`
3. Helper is placed after vars, before first function
4. No stray edits elsewhere in the file

---

### Summary of Changes

| Function | Line | Old | New |
|----------|------|-----|-----|
| (new helper) | ~51 | — | `func _boss_dmg_mult(key: String) -> float:` |
| `damage_area` | 803 | `amount * aura_mult` | `amount * aura_mult * _boss_dmg_mult(key)` |
| `damage_nearest` | 878 | `amount` | `amount * _boss_dmg_mult(best_key)` |
| `damage_line` | 1121 | `amount` | `amount * _boss_dmg_mult(key)` |
| `damage_rect` | 1179 | `amount` | `amount * _boss_dmg_mult(key)` |
| `damage_rect_filtered` | 1240 | `amount` | `amount * _boss_dmg_mult(key)` |
| `damage_cone` | 1313 | `amount` | `amount * _boss_dmg_mult(key)` |
| `damage_id` | 1401 | `amount` | `amount * _boss_dmg_mult(key)` |
