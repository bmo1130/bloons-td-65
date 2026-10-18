extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenarios: RefCounted = preload("res://tests/scenarios/balance_scenarios.gd").new()
	var campaigns: Array[Dictionary] = []
	for strategy in scenarios.STRATEGIES:
		var report: Dictionary = scenarios.campaign(root, strategy)
		campaigns.append(report)
		print("CAMPAIGN: %s %s" % [strategy, report.combat])
	var micro: Array[Dictionary] = []
	for build in ["0-0-0", "2-3-0", "0-3-2", "3-2-0", "3-0-2", "2-0-3", "0-2-3", "bomb"]:
		for condition in ["dense", "fast", "black", "lead", "mixed"]:
			for at in [Vector2(250, 350), Vector2(156, 180)]:
				micro.append(scenarios.micro(root, build, condition, at))
	var output: FileAccess = FileAccess.open("res://benchmarks/balance-v06.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"version": "v0.6", "engine": Engine.get_version_info().string,
		"conditions": "Deterministic campaign shop and 500G cap / single-tower / two-position micro scenarios; no tower stat changes",
		"campaigns": campaigns, "micro": micro}, "\t") + "\n")
	output.close()
	var csv: FileAccess = FileAccess.open("res://benchmarks/balance-v06.csv", FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["tower", "build", "position", "condition", "budget", "invested", "unspent", "pops", "leaked", "volleys", "projectiles", "pierce_used", "pierce_available", "utilization", "immune_contacts"]))
	for row in micro:
		csv.store_csv_line(PackedStringArray([row.name, str(row.build), str(row.position), row.condition, str(row.budget), str(row.invested_gold), str(row.unspent_budget), str(row.pops), str(row.leaked_layers), str(row.volleys), str(row.projectiles), str(row.pierce_used), str(row.pierce_available), str(row.pierce_utilization), str(row.immune_contacts)]))
	csv.close()
	print("BALANCE COMPLETE: %d campaigns, %d micro cases" % [campaigns.size(), micro.size()])
	quit()
