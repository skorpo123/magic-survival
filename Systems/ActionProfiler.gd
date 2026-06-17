extends Node

const FLUSH_INTERVAL: int = 60

static var _instance: Node = null
static var _enabled: bool = true

var _buffer: PackedStringArray = PackedStringArray()
var _flush_counter: int = 0
var _file: FileAccess = null
var _file_path: String = ""
var _frame: int = 0
var _aggregates: Dictionary = {}
var _summary_on_game_end: bool = true
var _pending: Array = []

func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = OS.is_debug_build()
	if not _enabled:
		set_process(false)
		return
	_open_file()
	_connect_eventbus()

func _open_file() -> void:
	var ts: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_").replace(" ", "")
	_file_path = "user://profiler_%s.csv" % ts
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	if _file:
		_file.store_line("frame,timestamp,category,action,fps_before,fps_after,delta_fps,process_before,process_after,objects_before,objects_after,draw_calls_before,draw_calls_after,items_drawn_before,items_drawn_after")

func _connect_eventbus() -> void:
	EventBus.player_damaged.connect(_on_eventbus_player_damaged)
	EventBus.player_healed.connect(_on_eventbus_player_healed)
	EventBus.player_died.connect(_on_eventbus_player_died)
	EventBus.player_level_up.connect(_on_eventbus_player_level_up)
	EventBus.player_xp_gained.connect(_on_eventbus_player_xp_gained)
	EventBus.enemy_died.connect(_on_eventbus_enemy_died)
	EventBus.enemy_spawned.connect(_on_eventbus_enemy_spawned)
	EventBus.spell_cast.connect(_on_eventbus_spell_cast)
	EventBus.spell_upgraded.connect(_on_eventbus_spell_upgraded)
	EventBus.wave_started.connect(_on_eventbus_wave_started)
	EventBus.wave_cleared.connect(_on_eventbus_wave_cleared)
	EventBus.pickup_collected.connect(_on_eventbus_pickup_collected)
	EventBus.mega_magnet_activated.connect(_on_eventbus_mega_magnet_activated)
	EventBus.mega_magnet_ended.connect(_on_eventbus_mega_magnet_ended)
	EventBus.game_started.connect(_on_eventbus_game_started)
	EventBus.game_paused.connect(_on_eventbus_game_paused)
	EventBus.game_resumed.connect(_on_eventbus_game_resumed)
	EventBus.game_over.connect(_on_eventbus_game_over)
	EventBus.victory.connect(_on_eventbus_victory)
	EventBus.level_up_card_selected.connect(_on_eventbus_level_up_card_selected)

func _process(_delta: float) -> void:
	if not _enabled:
		return
	_frame = Engine.get_process_frames()
	_flush_counter += 1
	if _flush_counter >= FLUSH_INTERVAL:
		_flush_counter = 0
		_flush()
	if not _pending.is_empty():
		var after: Dictionary = _snapshot()
		for entry in _pending:
			_log(entry.category, entry.action, entry.before, after)
		_pending.clear()
	if Input.is_key_pressed(KEY_F9):
		_print_summary()

func _flush() -> void:
	if not _file or _buffer.is_empty():
		return
	for line in _buffer:
		_file.store_line(line)
	_buffer.clear()
	_file.flush()

static func _snapshot() -> Dictionary:
	return {
		fps = Engine.get_frames_per_second(),
		process = Performance.get_monitor(Performance.TIME_PROCESS),
		objects = Performance.get_monitor(Performance.OBJECT_COUNT),
		draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		items_drawn = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}

static func probe(category: String, action: String) -> void:
	if not _instance or not _enabled:
		return
	var before: Dictionary = _snapshot()
	_instance._pending.append({category = category, action = action, before = before})

func _log(category: String, action: String, before: Dictionary, after: Dictionary) -> void:
	var delta_fps: float = after.fps - before.fps
	var line: String = "%d,%.3f,%s,%s,%.1f,%.1f,%.1f,%.6f,%.6f,%d,%d,%d,%d,%d,%d" % [
		_frame, Time.get_ticks_msec() * 0.001, category, action,
		before.fps, after.fps, delta_fps,
		before.process, after.process,
		before.objects, after.objects,
		before.draw_calls, after.draw_calls,
		before.items_drawn, after.items_drawn,
	]
	_buffer.append(line)
	_accumulate(category, action, before, after, delta_fps)

func _accumulate(category: String, action: String, before: Dictionary, after: Dictionary, delta_fps: float) -> void:
	var key: String = "%s/%s" % [category, action]
	if not _aggregates.has(key):
		_aggregates[key] = {
			count = 0,
			total_delta_fps = 0.0,
			min_delta_fps = INF,
			max_delta_fps = -INF,
			total_process_after = 0.0,
			max_process_after = 0.0,
			total_delta_objects = 0.0,
			min_delta_objects = INF,
			max_delta_objects = -INF,
		}
	var agg: Dictionary = _aggregates[key]
	agg.count += 1
	agg.total_delta_fps += delta_fps
	agg.min_delta_fps = minf(agg.min_delta_fps, delta_fps)
	agg.max_delta_fps = maxf(agg.max_delta_fps, delta_fps)
	agg.total_process_after += after.process
	agg.max_process_after = maxf(agg.max_process_after, after.process)
	var delta_objects: float = after.objects - before.objects
	agg.total_delta_objects += delta_objects
	agg.min_delta_objects = minf(agg.min_delta_objects, delta_objects)
	agg.max_delta_objects = maxf(agg.max_delta_objects, delta_objects)

func _on_eventbus_player_damaged(amount: float, _source: Node2D) -> void:
	_queue_eventbus("player_damaged", "amount:%.1f" % amount)

func _on_eventbus_player_healed(amount: float) -> void:
	_queue_eventbus("player_healed", "amount:%.1f" % amount)

func _on_eventbus_player_died() -> void:
	_queue_eventbus("player_died", "died")
	if _summary_on_game_end:
		call_deferred("_print_summary")

func _on_eventbus_player_level_up(new_level: int) -> void:
	_queue_eventbus("player_level_up", "level:%d" % new_level)

func _on_eventbus_player_xp_gained(amount: float) -> void:
	_queue_eventbus("player_xp_gained", "amount:%.1f" % amount)

func _on_eventbus_enemy_died(_pos: Vector2, xp_value: float, enemy_type: StringName) -> void:
	_queue_eventbus("enemy_died", "type:%s_xp:%.1f" % [enemy_type, xp_value])

func _on_eventbus_enemy_spawned(enemy_type: StringName) -> void:
	_queue_eventbus("enemy_spawned", "type:%s" % enemy_type)

func _on_eventbus_spell_cast(spell_name: StringName, _pos: Vector2, _dir: Vector2) -> void:
	_queue_eventbus("spell_cast", "spell:%s" % spell_name)

func _on_eventbus_spell_upgraded(spell_name: StringName, new_level: int) -> void:
	_queue_eventbus("spell_upgraded", "spell:%s_lvl:%d" % [spell_name, new_level])

func _on_eventbus_wave_started(wave_number: int) -> void:
	_queue_eventbus("wave_started", "wave:%d" % wave_number)

func _on_eventbus_wave_cleared(wave_number: int) -> void:
	_queue_eventbus("wave_cleared", "wave:%d" % wave_number)

func _on_eventbus_pickup_collected(pickup_type: StringName, value: float) -> void:
	_queue_eventbus("pickup_collected", "type:%s_val:%.1f" % [pickup_type, value])

func _on_eventbus_mega_magnet_activated() -> void:
	_queue_eventbus("mega_magnet", "activated")

func _on_eventbus_mega_magnet_ended() -> void:
	_queue_eventbus("mega_magnet", "ended")

func _on_eventbus_game_started() -> void:
	_aggregates.clear()
	_queue_eventbus("game_started", "started")

func _on_eventbus_game_paused() -> void:
	_queue_eventbus("game_paused", "paused")

func _on_eventbus_game_resumed() -> void:
	_queue_eventbus("game_resumed", "resumed")

func _on_eventbus_game_over() -> void:
	_queue_eventbus("game_over", "over")
	if _summary_on_game_end:
		call_deferred("_print_summary")

func _on_eventbus_victory() -> void:
	_queue_eventbus("victory", "victory")
	if _summary_on_game_end:
		call_deferred("_print_summary")

func _on_eventbus_level_up_card_selected(card_data: Resource) -> void:
	_queue_eventbus("level_up_card", "card:%s" % (card_data.resource_path if card_data else "null"))

func _queue_eventbus(signal_name: String, action: String) -> void:
	var before: Dictionary = _snapshot()
	_pending.append({category = "eventbus/%s" % signal_name, action = action, before = before})

func _print_summary() -> void:
	print("\n========== ACTION PROFILER SUMMARY ==========")
	print("Log file: %s" % _file_path)
	print("Total event types: %d\n" % _aggregates.size())

	var sorted_by_fps: Array = _aggregates.keys()
	sorted_by_fps.sort_custom(func(a, b): return _aggregates[a].total_delta_fps / _aggregates[a].count < _aggregates[b].total_delta_fps / _aggregates[b].count)

	print("--- Top-10 by AVG FPS DROP ---")
	print("%-40s %6s %10s %10s %10s" % ["action", "count", "avg_dFPS", "min_dFPS", "max_dFPS"])
	var count_fps: int = 0
	for key in sorted_by_fps:
		if count_fps >= 10:
			break
		var agg: Dictionary = _aggregates[key]
		var avg_dfps: float = agg.total_delta_fps / agg.count
		print("%-40s %6d %10.1f %10.1f %10.1f" % [key, agg.count, avg_dfps, agg.min_delta_fps, agg.max_delta_fps])
		count_fps += 1

	var sorted_by_process: Array = _aggregates.keys()
	sorted_by_process.sort_custom(func(a, b): return _aggregates[a].max_process_after > _aggregates[b].max_process_after)

	print("\n--- Top-10 by PEAK PROCESS TIME ---")
	print("%-40s %6s %10s %10s" % ["action", "count", "avg_proc", "peak_proc"])
	var count_proc: int = 0
	for key in sorted_by_process:
		if count_proc >= 10:
			break
		var agg: Dictionary = _aggregates[key]
		var avg_proc: float = agg.total_process_after / agg.count
		print("%-40s %6d %10.4f %10.4f" % [key, agg.count, avg_proc, agg.max_process_after])
		count_proc += 1

	var sorted_by_objects: Array = _aggregates.keys()
	sorted_by_objects.sort_custom(func(a, b): return _aggregates[a].max_delta_objects > _aggregates[b].max_delta_objects)

	print("\n--- Top-10 by OBJECT COUNT INCREASE ---")
	print("%-40s %6s %10s %10s %10s" % ["action", "count", "avg_dObj", "min_dObj", "max_dObj"])
	var count_obj: int = 0
	for key in sorted_by_objects:
		if count_obj >= 10:
			break
		var agg: Dictionary = _aggregates[key]
		var avg_dobj: float = agg.total_delta_objects / agg.count
		print("%-40s %6d %10.1f %10.1f %10.1f" % [key, agg.count, avg_dobj, agg.min_delta_objects, agg.max_delta_objects])
		count_obj += 1

	var categories: Dictionary = {}
	for key in _aggregates:
		var cat: String = key.split("/")[0]
		if not categories.has(cat):
			categories[cat] = {count = 0, total_delta_fps = 0.0, total_process_after = 0.0, total_delta_objects = 0.0}
		var agg: Dictionary = _aggregates[key]
		var cagg: Dictionary = categories[cat]
		cagg.count += agg.count
		cagg.total_delta_fps += agg.total_delta_fps
		cagg.total_process_after += agg.total_process_after
		cagg.total_delta_objects += agg.total_delta_objects

	print("\n--- PER-CATEGORY AGGREGATES ---")
	print("%-20s %6s %10s %10s %10s" % ["category", "count", "avg_dFPS", "avg_proc", "avg_dObj"])
	for cat in categories:
		var cagg: Dictionary = categories[cat]
		if cagg.count > 0:
			print("%-20s %6d %10.1f %10.4f %10.1f" % [cat, cagg.count, cagg.total_delta_fps / cagg.count, cagg.total_process_after / cagg.count, cagg.total_delta_objects / cagg.count])

	print("=============================================\n")

func _exit_tree() -> void:
	_flush()
	if _file:
		_file.close()
	_instance = null
