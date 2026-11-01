extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const BUILDS: Array = [[3, 2, 0], [3, 0, 2], [2, 3, 0], [0, 3, 2], [2, 0, 3], [0, 2, 3]]
var _root: Window
var _checks: int = 0
var _failures: int = 0

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BOOMERANG FAIL: " + message)

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	return game

func _tower(game: MainGame, build: Array, reverse: bool = false) -> TowerState:
	game.towers.add_tower(Vector2(250, 350), MainGame.BOOMERANG)
	var tower: TowerState = game.towers.towers.back()
	for path in ([2, 1, 0] if reverse else [0, 1, 2]):
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(path, tier))
	return tower

func _dummy(game: MainGame, at: Vector2, radius: float = 10.0) -> BalloonState:
	var data: BalloonDefinition = BalloonDefinition.new()
	data.shell_hp = 10000
	data.radius = radius
	data.speed = 0.0
	var balloon: BalloonState = game.balloons.spawn(data, 500.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _at(game: MainGame, kind: String, at: Vector2, armor: bool = false, camo: bool = false) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % kind), 500.0, camo, armor, true)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _fields(data: TowerDefinition) -> Array:
	var fields: Array = []
	for key in TowerStatResolver.FIELDS:
		fields.append(data.get(key))
	return fields

func run(window: Window) -> Dictionary:
	_root = window
	_catalog()
	_curves()
	_chains()
	_kylie()
	_attributes()
	_lifecycle()
	for build: Array in BUILDS:
		var one: Dictionary = battle(build, 1)
		_check(one == battle(build, 2), "six complete crosspaths exact fixed-step1x/2x " + str(build))
		_check(one.combat == battle(build, 1, false).combat, "statistics never determine trajectory/rehit/chain " + str(build))
		_check(one == battle(build, 1, true, false), "conservative bounds rejection never changes complete combat " + str(build))
		_check(one.damage > 0 and one.volleys > 0 and one.combat[3] > 1, "each purchased crosspath really fires and damages " + str(build))
	print("BOOMERANG TESTS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _catalog() -> void:
	var base: TowerDefinition = MainGame.BOOMERANG
	var original_fields: Array = _fields(base)
	_check(MainGame.TOWER_CATALOG.slice(0,3) == [MainGame.DART, MainGame.BOMB, base] and base.id == &"boomerang" and base.shortcut == "W", "third shared catalog entry and independent hotkey")
	_check(base.cost == 315 and base.damage == 1 and base.pierce == 4 and base.fire_interval == 1.2 and base.attack_range == 43 * 4.6875 and not base.detects_camo, "requested base values and existing distance conversion")
	var legacy_catalog: Array[UpgradeDefinition] = base.upgrades.filter(func(item: UpgradeDefinition) -> bool: return item.tier <= 3)
	_check(legacy_catalog.size() == 9, "original nine tier1-3 data upgrades remain intact")
	var expected_costs: Array = [[200, 280, 600], [175, 250, 1250], [100, 300, 1300]]
	var ids: Dictionary = {}
	for item in legacy_catalog:
		_check(not ids.has(item.id) and item.cost == expected_costs[item.path][item.tier - 1] and item.reference_medium_cost == item.cost and not item.description.is_empty(), "unique ID, explicit price and description")
		ids[item.id] = true
		_check(item.prerequisites == ([] if item.tier == 1 else [base.upgrade_at(item.path, item.tier - 1).id]), "data prerequisite is previous upgrade")
	for a in range(4):
		for b in range(4):
			for c in range(4):
				var build: Array = [a, b, c]
				if not UpgradePolicy.state_reason(PackedInt32Array(build)).is_empty():
					continue
				var game: MainGame = _game()
				var tower: TowerState = _tower(game, build)
				var reverse: TowerState = _tower(game, build, true)
				_check(tower.tiers == PackedInt32Array(build) and _fields(tower.stats) == _fields(reverse.stats), "all34 legal states synthesize independent of purchase order")
				var cost: int = 0
				for item in TowerStatResolver.acquired(base, tower.tiers):
					cost += item.cost
				_check(tower.spent_on_upgrades == cost and tower.combat_stats.invested_gold == 315 + cost and game.economy.gold == 1000000 - cost * 2, "all34 states have exact transaction and statistics costs")
				var stable: Array = _fields(tower.stats)
				tower.stats = TowerStatResolver.resolve(base, tower.tiers)
				_check(_fields(tower.stats) == stable and _fields(base) == original_fields, "repeated synthesis does not accumulate modifiers or mutate shared base")
				game.free()
	for build: Array in BUILDS:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var main: int = build.find(3)
		var secondary: int = build.find(2)
		var gold: int = game.economy.gold
		_check(not game.try_upgrade(tower, base.upgrade_at(secondary, 3)) and not game.try_upgrade(tower, base.upgrade_at(3 - main - secondary, 1)) and game.economy.gold == gold, "third path and second main reject without money changes")
		_check(base.upgrade_at(main, 4) != null and base.max_upgrade_tier(main) == 5 and game.upgrades.error_for_path(tower, main).is_empty(), "v014 catalog now exposes4 after the original tier3 domain")
		_check(not game.try_upgrade(tower, base.upgrade_at(main, 3)) and game.economy.gold == gold, "duplicate current upgrade rejected atomically")
		var index: int = BUILDS.find(build)
		var expected: Array = [[1, 15, 0.675, 0, 201.5625, 960, 5, 1820], [2, 15, 1.2, 2, 268.078125, 640, 5, 1795], [1, 13, 0.15, 0, 201.5625, 720, 3, 2470], [2, 4, 0.15, 2, 268.078125, 720, 3, 2390], [2, 27, 1.2, 2, 268.078125, 480, 3, 2495], [2, 18, 0.675, 2, 268.078125, 720, 3, 2440]][index]
		_check(tower.stats.damage == expected[0] and tower.stats.pierce == expected[1] and is_equal_approx(tower.stats.fire_interval, expected[2]), "independent crosspath damage/pierce/reload expectations")
		_check(tower.stats.attack_attribute == expected[3] and is_equal_approx(tower.stats.attack_range, expected[4]) and tower.stats.projectile_speed == expected[5] and tower.stats.projectile_lifetime == expected[6] and tower.combat_stats.invested_gold == expected[7], "independent crosspath attribute/range/speed/lifetime/total-cost expectations")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	game.economy.gold = 199
	_check(not game.try_upgrade(tower, base.upgrade_at(0, 1)) and game.economy.gold == 199, "insufficient funds do not change tower or money")
	game.economy.gold = 200
	var preview: TowerDefinition = TowerStatResolver.preview(base, tower.tiers, base.upgrade_at(0, 1))
	_check(game.try_upgrade(tower, base.upgrade_at(0, 1)) and game.economy.gold == 0 and _fields(tower.stats) == _fields(preview), "preview equals affordable purchase, exact funds accepted")
	game.free()
	var volleys: Array[int] = []
	for build: Array in [[0, 0, 0], [0, 3, 0]]:
		game = _game()
		tower = _tower(game, build)
		_dummy(game, Vector2(300, 350))
		for tick in range(3600):
			game.towers.update(MainGame.FIXED_STEP)
			game.projectiles.update(MainGame.FIXED_STEP)
		volleys.append(tower.combat_stats.volleys)
		game.free()
	_check(volleys == [50, 400], "Bionic really fires8x baseline over60 simulation seconds, no repeated prior reload multipliers: " + str(volleys))
	game = _game()
	tower = _tower(game, [2, 2, 0])
	_check(UpgradePolicy.main_path(tower.tiers) == -1 and game.try_upgrade(tower, base.upgrade_at(1, 3)), "2-2-0 remains undecided until actual tier3 choice")
	var stats: TowerDefinition = tower.stats
	_check(stats.pierce == 13 and is_equal_approx(stats.fire_interval, 0.15) and stats.moab_bonus == 1 and stats.projectile_speed == 720, "230 Bionic replaces previous reload multipliers without losing pierce/speed")
	_check(_tower(game, [2, 0, 3]).stats.pierce == 27 and _tower(game, [0, 2, 3]).stats.pierce == 18, "Kylie18 composes secondary4+5 pierce")
	_check(is_equal_approx(_tower(game, [3, 2, 0]).stats.fire_interval, 0.675) and _tower(game, [3, 0, 2]).stats.attack_attribute == AttackSpec.Attribute.NORMAL, "Ricochet speed and Normal crosspaths")
	game.free()

func _curves() -> void:
	var precise: TowerDefinition = TowerStatResolver.resolve(MainGame.BOOMERANG, PackedInt32Array([0, 0, 1]))
	var precision_game: MainGame = _game()
	var precise_shot: ProjectileState = precision_game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, precise)
	var maximum_error: float = 0.0
	for index in range(64):
		var phase: float = TAU * (index + 0.5) / 64.0
		var analytic: Vector2 = Vector2(200, 350) + Vector2(precise.flight_distance * (1.0 - cos(phase)) * 0.5, -precise.curve_width * sin(phase))
		maximum_error = maxf(maximum_error, analytic.distance_to(precise_shot.flight_points[index].lerp(precise_shot.flight_points[index + 1], 0.5)))
	_check(precise_shot.flight_points.size() == 65 and maximum_error < 0.25, "bounded64-segment authored curve, maximum midpoint ellipse deviation below0.25px at longest range")
	precision_game.free()
	for filtered in [false, true]:
		var moving_game: MainGame = _game()
		moving_game.projectiles.flight_broadphase_enabled = filtered
		var moving_data: TowerDefinition = MainGame.BOOMERANG.duplicate() as TowerDefinition
		moving_data.flight_distance = 200
		moving_data.curve_width = 50
		moving_data.projectile_speed = 400
		var moving_shot: ProjectileState = moving_game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, moving_data)
		var travel: float = 0.0
		for index in range(16):
			travel += moving_shot.flight_points[index].distance_to(moving_shot.flight_points[index + 1])
		var moving: BalloonState = _dummy(moving_game, Vector2(600, 600))
		moving.record_motion(PackedVector2Array([Vector2(600, 100), moving_shot.flight_points[16], Vector2(600, 600)]), 2.0)
		moving.motion_times = PackedFloat32Array([0.0, travel / 800.0, 1.0])
		moving_game.projectiles.update(2.0)
		_check(moving.shell_hp == 9999, "swept bounds include a moving balloon corner even when endpoint chord misses, filtered=" + str(filtered))
		moving_game.free()
	for steps in [1, 120]:
		var game: MainGame = _game()
		var data: TowerDefinition = MainGame.BOOMERANG.duplicate() as TowerDefinition
		data.pierce = 100
		data.flight_distance = 200
		data.curve_width = 50
		data.projectile_speed = 400
		var shot: ProjectileState = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, data)
		var first: BalloonState = _dummy(game, shot.flight_points[16])
		var tip: BalloonState = _dummy(game, shot.flight_points[32])
		var returning: BalloonState = _dummy(game, shot.flight_points[48])
		var chord: BalloonState = _dummy(game, Vector2(300, 350))
		for tick in range(steps):
			game.projectiles.update(2.0 / steps)
		_check(first.shell_hp == 9999 and tip.shell_hp == 9999 and returning.shell_hp == 9999, "actual curved middle segments and return hit exactly once, long/fixed steps")
		_check(chord.shell_hp == 10000, "curve never substitutes its straight endpoint chord for collision")
		_check(game.projectiles.projectiles.is_empty() and shot.position.distance_to(Vector2(200, 350)) < 0.0001, "completed roundtrip returns and is removed")
		_check(shot.hit_ids.size() == 3 and shot.remaining_pierce == 97, "ordinary rang retains ID history across outbound/return")
		game.free()
	var game: MainGame = _game()
	var data: TowerDefinition = MainGame.BOOMERANG.duplicate() as TowerDefinition
	data.pierce = 1
	var shot: ProjectileState = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, data)
	var a: BalloonState = _dummy(game, shot.flight_points[16])
	var b: BalloonState = _dummy(game, shot.flight_points[48])
	game.projectiles.update(2.0)
	_check(a.shell_hp == 9999 and b.shell_hp == 10000 and shot.remaining_pierce == 0 and game.projectiles.projectiles.is_empty(), "pierce exhaustion stops the curve at first physical contact")
	data.pierce = 0
	_check(game.projectiles.launch(Vector2.ZERO, Vector2.RIGHT, data) == null, "zero pierce cannot allocate a projectile")
	data.pierce = 1
	data.projectile_lifetime = 0.01
	shot = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, data)
	game.projectiles.update(1.0)
	_check(game.projectiles.projectiles.is_empty() and shot.age <= 0.010001, "lifetime clips curved motion and collision")
	game.free()

func _chains() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [3, 0, 0])
	var first: BalloonState = _dummy(game, Vector2(250, 350))
	var next: BalloonState = _dummy(game, Vector2(330, 350))
	var shot: ProjectileState = game.projectiles.fire(Vector2(200, 350), first, tower.stats, tower.id)
	game.projectiles.update(0.01)
	_check(first.shell_hp == 10000 and next.shell_hp == 10000, "chain is real travel, not instantaneous area damage")
	game.projectiles.update(0.05)
	_check(first.shell_hp == 9999 and next.shell_hp == 10000, "only physically reached first target hit")
	game.projectiles.update(0.5)
	_check(next.shell_hp == 9999 and game.projectiles.projectiles.is_empty(), "remaining step is replanned chronologically and ends with no candidates")
	game.free()
	for steps in [1, 120]:
		game = _game()
		tower = _tower(game, [3, 0, 0])
		var targets: Array[BalloonState] = []
		for index in range(20):
			targets.append(_dummy(game, Vector2(250 + index * 12, 350)))
		shot = game.projectiles.fire(Vector2(200, 350), targets[0], tower.stats, tower.id)
		for tick in range(steps):
			game.projectiles.update(2.0 / steps)
		_check(targets.filter(func(target: BalloonState) -> bool: return target.shell_hp == 9999).size() == 15 and targets.all(func(target: BalloonState) -> bool: return target.shell_hp >= 9999), "exactly fifteen unique targets, no revisit under long/fixed steps")
		_check(tower.combat_stats.effective_damage == 15 and tower.combat_stats.pierce_used == 15 and tower.combat_stats.targets_damaged == 15 and tower.combat_stats.volleys == 1, "chain actual damage, pierce, targets and one volley attribution")
		game.free()
	game = _game()
	tower = _tower(game, [3, 0, 0])
	first = _dummy(game, Vector2(250, 350))
	var lower_id: BalloonState = _dummy(game, Vector2(300, 330))
	var higher_id: BalloonState = _dummy(game, Vector2(300, 370))
	var data: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	data.pierce = 2
	shot = game.projectiles.fire(Vector2(200, 350), first, data, tower.id)
	game.projectiles.update(1.0)
	_check(lower_id.shell_hp == 9999 and higher_id.shell_hp == 10000, "equal-distance next targets use stable lower ID")
	game.free()
	game = _game()
	tower = _tower(game, [3, 0, 0])
	first = _dummy(game, Vector2(250, 350))
	next = _dummy(game, Vector2(300, 350))
	shot = game.projectiles.fire(Vector2(200, 350), first, tower.stats, tower.id)
	game.balloons._remove(first.array_index)
	game.projectiles.update(1.0)
	_check(next.shell_hp == 9999 and game.projectiles.projectiles.is_empty(), "lost initial target safely chooses a live valid ID without teleporting")
	game.free()
	game = _game()
	tower = _tower(game, [3, 0, 0])
	var parent: BalloonState = _at(game, "bfb", Vector2(250, 350))
	parent.shell_hp = 1
	shot = game.projectiles.fire(Vector2(200, 350), parent, tower.stats, tower.id)
	game.projectiles.update(1.0)
	_check(game.balloons.balloons.size() == 4 and game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.definition.id == &"moab" and child.shell_hp == 200), "chain excludes new split IDs in batch and keeps blimp overflow barrier")
	_check(tower.combat_stats.pops() == 1 and tower.combat_stats.gold_earned == 1, "one destroyed shell, not descendants' total RBE")
	game.free()

func _kylie() -> void:
	for steps in [1, 120]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 0, 3])
		var target: BalloonState = _dummy(game, Vector2(400, 350))
		var shot: ProjectileState = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, tower.stats, tower.id)
		for tick in range(steps):
			game.projectiles.update(2.0 / steps)
		_check(target.shell_hp == 9996 and tower.combat_stats.targets_damaged == 2 and shot.remaining_pierce == 16, "Kylie outbound and return damage independently with time eligibility")
		_check(game.projectiles.projectiles.is_empty() and shot.hit_times.size() == 1 and shot.max_bounces == 0, "Kylie timing is independent of Juggernaut bounce epochs")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 3])
	var target: BalloonState = _dummy(game, Vector2(387.5, 350), 200)
	var shot: ProjectileState = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, tower.stats, tower.id)
	game.projectiles.update(2.0)
	_check(target.shell_hp == 9988 and tower.combat_stats.targets_damaged == 6 and shot.remaining_pierce == 12, "long-step sustained overlap schedules each0.3s contact, not one per segment/frame")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 3])
	var data: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	data.projectile_speed = 10
	data.flight_distance = 100
	target = _dummy(game, Vector2(200, 350), 100)
	shot = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, data, tower.id)
	game.projectiles.update(0.299999)
	_check(target.shell_hp == 9998 and tower.combat_stats.targets_damaged == 1, "no rehit just before0.3s")
	game.projectiles.update(0.000001)
	_check(target.shell_hp == 9996 and is_equal_approx(float(shot.hit_times[target.id]), 0.3), "rehit allowed at exact0.3s boundary")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 3])
	var lead: BalloonState = _at(game, "lead", Vector2(400, 350), true)
	shot = game.projectiles.launch(Vector2(200, 350), Vector2.RIGHT, tower.stats, tower.id)
	for tick in range(120):
		game.projectiles.update(MainGame.FIXED_STEP)
	_check(game.balloons.find(lead.id) == null and game.balloons.balloons.size() == 2 and game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.definition.id == &"black" and child.shell_hp == 1), "return shell kill permanently excludes its own split children across later ticks")
	_check(tower.combat_stats.pops() == 1 and tower.combat_stats.effective_damage == 4 and tower.combat_stats.gold_earned == 1, "outbound HP chip plus return shell kill never duplicates reward/Pops")
	game.free()

func _attributes() -> void:
	for build: Array in [[0, 0, 0], [0, 0, 2], [3, 0, 0], [3, 0, 2], [0, 3, 0], [0, 3, 2], [0, 0, 3]]:
		for kind in ["lead", "black", "white", "ceramic", "moab", "bfb", "zomg", "bad", "ddt"]:
			var game: MainGame = _game()
			var tower: TowerState = _tower(game, build)
			var target: BalloonState = _at(game, kind, Vector2(300, 350), kind == "ceramic")
			var profile: TowerDefinition = tower.stats
			var expected: int = profile.damage + (profile.moab_bonus if target.definition.moab_class else 0)
			var can_hit: bool = kind != "ddt" and (kind != "lead" or build[2] >= 2)
			_check(game.combat.can_target(target, profile) == can_hit, "shared targeting respects type/camo independently " + str(build) + kind)
			var before: int = target.shell_hp
			var attack: AttackSpec = profile.make_attack()
			attack.source_id = tower.id
			var actual: int = game.combat.apply_hit(target.id, attack)
			_check(actual == (mini(before, expected) if target.definition.moab_class or kind == "ceramic" else (expected if can_hit else 0)) if kind not in ["lead", "black", "white", "ddt"] else (actual > 0) == can_hit, "actual confirmed HP and MOAB bonus/type immunity " + str(build) + kind)
			if kind in ["moab", "bfb", "zomg", "bad", "ceramic"]:
				_check(tower.combat_stats.moab_damage == (actual if kind != "ceramic" else 0) and tower.combat_stats.pops() == 0, "HP-only contact has actual damage but no shell Pops/reward")
			target = _at(game, "moab", Vector2(300, 350), false, true)
			_check(not game.combat.can_target(target, profile) and game.combat.apply_hit(target.id, attack) == 0, "no boomerang path grants automatic camo detection")
			game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [3, 0, 2])
	var ddt: BalloonState = _at(game, "ddt", Vector2(300, 350))
	var attack: AttackSpec = tower.stats.make_attack()
	attack.detects_camo = true
	_check(game.combat.apply_hit(ddt.id, attack) == 2, "explicit detection plusNormal can hit composite DDT")
	attack.attribute = AttackSpec.Attribute.SHARP
	_check(game.combat.apply_hit(ddt.id, attack) == 0, "detection alone cannot bypass DDT Sharp immunity")
	game.free()

func _lifecycle() -> void:
	for build: Array in [[0, 0, 0], [3, 0, 0], [0, 0, 3]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var target: BalloonState = _dummy(game, Vector2(380, 350))
		var shot: ProjectileState = game.projectiles.fire(Vector2(200, 350), target, tower.stats, tower.id)
		var damage: int = shot.attack.damage
		var mode: int = shot.flight_mode
		if tower.tiers[2] < 2:
			game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(2, 1))
			game.try_upgrade(tower, MainGame.BOOMERANG.upgrade_at(2, 2))
		game.towers.remove_tower(tower)
		_check(shot.attack.damage == damage and shot.flight_mode == mode and shot.attack.source_id == tower.id, "launched attack retains stats/path/owner after upgrade and removal")
		for tick in range(360):
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(game.projectiles.projectiles.is_empty() and target.shell_hp < 10000 and tower.combat_stats.effective_damage > 0, "all flight modes expire and preserve removed owner damage attribution")
		game.free()

func battle(build: Array, speed: int, statistics: bool = true, broadphase: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.projectiles.flight_broadphase_enabled = broadphase
	game.battle_stats.enabled = statistics
	var tower: TowerState = _tower(game, build)
	for index in range(50):
		game.balloons.spawn(load("res://data/balloons/%s.tres" % ["green", "lead", "ceramic", "moab", "black"][index % 5]), 450.0 + index * 3.0, index % 9 == 0, index % 3 == 0, true)
	game.simulation_speed = speed
	for frame in range(1200 / speed):
		game._process(MainGame.FIXED_STEP)
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance, balloon.camo, balloon.fortified])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var report: Dictionary = {"build": build, "combat": [live, game.economy.gold, game.economy.lives, game.projectiles._next_id, tower.attack_counter], "pops": game.battle_stats.total_pops, "damage": tower.combat_stats.effective_damage, "volleys": tower.combat_stats.volleys, "invested": tower.combat_stats.invested_gold}
	var flights: Array = []
	for shot in game.projectiles.projectiles:
		flights.append([shot.id, shot.position, shot.remaining_pierce, shot.lifetime, shot.age, shot.flight_index, shot.target_id, shot.hit_times.duplicate()])
	report.combat.append(flights)
	report.combat.append(tower.cooldown)
	game.free()
	return report
