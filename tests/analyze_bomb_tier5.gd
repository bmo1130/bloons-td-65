extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows: Array[Dictionary] = []
	var scenarios: RefCounted = load("res://tests/scenarios/bomb_stability_scenarios.gd").new()
	for build: Array in [[4, 2, 0], [4, 0, 2], [5, 2, 0], [5, 0, 2], [2, 4, 0], [0, 4, 2], [2, 5, 0], [0, 5, 2], [2, 0, 4], [0, 2, 4], [2, 0, 5], [0, 2, 5]]:
		for condition in ["incoming", "centered", "area", "sustained", "black", "white", "lead", "ceramic", "camo", "ddt"]:
			var one: Dictionary = scenarios.micro(root, build, condition, 1, build[2] >= 4, 1000000)
			if one != scenarios.micro(root, build, condition, 2, build[2] >= 4, 1000000):
				push_error("High tier micro speed mismatch")
				quit(1)
				return
			one.speed_match = true
			rows.append(one)
	var file: FileAccess = FileAccess.open("res://benchmarks/bomb-v012-crosspaths.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"conditions": "Stationary fixture inherited from v0111. Incoming/centered single MOAB, area16 MOAB, sustained10seconds with tower volleys; other types single contact. Recursive single-shot rows force recursive second shot; sustained uses actual attack counter. No abilities/movement. Fortified ceramic, invisible DDT. All real purchases funded with1M laboratory budget. All120cases match1x/2x.", "rows": rows}, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open("res://benchmarks/bomb-v012-crosspaths.csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["build", "condition", "damage", "moab_damage", "pops", "split_projectiles", "volleys", "speed_match"]))
	for row in rows:
		csv.store_csv_line(PackedStringArray([str(row.build), row.condition, str(row.damage), str(row.moab_damage), str(row.pops), str(row.split_projectiles), str(row.volleys), str(row.speed_match)]))
	csv.close()
	print("BOMB TIER5 CROSSPATH COMPLETE: %d cases, 120 speed comparisons" % rows.size())
	quit()
