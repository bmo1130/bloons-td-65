extends "res://tests/tier5_benchmark.gd"

var _search_mode: int = 0

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.projectiles.chain_cache_mode = _search_mode
	return game

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(2):
		for mode in [0, 3]:
			_search_mode = mode
			for speed in [1, 2]:
				var row: Dictionary = await _campaign(speed)
				row.search_mode = mode
				row.trial = trial
				rows.append(row)
	for row in rows:
		var same: Array = rows.filter(func(other: Dictionary) -> bool: return other.speed == row.speed and other.trial == row.trial and other.search_mode == 0)
		if row.fingerprint != same[0].fingerprint:
			push_error("Normal campaign reference/optimized regression")
			quit(1)
			return
	var label: String = "render" if _render else "cpu"
	var file: FileAccess = FileAccess.open("res://benchmarks/" + _output_prefix() + "-campaign-" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.13.1", "rows": rows, "conditions": "Unchanged ordinary20wave inherited mixed-shopping fixture. Two trials of reference mode0 and optimized3 at1x/2x. CPU measures all active-wave frames; actual render measures120frames atwave20 afterfixed450warmup ticks. CPU victory fingerprint is not the rendered checkpoint fingerprint. Normal campaign has dart/bomb, no new prices/resources. Reference0 uses current diagnostics-disabled code; separate original-code before stress is in before-cpu/render."}, "\t") + "\n")
	file.close()
	print("CHAIN CAMPAIGN COMPLETE: 8 cases %s; reference/optimized match" % label)
	quit()

func _output_prefix() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-prefix="):
			return arg.trim_prefix("--output-prefix=")
	return "boomerang-v014"
