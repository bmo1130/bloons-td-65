extends "res://tests/bomb_stability_benchmark.gd"

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		for mode in ["bomb_base10", "bomb_frag10", "bomb_cluster10", "bomb_recursive10", "bomb_recursive_fast10", "bomb_blitz_mix10"]:
			for speed in [1, 2]:
				var row: Dictionary = await _bomb_load(mode, 1000, speed)
				row.trial = trial
				rows.append(row)
	var label: String = "render" if _render else "cpu"
	var battles: Array[Dictionary] = []
	var suite: RefCounted = load("res://tests/bomb_tier5_tests.gd").new()
	suite._root = root
	for build: Array in [[4, 0, 2], [5, 2, 0], [0, 4, 2], [0, 5, 2], [2, 0, 4], [0, 2, 5]]:
		var one: Dictionary = suite.battle(build, 1)
		var two: Dictionary = suite.battle(build, 2)
		if one != two:
			push_error("New battle speed mismatch")
			quit(1)
			return
		battles.append({"build": build, "fingerprint": one, "speed_match": true})
	var report: Dictionary = {"version": "v0.12", "rendered": _render, "rows": rows, "battles": battles,
		"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name() if _render else "headless",
		"conditions": "Unchanged v0111 fixture:1000 maintained pink/blue/yellow,10 bombs,30warmup+120 measured frames/trial,2trials.000/302/203 unchanged;204 recursive every2;024 fast every2;Blitz mix=one025+nine024 to respect global tier5 limit. Fixed60Hz simulation,1/2steps per measured frame. Render wall includes frame_post_draw. Nested timers overlap. Combat fingerprint at equal wall-frame count compares CPU/render, not1x/2x;6 separate20 simulation-second mixed battles compare equal game time across speeds. No1-3 balance changes. No approximation/collision skipping. No pooling introduced."}
	var base: String = "res://benchmarks/bomb-v012-" + label
	var file: FileAccess = FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open(base + ".csv", FileAccess.WRITE)
	var keys: PackedStringArray = ["mode", "speed", "trial", "mean_ms", "p95_ms", "cpu_mean_ms", "creation_ms", "narrow_ms", "resolution_ms", "grid_ms", "projectiles_max", "effects_max"]
	for field in EXTRA_FIELDS:
		keys.append(field + "_mean")
	csv.store_csv_line(keys)
	for row in rows:
		var values: PackedStringArray = []
		for key in keys:
			values.append(str(row.get(key, "NA")))
		csv.store_csv_line(values)
	csv.close()
	print("BOMB TIER5 BENCHMARK COMPLETE: %d cases %s" % [rows.size(), label])
	quit()
