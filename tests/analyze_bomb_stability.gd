extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenarios: RefCounted = preload("res://tests/scenarios/bomb_stability_scenarios.gd").new()
	var micro: Array[Dictionary] = []
	for build: Array in scenarios.BUILDS:
		for condition in ["incoming", "centered", "area", "sustained", "black", "white", "lead", "ceramic", "camo", "ddt"]:
			micro.append(scenarios.micro(root, build, condition))
	var campaigns: Array[Dictionary] = []
	for strategy in scenarios.STRATEGIES:
		var normal: Dictionary = scenarios.campaign(root, strategy, 1)
		var fast: Dictionary = scenarios.campaign(root, strategy, 2)
		if normal != fast:
			push_error("Bomb budget 1x/2x differs: " + strategy)
			quit(1)
			return
		normal.speed_match = true
		campaigns.append(normal)
		print("BOMB BUDGET: %s %s wave%d cost%d pops%d leaks%d/%d lives%d gold%d" % [strategy, normal.result, normal.wave, normal.cost, normal.pops, normal.leaked_instances, normal.leaked_rbe, normal.lives, normal.gold])
	var phase: String = "before" if OS.get_cmdline_user_args().has("--before") else "after"
	var file: FileAccess = FileAccess.open("res://benchmarks/bomb-v0111-" + phase + "-analysis.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.11.1", "phase": phase,
		"conditions": "Micro: one forced real projectile, stationary targets, incoming origin250,350 vs MOAB300,350; centered origin300,350; area4 each at offsets0,45x,45y,45xy; Single shots1second60Hz; sustained uses actual tower cooldown/aiming for10seconds against16initial stationary MOABs, all descendants retained. Forced immune contacts explicitly separate from can_target. Campaign: normal400G/50lives/20waves, unupgraded dart support; upgrade existing bombs in ID/path order, then spend remaining cash with shared2-dart:1-bomb expansion (if cash<150 buy dart), upgrade each newly placed bomb toward strategy. No artificial unit cap or extra cash. Cross rotates302/203/032/023. Shared valid placement priority from balance_scenarios then56px grid fallback; purchase/start on next whole simulation second after clear. Failed play stops at defeat, not forced victory. Removed instances counts fully removed IDs including split parents, Pops counts removed layers; leaks count instances and full current-type RBE. All purchases/positions/waves retained.", "micro": micro, "campaigns": campaigns}, "\t") + "\n")
	file.close()
	var csv: FileAccess = FileAccess.open("res://benchmarks/bomb-v0111-" + phase + "-balance.csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["strategy", "result", "wave", "cost", "pops", "removed_instances", "leaked_instances", "leaked_rbe", "lives", "gold", "earned"]))
	for row in campaigns:
		csv.store_csv_line(PackedStringArray([row.strategy, row.result, str(row.wave), str(row.cost), str(row.pops), str(row.removed_instances), str(row.leaked_instances), str(row.leaked_rbe), str(row.lives), str(row.gold), str(row.earned)]))
	csv.close()
	csv = FileAccess.open("res://benchmarks/bomb-v0111-" + phase + "-crosspaths.csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["build", "condition", "can_target", "damage", "moab_damage", "pops", "gold_earned", "pierce_used", "volleys", "projectiles", "split_projectiles"]))
	for row in micro:
		csv.store_csv_line(PackedStringArray(["%d-%d-%d" % row.build, row.condition, str(row.can_target), str(row.damage), str(row.moab_damage), str(row.pops), str(row.gold_earned), str(row.pierce_used), str(row.volleys), str(row.projectiles), str(row.split_projectiles)]))
	csv.close()
	print("BOMB STABILITY ANALYSIS COMPLETE: %d micro, %d paired campaigns" % [micro.size(), campaigns.size()])
	quit()
