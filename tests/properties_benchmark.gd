extends SceneTree

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const CERAMIC: BalloonDefinition = preload("res://data/balloons/ceramic.tres")
var _render: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for pair: Array in [[10, false], [100, false], [100, true]]:
		rows.append(await _burst(pair[0], pair[1]))
	for speed in [1, 2]:
		rows.append(await _ultra(speed))
	var report: Dictionary = {"version": "v0.9", "engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"os": OS.get_name() + " " + OS.get_version(), "logical_processors": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless", "rendered": _render,
		"conditions": "Separate repeatable fixtures, full selected-tower HUD, debug editor engine. Burst: 20 fresh trials; Normal damage10 (all normal shells at full HP) or mixed camo/armor shells pre-damaged to1 outside timing then Normal damage1; radius1000/pierce=count AoE, detects camo, frozen initial membership. Measures actual common resolver, no child attack same batch. Ultra: 1x502, 100 ceramic instances at route distance500..649 with alternating camo/armor, 120 frames, speed1/2 fixed steps; no replacements. All creation timings nested inside total CPU. Post-draw intervals for render include renderer/driver/OS, not isolated GPU.", "rows": rows}
	var base: String = "res://benchmarks/properties-v09" + ("-render" if _render else "-cpu")
	if OS.get_cmdline_user_args().has("--v010"):
		report.version = "v0.10"
		base = base.replace("v09", "v010")
	if OS.get_cmdline_user_args().has("--v011"):
		report.version = "v0.11"
		base = base.replace("v09", "v011")
	var output: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["case", "count", "speed", "mean_ms", "p95_ms", "cpu_ms", "creation_ms", "created", "peak_active", "grid_ms", "narrow_ms", "resolution_ms", "candidates", "split_projectiles", "pops", "damage"]
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, 0)))
		csv.store_csv_line(values)
	csv.close()
	print("PROPERTIES BENCHMARK COMPLETE: %d cases render=%s" % [rows.size(), _render])
	quit()

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	game.profile_simulation = true
	game.balloons.profile_spatial = true
	game.balloons.profile_changes = true
	game.projectiles.profile_updates = true
	game.towers.add_tower(Vector2(250, 350), MainGame.DART)
	game.select_instance(game.towers.towers[0])
	return game

func _burst(count: int, mixed: bool) -> Dictionary:
	var walls: Array[float] = []
	var cpus: Array[float] = []
	var creation: float = 0.0
	var grid: float = 0.0
	var created: int = 0
	var alive: int = 0
	var fingerprint: Array = []
	for trial in range(20):
		var game: MainGame = _game()
		var tower: TowerState = game.towers.towers[0]
		var hit: AttackSpec = AttackSpec.new(1 if mixed else 10, count, AttackSpec.Attribute.NORMAL, 1000)
		hit.detects_camo = true
		hit.source_id = tower.id
		for index in range(count):
			var target: BalloonState = game.balloons.spawn(CERAMIC, 500 + index * 0.1, mixed and index % 2 == 0, mixed and index % 3 == 0)
			if mixed:
				var setup: AttackSpec = AttackSpec.new(target.shell_max_hp - 1, 1, AttackSpec.Attribute.NORMAL)
				setup.detects_camo = true
				game.combat.apply_hit(target.id, setup)
		if _render:
			await process_frame
			await RenderingServer.frame_post_draw
		game.balloons.reset_spatial_metrics()
		game.balloons.spawn_usec = 0
		game.balloons.spawn_count = 0
		var previous: int = Time.get_ticks_usec()
		if _render:
			await process_frame
		var started: int = Time.get_ticks_usec()
		game.hud.begin_combat_update()
		var hits: Array[int] = game.combat.explode(game.route.position_at(500), hit, 1.0, game.balloons.latest_id())
		game.hud.end_combat_update()
		var cpu: float = float(Time.get_ticks_usec() - started) / 1000.0
		if _render:
			await RenderingServer.frame_post_draw
		walls.append(float(Time.get_ticks_usec() - previous) / 1000.0 if _render else cpu)
		cpus.append(cpu)
		creation += float(game.balloons.spawn_usec) / 1000.0
		var spatial: Dictionary = game.balloons.spatial_metrics()
		grid += float(spatial.build_usec + spatial.query_usec) / 1000.0
		created = game.balloons.spawn_count
		alive = game.balloons.balloons.size()
		fingerprint = [game.economy.total_earned, game.battle_stats.total_pops, tower.combat_stats.effective_damage, hits.size(), alive]
		if created != count * 2 or alive != count * 2 or hits.size() != count or game.economy.total_earned != count:
			push_error("Burst membership/split/cash verification failed")
			quit(1)
		game.free()
	var row: Dictionary = {"case": "mixed_camo_fortified" if mixed else "ceramic_burst", "count": count, "speed": 1,
		"mean_ms": _mean(walls), "p95_ms": _p95(walls), "cpu_ms": _mean(cpus), "creation_ms": creation / 20,
		"grid_ms": grid / 20, "created": created, "peak_active": alive, "pops": count, "damage": count * (1 if mixed else 10), "fingerprint": fingerprint, "samples_ms": walls}
	print("PROPERTIES BENCH: %s N%d mean=%.3f p95=%.3f CPU=%.3f born=%d active=%d creation=%.3f" % [row.case, count, row.mean_ms, row.p95_ms, row.cpu_ms, created, alive, row.creation_ms])
	return row

func _ultra(speed: int) -> Dictionary:
	var game: MainGame = _game()
	var tower: TowerState = game.towers.towers[0]
	for path in range(3):
		for tier in range(1, [5, 0, 2][path] + 1):
			game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	for index in range(100):
		game.balloons.spawn(CERAMIC, 500 + index * 1.5, index % 2 == 0, index % 3 == 0)
	game.balloons.spawn_count = 0
	game.balloons.spawn_usec = 0
	var walls: Array[float] = []
	var cpus: Array[float] = []
	var narrow: float = 0.0
	var resolution: float = 0.0
	var candidates: int = 0
	var peak: int = 100
	var previous: int = Time.get_ticks_usec()
	for frame in range(120):
		if _render:
			await process_frame
		var started: int = Time.get_ticks_usec()
		for step in range(speed):
			game.balloons.reset_spatial_metrics()
			game.simulation_step(MainGame.FIXED_STEP)
			narrow += float(game.projectiles.profile_usec.narrow) / 1000.0
			resolution += float(game.projectiles.profile_usec.resolution) / 1000.0
			candidates += game.balloons.spatial_metrics().candidates
			peak = maxi(peak, game.balloons.balloons.size())
		cpus.append(float(Time.get_ticks_usec() - started) / 1000.0)
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		walls.append(float(now - previous) / 1000.0 if _render else cpus.back())
		previous = now
	var row: Dictionary = {"case": "ultra_ceramic100", "count": 100, "speed": speed,
		"mean_ms": _mean(walls), "p95_ms": _p95(walls), "cpu_ms": _mean(cpus),
		"creation_ms": float(game.balloons.spawn_usec) / 1000.0 / 120, "created": game.balloons.spawn_count,
		"peak_active": peak, "narrow_ms": narrow / 120, "resolution_ms": resolution / 120, "candidates": float(candidates) / 120,
		"split_projectiles": tower.combat_stats.split_projectiles, "pops": tower.combat_stats.pops(), "damage": tower.combat_stats.effective_damage,
		"fingerprint": [game.economy.gold, game.economy.lives, game.balloons.balloons.size(), game.balloons.latest_id(), tower.combat_stats.snapshot()], "samples_ms": walls}
	print("PROPERTIES BENCH: Ultra x%d mean=%.3f p95=%.3f CPU=%.3f born=%d peak=%d mini=%d" % [speed, row.mean_ms, row.p95_ms, row.cpu_ms, row.created, peak, row.split_projectiles])
	game.free()
	return row

func _mean(values: Array[float]) -> float:
	var sum: float = 0
	for value in values:
		sum += value
	return sum / values.size()

func _p95(values: Array[float]) -> float:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[ceili(sorted.size() * 0.95) - 1]
