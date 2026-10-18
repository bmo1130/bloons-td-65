extends RefCounted

const MAIN: PackedScene = preload("res://tests/fixtures/v05_main.tscn")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const YELLOW: BalloonDefinition = preload("res://data/balloons/yellow.tres")
const BLACK: BalloonDefinition = preload("res://data/balloons/black.tres")
const LEAD: BalloonDefinition = preload("res://data/balloons/lead.tres")
var _builds: Array[PackedInt32Array] = [PackedInt32Array([3, 2, 0]), PackedInt32Array([3, 0, 2]),
	PackedInt32Array([2, 3, 0]), PackedInt32Array([0, 3, 2]), PackedInt32Array([2, 0, 3]), PackedInt32Array([0, 2, 3])]
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_test_state_space()
	_test_order_independence()
	_test_crosspath_combat()
	for build in _builds:
		var normal: Dictionary = _campaign(build, 1)
		var fast: Dictionary = _campaign(build, 2)
		_check(normal == fast, "crosspath 1x/2x real accumulator outcomes match")
		_check(normal.result == &"victory" and normal.build == _text(build), "crosspath campaign buys requested build and clears six waves")
		print("V0.5 CROSSPATH PLAY: %s" % normal)
	print("V0.5 CROSSPATHS: %d checks, %d failures" % [_checks, _failures])
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

func _text(tiers: PackedInt32Array) -> String:
	return "%d-%d-%d" % [tiers[0], tiers[1], tiers[2]]

# Finite independent oracle for the implemented content: at most two nonzero
# coordinates, and at most one coordinate equal to 3. No purchase-order rules.
func _legal(tiers: PackedInt32Array) -> bool:
	return tiers.count(0) >= 1 and tiers.count(3) <= 1

func _fingerprint(stats: TowerDefinition) -> Dictionary:
	var values: Dictionary = {}
	for field in TowerStatResolver.FIELDS:
		values[field] = stats.get(field)
	values[&"color"] = stats.color
	return values

func _test_state_space() -> void:
	var game: MainGame = _game()
	game.towers.add_tower(Vector2(250, 350), MainGame.DART)
	var tower: TowerState = game.towers.towers[0]
	var legal_count: int = 0
	for top in range(4):
		for middle in range(4):
			for bottom in range(4):
				var state: PackedInt32Array = PackedInt32Array([top, middle, bottom])
				_check(UpgradePolicy.state_reason(state).is_empty() == _legal(state), "all 64 tier triples classified: " + _text(state))
				if not _legal(state):
					tower.tiers = state
					var money: int = game.economy.gold
					_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 1)) and game.economy.gold == money and tower.tiers == state, "invalid source state cannot transact")
					continue
				legal_count += 1
				for item in MainGame.DART.upgrades:
					if item.tier > 3:
						continue # Frozen v0.5 state-space oracle; tier 4 has its own suite.
					tower.tiers = state.duplicate()
					tower.stats = TowerStatResolver.resolve(tower.definition, state)
					tower.spent_on_upgrades = 0
					tower.cooldown = 0.23
					game.economy.gold = 1000
					var candidate: PackedInt32Array = state.duplicate()
					candidate[item.path] = item.tier
					var expected: bool = item.tier == state[item.path] + 1 and _legal(candidate)
					var before: TowerDefinition = tower.stats
					_check(game.upgrades.error_for(tower, item).is_empty() == expected, "purchase eligibility matches finite rule oracle")
					var result: bool = game.try_upgrade(tower, item)
					_check(result == expected, "transaction enforces same policy")
					if result:
						_check(tower.tiers == candidate and game.economy.gold == 1000 - item.cost and tower.spent_on_upgrades == item.cost, "successful crosspath purchases debit once and update one coordinate")
					else:
						_check(tower.tiers == state and tower.stats == before and tower.cooldown == 0.23 and tower.spent_on_upgrades == 0 and game.economy.gold == 1000, "every failed purchase preserves all state")
	_check(legal_count == 34, "34 legal states among implemented 0..3 triples")
	_check(not UpgradePolicy.state_reason(PackedInt32Array([6, 0, 0])).is_empty(), "tier 6 remains unavailable even when structural crosspath rule allows it")
	_check(UpgradePolicy.state_reason(PackedInt32Array([5, 2, 0]), UpgradePolicy.FINAL_TIER).is_empty(), "same structural validation can support future 5-2-0 data")
	_check(not UpgradePolicy.state_reason(PackedInt32Array([1, 0])).is_empty(), "malformed tier vector rejected")
	game.free()

func _orders(tiers: PackedInt32Array, prefix: Array[int] = []) -> Array:
	var orders: Array = []
	if tiers == PackedInt32Array([0, 0, 0]):
		orders.append(prefix)
		return orders
	for path in range(3):
		if tiers[path] <= 0:
			continue
		var remaining: PackedInt32Array = tiers.duplicate()
		remaining[path] -= 1
		var next: Array[int] = prefix.duplicate()
		next.append(path)
		orders.append_array(_orders(remaining, next))
	return orders

func _test_order_independence() -> void:
	for build in _builds:
		var reference: Dictionary = {}
		var expected_main: int = build.find(3)
		for order: Array in _orders(build):
			var game: MainGame = _game()
			game.economy.earn(1000)
			game.towers.add_tower(Vector2(250, 350), MainGame.DART)
			var tower: TowerState = game.towers.towers[0]
			for path: int in order:
				var item: UpgradeDefinition = MainGame.DART.upgrade_at(path, tower.tiers[path] + 1)
				var preview: TowerDefinition = TowerStatResolver.preview(tower.definition, tower.tiers, item)
				var previous: PackedInt32Array = tower.tiers.duplicate()
				_check(previous == tower.tiers and game.try_upgrade(tower, item), "all 60 main/secondary purchase interleavings are legal")
				_check(_fingerprint(preview) == _fingerprint(tower.stats), "preview and purchased attack values are identical")
			if reference.is_empty():
				reference = _fingerprint(tower.stats)
			_check(_fingerprint(tower.stats) == reference, "final stats/behavior/color independent of purchase order")
			_check(UpgradePolicy.main_path(tower.tiers) == expected_main and tower.stats.color == MainGame.DART.upgrade_at(expected_main, 3).visual_color, "derived main path and main visual identity survive secondary purchases")
			game.free()
		var stats: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, build)
		var expected_pierce: int = [2, 3, 5, 8][build[0]]
		_check(stats.pierce == expected_pierce, "crosspath additive pierce is retained")
		_check(is_equal_approx(stats.fire_interval, 0.476 if build[1] >= 2 else 0.7), "secondary/main interval multipliers retained")
		_check(stats.damage == (2 if build[2] == 3 else 1), "power main path retains damage override")
		_check(stats.projectile_count == (3 if build[1] == 3 else 1), "only middle tier 3 enables triple volley")
		_check(stats.attack_range == (200 if build[2] >= 2 else 150) and stats.projectile_speed == (660 if build[2] >= 2 else 480), "range/speed additions survive special attacks")
		_check(stats.projectile_radius == (7.0 if build[0] == 3 else 2.5) and stats.attack_attribute == AttackSpec.Attribute.SHARP, "large collision shape and SHARP retained")
	_check(MainGame.DART.pierce == 2 and MainGame.DART.fire_interval == 0.7 and MainGame.DART.projectile_count == 1, "all combinations leave shared base data immutable")

func _at(game: MainGame, data: BalloonDefinition, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 100.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _buy(game: MainGame, tower: TowerState, build: PackedInt32Array) -> void:
	for path in range(3):
		for tier in range(tower.tiers[path] + 1, build[path] + 1):
			_check(game.try_upgrade(tower, tower.definition.upgrade_at(path, tier)), "fixture purchases crosspath through production transaction")

func _test_crosspath_combat() -> void:
	for build in _builds:
		var game: MainGame = _game()
		game.economy.earn(1000)
		game.towers.add_tower(Vector2(250, 350), MainGame.DART)
		var tower: TowerState = game.towers.towers[0]
		_buy(game, tower, build)
		var stats: TowerDefinition = tower.stats
		var origin: Vector2 = Vector2(100, 300)
		for ray in range(stats.projectile_count):
			var angle: float = 0.0 if stats.projectile_count == 1 else deg_to_rad((ray - 1) * 12.0)
			for index in range(stats.pierce):
				_at(game, YELLOW, origin + Vector2.RIGHT.rotated(angle) * (200 + index * 36))
		var aim: BalloonState = _at(game, RED, origin + Vector2(800, 0))
		var before: int = game.economy.gold
		game.projectiles.fire_volley(origin, aim, stats)
		var shots: Array[ProjectileState] = game.projectiles.projectiles.duplicate()
		_check(shots.size() == stats.projectile_count, "crosspath spawns resolved number of independent darts")
		game.projectiles.update(1.2)
		for shot in shots:
			_check(shot.hit_ids.size() == stats.pierce and shot.remaining_pierce == 0 and shot.damage == stats.damage and shot.speed == stats.projectile_speed, "each crosspath dart uses full independent pierce/damage/speed")
		_check(game.economy.gold == before + stats.projectile_count * stats.pierce * stats.damage, "dense crosspath hits pay exact layer rewards")
		game.projectiles.update(0.01)
		_check(game.economy.gold == before + stats.projectile_count * stats.pierce * stats.damage, "transformed layers never duplicate rewards from old darts")
		var lead: BalloonState = _at(game, LEAD, Vector2(800, 600))
		var black: BalloonState = _at(game, BLACK, Vector2(800, 600))
		_check(game.combat.apply_hit(lead.id, stats.make_attack()) == 0 and lead.definition == LEAD, "crosspaths never bypass lead SHARP immunity")
		_check(game.combat.apply_hit(black.id, stats.make_attack()) == 1 and game.balloons.find(black.id) == null, "crosspath can peel black but does not propagate overkill to children")
		game.free()
	# 2-2-0 allows either path to become main, with distinct lock reasons.
	for path in [0, 1]:
		var game: MainGame = _game()
		game.economy.earn(1000)
		game.towers.add_tower(Vector2(250, 350), MainGame.DART)
		var tower: TowerState = game.towers.towers[0]
		_buy(game, tower, PackedInt32Array([2, 2, 0]))
		_check(UpgradePolicy.main_path(tower.tiers) == -1, "2-2-0 has no predetermined main")
		_check(game.try_upgrade(tower, MainGame.DART.upgrade_at(path, 3)), "either invested path may become main")
		_check(game.upgrades.error_for_path(tower, 1 - path).contains("주력"), "secondary tier-3 reason identifies other main path")
		_check(game.upgrades.error_for_path(tower, 2).contains("세 번째"), "third-path lock reason is distinct")
		_check(tower.definition.upgrade_at(path, 4) != null and game.upgrades.error_for_path(tower, path).contains("자금 부족"), "tier 4 offered without changing tier-3 economy")
		game.free()

func _campaign(build: PackedInt32Array, speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.simulation_speed = speed
	var main: int = build.find(3)
	var secondary: int = build.find(2)
	game.try_place_tower(Vector2(250, 350), MainGame.DART)
	game.try_place_tower(Vector2(250, 410), MainGame.BOMB)
	var tower: TowerState = game.towers.towers[0]
	for tier in [1, 2]:
		_check(game.try_upgrade(tower, MainGame.DART.upgrade_at(main, tier)), "campaign starts with main tier 2 using real budget")
	for wave in range(6):
		if wave == 1:
			_check(game.try_place_tower(Vector2(460, 450), MainGame.DART), "campaign earnings fund support dart")
		if wave == 3:
			_check(game.try_upgrade(tower, MainGame.DART.upgrade_at(main, 3)), "campaign earns main tier 3 before wave 4")
		if wave == 4:
			_check(game.try_place_tower(Vector2(672, 232), MainGame.DART), "campaign funds front support before wave 5")
			_check(game.try_place_tower(Vector2(672, 440), MainGame.DART), "campaign funds rear support before wave 5")
		if wave == 5:
			_check(game.try_place_tower(Vector2(460, 650), MainGame.BOMB), "campaign funds lead support")
		_check(game.start_next_wave(), "crosspath campaign wave starts")
		for frame in range(90 * 60 / speed):
			game._process(1.0 / 60.0)
			# Check at fixed simulation times, not render-frame boundaries, so
			# buying from actual wave-6 income has identical timing at 1x/2x.
			if wave == 5 and (frame + 1) % (60 / speed) == 0 and tower.tiers[secondary] < 2:
				var item: UpgradeDefinition = MainGame.DART.upgrade_at(secondary, tower.tiers[secondary] + 1)
				if game.economy.gold >= item.cost and game.result == &"":
					_check(game.try_upgrade(tower, item), "wave-6 income buys secondary tier during live combat")
	var spent: int = 0
	for built in game.towers.towers:
		spent += built.definition.cost + built.spent_on_upgrades
	_check(game.economy.gold + spent + 50 - game.economy.lives == 1071, "crosspath campaign conserves layer/bonus/gold values")
	var report: Dictionary = {"build": tower.upgrade_text(), "result": game.result, "wave": game.waves.current_wave,
		"gold": game.economy.gold, "lives": game.economy.lives, "shots": game.projectiles._next_id - 1, "spent": spent}
	game.free()
	return report
