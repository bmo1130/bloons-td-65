extends "res://tests/tack_benchmark.gd"

const NEW_BUILDS: Array = [[4,0,0],[5,0,0],[0,4,0],[0,5,0],[0,0,4],[0,0,5]]
const CROSS_BUILDS: Array = [[4,2,0],[4,0,2],[2,4,0],[0,4,2],[2,0,4],[0,2,4],[5,2,0],[5,0,2],[2,5,0],[0,5,2],[2,0,5],[0,2,5]]
var _setup_done: bool = false
var _high_mix: bool = false
var _area_before: int = 0
var _dot_before: int = 0

func _game() -> MainGame:
	var game: MainGame = super._game()
	# Only this explicit10-identical-tower stress fixture permits10samepath tier5s.
	game.towers.tier5_registry.limits = {&"tack":{0:10,1:10,2:10}}
	_setup_done = false
	return game

func _frame(game: MainGame,speed: int,count: int,frame: int) -> Dictionary:
	if not _setup_done:
		_setup_done = true
		if _high_mix:
			for index in range(game.towers.towers.size()-1,-1,-1):
				game.towers.remove_tower(game.towers.towers[index])
			var catalog: Array[TowerDefinition] = [MainGame.DART,MainGame.BOMB,MainGame.BOOMERANG,MainGame.TACK]
			for index in range(4):
				game.towers.add_tower(Vector2(250+index%2*150,220+(index/2)*28),catalog[index])
				var tower: TowerState = game.towers.towers.back()
				var tiers: Array = [[0,2,5],[0,2,5],[5,0,2],[0,5,2]][index]
				for path in range(3):
					for tier in range(1,tiers[path]+1):
						if not game.try_upgrade(tower,catalog[index].upgrade_at(path,tier)):
							push_error("High mixed purchase failed")
			game.select_instance(game.towers.towers.back())
		for tower in game.towers.towers:
			var state: AbilityState = game.abilities.state_for(tower)
			if state != null and state.definition.effect == AbilityDefinition.Effect.RADIAL_BURST:
				state.cooldown_remaining = 0
				if not game.abilities.activate(tower):
					push_error("Stress active failed")
	var sample: Dictionary = super._frame(game,speed,count,frame)
	sample.active_casters = 0
	for state: AbilityState in game.abilities.states.values():
		if state.definition.effect == AbilityDefinition.Effect.RADIAL_BURST and state.active_remaining > 0.000001:
			sample.active_casters += 1
	sample.area_events = game.combat.area_events-_area_before
	sample.dot_ticks = game.combat.dot_ticks-_dot_before
	return sample

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	_area_before = game.combat.area_events
	_dot_before = game.combat.dot_ticks

func _report(game: MainGame,data: Dictionary,mode: String,count: int,speed: int) -> Dictionary:
	var row: Dictionary = super._report(game,data,mode,count,speed)
	var statuses: Array = []
	for tower in game.towers.towers:
		var state: AbilityState = game.abilities.state_for(tower)
		if state != null and state.definition.effect == AbilityDefinition.Effect.RADIAL_BURST:
			statuses.append([tower.id,state.active_elapsed,state.active_remaining,state.cooldown_remaining,state.burst_cooldown,state.burst_phase,state.bursts_emitted])
	if not statuses.is_empty():
		row.fingerprint.append(statuses)
	var active: Array = data.frame_details.filter(func(sample:Dictionary)->bool:return sample.active_casters>0)
	row.active_samples = active.size()
	row.active_mean_ms = _mean(active.map(func(sample:Dictionary)->float:return sample.wall)) if not active.is_empty() else 0.0
	return row

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		for build: Array in NEW_BUILDS:
			for count in [100,500,1000]:
				for speed in [1,2]:
					var row: Dictionary = await _tack_load(build,count,speed)
					row.trial = trial
					rows.append(row)
		for build: Array in CROSS_BUILDS:
			for speed in [1,2]:
				var row: Dictionary = await _tack_load(build,1000,speed)
				row.trial = trial
				rows.append(row)
		for speed in [1,2]:
			for build: Array in [[0,3,2],[2,3,0]]:
				var row: Dictionary = await _tack_load(build,1000,speed)
				row.trial = trial
				rows.append(row)
			var row: Dictionary = await _boomerang_load([3,2,0],1000,speed)
			row.trial = trial
			rows.append(row)
			row = await _bomb_load("bomb_blitz_mix10",1000,speed)
			row.trial = trial
			rows.append(row)
		_high_mix = true
		for speed in [1,2]:
			var row: Dictionary = await _tack_load([0,5,2],1000,speed)
			row.mode = "four_high_towers_mix"
			row.trial = trial
			rows.append(row)
		_high_mix = false
	var label: String = "render" if _render else "cpu"
	var base: String = "res://benchmarks/tack-v016-"+label
	var output: FileAccess = FileAccess.open(base+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"version":"v0.16","rendered":_render,"rows":rows,"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name() if _render else "headless","source_sha":{"projectiles":FileAccess.get_sha256("res://scripts/systems/projectile_system.gd"),"towers":FileAccess.get_sha256("res://scripts/systems/tower_system.gd"),"abilities":FileAccess.get_sha256("res://scripts/systems/ability_system.gd"),"combat":FileAccess.get_sha256("res://scripts/systems/combat_system.gd"),"resolver":FileAccess.get_sha256("res://scripts/core/tower_stat_resolver.gd")},"conditions":"70cases x2trials=140rows per surface. Six new singlepaths x100/500/1000x1x2x (36cases);12crosspaths x1000x1x2x (24);old032/230/boomer320/Blitz x1000x1x2x (8);high mixed4x1x2x(2).10towers x250/400,y220+28row,maintainedpink/blue/yellow600..620.30warm120samples,240pooled samples/case,nearestP95.1/2fixed60Hz steps/frame=2.5/5game sec,total;2/4game sec measured. Maelstrom real initial wait is charged once by fixture at0,normal3/9seconds duration preserved;0402xexpires during measured interval,active-only samples additionally reported,never filter overall timing. Tier5capacity10 ONLY here. High mixed4dart025/bomb025/boomer502/tack052. Real render1280x720 Compatibility,VSyncOFF,frame_post_draw wall. CPUinclusive maintenance/timers/HUD. Nested timers overlap;do not sum. Actual constructor counts and processwide memory incl reporting buffers;not transient heap/leak proof. No CombatTrace or approximation/pooling/skipped attacks. Detailed owner/ability phases and all live projectiles retained in fingerprints."},"\t")+"\n")
	output.close()
	var csv: FileAccess = FileAccess.open(base+".csv",FileAccess.WRITE)
	var keys: PackedStringArray = ["mode","balloons","speed","trial","mean_ms","p95_ms","max_ms","stddev_ms","projectiles_max","projectiles_per_game_second","queries_mean","checks_mean","creation_ms","removal_ms","tower_draw_ms_mean","balloon_draw_ms_mean","projectile_draw_ms_mean","active_samples","active_mean_ms"]
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key,"NA")))
		csv.store_csv_line(values)
	csv.close()
	print("TACK TIER5 BENCHMARK COMPLETE:140rows "+label)
	quit()
