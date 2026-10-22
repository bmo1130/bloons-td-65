extends "res://tests/balloon_properties_tests.gd"

const MOAB: BalloonDefinition = preload("res://data/balloons/moab.tres")
const BFB: BalloonDefinition = preload("res://data/balloons/bfb.tres")
const ZOMG: BalloonDefinition = preload("res://data/balloons/zomg.tres")

func run(window: Window) -> Dictionary:
	_root = window
	_data_and_splits()
	_bonuses_and_status()
	_target_modes()
	_collision_and_lifetime()
	_full_tree(false)
	_full_tree(true)
	_blimp_leaks()
	var one: Dictionary = _moab_battle(1)
	_check(one == _moab_battle(2), "MOAB combat and statistics exact 1x/2x")
	_check(one.combat == _moab_battle(1, false).combat, "MOAB combat statistics ON/OFF is passive")
	print("V0.10 BATTLE: %s" % one)
	print("V0.10 MOAB: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _data_and_splits() -> void:
	for row: Array in [[MOAB, 200, 616, 856, 95.0, CERAMIC], [BFB, 700, 3164, 4824, 23.75, MOAB], [ZOMG, 4000, 16656, 27296, 17.1, BFB]]:
		var data: BalloonDefinition = row[0]
		_check(data.shell_hp == row[1] and data.fortified_hp == row[1] * 2 and data.total_rbe() == row[2] and data.total_rbe(true) == row[3], "type HP/RBE/fortified descendant value: " + str(data.id))
		_check(data.speed == row[4] and data.moab_class and data.radius > CERAMIC.radius and not data.knockback_allowed, "blimp classification/speed/collision/status: " + str(data.id))
		_check(data.total_reward() == (381 if data == MOAB else (1525 if data == BFB else 6101)), "base cash follows removed-shell graph, not HP/RBE")
		for attribute in [AttackSpec.Attribute.SHARP, AttackSpec.Attribute.EXPLOSIVE, AttackSpec.Attribute.NORMAL, AttackSpec.Attribute.PLASMA]:
			var game: MainGame = _game()
			var target: BalloonState = _at(game, data)
			_check(game.combat.apply_hit(target.id, _attack(1, true, attribute)) == 1 and target.shell_hp == row[1] - 1 and game.balloons.balloons.size() == 1, "ordinary attribute chips blimp without splitting")
			game.free()
		for armor in [false, true]:
			var game: MainGame = _game()
			var target: BalloonState = game.balloons.spawn(data, 500, true, armor, true)
			game.balloons.update(0.1, true)
			_check(is_equal_approx(target.distance, 500 + data.speed * 0.1), "own data speed")
			var at: Vector2 = target.position_at_time(0.5)
			var distance: float = target.distance_at_time(0.5)
			var excluded: Dictionary = {}
			var damage: int = game.combat.apply_hit(target.id, _attack(100000), 0.5, excluded)
			_check(damage == data.max_hp(armor) and game.balloons.find(target.id) == null and game.balloons.balloons.size() == 4, "overkill stops at MOAB boundary, only four children")
			var ids: Dictionary = {}
			for child in game.balloons.balloons:
				ids[child.id] = true
				_check(child.definition == row[5] and child.fortified == armor and child.camo and child.shell_hp == child.definition.max_hp(armor), "fortified/camo/full child HP inherited")
				_check(child.position.is_equal_approx(at) and is_equal_approx(child.distance, distance) and excluded.has(child.id), "contact location and exclusion inherited")
			_check(ids.size() == 4 and game.economy.total_earned == 1 and game.combat.apply_hit(target.id, _attack(100000)) == 0, "unique IDs/single reward/stale parent cannot split twice")
			game.balloons.resolve_leaks()
			game.balloons.update(0.1)
			_check(is_equal_approx(game.balloons.balloons[0].distance, distance + row[5].speed * 0.1), "child follows its own speed next tick")
			game.free()

func _bonuses_and_status() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [4, 0, 2])
	var hit: AttackSpec = _attack(2, true, AttackSpec.Attribute.NORMAL, tower.id)
	hit.moab_bonus = 10
	hit.ceramic_bonus = 3
	hit.fortified_bonus = 5
	var blimp: BalloonState = _at(game, MOAB)
	_check(game.combat.apply_hit(blimp.id, hit) == 12 and blimp.shell_hp == 188, "base2 plus MOAB10, ceramic bonus not added")
	var armor: BalloonState = _at(game, BFB, false, true)
	_check(game.combat.apply_hit(armor.id, hit) == 17, "MOAB and fortification bonuses add once")
	var ceramic: BalloonState = _at(game, CERAMIC)
	_check(game.combat.apply_hit(ceramic.id, hit) == 5, "ceramic bonus independent from MOAB")
	var red: BalloonState = _at(game, load("res://data/balloons/red.tres"))
	_check(game.combat.apply_hit(red.id, hit) == 1, "MOAB bonus not given to ordinary types")
	_check(tower.combat_stats.moab_damage == 29 and tower.combat_stats.effective_damage == 35 and tower.combat_stats.gold_earned == 1, "attributed MOAB HP is subset of actual damage, gold independent")
	for data in [MOAB, BFB, ZOMG]:
		var target: BalloonState = _at(game, data)
		game.combat.apply_hit(target.id, tower.stats.make_attack())
		_check(target.knockback_remaining == 0 and target.knockback_multiplier == 0, "Juggernaut cannot knock back MOAB class")
	var target: BalloonState = _at(game, MOAB)
	for pair: Array in [[200, 0], [150, 1], [100, 2], [50, 3], [1, 3]]:
		target.shell_hp = pair[0]
		_check(target.damage_stage() == pair[1], "quarter HP visual damage stages")
	var invisible: BalloonState = _at(game, MOAB, true, true)
	var blind: AttackSpec = _attack(100000, false)
	_check(game.combat.apply_hit(invisible.id, blind) == 0 and invisible.shell_hp == 400, "camo and fortified blimp still requires detection")
	var data: TowerDefinition = MainGame.DART.duplicate() as TowerDefinition
	data.moab_bonus = 10
	var shot: ProjectileState = game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, data, tower.id)
	data.moab_bonus = 999
	_check(shot.attack.moab_bonus == 10 and TowerStatResolver.resolve(data, PackedInt32Array([0, 0, 0])).moab_bonus == 999, "MOAB bonus data resolver and launched immutable snapshot")
	game.free()

func _target_modes() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 2], Vector2(250, 350))
	var front: BalloonState = _at(game, CERAMIC, false, false, true, Vector2(300, 350))
	front.distance = 900
	var last: BalloonState = _at(game, MOAB, false, false, true, Vector2(330, 350))
	last.distance = 100
	var close: BalloonState = _at(game, BFB, false, false, true, Vector2(260, 350))
	close.distance = 500
	var strongest: BalloonState = _at(game, ZOMG, true, false, true, Vector2(310, 350))
	strongest.distance = 200
	for pair: Array in [[TowerState.TargetMode.FIRST, front], [TowerState.TargetMode.LAST, last], [TowerState.TargetMode.CLOSE, close], [TowerState.TargetMode.STRONG, strongest]]:
		tower.target_mode = pair[0]
		_check(game.towers._first_in_range(tower) == pair[1], "shared target mode: " + str(pair[0]))
	strongest.camo = true
	tower.stats.detects_camo = false # isolated resolved instance, never a Resource asset
	_check(game.towers._first_in_range(tower) == close, "Strong skips undetectable higher class")
	tower.stats.detects_camo = true
	var fortified: BalloonState = _at(game, ZOMG, false, true, true, Vector2(320, 350))
	fortified.distance = 50
	fortified.shell_hp = 1
	_check(game.towers._first_in_range(tower) == fortified, "provisional same-class Fortified before current HP")
	strongest.fortified = true
	_check(game.towers._first_in_range(tower) == strongest, "same class and fortification compare current shell HP")
	strongest.shell_hp = 1
	_check(game.towers._first_in_range(tower) == strongest, "equal strength uses First, camo not extra priority")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 0], Vector2(250, 350))
	var edge: BalloonState = _at(game, ZOMG, false, false, true, Vector2(450, 350))
	_check(game.towers._first_in_range(tower) == edge, "large hitbox exactly touches range despite center outside")
	edge.position.x += 0.1
	_check(game.towers._first_in_range(tower) == null, "large hitbox just outside range rejected")
	game.free()

func _collision_and_lifetime() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	var target: BalloonState = _at(game, ZOMG, false, false, true, Vector2(400, 350))
	var shot: ProjectileState = game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	game.projectiles.update(0.11)
	_check(target.shell_hp == 3999 and shot.hit_ids.has(target.id) and shot.remaining_pierce == 1, "large circular swept contact consumes one pierce")
	game.projectiles.update(0.1)
	_check(target.shell_hp == 3999 and tower.combat_stats.pierce_used == 1, "same projectile cannot chip blimp repeatedly")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 0])
	target = _at(game, MOAB)
	var profile: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	profile.damage = 200
	profile.pierce = 10
	shot = game.projectiles.launch(target.position, Vector2.RIGHT, profile, tower.id)
	game.projectiles.update(0.01)
	_check(game.balloons.balloons.size() == 4 and tower.combat_stats.moab_damage == 200 and tower.combat_stats.pops() == 1 and tower.combat_stats.gold_earned == 1, "parent contact not duplicated on newborn ceramics")
	_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return shot.was_hit(child.id, 0) and child.shell_hp == 10), "same projectile permanently excludes new descendants")
	game.projectiles.update(0.1)
	_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.shell_hp == 10), "excluded children remain untouched on following projectile step")
	game.free()

func _full_tree(armor: bool) -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	game.balloons.profile_changes = true
	game.balloons.spawn(ZOMG, 500, true, armor, true)
	var expected: Array[int] = [4, 16, 64, 128, 256, 512, 1024, 1024, 1024, 1024, 1024, 0]
	for phase in range(12):
		var parents: Array[BalloonState] = game.balloons.balloons.duplicate()
		for parent in parents:
			var hit: AttackSpec = _attack(parent.shell_hp, true, AttackSpec.Attribute.NORMAL, tower.id)
			game.combat.apply_hit(parent.id, hit)
		_check(game.balloons.balloons.size() == expected[phase], "ZOMG full tree phase%d armor%s" % [phase, armor])
		if phase < 3:
			_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return child.fortified == armor and child.camo and child.distance == 500), "armor preserved down to ceramic")
		elif phase == 3:
			_check(game.balloons.balloons.all(func(child: BalloonState) -> bool: return not child.fortified and child.camo), "ceramic boundary drops armor but keeps camo")
	_check(tower.combat_stats.pops() == 6101 and game.economy.total_earned == 6101 and tower.combat_stats.gold_earned == 6101, "full ZOMG actual shell Pops and cash6101, never RBE reward")
	_check(tower.combat_stats.effective_damage == (27296 if armor else 16656) and tower.combat_stats.moab_damage == (20000 if armor else 10000), "full RBE damage and MOAB-only subset exact")
	_check(game.balloons.latest_id() == 2005 and game.balloons.removal_count == 2005 and game.balloons.peak_active_count == 1024, "all unique IDs created/removed, full active peak observed")
	game.free()

func _blimp_leaks() -> void:
	for data in [MOAB, BFB, ZOMG]:
		for armor in [false, true]:
			var game: MainGame = _game()
			var target: BalloonState = game.balloons.spawn(data, game.route.total_length - 0.1, false, armor)
			game.combat.apply_hit(target.id, _attack(target.shell_hp - 1))
			var lives: int = game.economy.lives
			game.balloons.update(1.0, true)
			game.balloons.resolve_leaks()
			_check(game.economy.lives == lives - data.total_rbe(armor) and game.economy.total_earned == 0, "adopted full-type leak after partial shell damage")
			game.free()
	var game: MainGame = _game()
	var target: BalloonState = game.balloons.spawn(MOAB, game.route.total_length, true, true, true)
	game.balloons.update(0.1, true)
	game.combat.apply_hit(target.id, _attack(100000), target.exit_time)
	game.balloons.resolve_leaks()
	_check(game.economy.lives == 1000000 - 456 and game.economy.total_earned == 1, "split at exit leaks four fortified ceramics456, never removed parent856")
	game.free()

func _moab_battle(speed: int, enabled: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = enabled
	_tower(game, [0, 2, 5])
	_tower(game, [5, 0, 2], Vector2(460, 450))
	game.balloons.spawn(MOAB, 500, true, true, true)
	game.balloons.spawn(MOAB, 510, false, false, true)
	game.balloons.spawn(BFB, 520, false, false, true)
	for frame in range(600 / speed):
		for step in range(speed):
			game.simulation_step(MainGame.FIXED_STEP)
	var counters: Array[Dictionary] = []
	for record: TowerCombatStats in game.battle_stats.records.values():
		counters.append(record.snapshot())
	var report: Dictionary = {"combat": [game.economy.gold, game.economy.lives, game.balloons.balloons.size(), game.balloons.latest_id()], "counters": counters}
	game.free()
	return report
