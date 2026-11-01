extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _micro(build: Array, kind: String, count: int, camo: bool = false, armor: bool = false, filtered: bool = true) -> Dictionary:
	var suite: RefCounted = load("res://tests/boomerang_tests.gd").new()
	suite._root = root
	var game: MainGame = suite._game()
	game.projectiles.flight_broadphase_enabled = filtered
	var tower: TowerState = suite._tower(game, build)
	var first: BalloonState
	for index in range(count):
		var at: Vector2 = Vector2(340 + (index % 8) * 22, 350 + (index / 8) * 22)
		var balloon: BalloonState = suite._at(game, kind, at, armor, camo)
		if first == null:
			first = balloon
	var can_target: bool = game.combat.can_target(first, tower.stats)
	if can_target:
		game.projectiles.fire(Vector2(200, 350), first, tower.stats, tower.id)
	for tick in range(360):
		game.projectiles.update(MainGame.FIXED_STEP)
	var remaining: Array = []
	for balloon in game.balloons.balloons:
		remaining.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.camo, balloon.fortified])
	remaining.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var report: Dictionary = {"build": build, "kind": kind, "count": count, "camo": camo, "fortified": armor,
		"stats": suite._fields(tower.stats), "can_target": can_target, "record": tower.combat_stats.snapshot(), "live": remaining,
		"projectiles_end": game.projectiles.projectiles.size()}
	game.free()
	return report

func _run() -> void:
	var rows: Array[Dictionary] = []
	var battles: Array[Dictionary] = []
	var suite: RefCounted = load("res://tests/boomerang_tests.gd").new()
	suite._root = root
	for build: Array in suite.BUILDS:
		var one: Dictionary = suite.battle(build, 1)
		if one != suite.battle(build, 2) or one != suite.battle(build, 1, true, false):
			push_error("Boomerang equal-time combat mismatch")
			quit(1)
			return
		battles.append(one)
		for condition: Array in [["moab", 1, false, false], ["moab", 16, false, false], ["lead", 1, false, false], ["black", 1, false, false], ["white", 1, false, false], ["ceramic", 1, false, true], ["moab", 1, true, false], ["ddt", 1, false, false]]:
			var row: Dictionary = _micro(build, condition[0], condition[1], condition[2], condition[3])
			if row != _micro(build, condition[0], condition[1], condition[2], condition[3], false):
				push_error("Conservative bounds changed micro collision")
				quit(1)
				return
			rows.append(row)
	var prefix: String = "res://benchmarks/boomerang-v0131-crosspaths" if OS.get_cmdline_user_args().has("--v0131") else "res://benchmarks/boomerang-v013-crosspaths"
	if OS.get_cmdline_user_args().has("--v014"):
		prefix = "res://benchmarks/boomerang-v014-legacy-crosspaths"
	var output: FileAccess = FileAccess.open(prefix + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"conditions": "6real purchased builds. Single stationary target or16in8x2grid22px spacing. One physical projectile from200,350; no towers.update.360fixedticks to drain all flights.20second mixed battle separately uses50moving green/lead/ceramic/MOAB/black,camo/fortified/spill,actual cooldown. All6equal-time1x/2x,all48micro and6battles filtered/unfiltered match. Budget1M is laboratory only. STAT_FIELDS match TowerStatResolver.FIELDS.", "fields": TowerStatResolver.FIELDS, "rows": rows, "battles": battles}, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open(prefix + ".csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["build", "kind", "count", "camo", "fortified", "damage", "pops", "targets", "pierce_used", "gold", "projectiles_end"]))
	for row in rows:
		csv.store_csv_line(PackedStringArray([str(row.build), row.kind, str(row.count), str(row.camo), str(row.fortified), str(row.record.effective_damage), str(row.record.pops), str(row.record.targets_damaged), str(row.record.pierce_used), str(row.record.gold_earned), str(row.projectiles_end)]))
	csv.close()
	print("BOOMERANG ANALYSIS COMPLETE: %d micro cases and6equal-time battles" % rows.size())
	quit()
