extends "res://tests/chain_benchmark.gd"
func _run() -> void:
	for path: String in ["scripts/systems/projectile_system.gd","scripts/systems/tower_system.gd","scripts/systems/combat_system.gd"]:
		if FileAccess.get_sha256("res://"+path) != FileAccess.get_sha256("res://test-results/v015-start/"+path):
			push_error("Before capture requires unchanged v015-start runtime; preserve original before raw data")
			quit(1)
			return
	_render = OS.get_cmdline_user_args().has("--render")
	if FileAccess.file_exists("res://benchmarks/tack-v015-before-%s.json"%("render" if _render else "cpu")):
		push_error("Original before raw already exists; never replace historical timing data")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		for speed in [1,2]:
			var row: Dictionary = await _boomerang_load([3,2,0],1000,speed)
			row.trial = trial
			rows.append(row)
	var file: FileAccess = FileAccess.open("res://benchmarks/tack-v015-before-%s.json"%("render"if _render else"cpu"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"conditions":"Actual v014 local source before v015 edits. Original320/10towers/1000bloons;30warm+120samples x2trials;1x/2x;render frame_post_draw VSyncOFF."},"\t")+"\n")
	file.close()
	print("TACK BEFORE BENCHMARK COMPLETE")
	quit()
