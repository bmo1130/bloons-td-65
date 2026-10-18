extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const BLUE: BalloonDefinition = preload("res://data/balloons/blue.tres")
const GREEN: BalloonDefinition = preload("res://data/balloons/green.tres")
const YELLOW: BalloonDefinition = preload("res://data/balloons/yellow.tres")
const DART: TowerDefinition = preload("res://data/towers/dart.tres")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_test_damage_matrix()
	_test_projectile_damage_matrix()
	_test_leaks_and_speed()
	_test_pierce_and_order()
	_test_no_repeat_and_overkill()
	_test_overlap_and_removed_targets()
	_test_continuous_collision()
	_test_lifetime_and_event_order()
	_test_exit_and_shrinking_layers()
	_test_spatial_candidates()
	_test_wave_data()
	_test_wave_speed_consistency()
	print("V0.2 COMBAT: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _new_game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	return game

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

func _stats(pierce: int, damage: int = 1, speed: float = 1000.0) -> TowerDefinition:
	var data: TowerDefinition = DART.duplicate() as TowerDefinition
	data.pierce = pierce
	data.damage = damage
	data.projectile_speed = speed
	return data

func _at(game: MainGame, definition: BalloonDefinition, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(definition)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _test_damage_matrix() -> void:
	var definitions: Array[BalloonDefinition] = [RED, BLUE, GREEN, YELLOW]
	for definition in definitions:
		for damage in [0, 1, 2, 3, 4, 12]:
			var game: MainGame = _new_game()
			var balloon: BalloonState = game.balloons.spawn(definition)
			balloon.distance = 100.0
			balloon.position = game.route.position_at(100.0)
			var layers: int = definition.layer_count()
			var expected: int = maxi(0, layers - damage)
			var actual: int = game.balloons.damage(balloon.id, damage)
			var survivor: BalloonState = game.balloons.find(balloon.id)
			_check(actual == mini(layers, damage), "%s damage %d removes only available layers" % [definition.id, damage])
			_check((survivor == null and expected == 0) or (survivor != null and survivor.definition.layer_count() == expected), "%s damage %d leaves correct layer" % [definition.id, damage])
			_check(game.economy.gold == 200 + mini(layers, damage), "damage %d pays exact layer rewards" % damage)
			if survivor != null:
				_check(survivor == balloon and survivor.distance == 100.0, "multi-damage preserves survivor identity/progress")
			game.free()
	var game: MainGame = _new_game()
	var rewarded: BalloonDefinition = BLUE.duplicate() as BalloonDefinition
	rewarded.pop_reward = 7
	var balloon: BalloonState = game.balloons.spawn(rewarded)
	game.balloons.damage(balloon.id, 20)
	_check(game.economy.gold == 208, "each removed layer uses its own reward data")
	game.free()

func _test_leaks_and_speed() -> void:
	var definitions: Array[BalloonDefinition] = [RED, BLUE, GREEN, YELLOW]
	_check(RED.speed < BLUE.speed and BLUE.speed < GREEN.speed and GREEN.speed < YELLOW.speed, "data speeds increase by color")
	for index in range(definitions.size()):
		var game: MainGame = _new_game()
		var balloon: BalloonState = game.balloons.spawn(definitions[index])
		game.balloons.update(0.1)
		_check(is_equal_approx(balloon.distance, definitions[index].speed * 0.1), "data-driven movement speed")
		balloon.distance = game.route.total_length - 0.01
		game.balloons.update(0.1)
		_check(game.economy.lives == 20 - (index + 1), "leak damage equals remaining layers")
		_check(game.economy.gold == 200, "all colors leak without rewards")
		game.free()

	for damage in [1, 2, 3]:
		var game: MainGame = _new_game()
		var balloon: BalloonState = game.balloons.spawn(YELLOW)
		game.balloons.damage(balloon.id, damage)
		game.balloons.update(0.1)
		_check(is_equal_approx(balloon.distance, definitions[3 - damage].speed * 0.1), "multi-layer downgrade changes speed")
		balloon.distance = game.route.total_length - 0.01
		game.balloons.update(0.1)
		_check(game.economy.lives == 20 - (4 - damage), "downgraded leak uses remaining layers")
		_check(game.economy.gold == 200 + damage, "downgraded leak gives no extra reward")
		game.free()

func _test_projectile_damage_matrix() -> void:
	for damage in [1, 2, 3, 4]:
		var game: MainGame = _new_game()
		var balloon: BalloonState = _at(game, YELLOW, Vector2(200, 300))
		var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1, damage))
		game.projectiles.update(0.2)
		var survivor: BalloonState = game.balloons.find(balloon.id)
		_check((survivor == null and damage == 4) or (survivor != null and survivor.definition.layer_count() == 4 - damage), "projectile damage %d resolves yellow layers" % damage)
		_check(game.economy.gold == 200 + damage, "projectile multi-layer reward is exact")
		_check(shot.hit_ids.size() == 1 and shot.remaining_pierce == 0, "damage amount never changes pierce consumption")
		game.free()

func _test_pierce_and_order() -> void:
	for pierce in [1, 2, 3]:
		var game: MainGame = _new_game()
		var targets: Array[BalloonState] = []
		# Deliberately reverse insertion/progress order: physical contact must win.
		for x in [400, 300, 200]:
			targets.append(_at(game, RED, Vector2(x, 300)))
		var miss: BalloonState = _at(game, RED, Vector2(220, 350))
		var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(pierce))
		game.projectiles.update(0.4)
		_check(game.balloons.balloons.size() == 4 - pierce, "pierce %d hits exactly that many balloons" % pierce)
		_check(game.economy.gold == 200 + pierce, "pierce reward counts distinct balloons")
		_check(shot.remaining_pierce == 0 and game.projectiles.projectiles.is_empty(), "exhausted dart removed")
		_check(game.balloons.find(miss.id) != null, "off-trajectory balloon is not hit")
		for index in range(3):
			_check((game.balloons.find(targets[index].id) == null) == (index >= 3 - pierce), "geometric hit order independent of storage/target order")
		_check(shot.position.is_equal_approx(Vector2(200 + (pierce - 1) * 100 - 14.5, 300)), "dart ends at actual last contact point")
		game.free()

func _test_no_repeat_and_overkill() -> void:
	var game: MainGame = _new_game()
	var balloon: BalloonState = _at(game, YELLOW, Vector2(200, 300))
	var shot: ProjectileState = game.projectiles.launch(Vector2(185, 300), Vector2.RIGHT, _stats(3, 1, 10.0))
	game.projectiles.update(0.1)
	_check(balloon.definition == GREEN and shot.remaining_pierce == 2, "one hit downgrades yellow and spends one pierce")
	for tick in range(20):
		game.projectiles.update(0.01)
	_check(balloon.definition == GREEN and game.economy.gold == 201, "same dart never re-hits changed layer while overlapping")
	_check(shot.hit_ids.size() == 1 and shot.remaining_pierce == 2, "repeat overlap spends no extra pierce")
	var second: ProjectileState = game.projectiles.launch(Vector2(190, 300), Vector2.RIGHT, _stats(1))
	game.projectiles.update(0.01)
	_check(balloon.definition == BLUE and second.hit_ids.has(balloon.id), "a different dart may hit the same balloon")
	game.free()
	game = _new_game()
	var first: BalloonState = _at(game, BLUE, Vector2(200, 300))
	var next: BalloonState = _at(game, YELLOW, Vector2(260, 300))
	shot = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(2, 3))
	game.projectiles.update(0.3)
	_check(game.balloons.find(first.id) == null and next.definition == RED, "damage 3 applies independently at each pierce hit")
	_check(game.economy.gold == 205 and shot.remaining_pierce == 0, "overkill pays 2+3 layers, spends only two pierce")
	game.free()
	game = _new_game()
	_at(game, RED, Vector2(200, 300))
	var untouched: BalloonState = _at(game, YELLOW, Vector2(250, 300))
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1, 12))
	game.projectiles.update(0.3)
	_check(untouched.definition == YELLOW and game.economy.gold == 201, "excess damage does not spill beyond pierce budget")
	game.free()

func _test_overlap_and_removed_targets() -> void:
	var game: MainGame = _new_game()
	for count in range(4):
		_at(game, BLUE, Vector2(220, 300))
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(3, 2))
	game.projectiles.update(0.3)
	_check(game.balloons.balloons.size() == 1 and game.economy.gold == 206, "overlapping blue balloons accept three independent damage-2 hits")
	_check(shot.hit_ids.size() == 3, "overlap candidate duplicated across grid cells is hit once")
	game.free()
	game = _new_game()
	var aim: BalloonState = _at(game, RED, Vector2(200, 300))
	var behind: BalloonState = _at(game, RED, Vector2(260, 300))
	shot = game.projectiles.fire(Vector2(100, 300), aim, _stats(1))
	game.balloons.damage(aim.id, 1)
	game.projectiles.update(0.3)
	_check(game.balloons.find(behind.id) == null and shot.hit_ids.has(behind.id), "lost aim target does not prevent a later physical hit")
	_check(game.economy.gold == 202, "removed target and new hit each pay only once")
	game.free()

func _test_continuous_collision() -> void:
	var game: MainGame = _new_game()
	var balloon: BalloonState = _at(game, RED, Vector2(200, 300))
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1, 1, 30000.0))
	game.projectiles.update(1.0 / 60.0)
	_check(game.balloons.find(balloon.id) == null, "fast dart cannot tunnel through stationary balloon")
	game.free()
	game = _new_game()
	balloon = _at(game, RED, Vector2(200, 400))
	balloon.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400)]), 0.1)
	shot = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1, 1, 2000.0))
	game.projectiles.update(0.1)
	_check(game.balloons.find(balloon.id) == null, "moving balloon and dart collide between their endpoints")
	game.free()
	game = _new_game()
	balloon = _at(game, RED, Vector2(200, 400))
	balloon.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400)]), 0.1)
	shot = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1, 1, 4000.0))
	game.projectiles.update(0.1)
	_check(game.balloons.find(balloon.id) != null, "paths crossing at different times do not collide")
	game.free()
	game = _new_game()
	balloon = _at(game, RED, Vector2(300, 400))
	balloon.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400), Vector2(300, 400)]), 0.1)
	game.projectiles.launch(Vector2(200, 300), Vector2.RIGHT, _stats(1, 1, 1000.0))
	game.projectiles.update(0.1)
	_check(game.balloons.find(balloon.id) != null, "corner traversal does not collide along a diagonal shortcut")
	game.free()
	game = _new_game()
	balloon = _at(game, RED, Vector2(300, 400))
	balloon.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400), Vector2(300, 400)]), 0.1)
	shot = game.projectiles.launch(Vector2(150, 300), Vector2.RIGHT, _stats(1, 1, 1500.0))
	game.projectiles.update(0.1)
	_check(game.balloons.find(balloon.id) == null, "CCD respects separate segments through a path corner")
	game.free()

func _test_lifetime_and_event_order() -> void:
	var game: MainGame = _new_game()
	var near: BalloonState = _at(game, RED, Vector2(130, 300))
	var far: BalloonState = _at(game, RED, Vector2(300, 300))
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(3))
	shot.lifetime = 0.05
	game.projectiles.update(0.4)
	_check(game.balloons.find(near.id) == null, "impact before expiration still applies")
	_check(game.balloons.find(far.id) != null, "no impact beyond expiration distance")
	_check(game.projectiles.projectiles.is_empty(), "unspent dart expires")
	game.free()
	game = _new_game()
	var shared: BalloonState = _at(game, RED, Vector2(200, 300))
	var further: BalloonState = _at(game, RED, Vector2(260, 300))
	var later: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1))
	var earlier: ProjectileState = game.projectiles.launch(Vector2(170, 300), Vector2.RIGHT, _stats(1))
	game.projectiles.update(0.3)
	_check(earlier.hit_ids.has(shared.id) and later.hit_ids.has(further.id), "all projectiles resolve in physical time order")
	_check(game.economy.gold == 202, "simultaneous removal candidates cannot duplicate rewards")
	game.free()

func _test_spatial_candidates() -> void:
	var game: MainGame = _new_game()
	_at(game, RED, Vector2(200, 300))
	for index in range(400):
		_at(game, RED, Vector2(600 + index % 40 * 12, 600 + index / 40 * 12))
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1))
	game.projectiles.update(0.15)
	_check(game.projectiles.collision_checks < 10, "spatial grid avoids scanning 400 distant balloons")
	_check(game.balloons.balloons.size() == 400, "local shot hits only the nearby balloon")
	game.free()

func _test_exit_and_shrinking_layers() -> void:
	var game: MainGame = _new_game()
	var balloon: BalloonState = game.balloons.spawn(BLUE)
	balloon.distance = game.route.total_length - 10.0
	balloon.position = game.route.position_at(balloon.distance)
	var shot: ProjectileState = game.projectiles.launch(balloon.position - Vector2(20, 0), Vector2.RIGHT, _stats(1, 1, 1000.0))
	game.balloons.update(0.1, true)
	game.projectiles.update(0.1)
	game.balloons.resolve_leaks()
	_check(game.economy.gold == 201 and game.economy.lives == 19, "impact before exit charges only surviving red layer")
	_check(game.balloons.balloons.is_empty(), "deferred exiting balloon is removed once")
	game.free()
	game = _new_game()
	balloon = game.balloons.spawn(RED)
	balloon.distance = game.route.total_length - 1.0
	balloon.position = game.route.position_at(balloon.distance)
	shot = game.projectiles.launch(balloon.position - Vector2(100, 0), Vector2.RIGHT, _stats(1, 1, 1000.0))
	game.balloons.update(0.1, true)
	game.projectiles.update(0.1)
	game.balloons.resolve_leaks()
	_check(game.economy.gold == 200 and game.economy.lives == 19, "no impact after a balloon has already crossed the exit")
	game.free()
	game = _new_game()
	balloon = _at(game, BLUE, Vector2(200, 300))
	game.projectiles.launch(Vector2(180, 300), Vector2.RIGHT, _stats(1))
	var late: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1))
	late.lifetime = 0.0845
	game.projectiles.update(0.1)
	_check(balloon.definition == RED and game.economy.gold == 201, "shrinking radius postpones contact beyond dart lifetime")
	_check(not late.hit_ids.has(balloon.id), "stale large-circle candidate does not consume pierce")
	game.free()
	game = _new_game()
	balloon = _at(game, BLUE, Vector2(200, 300))
	game.projectiles.launch(Vector2(180, 300), Vector2.RIGHT, _stats(1))
	late = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _stats(1))
	game.projectiles.update(0.1)
	_check(game.balloons.find(balloon.id) == null and game.economy.gold == 202, "recomputed small-circle contact still applies when reachable")
	_check(is_equal_approx(late.position.x, 185.5), "second contact uses red radius instead of former blue radius")
	game.free()

func _test_wave_speed_consistency() -> void:
	var normal: Dictionary = _play(1)
	var fast: Dictionary = _play(2)
	_check(normal.result == &"victory" and fast.result == &"victory", "four-color waves are playable at both speeds")
	_check(normal == fast, "1x and 2x have identical lives, gold, popped layers and shots")
	_check(normal.gold + (20 - normal.lives) == 205, "new waves conserve 110 layer rewards/leaks and 90 clear rewards")
	print("V0.2 PLAY: %s" % normal)

func _test_wave_data() -> void:
	var game: MainGame = _new_game()
	var colors: Dictionary = {}
	var has_dense_group: bool = false
	for wave in game.waves.waves:
		for group in wave.groups:
			colors[group.balloon.id] = true
			if group.balloon.speed * group.interval < group.balloon.radius * 2.0:
				has_dense_group = true
	_check(colors.size() == 4 and colors.has(&"yellow") and colors.has(&"green"), "playable waves contain all four colors")
	_check(has_dense_group, "waves contain overlapping formations for visible pierce")
	game.free()

func _play(speed: int) -> Dictionary:
	var game: MainGame = _new_game()
	game.simulation_speed = speed
	var layers: Array[int] = [0]
	game.balloons.layer_popped.connect(func(reward: int) -> void: layers[0] += reward)
	for at in [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232)]:
		game.try_place_tower(at)
	for wave in range(3):
		game.start_next_wave()
		# Deliver wave-start input at identical simulation times (0/90/180 s),
		# not at render-frame boundaries that can add a different idle tick at 2x.
		for frame in range(60 * 90 / speed):
			game._process(1.0 / 60.0)
			if game.result != &"":
				break
	var report: Dictionary = {"result": game.result, "gold": game.economy.gold,
		"lives": game.economy.lives, "layers": layers[0], "wave": game.waves.current_wave,
		"shots": game.projectiles._next_id - 1}
	game.free()
	return report
