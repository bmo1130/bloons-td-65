extends SceneTree

const MAIN: PackedScene = preload("res://tests/fixtures/v05_main.tscn")
const BLUE: BalloonDefinition = preload("res://data/balloons/blue.tres")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const COMBAT_TESTS: Script = preload("res://tests/combat_tests.gd")
const ATTRIBUTE_TESTS: Script = preload("res://tests/attribute_tests.gd")
const UPGRADE_TESTS: Script = preload("res://tests/upgrade_tests.gd")
const CROSSPATH_TESTS: Script = preload("res://tests/crosspath_tests.gd")
const STATISTICS_TESTS: Script = preload("res://tests/statistics_tests.gd")

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_layers_and_leaks()
	_test_economy_and_placement()
	_test_targeting_and_projectiles()
	_test_three_waves()
	_test_defeat()
	print("V0.1 REGRESSION: %d checks, %d failures" % [_checks, _failures])
	var combat: RefCounted = COMBAT_TESTS.new()
	var report: Dictionary = combat.run(root)
	_checks += report.checks
	_failures += report.failures
	var attributes: RefCounted = ATTRIBUTE_TESTS.new()
	var attribute_report: Dictionary = attributes.run(root)
	_checks += attribute_report.checks
	_failures += attribute_report.failures
	var upgrades: RefCounted = UPGRADE_TESTS.new()
	var upgrade_report: Dictionary = upgrades.run(root)
	_checks += upgrade_report.checks
	_failures += upgrade_report.failures
	var crosspaths: RefCounted = CROSSPATH_TESTS.new()
	var crosspath_report: Dictionary = crosspaths.run(root)
	_checks += crosspath_report.checks
	_failures += crosspath_report.failures
	var statistics: RefCounted = STATISTICS_TESTS.new()
	var statistics_report: Dictionary = statistics.run(root)
	_checks += statistics_report.checks
	_failures += statistics_report.failures
	var tier4: RefCounted = load("res://tests/tier4_tests.gd").new()
	var tier4_report: Dictionary = tier4.run(root)
	_checks += tier4_report.checks
	_failures += tier4_report.failures
	var tier5: RefCounted = load("res://tests/tier5_tests.gd").new()
	var tier5_report: Dictionary = tier5.run(root)
	_checks += tier5_report.checks
	_failures += tier5_report.failures
	var properties: RefCounted = load("res://tests/balloon_properties_tests.gd").new()
	var properties_report: Dictionary = properties.run(root)
	_checks += properties_report.checks
	_failures += properties_report.failures
	var moab_report: Dictionary = load("res://tests/moab_tests.gd").new().run(root)
	_checks += moab_report.checks
	_failures += moab_report.failures
	var late_report: Dictionary = load("res://tests/ddt_bad_tests.gd").new().run(root)
	_checks += late_report.checks
	_failures += late_report.failures
	var bomb_report: Dictionary = load("res://tests/bomb_upgrade_tests.gd").new().run(root)
	_checks += bomb_report.checks
	_failures += bomb_report.failures
	var stability_report: Dictionary = load("res://tests/bomb_stability_tests.gd").new().run(root)
	_checks += stability_report.checks
	_failures += stability_report.failures
	var bomb_tier5_report: Dictionary = load("res://tests/bomb_tier5_tests.gd").new().run(root)
	_checks += bomb_tier5_report.checks
	_failures += bomb_tier5_report.failures
	print("TEST RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _new_game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	root.add_child(game)
	game.set_process(false)
	preload("res://tests/fixtures/v02_config.gd").apply(game)
	return game

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _test_layers_and_leaks() -> void:
	var game: MainGame = _new_game()
	var balloon: BalloonState = game.balloons.spawn(BLUE)
	balloon.distance = 100.0
	balloon.position = game.route.position_at(balloon.distance)
	var old_position: Vector2 = balloon.position
	game.balloons.damage(balloon.id, 1)
	_check(balloon.definition == RED, "blue becomes red after one hit")
	_check(game.balloons.find(balloon.id) == balloon, "layer change preserves identity")
	_check(balloon.distance == 100.0 and balloon.position == old_position, "layer change preserves route progress")
	_check(game.economy.gold == 201, "blue layer pays exactly one gold")
	game.balloons.update(0.1)
	_check(is_equal_approx(balloon.distance, 109.5), "converted red uses red speed")
	game.balloons.damage(balloon.id, 1)
	_check(game.balloons.balloons.is_empty(), "red is destroyed by one hit")
	_check(game.economy.gold == 202, "red destruction pays one gold")
	game.balloons.damage(balloon.id, 1)
	_check(game.economy.gold == 202, "duplicate hit cannot duplicate rewards")
	var blue_leak: BalloonState = game.balloons.spawn(BLUE)
	blue_leak.distance = game.route.total_length - 1.0
	game.balloons.update(0.1)
	_check(game.economy.lives == 18, "unhit blue leak costs two lives")
	_check(game.economy.gold == 202, "leaks do not award gold")
	var red_leak: BalloonState = game.balloons.spawn(BLUE)
	game.balloons.damage(red_leak.id, 1)
	red_leak.distance = game.route.total_length - 1.0
	game.balloons.update(0.1)
	_check(game.economy.lives == 17, "converted blue leaks only its remaining red layer")
	_check(game.balloons.balloons.is_empty(), "leaked balloons are removed")
	game.free()

func _test_economy_and_placement() -> void:
	var game: MainGame = _new_game()
	_check(game.economy.gold == 200 and game.economy.lives == 20, "initial economy")
	_check(not game.try_place_tower(Vector2(156, 350)), "road placement rejected")
	_check(not game.try_place_tower(Vector2(180, 240)), "path corner placement rejected")
	_check(not game.try_place_tower(Vector2(24, 150)), "tower footprint must fit board")
	_check(not game.try_place_tower(Vector2(1040, 400)), "sidebar placement rejected")
	_check(game.economy.gold == 200, "invalid placements spend nothing")
	_check(game.try_place_tower(Vector2(250, 350)), "valid free placement succeeds")
	_check(game.economy.gold == 135 and game.towers.towers.size() == 1, "placement spends cost once")
	_check(not game.try_place_tower(Vector2(260, 350)), "overlapping tower rejected")
	_check(game.economy.gold == 135, "overlap does not spend gold")
	_check(not game.economy.try_spend(-10), "negative purchases rejected")
	game.economy.earn(-10)
	_check(game.economy.gold == 135, "negative income ignored")
	_check(game.economy.try_spend(135), "exact-balance purchase accepted")
	_check(not game.try_place_tower(Vector2(460, 450)), "unaffordable placement rejected")
	_check(game.towers.towers.size() == 1 and game.economy.gold == 0, "insufficient gold has no side effects")
	game.free()

func _test_targeting_and_projectiles() -> void:
	var game: MainGame = _new_game()
	game.try_place_tower(Vector2(250, 350))
	var first: BalloonState = game.balloons.spawn(RED)
	first.distance = 240.0
	first.position = game.route.position_at(first.distance)
	first.record_motion(PackedVector2Array([first.position, first.position]), 0.0)
	var front: BalloonState = game.balloons.spawn(BLUE)
	front.distance = 320.0
	front.position = game.route.position_at(front.distance)
	front.record_motion(PackedVector2Array([front.position, front.position]), 0.0)
	game.towers.update(1.0 / 60.0)
	_check(game.projectiles.projectiles.size() == 1, "tower fires a projectile")
	if not game.projectiles.projectiles.is_empty():
		_check(game.projectiles.projectiles[0].target_id == front.id, "target is furthest along route in range")
		game.projectiles.update(1.0)
		_check(front.definition == RED, "projectile applies layer damage on impact")
		_check(game.balloons.find(first.id) != null, "projectile does not damage other balloons")
	game.projectiles.fire(Vector2(250, 350), first, MainGame.DART)
	game.balloons.damage(first.id, 1)
	var gold: int = game.economy.gold
	game.projectiles.update(0.1)
	# v0.2: losing the aimed target must not destroy a useful ballistic dart.
	_check(not game.projectiles.projectiles.is_empty(), "projectiles survive removed aim targets")
	_check(game.economy.gold == gold, "stale projectile does not pay extra gold")
	game.free()

func _test_three_waves() -> void:
	var game: MainGame = _new_game()
	# Keep the original economy/balance regression; v0.2 waves are tested separately.
	game.waves.waves = [preload("res://data/waves/wave_01.tres"),
		preload("res://tests/fixtures/v01_wave_02.tres"),
		preload("res://tests/fixtures/v01_wave_03.tres")]
	for at in [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232)]:
		_check(game.try_place_tower(at), "three-tower scenario placement at %s" % at)
	for wave in range(1, 4):
		_check(game.start_next_wave(), "wave %d starts" % wave)
		_check(not game.start_next_wave(), "active wave cannot be started twice")
		for tick in range(90 * 60):
			game.simulation_step(1.0 / 60.0)
			if not game.waves.active or game.result != &"":
				break
		_check(not game.waves.active, "wave %d finishes within 90 simulated seconds" % wave)
		_check(game.economy.lives > 0, "wave %d is survivable" % wave)
	_check(game.result == &"victory", "third clear triggers victory")
	_check(game.economy.lives == 20, "sample three-tower layout stops all balloons")
	_check(game.economy.gold == 175, "80 layer rewards + 90 clear gold + 5 remaining gold")
	_check(not game.start_next_wave(), "no fourth wave")
	var gold: int = game.economy.gold
	game.waves.check_cleared()
	_check(game.economy.gold == gold, "wave clear reward cannot repeat")
	print("VICTORY SCENARIO: lives=%d gold=%d waves=%d" % [game.economy.lives, game.economy.gold, game.waves.current_wave])
	game.free()

func _test_defeat() -> void:
	var game: MainGame = _new_game()
	game.economy.lose_lives(19)
	game.start_next_wave()
	for tick in range(90 * 60):
		game.simulation_step(1.0 / 60.0)
		if game.result != &"":
			break
	_check(game.result == &"defeat" and game.economy.lives == 0, "unprotected leak triggers defeat")
	_check(game.economy.gold == 200, "defeat gives neither pop nor clear rewards")
	_check(not game.try_place_tower(Vector2(250, 350)), "placement disabled after defeat")
	_check(not game.start_next_wave(), "wave start disabled after defeat")
	game.economy.lose_lives(100)
	_check(game.economy.lives == 0, "lives never go negative")
	var count: int = game.balloons.balloons.size()
	game.simulation_step(10.0)
	_check(game.balloons.balloons.size() == count, "simulation stops on defeat")
	game.free()
