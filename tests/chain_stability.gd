extends "res://tests/chain_benchmark.gd"

var _stability_checks: int = 0
var _stability_failures: int = 0

func _require(ok: bool, message: String) -> void:
	_stability_checks += 1
	if not ok:
		_stability_failures += 1
		push_error("CHAIN STABILITY: " + message)

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var short: bool = _render or OS.get_cmdline_user_args().has("--short")
	var rows: Array[Dictionary] = []
	var variants: Array = [[3, true, true], [3, true, false]] if _render else [[0, true, true], [3, true, true], [3, false, true], [3, true, false]]
	for variant: Array in variants:
		rows.append(await _endurance(variant[0], variant[1], variant[2], 600 if short else 3600))
	for row in rows:
		_require(row.fingerprint == rows[0].fingerprint, "same lifetime/HP/IDs/positions/economy across reference/statistics/draw controls")
	var label: String = "render" if _render else ("cpu-short" if short else "cpu")
	if OS.get_cmdline_user_args().has("--capture-stages"):
		label += "-profile"
	var file: FileAccess = FileAccess.open("res://benchmarks/" + _argument("--output-prefix", "boomerang-v0131") + "-stability-" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.13.1", "rows": rows, "checks": _stability_checks, "failures": _stability_failures,
		"conditions": "12chain towers300 then320,1000maintained bloons,3600frames/5400fixed ticks=90game seconds. Alternate1x/2x every600frames; pause checks every300; buyat900/removeat1800/reinstallat2000; real branch shells periodically1HP. Maintainer deliberately trims excess for fixed-load fixture, not a full-split benchmark. All targets removed at end and60ticks drain. CPU short and rendered ON/OFF controls use600frames=10game seconds, separately from endurance. Process-wide static bytes/objects sampled every300frames, not RSS/leak proof. Combat fingerprint excludes optional statistics but includes whole live state and active flights before drain."}, "\t") + "\n")
	file.close()
	print("CHAIN STABILITY COMPLETE: %d checks, %d failures, %s" % [_stability_checks, _stability_failures, label])
	quit(0 if _stability_failures == 0 else 1)

func _endurance(mode: int, statistics: bool, cached: bool, frames: int) -> Dictionary:
	var game: MainGame = _game()
	game.projectiles.chain_cache_mode = mode
	game.battle_stats.enabled = statistics
	game.balloons.use_draw_cache = cached
	game.balloons.profile_changes = true
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	for index in range(12):
		_install(game, index)
	game.select_instance(game.towers.towers[0])
	game.developer_mode = true
	_serial = 0
	var memory: Array = []
	var samples: Array[float] = []
	var frame_stages: Array[Dictionary] = []
	var maximum: int = 0
	var previous: int = Time.get_ticks_usec()
	for frame in range(frames):
		if frame == 900:
			for tower in game.towers.towers:
				_require(game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(1, 1)) and game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(1, 2)), "actual upgrades during existing flights")
		if frame == 1800:
			game.towers.remove_tower(game.towers.towers[0])
		if frame == 2000:
			_install(game, 0)
		if frame % 300 == 0:
			game.experiment_paused = true
			var frozen: Array = [game.economy.gold, game.balloons.latest_id(), game.projectiles._next_id, game.towers.towers[0].cooldown]
			game._process(1.0)
			game.simulation_step(MainGame.FIXED_STEP)
			_require(frozen == [game.economy.gold, game.balloons.latest_id(), game.projectiles._next_id, game.towers.towers[0].cooldown], "pause never advances pending chain/cooldown/economy")
			game.experiment_paused = false
			_require(game.projectiles._chain_candidates.is_empty() and game.projectiles._chain_groups.is_empty() and not game.projectiles._resolving, "no batch cache or event work retained between frames")
			memory.append([frame, Performance.get_monitor(Performance.MEMORY_STATIC), Performance.get_monitor(Performance.OBJECT_COUNT), game.projectiles.projectiles.size()])
		game.simulation_speed = 1 if frame % 1200 < 600 else 2
		_reset_frame(game)
		if _render:
			await process_frame
		var sample: Dictionary = _frame(game, game.simulation_speed, 1000, frame)
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0 if _render else sample.cpu)
		if OS.get_cmdline_user_args().has("--capture-stages"):
			_finish_sample(game, sample)
			frame_stages.append(sample.duplicate(true))
		previous = now
		maximum = maxi(maximum, game.projectiles.projectiles.size())
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance, balloon.camo, balloon.fortified])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var flights: Array = []
	for shot in game.projectiles.projectiles:
		flights.append([shot.id, shot.position, shot.lifetime, shot.age, shot.remaining_pierce, shot.target_id, shot.hit_ids])
	var counters: Array = []
	for tower in game.towers.towers:
		counters.append([tower.id, tower.attack_counter, tower.cooldown])
	var fingerprint: Array = [game.economy.gold, game.economy.lives, game.balloons.latest_id(), game.projectiles._next_id, live, flights, counters]
	while not game.balloons.balloons.is_empty():
		game.balloons._remove(game.balloons.balloons.size() - 1)
	for tick in range(60):
		game.simulation_step(MainGame.FIXED_STEP)
	_require(game.projectiles.projectiles.is_empty() and game.projectiles._chain_groups.is_empty(), "all targets disappear and simultaneous glaives finish without accumulation")
	_require(maximum < 256 and game.towers.towers.size() >= 11, "bounded active projectiles with at least eleven chain towers")
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var report: Dictionary = {"mode": mode, "statistics": statistics, "draw_cache": cached, "frames": frames, "mean_ms": _mean(samples), "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "max_ms": sorted[-1], "samples_ms": samples, "frame_stages": frame_stages, "memory_samples": memory, "projectiles_max": maximum, "created_balloons": game.balloons.latest_id(), "created_projectiles": game.projectiles._next_id - 1, "pops_when_enabled": game.battle_stats.total_pops, "fingerprint": fingerprint, "drained_projectiles": game.projectiles.projectiles.size(), "objects_before_free": Performance.get_monitor(Performance.OBJECT_COUNT)}
	game.free()
	await process_frame
	report.objects_after_free = Performance.get_monitor(Performance.OBJECT_COUNT)
	print("CHAIN ENDURANCE mode%d stats%s cache%s frames%d mean%.3f p95%.3f max%d" % [mode, statistics, cached, frames, report.mean_ms, report.p95_ms, maximum])
	return report

func _install(game: MainGame, index: int) -> void:
	game.towers.add_tower(Vector2(250 + index % 2 * 150, 220 + (index / 2) * 28), MainGame.BOOMERANG)
	var tower: TowerState = game.towers.towers.back()
	for tier in range(1, 4):
		_require(game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(0, tier)), "chain tower installs through common catalog and transaction")

func _maintain(game: MainGame, count: int) -> void:
	while game.balloons.balloons.size() > count:
		game.balloons._remove(game.balloons.balloons.size() - 1)
	while game.balloons.balloons.size() < count:
		var kind: String = ["pink", "blue", "yellow", "ceramic"][_serial % 4]
		if _serial % 97 == 0:
			kind = "bfb"
		var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % kind), 600.0 + (_serial % 41) * 0.5, false, false, true)
		if kind == "bfb" or kind == "ceramic":
			balloon.shell_hp = 1
		_serial += 1
