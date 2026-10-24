extends RefCounted

const SCENARIOS: Script = preload("res://tests/scenarios/bomb_stability_scenarios.gd")
var _checks: int = 0
var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.11.1 FAIL: " + label)

func _normalized(value: Variant) -> Variant:
	# JSON stores numeric values without GDScript's typed-array/int distinction.
	# Compare the identical serialization boundary used for the frozen report;
	# no numerical tolerance or omitted combat fields is introduced.
	return JSON.parse_string(JSON.stringify(value))

func run(window: Window) -> Dictionary:
	var scenarios: RefCounted = SCENARIOS.new()
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmarks/bomb-v0111-before-analysis.json"))
	var expected_incoming: Array[int] = [12, 8, 22, 2]
	var expected_centered: Array[int] = [27, 2, 27, 1]
	var expected_area: Array[int] = [72, 80, 236, 24]
	for index in range(scenarios.BUILDS.size()):
		var build: Array = scenarios.BUILDS[index]
		for condition in ["incoming", "centered", "area", "sustained", "black", "white", "lead", "ceramic", "camo", "ddt"]:
			var one: Dictionary = scenarios.micro(window, build, condition, 1)
			var fast: Dictionary = scenarios.micro(window, build, condition, 2)
			_check(one == fast, "crosspath %s/%s 1x/2x actual attacks" % [str(build), condition])
			var expected: Dictionary = {}
			for row: Dictionary in baseline.micro:
				if row.build == _normalized(build) and row.condition == condition:
					expected = row
			_check(not expected.is_empty() and _normalized(one) == expected, "exact pre-optimization HP/IDs/rewards/counters " + condition)
			if condition != "sustained":
				_check(one.volleys == 1 and one.projectiles == (1 if condition in ["camo", "ddt"] else 9), "children never create extra volleys")
			if condition not in ["camo", "ddt", "sustained"]:
				_check(one.projectiles_end == 0 and one.effects_end == 0, "resolved fragments/clusters and effects all expire")
			if condition == "incoming":
				_check(one.damage == expected_incoming[index], "geometric first-contact single-target damage")
			elif condition == "centered":
				_check(one.damage == expected_centered[index], "eight intentional fragments vs outward fused explosions")
			elif condition == "area":
				_check(one.damage == expected_area[index], "independent overlapping AoEs with individual pierce limits")
			elif condition in ["camo", "ddt"]:
				_check(one.damage == 0 and one.split_projectiles == 0 and not one.can_target, "detection and composite immunity never bypassed")
			elif condition == "black":
				_check(one.damage == [11, 0, 8, 0][index] and one.can_target == (index in [0, 2]), "sharp fragments vs explosive immunity")
			_check(one.gold_earned == one.pops, "only removed layers/shells reward, never HP-only")
	for expected: Dictionary in baseline.campaigns:
		var one: Dictionary = scenarios.campaign(window, expected.strategy, 1)
		var fast: Dictionary = scenarios.campaign(window, expected.strategy, 2)
		var frozen: Dictionary = expected.duplicate(true)
		frozen.erase("speed_match")
		_check(one == fast, "normal budget campaign 1x/2x " + expected.strategy)
		_check(_normalized(one) == frozen, "campaign before/after including every purchase/position/wave " + expected.strategy)
		_check(one.gold + one.cost == 400 + one.earned, "normal400G plus actual income conservation")
		var spent: int = 0
		var legal: bool = true
		for purchase: Dictionary in one.purchases:
			spent += purchase.cost
			legal = legal and purchase.cost > 0 and purchase.balance >= 0
		_check(legal and spent == one.cost, "real transactions remain affordable and invested sum exact")
		_check(one.lives == maxi(0, 50 - one.leaked_rbe), "normal50 lives and actual leak RBE")
		if one.strategy == "none":
			_check(one.towers.all(func(tower: Dictionary) -> bool: return tower.build == "0-0-0"), "no-upgrade campaign has no hidden upgrades")
		else:
			_check(one.towers.any(func(tower: Dictionary) -> bool: return tower.kind == "bomb" and tower.build != "0-0-0"), "real bomb upgrades actually purchased")
		print("V0.11.1 BUDGET %s: %s wave%d cost%d pops%d leaks%d lives%d gold%d" % [one.strategy, one.result, one.wave, one.cost, one.pops, one.leaked_rbe, one.lives, one.gold])
	print("BOMB STABILITY TESTS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}
