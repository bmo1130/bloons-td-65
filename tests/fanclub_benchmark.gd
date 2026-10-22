extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const TYPES: Array = [preload("res://data/balloons/pink.tres"), preload("res://data/balloons/black.tres"), preload("res://data/balloons/lead.tres")]
var _render: bool = false
var _hide_panel: bool = false
var _serial: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	_hide_panel = OS.get_cmdline_user_args().has("--hide-panel")
	if _render:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for active in [false, true]:
		for count in [100, 500, 1000]:
			for speed in [1, 2]:
				if _hide_panel and (count != 1000 or speed != 2):
					continue
				rows.append(await _measure(count, speed, active))
	var version: String = "v08" if OS.get_cmdline_user_args().has("--v08") else "v07"
	if OS.get_cmdline_user_args().has("--v09"):
		version = "v09"
	var report: Dictionary = {"version": "v0.8" if version == "v08" else "v0.7", "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"os": OS.get_name() + " " + OS.get_version(), "display": DisplayServer.get_name(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"rendered": _render, "upgrade_panel_visible": not _hide_panel, "statistics_enabled": true, "fixed_step": MainGame.FIXED_STEP,
		"conditions": "10 clustered darts: 1x240 + 9x220; same locations/builds OFF vs transformed ON; pink/black/lead steady population around route distance 600; 30 warmup + 120 measured frames, 1x/2x fixed steps; includes deterministic population maintenance, spatial profiling, full HUD; post-draw wall times for render, CPU wall otherwise; activation lasts beyond sampling; no normal campaign or prices modified",
		"rows": rows}
	var base: String = "res://benchmarks/fanclub-" + version + ("-render" if _render else "-cpu")
	if version == "v09":
		report.version = "v0.9"
	if OS.get_cmdline_user_args().has("--v010"):
		report.version = "v0.10"
		base = base.replace(version, "v010")
	if OS.get_cmdline_user_args().has("--v011"):
		report.version = "v0.11"
		base = base.replace(version, "v011")
	if _hide_panel:
		base += "-uihidden"
	var output: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["active", "balloons", "speed", "mean_ms", "p95_ms", "cpu_mean_ms", "projectiles_mean", "projectiles_max", "collision_checks_mean", "grid_candidates_mean", "grid_ms_mean"]))
	for row in rows:
		csv.store_csv_line(PackedStringArray([str(row.active), str(row.balloons), str(row.speed), str(row.mean_ms), str(row.p95_ms), str(row.cpu_mean_ms), str(row.projectiles_mean), str(row.projectiles_max), str(row.collision_checks_mean), str(row.grid_candidates_mean), str(row.grid_ms_mean)]))
	csv.close()
	print("FANCLUB BENCHMARK COMPLETE: %d cases, renderer=%s" % [rows.size(), _render])
	quit()

func _measure(count: int, speed: int, active: bool) -> Dictionary:
	var game: MainGame = MAIN.instantiate() as MainGame
	root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	game.profile_simulation = true
	game.balloons.profile_spatial = true
	for index in range(10):
		var at: Vector2 = Vector2(250 + (index % 2) * 150, 220 + (index / 2) * 40)
		game.towers.add_tower(at, MainGame.DART)
		var tower: TowerState = game.towers.towers.back()
		var build: Array = [2, 4, 0] if index == 0 else [2, 2, 0]
		for path in range(3):
			for tier in range(1, build[path] + 1):
				game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	if active:
		game.abilities.update(17.0)
		game.abilities.activate(game.towers.towers[0])
	game.select_instance(game.towers.towers[0])
	if _hide_panel:
		game.hud.upgrade_panel.visible = false
	_serial = 0
	var samples: Array[float] = []
	var cpu_samples: Array[float] = []
	var sums: Dictionary = {"projectiles": 0.0, "checks": 0.0, "candidates": 0.0, "grid_usec": 0.0, "movement_usec": 0.0, "projectile_combat_usec": 0.0, "spawn_towers_usec": 0.0}
	var maximum: int = 0
	var previous: int = Time.get_ticks_usec()
	for frame in range(150):
		if _render:
			await process_frame
		game.balloons.reset_spatial_metrics()
		var started: int = Time.get_ticks_usec()
		var frame_checks: int = 0
		var stages: Dictionary = {"movement_usec": 0.0, "projectile_combat_usec": 0.0, "spawn_towers_usec": 0.0}
		for step in range(speed):
			_maintain(game, count)
			game.simulation_step(MainGame.FIXED_STEP)
			frame_checks += game.projectiles.collision_checks
			for key: String in stages:
				stages[key] += game.step_metrics[key]
			_maintain(game, count)
		var cpu: float = float(Time.get_ticks_usec() - started) / 1000.0
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var wall: float = float(now - previous) / 1000.0 if _render else cpu
		previous = now
		if frame < 30:
			continue
		if active and game.abilities.transformations.size() != 10:
			push_error("Benchmark transformation expired or setup invalid")
			quit(1)
			return {}
		samples.append(wall)
		cpu_samples.append(cpu)
		maximum = maxi(maximum, game.projectiles.projectiles.size())
		sums.projectiles += game.projectiles.projectiles.size()
		sums.checks += frame_checks
		var metrics: Dictionary = game.balloons.spatial_metrics()
		sums.candidates += metrics.candidates
		sums.grid_usec += metrics.build_usec + metrics.query_usec
		for key: String in stages:
			sums[key] += stages[key]
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var row: Dictionary = {"active": active, "balloons": count, "speed": speed,
		"mean_ms": _mean(samples), "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"cpu_mean_ms": _mean(cpu_samples), "projectiles_mean": sums.projectiles / samples.size(),
		"projectiles_max": maximum, "collision_checks_mean": sums.checks / samples.size(),
		"grid_candidates_mean": sums.candidates / samples.size(), "grid_ms_mean": sums.grid_usec / samples.size() / 1000.0,
		"movement_ms_mean": sums.movement_usec / samples.size() / 1000.0,
		"projectile_combat_ms_mean": sums.projectile_combat_usec / samples.size() / 1000.0,
		"spawn_towers_ms_mean": sums.spawn_towers_usec / samples.size() / 1000.0, "samples_ms": samples}
	print("FANCLUB BENCH: active=%s N=%d speed=%d mean=%.3f p95=%.3f CPU=%.3f shots=%.1f candidates=%.1f" % [active, count, speed, row.mean_ms, row.p95_ms, row.cpu_mean_ms, row.projectiles_mean, row.grid_candidates_mean])
	game.free()
	return row

func _mean(values: Array[float]) -> float:
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum / values.size()

func _maintain(game: MainGame, count: int) -> void:
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		game.balloons.spawn(TYPES[_serial % TYPES.size()], 600.0 + (_serial % 41) * 0.5)
		_serial += 1
