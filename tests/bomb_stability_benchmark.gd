extends "res://tests/bomb_benchmark.gd"

const EXTRA_FIELDS: Array[String] = ["aoe_query_ms", "aoe_sort_ms", "aoe_damage_ms", "explosions", "aoe_entries", "contact_attempts", "projectile_allocations", "balloon_draw_ms", "effect_draw_ms", "objects", "static_bytes", "draw_calls"]
var _before_projectiles: int = 0

func _argument(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return fallback

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var phase: String = _argument("--phase", "before")
	var rows: Array[Dictionary] = []
	for trial in range(int(_argument("--trials", "2"))):
		for mode in ["bomb_base10", "bomb_frag10", "bomb_cluster10"]:
			if _argument("--mode", mode) != mode:
				continue
			for speed in [1, 2]:
				if int(_argument("--speed", str(speed))) != speed:
					continue
				var row: Dictionary = await _bomb_load(mode, 1000, speed)
				row.trial = trial
				rows.append(row)
	var label: String = "render" if _render else "cpu"
	if OS.get_cmdline_user_args().has("--hide-balloons"):
		label += "-hide-balloons"
	if OS.get_cmdline_user_args().has("--hide-effects"):
		label += "-hide-effects"
	var report: Dictionary = {"version": "v0.11.1", "phase": phase, "rendered": _render,
		"arguments": OS.get_cmdline_user_args(), "cache_enabled": not OS.get_cmdline_user_args().has("--uncached-draw"),
		"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "os": OS.get_name() + " " + OS.get_version(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless", "rows": rows,
		"source_sha": {"balloons": FileAccess.get_sha256("res://scripts/systems/balloon_system.gd"), "combat": FileAccess.get_sha256("res://scripts/systems/combat_system.gd")},
		"conditions": "1000 maintained pink/blue/yellow at route600..620,10 bombs,x250/400,y220+28*row. base000/frag302/cluster203. 30 warmup+120 measured frames/trial; speed fixed60Hz steps/frame. CPU includes maintenance+instrumentation+HUD; actual render post_draw includes CPU/GPU/driver/OS. Same fixture in before/after. Hide flags only hide drawing, never combat. Allocation proxies are projectile IDs, AoE candidate Dictionary entries and contact attempts, not a heap allocation trace. Static memory/object monitors are process-wide, sampled after frame, not transient allocation peaks. Nested timers overlap; do not sum. Draw calls include HUD/map. No budgets or balance conclusions from this stress fixture."}
	var base: String = "res://benchmarks/bomb-v0111-" + phase + "-" + label
	var file: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "speed", "trial", "mean_ms", "p95_ms", "cpu_mean_ms", "creation_ms", "narrow_ms", "resolution_ms", "grid_ms", "projectiles_max"]
	for field in EXTRA_FIELDS:
		keys.append(field + "_mean")
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, "NA")))
		csv.store_csv_line(values)
	csv.close()
	print("BOMB STABILITY BENCHMARK COMPLETE: %d cases %s %s" % [rows.size(), phase, label])
	quit()

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.combat.profile_updates = true
	game.balloons.use_draw_cache = not OS.get_cmdline_user_args().has("--uncached-draw")
	game.balloons.visible = not OS.get_cmdline_user_args().has("--hide-balloons")
	game.combat.visible = not OS.get_cmdline_user_args().has("--hide-effects")
	return game

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	game.combat.reset_profile()
	_before_projectiles = game.projectiles._next_id

func _frame(game: MainGame, speed: int, count: int, frame: int) -> Dictionary:
	var sample: Dictionary = super._frame(game, speed, count, frame)
	for stage in game.combat.profile_usec:
		sample[stage + "_ms"] = game.combat.profile_usec[stage] / 1000.0
	sample.explosions = game.combat.profile_counts.explosions
	sample.aoe_entries = game.combat.profile_counts.aoe_entries
	sample.contact_attempts = game.combat.profile_counts.contacts
	sample.projectile_allocations = game.projectiles._next_id - _before_projectiles
	return sample

func _finish_sample(game: MainGame, sample: Dictionary) -> void:
	super._finish_sample(game, sample)
	sample.balloon_draw_ms = game.balloons.draw_usec / 1000.0
	sample.effect_draw_ms = game.combat.draw_usec / 1000.0
	sample.objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	sample.static_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	sample.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

func _samples() -> Dictionary:
	var result: Dictionary = super._samples()
	for field in EXTRA_FIELDS:
		result[field] = []
	return result

func _accumulate(data: Dictionary, sample: Dictionary) -> void:
	super._accumulate(data, sample)
	for field in EXTRA_FIELDS:
		data[field].append(sample[field])

func _report(game: MainGame, data: Dictionary, mode: String, count: int, speed: int) -> Dictionary:
	var row: Dictionary = super._report(game, data, mode, count, speed)
	for field in EXTRA_FIELDS:
		row[field + "_mean"] = _mean(data[field])
		row[field + "_samples"] = data[field]
	return row
