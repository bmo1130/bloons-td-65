extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const CERAMIC: BalloonDefinition = preload("res://data/balloons/ceramic.tres")
const LEAD: BalloonDefinition = preload("res://data/balloons/lead.tres")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_graph()
	_camo()
	_shells()
	_overflow()
	_projectiles()
	_leaks()
	var one: Dictionary = _battle(1)
	_check(one == _battle(2), "new-content HP/splits/camo exact 1x/2x combat and counters")
	_check(one.combat == _battle(1, false).combat, "HP combat does not depend on statistics")
	print("V0.9 BATTLE: %s" % one)
	print("V0.9 PROPERTIES: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.9 FAIL: " + label)

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	return game

func _tower(game: MainGame, build: Array, at: Vector2 = Vector2(250, 350)) -> TowerState:
	game.towers.add_tower(at, MainGame.DART)
	var tower: TowerState = game.towers.towers.back()
	for path in range(3):
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	return tower

func _at(game: MainGame, data: BalloonDefinition, camo: bool = false, armor: bool = false, spill: bool = true, at: Vector2 = Vector2(300, 350)) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 500.0, camo, armor, spill)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _attack(damage: int, detect: bool = true, attribute: AttackSpec.Attribute = AttackSpec.Attribute.NORMAL, id: int = 0) -> AttackSpec:
	var hit: AttackSpec = AttackSpec.new(damage, 1, attribute)
	hit.detects_camo = detect
	hit.source_id = id
	return hit

func _graph() -> void:
	for row: Array in [["black", 11, 1, 11, ["pink", "pink"]], ["white", 11, 1, 11, ["pink", "pink"]], ["zebra", 23, 1, 23, ["black", "white"]], ["rainbow", 47, 1, 47, ["zebra", "zebra"]], ["lead", 23, 1, 23, ["black", "black"]], ["ceramic", 104, 10, 95, ["rainbow", "rainbow"]]]:
		var game: MainGame = _game()
		var data: BalloonDefinition = load("res://data/balloons/%s.tres" % row[0])
		var balloon: BalloonState = _at(game, data, true)
		_check(balloon.shell_hp == row[2] and balloon.total_rbe() == row[1] and data.layer_count() == row[3], "type HP RBE and actual layer count separated: " + row[0])
		game.combat.apply_hit(balloon.id, _attack(row[2]))
		var names: Array[String] = []
		for child: BalloonState in game.balloons.balloons:
			names.append(child.definition.id)
			_check(child.camo and not child.fortified and child.distance == 500.0 and child.position == Vector2(300, 350), "camo and contact location inherited: " + row[0])
		names.sort()
		var expected: Array = row[4].duplicate()
		expected.sort()
		_check(names == expected and game.economy.total_earned == 1, "data graph children and exactly one shell reward: " + row[0])
		game.balloons.update(0.1)
		for child in game.balloons.balloons:
			_check(is_equal_approx(child.distance, 500.0 + child.definition.speed * 0.1), "child applies own speed next step")
		game.free()
	_check(CERAMIC.speed == 95.0 * 2.5 and CERAMIC.total_rbe(true) == 114 and LEAD.total_rbe(true) == 26, "fortified RBE and ceramic red speed ratio")
	var game: MainGame = _game()
	for kind in ["white", "zebra"]:
		var target: BalloonState = _at(game, load("res://data/balloons/%s.tres" % kind))
		_check(game.combat.apply_hit(target.id, _attack(1, true, AttackSpec.Attribute.COLD)) == 0, "COLD immunity " + kind)
		_check(game.combat.apply_hit(target.id, _attack(1, true, AttackSpec.Attribute.EXPLOSIVE)) == (0 if kind == "zebra" else 1), "white/zebra explosive distinction")
	game.free()

func _camo() -> void:
	for build in [[0, 0, 0], [0, 0, 2], [2, 0, 2], [0, 2, 2], [4, 0, 0], [4, 0, 2], [0, 0, 5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var target: BalloonState = _at(game, LEAD if build[0] == 4 else load("res://data/balloons/red.tres"), true)
		var detects: bool = build[2] >= 2
		_check((game.towers._first_in_range(tower) != null) == detects, "common targeting respects camo: " + str(build))
		var data: TowerDefinition = tower.stats
		_check(data.make_attack().detects_camo == detects, "attack snapshots camo capability")
		game.projectiles.launch(Vector2(220, 350), Vector2.RIGHT, data, tower.id)
		game.projectiles.update(0.2)
		_check((game.balloons.find(target.id) == null) == detects and tower.combat_stats.pierce_used == (1 if detects else 0), "incidental camo projectile contact and pierce")
		game.free()
	var game: MainGame = _game()
	var target: BalloonState = _at(game, LEAD, true, true)
	_check(game.combat.apply_hit(target.id, _attack(80, true, AttackSpec.Attribute.SHARP)) == 0 and target.shell_hp == 4, "seeing camo never bypasses sharp immunity")
	var blast: AttackSpec = _attack(2, false, AttackSpec.Attribute.EXPLOSIVE)
	blast.explosion_radius = 60
	blast.pierce = 10
	_check(game.combat.explode(target.position, blast).is_empty() and target.shell_hp == 4, "AoE without detection leaves camo armored shell untouched")
	blast.detects_camo = true
	_check(game.combat.explode(target.position, blast).size() == 1 and target.shell_hp == 2, "detected camo armored lead can take explosive HP damage")
	target.remove_camo()
	game.combat.apply_hit(target.id, _attack(2, false))
	_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return not child.camo and not child.fortified), "decamo state hook affects future descendants without any tower implementation")
	var invalid: BalloonState = _at(game, load("res://data/balloons/red.tres"), false, true)
	_check(not invalid.fortified and invalid.shell_hp == 1, "unsupported fortification is rejected by shared type data")
	game.free()
	game = _game()
	var caster: TowerState = _tower(game, [0, 5, 2])
	var receiver: TowerState = _tower(game, [0, 0, 0], Vector2(350, 350))
	game.abilities.update(17)
	game.abilities.activate(caster)
	_check(caster.transformed_stats.detects_camo and not receiver.transformed_stats.detects_camo, "Plasma retains each recipient's own camo capability")
	game.abilities.update(15)
	_check(caster.stats.detects_camo and caster.transformed_stats == null, "camo survives transformation expiry")
	game.free()

func _shells() -> void:
	for data: BalloonDefinition in [LEAD, CERAMIC]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 0, 0])
		var target: BalloonState = _at(game, data, true, true)
		var applied: int = game.combat.apply_hit(target.id, _attack(999, true, AttackSpec.Attribute.NORMAL, tower.id))
		_check(applied == data.total_rbe(true) and tower.combat_stats.pops() == data.layer_count() and game.economy.total_earned == data.layer_count() and game.balloons.balloons.is_empty(), "full fortified tree HP/cash/shells conserve separately")
		game.free()
	for armor in [false, true]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 0, 0])
		var target: BalloonState = _at(game, CERAMIC, true, armor)
		var maximum: int = 20 if armor else 10
		var hit: AttackSpec = _attack(1, true, AttackSpec.Attribute.NORMAL, tower.id)
		for damage in range(1, maximum):
			game.combat.apply_hit(target.id, hit)
		_check(target.shell_hp == 1 and target.definition == CERAMIC and game.balloons.balloons.size() == 1 and game.economy.total_earned == 0, "partial ceramic shell never spawns or rewards")
		_check(tower.combat_stats.pops() == 0 and tower.combat_stats.effective_damage == maximum - 1 and tower.combat_stats.pierce_used == maximum - 1, "HP-only hits count damage and pierce, not removed shells")
		_check(target.total_rbe() == maximum + 94 and target.remaining_rbe() == 95 and target.leak_damage() == maximum + 94, "full type leakage is separate from remaining HP RBE")
		game.combat.apply_hit(target.id, hit)
		_check(game.balloons.balloons.size() == 2 and tower.combat_stats.pops() == 1 and tower.combat_stats.effective_damage == maximum and game.economy.total_earned == 1, "shell break records one pop and all real HP")
		_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.camo and not child.fortified and child.definition.id == &"rainbow"), "camo armor ceramic produces two camo unarmored rainbows")
		game.free()
	for build in [[4, 0, 0], [5, 0, 0]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var target: BalloonState = _at(game, CERAMIC, false, true)
		var applied: int = game.combat.apply_hit(target.id, tower.stats.make_attack())
		_check(applied == (7 if build[0] == 4 else 18) and target.shell_hp == (13 if build[0] == 4 else 2), "actual ceramic and fortified bonuses applied once to thick shell")
		game.free()

func _overflow() -> void:
	for row: Array in [[10, 10, 1, 2, 1], [11, 12, 3, 4, 3], [12, 16, 7, 8, 7], [13, 24, 15, 16, 15], [99, 104, 95, 0, 31]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 0, 0])
		var target: BalloonState = _at(game, CERAMIC)
		var damage: int = game.combat.apply_hit(target.id, _attack(row[0], true, AttackSpec.Attribute.NORMAL, tower.id))
		_check(damage == row[1] and tower.combat_stats.effective_damage == row[1] and tower.combat_stats.pops() == row[2] and game.economy.total_earned == row[2] and game.balloons.balloons.size() == row[3], "recursive surplus copied to each child and actual HP/cash counted once: " + str(row[0]))
		_check(tower.combat_stats.pierce_used == 1 and tower.combat_stats.targets_damaged == row[4], "root pierce and actually damaged descendant IDs are separate counters")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [5, 0, 0])
	var target: BalloonState = _at(game, CERAMIC)
	game.combat.apply_hit(target.id, tower.stats.make_attack())
	_check(game.balloons.balloons.size() == 16 and game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.definition.id == &"pink"), "ultra 13 damage enters children but ceramic bonus never reapplies recursively")
	game.free()
	game = _game()
	target = _at(game, CERAMIC)
	game.combat.apply_hit(target.id, _attack(99, true, AttackSpec.Attribute.EXPLOSIVE))
	_check(game.balloons.balloons.size() == 4 and game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.definition.id == &"zebra"), "overflow checks immunity at each encountered child boundary")
	game.free()
	game = _game()
	target = _at(game, LEAD, false, false, false)
	game.combat.apply_hit(target.id, _attack(99))
	_check(game.balloons.balloons.size() == 2 and game.economy.total_earned == 1, "legacy lead branch stop preserved for campaign")
	game.free()

func _projectiles() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	var data: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	data.attack_attribute = AttackSpec.Attribute.NORMAL
	data.damage = 6
	data.pierce = 1
	data.detects_camo = true
	var target: BalloonState = _at(game, CERAMIC, true)
	game.projectiles.launch(Vector2(220, 350), Vector2.RIGHT, data, tower.id)
	game.projectiles.launch(Vector2(220, 350), Vector2.RIGHT, data, tower.id)
	game.projectiles.update(0.2)
	_check(tower.combat_stats.effective_damage == 16 and tower.combat_stats.pops() == 7 and tower.combat_stats.pierce_used == 2 and game.balloons.balloons.size() == 8, "simultaneous shots use actual remaining HP then spill once; new children not independently hit")
	_check(game.balloons.find(target.id) == null and game.projectiles.projectiles.is_empty(), "destroyed shell refs safe and both pierce-one shots consumed")
	game.free()
	game = _game()
	tower = _tower(game, [5, 0, 2])
	var shot: ProjectileState = game.projectiles.launch(Vector2(300, 600), Vector2.UP, tower.stats, tower.id)
	game.projectiles.update(1.7)
	_check(shot.split_bursts == 2 and game.projectiles.projectiles.all(func(child: ProjectileState) -> bool: return child.attack.detects_camo), "502 mini juggernauts inherit parent's snapshotted camo capability")
	game.free()

func _leaks() -> void:
	for row: Array in [[CERAMIC, false, 104], [CERAMIC, true, 114], [LEAD, true, 26]]:
		var game: MainGame = _game()
		var target: BalloonState = game.balloons.spawn(row[0], game.route.total_length - 0.1, true, row[1])
		game.combat.apply_hit(target.id, _attack(1))
		game.balloons.update(0.1, true)
		game.balloons.resolve_leaks()
		_check(game.economy.lives == 1000000 - row[2] and game.economy.total_earned == 0, "damaged thick shell leakage uses full current type RBE")
		game.free()
	var game: MainGame = _game()
	var target: BalloonState = game.balloons.spawn(CERAMIC, game.route.total_length - 1)
	game.balloons.update(0.1, true)
	game.combat.apply_hit(target.id, _attack(10), target.exit_time)
	game.balloons.resolve_leaks()
	_check(game.balloons.balloons.is_empty() and game.economy.lives == 1000000 - 94 and game.economy.total_earned == 1, "splitting exactly at exit charges children94 once, not dead parent104")
	game.free()
	game = _game()
	target = game.balloons.spawn(CERAMIC, game.route.total_length - 10)
	game.balloons.update(0.1, true)
	game.combat.apply_hit(target.id, _attack(10), 0.1)
	game.balloons.resolve_leaks()
	_check(game.balloons.balloons.size() == 2 and game.economy.lives == 1000000, "split before parent future exit does not charge stationary newborns prematurely")
	game.balloons.update(0.1, true)
	game.balloons.resolve_leaks()
	_check(game.economy.lives == 1000000 - 94, "rainbow children leak their own RBE next movement")
	game.free()

func _battle(speed: int, collect: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.simulation_speed = speed
	game.battle_stats.enabled = collect
	_tower(game, [4, 0, 2])
	_tower(game, [0, 2, 5], Vector2(460, 450))
	for index in range(24):
		game.balloons.spawn(CERAMIC, index * 12.0, index % 2 == 0, index % 3 == 0)
	for frame in range(20 * 60 / speed):
		game._process(MainGame.FIXED_STEP)
	var counters: Array = []
	for tower in game.towers.towers:
		counters.append(tower.combat_stats.snapshot())
	var result: Dictionary = {"combat": [game.economy.gold, game.economy.lives, game.balloons.balloons.size(), game.projectiles._next_id], "counters": counters}
	game.free()
	return result
