class_name LevelUpManager extends Node2D

var _owned_spells: Dictionary = {}
var _player: Player = null
var _all_spell_factories: Dictionary = {}
var _passive_levels: Dictionary = {}
var _class_data: Dictionary = {}
var _pending_level_ups: int = 0

func _ready() -> void:
	add_to_group("level_up_manager")
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.game_started.connect(_on_game_started)
	_find_player()
	_register_spell_factories()

func _on_game_started() -> void:
	_owned_spells.clear()
	_passive_levels.clear()
	_pending_level_ups = 0
	_class_data = GameManager.selected_class
	_find_player()
	_remove_all_casters()
	call_deferred("_give_starting_spell")

func _find_player() -> void:
	var p := GameManager.get_player()
	if p and p is Player:
		_player = p

func _register_spell_factories() -> void:
	_all_spell_factories[&"magic_bolt"] = _create_magic_bolt
	_all_spell_factories[&"fireball"] = _create_fireball
	_all_spell_factories[&"orbiting_arcana"] = _create_orbiting_arcana
	_all_spell_factories[&"lightning_strike"] = _create_lightning_strike
	_all_spell_factories[&"cyclone"] = _create_cyclone
	_all_spell_factories[&"arcane_ray"] = _create_arcane_ray
	_all_spell_factories[&"electric_zone"] = _create_electric_zone
	_all_spell_factories[&"spirit"] = _create_spirit
	_all_spell_factories[&"shield"] = _create_shield
	_all_spell_factories[&"fire_breath"] = _create_fire_breath
	_all_spell_factories[&"needle"] = _create_needle
	_all_spell_factories[&"poison_pool"] = _create_poison_pool
	_all_spell_factories[&"frost_nova"] = _create_frost_nova

func _give_starting_spell() -> void:
	var spell_id: StringName = &"magic_bolt"
	if not _class_data.is_empty():
		spell_id = _class_data.get("spell_id", &"magic_bolt")
	
	var factory: Callable = _all_spell_factories.get(spell_id)
	if not factory:
		factory = _create_magic_bolt
	
	var spell: Spell = factory.call()
	_apply_class_bonuses(spell)
	add_owned_spell(spell)
	_add_spell_caster_to_player(spell)
	
	# Guardian special: extra Magic Bolt
	for bonus in _class_data.get("bonuses", []):
		if bonus.get("type") == "spell":
			var extra_id: StringName = bonus.value
			var extra_factory: Callable = _all_spell_factories.get(extra_id)
			if extra_factory:
				var extra_spell: Spell = extra_factory.call()
				add_owned_spell(extra_spell)
				_add_spell_caster_to_player(extra_spell)

func _apply_class_bonuses(spell: Spell) -> void:
	for bonus in _class_data.get("bonuses", []):
		var btype: String = bonus.get("type", "")
		if btype == "spell":
			continue
		var stat: String = bonus.get("stat", "")
		var value: float = bonus.get("value", 0.0)
		match stat:
			"projectile_count":
				spell.projectile_count += int(value)
			"cooldown_reduction":
				spell.base_cooldown *= (1.0 - value)
			"damage":
				spell.base_damage *= (1.0 + value)
			"area":
				pass
			"duration":
				pass
			"width":
				pass
			"shield_hp":
				spell.base_damage *= (1.0 + value)

func add_owned_spell(spell: Spell) -> void:
	_owned_spells[spell.spell_id] = spell

func remove_spell(spell_id: StringName) -> void:
	_owned_spells.erase(spell_id)

func _on_player_level_up(_new_level: int) -> void:
	_pending_level_ups += 1
	_try_show_level_up()

func _try_show_level_up() -> void:
	if _pending_level_ups <= 0:
		return
	var st := GameManager.current_state
	if st != GameManager.GameState.PLAYING and st != GameManager.GameState.BOSS_FIGHT:
		return
	if not _player:
		_find_player()
	var cards := generate_cards(3)
	if cards.is_empty():
		return
	_pending_level_ups -= 1
	GameManager.enter_level_up()
	_show_level_up_ui(cards)

func generate_cards(count: int) -> Array[LevelUpCard]:
	var pool: Array[LevelUpCard] = []

	for spell_id: StringName in _owned_spells:
		var owned_spell: Spell = _owned_spells[spell_id]
		if not owned_spell or not is_instance_valid(owned_spell):
			continue
		if not owned_spell.is_max_level():
			var card := LevelUpCard.new()
			card.card_type = LevelUpCard.CardType.SPELL_UPGRADE
			var spell_name_tr := SettingsManager.t(&"spell_" + String(spell_id))
			card.title = spell_name_tr
			var next_lvl := owned_spell.current_level - 1
			if owned_spell.level_data.size() > next_lvl and next_lvl >= 0:
				card.description = SettingsManager.t(_get_lvl_desc_key(spell_id, owned_spell.current_level + 1))
			else:
				card.description = SettingsManager.t(&"upgrade_spell") % spell_name_tr
			card.icon = owned_spell.icon
			card.spell_id = owned_spell.spell_id
			card.new_level = owned_spell.current_level + 1
			if owned_spell.current_level >= 4:
				card.rarity = LevelUpCard.Rarity.EPIC
				card.rarity_color = Color(1.0, 0.4, 0.9)
			elif owned_spell.current_level >= 2:
				card.rarity = LevelUpCard.Rarity.RARE
				card.rarity_color = Color(0.3, 0.7, 1.0)
			else:
				card.rarity = LevelUpCard.Rarity.COMMON
				card.rarity_color = Color(0.4, 0.85, 0.4)
			pool.append(card)

	for spell_id: StringName in _all_spell_factories:
		if not _owned_spells.has(spell_id):
			var factory: Callable = _all_spell_factories[spell_id]
			if not factory.is_valid():
				continue
			var spell: Variant = factory.call()
			if spell == null or not spell is Spell:
				continue
			var spell_name_tr := SettingsManager.t(&"spell_" + String(spell_id))
			var card := LevelUpCard.new()
			card.card_type = LevelUpCard.CardType.NEW_SPELL
			card.title = spell_name_tr
			card.description = SettingsManager.t(&"new_spell")
			if spell.level_data.size() > 0:
				card.description = SettingsManager.t(_get_lvl_desc_key(spell_id, 1))
			card.spell = spell
			card.icon = spell.icon
			card.rarity = LevelUpCard.Rarity.RARE
			card.rarity_color = Color(0.3, 0.6, 1.0)
			pool.append(card)

	var stat_defs: Array[Dictionary] = [
		{"key": &"max_hp", "value": 1.2, "tr": &"boost_max_hp", "desc_tr": &"boost_desc_max_hp", "color": Color.RED},
		{"key": &"move_speed", "value": 1.1, "tr": &"boost_move_speed", "desc_tr": &"boost_desc_move_speed", "color": Color.CYAN},
		{"key": &"magic_power", "value": 0.15, "tr": &"boost_magic_power", "desc_tr": &"boost_desc_magic_power", "color": Color.MAGENTA},
		{"key": &"cooldown_reduction", "value": 0.03, "tr": &"boost_cd_reduction", "desc_tr": &"boost_desc_cd_reduction", "color": Color.YELLOW},
		{"key": &"hp_regen", "value": 0.1, "tr": &"boost_hp_regen", "desc_tr": &"boost_desc_hp_regen", "color": Color.GREEN},
		{"key": &"pickup_range", "value": 1.25, "tr": &"boost_pickup_range", "desc_tr": &"boost_desc_pickup_range", "color": Color.CORNFLOWER_BLUE},
		{"key": &"spell_duration", "value": 1.05, "tr": &"boost_spell_duration", "desc_tr": &"boost_desc_spell_duration", "color": Color(0.8, 0.6, 1.0)},
		{"key": &"crit_chance", "value": 0.03, "tr": &"boost_crit_chance", "desc_tr": &"boost_desc_crit_chance", "color": Color(1.0, 0.6, 0.2)},
		{"key": &"crit_damage_mult", "value": 0.10, "tr": &"boost_crit_damage", "desc_tr": &"boost_desc_crit_damage_mult", "color": Color(1.0, 0.3, 0.3)},
		{"key": &"area_multiplier", "value": 1.05, "tr": &"boost_area_multiplier", "desc_tr": &"boost_desc_area_multiplier", "color": Color(0.5, 0.8, 1.0)},
		{"key": &"mana_gain", "value": 1.08, "tr": &"boost_mana_gain", "desc_tr": &"boost_desc_mana_gain", "color": Color(0.4, 0.6, 1.0)},
	]
	for def in stat_defs:
		var key: StringName = def["key"]
		var lvl: int = _passive_levels.get(key, 0)
		if lvl < 5:
			pool.append(_make_stat_card(key, def["value"], SettingsManager.t(def["tr"]), SettingsManager.t(def["desc_tr"]), def["color"], lvl))

	var fusion_recipes := SpellFusionManager.get_all_eligible_fusions(_owned_spells)
	for recipe in fusion_recipes:
		var card := LevelUpCard.new()
		card.card_type = LevelUpCard.CardType.SPELL_FUSION
		var tr_name: String = recipe.get("tr_name_en", "")
		if SettingsManager.get_language() == "ru":
			tr_name = recipe.get("tr_name_ru", tr_name)
		card.title = tr_name
		card.description = recipe["desc"]
		card.fusion_main_id = recipe["main_id"]
		card.fusion_secondary_id = recipe["secondary_id"]
		card.fusion_main_mod_id = recipe["main_mod_id"]
		card.fusion_secondary_mod_id = recipe["secondary_mod_id"]
		card.fusion_name = tr_name
		card.rarity = LevelUpCard.Rarity.EPIC
		card.rarity_color = Color(1.0, 0.6, 0.2)
		pool.append(card)

	pool.shuffle()

	if pool.size() < count:
		var fallback_stats: Array[Dictionary] = [
			{"key": &"max_hp", "value": 1.2, "tr": &"boost_max_hp", "desc_tr": &"boost_desc_max_hp", "color": Color.RED},
			{"key": &"move_speed", "value": 1.1, "tr": &"boost_move_speed", "desc_tr": &"boost_desc_move_speed", "color": Color.CYAN},
			{"key": &"magic_power", "value": 0.15, "tr": &"boost_magic_power", "desc_tr": &"boost_desc_magic_power", "color": Color.MAGENTA},
			{"key": &"hp_regen", "value": 0.1, "tr": &"boost_hp_regen", "desc_tr": &"boost_desc_hp_regen", "color": Color.GREEN},
			{"key": &"crit_chance", "value": 0.03, "tr": &"boost_crit_chance", "desc_tr": &"boost_desc_crit_chance", "color": Color(1.0, 0.6, 0.2)},
		]
		while pool.size() < count:
			var fb: Dictionary = fallback_stats[pool.size() % fallback_stats.size()]
			var lvl: int = _passive_levels.get(fb["key"], 0)
			pool.append(_make_stat_card(fb["key"], fb["value"], SettingsManager.t(fb["tr"]), SettingsManager.t(fb["desc_tr"]), fb["color"], lvl))

	var result: Array[LevelUpCard] = []
	for i in range(mini(count, pool.size())):
		result.append(pool[i])
	return result

func _make_stat_card(stat: StringName, value: float, title: String, desc: String, color: Color, level: int = 0) -> LevelUpCard:
	var card := LevelUpCard.new()
	card.card_type = LevelUpCard.CardType.STAT_BOOST
	card.title = title
	card.description = desc
	card.stat_name = stat
	card.stat_value = value
	card.stat_level = level
	card.stat_max_level = 5
	card.rarity_color = color
	card.rarity = LevelUpCard.Rarity.COMMON
	var stat_icons: Dictionary = {
		&"max_hp": preload("res://Sprites/Health_icon_pix.png"),
		&"move_speed": preload("res://Sprites/Movement_Speed_icon_pix.png"),
		&"magic_power": preload("res://Sprites/Magic_Power_icon_pix.png"),
		&"cooldown_reduction": preload("res://Sprites/Cooldown_Reduction_icon_pix.png"),
		&"hp_regen": preload("res://Sprites/HP_Regeneration_icon_pix.png"),
		&"pickup_range": preload("res://Sprites/Pickup_Radius_icon_pix.png"),
		&"spell_duration": preload("res://Sprites/Spell_Duration_icon_pix.png"),
		&"crit_chance": preload("res://Sprites/Crit_Chance_icon_pix.png"),
		&"crit_damage_mult": preload("res://Sprites/Crit_Damage_icon_pix.png"),
		&"area_multiplier": preload("res://Sprites/Spell_Size_icon_pix.png"),
		&"mana_gain": preload("res://Sprites/XP_icon_pix.png"),
	}
	card.icon = stat_icons.get(stat)
	return card

func _show_level_up_ui(cards: Array[LevelUpCard]) -> void:
	var ui := get_tree().get_first_node_in_group("level_up_ui")
	if ui and ui.has_method("show_cards"):
		ui.show_cards(cards)

func _show_modification_screen(spell: Spell) -> void:
	var ui := get_tree().get_first_node_in_group("modification_ui")
	if ui and ui.has_method("show_modifications"):
		ui.show_modifications(spell)

func notify_modification_applied(spell: Spell) -> void:
	_notify_caster_upgrade(spell)

func apply_card(card: LevelUpCard) -> void:
	match card.card_type:
		LevelUpCard.CardType.NEW_SPELL:
			if card.spell and _player:
				add_owned_spell(card.spell)
				_add_spell_caster_to_player(card.spell)
				EventBus.spell_upgraded.emit(card.spell.spell_id, 1)
		LevelUpCard.CardType.SPELL_UPGRADE:
			if _owned_spells.has(card.spell_id):
				var spell: Spell = _owned_spells[card.spell_id]
				spell.level_up()
				EventBus.spell_upgraded.emit(card.spell_id, card.new_level)
				_notify_caster_upgrade(spell)
				if spell.is_max_level() and spell.modifications.size() > 0 and not spell.active_modification:
					_show_modification_screen(spell)
					return
		LevelUpCard.CardType.SPELL_MODIFICATION:
			if _owned_spells.has(card.spell_id):
				var spell: Spell = _owned_spells[card.spell_id]
				spell.apply_modification(card.modification)
				EventBus.spell_upgraded.emit(card.spell_id, spell.current_level)
				_notify_caster_upgrade(spell)
		LevelUpCard.CardType.STAT_BOOST:
			if _player and _player.stats:
				_apply_stat_boost(card.stat_name, card.stat_value)
				_passive_levels[card.stat_name] = _passive_levels.get(card.stat_name, 0) + 1

		LevelUpCard.CardType.SPELL_FUSION:
			if card.fusion_main_mod_id != &"" and card.fusion_secondary_mod_id != &"":
				_fuse_spells(card.fusion_main_id, card.fusion_secondary_id, card.fusion_main_mod_id, card.fusion_secondary_mod_id)

	GameManager.exit_level_up()
	_try_show_level_up()

func apply_mana_return() -> void:
	GameManager.exit_level_up()
	_try_show_level_up()

func _notify_caster_upgrade(spell: Spell) -> void:
	if not _player:
		return
	var spells_node: Node = _player.get_node_or_null("Spells")
	if not spells_node:
		return
	for child in spells_node.get_children():
		if child is SpellCaster and child.spell == spell:
			child.notify_spell_upgraded()
			break



func _add_spell_caster_to_player(spell: Spell) -> void:
	if not _player:
		_find_player()
	if not _player:
		return
	var spells_node: Node = _player.get_node_or_null("Spells")
	if not spells_node:
		return

	var caster := SpellCaster.new()
	caster.spell = spell
	caster.name = String(spell.spell_id) + "Caster"
	spells_node.add_child(caster)

func _remove_spell_caster(spell_id: StringName) -> void:
	if not _player:
		return
	var spells_node: Node = _player.get_node_or_null("Spells")
	if not spells_node:
		return
	for child in spells_node.get_children():
		if child is SpellCaster and child.spell and child.spell.spell_id == spell_id:
			if child.spell and child.spell.behavior:
				child.spell.behavior.on_spell_removed(child, child.spell)
			child.queue_free()
			break

func _fuse_spells(main_id: StringName, secondary_id: StringName, main_mod_id: StringName, secondary_mod_id: StringName) -> void:
	# Find the spell with the matching mod_id
	var main_spell: Spell = _find_spell_by_mod_id(main_id, main_mod_id)
	var secondary_spell: Spell = _find_spell_by_mod_id(secondary_id, secondary_mod_id)
	if not main_spell or not secondary_spell:
		return

	var fusion_spell := SpellFusionManager.get_fusion_spell(main_mod_id, secondary_mod_id)
	if not fusion_spell:
		return

	# Remove secondary spell
	_owned_spells.erase(secondary_spell.spell_id)
	_remove_spell_caster(secondary_spell.spell_id)

	# Replace main spell with fusion
	_owned_spells[main_spell.spell_id] = fusion_spell
	_remove_spell_caster(main_spell.spell_id)
	_add_spell_caster_to_player(fusion_spell)

	EventBus.spell_fused.emit(main_spell.spell_id, secondary_spell.spell_id, fusion_spell.fusion_id)
	EventBus.spell_upgraded.emit(fusion_spell.fusion_id, 1)

func _find_spell_by_mod_id(spell_id: StringName, mod_id: StringName) -> Spell:
	var spell: Spell = _owned_spells.get(spell_id) as Spell
	if not spell:
		return null
	if spell.active_modification and spell.active_modification.mod_id == mod_id:
		return spell
	return null

func _remove_all_casters() -> void:
	if not _player:
		return
	var spells_node: Node = _player.get_node_or_null("Spells")
	if not spells_node:
		return
	for child in spells_node.get_children():
		if child is SpellCaster:
			if child.spell and child.spell.behavior:
				child.spell.behavior.on_spell_removed(child, child.spell)
			child.queue_free()

func _apply_stat_boost(stat: StringName, value: float) -> void:
	if not _player or not _player.stats:
		return
	match stat:
		&"max_hp":
			var old_hp: float = _player.stats.max_hp
			_player.stats.max_hp *= value
			var healed: float = _player.stats.max_hp - old_hp
			_player.stats.current_hp += healed
			EventBus.player_healed.emit(healed)
		&"move_speed":
			_player.stats.move_speed *= value
		&"magic_power":
			_player.stats.magic_power += value
		&"cooldown_reduction":
			_player.stats.cooldown_reduction += value
		&"hp_regen":
			_player.stats.hp_regen += value
		&"pickup_range":
			_player.stats.pickup_range *= value
			_player.update_pickup_detector()
		&"spell_duration":
			_player.stats.spell_duration_mult *= value
		&"crit_chance":
			_player.stats.crit_chance += value
		&"crit_damage_mult":
			_player.stats.crit_damage_mult += value
		&"area_multiplier":
			_player.stats.area_multiplier *= value
		&"mana_gain":
			_player.stats.mana_gain *= value

func _create_magic_bolt() -> Spell:
	var bolt := SpellData.new()
	bolt.spell_name = "Magic Bolt"
	bolt.spell_id = &"magic_bolt"
	bolt.max_level = 5
	bolt.cast_pattern = Spell.CastPattern.SINGLE
	bolt.base_damage = 15.0
	bolt.base_cooldown = 0.8
	bolt.projectile_speed = 450.0
	bolt.pierce = 1
	bolt.projectile_count = 1
	bolt.projectile_scene = preload("res://magic_bolt.tscn")
	bolt.pool_name = &"MagicBolt"
	bolt.pool_initial_size = 100
	bolt.color = Color(0.4, 0.7, 1.0)
	bolt.icon = preload("res://Sprites/magic_bolt_icon_pix.png")
	bolt.vfx_color_primary = Color(0.7, 0.8, 1.0)
	bolt.vfx_color_secondary = Color(0.4, 0.5, 0.9)

	var behavior := ProjectileBehavior.new()
	behavior.pattern = ProjectileBehavior.Pattern.SINGLE
	bolt.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.cooldown_multiplier = 0.9
	lvl2.description = "Damage +25%, cooldown -10%"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, fires an additional bolt"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.pierce_add = 1
	lvl4.description = "Damage +80%, pierces through 1 more enemy"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.cooldown_multiplier = 0.8
	lvl5.description = "Damage +120%, cooldown -20%"

	bolt.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_storm := SpellModification.new()
	mod_storm.mod_name = "Magic Missile Storm"
	mod_storm.mod_id = &"magic_bolt_storm"
	mod_storm.mod_type = SpellModification.ModType.SPEED_BOOST
	mod_storm.description = "Fires 2 bolts per cast, each dealing 30% less damage"
	mod_storm.projectile_count_add = 1
	mod_storm.damage_multiplier = 0.7

	var mod_homing := SpellModification.new()
	mod_homing.mod_name = "Homing"
	mod_homing.mod_id = &"magic_bolt_homing"
	mod_homing.mod_type = SpellModification.ModType.HOMING
	mod_homing.description = "Bolts track the nearest enemy with perfect accuracy"
	mod_homing.homing_strength = 4.5
	mod_homing.damage_multiplier = 1.0

	var mod_chain := SpellModification.new()
	mod_chain.mod_name = "Chain Lightning"
	mod_chain.mod_id = &"magic_bolt_chain"
	mod_chain.mod_type = SpellModification.ModType.CHAIN
	mod_chain.description = "Bolts chain to 1 nearby enemy for 50% damage"
	mod_chain.chain_range = 150.0
	mod_chain.chain_damage_mult = 0.5
	mod_chain.damage_multiplier = 1.0

	bolt.modifications = [mod_storm, mod_homing, mod_chain]
	return bolt

func _create_fireball() -> Spell:
	var fb := SpellData.new()
	fb.spell_name = "Fireball"
	fb.spell_id = &"fireball"
	fb.max_level = 5
	fb.cast_pattern = Spell.CastPattern.SINGLE
	fb.base_damage = 25.0
	fb.base_cooldown = 1.5
	fb.projectile_speed = 250.0
	fb.pierce = 1
	fb.projectile_count = 1
	fb.explosion_radius = 50.0
	fb.projectile_scene = preload("res://fireball.tscn")
	fb.pool_name = &"Fireball"
	fb.pool_initial_size = 30
	fb.color = Color(1.5, 0.7, 0.2)
	fb.icon = preload("res://Sprites/fireball_icon_pix.png")
	fb.vfx_color_primary = Color(1.0, 0.5, 0.1)
	fb.vfx_color_secondary = Color(0.8, 0.2, 0.05)

	var behavior := ProjectileBehavior.new()
	behavior.pattern = ProjectileBehavior.Pattern.SINGLE
	fb.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.25
	lvl2.description = "Damage +25%, explosion radius +25%"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, fires an additional fireball"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.5
	lvl4.description = "Damage +80%, explosion radius +50%"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.area_multiplier = 2.0
	lvl5.description = "Damage +120%, explosion radius +100%"

	fb.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_split := SpellModification.new()
	mod_split.mod_name = "Split Fireball"
	mod_split.mod_id = &"fireball_split"
	mod_split.mod_type = SpellModification.ModType.SPLIT
	mod_split.description = "Explodes into 4 smaller fireballs on impact"
	mod_split.split_count = 4
	mod_split.split_angle_spread = 1.2
	mod_split.damage_multiplier = 0.7

	var mod_meteor := SpellModification.new()
	mod_meteor.mod_name = "Skyfall"
	mod_meteor.mod_id = &"fireball_meteor"
	mod_meteor.mod_type = SpellModification.ModType.EXPLODE
	mod_meteor.description = "Calls down a massive meteor from the sky, devastating AoE"
	mod_meteor.explosion_radius_mult = 4.0
	mod_meteor.speed_multiplier = 1.0
	mod_meteor.damage_multiplier = 2.0
	mod_meteor.cooldown_multiplier = 2.8
	mod_meteor.color_tint = Color(1.0, 0.4, 0.05)

	var mod_pierce := SpellModification.new()
	mod_pierce.mod_name = "Piercing Blaze"
	mod_pierce.mod_id = &"fireball_pierce"
	mod_pierce.mod_type = SpellModification.ModType.PIERCE_BOOST
	mod_pierce.description = "Pierces through 4 enemies before exploding"
	mod_pierce.pierce_add = 4
	mod_pierce.damage_multiplier = 1.0

	fb.modifications = [mod_split, mod_meteor, mod_pierce]
	return fb

func _create_orbiting_arcana() -> Spell:
	var oa := SpellData.new()
	oa.spell_name = "Orbiting Arcana"
	oa.spell_id = &"orbiting_arcana"
	oa.max_level = 5
	oa.cast_pattern = Spell.CastPattern.ORBIT
	oa.base_damage = 15.0
	oa.base_cooldown = 2.0
	oa.projectile_count = 3
	oa.projectile_scene = preload("res://orbit_arcane.tscn")
	oa.pool_name = &"OrbitArcane"
	oa.pool_initial_size = 10
	oa.icon = preload("res://Sprites/orbiting_arcana_icon_pix.png")
	oa.vfx_color_primary = Color(0.7, 0.8, 1.0)
	oa.vfx_color_secondary = Color(0.4, 0.5, 0.9)

	var behavior := OrbitBehavior.new()
	oa.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.projectile_count_add = 1
	lvl2.description = "Damage +25%, +1 orbiting blade"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 orbiting blade"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.projectile_count_add = 1
	lvl4.description = "Damage +80%, +1 orbiting blade"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 2
	lvl5.description = "Damage +120%, +2 orbiting blades"

	oa.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_wide := SpellModification.new()
	mod_wide.mod_name = "Pulsating Vortex"
	mod_wide.mod_id = &"orbiting_arcana_vortex"
	mod_wide.description = "Orbit radius pulses from -40% to +80% over 2 seconds"
	mod_wide.orbit_radius_mult = 1.8
	mod_wide.damage_multiplier = 0.85
	mod_wide.color_tint = Color(0.2, 0.6, 1.0)

	var mod_fast := SpellModification.new()
	mod_fast.mod_name = "Blade Strike"
	mod_fast.mod_id = &"orbiting_arcana_blade"
	mod_fast.description = "Every 3s a blade flies to the nearest enemy for 200% damage, then returns"
	mod_fast.orbit_speed_mult = 1.5
	mod_fast.damage_multiplier = 0.9
	mod_fast.color_tint = Color(1.0, 0.8, 0.3)

	var mod_more := SpellModification.new()
	mod_more.mod_name = "Cross Storm"
	mod_more.mod_id = &"orbiting_arcana_cross"
	mod_more.description = "4 additional counter-rotating blades, each dealing 25% less damage"
	mod_more.projectile_count_add = 4
	mod_more.damage_multiplier = 0.75
	mod_more.color_tint = Color(0.8, 0.3, 1.0)

	oa.modifications = [mod_wide, mod_fast, mod_more]
	return oa

func _create_lightning_strike() -> Spell:
	var ls := SpellData.new()
	ls.spell_name = "Lightning Strike"
	ls.spell_id = &"lightning_strike"
	ls.max_level = 5
	ls.cast_pattern = Spell.CastPattern.AOE
	ls.base_damage = 25.0
	ls.base_cooldown = 3.0
	ls.color = Color(0.5, 0.8, 1.0)
	ls.icon = preload("res://Sprites/lightning_strike_icon_pix.png")
	ls.vfx_color_primary = Color(0.6, 0.8, 1.0)
	ls.vfx_color_secondary = Color(0.3, 0.5, 1.0)

	var behavior := LightningBehavior.new()
	behavior.strike_range = 550.0
	behavior.chain_count = 0
	behavior.chain_range = 120.0
	behavior.chain_damage_mult = 0.5
	ls.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.chain_count_add = 0
	lvl2.description = "Damage +25%"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 lightning strike"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.chain_count_add = 0
	lvl4.description = "Damage +80%"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 1
	lvl5.description = "Damage +120%, +1 lightning strike"

	ls.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_chain := SpellModification.new()
	mod_chain.mod_name = "Chain Amplifier"
	mod_chain.mod_id = &"lightning_strike_chain"
	mod_chain.mod_type = SpellModification.ModType.CHAIN
	mod_chain.description = "+8 chain targets, 250 range, -25% damage"
	mod_chain.chain_count_add = 8
	mod_chain.chain_range = 250.0
	mod_chain.chain_damage_mult = 0.6
	mod_chain.damage_multiplier = 0.75

	var mod_overcharge := SpellModification.new()
	mod_overcharge.mod_name = "Overcharge"
	mod_overcharge.mod_id = &"lightning_strike_overcharge"
	mod_overcharge.description = "3x damage, 3x size, no chains"
	mod_overcharge.damage_multiplier = 3.0
	mod_overcharge.color_tint = Color(1.0, 1.0, 0.5)

	var mod_rapid := SpellModification.new()
	mod_rapid.mod_name = "Rapid Bolt"
	mod_rapid.mod_id = &"lightning_strike_rapid"
	mod_rapid.description = "50% less cooldown, -20% damage per strike"
	mod_rapid.cooldown_multiplier = 0.5
	mod_rapid.damage_multiplier = 0.8
	mod_rapid.color_tint = Color(0.5, 0.8, 1.0)

	ls.modifications = [mod_chain, mod_overcharge, mod_rapid]
	return ls

func _create_cyclone() -> Spell:
	var cy := SpellData.new()
	cy.spell_name = "Cyclone"
	cy.spell_id = &"cyclone"
	cy.max_level = 5
	cy.cast_pattern = Spell.CastPattern.AOE
	cy.base_damage = 8.0
	cy.base_cooldown = 6.0
	cy.color = Color(0.3, 0.8, 0.95)
	cy.icon = preload("res://Sprites/whirlwind_icon_pix.png")
	cy.vfx_color_primary = Color(0.6, 0.9, 1.0)
	cy.vfx_color_secondary = Color(0.3, 0.6, 0.9)

	var behavior := CycloneBehavior.new()
	behavior.fly_speed = 120.0
	behavior.start_radius = 15.0
	behavior.max_radius = 80.0
	behavior.grow_time = 1.0
	behavior.fade_time = 0.5
	behavior.damage_interval = 0.3
	behavior.rotation_speed = 3.0
	behavior.aim_range = 600.0
	cy.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.3
	lvl2.description = "Damage +25%, +30% area and duration"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 vortex"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.5
	lvl4.description = "Damage +80%, +50% area and duration"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 2
	lvl5.description = "Damage +120%, +2 vortexes"

	cy.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_gravity := SpellModification.new()
	mod_gravity.mod_name = "Gravity Well"
	mod_gravity.mod_id = &"cyclone_gravity"
	mod_gravity.description = "No damage, 5x pull strength, sucks enemies in"
	mod_gravity.zone_radius_mult = 2.0
	mod_gravity.orbit_speed_mult = 0.8
	mod_gravity.damage_multiplier = 0.0
	mod_gravity.color_tint = Color(0.5, 0.2, 0.9)

	var mod_gale := SpellModification.new()
	mod_gale.mod_name = "Seeking Wind"
	mod_gale.mod_id = &"cyclone_gale"
	mod_gale.description = "Vortex chases enemies, +40% move speed, -15% damage"
	mod_gale.orbit_speed_mult = 1.5
	mod_gale.speed_multiplier = 1.4
	mod_gale.damage_interval_mult = 0.6
	mod_gale.damage_multiplier = 0.85
	mod_gale.color_tint = Color(1.0, 0.4, 0.2)

	var mod_twin := SpellModification.new()
	mod_twin.mod_name = "Twin Cyclone"
	mod_twin.mod_id = &"cyclone_twin"
	mod_twin.description = "Paired vortexes rotating around a shared axis, 2.5x area, 1.5x damage"
	mod_twin.damage_multiplier = 1.7
	mod_twin.zone_radius_mult = 2.5
	mod_twin.color_tint = Color(0.6, 0.2, 1.0)

	cy.modifications = [mod_gravity, mod_gale, mod_twin]
	return cy

func _create_arcane_ray() -> Spell:
	var ar := SpellData.new()
	ar.spell_name = "Arcane Ray"
	ar.spell_id = &"arcane_ray"
	ar.max_level = 5
	ar.cast_pattern = Spell.CastPattern.SINGLE
	ar.base_damage = 40.0
	ar.base_cooldown = 5.0
	ar.projectile_count = 1
	ar.color = Color(1.0, 0.3, 0.2)
	ar.icon = load("res://Sprites/arcane_ray_pix.png")
	ar.vfx_color_primary = Color(1.0, 0.4, 0.25)
	ar.vfx_color_secondary = Color(0.8, 0.15, 0.08)
	ar.vfx_impact_key = "arcane_impact"

	var behavior := RayBehavior.new()
	behavior.half_width = 3.5
	behavior.sustain_time = 0.4
	behavior.damage_interval = 0.1
	ar.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.25
	lvl2.description = "Damage +25%, +25% beam width"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 ray"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.5
	lvl4.description = "Damage +80%, +50% beam width"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 2
	lvl5.description = "Damage +120%, +2 rays"

	ar.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_prism := SpellModification.new()
	mod_prism.mod_name = "Spinning Prism"
	mod_prism.mod_id = &"arcane_ray_prism"
	mod_prism.description = "5 rays in a 90 degree fan, whole structure rotates, -40% damage each"
	mod_prism.projectile_count_add = 3
	mod_prism.damage_multiplier = 0.6
	mod_prism.color_tint = Color(0.9, 0.5, 1.0)

	var mod_photon := SpellModification.new()
	mod_photon.mod_name = "Photon"
	mod_photon.mod_id = &"arcane_ray_photon"
	mod_photon.description = "2.5x damage, fires as a pulse every 1.5s"
	mod_photon.damage_multiplier = 2.5
	mod_photon.cooldown_multiplier = 0.3
	mod_photon.color_tint = Color(1.0, 0.85, 0.3)

	var mod_refraction := SpellModification.new()
	mod_refraction.mod_name = "Refraction"
	mod_refraction.mod_id = &"arcane_ray_refraction"
	mod_refraction.description = "Ray reflects off screen edges up to 2 times, -15% damage"
	mod_refraction.damage_multiplier = 0.85
	mod_refraction.color_tint = Color(1.0, 0.4, 0.7)

	ar.modifications = [mod_prism, mod_photon, mod_refraction]
	return ar

func _create_electric_zone() -> Spell:
	var ez := SpellData.new()
	ez.spell_name = "Electric Zone"
	ez.spell_id = &"electric_zone"
	ez.max_level = 5
	ez.cast_pattern = Spell.CastPattern.AOE
	ez.base_damage = 15.0
	ez.base_cooldown = 0.6
	ez.color = Color(0.6, 0.8, 1.0)
	ez.icon = load("res://Sprites/electric_zone_pix.png")
	ez.vfx_color_primary = Color(0.6, 0.8, 1.0)
	ez.vfx_color_secondary = Color(0.3, 0.5, 1.0)
	ez.vfx_impact_key = "electric_spark"

	var behavior := ElectricZoneBehavior.new()
	behavior.zone_radius = 90.0
	behavior.damage_interval = 0.6
	behavior.arc_count = 3
	ez.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.15
	lvl2.description = "Damage +25%, +15% area"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.area_multiplier = 1.3
	lvl3.description = "Damage +50%, +30% area, +1 electric arc"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.5
	lvl4.description = "Damage +80%, +50% area"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.area_multiplier = 1.75
	lvl5.description = "Damage +120%, +75% area, +2 electric arcs"

	ez.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_shockwave := SpellModification.new()
	mod_shockwave.mod_name = "Shockwave"
	mod_shockwave.mod_id = &"electric_zone_shockwave"
	mod_shockwave.description = "Every 3s the zone emits an expanding ring, 40% damage, pushes enemies back"
	mod_shockwave.zone_radius_mult = 1.3
	mod_shockwave.damage_multiplier = 0.7
	mod_shockwave.color_tint = Color(0.15, 0.25, 0.7)

	var mod_arc := SpellModification.new()
	mod_arc.mod_name = "Arc Flash"
	mod_arc.mod_id = &"electric_zone_arc"
	mod_arc.description = "3x tick speed, -50% damage per tick"
	mod_arc.damage_interval_mult = 0.333
	mod_arc.damage_multiplier = 0.5
	mod_arc.color_tint = Color(0.9, 0.9, 1.0)

	var mod_chain := SpellModification.new()
	mod_chain.mod_name = "Chain Lightning"
	mod_chain.mod_id = &"electric_zone_chain"
	mod_chain.description = "Each arc chains to +3 enemies outside the zone"
	mod_chain.chain_count_add = 3
	mod_chain.damage_multiplier = 1.0
	mod_chain.color_tint = Color(0.5, 0.3, 1.0)

	ez.modifications = [mod_shockwave, mod_arc, mod_chain]
	return ez

func _create_spirit() -> Spell:
	var sp := SpellData.new()
	sp.spell_name = "Spirit"
	sp.spell_id = &"spirit"
	sp.max_level = 5
	sp.cast_pattern = Spell.CastPattern.ORBIT
	sp.base_damage = 15.0
	sp.base_cooldown = 1.5
	sp.projectile_count = 1
	sp.color = Color(0.85, 0.75, 1.0)
	sp.icon = load("res://Sprites/spirit_icon_pix.png")
	sp.vfx_color_primary = Color(0.85, 0.75, 1.0)
	sp.vfx_color_secondary = Color(0.5, 0.35, 0.8)

	var behavior := SpiritBehavior.new()
	behavior.base_orb_count = 1
	behavior.chain_delay = 0.2
	behavior.chain_cooldown = 1.5
	behavior.bolt_speed = 600.0
	behavior.y_offset = -60.0
	behavior.spacing = 40.0
	behavior.row_gap = 32.0
	behavior.detect_range = 550.0
	sp.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.speed_multiplier = 1.2
	lvl2.projectile_count_add = 1
	lvl2.description = "Damage +25%, +20% bolt speed, +1 spirit"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 spirit"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.cooldown_multiplier = 0.7
	lvl4.projectile_count_add = 1
	lvl4.description = "Damage +80%, +30% attack speed, +1 spirit"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 1
	lvl5.description = "Damage +120%, +1 spirit"

	sp.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_phantom := SpellModification.new()
	mod_phantom.mod_name = "Phantom Legion"
	mod_phantom.mod_id = &"spirit_phantom"
	mod_phantom.description = "+3 spirits, each targets a different enemy, -30% damage each"
	mod_phantom.projectile_count_add = 3
	mod_phantom.damage_multiplier = 0.7
	mod_phantom.color_tint = Color(0.6, 0.9, 0.7)

	var mod_blades := SpellModification.new()
	mod_blades.mod_name = "Phantom Blades"
	mod_blades.mod_id = &"spirit_blades"
	mod_blades.description = "Spirits deal instant damage instead of firing bolts, -15% damage"
	mod_blades.damage_multiplier = 0.85
	mod_blades.color_tint = Color(1.0, 0.3, 0.2)

	var mod_haunt := SpellModification.new()
	mod_haunt.mod_name = "Haunt"
	mod_haunt.mod_id = &"spirit_haunt"
	mod_haunt.description = "Spirits fly to enemies and explode for 150% damage AoE, 2s recovery"
	mod_haunt.damage_multiplier = 1.5
	mod_haunt.color_tint = Color(0.35, 0.15, 0.6)

	sp.modifications = [mod_phantom, mod_blades, mod_haunt]
	return sp

func _create_shield() -> Spell:
	var sh := SpellData.new()
	sh.spell_name = "Shield"
	sh.spell_id = &"shield"
	sh.max_level = 5
	sh.cast_pattern = Spell.CastPattern.AOE
	sh.base_damage = 0.0
	sh.base_cooldown = 15.0
	sh.color = Color(0.3, 0.7, 1.0)
	sh.icon = load("res://Sprites/shield_icon_pix.png")
	sh.vfx_color_primary = Color(0.4, 0.7, 1.0)
	sh.vfx_color_secondary = Color(0.2, 0.4, 0.8)

	var behavior := ShieldBehavior.new()
	behavior.base_charges = 2
	behavior.base_recharge_time = 15.0
	sh.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.cooldown_multiplier = 0.95
	lvl2.description = "+1 charge, -5% cooldown"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.cooldown_multiplier = 0.9
	lvl3.description = "+1 charge, -10% cooldown"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.cooldown_multiplier = 0.85
	lvl4.description = "+1 charge, -15% cooldown"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.cooldown_multiplier = 0.8
	lvl5.description = "+2 charges, -20% cooldown"

	sh.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_thorns := SpellModification.new()
	mod_thorns.mod_name = "Thorns"
	mod_thorns.mod_id = &"shield_thorns"
	mod_thorns.description = "On absorb: 100% spell damage to all enemies in range 100, +20% cooldown"
	mod_thorns.cooldown_multiplier = 1.2
	mod_thorns.color_tint = Color(0.9, 0.3, 0.2)

	var mod_refract := SpellModification.new()
	mod_refract.mod_name = "Refraction"
	mod_refract.mod_id = &"shield_refraction"
	mod_refract.description = "On absorb: fires 6 homing magic projectiles"
	mod_refract.damage_multiplier = 1.0
	mod_refract.color_tint = Color(1.0, 0.85, 0.3)

	var mod_aegis := SpellModification.new()
	mod_aegis.mod_name = "Aegis"
	mod_aegis.mod_id = &"shield_aegis"
	mod_aegis.description = "1 charge, absorbs all damage fully, -60% cooldown"
	mod_aegis.cooldown_multiplier = 0.4
	mod_aegis.color_tint = Color(0.9, 0.9, 1.0)

	sh.modifications = [mod_thorns, mod_refract, mod_aegis]
	return sh

func _create_fire_breath() -> Spell:
	var fb := SpellData.new()
	fb.spell_name = "Fire Breath"
	fb.spell_id = &"fire_breath"
	fb.max_level = 5
	fb.cast_pattern = Spell.CastPattern.AOE
	fb.base_damage = 24.0
	fb.base_cooldown = 4.0
	fb.color = Color(1.0, 0.5, 0.1)
	fb.icon = preload("res://Sprites/firebreath_icon_pix.png")
	fb.vfx_color_primary = Color(1.0, 0.5, 0.1)
	fb.vfx_color_secondary = Color(0.8, 0.2, 0.05)

	var behavior := FireBreathBehavior.new()
	behavior.cone_angle = PI * 0.3
	behavior.cone_range = 180.0
	behavior.damage_interval = 0.10
	behavior.tick_damage = 16.0
	behavior.burst_ticks = 22
	fb.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.2
	lvl2.description = "Damage +25%, +20% range"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.area_multiplier = 1.3
	lvl3.description = "Damage +30%, +30% range"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.4
	lvl4.description = "Damage +40%, +40% range"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.area_multiplier = 1.6
	lvl5.description = "Damage +60%, +60% range"

	fb.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_dragon := SpellModification.new()
	mod_dragon.mod_name = "Dragon Breath"
	mod_dragon.mod_id = &"fire_breath_dragon"
	mod_dragon.description = "2x size, 2x damage, turns blue over time"
	mod_dragon.damage_multiplier = 2.0
	mod_dragon.color_tint = Color(1.0, 0.3, 0.05)

	var mod_fan := SpellModification.new()
	mod_fan.mod_name = "Fire Fan"
	mod_fan.mod_id = &"fire_breath_fan"
	mod_fan.description = "Wider cone, -20% damage"
	mod_fan.damage_multiplier = 0.8
	mod_fan.color_tint = Color(1.0, 0.35, 0.5)

	var mod_ash := SpellModification.new()
	mod_ash.mod_name = "Burning Ash"
	mod_ash.mod_id = &"fire_breath_ash"
	mod_ash.description = "Burning ground trail for 2s, -25% base damage"
	mod_ash.damage_multiplier = 0.75
	mod_ash.color_tint = Color(0.7, 0.15, 0.05)

	fb.modifications = [mod_dragon, mod_fan, mod_ash]
	return fb

func _create_needle() -> Spell:
	var nd := SpellData.new()
	nd.spell_name = "Needle"
	nd.spell_id = &"needle"
	nd.max_level = 5
	nd.cast_pattern = Spell.CastPattern.AOE
	nd.base_damage = 24.0
	nd.base_cooldown = 4.0
	nd.color = Color(0.85, 0.75, 0.95)
	nd.icon = preload("res://Sprites/needle_icon_pix.png")
	nd.vfx_color_primary = Color(0.85, 0.75, 0.95)
	nd.vfx_color_secondary = Color(0.6, 0.45, 0.75)

	var behavior := NeedleBehavior.new()
	behavior.needle_range = 220.0
	behavior.needle_count = 1
	behavior.needle_speed = 500.0
	behavior.cooldown_time = 1.2
	behavior.dir_smooth_speed = 4.0
	behavior.stabbed_duration = 0.5
	behavior.return_pierce_ratio = 0.5
	behavior.return_detect_radius = 30.0
	behavior.cascade_delay = 0.1
	behavior.cascade_spread = 8.0
	nd.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.2
	lvl2.description = "Damage +25%, +20% needle length"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +1 needle cascade"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.4
	lvl4.description = "Damage +80%, +40% needle length"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.projectile_count_add = 2
	lvl5.description = "Damage +120%, +2 needle cascade"

	nd.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_volley := SpellModification.new()
	mod_volley.mod_name = "Needle Volley"
	mod_volley.mod_id = &"needle_volley"
	mod_volley.description = "7 needles in a 45 degree cone burst, +30% cooldown"
	mod_volley.cooldown_multiplier = 1.3
	mod_volley.damage_multiplier = 1.0
	mod_volley.color_tint = Color(0.8, 0.85, 0.95)

	var mod_ricochet := SpellModification.new()
	mod_ricochet.mod_name = "Ricochet Needle"
	mod_ricochet.mod_id = &"needle_ricochet"
	mod_ricochet.description = "Needle stabs then bounces to the next enemy up to 3 times, -15% damage"
	mod_ricochet.damage_multiplier = 0.85
	mod_ricochet.color_tint = Color(0.85, 0.9, 1.0)

	var mod_frost := SpellModification.new()
	mod_frost.mod_name = "Frost Shard"
	mod_frost.mod_id = &"needle_frost"
	mod_frost.description = "Stab freezes enemies for 3.5s, return pierce also slows, -20% damage"
	mod_frost.damage_multiplier = 0.8
	mod_frost.damage_interval_mult = 1.15
	mod_frost.color_tint = Color(0.6, 0.7, 0.95)

	nd.modifications = [mod_volley, mod_ricochet, mod_frost]
	return nd

func _create_poison_pool() -> Spell:
	var pp := SpellData.new()
	pp.spell_name = "Poison Pool"
	pp.spell_id = &"poison_pool"
	pp.max_level = 5
	pp.cast_pattern = Spell.CastPattern.AOE
	pp.base_damage = 8.0
	pp.base_cooldown = 3.0
	pp.color = Color(0.4, 1.0, 0.2)
	pp.icon = load("res://Sprites/poison_puddle_icon_pix.png")
	pp.vfx_color_primary = Color(0.4, 1.0, 0.2)
	pp.vfx_color_secondary = Color(0.1, 0.5, 0.05)

	var behavior := PoisonPoolBehavior.new()
	behavior.base_radius = 85.0
	behavior.damage_interval = 0.3
	behavior.duration = 5.0
	behavior.spawn_delay = 0.3
	behavior.base_max_pools = 1
	pp.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.2
	lvl2.description = "Damage +25%, +20% area"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.area_multiplier = 1.3
	lvl3.projectile_count_add = 1
	lvl3.description = "Damage +50%, +30% area, +1 pool"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.4
	lvl4.description = "Damage +80%, +40% area"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.area_multiplier = 1.6
	lvl5.projectile_count_add = 1
	lvl5.description = "Damage +120%, +60% area, +1 pool (3 max)"

	pp.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_bloom := SpellModification.new()
	mod_bloom.mod_name = "Toxic Bloom"
	mod_bloom.mod_id = &"poison_pool_bloom"
	mod_bloom.mod_type = SpellModification.ModType.ON_KILL_EXPLODE
	mod_bloom.description = "Enemies killed in the pool explode for 50% damage AoE"
	mod_bloom.damage_multiplier = 1.0
	mod_bloom.color_tint = Color(0.4, 1.0, 0.2)

	var mod_miasma := SpellModification.new()
	mod_miasma.mod_name = "Miasma"
	mod_miasma.mod_id = &"poison_pool_miasma"
	mod_miasma.mod_type = SpellModification.ModType.AREA_BOOST
	mod_miasma.description = "2.5x pool radius, -40% damage per tick"
	mod_miasma.zone_radius_mult = 2.5
	mod_miasma.damage_multiplier = 0.6
	mod_miasma.color_tint = Color(0.1, 0.4, 0.05)

	var mod_plague := SpellModification.new()
	mod_plague.mod_name = "Plague"
	mod_plague.mod_id = &"poison_pool_plague"
	mod_plague.mod_type = SpellModification.ModType.TICK_RATE
	mod_plague.description = "3x tick speed, -25% damage each"
	mod_plague.damage_interval_mult = 0.333
	mod_plague.damage_multiplier = 0.75
	mod_plague.color_tint = Color(0.5, 0.9, 0.15)

	pp.modifications = [mod_bloom, mod_miasma, mod_plague]
	return pp

func _create_frost_nova() -> Spell:
	var fn := SpellData.new()
	fn.spell_name = "Frost Nova"
	fn.spell_id = &"frost_nova"
	fn.max_level = 5
	fn.cast_pattern = Spell.CastPattern.AOE
	fn.base_damage = 45.0
	fn.base_cooldown = 4.0
	fn.color = Color(0.6, 0.85, 1.0)
	fn.icon = load("res://Sprites/electric_zone_pix.png")
	fn.vfx_color_primary = Color(0.6, 0.85, 1.0)
	fn.vfx_color_secondary = Color(0.3, 0.6, 0.9)
	fn.vfx_impact_key = "frost_nova"

	var behavior := FrostNovaBehavior.new()
	behavior.nova_radius = 140.0
	behavior.freeze_duration = 2.0
	fn.behavior = behavior

	var lvl2 := SpellLevelData.new()
	lvl2.level = 2
	lvl2.damage_multiplier = 1.25
	lvl2.area_multiplier = 1.2
	lvl2.description = "Damage +25%, area +20%"

	var lvl3 := SpellLevelData.new()
	lvl3.level = 3
	lvl3.damage_multiplier = 1.5
	lvl3.area_multiplier = 1.3
	lvl3.description = "Damage +50%, area +30%, freeze +0.3s"

	var lvl4 := SpellLevelData.new()
	lvl4.level = 4
	lvl4.damage_multiplier = 1.8
	lvl4.area_multiplier = 1.4
	lvl4.description = "Damage +80%, area +40%"

	var lvl5 := SpellLevelData.new()
	lvl5.level = 5
	lvl5.damage_multiplier = 2.2
	lvl5.area_multiplier = 1.6
	lvl5.description = "Damage +120%, area +60%, freeze +0.5s"

	fn.level_data = [lvl2, lvl3, lvl4, lvl5]

	var mod_shards := SpellModification.new()
	mod_shards.mod_name = "Ice Shards"
	mod_shards.mod_id = &"frost_nova_shards"
	mod_shards.description = "Nova fires 6 piercing ice shards dealing 40% damage each"
	mod_shards.damage_multiplier = 1.0
	mod_shards.color_tint = Color(0.7, 0.9, 1.0)

	var mod_permafrost := SpellModification.new()
	mod_permafrost.mod_name = "Permafrost"
	mod_permafrost.mod_id = &"frost_nova_permafrost"
	mod_permafrost.description = "Nova deals +25% area damage to frozen enemies"
	mod_permafrost.damage_multiplier = 1.25
	mod_permafrost.color_tint = Color(0.4, 0.7, 0.9)

	var mod_crystallize := SpellModification.new()
	mod_crystallize.mod_name = "Crystallize"
	mod_crystallize.mod_id = &"frost_nova_crystallize"
	mod_crystallize.description = "Killing frozen enemies triggers ice explosion"
	mod_crystallize.damage_multiplier = 1.0
	mod_crystallize.color_tint = Color(0.5, 0.8, 1.0)

	fn.modifications = [mod_shards, mod_permafrost, mod_crystallize]
	return fn

func _get_lvl_desc_key(spell_id: StringName, level: int) -> StringName:
	var prefix := ""
	match spell_id:
		&"magic_bolt": prefix = "mb"
		&"fireball": prefix = "fb"
		&"orbiting_arcana": prefix = "oa"
		&"lightning_strike": prefix = "ls"
		&"cyclone": prefix = "cy"
		&"arcane_ray": prefix = "ar"
		&"electric_zone": prefix = "ez"
		&"spirit": prefix = "sp"
		&"shield": prefix = "sh"
		&"fire_breath": prefix = "fbr"
		&"needle": prefix = "ndl"
		&"poison_pool": prefix = "ppl"
		&"frost_nova": prefix = "fn"
		_: return &""
	return StringName(prefix + "_lv" + str(level))
