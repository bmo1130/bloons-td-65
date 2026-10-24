extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_purchases()
	_control()
	_missiles()
	_recursive()
	_storm()
	for build: Array in [[4, 0, 2], [5, 2, 0], [0, 4, 2], [0, 5, 2], [2, 0, 4], [0, 2, 5]]:
		var one: Dictionary = battle(build, 1)
		_check(one == battle(build, 2), "new mechanisms identical fixed-step accumulator 1x/2x " + str(build))
		_check(one.combat == battle(build, 1, false).combat, "statistics never determine new combat " + str(build))
	print("BOMB TIER5 TESTS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BOMB TIER5 FAIL: " + label)

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	return game

func _tower(game: MainGame, build: Array, reverse: bool = false) -> TowerState:
	game.towers.add_tower(Vector2(250, 350), MainGame.BOMB)
	var tower: TowerState = game.towers.towers.back()
	for path in ([2, 1, 0] if reverse else [0, 1, 2]):
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.BOMB.upgrade_at(path, tier))
	return tower

func _balloon(game: MainGame, kind: String, distance: float = 500.0, armor: bool = false, camo: bool = false) -> BalloonState:
	return game.balloons.spawn(load("res://data/balloons/%s.tres" % kind), distance, camo, armor, true)

func _dummy(game: MainGame, at: Vector2 = Vector2(300, 350)) -> BalloonState:
	var data: BalloonDefinition = BalloonDefinition.new()
	data.shell_hp = 100000
	data.speed = 0.0
	var balloon: BalloonState = game.balloons.spawn(data, 500.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _purchases() -> void:
	_check(MainGame.BOMB.upgrades.size() == 15, "all fifteen unique upgrades available")
	for path in range(3):
		for tier in [4, 5]:
			for secondary in [-1, (path + 1) % 3, (path + 2) % 3]:
				for side_tier in ([0] if secondary < 0 else [1, 2]):
					var game: MainGame = _game()
					var build: Array = [0, 0, 0]
					build[path] = tier
					if secondary >= 0:
						build[secondary] = side_tier
					var tower: TowerState = _tower(game, build)
					_check(tower.tiers == PackedInt32Array(build), "all high tier and legal secondary states purchasable")
					_check(game.economy.gold == 1000000 - tower.spent_on_upgrades and tower.combat_stats.invested_gold == 150 + tower.spent_on_upgrades, "one debit and investment per purchase")
					var gold: int = game.economy.gold
					_check(not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(path, tier)) and game.economy.gold == gold, "duplicate high tier leaves money and stats unchanged")
					if secondary >= 0:
						_check(not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(secondary, 3)) and not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(3 - path - secondary, 1)), "second main and third path remain locked")
					if tier == 5:
						var other: Array = build.duplicate()
						other[path] = 4
						var b: TowerState = _tower(game, other, true)
						gold = game.economy.gold
						_check(not game.try_upgrade(b, MainGame.BOMB.upgrade_at(path, 5)) and game.economy.gold == gold, "map-wide kind/path tier5 limit")
						game.towers.remove_tower(tower)
						_check(game.try_upgrade(b, MainGame.BOMB.upgrade_at(path, 5)), "removal releases ability and registry slot")
						for field in TowerStatResolver.FIELDS:
							_check(b.stats.get(field) == tower.stats.get(field), "secondary-first synthesis equals primary-first " + str(field))
					else:
						var b: TowerState = _tower(game, build, true)
						_check(b.stats.damage == tower.stats.damage and b.stats.fire_interval == tower.stats.fire_interval and b.stats.projectile_split == tower.stats.projectile_split, "tier4 secondary-first synthesis")
					game.free()
	var game: MainGame = _game()
	var top: TowerState = _tower(game, [5, 0, 2])
	_check(top.stats.damage == 30 and top.stats.pierce == 100 and top.stats.attack_range == 195 and top.stats.frag_damage_bonus == 2, "502 composes range and strengthened32 damage SHARP fragments")
	_check(_tower(game, [2, 0, 4]).stats.damage == 3 and is_equal_approx(_tower(game, [0, 2, 4]).stats.fire_interval, 0.81), "204 damage and024 speed crosspaths compose")
	_check(is_equal_approx(_tower(game, [0, 2, 5]).stats.fire_interval, 0.405) and _tower(game, [2, 5, 0]).stats.moab_bonus == 99, "025 speed and250 MOAB bonus compose")
	game.free()

func _control() -> void:
	for build: Array in [[4, 0, 0], [5, 0, 0]]:
		for kind in ["ceramic", "moab", "bfb", "zomg", "bad"]:
			var game: MainGame = _game()
			var tower: TowerState = _tower(game, build)
			var balloon: BalloonState = _balloon(game, kind, 500.0, kind == "ceramic")
			if kind == "ceramic":
				balloon.shell_hp = 100 # Surviving control target, not a balance expectation.
			game.combat.apply_hit(balloon.id, tower.stats.make_attack())
			var allowed: bool = kind == "ceramic" or (build[0] == 5 and kind != "bad")
			_check((balloon.stun_remaining > 0.0) == allowed, "STUN capability and explicit boss mask " + kind)
			_check((balloon.pending_push > 0.0) == allowed, "MOAB push requires explicit capability, boss mask wins " + kind)
			if allowed:
				var push: float = balloon.pending_push
				var remaining: float = balloon.stun_remaining
				game.balloons.update(0.25, true)
				_check(is_equal_approx(balloon.distance, 500.0 - push) and balloon.position == game.route.position_at(balloon.distance), "path-based push and no forward movement during stun")
				game.combat.apply_hit(balloon.id, tower.stats.make_attack())
				_check(is_equal_approx(balloon.stun_remaining, remaining), "repeat contact refreshes maximum duration without adding stacks")
				balloon.pending_push = 0.0
				game.balloons.update(remaining + 0.5, true)
				_check(balloon.stun_remaining == 0.0 and is_equal_approx(balloon.distance, 500.0 - push + balloon.speed * 0.5), "partial tick expiry resumes movement for exact residual time")
			game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [5, 0, 0])
	var near_start: BalloonState = _balloon(game, "moab", 1.0)
	game.combat.apply_hit(near_start.id, tower.stats.make_attack())
	game.balloons.update(0.1, true)
	_check(near_start.distance == 0.0 and near_start.position == game.route.position_at(0.0), "push clamps at route start")
	var stopped: BalloonState = _balloon(game, "moab", 500.0)
	stopped.record_motion(PackedVector2Array([stopped.position, stopped.position]), MainGame.FIXED_STEP)
	stopped.stun_remaining = 1.0
	var origin: Vector2 = stopped.position + Vector2(0, 100)
	_check(game.projectiles._aim_direction(origin, stopped, MainGame.BOMB).is_equal_approx(origin.direction_to(stopped.position)), "predictive aim respects a stationary stunned target instead of leading past it")
	stopped.pending_push = 18.0
	_check(game.projectiles._aim_direction(origin, stopped, MainGame.BOMB).is_equal_approx(origin.direction_to(game.route.position_at(482.0))), "predictive aim includes next-step path push without mutating target")
	_check(stopped.distance == 500.0 and stopped.pending_push == 18.0 and stopped.stun_remaining == 1.0, "prediction never consumes movement or status")
	for kind in ["black", "white", "lead", "ddt"]:
		var target: BalloonState = _balloon(game, kind)
		var hp: int = target.shell_hp
		game.combat.apply_hit(target.id, tower.stats.make_attack())
		_check((game.balloons.find(target.id) == null or target.shell_hp < hp or target.definition.id != StringName(kind)) == (kind != "ddt"), "Normal blast penetrates type immunity while camo stays independent " + kind)
	game.free()

func _missiles() -> void:
	for tier in [4, 5]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, tier, 2])
		var state: AbilityState = game.abilities.state_for(tower)
		_check(not game.abilities.activate(tower) and state.cooldown_remaining == 0.0, "empty screen activation does not spend cooldown")
		var a: BalloonState = _balloon(game, "moab", 900.0)
		var b: BalloonState = _balloon(game, "bfb", 400.0)
		var c: BalloonState = _balloon(game, "zomg", 700.0)
		var invisible: BalloonState = _balloon(game, "ddt", 1100.0)
		for mode in range(4):
			tower.target_mode = mode as TowerState.TargetMode
			var target: BalloonState = game.abilities.missile_target(tower)
			var expected: BalloonState = [a, b, c, c][mode]
			_check(target == expected and target != invisible, "global missile uses First Last Close Strong and detection")
			expected.shell_hp = 10000
			var old_hp: int = expected.shell_hp
			state.cooldown_remaining = 0.0
			_check(game.abilities.activate(tower) and game.projectiles.projectiles.size() == 1, "one real targeted missile per activation")
			_check(not game.abilities.activate(tower), "cooldown blocks duplicate activation")
			for tick in range(180):
				game.projectiles.update(MainGame.FIXED_STEP)
			_check(expected.shell_hp == old_hp - (750 if tier == 4 else 4500) and game.projectiles.projectiles.is_empty(), "exact single-target damage and missile cleanup")
			_check(state.last_targets == PackedInt64Array([expected.id]), "stable target identity, no splash or retarget")
		for target in [a, b, c]:
			target.position = Vector2(-100, -100)
		_check(game.abilities.missile_target(tower) == null, "offscreen and camo-only targets are invalid")
		game.balloons._remove(invisible.array_index)
		a.position = Vector2(900, 200)
		state.cooldown_remaining = 0.0
		_check(game.abilities.activate(tower), "ability reaches outside ordinary range")
		game.balloons._remove(a.array_index)
		game.projectiles.update(MainGame.FIXED_STEP)
		_check(game.projectiles.projectiles.is_empty() and state.cooldown_remaining > 0.0, "lost target removes missile without refund or replacement")
		if tier == 4:
			game.try_upgrade(tower, MainGame.BOMB.upgrade_at(1, 5))
			_check(game.abilities.states.size() == 1 and state.definition.id == &"bomb_eliminator" and state.cooldown_remaining == 10.0, "Assassin replacement keeps one state and clamps remaining cooldown")
		game.abilities.update(3.0)
		var cooldown: float = state.cooldown_remaining
		game.abilities.update(cooldown)
		_check(state.cooldown_remaining == 0.0, "cooldown expires on simulation time")
		game.towers.remove_tower(tower)
		_check(game.abilities.state_for(tower) == null and not game.abilities.activate(tower), "removed tower has no usable ability")
		game.free()

func _recursive() -> void:
	for build: Array in [[2, 0, 4], [0, 2, 4], [2, 0, 5], [0, 2, 5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var target: BalloonState = _dummy(game)
		for volley in range(1, 5):
			var previous: int = tower.combat_stats.split_projectiles
			tower.cooldown = 0.0
			game.towers.update(MainGame.FIXED_STEP)
			for tick in range(60):
				game.combat.update(MainGame.FIXED_STEP)
				game.projectiles.update(MainGame.FIXED_STEP)
			var expected: int = 16 if build[2] == 5 or volley % 2 == 0 else 8
			_check(tower.combat_stats.split_projectiles - previous == expected, "exact eight plus optional eight children per volley")
			_check(tower.attack_counter == volley and tower.combat_stats.volleys == volley, "children and statistics never advance parent attack counter")
			_check(game.projectiles.projectiles.is_empty() and game.combat.effects.is_empty() and game.projectiles.split_effects.is_empty(), "all recursive projectiles and effects expire")
			_check(target.shell_hp < 100000, "bounded independent blasts really damage targets")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 3])
	tower.attack_counter = 7
	game.try_upgrade(tower, MainGame.BOMB.upgrade_at(2, 4))
	_check(tower.attack_counter == 0, "buying Recursive initializes its attack phase")
	var target: BalloonState = _dummy(game, Vector2(300, 350))
	var shot: ProjectileState = game.projectiles.launch(target.position, Vector2.RIGHT, tower.stats, tower.id)
	shot.recursive = true
	var ids: Array[int] = []
	game.combat.exploded.connect(func(_at: Vector2, _radius: float) -> void: ids.append(game.battle_stats.total_pops))
	game.projectiles.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.size() == 16, "recursive parent creates exactly sixteen timed children")
	var unique: Dictionary = {}
	for child in game.projectiles.projectiles:
		unique[child.id] = true
		_check(child.attack.source_id == tower.id and child.split == null and child.attack.damage == tower.stats.damage and child.attack.moab_bonus == 0, "each child snapshots damage, attribution and no inherited MOAB bonus or further recursion")
	_check(unique.size() == 16 and ids.size() == 1, "one original detonation and independent projectile IDs")
	game.free()
	game = _game()
	tower = _tower(game, [2, 0, 4])
	target = _dummy(game)
	var profile: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	profile.projectile_split = profile.projectile_split.duplicate() as ProjectileSplitDefinition
	profile.projectile_split.child_speed_ratio = 0.0
	profile.projectile_split.secondary_projectile = profile.projectile_split.secondary_projectile.duplicate() as TowerDefinition
	(profile.projectile_split.secondary_projectile as TowerDefinition).projectile_speed = 0.0
	shot = game.projectiles.launch(target.position, Vector2.RIGHT, profile, tower.id)
	shot.recursive = true
	for tick in range(60):
		game.combat.update(MainGame.FIXED_STEP)
		game.projectiles.update(MainGame.FIXED_STEP)
	_check(target.shell_hp == 100000 - 17 * 3 and tower.combat_stats.targets_damaged == 17 and tower.combat_stats.pierce_used == 17, "one primary plus sixteen independent blasts each hit once; intentional overlap retains51HP damage")
	var excluded: Dictionary = {}
	var first: int = game.combat.apply_hit(target.id, profile.make_attack(), 1.0, excluded)
	_check(first == 3 and game.combat.apply_hit(target.id, profile.make_attack(), 1.0, excluded) == 0, "same explosion exclusion never damages the same ID twice")
	game.free()

func _storm() -> void:
	for armor in [false, true]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 0, 5])
		var state: AbilityState = game.abilities.state_for(tower)
		game.economy.lives = 1
		var leaks: Array[int] = []
		game.balloons.leaked.connect(func(amount: int) -> void: leaks.append(amount))
		for index in range(10):
			_balloon(game, "ceramic", game.route.total_length - 0.1, armor)
		game.balloons.update(MainGame.FIXED_STEP, true)
		game.balloons.resolve_leaks()
		_check(game.balloons.balloons.is_empty() and leaks.is_empty() and game.economy.lives == 1, "Storm prevents life loss and drains split descendants exactly once at exit")
		_check(state.cooldown_remaining == 40.0 and tower.combat_stats.effective_damage > 0 and tower.combat_stats.pops() == tower.combat_stats.gold_earned, "one reserved passive cooldown and confirmed Pops/rewards")
		_check(not game.abilities.activate(tower), "passive cannot be manually activated")
		var pops: int = game.battle_stats.total_pops
		game.balloons.resolve_leaks()
		_check(game.battle_stats.total_pops == pops and state.cooldown_remaining == 40.0, "repeated finalization never repeats Storm or rewards")
		_balloon(game, "red", game.route.total_length - 0.1)
		game.balloons.update(MainGame.FIXED_STEP, true)
		game.balloons.resolve_leaks()
		_check(game.economy.lives == 0 and leaks.size() == 1 and game.result == &"defeat", "cooldown leak causes one clamped life loss and defeat")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 5])
	var moab: BalloonState = _balloon(game, "moab", game.route.total_length - 0.01, true)
	game.economy.lives = 1
	game.balloons.update(MainGame.FIXED_STEP, true)
	game.balloons.resolve_leaks()
	_check(game.balloons.find(moab.id) == null and game.balloons.balloons.is_empty() and game.economy.lives == 0, "Storm respects MOAB child damage barrier and leaked children finalize without stale parents")
	_check(tower.combat_stats.moab_damage == 400 and tower.combat_stats.pops() == 1, "passive only rewards destroyed MOAB shell, not leaked descendants")
	game.free()

func battle(build: Array, speed: int, stats_enabled: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = stats_enabled
	var tower: TowerState = _tower(game, build)
	for index in range(45):
		_balloon(game, ["ceramic", "moab", "black", "lead", "bfb"][index % 5], 450.0 + index * 3.0, index % 2 == 0)
	game.simulation_speed = speed
	for frame in range(1200 / speed):
		if frame * speed % 300 == 0:
			game.abilities.activate(tower)
		game._process(MainGame.FIXED_STEP)
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance, balloon.stun_remaining, balloon.pending_push])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var state: AbilityState = game.abilities.state_for(tower)
	var report: Dictionary = {"combat": [live, game.economy.gold, game.economy.lives, game.projectiles._next_id, tower.attack_counter, state.cooldown_remaining if state != null else 0.0], "pops": game.battle_stats.total_pops, "damage": tower.combat_stats.effective_damage if tower.combat_stats != null else 0}
	game.free()
	return report
