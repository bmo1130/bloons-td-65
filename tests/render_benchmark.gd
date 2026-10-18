extends SceneTree

const TYPES: Array = ["red", "blue", "green", "yellow", "pink", "black", "lead"]
var _serial: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for count in [100, 500, 1000]:
		for speed in [1, 2]:
			rows.append(await _measure(count, speed, false, true))
	for enabled in [true, false]:
		rows.append(await _measure(1000, 2, true, enabled))
	var output: FileAccess = FileAccess.open("res://benchmarks/render-v06.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"display": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"conditions": "1280x720 OpenGL Compatibility, VSync disabled, 30 warmup / 120 samples; post-draw wall intervals include rendering/submission/scheduling, not a GPU-only timer", "rows": rows}, "\t") + "\n")
	output.close()
	print("RENDER BENCHMARK COMPLETE: %d cases" % rows.size())
	quit()

func _measure(count: int, speed: int, cluster: bool, enabled: bool) -> Dictionary:
	var scenarios: RefCounted = preload("res://tests/scenarios/balance_scenarios.gd").new()
	var game: MainGame = scenarios.create_game(root)
	game.battle_stats.enabled = enabled
	game.economy.starting_lives = 1000000000
	game.economy.reset()
	game.economy.earn(10000)
	var positions: Array[Vector2] = [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232), Vector2(704, 440),
		Vector2(460, 650), Vector2(80, 300), Vector2(460, 180), Vector2(860, 420)]
	var builds: Array[String] = ["3-2-0", "2-3-0", "2-0-3", "0-3-2"]
	for index in range(8):
		game.towers.add_tower(positions[index], MainGame.DART if index % 2 == 0 else MainGame.BOMB)
		if index % 2 == 0:
			scenarios.upgrade_toward(game, game.towers.towers[index], builds[index / 2])
	game.select_instance(game.towers.towers[0])
	_serial = 0
	var durations: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame in range(150):
		await process_frame
		for step in range(speed):
			_maintain(game, count, cluster)
			game.simulation_step(MainGame.FIXED_STEP)
			_maintain(game, count, cluster)
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		if frame >= 30:
			durations.append(float(now - previous) / 1000.0)
		previous = now
	var sum: float = 0.0
	for value in durations:
		sum += value
	durations.sort()
	var row: Dictionary = {"balloons": count, "speed": speed, "cluster": cluster, "statistics_enabled": enabled,
		"mean_ms": sum / durations.size(), "p95_ms": durations[ceili(durations.size() * 0.95) - 1], "samples_ms": durations}
	game.free()
	print("RENDER: %s" % {"count": count, "speed": speed, "cluster": cluster, "stats": enabled, "mean": row.mean_ms, "p95": row.p95_ms})
	return row

func _maintain(game: MainGame, count: int, cluster: bool) -> void:
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		var distance: float = 800.0 + (_serial % 41) * 0.25 if cluster else fposmod(_serial * 37.0 + (_serial % 7) * 19.0, game.route.total_length - 80.0)
		game.balloons.spawn(load("res://data/balloons/%s.tres" % TYPES[_serial % 7]), distance)
		_serial += 1
