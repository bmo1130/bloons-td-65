extends "res://tests/tier5_benchmark.gd"

const MOAB: BalloonDefinition = preload("res://data/balloons/moab.tres")
const BFB: BalloonDefinition = preload("res://data/balloons/bfb.tres")
const ZOMG: BalloonDefinition = preload("res://data/balloons/zomg.tres")

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for pair: Array in [[MOAB, 10], [MOAB, 100], [BFB, 10]]:
		for speed in [1, 2]:
			rows.append(await _live(pair[0], pair[1], speed))
	rows.append(await _complete(1, false))
	rows.append(await _complete(3, true))
	for speed in [1, 2]:
		rows.append(await _campaign(speed))
	var report: Dictionary = {"version": "v0.10", "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "os": OS.get_name() + " " + OS.get_version(), "logical_processors": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless", "rendered": _render,
		"conditions": "Compatibility1280x720, VSyncOFF, debug. Live=120 measured frames without population maintenance, 1/2 fixed60Hz steps/frame; 1x025,1x502,1x052+4x002 activated Plasma at start; initial route distances500..519.8, full HUD. Full split=5 fresh trials of12 phases, each phase moves60Hz once, grid-query full map then direct Normal damage equal to each initial shell HP; snapshot excludes newborns; no tower attacks in this debug fixture. All 3 fortified ZOMGs retained, all descendants rendered through pink1024/root then lower colors, no truncation. Partial timers overlap. Normal20 uses unchanged mixed shopping; render only wave20 checkpoint. post_draw includes renderer/driver/OS, not isolated GPU time.", "rows": rows}
	var base: String = "res://benchmarks/moab-v010-" + ("render" if _render else "cpu")
	if OS.get_cmdline_user_args().has("--v011"):
		report.version = "v0.11"
		base = base.replace("v010", "v011")
	var output: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "balloons", "speed", "mean_ms", "p95_ms", "cpu_mean_ms", "created", "removed", "peak_active", "active_end", "balloon_creation_ms", "balloon_removal_ms", "projectiles_mean", "projectiles_max", "checks_mean", "candidates_mean", "movement_ms", "grid_ms", "narrow_ms", "resolution_ms", "draw_commands_ms"]
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, "NA")))
		csv.store_csv_line(values)
	csv.close()
	print("MOAB BENCHMARK COMPLETE: %d cases render=%s" % [rows.size(), _render])
	quit()

func _live(definition: BalloonDefinition, count: int, speed: int, plasma_only: bool = false) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	var builds: Array = [[0, 2, 5], [5, 0, 2], [0, 5, 2], [0, 0, 2], [0, 0, 2], [0, 0, 2], [0, 0, 2]]
	if plasma_only:
		builds = [[0, 5, 2]]
		for index in range(19):
			builds.append([0, 0, 2])
	for index in range(builds.size()):
		_build(game, index, builds[index])
	var leader: TowerState = game.towers.towers[0 if plasma_only else 2]
	game.abilities.update(17.0)
	if not game.abilities.activate(leader):
		push_error("MOAB benchmark Plasma activation failed")
		quit(1)
	game.select_instance(leader)
	for index in range(count):
		game.balloons.spawn(definition, 500 + index * 0.2, false, index % 3 == 0, true)
	game.balloons.profile_changes = true
	game.balloons.peak_active_count = count
	var data: Dictionary = _samples()
	var previous: int = Time.get_ticks_usec()
	for frame in range(120):
		_reset_frame(game)
		if _render:
			await process_frame
		var sample: Dictionary = _frame(game, speed, 0, frame)
		if _render:
			await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		sample.wall = float(now - previous) / 1000.0 if _render else sample.cpu
		previous = now
		_finish_sample(game, sample)
		_accumulate(data, sample)
	var row: Dictionary = _report(game, data, ("plasma20_" if plasma_only else "") + str(definition.id) + "_live", count, speed)
	_change_metrics(row, game, 120)
	game.free()
	return row

func _complete(count: int, armor: bool, definition: BalloonDefinition = ZOMG, phases: int = 12, camo: bool = true) -> Dictionary:
	var data: Dictionary = _samples()
	var row: Dictionary = {}
	var reference: Array = []
	var total_creation: int = 0
	var total_removal: int = 0
	for trial in range(5):
		var game: MainGame = _game()
		game.economy.gold = 1000000
		game.economy.lives = 1000000
		game.towers.add_tower(Vector2(250, 350), MainGame.DART)
		var owner: TowerState = game.towers.towers[0]
		game.select_instance(owner)
		for index in range(count):
			game.balloons.spawn(definition, 500 + index * 20, camo, armor, true)
		game.balloons.profile_changes = true
		game.balloons.peak_active_count = count
		var previous: int = Time.get_ticks_usec()
		for phase in range(phases):
			_reset_frame(game)
			if _render:
				await process_frame
			var started: int = Time.get_ticks_usec()
			game.balloons.update(MainGame.FIXED_STEP, true)
			var moved: int = Time.get_ticks_usec()
			var targets: Array[BalloonState] = game.balloons.candidates_in_rect(GameRoute.BUILD_BOUNDS)
			game.hud.begin_combat_update()
			for parent in targets:
				var attack: AttackSpec = AttackSpec.new(parent.shell_hp, 1, AttackSpec.Attribute.NORMAL)
				attack.detects_camo = true
				attack.source_id = owner.id
				game.combat.apply_hit(parent.id, attack)
			game.balloons.resolve_leaks()
			game.hud.end_combat_update()
			var done: int = Time.get_ticks_usec()
			var sample: Dictionary = {"checks": 0, "cpu": float(done - started) / 1000.0}
			for stage in STAGES:
				sample[stage] = 0.0
			sample.movement = float(moved - started) / 1000.0
			sample.resolution = float(done - moved) / 1000.0
			if _render:
				await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			sample.wall = float(now - previous) / 1000.0 if _render else sample.cpu
			previous = now
			_finish_sample(game, sample)
			_accumulate(data, sample)
		var fingerprint: Array = [game.economy.total_earned, owner.combat_stats.snapshot(), game.balloons.latest_id(), game.balloons.balloons.size()]
		if trial > 0 and fingerprint != reference:
			push_error("Repeated full split fingerprint changed")
			quit(1)
		reference = fingerprint
		if game.balloons.balloons.size() != 0 or game.economy.total_earned != count * definition.total_reward() or owner.combat_stats.effective_damage != count * definition.total_rbe(armor):
			push_error("Full blimp split missed descendants, damage or reward")
			quit(1)
		total_creation += game.balloons.spawn_usec
		total_removal += game.balloons.removal_usec
		if trial == 4:
			row = _report(game, data, ("fortified_" if armor else "") + str(definition.id) + "_complete", count, 1)
			_change_metrics(row, game, phases)
			row.balloon_creation_ms = float(total_creation) / 1000.0 / (phases * 5)
			row.balloon_removal_ms = float(total_removal) / 1000.0 / (phases * 5)
			row.fingerprint = fingerprint
		game.free()
	return row

func _change_metrics(row: Dictionary, game: MainGame, frames: int) -> void:
	row.created = game.balloons.spawn_count
	row.removed = game.balloons.removal_count
	row.peak_active = game.balloons.peak_active_count
	row.active_end = game.balloons.balloons.size()
	row.balloon_creation_ms = float(game.balloons.spawn_usec) / 1000.0 / frames
	row.balloon_removal_ms = float(game.balloons.removal_usec) / 1000.0 / frames
