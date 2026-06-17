class_name SpellCaster extends Node2D

@export var spell: Spell

var _player: CharacterBody2D
var _time_since_cast: float = 0.0
var _last_cast_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	_find_player()
	if spell and spell.projectile_scene:
		if PoolManager.get_available_count(spell.pool_name) == 0 and PoolManager.get_active_count(spell.pool_name) == 0:
			PoolManager.register_pool(spell.pool_name, spell.projectile_scene, spell.pool_initial_size)
	if spell and spell.behavior:
		var ps: PlayerStats = null
		if _player and "stats" in _player and _player.stats is PlayerStats:
			ps = _player.stats
		spell.behavior.on_spell_added(self, spell, ps)

func _find_player() -> void:
	var p := GameManager.get_player()
	if p and p is CharacterBody2D:
		_player = p
		return
	var node := get_parent()
	while node:
		if node is CharacterBody2D and node.is_in_group("player"):
			_player = node
			return
		node = node.get_parent()

func _process(delta: float) -> void:
	if not spell or not is_instance_valid(_player):
		if not is_instance_valid(_player):
			_find_player()
		return

	if not GameManager.is_playing():
		return

	if not spell.behavior:
		return

	if _player and "velocity" in _player:
		var vel: Vector2 = _player.velocity
		if vel.length_squared() > 4.0:
			_last_cast_dir = vel.normalized()

	spell.behavior.tick(delta)

	if not spell.behavior.needs_periodic_cast():
		return

	_time_since_cast += delta

	var player_stats: PlayerStats = null
	if "stats" in _player and _player.stats is PlayerStats:
		player_stats = _player.stats

	var cd_reduction: float = 0.0
	if player_stats:
		cd_reduction = player_stats.cooldown_reduction
	var cooldown := spell.get_cooldown(cd_reduction)

	if _time_since_cast < cooldown:
		return

	_time_since_cast = 0.0
	EventBus.spell_cast.emit(spell.spell_id, global_position, _last_cast_dir)
	spell.behavior.cast(self, spell, player_stats)

func notify_spell_upgraded() -> void:
	if not spell or not spell.behavior:
		return
	if spell.active_modification and spell.active_modification.mod_id == &"fireball_meteor":
		if not (spell.behavior is MeteorBehavior):
			var old_behavior: BaseSpellBehavior = spell.behavior
			var ps: PlayerStats = null
			if _player and "stats" in _player and _player.stats is PlayerStats:
				ps = _player.stats
			old_behavior.on_spell_removed(self, spell)
			var new_behavior := MeteorBehavior.new()
			spell.behavior = new_behavior
			new_behavior.on_spell_added(self, spell, ps)
			return
	var ps: PlayerStats = null
	if _player and "stats" in _player and _player.stats is PlayerStats:
		ps = _player.stats
	spell.behavior.on_spell_upgraded(self, spell, ps)
