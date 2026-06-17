# Руководство по кастомизации — Magic Survival: Echoes of Arcana

## Обзор

Все настраиваемые параметры заклинаний и визуальных эффектов доступны через ресурсные файлы и inspector Godot. Нет необходимости редактировать код поведения для изменения визуала.

---

## 1. SpellData — ресурс заклинания

**Файл:** `Spells/Resources/SpellData.gd`  
**Наследует:** `Spell` (все базовые поля `damage`, `cooldown`, `color` и т.д. доступны)

### Группа: Projectile Visual
| Поле | Тип | По умолчанию | Описание |
|------|-----|-------------|----------|
| `projectile_texture` | Texture2D | null | Текстура снаряда |
| `projectile_modulate` | Color | WHITE | Модуляция цвета снаряда |
| `projectile_z_index` | int | 3 | Z-индекс снаряда |
| `glow_texture` | Texture2D | null | Текстура свечения |
| `glow_scale` | float | 1.0 | Масштаб свечения |
| `glow_alpha` | float | 1.0 | Прозрачность свечения |

### Группа: Animation
| Поле | Тип | По умолчанию | Описание |
|------|-----|-------------|----------|
| `rotation_speed` | float | 0.0 | Скорость вращения (рад/с) |
| `scale_curve` | Curve | null | Кривая масштаба по времени жизни |
| `flicker_frequency` | float | 0.0 | Частота мерцания (Гц) |
| `custom_shader_material` | ShaderMaterial | null | Кастомный шейдер |

### Группа: VFX
| Поле | Тип | По умолчанию | Описание |
|------|-----|-------------|----------|
| `vfx_spawn_key` | String | "" | Ключ эффекта появления (VFXCatalog) |
| `vfx_impact_key` | String | "" | Ключ эффекта удара (VFXCatalog) |
| `vfx_death_key` | String | "" | Ключ эффекта смерти (VFXCatalog) |
| `vfx_flight_key` | String | "" | Ключ эффекта полёта (VFXCatalog) |
| `vfx_color_primary` | Color | WHITE | Основной цвет VFX |
| `vfx_color_secondary` | Color | GRAY | Вторичный цвет VFX |
| `vfx_intensity` | float | 1.0 | Множитель интенсивности VFX |

### Группа: Timing
| Поле | Тип | По умолчанию | Описание |
|------|-----|-------------|----------|
| `spawn_delay` | float | 0.0 | Задержка перед появлением |
| `impact_duration` | float | 0.5 | Длительность эффекта удара |
| `cycle_pause` | float | 0.0 | Пауза между циклами |

### Как поведения читают цвета

Каждое поведение с визуалом имеет `_get_primary_color(spell)` и `_get_secondary_color(spell)`:

```
1. Если spell это SpellData и vfx_color_primary != WHITE → использовать его
2. Иначе если есть modification с color_tint != WHITE → использовать tint
3. Иначе → hardcoded default из поведения
```

**Это значит:** чтобы сменить цвет заклинания, достаточно изменить `vfx_color_primary` / `vfx_color_secondary` в SpellData. Код менять не нужно.

---

## 2. SpellModifierData — визуальные переопределения модификации

**Файл:** `Spells/Resources/SpellModifierData.gd`  
**Наследует:** `SpellModification`

### Группа: Visual Overrides
| Поле | Тип | По умолчанию | Описание |
|------|-----|-------------|----------|
| `override_projectile_texture` | Texture2D | null | Заменить текстуру снаряда |
| `override_projectile_modulate` | Color | WHITE | Заменить цвет снаряда |
| `override_glow_scale` | float | -1.0 | Заменить масштаб свечения (-1 = не менять) |
| `override_glow_alpha` | float | -1.0 | Заменить прозрачность свечения |
| `override_vfx_spawn_key` | String | "" | Заменить ключ эффекта появления |
| `override_vfx_impact_key` | String | "" | Заменить ключ эффекта удара |
| `override_vfx_color_primary` | Color | WHITE | Заменить основной цвет VFX |
| `override_vfx_color_secondary` | Color | GRAY | Заменить вторичный цвет VFX |
| `override_custom_shader` | ShaderMaterial | null | Заменить шейдер |

**Соглашение:** значения по умолчанию (WHITE, GRAY, -1, "") означают «использовать базовое значение из SpellData».

---

## 3. VFXCatalog — каталог визуальных эффектов

**Файл:** `Systems/VFXCatalog.gd` (autoload)

### Зарегистрированные эффекты
| Ключ | Сцена | Описание |
|------|-------|----------|
| `death_default` | Scenes/death_default.tscn | Стандартная смерть врага |
| `death_fire` | (placeholder) | Огненная смерть |
| `death_cold` | (placeholder) | Ледяная смерть |
| `death_arcane` | (placeholder) | Арканная смерть |
| `death_rage` | (placeholder) | Яростная смерть |
| `electric_spark` | Scenes/vfx_electric_spark.tscn | Искра электричества |
| `arcane_impact` | Scenes/vfx_arcane_impact.tscn | Удар арканы |
| `heal_flash` | (placeholder) | Вспышка лечения |
| `level_up_burst` | (placeholder) | Вспышка левел-апа |

### API
```gdscript
VFXCatalog.play_effect("electric_spark", Vector2(100, 200))
VFXCatalog.play_effect("electric_spark", pos, 1.5, Color.CYAN)
VFXCatalog.get_scene("death_fire")
VFXCatalog.has_effect("death_fire")
VFXCatalog.register("my_effect", "res://Scenes/my_vfx.tscn")
```

### Как добавить новый эффект

1. Создать сцену с `BurstParticleGroup2D` как корневой узел
2. Настроить частицы (количество, цвет, размер, время жизни)
3. Сохранить в `Scenes/vfx_my_effect.tscn`
4. В `VFXCatalog._ready()` добавить: `register("my_effect", "res://Scenes/vfx_my_effect.tscn")`
5. Использовать: `BurstEffectPool.spawn("my_effect", position)` или `VFXCatalog.play_effect("my_effect", position)`

---

## 4. BurstEffectPool — пул эффектов

**Файл:** `Systems/BurstEffectPool.gd`

### Константы
| Имя | Значение | Описание |
|-----|----------|----------|
| `POOL_SIZE` | 50 | Макс. экземпляров в пуле |
| `MAX_SPAWN_PER_FRAME` | 20 | Лимит спавна за кадр (глобальный) |
| `MAX_PER_TYPE_PER_SECOND` | 10 | Лимит спавна одного типа за секунду |

### Регистрация типа
```gdscript
_scene_map["my_effect"] = preload("res://Scenes/vfx_my_effect.tscn")
_scale_map["my_effect"] = 1.0
```

### API
```gdscript
BurstEffectPool.spawn("electric_spark", Vector2(100, 200))
BurstEffectPool.spawn("death_default", pos, Color.RED)
```

---

## 5. Изменение баланса заклинаний

Все фабрики заклинаний в `Systems/LevelUpManager.gd`. Каждый метод `_create_*()` возвращает `SpellData` со всеми параметрами.

### Пример: изменить урон Electric Zone
```gdscript
# В _create_electric_zone():
ez.base_damage = 15.0  # было 10.0
```

### Пример: изменить цвет молнии
```gdscript
# В _create_lightning_strike():
ls.vfx_color_primary = Color(0.8, 0.5, 1.0)  # фиолетовый вместо голубого
ls.vfx_color_secondary = Color(0.5, 0.2, 0.8)
```

### Пример: изменить визуал модификации
```gdscript
# В _create_cyclone(), модификация Gravity Well:
mod_tornado.color_tint = Color(0.5, 0.2, 0.9)
# Этот tint автоматически применяется к CycloneVortex через _get_primary_color()
```

---

## 6. Константы разделения врагов

**Файл:** `Systems/EnemyMeshManager.gd`

| Константа | Значение | Описание |
|-----------|----------|----------|
| `SEPARATION_RADIUS` | 35.0 | Радиус разделения для мелких врагов |
| `BIG_SEPARATION_RADIUS` | 70.0 | Радиус разделения для крупных |
| `SEPARATION_FORCE` | 80.0 | Сила отталкивания мелких |
| `BIG_SEPARATION_FORCE` | 60.0 | Сила отталкивания крупных |
| `SEPARATION_UPDATE_INTERVAL` | 4 | Каждый 4-й кадр |
| `SEPARATION_MAX_NEIGHBORS` | 8 | Макс. соседей для проверки |
| `BIG_TYPE_KEYS` | ["big","overlord",...] | Типы с большим радиусом разделения |

**Файл:** `Systems/SwarmManager.gd`

| Константа | Значение | Описание |
|-----------|----------|----------|
| `SWARM_SEP_RADIUS` | 20.0 | Радиус разделения swarm |
| `SWARM_SEP_FORCE` | 40.0 | Сила отталкивания swarm |
| `SWARM_SEP_INTERVAL` | 4 | Каждый 4-й кадр |

---

## 7. Фазовое расписание спавна

**Файл:** `Systems/Waves/WaveManager.gd`

| Фаза | Тип врага | Описание |
|------|-----------|----------|
| Phase 1 | Drone | Начальная волна |
| Break 1 | — | 6 сек передышка |
| Phase 2 | Mine | Мины |
| Break 2 | — | 7 сек |
| Phase 3 | Golem | Големы |
| Break 3 | — | 7 сек |
| Phase 4 | Rampage | Берсерки |
| Break 4 | — | 8 сек |
| Phase 5 | Overlord | Оверлорды |
| Break 5 | — | 8 сек |
| Phase 6 | Armageddon | Все типы + swarm |

---

## 8. Заклинания — уровни и модификации

Все 11 заклинаний фабрикуются в `Systems/LevelUpManager.gd`. Каждая фабрика `_create_*()` возвращает `SpellData`.

### Magic Bolt
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | -10% cd |
| 3 | 1.5 | +1 proj |
| 4 | 1.8 | +1 pierce |
| 5 | 2.2 | -20% cd |

| Мода | Описание |
|------|----------|
| Magic Missile Storm | +1 proj, -30% dmg each |
| Homing | 100% homing accuracy |
| Chain Lightning | Hits chain to nearby enemy, 50% dmg |

### Fireball
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | +25% explosion |
| 3 | 1.5 | +1 proj |
| 4 | 1.8 | +50% explosion |
| 5 | 2.2 | +100% explosion |

| Мода | Описание |
|------|----------|
| Split Fireball | Explodes into 4 smaller fireballs, -30% dmg |
| Meteor | 3x size/explosion, 40% slower |
| Piercing Blaze | +4 pierce |

### Orbiting Arcana
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | 3 blades |
| 2 | 1.25 | +1 blade |
| 3 | 1.5 | +1 blade |
| 4 | 1.8 | +1 blade |
| 5 | 2.2 | +2 blades |

| Мода | Описание |
|------|----------|
| Pulsating Vortex | Orbit radius pulses -40% to +80% over 2s, 1.8x orbit radius, -15% dmg |
| Blade Strike | Every 3s a blade flies to nearest enemy for 200% dmg, then returns |
| Cross Storm | +4 counter-rotating blades, -25% dmg each |

### Lightning Strike
| Уровень | damage_mult | chain_count_add | Доп. эффекты |
|---------|-------------|-----------------|--------------|
| 1 | 1.0 | 0 | 2 chains base |
| 2 | 1.25 | +2 | — |
| 3 | 1.5 | 0 | +1 strike |
| 4 | 1.8 | +3 | — |
| 5 | 2.2 | 0 | +1 strike |

| Мода | Описание |
|------|----------|
| Chain Amplifier | +8 chains, range 250, -25% dmg |
| Overcharge | 3x damage, 3x size, no chains |
| Rapid Bolt | -50% cooldown, -20% dmg |

### Cyclone
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | +30% area/duration |
| 3 | 1.5 | +1 vortex |
| 4 | 1.8 | +50% area/duration |
| 5 | 2.2 | +2 vortexes |

| Мода | Описание |
|------|----------|
| Gravity Well | No damage, 5x pull strength, 2x zone radius |
| Seeking Wind | Vortex chases enemies, +40% speed, -15% dmg |
| Twin Cyclone | Paired vortexes around shared axis, 2.5x area, 1.5x dmg |

### Arcane Ray
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | +25% width |
| 3 | 1.5 | +1 ray |
| 4 | 1.8 | +50% width |
| 5 | 2.2 | +2 rays |

| Мода | Описание |
|------|----------|
| Spinning Prism | 5 rays in 90° fan, whole structure rotates, -40% each |
| Photon | 2.5x damage, fires as short pulse every 1.5s, 1.8x width |
| Refraction | Ray reflects off screen edges up to 2 times, -15% dmg |

### Electric Zone
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | 3 arcs |
| 2 | 1.25 | +15% area |
| 3 | 1.5 | +1 arc |
| 4 | 1.8 | +30% area |
| 5 | 2.2 | +2 arcs |

| Мода | Описание |
|------|----------|
| Shockwave | Every 3s emits expanding ring + knockback, 1.3x zone |
| Arc Flash | 3x tick speed, -50% dmg per tick |
| Chain Lightning | Each arc chains to +3 enemies outside zone |

### Spirit
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | 1 spirit |
| 2 | 1.25 | +20% bolt speed |
| 3 | 1.5 | +1 spirit |
| 4 | 1.8 | -30% attack cd |
| 5 | 2.2 | +2 spirits |

| Мода | Описание |
|------|----------|
| Phantom Legion | +3 spirits, each targets different enemy, -30% dmg |
| Phantom Blades | Spirits deal instant damage instead of firing bolts, -15% dmg |
| Haunt | Spirits fly to enemies and explode for 150% dmg AoE, 2s recovery |

### Shield
| Уровень | Заряды | Доп. эффекты |
|---------|--------|--------------|
| 1 | 2 | — |
| 2 | 3 | -5% recharge |
| 3 | 4 | -10% recharge |
| 4 | 5 | -15% recharge |
| 5 | 7 | -20% recharge |

| Мода | Описание |
|------|----------|
| Thorns | On absorb: 100% spell dmg to enemies in range 100, +20% recharge |
| Refraction | On absorb: 6 homing magic projectiles in all directions |
| Aegis | 1 charge, absorbs all damage fully, -60% recharge |

### Fire Breath
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | +20% range |
| 3 | 1.5 | +30% cone angle |
| 4 | 1.8 | +40% range |
| 5 | 2.2 | +60% cone angle |

| Мода | Описание |
|------|----------|
| Dragon Breath | Narrow beam (angle×0.5), +150% range, +50% dmg |
| Fire Fan | 3 cones in 120° fan, -20% dmg each |
| Burning Ash | Burning ground trail for 3s, +30% dmg on direct hit |

### Needle
| Уровень | damage_mult | Доп. эффекты |
|---------|-------------|--------------|
| 1 | 1.0 | — |
| 2 | 1.25 | +20% length |
| 3 | 1.5 | +1 needle parallel |
| 4 | 1.8 | +40% length |
| 5 | 2.2 | +2 needles |

| Мода | Описание |
|------|----------|
| Needle Volley | 7 needles in 45° cone burst, +30% cd |
| Ricochet Needle | Needles bounce off screen edges 3 times, +2 mini-needles per bounce, -15% dmg |
| Frost Shard | Freezes enemies 1.5s, -20% dmg, -15% atk speed |

---

## 9. Визуальная система: Сочность и Контраст

### 9.1 WorldEnvironment + Glow (Пост-обработка)

**Файл:** `Scenes/default_env.tres`  
**Узел:** `WorldEnvironment` в `main.tscn`

Glow работает как пост-обработка — только пиксели с яркостью > 1.0 (HDR) испускают свечение. Это заменяет PointLight2D для заклинаний.

| Параметр | Значение | Описание |
|----------|----------|----------|
| `glow_enabled` | true | Включить свечение |
| `glow_blend_mode` | ADDITIVE (1) | Режим сложения |
| `glow_hdr_threshold` | 1.0 | Порог HDR — светятся только пиксели > 1.0 |
| `glow_hdr_scale` | 2.0 | Усиление HDR-диапазона |
| `glow_intensity` | 0.8 | Сила свечения |
| `glow_strength` | 1.0 | Радиус свечения |
| `glow_bloom` | 0.0 | Без bloom (только HDR glow) |
| `tonemap_mode` | FILMIC (2) | Тональная компрессия ACES-подобная |

### 9.2 CanvasModulate (Тонировка мира)

**Узел:** `CanvasModulate` в `main.tscn`  
**Цвет:** `Color(0.239, 0.290, 0.361)` — gothic blue (#3d4a5c)

Умножается на ВСЕ canvas items. Спеллы не темнеют благодаря HDR-цветам (> 1.0) и `LIGHT_MODE_UNSHADED` — даже после умножения на тёмный tint их пиксели остаются выше 1.0 и активируют Glow.

### 9.3 Цветовая коррекция (Color Correction Shader)

**Файл:** `Shaders/color_correction.gdshader`  
**Узел:** `ColorRect` → `UI/ColorFilter` в `main.tscn`

| Uniform | По умолчанию | Описание |
|---------|-------------|----------|
| `contrast` | 1.15 | Контраст (1.0 = нет изменений) |
| `saturation` | 1.25 | Насыщенность (1.0 = нет изменений) |

Читает `SCREEN_TEXTURE` через `BackBufferCopy`, применяет контраст + насыщенность ко всему кадру.

### 9.4 Теневые MultiMesh (Тени под врагами и орбами)

**Утилита:** `Systems/ShadowTexture.gd` (процедурная текстура овала 32×32)

Каждый MultiMesh-менеджер получил «теневого близнеца» — второй `MultiMeshInstance2D`, обновляемый в том же `_process` цикле:

| Менеджер | Поле тени | Смещение Y | Alpha |
|----------|-----------|------------|-------|
| `SwarmManager` | `_mm_shadow` | +8.0 | 0.45 |
| `EnemyMeshManager` | `td.mm_shadow` (per type) | +8.0 | 0.45 |
| `OrbManager` | `_mm_shadow` | +5.0 | 0.35 |

Текстура: одна общая `ShadowTexture.get_texture()` (эллипс с квадратичным затуханием).  
Z-index: 0 (ниже врагов z=1, выше мира).  
Material: `BLEND_MODE_MIX` + `LIGHT_MODE_NORMAL` (тени ДОЛЖНЫ быть затенены CanvasModulate).

### 9.5 Режимы Light Mode и Blend Mode для спеллов

Все заклинания и VFX получили иммунитет к CanvasModulate и 2D-светам:

| Компонент | Свойство | Значение |
|-----------|----------|----------|
| 14 `CanvasItemMaterial` (Spells/visuals) | `light_mode` | `LIGHT_MODE_UNSHADED` |
| `Projectile.gd`, `FireballProjectile.gd` | `light_mode` | `LIGHT_MODE_UNSHADED` |
| `FireBreathPuff.gd` (local ci_mat) | `light_mode` | `LIGHT_MODE_UNSHADED` |
| `VFXManager.gd` (GPU particles) | `light_mode` | `LIGHT_MODE_UNSHADED` |
| `SwarmShader.gdshader` | `render_mode` | `unshaded` |
| `OrbShader.gdshader` | `render_mode` | `unshaded` |
| `BurstParticleGradientMapAdd.gdshader` | `render_mode` | `blend_add, unshaded` |
| `BurstParticleGradientMap.gdshader` | `render_mode` | `blend_mix, unshaded` |

Все blend_mode остаются ADD для заклинаний (было до изменения, не тронуто).

---

## 10. Профайлер

**Файл:** `Systems/ActionProfiler.gd` (autoload)

- **F9** — сводка в консоль
- CSV лог: `user://profiler_*.csv`
- Авто-сводка при game_over / victory
- Колонки: frame, timestamp, category, action, fps_before/after, delta_fps, process_before/after, objects_before/after, draw_calls_before/after, items_drawn_before/after
