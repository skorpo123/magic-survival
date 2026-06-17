extends Node

var equipped: Array[ArtifactData] = []
var _catalog: Array[ArtifactData] = []

var _cached_xp_mult: float = 1.0
var _cached_life_steal: float = 0.0
var _cached_crit_chance: float = 0.0
var _cached_dodge_chance: float = 0.0
var _cached_regen: float = 0.0
var _cached_pickup_mult: float = 1.0
var _cached_move_speed_mult: float = 1.0
var _cached_max_hp_mult: float = 1.0
var _cached_cooldown_reduce: float = 0.0
var _cached_knockback: float = 1.0
var _cached_damage_mult: float = 1.0
var _cached_projectile_speed_mult: float = 1.0
var _cached_area_mult: float = 1.0
var _cached_duration_mult: float = 1.0
var _cached_boss_damage_mult: float = 1.0
var _cached_on_kill_regen: float = 0.0
var _cached_pierce_add: int = 0
var _cached_missing_hp_damage_mult: float = 1.0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.artifact_equipped.connect(_apply)
	_build_catalog()

func _on_game_started() -> void:
	equipped.clear()
	_reset_cache()
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats:
		var stats: PlayerStats = player.stats
		stats.remove_meta(&"raw_move_speed")
		stats.remove_meta(&"raw_max_hp")
		stats.remove_meta(&"raw_pickup_range")
		stats.remove_meta(&"raw_hp_regen")
		stats.remove_meta(&"raw_dodge_chance")
		stats.remove_meta(&"raw_magic_power")
		stats.remove_meta(&"raw_crit_chance")
		stats.remove_meta(&"raw_life_steal")
		stats.remove_meta(&"raw_projectile_speed_mult")
		stats.remove_meta(&"raw_area_multiplier")
		stats.remove_meta(&"raw_spell_duration_mult")

func _reset_cache() -> void:
	_cached_xp_mult = 1.0
	_cached_life_steal = 0.0
	_cached_crit_chance = 0.0
	_cached_dodge_chance = 0.0
	_cached_regen = 0.0
	_cached_pickup_mult = 1.0
	_cached_move_speed_mult = 1.0
	_cached_max_hp_mult = 1.0
	_cached_cooldown_reduce = 0.0
	_cached_knockback = 1.0
	_cached_damage_mult = 1.0
	_cached_projectile_speed_mult = 1.0
	_cached_area_mult = 1.0
	_cached_duration_mult = 1.0
	_cached_boss_damage_mult = 1.0
	_cached_on_kill_regen = 0.0
	_cached_pierce_add = 0
	_cached_missing_hp_damage_mult = 1.0

func _is_global_artifact(artifact: ArtifactData) -> bool:
	return artifact.target_spell_name == &"" and artifact.target_spell_type == &"" and artifact.target_spell_ids.is_empty()

func _matches(artifact: ArtifactData, spell_name: StringName, spell_type: StringName) -> bool:
	if artifact.target_spell_ids.size() > 0:
		return spell_name in artifact.target_spell_ids
	return (artifact.target_spell_name == &"" or artifact.target_spell_name == spell_name) and (artifact.target_spell_type == &"" or artifact.target_spell_type == spell_type)

func ae(type: ArtifactEffect.EffectType, val: float) -> ArtifactEffect:
	var e := ArtifactEffect.new()
	e.effect_type = type
	e.value = val
	return e

func _add_artifact(en_name: String, ru_name: String, en_desc: String, ru_desc: String,
		rarity: int, target_type: StringName,
		bonuses: Array[ArtifactEffect], debuffs: Array[ArtifactEffect],
		target_ids: Array[StringName] = []) -> void:
	var a := ArtifactData.new()
	a.artifact_name = en_name
	a.description = en_desc
	var snake := en_name.to_snake_case().replace("'", "")
	a.name_key = &"art_" + snake
	a.desc_key = &"art_desc_" + snake
	a.rarity = rarity
	a.target_spell_type = target_type
	a.bonuses = bonuses
	a.debuffs = debuffs
	a.target_spell_ids = target_ids
	_catalog.append(a)

func _build_catalog() -> void:
	_catalog.clear()

	# === COMMON (10) ===
	_add_artifact("Grimoire Page", "Страница гримуара",
		"+10% damage to all spells", "+10% урон ко всем заклинаниям",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.1)], [])

	_add_artifact("Rune of Haste", "Руна стремительности",
		"+15% cooldown reduction", "+15% сокращение перезарядки",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.15)], [])

	_add_artifact("Lucky Coin", "Счастливая монета",
		"+20% XP gained from all sources", "+20% опыта из всех источников",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.XP_MULT, 1.2)], [])

	_add_artifact("Magnetic Core", "Магнитное ядро",
		"+50% pickup range", "+50% радиус сбора",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.PICKUP_RANGE_MULT, 1.5)], [])

	_add_artifact("Swift Boots", "Сапоги скорости",
		"+15% move speed", "+15% скорость передвижения",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 1.15)], [])

	_add_artifact("Iron Will", "Железная воля",
		"+5% dodge chance", "+5% шанс уворота",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.DODGE_CHANCE, 0.05)], [])

	_add_artifact("Vitality Dew", "Роса жизненной силы",
		"+10% max HP", "+10% макс. ОЗ",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 1.1)], [])

	_add_artifact("Quickdraw Charm", "Амулет быстрой руки",
		"+15% projectile speed", "+15% скорость снарядов",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.15)], [])

	_add_artifact("Mana Shard", "Осколок маны",
		"+10% cooldown reduction", "+10% сокращение перезарядки",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.10)], [])

	_add_artifact("Blood Gem", "Кровавый самоцвет",
		"+2% life steal", "+2% вампиризм",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.LIFE_STEAL, 0.02)], [])

	# === UNCOMMON (14) ===
	_add_artifact("Ember Core", "Огненное ядро",
		"+25% fire damage, +15% fire area", "+25% огненный урон, +15% область огня",
		ItemRarity.Tier.UNCOMMON, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.AREA_MULT, 1.15)], [])

	_add_artifact("Arcane Crystal", "Тайный кристалл",
		"+20% arcane damage, +1 projectile", "+20% тайный урон, +1 снаряд",
		ItemRarity.Tier.UNCOMMON, &"arcane",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)], [])

	_add_artifact("Storm Capacitor", "Штормовой конденсатор",
		"+1 chain jump for lightning", "+1 прыжок цепи для молний",
		ItemRarity.Tier.UNCOMMON, &"lightning",
		[ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0)], [])

	_add_artifact("Frost Shard", "Ледяной осколок",
		"+30% cold area, +20% duration", "+30% область холода, +20% длительность",
		ItemRarity.Tier.UNCOMMON, &"cold",
		[ae(ArtifactEffect.EffectType.AREA_MULT, 1.3), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.2)], [])

	_add_artifact("Vitality Heart", "Сердце жизни",
		"+25% max HP, +0.5 HP/s regen", "+25% макс. ОЗ, +0.5 ОЗ/с реген.",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 1.25), ae(ArtifactEffect.EffectType.REGEN, 0.5)], [])

	_add_artifact("Mana Crystal", "Кристалл маны",
		"-20% cooldown for all spells", "-20% перезарядка всех заклинаний",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.2)], [])

	_add_artifact("Rapid Quiver", "Скорый колчан",
		"+25% projectile speed for all", "+25% скорость снарядов всех заклинаний",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.25)], [])

	_add_artifact("Seeker's Eye", "Око искателя",
		"+30% pickup range, +10% XP", "+30% радиус сбора, +10% опыта",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.PICKUP_RANGE_MULT, 1.3), ae(ArtifactEffect.EffectType.XP_MULT, 1.1)], [])

	_add_artifact("Battle Focus", "Боевой фокус",
		"+10% damage, +10% crit chance", "+10% урон, +10% шанс крита",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.1), ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.10)], [])

	_add_artifact("Tiny Menace", "Крошечная угроза",
		"25% smaller, +5% dodge chance", "На 25% меньше, +5% шанс уворота",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.TINY_MENACE, 0.0), ae(ArtifactEffect.EffectType.DODGE_CHANCE, 0.05)], [])

	_add_artifact("Flame Tongue", "Пламенный язык",
		"+20% fire damage, +1 projectile", "+20% огненный урон, +1 снаряд",
		ItemRarity.Tier.UNCOMMON, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)], [])

	_add_artifact("Static Charge", "Статический заряд",
		"+15% lightning damage, +1 chain", "+15% урон молнией, +1 прыжок цепи",
		ItemRarity.Tier.UNCOMMON, &"lightning",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15), ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0)], [])

	_add_artifact("Blizzard Heart", "Сердце бури",
		"+25% cold damage, +15% cold area", "+25% урон холода, +15% область холода",
		ItemRarity.Tier.UNCOMMON, &"cold",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.AREA_MULT, 1.15)], [])

	_add_artifact("Second Wind", "Второе дыхание",
		"When HP < 25%: heal 50% over 3s (60s cd)", "При HP < 25%: лечение 50% за 3с (60с кд)",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.SECOND_WIND, 0.0)], [])

	# === RARE (16) ===
	_add_artifact("Bloodstone", "Кровавый камень",
		"+25% crit chance, +10% damage", "+25% шанс крита, +10% урон",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.25), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.1)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.85)])

	_add_artifact("Ember Sigil", "Печать углей",
		"+30% fire damage, +25% fire area", "+30% огненный урон, +25% область огня",
		ItemRarity.Tier.RARE, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.AREA_MULT, 1.25)], [])

	_add_artifact("Storm Eye", "Око бури",
		"+20% lightning damage, +1 chain", "+20% урон молнией, +1 прыжок цепи",
		ItemRarity.Tier.RARE, &"lightning",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0)], [])

	_add_artifact("Frozen Heart", "Ледяное сердце",
		"+35% cold area, +20% cold duration", "+35% область холода, +20% длительность холода",
		ItemRarity.Tier.RARE, &"cold",
		[ae(ArtifactEffect.EffectType.AREA_MULT, 1.35), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.2)], [])

	_add_artifact("Bouncing Essence", "Прыгучая эссенция",
		"+1 chain, +20% arcane duration", "+1 прыжок цепи, +20% длительность тайных",
		ItemRarity.Tier.RARE, &"arcane",
		[ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.2)], [])

	_add_artifact("Glass Cannon", "Стеклянная пушка",
		"+50% damage to all spells", "+50% урон ко всем заклинаниям",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.5)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.5)])

	_add_artifact("Spectral Touch", "Призрачное касание",
		"3% life steal from all damage", "3% вампиризм от всего урона",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.LIFE_STEAL, 0.03)], [])

	_add_artifact("Lethal Critical", "Смертельный крит",
		"+15% crit chance, +20% crit damage", "+15% шанс крита, +20% урон крита",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.15), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)], [])

	_add_artifact("Void Shard", "Осколок пустоты",
		"+10% all damage, +30% XP, +20% pickup", "+10% урон, +30% опыта, +20% сбор",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.1), ae(ArtifactEffect.EffectType.XP_MULT, 1.3), ae(ArtifactEffect.EffectType.PICKUP_RANGE_MULT, 1.2)], [])

	_add_artifact("Phoenix Feather", "Перо феникса",
		"+20% fire damage, +1 HP/s regen", "+20% огненный урон, +1 ОЗ/с реген.",
		ItemRarity.Tier.RARE, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.REGEN, 1.0)], [])

	_add_artifact("Lightning Rod", "Молниевой стержень",
		"+25% lightning damage, +2 chains", "+25% урон молнией, +2 прыжка цепи",
		ItemRarity.Tier.RARE, &"lightning",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.CHAIN_COUNT, 2.0)], [])

	_add_artifact("Permafrost Core", "Ядро вечной мерзлоты",
		"+30% cold damage, +25% cold duration", "+30% урон холода, +25% длительность холода",
		ItemRarity.Tier.RARE, &"cold",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.25)], [])

	_add_artifact("Arcane Focus", "Тайный фокус",
		"+25% arcane damage, +1 projectile", "+25% тайный урон, +1 снаряд",
		ItemRarity.Tier.RARE, &"arcane",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)], [])

	_add_artifact("Berserker's Mark", "Знак берсерка",
		"+30% damage, +15% move speed", "+30% урон, +15% скорость",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 1.15)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.9)])

	_add_artifact("Sage's Wisdom", "Мудрость мудреца",
		"+25% XP, -20% cooldown", "+25% опыта, -20% перезарядка",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.XP_MULT, 1.25), ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.2)], [])

	_add_artifact("Vampiric Fang", "Вампирский клык",
		"+5% life steal, +15% damage", "+5% вампиризм, +15% урон",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.LIFE_STEAL, 0.05), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15)], [])

	# === LEGENDARY (10) ===
	_add_artifact("Cursed Phylactery", "Проклятая филактерия",
		"×2 damage to all spells", "×2 урон ко всем заклинаниям",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 2.0)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.6)])

	_add_artifact("Spell Echo", "Эхо заклинаний",
		"+20% damage, every 10th cast duplicates", "+20% урон, каждое 10-е заклинание дублируется",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.SPELL_ECHO, 0.0), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.9)])

	_add_artifact("Overflow", "Переполнение",
		"25% of XP gained as temporary HP (decays 1/s)", "25% опыта → временные ОЗ (распад 1/с)",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.OVERFLOW, 0.0)], [])

	_add_artifact("Dragon's Heart", "Сердце дракона",
		"+40% fire damage, +30% fire area", "+40% огненный урон, +30% область огня",
		ItemRarity.Tier.LEGENDARY, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.AREA_MULT, 1.3)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.85)])

	_add_artifact("Static Aura", "Статическая аура",
		"Enemies within 80 take periodic damage (5 dmg/s)", "Враги в радиусе 80 получают периодический урон (5 урон/с)",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.STATIC_AURA, 0.0)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)])

	_add_artifact("Glacial Spire", "Ледяной шпиль",
		"+40% cold damage, +30% cold duration", "+40% урон холода, +30% длительность холода",
		ItemRarity.Tier.LEGENDARY, &"cold",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.3)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)])

	_add_artifact("Void Amulet", "Амулет пустоты",
		"+25% all damage, +2 projectiles, +15% XP", "+25% урон, +2 снаряда, +15% опыта",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 2.0), ae(ArtifactEffect.EffectType.XP_MULT, 1.15)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.85)])

	_add_artifact("Cascade", "Каскад",
		"Critical hits create shockwaves (50% dmg, 100 radius, 0.5s cd)", "Криты создают ударные волны (50% урона, 100 ед., 0.5с кд)",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.CRIT_CASCADE, 0.0)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.85)])

	_add_artifact("Chrono Shard", "Осколок времени",
		"-30% cooldown, +25% projectile speed", "-30% перезарядка, +25% скорость снарядов",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.3), ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.25)],
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 0.9)])

	_add_artifact("Infinity Flame", "Пламя бесконечности",
		"+35% fire damage, +30% area, +1 projectile", "+35% огненный урон, +30% область, +1 снаряд",
		ItemRarity.Tier.LEGENDARY, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.35), ae(ArtifactEffect.EffectType.AREA_MULT, 1.3), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.8)])

	# === NEW: Special effect artifacts per rarity ===

	# UNCOMMON — Low HP Explode
	_add_artifact("Explosive Tip", "Взрывной наконечник",
		"Killed enemies explode dealing AoE damage (15 dmg)", "Убитые враги взрываются, нанося AoE урон (15 урон)",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.LOW_HP_EXPLODE, 0.0)], [])

	# RARE — Move Trail
	_add_artifact("Phantom Speed", "Призрачная скорость",
		"Moving leaves a damage trail (5 dmg/sec)", "Движение оставляет след урона (5 урон/сек)",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.MOVE_TRAIL, 0.0)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.9)])

	# LEGENDARY — Damage Aura
	_add_artifact("Arcane Storm", "Тайный шторм",
		"Periodic AoE damage around player (8 dmg/s, scaled by magic power)", "Периодический урон по области (8 урон/с, масштабируется силой магии)",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_AURA, 0.0)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.85)])

	# LEGENDARY — Spell Split
	_add_artifact("Spell Weaver", "Ткач заклинаний",
		"Every 3rd spell cast fires 2 copies", "Каждое 3-е заклинание выпускает 2 копии",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.SPELL_SPLIT, 0.0), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15)],
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, -0.1)])

	# === POISON group ===
	_add_artifact("Plague Sigil", "Печать чумы",
		"+30% poison damage, poison zones tick 25% faster", "+30% урон яда, ядовитые зоны тикают на 25% чаще",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.DURATION_MULT, 1.25)],
		[], [&"poison_pool"])

	_add_artifact("Venom Codex", "Ядовитый кодекс",
		"+40% poison damage, +35% poison area, -10% move speed", "+40% урон яда, +35% область яда, -10% скорость",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.AREA_MULT, 1.35)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)], [&"poison_pool"])

	_add_artifact("Toxic Bloom", "Токсичный цветок",
		"On kill: 20% chance to create small poison zone (2s)", "При убийстве: 20% шанс создать малую ядовитую зону (2с)",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.TOXIC_BLOOM, 0.2)],
		[], [&"poison_pool"])

	_add_artifact("Miasma Flask", "Фляга миазмов",
		"+50% poison duration, poison slows enemies 20%", "+50% длительность яда, яд замедляет врагов на 20%",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DURATION_MULT, 1.5)],
		[], [&"poison_pool"])

	# === SPIRIT group ===
	_add_artifact("Soul Lantern", "Фонарь душ",
		"+30% spirit damage, spirit projectiles leave damage trails (1s)", "+30% урон духа, духи оставляют следы урона (1с)",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3)],
		[], [&"spirit"])

	_add_artifact("Wraith Mantle", "Плащ призрака",
		"+25% spirit damage, +20% projectile speed, +1 spirit projectile", "+25% урон духа, +20% скорость снарядов, +1 дух",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.2), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)],
		[], [&"spirit"])

	_add_artifact("Phantom Seal", "Печать призрака",
		"Spirit projectiles crit on first hit, +10% global crit", "Духи критят при первом ударе, +10% глобальный крит",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.1)],
		[], [&"spirit"])

	_add_artifact("Haunt Essence", "Эссенция проклятия",
		"+40% spirit damage vs bosses, +0.1 HP per spirit kill", "+40% урон духа по боссам, +0.1 ОЗ за убийство духом",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.ON_KILL_REGEN, 0.1)],
		[], [&"spirit"])

	# === PHYSICAL group ===
	_add_artifact("Whetstone", "Точильный камень",
		"+15% physical spell damage", "+15% урон физических заклинаний",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15)],
		[], [&"needle", &"orbiting_arcana", &"cyclone"])

	_add_artifact("Blade Rune", "Руна клинка",
		"+25% physical damage, +1 pierce", "+25% урон физических, +1 пробитие",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.25), ae(ArtifactEffect.EffectType.PIERCE_COUNT, 1.0)],
		[], [&"needle", &"orbiting_arcana", &"cyclone"])

	_add_artifact("Executioner's Brand", "Клеймо палача",
		"+50% damage to enemies below 30% HP", "+50% урон по врагам с HP < 30%",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.5)],
		[], [&"needle", &"orbiting_arcana", &"cyclone"])

	# === GLOBAL group ===
	_add_artifact("Orbweaver's Thread", "Нить орбиты",
		"+20% orbit speed (Orbiting Arcana)", "+20% скорость орбит",
		ItemRarity.Tier.COMMON, &"orbiting_arcana",
		[ae(ArtifactEffect.EffectType.PROJECTILE_SPEED, 1.2)], [])

	_add_artifact("Clockwork Cog", "Шестерёнка",
		"-10% cooldown, every 100 kills: -5% more (max -25%)", "-10% перезарядка, каждые 100 убийств: -5% ещё (макс -25%)",
		ItemRarity.Tier.COMMON, &"",
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, 0.1)], [])

	_add_artifact("Focus Gem", "Камень фокуса",
		"+20% damage to single-target spells", "+20% урон заклинаниям с одной целью",
		ItemRarity.Tier.UNCOMMON, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)], [])

	_add_artifact("Scholar's Monocle", "Монокль учёного",
		"+30% XP, every 5 levels: +5% all damage", "+30% опыта, каждые 5 уровней: +5% урон всем",
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
		"+0.3 HP per enemy killed", "+0.3 ОЗ за убитого врага",
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
		"+15% arcane damage, +1 arcane projectile", "+15% тайный урон, +1 снаряд",
		ItemRarity.Tier.RARE, &"arcane",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.15), ae(ArtifactEffect.EffectType.EXTRA_PROJECTILE, 1.0)], [])

	# === ELEMENT group ===
	_add_artifact("Glacial Core", "Ледяное ядро",
		"+40% cold duration, +20% cold damage, -10% move speed", "+40% длительность холода, +20% урон холода, -10% скорость",
		ItemRarity.Tier.RARE, &"cold",
		[ae(ArtifactEffect.EffectType.DURATION_MULT, 1.4), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.9)])

	_add_artifact("Conductor's Rod", "Стержень проводника",
		"+30% lightning damage, lightning always chains 1 time", "+30% урон молнией, молния всегда передаётся 1 раз",
		ItemRarity.Tier.RARE, &"lightning",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3), ae(ArtifactEffect.EffectType.CHAIN_COUNT, 1.0)], [])

	_add_artifact("Volcanic Glyph", "Вулканический glyph",
		"+20% fire damage, fire kills leave burning trail", "+20% огненный урон, убийства огнём оставляют горящий след",
		ItemRarity.Tier.UNCOMMON, &"fire",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.VOLCANIC_GLYPH, 0.0)], [])

	# === RISKY group ===
	_add_artifact("Martyr's Brand", "Клеймо мученика",
		"+1% damage per 1% missing HP, -20% max HP", "+1% урон за каждый % потерянного HP, -20% макс. ОЗ",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.MISSING_HP_DAMAGE, 1.9)],
		[ae(ArtifactEffect.EffectType.MAX_HP_MULT, 0.8)])

	_add_artifact("Twin Cast", "Двойной каст",
		"20% chance to cast spell twice, +25% cooldown", "20% шанс каста дважды, +25% перезарядка",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.TWIN_CAST, 0.2)],
		[ae(ArtifactEffect.EffectType.COOLDOWN_REDUCE, -0.25)])

	_add_artifact("Berserker's Oath", "Клятва берсерка",
		"x1.5 damage, regen disabled, life steal x2", "x1.5 урон, реген отключен, вампиризм x2",
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

	# === LEGENDARY group ===
	_add_artifact("Void Codex", "Кодекс пустоты",
		"+20% all damage, every 5th shot auto-crits", "+20% урон, каждое 5-е попадание крит",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2), ae(ArtifactEffect.EffectType.CRIT_CHANCE, 0.5)], [])

	_add_artifact("Inferno Grimoire", "Гrimуар инферно",
		"+35% fire, poison, lightning damage", "+35% урон огня, яда, молнии",
		ItemRarity.Tier.LEGENDARY, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.35)],
		[], [&"fireball", &"fire_breath", &"poison_pool", &"lightning_strike", &"electric_zone"])

	_add_artifact("Absolute Zero", "Абсолютный ноль",
		"+60% cold damage, +50% cold area", "+60% урон холода, +50% область холода",
		ItemRarity.Tier.LEGENDARY, &"cold",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.6), ae(ArtifactEffect.EffectType.AREA_MULT, 1.5)],
		[ae(ArtifactEffect.EffectType.MOVE_SPEED_MULT, 0.85)])

	# === FUSION group ===
	_add_artifact("Firenado Lens", "Линза Огненного вихря",
		"Firenado: +40% damage, +25% area", "Огненный вихрь: +40% урон, +25% область",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.4), ae(ArtifactEffect.EffectType.AREA_MULT, 1.25)],
		[], [&"firenado"])

	_add_artifact("Thunderbolt Coil", "Катушка молнии",
		"Thunderbolt: +2 chain jumps, +30% damage", "Thunderbolt: +2 прыжка цепи, +30% урон",
		ItemRarity.Tier.RARE, &"",
		[ae(ArtifactEffect.EffectType.CHAIN_COUNT, 2.0), ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.3)],
		[], [&"thunderbolt"])

	_add_artifact("Crystal Aegis Shard", "Осколок Кристального aegis",
		"Crystal Aegis: +40% shield absorb", "Кристальный aegis: +40% поглощение",
		ItemRarity.Tier.RARE, &"cold",
		[ae(ArtifactEffect.EffectType.DAMAGE_MULT, 1.2)],
		[], [&"crystal_aegis"])

func generate_offer(chest_rarity: int) -> Array[ArtifactData]:
	var pool: Array[ArtifactData] = []
	var extras: Array[ArtifactData] = []
	for a in _catalog:
		if a in equipped:
			continue
		if a.rarity == chest_rarity:
			pool.append(a)
		else:
			extras.append(a)
	if pool.size() < 3:
		for a in extras:
			if pool.size() >= 3:
				break
			pool.append(a)
	if pool.is_empty():
		return []
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func _apply(artifact: ArtifactData) -> void:
	equipped.append(artifact)
	_update_cache_for_artifact(artifact, true)
	_register_artifact_effects(artifact)
	if GameManager.get_player():
		recompute_player()

func _register_artifact_effects(_artifact: ArtifactData) -> void:
	pass

func recompute_player() -> void:
	var player := GameManager.get_player()
	if not player or not "stats" in player: return
	var stats: PlayerStats = player.stats
	if not stats: return
	_ensure_base(stats)
	_apply_artifacts_to(stats)
	if player.has_method("update_pickup_detector"):
		player.update_pickup_detector()

func _ensure_base(stats: PlayerStats) -> void:
	if not stats.has_meta(&"raw_move_speed"):
		stats.set_meta(&"raw_move_speed", stats.move_speed)
	if not stats.has_meta(&"raw_max_hp"):
		stats.set_meta(&"raw_max_hp", stats.max_hp)
	if not stats.has_meta(&"raw_pickup_range"):
		stats.set_meta(&"raw_pickup_range", stats.pickup_range)
	if not stats.has_meta(&"raw_hp_regen"):
		stats.set_meta(&"raw_hp_regen", stats.hp_regen)
	if not stats.has_meta(&"raw_dodge_chance"):
		stats.set_meta(&"raw_dodge_chance", stats.dodge_chance)
	if not stats.has_meta(&"raw_magic_power"):
		stats.set_meta(&"raw_magic_power", stats.magic_power)
	if not stats.has_meta(&"raw_crit_chance"):
		stats.set_meta(&"raw_crit_chance", stats.crit_chance)
	if not stats.has_meta(&"raw_life_steal"):
		stats.set_meta(&"raw_life_steal", stats.life_steal)
	if not stats.has_meta(&"raw_projectile_speed_mult"):
		stats.set_meta(&"raw_projectile_speed_mult", stats.projectile_speed_mult)
	if not stats.has_meta(&"raw_area_multiplier"):
		stats.set_meta(&"raw_area_multiplier", stats.area_multiplier)
	if not stats.has_meta(&"raw_spell_duration_mult"):
		stats.set_meta(&"raw_spell_duration_mult", stats.spell_duration_mult)

func _apply_artifacts_to(stats: PlayerStats) -> void:
	stats.move_speed = float(stats.get_meta(&"raw_move_speed")) * _cached_move_speed_mult
	stats.max_hp = float(stats.get_meta(&"raw_max_hp")) * _cached_max_hp_mult
	stats.pickup_range = float(stats.get_meta(&"raw_pickup_range")) * _cached_pickup_mult
	stats.hp_regen = float(stats.get_meta(&"raw_hp_regen")) + _cached_regen
	stats.dodge_chance = clampf(float(stats.get_meta(&"raw_dodge_chance")) + _cached_dodge_chance, 0.0, 0.75)
	stats.cooldown_reduction = clampf(_cached_cooldown_reduce, 0.0, 0.75)
	stats.magic_power = float(stats.get_meta(&"raw_magic_power")) * _cached_damage_mult
	stats.crit_chance = clampf(float(stats.get_meta(&"raw_crit_chance")) + _cached_crit_chance, 0.0, 1.0)
	stats.life_steal = clampf(float(stats.get_meta(&"raw_life_steal")) + _cached_life_steal, 0.0, 1.0)
	stats.projectile_speed_mult = float(stats.get_meta(&"raw_projectile_speed_mult")) * _cached_projectile_speed_mult
	stats.area_multiplier = float(stats.get_meta(&"raw_area_multiplier")) * _cached_area_mult
	stats.spell_duration_mult = float(stats.get_meta(&"raw_spell_duration_mult")) * _cached_duration_mult
	stats.current_hp = minf(stats.current_hp, stats.max_hp)

func _update_cache_for_artifact(artifact: ArtifactData, equip: bool) -> void:
	var sign_val: float = 1.0 if equip else -1.0
	for eff in artifact.bonuses:
		_apply_cache_delta(eff, sign_val)
	for eff in artifact.debuffs:
		_apply_cache_delta(eff, -sign_val)

func _apply_cache_delta(eff: ArtifactEffect, sign: float) -> void:
	match eff.effect_type:
		ArtifactEffect.EffectType.MOVE_SPEED_MULT:
			_cached_move_speed_mult *= pow(eff.value, sign)
		ArtifactEffect.EffectType.MAX_HP_MULT:
			_cached_max_hp_mult *= pow(eff.value, sign)
		ArtifactEffect.EffectType.PICKUP_RANGE_MULT:
			_cached_pickup_mult *= pow(eff.value, sign)
		ArtifactEffect.EffectType.COOLDOWN_REDUCE:
			_cached_cooldown_reduce += eff.value * sign
		ArtifactEffect.EffectType.CRIT_CHANCE:
			_cached_crit_chance += eff.value * sign
		ArtifactEffect.EffectType.XP_MULT:
			_cached_xp_mult *= pow(eff.value, sign)
		ArtifactEffect.EffectType.LIFE_STEAL:
			_cached_life_steal += eff.value * sign
		ArtifactEffect.EffectType.REGEN:
			_cached_regen += eff.value * sign
		ArtifactEffect.EffectType.DODGE_CHANCE:
			_cached_dodge_chance += eff.value * sign
		ArtifactEffect.EffectType.KNOCKBACK:
			_cached_knockback *= pow(eff.value, sign)
		ArtifactEffect.EffectType.DAMAGE_MULT:
			if sign > 0:
				_cached_damage_mult *= eff.value
			else:
				_cached_damage_mult /= eff.value
		ArtifactEffect.EffectType.PROJECTILE_SPEED:
			if sign > 0:
				_cached_projectile_speed_mult *= eff.value
			else:
				_cached_projectile_speed_mult /= eff.value
		ArtifactEffect.EffectType.AREA_MULT:
			if sign > 0:
				_cached_area_mult *= eff.value
			else:
				_cached_area_mult /= eff.value
		ArtifactEffect.EffectType.DURATION_MULT:
			if sign > 0:
				_cached_duration_mult *= eff.value
			else:
				_cached_duration_mult /= eff.value
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
		_:
			pass

# === Public API: cached player-wide effects ===

func get_xp_mult() -> float:
	return _cached_xp_mult

func get_life_steal() -> float:
	return _cached_life_steal

func get_crit_chance() -> float:
	return clampf(_cached_crit_chance, 0.0, 1.0)

func get_dodge_chance_bonus() -> float:
	return _cached_dodge_chance

func get_regen_bonus() -> float:
	return _cached_regen

func get_pickup_range_mult() -> float:
	return _cached_pickup_mult

func get_move_speed_mult() -> float:
	return _cached_move_speed_mult

func get_max_hp_mult() -> float:
	return _cached_max_hp_mult

func get_cooldown_reduce() -> float:
	var extra := 0.0
	if has_artifact("Clockwork Cog"):
		extra = floorf(float(GameManager.enemies_killed) / 100.0) * 0.05
		extra = minf(extra, 0.15)
	return clampf(_cached_cooldown_reduce + extra, 0.0, 0.75)

func get_damage_mult() -> float:
	var extra := 1.0
	if has_artifact("Scholar's Monocle"):
		extra *= (1.0 + floorf(float(GameManager.current_level) / 5.0) * 0.05)
	if has_artifact("Gambler's Dice"):
		extra *= ArtifactAbilityRunner.get_gambler_damage_mult()
	return _cached_damage_mult * extra

func get_projectile_speed_mult() -> float:
	return _cached_projectile_speed_mult

func get_area_mult() -> float:
	return _cached_area_mult

func get_duration_mult() -> float:
	return _cached_duration_mult

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

func has_artifact(artifact_name: String) -> bool:
	for a in equipped:
		if a.artifact_name == artifact_name:
			return true
	return false

# === Public API: spell-specific (type/name targeted) effects ===

func get_spell_multiplier(spell_name: StringName, spell_type: StringName, effect: ArtifactEffect.EffectType) -> float:
	var mult := 1.0
	var skip_global: bool = effect in [
		ArtifactEffect.EffectType.DAMAGE_MULT,
		ArtifactEffect.EffectType.PROJECTILE_SPEED,
		ArtifactEffect.EffectType.AREA_MULT,
		ArtifactEffect.EffectType.DURATION_MULT,
	]
	for artifact in equipped:
		var is_global: bool = _is_global_artifact(artifact)
		if skip_global and is_global:
			continue
		var matches: bool = _matches(artifact, spell_name, spell_type)
		if not matches:
			continue
		for bonus in artifact.bonuses:
			if bonus.effect_type == effect:
				mult *= bonus.value
	return mult

func get_chain_count_add(spell_name: StringName, spell_type: StringName) -> int:
	var add := 0
	for artifact in equipped:
		var matches: bool = _matches(artifact, spell_name, spell_type)
		if not matches:
			continue
		for bonus in artifact.bonuses:
			if bonus.effect_type == ArtifactEffect.EffectType.CHAIN_COUNT:
				add += int(bonus.value)
	return add

func get_extra_projectile_count(spell_name: StringName, spell_type: StringName) -> int:
	var add := 0
	for artifact in equipped:
		var matches: bool = _matches(artifact, spell_name, spell_type)
		if not matches:
			continue
		for bonus in artifact.bonuses:
			if bonus.effect_type == ArtifactEffect.EffectType.EXTRA_PROJECTILE:
				add += int(bonus.value)
	return add
