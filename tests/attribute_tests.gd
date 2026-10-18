extends RefCounted

const MAIN: PackedScene = preload("res://tests/fixtures/v05_main.tscn")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const BLUE: BalloonDefinition = preload("res://data/balloons/blue.tres")
const PINK: BalloonDefinition = preload("res://data/balloons/pink.tres")
const BLACK: BalloonDefinition = preload("res://data/balloons/black.tres")
const LEAD: BalloonDefinition = preload("res://data/balloons/lead.tres")
const SHARP: AttackSpec.Attribute = AttackSpec.Attribute.SHARP
const EXPLOSIVE: AttackSpec.Attribute = AttackSpec.Attribute.EXPLOSIVE
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_test_data_and_immunity()
	_test_split_economy()
	_test_split_at_exit()
	_test_immune_pierce_and_descendants()
	_test_target_selection_and_context()
	_test_aoe_boundary_and_budget()
	_test_bomb_contact()
	_test_batch_and_reference_safety()
	_test_mixed_play()
	print("V0.3 ATTRIBUTES: %d checks, %d failures" % [_checks, _failures])
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

func _at(game: MainGame, data: BalloonDefinition, position: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 100.0)
	balloon.position = position
	balloon.record_motion(PackedVector2Array([position, position]), 0.0)
	return balloon

func _shot(kind: AttackSpec.Attribute, pierce: int = 1, damage: int = 1, radius: float = 0.0, speed: float = 1000.0) -> TowerDefinition:
	var data: TowerDefinition = MainGame.DART.duplicate() as TowerDefinition
	data.attack_attribute = kind
	data.pierce = pierce
	data.damage = damage
	data.explosion_radius = radius
	data.projectile_speed = speed
	return data

func _valid_tree(data: BalloonDefinition, visiting: Dictionary) -> bool:
	if visiting.has(data) or (data.next_layer != null and not data.split_children.is_empty()):
		return false
	if data.next_layer != null and data.next_layer.radius > data.radius:
		return false
	var path: Dictionary = visiting.duplicate()
	path[data] = true
	if data.next_layer != null and not _valid_tree(data.next_layer, path):
		return false
	for child in data.split_children:
		if not child is BalloonDefinition or not _valid_tree(child as BalloonDefinition, path):
			return false
	return true

func _test_data_and_immunity() -> void:
	var all: Array[BalloonDefinition] = [RED, BLUE, preload("res://data/balloons/green.tres"),
		preload("res://data/balloons/yellow.tres"), PINK, BLACK, LEAD]
	for data in all:
		_check(_valid_tree(data, {}), "%s has valid acyclic transition/split data" % data.id)
		for kind in [SHARP, EXPLOSIVE]:
			var game: MainGame = _game()
			var balloon: BalloonState = game.balloons.spawn(data)
			var immune: bool = (data == BLACK and kind == EXPLOSIVE) or (data == LEAD and kind == SHARP)
			var removed: int = game.combat.apply_hit(balloon.id, AttackSpec.new(1, 1, kind))
			_check(removed == (0 if immune else 1), "%s vs %s damage eligibility" % [data.id, AttackSpec.attribute_name(kind)])
			_check(game.economy.gold == 400 + removed, "immune hit never rewards gold")
			if immune:
				_check(game.balloons.find(balloon.id) == balloon and balloon.definition == data, "immune hit does not transform/split")
			game.free()
	_check(PINK.speed > preload("res://data/balloons/yellow.tres").speed, "pink is faster than yellow")
	_check(PINK.layer_count() == 5 and BLACK.layer_count() == 11 and LEAD.layer_count() == 23, "tree layer values include all descendants")
	var game: MainGame = _game()
	var renamed: BalloonDefinition = LEAD.duplicate() as BalloonDefinition
	renamed.id = &"not_named_lead"
	_check(not game.combat.can_damage(renamed, SHARP), "immunity uses attribute mask, not balloon name")
	var data: TowerDefinition = _shot(EXPLOSIVE)
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, data)
	data.attack_attribute = SHARP
	data.damage = 99
	_check(shot.attack.attribute == EXPLOSIVE and shot.damage == 1, "attack snapshot stays independent of later tower data")
	game.free()

func _test_split_economy() -> void:
	var game: MainGame = _game()
	var pink: BalloonState = game.balloons.spawn(PINK, 123.0)
	game.combat.apply_hit(pink.id, AttackSpec.new(1, 1, SHARP))
	_check(game.balloons.find(pink.id) == pink and pink.definition.id == &"yellow", "pink changes to yellow with same ID")
	game.combat.apply_hit(pink.id, AttackSpec.new(10, 1, SHARP))
	_check(game.economy.gold == 405 and game.balloons.balloons.is_empty(), "pink overkill pays exactly five layers")
	game.free()
	game = _game()
	var parent: BalloonState = game.balloons.spawn(BLACK, 321.0)
	var position: Vector2 = parent.position
	var ignored: Dictionary = {}
	_check(game.combat.apply_hit(parent.id, AttackSpec.new(100, 1, SHARP), 1.0, ignored) == 1, "branch discards excess damage")
	_check(game.balloons.find(parent.id) == null and game.balloons.balloons.size() == 2, "black shell produces two new balloons")
	for child in game.balloons.balloons:
		_check(child.definition == PINK and child.id != parent.id, "black children have pink data and new IDs")
		_check(child.distance == 321.0 and child.position == position, "children inherit exact path progress and position")
		_check(ignored.has(child.id), "source attack excludes its descendants")
	_check(game.economy.gold == 401, "split rewards outer shell only")
	var children: Array[BalloonState] = game.balloons.balloons.duplicate()
	for child in children:
		game.combat.apply_hit(child.id, AttackSpec.new(100, 1, SHARP))
	_check(game.economy.gold == 411 and game.balloons.balloons.is_empty(), "full black tree pays exactly 11 gold")
	game.free()
	game = _game()
	parent = game.balloons.spawn(LEAD, 400.0)
	game.combat.apply_hit(parent.id, AttackSpec.new(999, 1, EXPLOSIVE))
	_check(game.balloons.balloons.size() == 2 and game.economy.gold == 401, "lead creates two black shells without damage propagation")
	children = game.balloons.balloons.duplicate()
	for child in children:
		_check(child.definition == BLACK, "lead child is explosive-immune black")
		game.combat.apply_hit(child.id, AttackSpec.new(999, 1, SHARP))
	children = game.balloons.balloons.duplicate()
	_check(children.size() == 4, "two black shells create four pink children")
	for child in children:
		game.combat.apply_hit(child.id, AttackSpec.new(999, 1, SHARP))
	_check(game.economy.gold == 423 and game.balloons.balloons.is_empty(), "full lead tree pays exactly 23 gold")
	game.free()

func _test_split_at_exit() -> void:
	var game: MainGame = _game()
	for data in [PINK, BLACK, LEAD]:
		var balloon: BalloonState = game.balloons.spawn(data, game.route.total_length - 0.1)
		_check(balloon.definition.leak_damage == data.layer_count(), "leak value matches unpopped subtree")
	game.balloons.update(0.1)
	_check(game.economy.lives == 11 and game.economy.gold == 400, "pink+black+lead leaks cost 5+11+23 lives without rewards")
	game.free()
	game = _game()
	var parent: BalloonState = game.balloons.spawn(BLACK, game.route.total_length - 4.0)
	game.balloons.update(0.1, true)
	var expected_distance: float = parent.distance_at_time(0.2)
	var expected_position: Vector2 = parent.position_at_time(0.2)
	game.combat.apply_hit(parent.id, AttackSpec.new(10, 1, SHARP), 0.2)
	game.balloons.resolve_leaks()
	_check(game.economy.lives == 50 and game.balloons.balloons.size() == 2, "split before exit does not charge removed parent or newborns early")
	for child in game.balloons.balloons:
		_check(is_equal_approx(child.distance, expected_distance) and child.position.is_equal_approx(expected_position), "mid-step split inherits contact-time path position")
	game.balloons.update(0.1)
	_check(game.economy.lives == 40 and game.economy.gold == 401, "later child leaks plus shell reward conserve black value")
	game.free()

func _test_immune_pierce_and_descendants() -> void:
	var game: MainGame = _game()
	var lead: BalloonState = _at(game, LEAD, Vector2(200, 300))
	var red: BalloonState = _at(game, RED, Vector2(240, 300))
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(SHARP))
	game.projectiles.update(0.3)
	_check(game.balloons.find(lead.id) != null and game.balloons.find(red.id) == null, "sharp dart passes immune lead and hits red")
	_check(shot.remaining_pierce == 0 and game.economy.gold == 401, "immune contact does not consume pierce or reward")
	game.free()
	game = _game()
	_at(game, BLACK, Vector2(200, 300))
	shot = game.projectiles.launch(Vector2(185, 300), Vector2.RIGHT, _shot(SHARP, 3, 100, 0.0, 10.0))
	game.projectiles.update(0.1)
	game.projectiles.update(0.1)
	_check(game.balloons.balloons.size() == 2 and game.balloons.balloons[0].definition == PINK, "same dart cannot hit children it just created, even next update")
	_check(shot.remaining_pierce == 2 and game.economy.gold == 401, "splitting consumes only one direct pierce")
	game.free()

func _test_aoe_boundary_and_budget() -> void:
	var game: MainGame = _game()
	var edge: BalloonState = _at(game, RED, Vector2(360, 300))
	var outside: BalloonState = _at(game, RED, Vector2(360.02, 300))
	var hit_ids: Array[int] = game.combat.explode(Vector2(300, 300), AttackSpec.new(1, 10, EXPLOSIVE, 60.0))
	_check(hit_ids.has(edge.id) and not hit_ids.has(outside.id), "AoE includes center exactly on radius, excludes just outside")
	_check(game.economy.gold == 401, "radius boundary hit pays once")
	game.free()

	game = _game()
	_at(game, BLACK, Vector2(301, 300))
	var lead: BalloonState = _at(game, LEAD, Vector2(310, 300))
	var blue: BalloonState = _at(game, BLUE, Vector2(320, 300))
	hit_ids = game.combat.explode(Vector2(300, 300), AttackSpec.new(10, 1, EXPLOSIVE, 60.0))
	_check(hit_ids.size() == 1 and hit_ids[0] == lead.id, "AoE skips immune black and spends budget on nearest valid target")
	_check(blue.definition == BLUE and game.economy.gold == 401, "AoE pierce is target count, independent of damage")
	_check(game.balloons.balloons.size() == 4, "lead children are not hit by their spawning explosion")
	game.free()
	game = _game()
	for index in range(8):
		_at(game, BLUE, Vector2(300, 300))
	hit_ids = game.combat.explode(Vector2(300, 300), AttackSpec.new(1, 3, EXPLOSIVE, 80.0))
	_check(hit_ids.size() == 3 and game.economy.gold == 403, "overlapping/grid-duplicated targets are hit exactly once up to blast pierce")
	_check(game.balloons.balloons.size() == 8, "one blast does not hit converted red layers again")
	game.free()

func _test_target_selection_and_context() -> void:
	for tower in [MainGame.DART, MainGame.BOMB]:
		var game: MainGame = _game()
		game.try_place_tower(Vector2(250, 350), tower)
		var immune: BalloonState = _at(game, LEAD if tower == MainGame.DART else BLACK, Vector2(156, 300))
		var valid: BalloonState = _at(game, BLACK if tower == MainGame.DART else LEAD, Vector2(156, 380))
		immune.distance = 1000.0
		valid.distance = 900.0
		game.towers.update(MainGame.FIXED_STEP)
		_check(game.projectiles.projectiles.size() == 1 and game.projectiles.projectiles[0].target_id == valid.id, "targeting skips immune front balloon via common attribute rules")
		game.free()
	var game: MainGame = _game()
	var balloon: BalloonState = game.balloons.spawn(PINK)
	var context: Dictionary = {}
	var attack: AttackSpec = AttackSpec.new(1, 1, SHARP)
	game.combat.apply_hit(balloon.id, attack, 1.0, context)
	game.combat.apply_hit(balloon.id, attack, 1.0, context)
	_check(game.economy.gold == 401 and balloon.definition.id == &"yellow", "common resolver also rejects duplicate IDs in a shared attack context")
	game.free()

func _test_bomb_contact() -> void:
	var game: MainGame = _game()
	var blue: BalloonState = _at(game, BLUE, Vector2(200, 300))
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(EXPLOSIVE, 12, 1, 68.0))
	game.projectiles.update(0.2)
	_check(blue.definition == RED and game.economy.gold == 401, "direct contact target receives only the blast, not additional direct damage")
	_check(game.projectiles.projectiles.is_empty() and game.combat.effects.size() == 1, "bomb is removed and one circular effect is created")
	game.free()
	game = _game()
	_at(game, BLACK, Vector2(200, 300))
	var red: BalloonState = _at(game, RED, Vector2(230, 300))
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(EXPLOSIVE, 1, 1, 68.0))
	game.projectiles.update(0.2)
	_check(game.balloons.find(red.id) == null and game.economy.gold == 401, "bomb detonates on immune physical contact and can damage another valid target")
	game.free()
	game = _game()
	_at(game, RED, Vector2(200, 300))
	var moving: BalloonState = _at(game, PINK, Vector2(200, 400))
	moving.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400)]), 0.2)
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(EXPLOSIVE, 12, 1, 30.0))
	game.projectiles.update(0.2)
	_check(moving.definition.id == &"yellow" and game.economy.gold == 402, "blast uses moving balloon positions at impact time, not frame end")
	game.free()
	game = _game()
	moving = _at(game, PINK, Vector2(200, 400))
	moving.record_motion(PackedVector2Array([Vector2(200, 200), Vector2(200, 400)]), 0.1)
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(EXPLOSIVE, 12, 1, 68.0, 2000.0))
	game.projectiles.update(0.1)
	_check(moving.definition.id == &"yellow" and game.combat.effects.size() == 1, "fast moving pink and bomb collide between endpoints")
	game.free()

func _test_batch_and_reference_safety() -> void:
	var game: MainGame = _game()
	_at(game, BLACK, Vector2(200, 300))
	_at(game, RED, Vector2(300, 300))
	game.projectiles.launch(Vector2(180, 300), Vector2.RIGHT, _shot(SHARP, 1, 1, 120.0))
	game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, _shot(SHARP, 1, 1, 120.0))
	game.projectiles.update(0.3)
	_check(game.balloons.balloons.size() == 2 and game.economy.gold == 402, "two same-batch blasts cannot chain-hit newly split children")
	for child in game.balloons.balloons:
		_check(child.definition == PINK, "newborn pink survives all old batch candidates")
	game.combat.explode(Vector2(200, 300), AttackSpec.new(1, 10, SHARP, 120.0))
	_check(game.economy.gold == 404 and game.balloons.balloons[0].definition.id == &"yellow", "later independent blast may hit prior children normally")
	game.free()
	game = _game()
	var target: BalloonState = _at(game, LEAD, Vector2(200, 300))
	var next: BalloonState = _at(game, RED, Vector2(230, 300))
	game.projectiles.fire(Vector2(100, 300), target, _shot(EXPLOSIVE, 12, 1, 68.0))
	game.combat.apply_hit(target.id, AttackSpec.new(1, 1, EXPLOSIVE))
	game.projectiles.update(0.3)
	_check(game.balloons.find(next.id) == null and game.economy.gold == 402, "removed/split aim target does not invalidate bomb flight or references")
	game.free()

func _test_mixed_play() -> void:
	var normal: Dictionary = play(1)
	var fast: Dictionary = play(2)
	_check(normal.result == &"victory" and normal.wave == 6, "mixed towers can clear all six playable waves")
	_check(normal == fast, "1x/2x mixed immunity/split/AoE combat outcomes are identical")
	_check(normal.gold + (50 - normal.lives) == 511, "mixed campaign rewards plus leaks conserve all 491 layers and 180 clear gold")
	print("V0.3 MIXED PLAY: %s" % normal)

func play(speed: int) -> Dictionary:
	var game: MainGame = _game()
	game.simulation_speed = speed
	game.try_place_tower(Vector2(250, 350), MainGame.DART)
	game.try_place_tower(Vector2(250, 410), MainGame.BOMB)
	game.try_place_tower(Vector2(460, 450), MainGame.DART)
	game.try_place_tower(Vector2(672, 232), MainGame.DART)
	for wave in range(6):
		if wave == 1:
			_check(game.try_place_tower(Vector2(672, 440), MainGame.DART), "earned gold buys fourth dart")
		if wave == 3:
			_check(game.try_place_tower(Vector2(460, 650), MainGame.BOMB), "earned gold buys second bomb")
		game.start_next_wave()
		for frame in range(60 * 90 / speed):
			game._process(1.0 / 60.0)
			if game.result != &"":
				break
	var report: Dictionary = {"result": game.result, "wave": game.waves.current_wave,
		"gold": game.economy.gold, "lives": game.economy.lives, "shots": game.projectiles._next_id - 1}
	game.free()
	return report
