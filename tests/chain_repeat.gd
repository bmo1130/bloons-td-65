extends "res://tests/chain_benchmark.gd"

var _forced_mode: int = 0

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.projectiles.chain_cache_mode = _forced_mode
	return game

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	for trial in range(4):
		for mode in [0, 3]:
			_forced_mode = mode
			var row: Dictionary = await _boomerang_load([3, 2, 0], 1000, 2)
			row.search_mode = mode
			row.trial = trial
			rows.append(row)
	for row in rows:
		if row.fingerprint != rows[0].fingerprint:
			push_error("Paired repeat combat mismatch")
			quit(1)
			return
	var label: String = "render" if _render else "cpu"
	var file: FileAccess = FileAccess.open("res://benchmarks/" + _argument("--output-prefix", "boomerang-v0131") + "-repeat-" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.13.1", "rows": rows, "conditions": "320/1000/10towers/2x original fixture. Four independent trials alternating mode0 reference and3 optimized. Each30warmup+120samples=480pooledframes per mode. Same final code/diagnostic branches, detailed trace disabled. Baseline original-code before is separately preserved; mode0 is a present-code control. No selected-frame filtering."}, "\t") + "\n")
	file.close()
	print("CHAIN REPEAT COMPLETE: four alternating reference/optimized trials %s, fingerprints match" % label)
	quit()
