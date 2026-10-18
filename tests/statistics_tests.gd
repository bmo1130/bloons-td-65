extends RefCounted

var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_test_pops_and_identity()
	_test_volley_and_immunity()
	_test_blast_and_splits()
	_test_investment()
	_test_campaign()
	print("V0.6 STATISTICS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _game() -> MainGame:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	return game

func _at(game: MainGame, type: String, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % type))
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _test_pops_and_identity() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	game.try_place_tower(Vector2(460, 450))
	var first: TowerState = game.towers.towers[0]
	var second: TowerState = game.towers.towers[1]
	_check(first.id != second.id and first.combat_stats != second.combat_stats, "tower IDs own independent counters")
	_check(first.combat_stats.pierce_utilization() == 0.0 and first.combat_stats.pops_per_gold() == 0.0, "empty rates are zero, never NaN")
	var data: TowerDefinition = MainGame.DART.duplicate() as TowerDefinition
	data.damage = 4
	var blue: BalloonState = _at(game, "blue", Vector2(200, 300))
	game.projectiles.fire(Vector2(180, 300), blue, data, first.id)
	game.projectiles.update(0.1)
	var record: TowerCombatStats = first.combat_stats
	_check(record.pops() == 2 and record.normal_pops == 2 and record.shell_pops == 0 and record.effective_damage == 2, "overkill only records two actual layers of blue")
	_check(record.volleys == 1 and record.projectiles == 1 and record.targets_damaged == 1, "fire, projectile, distinct hit event are separate")
	_check(record.pierce_used == 1 and record.pierce_available == 2 and record.pierce_utilization() == 0.5, "multi-layer damage consumes one of two available pierce")
	_check(second.combat_stats.pops() == 0 and game.battle_stats.total_pops == 2, "source attribution does not bleed to another tower")
	game.projectiles.update(0.1)
	_check(record.pops() == 2 and record.targets_damaged == 1, "dead/layer-transformed IDs cannot duplicate counters")
	game.free()

func _test_volley_and_immunity() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	var data: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, PackedInt32Array([0, 3, 0]))
	var yellow: BalloonState = _at(game, "yellow", Vector2(200, 300))
	game.projectiles.fire_volley(Vector2(199, 300), yellow, data, tower.id)
	game.projectiles.update(0.001)
	var record: TowerCombatStats = tower.combat_stats
	_check(record.volleys == 1 and record.projectiles == 3 and record.pierce_available == 6, "triple volley counts one attack, three darts, six pierce")
	_check(record.targets_damaged == 3 and record.pops() == 3 and record.pierce_used == 3, "different volley darts may each peel same balloon")
	game.projectiles.update(0.001)
	_check(record.pops() == 3 and record.pierce_utilization() == 0.5, "overlapping darts do not rehit or inflate utilization")
	game.free()
	game = _game()
	game.try_place_tower(Vector2(250, 350))
	tower = game.towers.towers[0]
	var lead: BalloonState = _at(game, "lead", Vector2(200, 300))
	game.projectiles.fire(Vector2(180, 300), lead, MainGame.DART, tower.id)
	game.projectiles.update(0.1)
	game.projectiles.update(0.1)
	record = tower.combat_stats
	_check(record.immune_contacts == 1 and record.effective_damage == 0 and record.targets_damaged == 0, "immune direct contact records zero damage once")
	_check(record.pierce_used == 0 and record.pierce_available == 2 and lead.definition.id == &"lead", "immunity neither spends pierce nor changes combat")
	game.free()

func _test_blast_and_splits() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 410), MainGame.BOMB)
	var tower: TowerState = game.towers.towers[0]
	var aim: BalloonState = _at(game, "lead", Vector2(200, 300))
	_at(game, "black", Vector2(200, 300))
	_at(game, "blue", Vector2(200, 300))
	_at(game, "red", Vector2(200, 300))
	game.projectiles.fire(Vector2(180, 300), aim, tower.stats, tower.id)
	game.projectiles.update(0.1)
	var record: TowerCombatStats = tower.combat_stats
	_check(record.volleys == 1 and record.projectiles == 1 and record.targets_damaged == 3, "one blast damages exactly three eligible targets, no extra direct hit")
	_check(record.normal_pops == 2 and record.shell_pops == 1 and record.pops() == 3, "lead outer shell is one pop, not the entire descendant value")
	_check(record.immune_contacts == 1 and record.pierce_used == 3 and record.pierce_available == 12, "immune black excluded from AoE utilization numerator")
	_check(record.pierce_utilization() == 0.25 and game.economy.gold == 253, "blast usage and gold use confirmed outcomes")
	game.projectiles.update(0.1)
	_check(record.pops() == 3 and game.balloons.balloons.size() == 4, "new split children never add phantom damage/pops")
	game.free()
	game = _game()
	game.try_place_tower(Vector2(250, 350))
	tower = game.towers.towers[0]
	var data: TowerDefinition = MainGame.DART.duplicate() as TowerDefinition
	data.damage = 10
	var black: BalloonState = _at(game, "black", Vector2(200, 300))
	game.projectiles.fire(Vector2(180, 300), black, data, tower.id)
	game.projectiles.update(0.1)
	_check(tower.combat_stats.shell_pops == 1 and tower.combat_stats.normal_pops == 0 and tower.combat_stats.effective_damage == 1, "branching shell stops excess damage before children in statistics too")
	_check(game.balloons.balloons.size() == 2 and game.battle_stats.total_pops == 1, "black split creates two uncounted live pinks")
	game.free()

func _test_investment() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	var record: TowerCombatStats = tower.combat_stats
	var before: Dictionary = record.snapshot()
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 2)) and record.snapshot() == before, "failed upgrade leaves all counters/investment unchanged")
	_check(game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 1)) and tower.combat_stats == record and record.invested_gold == 110 and record.build == "1-0-0", "successful upgrade retains identity and adds actual cost")
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 1)) and record.invested_gold == 110, "repeat purchase cannot inflate investment")
	game.economy.earn(7)
	_check(game.economy.total_earned == 7, "acquired gold excludes starting funds and purchases")
	game.economy.reset()
	_check(game.economy.total_earned == 0, "new economy resets acquired gold")
	game.free()

func _test_campaign() -> void:
	var game: MainGame = _game()
	_check(game.waves.waves.size() == 20 and game.waves.waves[19].groups.size() >= 3, "normal scene has 20 data-driven mixed waves")
	var total_value: int = 0
	for wave in game.waves.waves:
		for group in wave.groups:
			total_value += group.count * group.balloon.layer_count()
	_check(total_value > 5000 and game.waves.waves[19].groups[0].balloon.id == &"lead", "campaign includes substantial final lead pressure")
	game.free()
	var scenarios: RefCounted = preload("res://tests/scenarios/balance_scenarios.gd").new()
	var normal: Dictionary = scenarios.campaign(_root, "mixed", 1, true)
	var fast: Dictionary = scenarios.campaign(_root, "mixed", 2, true)
	var disabled: Dictionary = scenarios.campaign(_root, "mixed", 1, false)
	_check(normal.combat.result == &"victory" and normal.combat.wave == 20, "legal mixed shopping strategy clears campaign wave 20")
	_check(normal == fast, "all campaign results and per-tower statistics identical at 1x/2x")
	_check(normal.combat == disabled.combat and disabled.pops == 0, "statistics enabled/disabled never change combat outcome")
	var sum: int = 0
	for record in normal.towers:
		sum += record.pops
		_check(record.pierce_used <= record.pierce_available and record.effective_damage == record.pops, "real campaign statistics respect actual HP and capacity")
	_check(sum == normal.pops and normal.pops + 50 - normal.combat.lives == total_value, "tower pops plus leaks conserve complete campaign layer tree")
