extends "res://tests/chain_benchmark.gd"

var _mixed: bool = false
var _before_instances: int = 0

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		_mixed = false
		for build: Array in [[0,0,0],[3,0,0],[0,3,0],[0,0,3],[2,3,0],[0,3,2],[2,0,3],[0,2,3]]:
			for count in ([100,500,1000] if build in [[0,0,0],[3,0,0],[0,3,0],[0,0,3]] else [1000]):
				for speed in [1,2]:
					var row: Dictionary = await _tack_load(build,count,speed)
					row.trial = trial
					rows.append(row)
		_mixed = true
		for speed in [1,2]:
			var row: Dictionary = await _tack_load([0,2,3],1000,speed)
			row.trial = trial
			rows.append(row)
		_mixed = false
		for speed in [1,2]:
			var row: Dictionary = await _boomerang_load([3,2,0],1000,speed)
			row.trial = trial
			rows.append(row)
	var label: String = "render" if _render else "cpu"
	var base: String = "res://benchmarks/"+_argument("--output-prefix","tack-v016-legacy")+"-"+label
	var report: Dictionary = {"version":"v0.15","rows":rows,"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name() if _render else "headless","rendered":_render,
		"source_sha":{"projectiles":FileAccess.get_sha256("res://scripts/systems/projectile_system.gd"),"towers":FileAccess.get_sha256("res://scripts/systems/tower_system.gd")},
		"conditions":"36cases x2trials =72rows/surface. Each30warmup+120measured frames;pool240samples/case nearest-rank P95.10towers x250/400,y220+28row;maintained100/500/1000pink/blue/yellow distance600..620. Mixed4:dart230,bomb203,boomer320,tack023,same first4positions. Stress-only unrestricted placement/budget;not campaign balance. Speed1/2fixed60Hz steps per frame:2.5/5total game sec;2/4measured sec. CPU inclusive maintenance/HUD/profiling. Render1280x720 Compatibility,VSyncOFF,frame_post_draw wall includes driver/OS. Profile timers overlap;do not sum. Projectile allocations are actual constructors;static memory/object_count are process-wide observations,not temporary heap peaks. No CombatTrace/pooling/approximation/budget/skipped attacks. Fingerprints include balloons,projectiles,auxiliary owner states."}
	var file: FileAccess = FileAccess.open(base+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base+".csv",FileAccess.WRITE)
	var keys: PackedStringArray = ["mode","balloons","speed","trial","mean_ms","p95_ms","max_ms","stddev_ms","projectiles_max","projectile_allocations_mean","queries_mean","checks_mean","creation_ms","removal_ms","tower_draw_ms_mean","balloon_draw_ms_mean","projectile_draw_ms_mean","objects_mean","static_bytes_mean"]
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key,"NA")))
		csv.store_csv_line(values)
	csv.close()
	print("TACK BENCHMARK COMPLETE: %d rows %s"%[rows.size(),label])
	quit()

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	_before_instances = game.projectiles.instances_created

func _frame(game: MainGame,speed: int,count: int,frame: int) -> Dictionary:
	var sample: Dictionary = super._frame(game,speed,count,frame)
	sample.projectile_allocations = game.projectiles.instances_created-_before_instances
	return sample

func _finish_sample(game: MainGame,sample: Dictionary) -> void:
	super._finish_sample(game,sample)
	sample.queries = game.balloons.spatial_metrics().queries
	sample.tower_draw_ms = game.towers.draw_usec/1000.0

func _samples() -> Dictionary:
	var data: Dictionary = super._samples()
	data.queries = []
	data.tower_draw_ms = []
	return data

func _accumulate(data: Dictionary,sample: Dictionary) -> void:
	super._accumulate(data,sample)
	data.queries.append(sample.queries)
	data.tower_draw_ms.append(sample.tower_draw_ms)

func _report(game: MainGame,data: Dictionary,mode: String,count: int,speed: int) -> Dictionary:
	var row: Dictionary = super._report(game,data,mode,count,speed)
	row.queries_mean = _mean(data.queries)
	row.tower_draw_ms_mean = _mean(data.tower_draw_ms)
	row.projectiles_per_game_second = row.projectile_allocations_mean*60.0/speed
	if not mode.begins_with("boomerang_"):
		row.fingerprint.append(load("res://tests/boomerang_tier5_tests.gd").new().auxiliary_snapshot(game))
	return row

func _tack_load(build: Array, count: int, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	for index in range(4 if _mixed else 10):
		var definition: TowerDefinition = [MainGame.DART,MainGame.BOMB,MainGame.BOOMERANG,MainGame.TACK][index] if _mixed else MainGame.TACK
		game.towers.add_tower(Vector2(250+index%2*150,220+(index/2)*28),definition)
		var tower: TowerState = game.towers.towers.back()
		var tiers: Array = [[2,3,0],[2,0,3],[3,2,0],[0,2,3]][index] if _mixed else build
		for path in range(3):
			for tier in range(1,tiers[path]+1):
				if not game.try_upgrade(tower,definition.upgrade_at(path,tier)):
					push_error("Tack fixture real purchase failed")
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
	var row: Dictionary = _report(game, data, "four_towers_mix" if _mixed else "tack_%d%d%d" % build, count, speed)
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

