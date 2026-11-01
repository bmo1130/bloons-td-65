extends "res://tests/bomb_stability_benchmark.gd"

const FLIGHT_FIELDS: Array[String] = ["chain_search_ms", "segments", "projectile_draw_ms"]
const BUILDS: Array = [[0, 0, 0], [3, 0, 0], [0, 3, 0], [0, 0, 3], [3, 2, 0], [3, 0, 2], [2, 3, 0], [0, 3, 2], [2, 0, 3], [0, 2, 3]]

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	var legacy: Array[Dictionary] = []
	for trial in range(int(_argument("--trials", "2"))):
		for build: Array in BUILDS:
			var mode: String = "%d%d%d" % build
			if _argument("--mode", mode) != mode:
				continue
			for count in [100, 500, 1000]:
				for speed in [1, 2]:
					var row: Dictionary = await _boomerang_load(build, count, speed)
					row.trial = trial
					rows.append(row)
		if not OS.get_cmdline_user_args().has("--quick"):
			for mode in ["bomb_recursive_fast10", "bomb_blitz_mix10"]:
				for speed in [1, 2]:
					var row: Dictionary = await _bomb_load(mode, 1000, speed)
					row.trial = trial
					legacy.append(row)
	var label: String = "render" if _render else "cpu"
	var report: Dictionary = {"version": "v0.13", "rendered": _render, "rows": rows, "legacy_rows": legacy,
		"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"arguments": OS.get_cmdline_user_args(), "source_sha": {"projectiles": FileAccess.get_sha256("res://scripts/systems/projectile_system.gd"), "state": FileAccess.get_sha256("res://scripts/core/projectile_state.gd"), "towers": FileAccess.get_sha256("res://scripts/systems/tower_system.gd")},
		"conditions": "10 towers at x250/400,y220+28*row; maintained pink/blue/yellow at route600..620. Load fixture only, unrestricted budget/placement.000/300/030/003 and all6crosspaths,100/500/1000,1/2fixed60Hz steps/frame.30warmup+120samples,2trials; pool240samples/case for mean/nearestP95. Actual rendering includes frame_post_draw; CPU includes population maintenance/HUD/instrumentation.64-piece authored curved path; chain physically targets one ID at a time, nearest search via same spatial grid; Kylie0.3s time policy. No collision skipping. Trail is bounded12 positions. Nested timers overlap; do not sum. Legacy024 and one025+nine024 use original v012 fixture and global tier5 policy. Stress speed runs different game durations, not an equal-time speed proof; tests separately compare20game seconds."}
	var base: String = "res://benchmarks/" + _argument("--output-prefix", "boomerang-v013") + "-" + label
	if OS.get_cmdline_user_args().has("--quick"):
		base += "-quick"
	if OS.get_cmdline_user_args().has("--unfiltered-flight"):
		base += "-unfiltered"
	var file: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "balloons", "speed", "trial", "mean_ms", "p95_ms", "cpu_mean_ms", "projectiles_max", "trajectory_ms", "candidates_ms", "narrow_ms", "resolution_ms", "creation_ms", "grid_ms", "chain_search_ms_mean", "segments_mean", "projectile_draw_ms_mean", "balloon_draw_ms_mean", "draw_calls_mean"]
	csv.store_csv_line(keys)
	for row in rows + legacy:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, "NA")))
		csv.store_csv_line(values)
	csv.close()
	print("BOOMERANG BENCHMARK COMPLETE: %d new / %d legacy cases %s" % [rows.size(), legacy.size(), label])
	quit()

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.projectiles.flight_broadphase_enabled = not OS.get_cmdline_user_args().has("--unfiltered-flight")
	return game

func _boomerang_load(build: Array, count: int, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	for index in range(10):
		game.towers.add_tower(Vector2(250 + index % 2 * 150, 220 + (index / 2) * 28), MainGame.BOOMERANG)
		var tower: TowerState = game.towers.towers.back()
		for path in range(3):
			for tier in range(1, build[path] + 1):
				if not game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(path, tier)):
					push_error("Boomerang benchmark real purchase failed")
					quit(1)
	game.select_instance(game.towers.towers[0])
	_serial = 0
	var data: Dictionary = _samples()
	var previous: int = Time.get_ticks_usec()
	for frame in range(150):
		_reset_frame(game)
		if _render:
			await process_frame
		var sample: Dictionary = _frame(game, speed, count, frame)
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		sample.wall = float(now - previous) / 1000.0 if _render else sample.cpu
		previous = now
		_finish_sample(game, sample)
		if frame >= 30:
			_accumulate(data, sample)
	var row: Dictionary = _report(game, data, "boomerang_%d%d%d" % build, count, speed)
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	row.fingerprint.append(live)
	var flights: Array = []
	for shot in game.projectiles.projectiles:
		flights.append([shot.id, shot.position.x, shot.position.y, shot.age, shot.lifetime, shot.remaining_pierce, shot.flight_index, shot.target_id, shot.hit_times.duplicate()])
	row.fingerprint.append(flights)
	game.free()
	return row

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	game.projectiles.chain_search_total_usec = 0
	game.projectiles.trajectory_segments_total = 0

func _frame(game: MainGame, speed: int, count: int, frame: int) -> Dictionary:
	var sample: Dictionary = super._frame(game, speed, count, frame)
	sample.chain_search_ms = game.projectiles.chain_search_total_usec / 1000.0
	sample.segments = game.projectiles.trajectory_segments_total
	return sample

func _finish_sample(game: MainGame, sample: Dictionary) -> void:
	super._finish_sample(game, sample)
	sample.projectile_draw_ms = game.projectiles.draw_usec / 1000.0

func _samples() -> Dictionary:
	var data: Dictionary = super._samples()
	for field in FLIGHT_FIELDS:
		data[field] = []
	return data

func _accumulate(data: Dictionary, sample: Dictionary) -> void:
	super._accumulate(data, sample)
	for field in FLIGHT_FIELDS:
		data[field].append(sample[field])

func _report(game: MainGame, data: Dictionary, mode: String, count: int, speed: int) -> Dictionary:
	var row: Dictionary = super._report(game, data, mode, count, speed)
	for field in FLIGHT_FIELDS:
		row[field + "_mean"] = _mean(data[field])
		row[field + "_samples"] = data[field]
	return row
