extends SceneTree

# CPU simulation benchmark, deliberately separate from normal play and tests.
# One measured frame = speed fixed steps + deterministic population maintenance.
const MAIN: PackedScene = preload("res://scenes/main.tscn")
const WARMUP_FRAMES: int = 90
const SAMPLE_FRAMES: int = 240
const TRIALS: int = 2
const TYPES: Array[BalloonDefinition] = [preload("res://data/balloons/red.tres"),
	preload("res://data/balloons/blue.tres"), preload("res://data/balloons/green.tres"),
	preload("res://data/balloons/yellow.tres"), preload("res://data/balloons/pink.tres"),
	preload("res://data/balloons/black.tres"), preload("res://data/balloons/lead.tres")]
var _serial: int = 0
var _upgraded: bool = false
var _crosspath: bool = false
var _statistics_enabled: bool = true
var _concentrated: bool = false
const SINGLE_BUILDS: Array = [[3, 0, 0], [0, 3, 0], [0, 0, 3], [0, 3, 0]]
const CROSS_BUILDS: Array = [[3, 2, 0], [2, 3, 0], [2, 0, 3], [0, 3, 2]]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_crosspath = OS.get_cmdline_user_args().has("--crosspath")
	_upgraded = _crosspath or OS.get_cmdline_user_args().has("--upgraded")
	_statistics_enabled = not OS.get_cmdline_user_args().has("--stats-off")
	_concentrated = OS.get_cmdline_user_args().has("--concentrated")
	var mode: String = "crosspath" if _crosspath else ("single" if _upgraded else "base")
	var rows: Array[Dictionary] = []
	for count in [100, 500, 1000]:
		for speed in [1, 2]:
			var row: Dictionary = _measure(count, speed)
			rows.append(row)
			print("BENCH: N=%d speed=%d avg=%.3fms p95=%.3fms shots=%.1f candidates=%.1f grid=%.3fms" % [
				count, speed, row.mean_ms, row.p95_ms, row.mean_projectiles,
				row.mean_grid_candidates, row.mean_grid_build_ms + row.mean_grid_query_ms])
	var report: Dictionary = {
		"version": "v0.8" if OS.get_cmdline_user_args().has("--v08") else ("v0.7" if OS.get_cmdline_user_args().has("--v07") else "v0.6"), "mode": mode, "upgraded": _upgraded, "statistics_enabled": _statistics_enabled,
		"concentrated": _concentrated, "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"os": OS.get_name() + " " + OS.get_version(), "display": DisplayServer.get_name(),
		"debug_build": OS.is_debug_build(), "utc": Time.get_datetime_string_from_system(true),
		"warmup_frames_per_trial": WARMUP_FRAMES, "samples_per_trial": SAMPLE_FRAMES,
		"trials": TRIALS, "fixed_step": MainGame.FIXED_STEP,
		"workload": "8 towers (4 dart/4 bomb), 7-color steady population, deterministic route distribution; CPU simulation only, no rendering/UI/VSync/frame pacing; maintenance and enabled spatial timers included",
		"dart_upgrade_paths": CROSS_BUILDS if _crosspath else (SINGLE_BUILDS if _upgraded else [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]),
		"rows": rows,
	}
	var directory: String = ProjectSettings.globalize_path("res://benchmarks")
	if OS.get_cmdline_user_args().has("--v09"):
		report.version = "v0.9"
	DirAccess.make_dir_recursive_absolute(directory)
	var prefix: String = "results-v08-" if OS.get_cmdline_user_args().has("--v08") else ("results-v07-" if OS.get_cmdline_user_args().has("--v07") else "results-v06-")
	if OS.get_cmdline_user_args().has("--v09"):
		prefix = "results-v09-"
	var basename: String = prefix + mode + ("-cluster" if _concentrated else "") + ("-on" if _statistics_enabled else "-off")
	var output: FileAccess = FileAccess.open(directory.path_join(basename + ".json"), FileAccess.WRITE)
	if output == null:
		push_error("Could not write benchmark results")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(directory.path_join(basename + ".csv"), FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["balloons", "speed", "mean_ms", "p95_ms", "mean_projectiles", "max_projectiles", "mean_narrow_checks", "mean_aoe_candidates", "mean_grid_candidates", "mean_grid_build_ms", "mean_grid_query_ms", "mean_grid_queries", "peak_balloons_before_maintenance", "mean_spawn_towers_ms", "mean_movement_ms", "mean_projectile_combat_ms", "mean_finalize_ms", "mean_maintenance_ms"]))
	for row in rows:
		csv.store_csv_line(PackedStringArray([str(row.balloons), str(row.speed), str(row.mean_ms), str(row.p95_ms), str(row.mean_projectiles), str(row.max_projectiles), str(row.mean_narrow_checks), str(row.mean_aoe_candidates), str(row.mean_grid_candidates), str(row.mean_grid_build_ms), str(row.mean_grid_query_ms), str(row.mean_grid_queries), str(row.peak_balloons_before_maintenance), str(row.mean_spawn_towers_ms), str(row.mean_movement_ms), str(row.mean_projectile_combat_ms), str(row.mean_finalize_ms), str(row.mean_maintenance_ms)]))
	csv.close()
	print("BENCHMARK COMPLETE: %d cases, %d samples/case" % [rows.size(), SAMPLE_FRAMES * TRIALS])
	quit()

func _measure(count: int, speed: int) -> Dictionary:
	var durations: Array[float] = []
	var projectile_sum: float = 0.0
	var projectile_max: int = 0
	var peak_balloons: int = count
	var narrow_sum: int = 0
	var aoe_sum: int = 0
	var build_sum: int = 0
	var query_sum: int = 0
	var query_count: int = 0
	var candidate_sum: int = 0
	var stage_totals: Dictionary = {"spawn_towers_usec": 0, "movement_usec": 0, "projectile_combat_usec": 0, "finalize_usec": 0}
	var maintenance_sum: int = 0
	for trial in range(TRIALS):
		_serial = 0
		var game: MainGame = MAIN.instantiate() as MainGame
		root.add_child(game)
		game.set_process(false)
		game.battle_stats.enabled = _statistics_enabled
		game.economy.starting_lives = 1000000000
		game.economy.reset()
		var positions: Array[Vector2] = [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232), Vector2(704, 440),
			Vector2(460, 650), Vector2(80, 300), Vector2(460, 180), Vector2(860, 420)]
		for index in range(positions.size()):
			game.towers.add_tower(positions[index], MainGame.DART if index % 2 == 0 else MainGame.BOMB)
		if _upgraded:
			game.economy.earn(10000) # Fixture budget, excluded from timing.
			var builds: Array = CROSS_BUILDS if _crosspath else SINGLE_BUILDS
			for index in range(4):
				var tower: TowerState = game.towers.towers[index * 2]
				for path in range(3):
					for tier in range(1, builds[index][path] + 1):
						if not game.try_upgrade(tower, tower.definition.upgrade_at(path, tier)):
							push_error("Benchmark upgrade setup failed")
							quit(1)
							return {}
		_maintain_population(game, count)
		for frame in range(WARMUP_FRAMES):
			for step in range(speed):
				game.simulation_step(MainGame.FIXED_STEP)
				_maintain_population(game, count)
		game.balloons.profile_spatial = true
		game.profile_simulation = true
		for frame in range(SAMPLE_FRAMES):
			game.balloons.reset_spatial_metrics()
			var started: int = Time.get_ticks_usec()
			for step in range(speed):
				game.simulation_step(MainGame.FIXED_STEP)
				for key: String in stage_totals:
					stage_totals[key] += game.step_metrics[key]
				narrow_sum += game.projectiles.collision_checks
				aoe_sum += game.combat.aoe_candidates
				peak_balloons = maxi(peak_balloons, game.balloons.balloons.size())
				var maintenance_started: int = Time.get_ticks_usec()
				_maintain_population(game, count)
				maintenance_sum += Time.get_ticks_usec() - maintenance_started
			durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
			var metrics: Dictionary = game.balloons.spatial_metrics()
			build_sum += metrics.build_usec
			query_sum += metrics.query_usec
			query_count += metrics.queries
			candidate_sum += metrics.candidates
			projectile_sum += game.projectiles.projectiles.size()
			projectile_max = maxi(projectile_max, game.projectiles.projectiles.size())
		game.free()
	var total_ms: float = 0.0
	for duration in durations:
		total_ms += duration
	var samples: int = durations.size()
	var raw_samples: Array[float] = durations.duplicate()
	durations.sort()
	return {"balloons": count, "speed": speed, "mean_ms": total_ms / samples,
		"p95_ms": durations[ceili(samples * 0.95) - 1], "mean_projectiles": projectile_sum / samples,
		"max_projectiles": projectile_max, "mean_narrow_checks": float(narrow_sum) / samples,
		"mean_aoe_candidates": float(aoe_sum) / samples, "mean_grid_candidates": float(candidate_sum) / samples,
		"mean_grid_build_ms": float(build_sum) / samples / 1000.0,
		"mean_grid_query_ms": float(query_sum) / samples / 1000.0,
		"mean_grid_queries": float(query_count) / samples,
		"peak_balloons_before_maintenance": peak_balloons, "frame_ms_samples": raw_samples,
		"mean_spawn_towers_ms": float(stage_totals.spawn_towers_usec) / samples / 1000.0,
		"mean_movement_ms": float(stage_totals.movement_usec) / samples / 1000.0,
		"mean_projectile_combat_ms": float(stage_totals.projectile_combat_usec) / samples / 1000.0,
		"mean_finalize_ms": float(stage_totals.finalize_usec) / samples / 1000.0,
		"mean_maintenance_ms": float(maintenance_sum) / samples / 1000.0}

func _maintain_population(game: MainGame, count: int) -> void:
	# Keep all requested active population levels for the entire timed run.
	# Removed excess children are benchmark bookkeeping, not combat rewards.
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		var distance: float = 800.0 + (_serial % 41) * 0.25 if _concentrated else fposmod(_serial * 37.0 + (_serial % 7) * 19.0, game.route.total_length - 80.0)
		game.balloons.spawn(TYPES[_serial % TYPES.size()], distance)
		_serial += 1
