extends SceneTree

# Fixed inputs, finite sampling, real attacks. Population replacement is a load
# fixture, not campaign behavior. Stage timers are optional and inclusive.
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const TYPES: Array = [preload("res://data/balloons/pink.tres"), preload("res://data/balloons/black.tres"), preload("res://data/balloons/lead.tres")]
const STAGES: Array[String] = ["movement", "tower", "spawn_towers", "projectile_combat", "finalize", "trajectory", "candidates", "narrow", "resolution", "creation", "removal", "sort", "grid", "ui", "draw_commands"]
var _render: bool = false
var _uncached: bool = false
var _unbatched: bool = false
var _serial: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	_uncached = OS.get_cmdline_user_args().has("--uncached-ui")
	_unbatched = OS.get_cmdline_user_args().has("--unbatched-ui")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for speed in [1, 2]:
		if not _uncached:
			rows.append(await _campaign(speed))
	for mode in ["plasma5", "plasma20", "ultra", "legacy10"]:
		if OS.get_cmdline_user_args().has("--campaign-only"):
			continue
		for count in [100, 500, 1000]:
			for speed in [1, 2]:
				# Paired expensive-UI control; same attacks and RNG-free fixture.
				if _uncached and (mode != "legacy10" or count != 1000):
					continue
				rows.append(await _load_case(mode, count, speed))
	var report: Dictionary = {"version": "v0.8", "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"os": OS.get_name() + " " + OS.get_version(), "display": DisplayServer.get_name(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"rendered": _render, "cached_previews": not _uncached, "fixed_step": MainGame.FIXED_STEP,
		"batched_combat_ui": not (_uncached or _unbatched),
		"conditions": "30 warmup + 120 measured frames, speed fixed steps/frame, full selected-tower HUD, refresh every 6 frames plus real gold signals (batched when optimized). Dense pink/black/lead at distance 600..620, steady count maintained inside CPU timing. Plasma 5/20 = 1x250 plus 4/19x220. Ultra = 1x520 with bumper. Legacy10 = 1x240 plus 9x220. Normal CPU = full 20-wave mixed shopping strategy, active-wave frames only, fixed 90s/wave; normal render = wave20 checkpoint after first19 waves simulated, 450 steps warmup then120 frames. UI stage measures upgrade-panel refresh only; full CPU includes gold/life label updates. Draw commands measures balloon/tower/projectile GDScript submission only; wall minus CPU includes renderer/driver/OS scheduling, not isolated GPU time. Nested stage timings must not be summed.",
		"rows": rows}
	var base: String = "res://benchmarks/tier5-v08" + ("-render" if _render else "-cpu") + ("-uncached" if _uncached else "")
	if OS.get_cmdline_user_args().has("--v09"):
		report.version = "v0.9"
		base = base.replace("v08", "v09")
	if OS.get_cmdline_user_args().has("--v010"):
		report.version = "v0.10"
		base = base.replace("v08", "v010")
	if OS.get_cmdline_user_args().has("--v011"):
		report.version = "v0.11"
		base = base.replace("v08", "v011")
	if _unbatched:
		base += "-prebatch"
	var file: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "balloons", "speed", "mean_ms", "p95_ms", "cpu_mean_ms", "projectiles_mean", "projectiles_max", "checks_mean", "candidates_mean"]
	for stage in STAGES:
		keys.append(stage + "_ms")
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, 0)))
		csv.store_csv_line(values)
	csv.close()
	print("TIER5 BENCHMARK COMPLETE: %d cases, render=%s cached=%s" % [rows.size(), _render, not _uncached])
	quit()

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	root.add_child(game)
	game.set_process(false)
	game.profile_simulation = true
	game.balloons.profile_spatial = true
	game.balloons.profile_draw = true
	game.projectiles.profile_updates = true
	game.hud.upgrade_panel.profile_updates = true
	game.hud.upgrade_panel.cache_previews = not _uncached
	game.hud.batch_combat_updates = not (_uncached or _unbatched)
	game.hud.upgrade_panel.set_process(false)
	game.hud.stats_panel.set_process(false)
	return game

func _build(game: MainGame, index: int, build: Array) -> TowerState:
	game.towers.add_tower(Vector2(250 + index % 2 * 150, 220 + (index / 2) * 28), MainGame.DART)
	var tower: TowerState = game.towers.towers.back()
	for path in range(3):
		for tier in range(1, build[path] + 1):
			if not game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier)):
				push_error("Benchmark purchase failed")
				quit(1)
	return tower

func _load_case(mode: String, count: int, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	var leader: TowerState
	if mode == "ultra":
		leader = _build(game, 0, [5, 2, 0])
		game.projectiles.ricochet_obstacles = [Rect2(450, 260, 20, 160)]
	else:
		var n: int = 5 if mode == "plasma5" else (20 if mode == "plasma20" else 10)
		for index in range(n):
			var tower: TowerState = _build(game, index, [2, 4 if mode == "legacy10" else 5, 0] if index == 0 else [2, 2, 0])
			if index == 0:
				leader = tower
		game.abilities.update(17.0)
		if not game.abilities.activate(leader):
			push_error("Benchmark activation failed")
			quit(1)
	game.select_instance(leader)
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
	var row: Dictionary = _report(game, data, mode, count, speed)
	game.free()
	return row

func _campaign(speed: int) -> Dictionary:
	var game: MainGame = _game()
	var scenarios: RefCounted = preload("res://tests/scenarios/balance_scenarios.gd").new()
	var data: Dictionary = _samples()
	for number in range(1, 21):
		scenarios.shop(game, "mixed", number)
		game.select_instance(game.towers.towers[0])
		game.start_next_wave()
		for frame in range(90 * 60 / speed):
			var active: bool = game.waves.active
			_reset_frame(game)
			var sample: Dictionary = _frame(game, speed, 0, frame)
			_finish_sample(game, sample)
			sample.wall = sample.cpu
			if active and not _render:
				_accumulate(data, sample)
			if game.result != &"":
				break
			if _render and number == 20 and frame == 450 / speed:
				var previous: int = Time.get_ticks_usec()
				for rendered_frame in range(120):
					_reset_frame(game)
					await process_frame
					sample = _frame(game, speed, 0, rendered_frame)
					await RenderingServer.frame_post_draw
					var now: int = Time.get_ticks_usec()
					sample.wall = float(now - previous) / 1000.0
					previous = now
					_finish_sample(game, sample)
					_accumulate(data, sample)
				var rendered: Dictionary = _report(game, data, "normal20_checkpoint", game.balloons.balloons.size(), speed)
				game.free()
				return rendered
	var row: Dictionary = _report(game, data, "normal20_campaign", 0, speed)
	if game.result != &"victory" or game.economy.lives != 50 or game.economy.gold != 3423 or game.battle_stats.total_pops != 10338:
		push_error("Normal campaign regression changed: " + str(row.fingerprint))
		quit(1)
	game.free()
	return row

func _reset_frame(game: MainGame) -> void:
	game.balloons.reset_spatial_metrics()
	game.hud.upgrade_panel.refresh_usec = 0
	game.projectiles.draw_usec = 0
	game.towers.draw_usec = 0
	game.balloons.draw_usec = 0

func _frame(game: MainGame, speed: int, count: int, frame: int) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var sample: Dictionary = {"checks": 0, "cpu": 0.0}
	for stage in STAGES:
		sample[stage] = 0.0
	for step in range(speed):
		if count > 0:
			_maintain(game, count)
		game.simulation_step(MainGame.FIXED_STEP)
		sample.checks += game.projectiles.collision_checks
		for stage in ["movement", "tower", "spawn_towers", "projectile_combat", "finalize"]:
			sample[stage] += float(game.step_metrics.get(stage + "_usec", 0)) / 1000.0
		for stage in game.projectiles.profile_usec:
			sample[stage] += float(game.projectiles.profile_usec[stage]) / 1000.0
		if count > 0:
			_maintain(game, count)
	if frame % 6 == 0:
		game.hud.upgrade_panel.refresh()
		game.hud.stats_panel.refresh()
	sample.cpu = float(Time.get_ticks_usec() - started) / 1000.0
	return sample

func _finish_sample(game: MainGame, sample: Dictionary) -> void:
	var grid: Dictionary = game.balloons.spatial_metrics()
	sample.candidates_count = grid.candidates
	sample.grid = float(grid.build_usec + grid.query_usec) / 1000.0
	sample.ui = float(game.hud.upgrade_panel.refresh_usec) / 1000.0
	sample.draw_commands = float(game.projectiles.draw_usec + game.towers.draw_usec + game.balloons.draw_usec) / 1000.0
	sample.projectiles = game.projectiles.projectiles.size()
	sample.balloons = game.balloons.balloons.size()

func _samples() -> Dictionary:
	var data: Dictionary = {"wall": [], "cpu": [], "checks": 0.0, "candidates": 0.0, "projectiles": 0.0, "projectiles_max": 0, "balloons_max": 0}
	for stage in STAGES:
		data[stage + "_total"] = 0.0
	return data

func _accumulate(data: Dictionary, sample: Dictionary) -> void:
	data.wall.append(sample.wall)
	data.cpu.append(sample.cpu)
	data.checks += sample.checks
	data.candidates += sample.candidates_count
	data.projectiles += sample.projectiles
	data.projectiles_max = maxi(data.projectiles_max, sample.projectiles)
	data.balloons_max = maxi(data.balloons_max, sample.balloons)
	for stage in STAGES:
		data[stage + "_total"] += sample[stage]

func _report(game: MainGame, data: Dictionary, mode: String, count: int, speed: int) -> Dictionary:
	var n: int = data.wall.size()
	var sorted: Array = data.wall.duplicate()
	sorted.sort()
	var stats: Array = []
	for tower: TowerState in game.towers.towers:
		stats.append(tower.combat_stats.snapshot())
	var row: Dictionary = {"mode": mode, "balloons": count, "speed": speed, "samples": n,
		"mean_ms": _mean(data.wall), "p95_ms": sorted[ceili(n * 0.95) - 1], "cpu_mean_ms": _mean(data.cpu),
		"projectiles_mean": data.projectiles / n, "projectiles_max": data.projectiles_max, "balloons_max": data.balloons_max,
		"checks_mean": data.checks / n, "candidates_mean": data.candidates / n,
		"fingerprint": [str(game.result), game.economy.gold, game.economy.lives, game.battle_stats.total_pops, game.projectiles._next_id - 1, game.balloons.latest_id(), stats], "samples_ms": data.wall}
	for stage in STAGES:
		row[stage + "_ms"] = data[stage + "_total"] / n
	print("TIER5 BENCH: %s N=%d x%d mean=%.3f p95=%.3f CPU=%.3f shots=%.1f UI=%.3f" % [mode, count, speed, row.mean_ms, row.p95_ms, row.cpu_mean_ms, row.projectiles_mean, row.ui_ms])
	return row

func _mean(values: Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()

func _maintain(game: MainGame, count: int) -> void:
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		game.balloons.spawn(TYPES[_serial % TYPES.size()], 600.0 + (_serial % 41) * 0.5)
		_serial += 1
