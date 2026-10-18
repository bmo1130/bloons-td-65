extends RefCounted

const MAIN: PackedScene = preload("res://tests/fixtures/v05_main.tscn")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const BLUE: BalloonDefinition = preload("res://data/balloons/blue.tres")
const YELLOW: BalloonDefinition = preload("res://data/balloons/yellow.tres")
const LEAD: BalloonDefinition = preload("res://data/balloons/lead.tres")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_test_catalog_and_purchases()
	_test_guards_and_composition()
	_test_large_dart()
	_test_volley()
	_test_power_and_targeting()
	_test_lifecycle()
	for path in range(3):
		var normal: Dictionary = _campaign(path, 1)
		var fast: Dictionary = _campaign(path, 2)
		_check(normal == fast, "path %d 1x/2x exact combat outcomes" % path)
		_check(normal.result == &"victory" and normal.tier == 3, "path %d can afford tier 3 and win normal campaign" % path)
		print("V0.4 PATH %d PLAY: %s" % [path, normal])
	print("V0.4 UPGRADES: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	return game

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _upgrade(game: MainGame, tower: TowerState, path: int, tier: int = 3) -> void:
	for step in range(1, tier + 1):
		_check(game.try_upgrade(tower, tower.definition.upgrade_at(path, step)), "purchase path %d tier %d" % [path, step])

func _at(game: MainGame, data: BalloonDefinition, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 100.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _test_catalog_and_purchases() -> void:
	var ids: Dictionary = {}
	_check(MainGame.DART.upgrades.filter(func(item: UpgradeDefinition) -> bool: return item.tier <= 3).size() == 9 and MainGame.BOMB.upgrades.is_empty(), "original nine dart upgrades preserved, bomb uses empty catalog")
	for item in MainGame.DART.upgrades:
		if item.tier > 3:
			continue
		_check(not ids.has(item.id) and not item.id.is_empty(), "unique nonempty upgrade ID")
		ids[item.id] = true
		_check(item.cost > 0 and not item.display_name.is_empty() and not item.description.is_empty(), "upgrade has positive price and player-facing metadata")
		for effects: Dictionary in [item.additions, item.multipliers, item.overrides]:
			for field: String in effects:
				_check(StringName(field) in TowerStatResolver.FIELDS, "upgrade modifier uses supported stat")
	for path in range(3):
		var game: MainGame = _game()
		_check(game.try_place_tower(Vector2(250, 350)), "place dart for purchase test")
		var tower: TowerState = game.towers.towers[0]
		var other: TowerState = TowerState.new(MainGame.DART, Vector2.ZERO)
		_check(tower.upgrade_text() == "0-0-0", "new tower starts with three independent zero tiers")
		for tier in range(1, 4):
			var item: UpgradeDefinition = MainGame.DART.upgrade_at(path, tier)
			var before: int = game.economy.gold
			tower.cooldown = tower.stats.fire_interval * 0.5
			_check(game.try_upgrade(tower, item), "path %d tier %d succeeds with exact predecessor" % [path, tier])
			_check(game.economy.gold == before - item.cost, "upgrade debits exactly once")
			_check(tower.tiers[path] == tier and is_equal_approx(tower.cooldown, tower.stats.fire_interval * 0.5), "tier and reload fraction update")
			if path == 0:
				_check(tower.stats.pierce == [3, 5, 8][tier - 1], "each top tier resolves exact pierce")
			elif path == 1:
				_check(is_equal_approx(tower.stats.fire_interval, [0.595, 0.476, 0.476][tier - 1]), "each middle tier resolves exact interval")
			else:
				_check(tower.stats.attack_range == [175, 200, 200][tier - 1] and tower.stats.damage == [1, 1, 2][tier - 1], "each bottom tier resolves exact range/damage")
			_check(not game.try_upgrade(tower, item) and game.economy.gold == before - item.cost, "repeated/stale purchase blocked without debit")
			# v0.5 intentionally replaces v0.4's single-path temporary restriction.
			_check(UpgradePolicy.reason(tower, MainGame.DART.upgrade_at((path + 1) % 3, 1)).is_empty(), "second path remains available after single-path purchases")
		_check(other.upgrade_text() == "0-0-0" and other.stats.pierce == 2, "upgrade leaves other instances untouched")
		_check(MainGame.DART.pierce == 2 and MainGame.DART.damage == 1 and MainGame.DART.projectile_count == 1, "base resource stays immutable")
		var a: TowerDefinition = tower.stats
		for rebuild in range(20):
			tower.stats = TowerStatResolver.resolve(tower.definition, tower.tiers)
		_check(tower.stats.fire_interval == a.fire_interval and tower.stats.pierce == a.pierce and tower.stats.attack_range == a.attack_range, "rebuilding never compounds modifiers")
		if path == 0:
			_check(tower.stats.pierce == 8 and tower.stats.projectile_radius == 7.0 and tower.stats.projectile_length == 24.0, "top final pierce/size values")
		elif path == 1:
			_check(is_equal_approx(tower.stats.fire_interval, 0.476) and tower.stats.projectile_count == 3 and tower.stats.spread_degrees == 24.0, "middle final interval and volley")
		else:
			_check(tower.stats.attack_range == 200 and tower.stats.projectile_speed == 660 and tower.stats.damage == 2, "bottom final range/speed/damage")
		game.free()

func _test_guards_and_composition() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	var gold: int = game.economy.gold
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 2)), "cannot skip tier")
	_check(not game.try_upgrade(null, MainGame.DART.upgrade_at(0, 1)), "missing selected tower rejected")
	_check(not game.try_upgrade(TowerState.new(MainGame.DART, Vector2.ZERO), MainGame.DART.upgrade_at(0, 1)), "foreign tower cannot spend game gold")
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 1).duplicate() as UpgradeDefinition), "forged copy cannot substitute for a catalog purchase")
	_check(game.economy.gold == gold and tower.upgrade_text() == "0-0-0", "failed prerequisites are side-effect free")
	game.economy.gold = 44
	var first: UpgradeDefinition = MainGame.DART.upgrade_at(0, 1)
	_check(game.upgrades.error_for(tower, first).contains("자금 부족"), "affordability reason is explicit")
	_check(not game.try_upgrade(tower, first) and game.economy.gold == 44 and tower.tiers[0] == 0, "insufficient funds leaves state unchanged")
	game.economy.gold = 45
	_check(game.try_upgrade(tower, first) and game.economy.gold == 0, "exact balance purchase succeeds")
	game.economy.earn(100)
	game._finish(false)
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 2)) and game.economy.gold == 100, "cannot upgrade after game ends")
	game.free()
	# A different tower definition uses the same resolver/policy/transaction.
	game = _game()
	var base: TowerDefinition = MainGame.BOMB.duplicate() as TowerDefinition
	var first_custom: UpgradeDefinition = UpgradeDefinition.new()
	first_custom.id = &"custom_1"
	first_custom.additions = {"damage": 1, "projectile_count": 2}
	first_custom.multipliers = {"damage": 2}
	var second_custom: UpgradeDefinition = UpgradeDefinition.new()
	second_custom.id = &"custom_2"
	second_custom.tier = 2
	second_custom.prerequisites = [&"missing"]
	second_custom.overrides = {"damage": 3, "heading_offset_degrees": 8.0}
	base.upgrades = [second_custom, first_custom]
	game.towers.add_tower(Vector2(250, 350), base)
	tower = game.towers.towers[0]
	_check(game.try_upgrade(tower, first_custom) and tower.stats.damage == 4 and tower.stats.projectile_count == 3, "additions then multipliers work for another tower")
	_check(not game.try_upgrade(tower, second_custom), "explicit additional prerequisite enforced")
	second_custom.prerequisites = [&"custom_1"]
	second_custom.cost = -1
	_check(not game.try_upgrade(tower, second_custom), "invalid negative cost cannot generate gold")
	second_custom.cost = 50
	_check(game.try_upgrade(tower, second_custom) and tower.stats.damage == 3 and tower.stats.heading_offset_degrees == 8.0, "overrides applied last, catalog ordering irrelevant")
	_check(tower.stats.attack_attribute == AttackSpec.Attribute.EXPLOSIVE, "unmodified attack attribute inherited from bomb base")
	var unsupported: UpgradeDefinition = UpgradeDefinition.new()
	unsupported.tier = 4
	base.upgrades.append(unsupported)
	_check(not UpgradePolicy.reason(tower, unsupported).is_empty(), "v0.4 rejects higher-tier policy")
	game.free()

func _test_large_dart() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	_upgrade(game, tower, 0)
	var balloon: BalloonState = _at(game, RED, Vector2(200, 318))
	var ordinary: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, MainGame.DART)
	game.projectiles.update(0.3)
	_check(not ordinary.hit_ids.has(balloon.id), "normal dart misses off-axis center by 18 pixels")
	var large: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats)
	game.projectiles.update(0.3)
	_check(large.hit_ids.has(balloon.id) and game.balloons.find(balloon.id) == null, "large dart collision width is real, including grid broadphase")
	game.free()
	game = _game()
	game.try_place_tower(Vector2(250, 350))
	tower = game.towers.towers[0]
	_upgrade(game, tower, 0)
	for index in range(10):
		_at(game, RED, Vector2(170 + index * 12, 300))
	large = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats)
	game.projectiles.update(0.5)
	_check(large.hit_ids.size() == 8 and game.balloons.balloons.size() == 2 and large.remaining_pierce == 0, "top dart hits eight dense targets and stops")
	game.free()

func _test_volley() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	_upgrade(game, tower, 1)
	var target: BalloonState = _at(game, YELLOW, Vector2(200, 300))
	game.projectiles.fire_volley(Vector2(100, 300), target, tower.stats)
	_check(game.projectiles.projectiles.size() == 3, "three independent projectiles per attack")
	var shots: Array[ProjectileState] = game.projectiles.projectiles.duplicate()
	for index in range(3):
		_check(is_equal_approx(rad_to_deg(shots[index].direction.angle()), (index - 1) * 12.0), "fan uses symmetric -12/0/+12 degree headings")
		_check(shots[index].remaining_pierce == 2 and shots[index].hit_ids.is_empty(), "each volley dart starts with own pierce and history")
	game.projectiles.projectiles.clear()
	# All three start inside one balloon; distinct shots can each peel it, but
	# each may peel only once even while the surviving layer still overlaps.
	game.projectiles.fire_volley(target.position, target, tower.stats)
	# Zero aim is deliberately invalid; choose a target slightly ahead instead.
	_check(game.projectiles.projectiles.is_empty(), "zero direction cannot create stuck projectiles")
	game.projectiles.fire_volley(target.position - Vector2(1, 0), target, tower.stats)
	shots = game.projectiles.projectiles.duplicate()
	var before: int = game.economy.gold
	game.projectiles.update(0.001)
	_check(target.definition == RED and game.economy.gold == before + 3, "three independent darts can each remove a layer from the same target")
	for shot in shots:
		_check(shot.remaining_pierce == 1 and shot.hit_ids.size() == 1, "independent per-dart pierce and dedup after overlap")
	game.projectiles.update(0.001)
	_check(target.definition == RED and game.economy.gold == before + 3, "same volley darts cannot hit a transformed target twice")
	_check(shots[0].id != shots[1].id and shots[1].id != shots[2].id, "volley IDs are unique")
	game.free()

func _test_power_and_targeting() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	var in_flight: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats)
	_upgrade(game, tower, 2)
	_check(in_flight.damage == 1 and in_flight.speed == 480.0 and in_flight.length == 10.0, "already flying attacks retain launch snapshot")
	game.projectiles.projectiles.clear()
	var yellow: BalloonState = _at(game, YELLOW, Vector2(200, 300))
	var lead: BalloonState = _at(game, LEAD, Vector2(250, 300))
	var blue: BalloonState = _at(game, BLUE, Vector2(300, 300))
	var before: int = game.economy.gold
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats)
	game.projectiles.update(0.4)
	_check(yellow.definition == BLUE and game.balloons.find(blue.id) == null, "power dart applies damage 2 independently at each target")
	_check(lead.definition == LEAD and shot.remaining_pierce == 0 and game.economy.gold == before + 4, "power dart retains SHARP immunity, immune target costs no pierce/gold")
	game.free()
	game = _game()
	game.try_place_tower(Vector2(250, 350))
	tower = game.towers.towers[0]
	var target: BalloonState = _at(game, RED, Vector2(440, 350))
	_check(game.towers._first_in_range(tower) == null, "target at 190 is outside base range")
	_upgrade(game, tower, 2, 2)
	_check(game.towers._first_in_range(tower) == target, "range upgrade affects actual spatial targeting")
	var immune: BalloonState = _at(game, LEAD, Vector2(300, 350))
	immune.distance = 500.0
	_check(game.towers._first_in_range(tower) == target, "upgraded targeting still skips lead")
	game.towers.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.size() == 1 and game.projectiles.projectiles[0].target_id == target.id, "upgraded tower fires at valid target with new stats")
	game.free()

func _test_lifecycle() -> void:
	var game: MainGame = _game()
	game.try_place_tower(Vector2(250, 350))
	var tower: TowerState = game.towers.towers[0]
	_upgrade(game, tower, 0)
	game.select_instance(tower)
	_check(game.selected_instance == tower and not game.building and game.hud.upgrade_panel.visible, "selection opens upgrade panel and ends placement")
	game.select_tower(MainGame.BOMB)
	_check(game.selected_instance == null and game.building and not game.hud.upgrade_panel.visible, "build mode clears tower selection")
	game.free()
	game = _game()
	game.try_place_tower(Vector2(250, 350))
	_check(game.selected_instance == null and game.towers.towers[0].upgrade_text() == "0-0-0" and game.projectiles.projectiles.is_empty(), "new scene never inherits upgrade/selection/projectile state")
	game.free()

func _campaign(path: int, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.simulation_speed = speed
	_check(game.try_place_tower(Vector2(250, 350), MainGame.DART), "campaign initial dart placement")
	_check(game.try_place_tower(Vector2(250, 410), MainGame.BOMB), "campaign initial bomb placement")
	var tower: TowerState = game.towers.towers[0]
	_upgrade(game, tower, path, 2)
	var purchased_at_wave: int = 0
	for wave in range(6):
		if wave == 1:
			_check(game.try_place_tower(Vector2(460, 450), MainGame.DART), "campaign adds second dart from real earnings")
		if wave == 3:
			var bought: bool = game.try_upgrade(tower, MainGame.DART.upgrade_at(path, 3))
			_check(bought, "campaign earnings buy tier 3 before wave 4")
			if bought:
				purchased_at_wave = wave + 1
		if wave == 4:
			_check(game.try_place_tower(Vector2(672, 232), MainGame.DART), "campaign buys front support dart")
			_check(game.try_place_tower(Vector2(672, 440), MainGame.DART), "campaign buys rear support dart")
		if wave == 5:
			_check(game.try_place_tower(Vector2(460, 650), MainGame.BOMB), "campaign buys second bomb against lead")
		_check(game.start_next_wave(), "campaign next wave starts")
		for frame in range(90 * 60 / speed):
			game._process(1.0 / 60.0)
	var spent: int = 0
	for built in game.towers.towers:
		spent += built.definition.cost + built.spent_on_upgrades
	_check(game.economy.gold + spent + (50 - game.economy.lives) == 400 + 491 + 180, "campaign upgrades preserve exact total layer/bonus economy")
	var score: Dictionary = {"result": game.result, "gold": game.economy.gold,
		"lives": game.economy.lives, "wave": game.waves.current_wave,
		"shots": game.projectiles._next_id - 1, "tier": tower.tiers[path], "tier3_before_wave": purchased_at_wave}
	game.free()
	return score
