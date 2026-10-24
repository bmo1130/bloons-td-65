extends "res://tests/tier5_benchmark.gd"

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for mode in ["bomb_frag10", "bomb_cluster10", "bomb_mixed10"]:
		for count in [100, 1000]:
			for speed in [1, 2]:
				rows.append(await _bomb_load(mode, count, speed))
	for speed in [1, 2]:
		rows.append(await _campaign(speed))
	var report: Dictionary = {"version": "v0.11-bomb", "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"os": OS.get_name() + " " + OS.get_version(), "gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"rendered": _render, "conditions": "Godot debug Compatibility1280x720 VSyncOFF. 10 bomb towers at x250/400,y220+28*row. frag=302, cluster=203, mixed rotates320/230/023. 30 warmup+120 samples; speed fixed60Hz steps/frame, dense maintained pink/blue/yellow population at distance600..620 (replacement fixture included in CPU). Single-layer chains keep damageable targets available to all3 builds; this is not an immunity/mixed-branch benchmark. Shared tier5 timers/HUD sampling. Cluster children all retained, finite lifetimes, no recursive effect. Campaign uses unchanged ordinary20 mixed shopping; render is only wave20 checkpoint. CPU time is not rendered FPS; nested stage timers overlap.", "rows": rows}
	var base: String = "res://benchmarks/bomb-v011-" + ("render" if _render else "cpu")
	if OS.get_cmdline_user_args().has("--v0111"):
		report.version = "v0.11.1"
		base = base.replace("v011-", "v0111-")
	var output: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "balloons", "speed", "mean_ms", "p95_ms", "cpu_mean_ms", "projectiles_mean", "projectiles_max", "effects_max", "checks_mean", "candidates_mean", "narrow_ms", "resolution_ms", "creation_ms", "grid_ms", "draw_commands_ms"]
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, "NA")))
		csv.store_csv_line(values)
	csv.close()
	print("BOMB BENCHMARK COMPLETE: %d cases render=%s" % [rows.size(), _render])
	quit()

func _bomb_load(mode: String, count: int, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	for index in range(10):
		game.towers.add_tower(Vector2(250 + index % 2 * 150, 220 + (index / 2) * 28), MainGame.BOMB)
		var tower: TowerState = game.towers.towers.back()
		var build: Array = [3, 0, 2] if mode == "bomb_frag10" else [2, 0, 3]
		if mode == "bomb_base10":
			build = [0, 0, 0]
		if mode == "bomb_recursive10":
			build = [2, 0, 4]
		if mode == "bomb_recursive_fast10":
			build = [0, 2, 4]
		if mode == "bomb_blitz_mix10":
			build = [0, 2, 5] if index == 0 else [0, 2, 4]
		if mode == "bomb_mixed10":
			build = [[3, 2, 0], [2, 3, 0], [0, 2, 3]][index % 3]
		for path in range(3):
			for tier in range(1, build[path] + 1):
				if not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(path, tier)):
					push_error("Bomb load fixture purchase failed")
					quit(1)
	game.select_instance(game.towers.towers[0])
	_serial = 0
	var data: Dictionary = _samples()
	var effects_max: int = 0
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
		effects_max = maxi(effects_max, game.combat.effects.size() + game.projectiles.split_effects.size())
		if frame >= 30:
			_accumulate(data, sample)
	var row: Dictionary = _report(game, data, mode, count, speed)
	row.effects_max = effects_max
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	row.fingerprint.append(live)
	game.free()
	return row

func _maintain(game: MainGame, count: int) -> void:
	# Keep this attack-load fixture hittable after warmup. Mixed black/lead can
	# otherwise leave only immune black targets and turn cluster timing idle.
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		var kind: String = ["pink", "blue", "yellow"][_serial % 3]
		game.balloons.spawn(load("res://data/balloons/%s.tres" % kind), 600.0 + (_serial % 41) * 0.5)
		_serial += 1
