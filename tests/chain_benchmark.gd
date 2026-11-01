extends "res://tests/boomerang_benchmark.gd"

const FOCUS_BUILDS: Array = [[0, 0, 0], [3, 0, 0], [3, 2, 0], [0, 3, 2], [2, 0, 3]]

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.projectiles.chain_cache_mode = int(_argument("--search-mode", str(game.projectiles.chain_cache_mode)))
	if OS.get_cmdline_user_args().has("--detail"):
		game.projectiles.trace = CombatTrace.new()
		game.combat.trace = game.projectiles.trace
	return game

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	if game.projectiles.trace != null:
		game.projectiles.trace.reset()

func _frame(game: MainGame, speed: int, count: int, frame: int) -> Dictionary:
	var sample: Dictionary = super._frame(game, speed, count, frame)
	if game.projectiles.trace != null:
		sample.detail = game.projectiles.trace.values.duplicate()
	return sample

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	var legacy: Array[Dictionary] = []
	var extra: Array[Dictionary] = []
	var core: bool = OS.get_cmdline_user_args().has("--core")
	var matrix: bool = OS.get_cmdline_user_args().has("--matrix")
	for trial in range(int(_argument("--trials", "2"))):
		for build: Array in ([[3, 2, 0]] if core else (BUILDS if matrix else FOCUS_BUILDS)):
			for count in ([100, 500, 1000] if matrix else [1000]):
				for speed in ([2] if core else [1, 2]):
					var row: Dictionary = await _boomerang_load(build, count, speed)
					row.trial = trial
					rows.append(row)
		if not core:
			for mode in ["bomb_recursive_fast10", "bomb_blitz_mix10"]:
				for speed in [1, 2]:
					var row: Dictionary = await _bomb_load(mode, 1000, speed)
					row.trial = trial
					legacy.append(row)
			for speed in [1, 2]:
				var row: Dictionary = await _mixed_load(speed)
				row.trial = trial
				extra.append(row)
	var label: String = "render" if _render else "cpu"
	var phase: String = _argument("--phase", "after")
	var base: String = "res://benchmarks/%s-%s-%s" % [_argument("--output-prefix", "boomerang-v0131"), phase, label]
	var report: Dictionary = {"version": "v0.13.1", "phase": phase, "rendered": _render, "rows": rows, "legacy_rows": legacy, "extra_rows": extra,
		"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "os": OS.get_name() + OS.get_version(), "gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"source_sha": {"projectiles": FileAccess.get_sha256("res://scripts/systems/projectile_system.gd"), "state": FileAccess.get_sha256("res://scripts/core/projectile_state.gd")},
		"arguments": OS.get_cmdline_user_args(), "conditions": "Inherited v013 exact fixture:10towers x250/400 y220+28row, maintained pink/blue/yellow distance600..620;30warmup+120samples/trial. Focus5builds or full10x3counts. CPU includes maintenance/HUD/instrumentation. Real render frame_post_draw interval,VSyncOFF,1280x720 Compatibility. Mixed8 uses old benchmark placements and320/230/203/032 dart/bomb builds, same dense fixture (distinct from distributed old fixture). Independent trials; no stats/attack/queue changes. Raw per-frame inclusive timers; do not sum. Core flag is320/1000/2x repeatability. Newprefix preserves v013 originals."}
	var file: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["mode", "balloons", "speed", "trial", "mean_ms", "p95_ms", "max_ms", "stddev_ms", "chain_search_ms", "checks", "projectiles_max"]))
	for row in rows + legacy + extra:
		csv.store_csv_line(PackedStringArray([row.mode, str(row.balloons), str(row.speed), str(row.trial), str(row.mean_ms), str(row.p95_ms), str(row.max_ms), str(row.stddev_ms), str(row.chain_search_ms_mean), str(row.checks_mean), str(row.projectiles_max)]))
	csv.close()
	print("CHAIN BENCHMARK COMPLETE: %d new/%d legacy/%d mixed rows %s %s" % [rows.size(), legacy.size(), extra.size(), phase, label])
	quit()

func _samples() -> Dictionary:
	var data: Dictionary = super._samples()
	data.frame_details = []
	return data

func _accumulate(data: Dictionary, sample: Dictionary) -> void:
	super._accumulate(data, sample)
	data.frame_details.append(sample.duplicate(true))

func _report(game: MainGame, data: Dictionary, mode: String, count: int, speed: int) -> Dictionary:
	var row: Dictionary = super._report(game, data, mode, count, speed)
	var variance: float = 0.0
	for value: float in data.wall:
		variance += (value - row.mean_ms) * (value - row.mean_ms)
	row.max_ms = data.wall.max()
	row.stddev_ms = sqrt(variance / data.wall.size())
	row.frame_details = data.frame_details
	return row

func _mixed_load(speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	var positions: Array[Vector2] = [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232), Vector2(704, 440), Vector2(460, 650), Vector2(80, 300), Vector2(460, 180), Vector2(860, 420)]
	var builds: Array = [[3, 2, 0], [2, 3, 0], [2, 0, 3], [0, 3, 2]]
	for index in range(8):
		game.towers.add_tower(positions[index], MainGame.DART if index % 2 == 0 else MainGame.BOMB)
		var tower: TowerState = game.towers.towers.back()
		for path in range(3):
			for tier in range(1, builds[index / 2][path] + 1):
				if not game.try_upgrade(tower, tower.definition.upgrade_at(path, tier)):
					push_error("Mixed load purchase failed")
	game.select_instance(game.towers.towers[0])
	_serial = 0
	var data: Dictionary = _samples()
	var previous: int = Time.get_ticks_usec()
	for frame in range(150):
		_reset_frame(game)
		if _render:
			await process_frame
		var sample: Dictionary = _frame(game, speed, 1000, frame)
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		sample.wall = float(now - previous) / 1000.0 if _render else sample.cpu
		previous = now
		_finish_sample(game, sample)
		if frame >= 30:
			_accumulate(data, sample)
	var row: Dictionary = _report(game, data, "dart_bomb_mixed8", 1000, speed)
	game.free()
	return row
