extends "res://tests/boomerang_tests.gd"

var _mode: int = 3
var _observe: bool = false

func _game() -> MainGame:
	var game: MainGame = super._game()
	game.projectiles.chain_cache_mode = _mode
	if _observe:
		game.projectiles.trace = CombatTrace.new()
		game.combat.trace = game.projectiles.trace
	return game

func run(window: Window) -> Dictionary:
	_root = window
	_boundaries()
	_live_mutations()
	var reference_events: Dictionary = _simultaneous(0)
	var optimized_events: Dictionary = _simultaneous(3)
	_check(reference_events == optimized_events, "same-time full event stream and final HP/economy equal reference")
	var ids: Array = []
	for event: Array in optimized_events.events:
		ids.append(event[0])
	_check(ids.size() == 60, "four simultaneous glaives each resolve exactly15 contacts")
	var ordered: bool = true
	for index in range(ids.size()):
		ordered = ordered and ids[index] == 1 + index / 15
	_check(ordered and optimized_events.projectiles == 0, "equal-time queue preserves projectile-ID order and simultaneous cleanup")
	for seed in range(8):
		_selection_sequence(seed)
	for build: Array in BUILDS:
		_mode = 0
		var baseline: Dictionary = battle(build, 1)
		for mode in [1, 2, 3]:
			_mode = mode
			_check(baseline == battle(build, 1), "six full battles preserve exact HP/IDs/positions/cooldowns under search mode " + str(mode))
		_mode = 3
		_check(baseline == battle(build, 2), "equal game duration1x/2x remains exact under optimization")
		_check(baseline.combat == battle(build, 1, false).combat, "statistics are not a ranking or lifetime input")
		_observe = true
		_check(baseline == battle(build, 1), "detailed observer does not affect decisions or rewards")
		_observe = false
	print("CHAIN OPTIMIZATION TESTS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _simultaneous(mode: int) -> Dictionary:
	_mode = mode
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [3, 2, 0])
	game.projectiles.trace = CombatTrace.new()
	game.projectiles.trace.record_events = true
	var target: BalloonState
	for index in range(20):
		target = _at(game, "moab", Vector2(300, 350))
	for index in range(4):
		game.projectiles.fire(Vector2(200, 350), target, tower.stats, tower.id)
	game.projectiles.update(1.0)
	var hp: Array = []
	for balloon in game.balloons.balloons:
		hp.append([balloon.id, balloon.shell_hp])
	var result: Dictionary = {"events": game.projectiles.trace.events.duplicate(true), "hp": hp, "gold": game.economy.gold, "pops": game.battle_stats.total_pops, "projectiles": game.projectiles.projectiles.size()}
	game.free()
	return result

func _shot(game: MainGame, at: Vector2 = Vector2(200, 350)) -> ProjectileState:
	var data: TowerDefinition = TowerStatResolver.resolve(MainGame.BOOMERANG, PackedInt32Array([3, 0, 0]))
	return ProjectileState.new(1, at, Vector2.RIGHT, data)

func _pick(game: MainGame, shot: ProjectileState, time: float, maximum: int) -> int:
	game.projectiles.chain_cache_mode = 0
	var reference: BalloonState = game.projectiles._chain_target(shot, time, maximum)
	game.projectiles.chain_cache_mode = 3
	var cached: BalloonState = game.projectiles._chain_target(shot, time, maximum)
	_check(cached == reference, "exact target matches reference after current live changes")
	return -1 if cached == null else cached.id

func _boundaries() -> void:
	var game: MainGame = _game()
	var shot: ProjectileState = _shot(game)
	var edge: BalloonState = _dummy(game, shot.position + Vector2(shot.chain_range, 0))
	_dummy(game, shot.position + Vector2(shot.chain_range + 0.0001, 0))
	game.projectiles._resolving = true
	for repeat in range(3):
		_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == edge.id, "range boundary included at unchanged float64 distance")
	shot.hit_ids[edge.id] = true
	_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == -1, "just-outside target is never admitted by ranking")
	game.projectiles._resolving = false
	game.projectiles.update(MainGame.FIXED_STEP)
	_check(game.projectiles._chain_candidates.is_empty() and game.projectiles._chain_ordered.is_empty() and game.projectiles._chain_groups.is_empty(), "batch end releases every candidate reference and ranking")
	game.free()
	game = _game()
	shot = _shot(game)
	var a: BalloonState = _dummy(game, Vector2(210, 350))
	var b: BalloonState = _dummy(game, Vector2(230, 350))
	a.record_motion(PackedVector2Array([Vector2(210, 350), Vector2(260, 350)]), MainGame.FIXED_STEP)
	b.record_motion(PackedVector2Array([Vector2(230, 350), Vector2(205, 350)]), MainGame.FIXED_STEP)
	game.projectiles._resolving = true
	for repeat in range(3):
		_check(_pick(game, shot, 0.0, game.balloons.latest_id()) == a.id, "motion at time0 uses exact first endpoint")
	for repeat in range(3):
		_check(_pick(game, shot, 1.0, game.balloons.latest_id()) == b.id, "different time invalidates previous geometric ordering")
	shot.position = Vector2(270, 350)
	_check(_pick(game, shot, 1.0, game.balloons.latest_id()) == a.id, "origin change invalidates exact query key")
	shot.chain_range = 5.0
	_check(_pick(game, shot, 1.0, game.balloons.latest_id()) == -1, "radius change does not reuse a wider eligibility decision")
	game.free()

func _live_mutations() -> void:
	var game: MainGame = _game()
	var shot: ProjectileState = _shot(game)
	var hidden: BalloonState = _at(game, "blue", Vector2(205, 350), false, true)
	var immune: BalloonState = _at(game, "lead", Vector2(210, 350))
	var visible: BalloonState = _at(game, "blue", Vector2(215, 350))
	game.projectiles._resolving = true
	for repeat in range(3):
		_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == visible.id, "sorted cache never freezes camo/immunity as eligible")
	hidden.remove_camo()
	_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == hidden.id, "camo removal is rechecked even for earlier rejected candidate")
	game.balloons._remove(hidden.array_index)
	immune.set_layer(load("res://data/balloons/blue.tres"))
	_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == immune.id, "same-time removal and immunity/layer change are live inputs")
	shot.hit_ids[immune.id] = true
	_check(_pick(game, shot, 0.5, game.balloons.latest_id()) == visible.id, "per-shot hit history remains independent from geometry cache")
	var maximum: int = game.balloons.latest_id()
	var child: BalloonState = _at(game, "red", Vector2(201, 350))
	_check(_pick(game, shot, 0.5, maximum) == visible.id, "new child ID stays excluded despite index rebuilding")
	_check(_pick(game, shot, 0.5, child.id) == child.id, "different maxID starts a new membership query")
	game.projectiles._resolving = false
	game.projectiles.update(MainGame.FIXED_STEP)
	game.balloons._remove(child.array_index)
	game.balloons._remove(visible.array_index)
	game.balloons._remove(immune.array_index)
	game.projectiles.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.is_empty() and game.balloons.balloons.is_empty() and game.projectiles._chain_groups.is_empty(), "all targets gone leaves no retained attacks or cached objects")
	game.free()

func _selection_sequence(seed: int) -> void:
	var game: MainGame = _game()
	var shot: ProjectileState = _shot(game)
	var kinds: Array[String] = ["blue", "black", "lead", "white", "moab", "ddt", "bad", "ceramic"]
	for index in range(128):
		var at: Vector2 = Vector2(200 + ((index * 73 + seed * 19) % 301) - 150, 350 + ((index * 37 + seed * 11) % 201) - 100)
		var balloon: BalloonState = _at(game, kinds[index % kinds.size()], at, false, index % 7 == 0)
		balloon.record_motion(PackedVector2Array([at - Vector2(5, 7), at + Vector2(3, -1), at]), MainGame.FIXED_STEP)
	game.projectiles._resolving = true
	var seen: Dictionary = {}
	for index in range(24):
		var id: int = _pick(game, shot, 0.75, game.balloons.latest_id())
		_check(id > 0 and not seen.has(id), "dense moving selection never revisits an excluded ID")
		seen[id] = true
		if index % 3 == 0:
			game.balloons._remove(game.balloons.find(id).array_index)
		else:
			shot.hit_ids[id] = true
	game.projectiles._resolving = false
	game.projectiles.update(MainGame.FIXED_STEP)
	_check(game.projectiles._chain_time < 0.0 and game.projectiles._chain_groups.is_empty(), "candidate storage expires before the next simulation step")
	game.free()
