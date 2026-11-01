extends "res://tests/chain_benchmark.gd"

func _run() -> void:
	for path: String in ["scripts/systems/projectile_system.gd", "scripts/core/projectile_state.gd", "scripts/systems/tower_system.gd"]:
		if FileAccess.get_sha256("res://" + path) != FileAccess.get_sha256("res://test-results/v014-start/" + path):
			push_error("Before capture requires original v014-start runtime; historical raw files must not be overwritten with after code")
			quit(1)
			return
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		for build: Array in [[0, 0, 0], [3, 2, 0]]:
			for speed in [1, 2]:
				var row: Dictionary = await _boomerang_load(build, 1000, speed)
				row.trial = trial
				rows.append(row)
	var label: String = "render" if _render else "cpu"
	var file: FileAccess = FileAccess.open("res://benchmarks/boomerang-v014-before-%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "rendered": _render, "engine": Engine.get_version_info().string, "conditions": "Unmodified v0131 runtime, 10 towers/1000 maintained balloons,30warm+120samples,2trials,1x/2x"}, "\t") + "\n")
	file.close()
	print("V014 BEFORE BENCHMARK COMPLETE")
	quit()
