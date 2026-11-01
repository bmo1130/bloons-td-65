extends "res://tests/tack_benchmark.gd"
func _run() -> void:
	for path: String in ["scripts/systems/projectile_system.gd","scripts/systems/tower_system.gd","scripts/systems/ability_system.gd","scripts/core/tower_stat_resolver.gd"]:
		if FileAccess.get_sha256("res://"+path) != FileAccess.get_sha256("res://test-results/v016-start/"+path):
			push_error("Before requires unchanged v016-start runtime")
			quit(1)
			return
	_render = OS.get_cmdline_user_args().has("--render")
	var output: String = "res://benchmarks/tack-v016-before-%s.json"%("render" if _render else "cpu")
	if FileAccess.file_exists(output):
		push_error("Never overwrite original before data")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
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
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"conditions":"Actual unchanged local v015 runtime before v016. Original10towers/1000maintained.032/230/boomer320/Blitz;1x2x;2trials30warm120samples. Real render frame_post_draw,VSyncOFF;headlessCPU includes maintenance/HUD/timers."},"\t")+"\n")
	file.close()
	print("TACK V016 BEFORE COMPLETE:16rows")
	quit()
