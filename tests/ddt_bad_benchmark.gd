extends "res://tests/moab_benchmark.gd"

const DDT: BalloonDefinition = preload("res://data/balloons/ddt.tres")
const BAD: BalloonDefinition = preload("res://data/balloons/bad.tres")

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for count in [10, 100]:
		for speed in [1, 2]:
			rows.append(await _live(DDT, count, speed))
	for speed in [1, 2]:
		rows.append(await _live(DDT, 100, speed, true))
	for pair: Array in [[1, false], [1, true], [3, false]]:
		rows.append(await _complete(pair[0], pair[1], BAD, 13, false))
	for speed in [1, 2]:
		rows.append(await _campaign(speed))
	var report: Dictionary = {"version": "v0.11", "engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "os": OS.get_name() + " " + OS.get_version(), "logical_processors": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name() if _render else "headless", "rendered": _render,
		"conditions": "Compatibility1280x720/VSyncOFF/debug. Live120 frames,1/2 fixed60Hz steps, no population replacement/truncation. Initial DDT at distance500+index*.2, every3rd Fortified, intrinsic Camo. Mixed=025/502/052+4x002; Plasma-only=052+19x002. Plasma activated at start. Synthetic dense placements x250+(i%2)*150,y220+floor(i/2)*28 include illegal construction positions, not campaign strategy. Complete=5 fresh13-phase trials per normalBAD1/FortifiedBAD1/normalBAD3. Each phase moves1 step, full-map grid query, direct Normal damage equal to initial targets' remaining shellHP; no tower attacks/newborn independent hits. All descendants rendered, no Regrow behavior/scaling. Partial timers overlap. Normal20 unchanged mixed shopping, render only wave20 checkpoint. Post_draw includes renderer/driver/OS; not isolated GPU time.", "rows": rows}
	var base: String = "res://benchmarks/ddt-bad-v011-" + ("render" if _render else "cpu")
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
	print("DDT BAD BENCHMARK COMPLETE: %d cases render=%s" % [rows.size(), _render])
	quit()
