class_name MagicBoltCaster extends SpellCaster

const BOLT_INTERVAL: float = 0.06

var _bolt_queue: Array[Dictionary] = []
var _bolt_timer: float = 0.0
var _pending_dir: Vector2 = Vector2.RIGHT
var _pending_stats: PlayerStats = null

func _process(delta: float) -> void:
	if _bolt_queue.is_empty():
		return
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_fire_next()

func _cast_single(dir: Vector2, player_stats: PlayerStats) -> void:
	_pending_dir = dir
	_pending_stats = player_stats
	var count := spell.get_projectile_count()
	if count <= 1:
		var proj := PoolManager.spawn(spell.pool_name, global_position)
		if proj:
			if proj.has_method("setup"):
				proj.setup(dir, spell, player_stats)
			if proj.has_method("on_spawn"):
				proj.on_spawn()
	else:
		var total_spread := 0.15 * (count - 1)
		var start_angle := dir.angle() - total_spread / 2.0
		for i in range(count):
			_bolt_queue.append({
				"dir": Vector2.RIGHT.rotated(start_angle + 0.15 * i),
			})
		_bolt_timer = 0.0
		_fire_next()

func _fire_next() -> void:
	if _bolt_queue.is_empty():
		return
	var entry: Dictionary = _bolt_queue.pop_front()
	var dir: Vector2 = entry["dir"]
	var proj := PoolManager.spawn(spell.pool_name, global_position)
	if proj:
		if proj.has_method("setup"):
			proj.setup(dir, spell, _pending_stats)
		if proj.has_method("on_spawn"):
			proj.on_spawn()
	if not _bolt_queue.is_empty():
		_bolt_timer = BOLT_INTERVAL
