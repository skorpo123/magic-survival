extends Node

# Per-effect state
var _sw_cooldown: float = 0.0
var _sw_active: bool = false
var _sw_heal_timer: float = 0.0
var _echo_count: int = 0
var _is_echoing: bool = false
var _static_aura_area: Area2D = null
var _cascade_cooldown: float = 0.0
var _overflow_hp: float = 0.0
var _split_cooldown: float = 0.0
var _aura_timer: float = 0.0
var _trail_timer: float = 0.0
var _twin_cast_chance: float = 0.0
var _berserker_oath: bool = false
var _gambler_timer: float = 0.0
var _gambler_active: bool = false
var _gambler_mult: float = 1.0
var _gambler_is_double: bool = false

# Equipped flags
var _has_second_wind: bool = false
var _has_spell_echo: bool = false
var _has_tiny_menace: bool = false
var _has_static_aura: bool = false
var _has_overflow: bool = false
var _has_cascade: bool = false
var _has_move_trail: bool = false
var _has_low_hp_explode: bool = false
var _has_spell_split: bool = false
var _has_damage_aura: bool = false
var _has_twin_cast: bool = false
var _has_berserker_oath: bool = false
var _has_gambler_dice: bool = false
var _has_toxic_bloom: bool = false
var _has_volcanic_glyph: bool = false

func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.player_xp_gained.connect(_on_player_xp_gained)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
	EventBus.crit_landed.connect(_on_crit_landed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.enemy_died.connect(_on_enemy_died)

func _on_game_started() -> void:
	_sw_cooldown = 0.0
	_sw_active = false
	_echo_count = 0
	_cascade_cooldown = 0.0
	_overflow_hp = 0.0
	_split_cooldown = 0.0
	_aura_timer = 0.0
	_trail_timer = 0.0
	_damage_aura_timer = 0.0
	_gambler_timer = 0.0
	_gambler_active = false
	_gambler_mult = 1.0
	_twin_cast_chance = 0.0
	if _static_aura_area and is_instance_valid(_static_aura_area):
		_static_aura_area.queue_free()
		_static_aura_area = null
	_has_second_wind = false
	_has_spell_echo = false
	_has_tiny_menace = false
	_has_static_aura = false
	_has_overflow = false
	_has_cascade = false
	_has_move_trail = false
	_has_low_hp_explode = false
	_has_spell_split = false
	_has_damage_aura = false
	_has_twin_cast = false
	_has_berserker_oath = false
	_has_gambler_dice = false
	_has_toxic_bloom = false
	_has_volcanic_glyph = false
	var player := GameManager.get_player()
	if player and player.has_meta(&"original_scale"):
		player.scale = player.get_meta(&"original_scale")
		player.remove_meta(&"original_scale")

func _on_artifact_equipped(artifact: Resource) -> void:
	if not artifact is ArtifactData:
		return
	for bonus in artifact.bonuses:
		match bonus.effect_type:
			ArtifactEffect.EffectType.SECOND_WIND:
				_has_second_wind = true
				_sw_cooldown = 0.0
			ArtifactEffect.EffectType.SPELL_ECHO:
				_has_spell_echo = true
				_echo_count = 0
			ArtifactEffect.EffectType.TINY_MENACE:
				_has_tiny_menace = true
				_apply_tiny_menace()
			ArtifactEffect.EffectType.STATIC_AURA:
				_has_static_aura = true
				_create_static_aura()
			ArtifactEffect.EffectType.OVERFLOW:
				_has_overflow = true
			ArtifactEffect.EffectType.CRIT_CASCADE:
				_has_cascade = true
			ArtifactEffect.EffectType.MOVE_TRAIL:
				_has_move_trail = true
			ArtifactEffect.EffectType.LOW_HP_EXPLODE:
				_has_low_hp_explode = true
			ArtifactEffect.EffectType.SPELL_SPLIT:
				_has_spell_split = true
			ArtifactEffect.EffectType.DAMAGE_AURA:
				_has_damage_aura = true
			ArtifactEffect.EffectType.TWIN_CAST:
				_has_twin_cast = true
				_twin_cast_chance = maxf(_twin_cast_chance, bonus.value)
			ArtifactEffect.EffectType.BERSERKER_OATH:
				_has_berserker_oath = true
			ArtifactEffect.EffectType.GAMBLER_DICE:
				_has_gambler_dice = true
				_gambler_timer = 30.0
			ArtifactEffect.EffectType.TOXIC_BLOOM:
				_has_toxic_bloom = true
			ArtifactEffect.EffectType.VOLCANIC_GLYPH:
				_has_volcanic_glyph = true

# === Second Wind ===
func _on_player_damaged(_amount: float, _source: Node2D) -> void:
	if not _has_second_wind or _sw_cooldown > 0.0 or _sw_active:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	if stats.current_hp / stats.max_hp < 0.25:
		_sw_active = true
		_sw_heal_timer = 3.0
		BurstEffectPool.spawn("explosion", player.global_position, Color(0.2, 1.0, 0.3))

func _process_second_wind(delta: float) -> void:
	if not _sw_active:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	_sw_heal_timer -= delta
	if _sw_heal_timer <= 0.0:
		_sw_active = false
		_sw_cooldown = 60.0
		return
	var heal_per_sec := stats.max_hp * 0.50 / 3.0
	stats.current_hp = minf(stats.current_hp + heal_per_sec * delta, stats.max_hp)
	EventBus.player_healed.emit(heal_per_sec * delta)

# === Spell Echo ===
func _on_spell_cast(spell_name: StringName, _pos: Vector2, _dir: Vector2) -> void:
	if _has_twin_cast and not _is_echoing:
		if randf() < _twin_cast_chance:
			_trigger_twin_cast(spell_name)
	if _has_spell_split and not _is_echoing:
		_split_cooldown -= 1.0
		if _split_cooldown <= 0.0:
			_split_cooldown = 3.0
			_trigger_split(spell_name)
	if not _has_spell_echo or _is_echoing:
		return
	_echo_count += 1
	if _echo_count >= 10:
		_echo_count = 0
		_trigger_echo(spell_name)

func _trigger_twin_cast(spell_name: StringName) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	for child in player.get_children():
		if child is Node2D and child.has_method("notify_spell_upgraded") and "spell" in child:
			if child.spell and child.spell.spell_id == spell_name:
				_is_echoing = true
				var ps: PlayerStats = null
				if "stats" in player and player.stats is PlayerStats:
					ps = player.stats
				child.spell.behavior.cast(child, child.spell, ps)
				_is_echoing = false
				BurstEffectPool.spawn("explosion", player.global_position, Color(0.6, 0.3, 1.0))
				return

func _trigger_split(spell_name: StringName) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	for child in player.get_children():
		if child is Node2D and child.has_method("notify_spell_upgraded") and "spell" in child:
			if child.spell and child.spell.spell_id == spell_name:
				_is_echoing = true
				var ps: PlayerStats = null
				if "stats" in player and player.stats is PlayerStats:
					ps = player.stats
				child.spell.behavior.cast(child, child.spell, ps)
				_is_echoing = false
				BurstEffectPool.spawn("explosion", player.global_position, Color(0.3, 0.8, 1.0))
				return

func _trigger_echo(spell_name: StringName) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	for child in player.get_children():
		if child is Node2D and child.has_method("notify_spell_upgraded") and "spell" in child:
			if child.spell and child.spell.spell_id == spell_name:
				_is_echoing = true
				var ps: PlayerStats = null
				if "stats" in player and player.stats is PlayerStats:
					ps = player.stats
				child.spell.behavior.cast(child, child.spell, ps)
				_is_echoing = false
				BurstEffectPool.spawn("explosion", player.global_position, Color(1.0, 0.4, 0.8))
				return

# === Tiny Menace ===
func _apply_tiny_menace() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	if not player.has_meta(&"original_scale"):
		player.set_meta(&"original_scale", player.scale)
	player.scale = player.get_meta(&"original_scale") * 0.75

# === Static Aura (fixed: deals 5 dmg/sec to nearby enemies) ===
func _create_static_aura() -> void:
	if _static_aura_area and is_instance_valid(_static_aura_area):
		return
	var player := GameManager.get_player()
	if not player:
		return
	_static_aura_area = Area2D.new()
	_static_aura_area.collision_layer = 0
	_static_aura_area.collision_mask = 0
	player.add_child(_static_aura_area)

func _process_static_aura(delta: float) -> void:
	if not _static_aura_area or not is_instance_valid(_static_aura_area):
		return
	var player := GameManager.get_player()
	if not player:
		return
	_static_aura_area.global_position = player.global_position
	_aura_timer += delta
	if _aura_timer >= 1.0:
		_aura_timer = 0.0
		var mp: float = 1.0
		if "stats" in player and player.stats is PlayerStats:
			mp = player.stats.magic_power
		var dmg := 5.0 * mp
		SwarmManager.damage_area(player.global_position, 80.0, dmg)
		EnemyMeshManager.damage_area(player.global_position, 80.0, dmg)
		BurstEffectPool.spawn("explosion", player.global_position, Color(0.4, 0.3, 0.9, 0.4))

# === Kill Heal ===
func _on_enemy_died(pos: Vector2, _xp: float, _type: StringName) -> void:
	if _has_low_hp_explode:
		var player := GameManager.get_player()
		if player:
			var mp: float = 1.0
			if "stats" in player and player.stats is PlayerStats:
				mp = player.stats.magic_power
			var explode_dmg := 15.0 * mp
			SwarmManager.damage_area(pos, 70.0, explode_dmg)
			EnemyMeshManager.damage_area(pos, 70.0, explode_dmg)
			BurstEffectPool.spawn("explosion", pos, Color(1.0, 0.5, 0.1))
	if _has_toxic_bloom and randf() < 0.20:
		_spawn_toxic_bloom_zone(pos)
	if _has_volcanic_glyph:
		_spawn_volcanic_trail(pos)

func _spawn_toxic_bloom_zone(pos: Vector2) -> void:
	var zone := DamageZone.new()
	var player := GameManager.get_player()
	if player:
		zone.setup(player, 60.0, 8.0, 0.5, Color(0.2, 0.8, 0.2, 0.4), &"cold")
		player.get_parent().add_child(zone)
		zone.global_position = pos
		BurstEffectPool.spawn("explosion", pos, Color(0.2, 0.8, 0.2, 0.4))
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(zone.queue_free)

func _spawn_volcanic_trail(pos: Vector2) -> void:
	var zone := DamageZone.new()
	var player := GameManager.get_player()
	if player:
		zone.setup(player, 40.0, 5.0, 0.5, Color(0.8, 0.3, 0.1, 0.4), &"fire")
		player.get_parent().add_child(zone)
		zone.global_position = pos
		var timer := get_tree().create_timer(1.5)
		timer.timeout.connect(zone.queue_free)

# === Move Trail ===
func _process_move_trail(delta: float) -> void:
	if not _has_move_trail:
		return
	_trail_timer += delta
	if _trail_timer < 1.0:
		return
	_trail_timer = 0.0
	var player := GameManager.get_player()
	if not player:
		return
	var vel: Vector2 = Vector2.ZERO
	if player is CharacterBody2D:
		vel = player.velocity
	if vel.length_squared() < 100.0:
		return
	var mp: float = 1.0
	if "stats" in player and player.stats is PlayerStats:
		mp = player.stats.magic_power
	var dmg := 5.0 * mp
	SwarmManager.damage_area(player.global_position, 50.0, dmg)
	EnemyMeshManager.damage_area(player.global_position, 50.0, dmg)

# === Damage Aura (periodic AoE around player) ===
var _damage_aura_timer: float = 0.0

func _process_damage_aura(delta: float) -> void:
	_damage_aura_timer += delta
	if _damage_aura_timer < 1.0:
		return
	_damage_aura_timer = 0.0
	var player := GameManager.get_player()
	if not player:
		return
	var mp: float = 1.0
	if "stats" in player and player.stats is PlayerStats:
		mp = player.stats.magic_power
	var dmg := 8.0 * mp
	SwarmManager.damage_area(player.global_position, 100.0, dmg)
	EnemyMeshManager.damage_area(player.global_position, 100.0, dmg)
	BurstEffectPool.spawn("explosion", player.global_position, Color(0.8, 0.2, 0.2, 0.3))

# === Overflow ===
func _on_player_xp_gained(amount: float) -> void:
	if not _has_overflow:
		return
	var hp_bonus := amount * 0.25
	_overflow_hp += hp_bonus
	var player := GameManager.get_player()
	if player and "stats" in player:
		var stats: PlayerStats = player.stats
		stats.current_hp = minf(stats.current_hp + hp_bonus, stats.max_hp + _overflow_hp)

func _process_overflow(delta: float) -> void:
	if _overflow_hp <= 0.0:
		return
	var player := GameManager.get_player()
	if not player or not "stats" in player:
		return
	var stats: PlayerStats = player.stats
	if stats.current_hp <= stats.max_hp:
		_overflow_hp = maxf(_overflow_hp - delta, 0.0)
		return
	var decay := 1.0 * delta
	stats.current_hp -= decay
	_overflow_hp -= decay
	if stats.current_hp < stats.max_hp:
		stats.current_hp = stats.max_hp
		_overflow_hp = 0.0

# === Cascade ===
func _on_crit_landed(damage: float, position: Vector2) -> void:
	if not _has_cascade or _cascade_cooldown > 0.0:
		return
	_cascade_cooldown = 0.5
	var wave_dmg := damage * 0.5
	SwarmManager.damage_area(position, 100.0, wave_dmg)
	EnemyMeshManager.damage_area(position, 100.0, wave_dmg)
	BurstEffectPool.spawn("shockwave", position, Color(1.0, 0.6, 0.2))
	JuiceManager.screen_shake(3.0, 0.06)

# === Gambler's Dice ===
func _process_gambler_dice(delta: float) -> void:
	if _gambler_active:
		_gambler_timer -= delta
		if _gambler_timer <= 0.0:
			_gambler_active = false
			_gambler_mult = 1.0
			_gambler_timer = 30.0
	else:
		_gambler_timer -= delta
		if _gambler_timer <= 0.0:
			_gambler_active = true
			_gambler_is_double = randf() > 0.5
			_gambler_mult = 2.0 if _gambler_is_double else 0.5
			_gambler_timer = 5.0

func get_gambler_damage_mult() -> float:
	if _gambler_active:
		return _gambler_mult
	return 1.0

# === Main process ===
func _process(delta: float) -> void:
	if _sw_active:
		_process_second_wind(delta)
	if _sw_cooldown > 0.0:
		_sw_cooldown -= delta
	if _cascade_cooldown > 0.0:
		_cascade_cooldown -= delta
	if _has_overflow and _overflow_hp > 0.0:
		_process_overflow(delta)
	if _has_static_aura:
		_process_static_aura(delta)
	if _has_damage_aura:
		_process_damage_aura(delta)
	if _has_gambler_dice:
		_process_gambler_dice(delta)
	if _has_move_trail:
		_process_move_trail(delta)
