extends Node

var _recipes: Dictionary = {}
var _icon_paths: Dictionary = {
	&"inferno_nova": "res://Sprites/inferno_nova_icon_pix.png",
	&"thunderbolt": "res://Sprites/thunder_arrow_icon_pix.png",
	&"astral_swarm": "res://Sprites/astral_swarm_icon_pix.png",
	&"firenado": "res://Sprites/fire_tornado_icon_pix.png",
	&"toxic_needles": "res://Sprites/toxic_needles_icon_pix.png",
	&"arcane_prison": "res://Sprites/arcane_prison_icon_pix.png",
	&"photon_storm": "res://Sprites/photon_storm_icon_pix.png",
	&"phase_bolt": "res://Sprites/phase_missile_icon_pix.png",
	&"galvanic_chain": "res://Sprites/galvanic_chain_icon_pix.png",
	&"arc_overload": "res://Sprites/arc_overload_icon_pix.png",
	&"seismic_pulse": "res://Sprites/seismic_pulse_icon_pix.png",
	&"phantom_orbit": "res://Sprites/phantom_orbit_icon_pix.png",
	&"soul_burst": "res://Sprites/soul_explosion_icon_pix.png",
	&"blade_vortex": "res://Sprites/blade_vortex_icon_pix.png",
	&"crystal_aegis": "res://Sprites/crystal _shield_icon_pix.png",
	&"flame_ward": "res://Sprites/flame_ward_icon_pix.png",
	&"mirror_shards": "res://Sprites/mirror_shards_icon_pix.png",
	&"frost_lance": "res://Sprites/ice_lance_icon_pix.png",
	&"toxic_bloom": "res://Sprites/toxic_flower_icon_pix.png",
}

func _ready() -> void:
	_register_recipes()

func _register_recipes() -> void:
	_register_recipe(&"inferno_nova", &"fireball", &"frost_nova",
		&"fireball_meteor", &"frost_nova_permafrost",
		"Inferno Nova", "Инферно Нова",
		"Поочерёдно создаёт огненные и ледяные волны урона вокруг игрока. Чередует типы взрывов.",
		["Урон по области вокруг игрока.",
		 "Пробивает 3 врагов."],
		["Долгая перезарядка (12с)."],
		Color(1.0, 0.7, 0.1), Color(0.4, 0.7, 1.0), 1.5, 50.0, 12.0, 250.0, 3)

	_register_recipe(&"thunderbolt", &"lightning_strike", &"needle",
		&"lightning_strike_overcharge", &"needle_ricochet",
		"Thunderbolt", "Громовая Стрела",
		"Вызывает 4 молнии, каждая бьёт ближайшего врага и цепляется к 3 дополнительным на 50% урона.",
		["4 молнии за один удар.",
		 "Цепная реакция на 3 врагов."],
		["Долгая перезарядка (18с)."],
		Color(0.5, 0.8, 1.0), Color(0.3, 0.5, 1.0), 1.8, 35.0, 18.0, 300.0, 4)

	_register_recipe(&"astral_swarm", &"spirit", &"magic_bolt",
		&"spirit_phantom", &"magic_bolt_storm",
		"Astral Swarm", "Астральный Рой",
		"Выпускает 3 магических снаряда, разлетающихся в случайные стороны с разбросом.",
		["3 снаряда за один выстрел.",
		 "Широкое покрытие области."],
		["Случайное направление полёта."],
		Color(0.7, 0.6, 1.0), Color(0.4, 0.3, 0.8), 2.0, 40.0, 15.0, 200.0, 3)

	_register_recipe(&"firenado", &"cyclone", &"fire_breath",
		&"cyclone_twin", &"fire_breath_dragon",
		"Firenado", "Огненный Торнадо",
		"Создаёт огненный торнадо, который мчится в случайном направлении 3 секунды, нанося постоянный урон.",
		["Непрерывный урон на протяжении 3с.",
		 "Подвижный снаряд."],
		["Случайное направление. Не Upgrade."],
		Color(1.0, 0.5, 0.1), Color(0.8, 0.2, 0.05), 1.6, 60.0, 10.0, 220.0, 2)

	_register_recipe(&"toxic_needles", &"poison_pool", &"needle",
		&"poison_pool_plague", &"needle_volley",
		"Toxic Needles", "Токсичные Иглы",
		"Выпускает 3 токсичные иглы по кругу. Каждая игла наносит прямой урон и оставляет ядовитую лужу.",
		["Прямой урон + урон от лужи.",
		 "3 иглы по кругу на 360°."],
		["Разброс по кругу, не по целям."],
		Color(0.3, 0.8, 0.3), Color(0.6, 0.9, 0.2), 1.7, 45.0, 14.0, 280.0, 3)

	_register_recipe(&"arcane_prison", &"arcane_ray", &"shield",
		&"arcane_ray_refraction", &"shield_aegis",
		"Arcane Prison", "Тайная Тюрьма",
		"Создаёт мощный тайный взрыв вокруг игрока, поражая всех врагов в области.",
		["Мгновенный урон по области.",
		 "Пробивает 3 врагов."],
		["Маленький радиус. Долгая КД (20с)."],
		Color(1.0, 0.4, 0.7), Color(0.9, 0.9, 1.0), 2.2, 30.0, 20.0, 0.0, 1)

	_register_recipe(&"photon_storm", &"arcane_ray", &"lightning_strike",
		&"arcane_ray_photon", &"lightning_strike_chain",
		"Photon Storm", "Фотонная Буря",
		"Вызывает 2 фотонных удара по ближайшим врагам. Каждый наносит огромный урон по области.",
		["Очень высокий урон за удар.",
		 "Автонаведение на врагов."],
		["Только 2 цели. КД 16с."],
		Color(1.0, 0.85, 0.3), Color(0.5, 0.8, 1.0), 2.5, 45.0, 16.0, 350.0, 2)

	_register_recipe(&"phase_bolt", &"magic_bolt", &"cyclone",
		&"magic_bolt_homing", &"cyclone_gale",
		"Phase Bolt", "Фазовый Снаряд",
		"Выпускает мощный фазовый снаряд, который самонаводится на ближайшего врага в радиусе 600.",
		["Дальность 600, гарантированное попадание.",
		 "Пробивает 3 врагов."],
		["Один снаряд за раз. КД 13с."],
		Color(0.4, 0.7, 1.0), Color(1.0, 0.4, 0.2), 1.9, 55.0, 13.0, 280.0, 5)

	_register_recipe(&"galvanic_chain", &"electric_zone", &"lightning_strike",
		&"electric_zone_chain", &"lightning_strike_rapid",
		"Galvanic Chain", "Гальваническая Цепь",
		"Запускает цепную молнию из позиции игрока, которая перескакивает через 6 врагов подряд.",
		["Поражает 6 врагов за раз.",
		 "Быстрая перезарядка (8с)."],
		["Начинается от игрока, не от врага."],
		Color(0.6, 0.8, 1.0), Color(0.5, 0.8, 1.0), 1.4, 100.0, 8.0, 0.0, 6)

	_register_recipe(&"arc_overload", &"electric_zone", &"fire_breath",
		&"electric_zone_arc", &"fire_breath_fan",
		"Arc Overload", "Дуговая Перегрузка",
		"Вызывает мощный электрический взрыв вокруг игрока. Сильная тряска экрана.",
		["Широкая область поражения.",
		 "Мощный удар с тряской."],
		["Вокруг игрока. КД 11с."],
		Color(0.9, 0.9, 1.0), Color(1.0, 0.35, 0.5), 2.0, 80.0, 11.0, 0.0, 4)

	_register_recipe(&"seismic_pulse", &"cyclone", &"needle",
		&"cyclone_gravity", &"needle_frost",
		"Seismic Pulse", "Сейсмический Импульс",
		"Создаёт 3 последовательных сейсмических волны, расширяющихся от игрока. Каждая следующая шире, но слабее.",
		["3 волны за один удар.",
		 "Расширяющаяся область."],
		["Убывающий урон. КД 15с."],
		Color(0.5, 0.2, 0.9), Color(0.6, 0.7, 0.95), 1.8, 120.0, 15.0, 0.0, 3)

	_register_recipe(&"phantom_orbit", &"spirit", &"orbiting_arcana",
		&"spirit_blades", &"orbiting_arcana_vortex",
		"Phantom Orbit", "Призрачная Орбита",
		"Призывает 4 призрачных клинка, которые наносят удары в случайных точках вокруг игрока в радиусе 90.",
		["4 удара за раз по случайным точкам.",
		 "Покрытие всей области вокруг."],
		["Случайное попадание. КД 14с."],
		Color(1.0, 0.3, 0.2), Color(0.2, 0.6, 1.0), 2.1, 90.0, 14.0, 180.0, 4)

	_register_recipe(&"soul_burst", &"spirit", &"fireball",
		&"spirit_haunt", &"fireball_split",
		"Soul Burst", "Взрыв Души",
		"Посылает душ к 3 ближайшим врагам в радиусе 500. Каждая душа взрывается при попадании.",
		["3 целенаправленных удара.",
		 "Дальность 500, AoE взрыв."],
		["Долгая перезарядка (17с)."],
		Color(0.35, 0.15, 0.6), Color(1.5, 0.7, 0.2), 2.3, 70.0, 17.0, 200.0, 3)

	_register_recipe(&"blade_vortex", &"orbiting_arcana", &"cyclone",
		&"orbiting_arcana_cross", &"cyclone_gale",
		"Blade Vortex", "Клинковый Вихрь",
		"Создаёт мощный вихрь клинков вокруг игрока, поражая всех врагов в широкой области.",
		["Широкая область поражения.",
		 "Мгновенный урон по области."],
		["Вокруг игрока. КД 12с."],
		Color(0.8, 0.3, 1.0), Color(1.0, 0.4, 0.2), 1.7, 100.0, 12.0, 200.0, 6)

	_register_recipe(&"crystal_aegis", &"shield", &"frost_nova",
		&"shield_thorns", &"frost_nova_crystallize",
		"Crystal Aegis", "Кристальный Щит",
		"Проецирует кристальную ауру, которая наносит постоянный урон ледяной энергией всем врагам поблизости.",
		["Большой радиус (150).",
		 "Постоянное давление на врагов."],
		["Долгая перезарядка (18с)."],
		Color(0.9, 0.3, 0.2), Color(0.5, 0.8, 1.0), 1.6, 150.0, 18.0, 0.0, 1)

	_register_recipe(&"flame_ward", &"shield", &"fire_breath",
		&"shield_refraction", &"fire_breath_ash",
		"Flame Ward", "Пламенная Охрана",
		"Извергает поток огненной энергии, сжигающий всех врагов в области вокруг игрока.",
		["Широкая область (120).",
		 "Постоянный огненный урон."],
		["Вокруг игрока. КД 16с."],
		Color(1.0, 0.85, 0.3), Color(0.7, 0.15, 0.05), 1.5, 120.0, 16.0, 0.0, 2)

	_register_recipe(&"mirror_shards", &"frost_nova", &"needle",
		&"frost_nova_shards", &"needle_volley",
		"Mirror Shards", "Зеркальные Осколки",
		"Раскалывается на 8 ледяных осколков, которые разлетаются во все стороны, поражая врагов по всей области.",
		["8 осколков на 360°.",
		 "Пробивает 3 врагов каждый."],
		["Случайные направления. КД 13с."],
		Color(0.7, 0.9, 1.0), Color(0.8, 0.85, 0.95), 1.9, 80.0, 13.0, 250.0, 8)

	_register_recipe(&"frost_lance", &"frost_nova", &"magic_bolt",
		&"frost_nova_permafrost", &"magic_bolt_chain",
		"Frost Lance", "Ледяное Копьё",
		"Запускает 2 ледяных копья, которые самонаводятся на ближайших врагов в радиусе 180.",
		["Автонаведение на врагов.",
		 "Пробивает 3 врагов."],
		["Только 2 копья. КД 14с."],
		Color(0.4, 0.7, 0.9), Color(0.4, 0.7, 1.0), 2.0, 60.0, 14.0, 300.0, 2)

	_register_recipe(&"toxic_bloom", &"poison_pool", &"fireball",
		&"poison_pool_bloom", &"fireball_meteor",
		"Toxic Bloom", "Токсичный Цветок",
		"Подрывает 3 токсичных цветка на позициях ближайших врагов в радиусе 400. Каждый наносит AoE урон.",
		["3 целенаправленных AoE удара.",
		 "Дальность 400, широкий радиус."],
		["КД 16с."],
		Color(0.4, 1.0, 0.2), Color(1.5, 0.7, 0.2), 2.4, 90.0, 16.0, 180.0, 3)

func _register_recipe(fusion_id: StringName, main_id: StringName, secondary_id: StringName,
	main_mod_id: StringName, secondary_mod_id: StringName,
	tr_name_en: String, tr_name_ru: String,
	desc: String, buffs: Array, debuffs: Array,
	color: Color, secondary_color: Color,
	dmg_mult: float, radius: float, cast_interval: float, speed: float, projectile_count: int) -> void:
	var key := _make_key(main_mod_id, secondary_mod_id)
	_recipes[key] = {
		"fusion_id": fusion_id,
		"main_id": main_id,
		"secondary_id": secondary_id,
		"main_mod_id": main_mod_id,
		"secondary_mod_id": secondary_mod_id,
		"tr_name_en": tr_name_en,
		"tr_name_ru": tr_name_ru,
		"desc": desc,
		"buffs": buffs,
		"debuffs": debuffs,
		"color": color,
		"secondary_color": secondary_color,
		"damage_mult": dmg_mult,
		"radius": radius,
		"cast_interval": cast_interval,
		"speed": speed,
		"projectile_count": projectile_count,
		"icon_path": _icon_paths.get(fusion_id, ""),
	}

func _make_key(a: StringName, b: StringName) -> String:
	if String(a) < String(b):
		return String(a) + "+" + String(b)
	return String(b) + "+" + String(a)

func get_all_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in _recipes:
		result.append(_recipes[key])
	return result

func find_recipe(main_mod_id: StringName, secondary_mod_id: StringName) -> Dictionary:
	return _recipes.get(_make_key(main_mod_id, secondary_mod_id), {})

func get_fusion_spell(main_mod_id: StringName, secondary_mod_id: StringName) -> FusionSpell:
	var recipe := find_recipe(main_mod_id, secondary_mod_id)
	if recipe.is_empty():
		return null
	return _build_fusion_spell(recipe)

func find_recipes_involving_mod(mod_id: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for key: String in _recipes:
		var r: Dictionary = _recipes[key]
		if r["main_mod_id"] == mod_id or r["secondary_mod_id"] == mod_id:
			results.append(r)
	return results

func find_recipes_involving_spell(spell_id: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for key: String in _recipes:
		var r: Dictionary = _recipes[key]
		if r["main_id"] == spell_id or r["secondary_id"] == spell_id:
			results.append(r)
	return results

func get_all_eligible_fusions(owned_spells: Dictionary) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for key: String in _recipes:
		var r: Dictionary = _recipes[key]
		var main_id: StringName = r["main_id"]
		var secondary_id: StringName = r["secondary_id"]
		var main_mod_id: StringName = r["main_mod_id"]
		var secondary_mod_id: StringName = r["secondary_mod_id"]

		var main: Spell = owned_spells.get(main_id) as Spell
		var secondary: Spell = owned_spells.get(secondary_id) as Spell
		if not main or not secondary:
			continue
		if not main.is_max_level() or not secondary.is_max_level():
			continue
		if not main.active_modification or not secondary.active_modification:
			continue
		if main.active_modification.mod_id != main_mod_id:
			continue
		if secondary.active_modification.mod_id != secondary_mod_id:
			continue
		eligible.append(r)
	return eligible

func _build_fusion_spell(recipe: Dictionary) -> FusionSpell:
	var fusion := FusionSpell.new()
	fusion.fusion_id = recipe["fusion_id"]
	fusion.main_id = recipe["main_id"]
	fusion.secondary_id = recipe["secondary_id"]
	fusion.spell_id = recipe["fusion_id"]
	fusion.spell_name = recipe.get("tr_name_en", "")
	fusion.base_damage = 10.0 * recipe["damage_mult"]
	fusion.base_cooldown = recipe["cast_interval"]
	fusion.projectile_speed = recipe["speed"]
	fusion.projectile_count = recipe["projectile_count"]
	fusion.pierce = 3
	fusion.color = recipe["color"]
	fusion.max_level = 1
	fusion.current_level = 1
	fusion.behavior = _create_behavior(recipe)
	return fusion

func _create_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	match recipe["fusion_id"]:
		&"inferno_nova":
			var b := InfernoNovaBehavior.new()
			b.nova_radius = recipe["radius"]
			return b
		&"thunderbolt":
			var b := ThunderboltBehavior.new()
			b.bolt_range = recipe["radius"] * 5.0
			b.chain_count = recipe["projectile_count"]
			return b
		&"astral_swarm":
			var b := AstralSwarmBehavior.new()
			b.orb_count = recipe["projectile_count"]
			b.attack_range = recipe["radius"] * 4.0
			return b
		&"firenado":
			var b := FirenadoBehavior.new()
			b.tornado_speed = recipe["speed"] * 0.5
			b.tornado_radius = recipe["radius"]
			return b
		&"toxic_needles":
			var b := ToxicNeedlesBehavior.new()
			b.needle_speed = recipe["speed"]
			b.pool_radius = recipe["radius"] * 0.4
			return b
		&"arcane_prison":
			return _create_arcane_prison_behavior(recipe)
		&"photon_storm":
			return _create_photon_storm_behavior(recipe)
		&"phase_bolt":
			return _create_phase_bolt_behavior(recipe)
		&"galvanic_chain":
			return _create_galvanic_chain_behavior(recipe)
		&"arc_overload":
			return _create_arc_overload_behavior(recipe)
		&"seismic_pulse":
			return _create_seismic_pulse_behavior(recipe)
		&"phantom_orbit":
			return _create_phantom_orbit_behavior(recipe)
		&"soul_burst":
			return _create_soul_burst_behavior(recipe)
		&"blade_vortex":
			return _create_blade_vortex_behavior(recipe)
		&"crystal_aegis":
			return _create_crystal_aegis_behavior(recipe)
		&"flame_ward":
			return _create_flame_ward_behavior(recipe)
		&"mirror_shards":
			return _create_mirror_shards_behavior(recipe)
		&"frost_lance":
			return _create_frost_lance_behavior(recipe)
		&"toxic_bloom":
			return _create_toxic_bloom_behavior(recipe)
	return null

func _create_arcane_prison_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := ArcanePrisonBehavior.new()
	b.prison_radius = recipe["radius"]
	b.prison_duration = 3.0
	return b

func _create_photon_storm_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := PhotonStormBehavior.new()
	b.storm_radius = recipe["radius"]
	b.bolt_count = recipe["projectile_count"]
	return b

func _create_phase_bolt_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := PhaseBoltBehavior.new()
	b.bolt_speed = recipe["speed"]
	b.pierce_count = recipe["projectile_count"]
	return b

func _create_galvanic_chain_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := GalvanicChainBehavior.new()
	b.chain_radius = recipe["radius"]
	b.chain_count = recipe["projectile_count"]
	return b

func _create_arc_overload_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := ArcOverloadBehavior.new()
	b.overload_radius = recipe["radius"]
	b.arc_count = recipe["projectile_count"]
	return b

func _create_seismic_pulse_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := SeismicPulseBehavior.new()
	b.pulse_radius = recipe["radius"]
	b.pulse_count = recipe["projectile_count"]
	return b

func _create_phantom_orbit_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := PhantomOrbitBehavior.new()
	b.orbit_count = recipe["projectile_count"]
	b.orbit_radius = recipe["radius"]
	return b

func _create_soul_burst_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := SoulBurstBehavior.new()
	b.burst_radius = recipe["radius"]
	b.burst_count = recipe["projectile_count"]
	return b

func _create_blade_vortex_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := BladeVortexBehavior.new()
	b.blade_count = recipe["projectile_count"]
	b.vortex_radius = recipe["radius"]
	return b

func _create_crystal_aegis_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := CrystalAegisBehavior.new()
	b.aura_radius = recipe["radius"]
	b.charge_count = recipe["projectile_count"]
	return b

func _create_flame_ward_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := FlameWardBehavior.new()
	b.ward_radius = recipe["radius"]
	b.tick_count = recipe["projectile_count"]
	return b

func _create_mirror_shards_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := MirrorShardsBehavior.new()
	b.shard_count = recipe["projectile_count"]
	b.shard_radius = recipe["radius"]
	return b

func _create_frost_lance_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := FrostLanceBehavior.new()
	b.lance_range = recipe["radius"] * 3.0
	b.lance_count = recipe["projectile_count"]
	return b

func _create_toxic_bloom_behavior(recipe: Dictionary) -> BaseSpellBehavior:
	var b := ToxicBloomBehavior.new()
	b.bloom_radius = recipe["radius"]
	b.bloom_count = recipe["projectile_count"]
	return b
