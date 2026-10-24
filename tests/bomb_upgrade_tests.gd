extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_catalog()
	_crosspaths()
	_blasts()
	_fragments()
	_clusters()
	_moabs()
	_lifecycle()
	for build: Array in [[3, 2, 0], [0, 3, 2], [2, 0, 3]]:
		var one: Dictionary = _battle(build, 1)
		_check(one == _battle(build, 2), "bomb %s exact process accumulator 1x/2x" % str(build))
		_check(one.combat == _battle(build, 1, false).combat, "bomb stats never change combat")
		_check(one.damage > 0 and one.combat[3] > 1, "actual tower attacks produce damage")
	print("BOMB UPGRADES: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BOMB FAIL: " + label)

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	return game

func _tower(game: MainGame, build: Array = [0, 0, 0]) -> TowerState:
	game.towers.add_tower(Vector2(250, 350), MainGame.BOMB)
	var tower: TowerState = game.towers.towers.back()
	for path in range(3):
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.BOMB.upgrade_at(path, tier))
	return tower

func _at(game: MainGame, id: String, at: Vector2 = Vector2(300, 350), armor: bool = false, camo: bool = false) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % id), 500.0, camo, armor, true)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _ticks(game: MainGame, count: int) -> void:
	for step in range(count):
		game.combat.update(MainGame.FIXED_STEP)
		game.projectiles.update(MainGame.FIXED_STEP)

func _catalog() -> void:
	var base: TowerDefinition = MainGame.BOMB
	_check(base.cost == 150 and base.damage == 1 and base.pierce == 12 and base.attack_range == 165 and base.fire_interval == 1.35 and base.explosion_radius == 68 and base.projectile_speed == 360, "all original bomb base values preserved")
	_check(base.upgrades.filter(func(item: UpgradeDefinition) -> bool: return item.tier <= 3).size() == 9, "original nine bomb upgrades preserved")
	var ids: Dictionary = {}
	for item in base.upgrades:
		if item.tier > 3:
			continue # Freeze this historical suite's tier1-3 domain and check count.
		_check(item.tier <= 3 and not ids.has(item.id) and item.cost > 0 and not item.description.is_empty(), "unique valid data and player description")
		ids[item.id] = true
	for path in range(3):
		var game: MainGame = _game()
		var tower: TowerState = _tower(game)
		for tier in range(1, 4):
			var item: UpgradeDefinition = base.upgrade_at(path, tier)
			var before: int = game.economy.gold
			var preview: TowerDefinition = TowerStatResolver.preview(base, tower.tiers, item)
			tower.cooldown = tower.stats.fire_interval * 0.5
			_check(game.try_upgrade(tower, item), "buy each bomb path/tier")
			_check(game.economy.gold == before - item.cost and tower.spent_on_upgrades > 0, "real debit exactly once")
			_check(is_equal_approx(tower.cooldown, tower.stats.fire_interval * 0.5), "purchase preserves reload fraction")
			_check(not game.try_upgrade(tower, item) and game.economy.gold == before - item.cost, "stale duplicate purchase atomic")
			for field in TowerStatResolver.FIELDS.slice(0, 24):
				_check(preview.get(field) == tower.stats.get(field), "all preview fields equal actual purchase")
			if path == 0:
				_check(tower.stats.damage == [1, 2, 3][tier - 1] and tower.stats.pierce == [16, 22, 32][tier - 1] and tower.stats.explosion_radius == [82, 82, 104][tier - 1], "top exact AoE/damage/pierce")
			elif path == 1:
				_check(is_equal_approx(tower.stats.fire_interval, [1.08, 0.81, 0.81][tier - 1]) and tower.stats.projectile_speed == [360, 540, 540][tier - 1] and tower.stats.moab_bonus == [0, 0, 18][tier - 1], "middle exact reload/speed/MOAB")
			else:
				_check(tower.stats.attack_range == 195 and (tower.stats.projectile_split != null) == (tier >= 2), "bottom range then real child profile")
		_check(base.upgrade_at(path, 4) != null and base.max_upgrade_tier(path) == 5 and game.upgrades.error_for_path(tower, path).is_empty(), "v0.12 tier3 now offers tier4 under the same purchase policy")
		var before_stats: TowerDefinition = tower.stats
		for repeat in range(10):
			tower.stats = TowerStatResolver.resolve(base, tower.tiers)
		_check(tower.stats.damage == before_stats.damage and tower.stats.fire_interval == before_stats.fire_interval and tower.stats.projectile_split == before_stats.projectile_split, "repeat resolution never compounds")
		game.free()
	var poor: MainGame = _game()
	var buyer: TowerState = _tower(poor)
	poor.economy.gold = 79
	_check(not poor.try_upgrade(buyer, base.upgrade_at(0, 1)) and poor.economy.gold == 79 and buyer.tiers[0] == 0, "insufficient funds atomic")
	poor.economy.gold = 80
	_check(poor.try_upgrade(buyer, base.upgrade_at(0, 1)) and poor.economy.gold == 0, "exact funds accepted")
	_check(not poor.try_upgrade(buyer, MainGame.DART.upgrade_at(0, 1)), "foreign tower upgrade rejected")
	poor.economy.gold = 1000
	poor._finish(false)
	_check(not poor.try_upgrade(buyer, base.upgrade_at(0, 2)) and poor.economy.gold == 1000, "ended game rejects purchase")
	poor.free()

func _crosspaths() -> void:
	for main in range(3):
		for secondary in range(3):
			if main == secondary:
				continue
			var game: MainGame = _game()
			var tower: TowerState = _tower(game)
			for tier in range(1, 3):
				game.try_upgrade(tower, MainGame.BOMB.upgrade_at(main, tier))
				game.try_upgrade(tower, MainGame.BOMB.upgrade_at(secondary, tier))
			_check(UpgradePolicy.main_path(tower.tiers) == -1, "2/2 bomb does not preselect main")
			_check(game.try_upgrade(tower, MainGame.BOMB.upgrade_at(main, 3)), "either invested path may become main")
			var gold: int = game.economy.gold
			_check(not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(secondary, 3)) and not game.try_upgrade(tower, MainGame.BOMB.upgrade_at(3 - main - secondary, 1)) and game.economy.gold == gold, "secondary3 and third path blocked without debit")
			var preview: TowerDefinition = TowerStatResolver.resolve(MainGame.BOMB, tower.tiers)
			var other: TowerState = _tower(game)
			for path in [secondary, main]:
				for tier in range(1, tower.tiers[path] + 1):
					game.try_upgrade(other, MainGame.BOMB.upgrade_at(path, tier))
			_check(other.stats.damage == preview.damage and other.stats.fire_interval == preview.fire_interval and other.stats.projectile_split == preview.projectile_split and other.stats.moab_bonus == preview.moab_bonus, "crosspath purchase order independent")
			game.select_instance(tower)
			_check(game.hud.upgrade_panel._stats.text.contains("EXPLOSIVE"), "shared selected tower UI")
			game.free()

func _blasts() -> void:
	for build: Array in [[0, 0, 0], [1, 0, 0], [2, 0, 0], [3, 0, 0]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		for index in range(40):
			_at(game, "blue")
		game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
		_ticks(game, 1)
		_check(tower.combat_stats.pierce_used == tower.stats.pierce, "AoE caps independently at upgrade pierce")
		_check(tower.combat_stats.effective_damage == tower.stats.pierce * mini(2, tower.stats.damage), "no separate direct hit or same blast duplicate")
		_check(game.projectiles.projectiles.is_empty() and game.combat.effects.size() == 1, "one blast consumes parent")
		_ticks(game, 30)
		_check(game.combat.effects.is_empty(), "blast visual expires")
		game.free()
	for row: Array in [["black", false, 0], ["white", false, 3], ["lead", false, 1], ["lead", true, 2], ["ceramic", false, 2], ["ceramic", true, 2], ["red", false, 1]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [2, 0, 0])
		_at(game, row[0], Vector2(300, 350), row[1])
		game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
		_ticks(game, 1)
		_check(tower.combat_stats.effective_damage == row[2], "HP and immunity " + str(row))
		_check(tower.combat_stats.pierce_used <= 1, "HP-only contact consumes one pierce")
		_check(tower.combat_stats.gold_earned == tower.combat_stats.pops(), "only removed shells reward, never HP-only")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [3, 0, 0])
	_at(game, "red", Vector2(404, 350))
	_at(game, "red", Vector2(404.01, 350))
	var hit: AttackSpec = tower.stats.make_attack()
	_check(game.combat.explode(Vector2(300, 350), hit).size() == 1, "upgraded AoE exact boundary")
	game.free()

func _fragments() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 2])
	var black: BalloonState = _at(game, "black", Vector2(310, 350))
	_check(game.towers._first_in_range(tower) == black, "frag SHARP child permits targeting black without changing bomb immunity")
	game.projectiles.fire_volley(Vector2(300, 350), black, tower.stats, tower.id)
	_ticks(game, 1)
	_check(tower.combat_stats.split_projectiles == 8 and tower.combat_stats.projectiles == 9 and tower.combat_stats.volleys == 1, "eight real fragments attributed without extra volleys")
	_check(game.balloons.find(black.id) == null and game.balloons.balloons.size() == 2 and tower.combat_stats.effective_damage == 1, "fragment removes immune black, newborns excluded in same batch")
	_check(game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.shell_hp == 1 and b.definition.id == &"pink"), "black children receive no repeated contact this step")
	_ticks(game, 60)
	_check(game.projectiles.projectiles.is_empty() and game.projectiles.split_effects.is_empty(), "fragments and emission effects expire")
	game.free()
	for kind in ["lead", "black", "white"]:
		game = _game()
		tower = _tower(game, [0, 0, 2])
		var balloon: BalloonState = _at(game, kind)
		var profile: TowerDefinition = tower.stats.projectile_split.child_projectile as TowerDefinition
		game.projectiles.launch(Vector2(280, 350), Vector2.RIGHT, profile, tower.id, true)
		_ticks(game, 12)
		_check((game.balloons.find(balloon.id) == null) == (kind != "lead"), "fragment SHARP interaction " + kind)
		game.free()
	game = _game()
	tower = _tower(game, [3, 0, 2])
	var parent: ProjectileState = game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	_check(parent.child_profile.damage == 3 and parent.child_profile.pierce == 1, "top damage crosses into frag but pierce remains separate")
	parent.child_profile.damage = 99
	_check((tower.stats.projectile_split.child_projectile as TowerDefinition).damage == 1, "child snapshots never mutate Resource")
	game.projectiles.projectiles.clear()
	parent = game.projectiles.launch(Vector2(100, 100), Vector2.RIGHT, tower.stats, tower.id)
	_ticks(game, 240)
	_check(tower.combat_stats.split_projectiles == 0 and game.projectiles.projectiles.is_empty(), "missed bomb expiry does not emit fragments")
	game.free()

func _clusters() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 3])
	var center: BalloonState = _at(game, "moab")
	var side: BalloonState = _at(game, "moab", Vector2(345, 350))
	game.projectiles.fire_volley(Vector2(300, 350), side, tower.stats, tower.id)
	_ticks(game, 1)
	_check(center.shell_hp == 199 and side.shell_hp == 199 and game.projectiles.projectiles.size() == 8, "cluster first blast then eight real fused children")
	_check(game.projectiles.projectiles.all(func(s: ProjectileState) -> bool: return s.timed_explosion and s.attack.attribute == AttackSpec.Attribute.EXPLOSIVE and s.attack.pierce == 8 and s.attack.damage == 1), "all clusters have independent explosive budgets")
	_ticks(game, 6)
	_check(side.shell_hp == 199, "cluster waits for fuse, no early contact damage")
	_ticks(game, 5)
	_check(side.shell_hp == 196 and center.shell_hp == 199, "three intended overlapping extra AoEs each hit once at outward positions")
	_check(game.projectiles.projectiles.is_empty() and game.combat.effects.size() == 9, "all eight additional explosions resolve once and projectiles retire")
	_check(tower.combat_stats.split_projectiles == 8 and tower.combat_stats.volleys == 1 and tower.combat_stats.effective_damage == 5, "cluster confirmed damage and source stats")
	_ticks(game, 40)
	_check(game.combat.effects.is_empty() and game.projectiles.split_effects.is_empty(), "all cluster visuals expire")
	game.free()
	game = _game()
	tower = _tower(game, [2, 0, 3])
	_at(game, "black")
	_check(game.towers._first_in_range(tower) == null, "explosive clusters preserve black immunity")
	var parent: ProjectileState = game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	_check(parent.child_profile.damage == 2 and parent.child_profile.pierce == 8 and parent.child_profile.projectile_split == null, "203 top damage inherited and no recursive emission")
	_ticks(game, 60)
	_check(tower.combat_stats.effective_damage == 0 and tower.combat_stats.split_projectiles == 8, "immune trigger still emits exactly eight explosions, none damage black")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 3])
	for index in range(12):
		_at(game, "moab")
	var child: TowerDefinition = tower.stats.projectile_split.child_projectile as TowerDefinition
	game.projectiles.launch(Vector2(255.2, 350), Vector2.RIGHT, child, tower.id, true)
	_ticks(game, 12)
	_check(tower.combat_stats.pierce_used == 8 and tower.combat_stats.effective_damage == 8, "one fused cluster hits multiple balloons with strict8 pierce")
	_check(game.balloons.balloons.filter(func(b: BalloonState) -> bool: return b.shell_hp == 199).size() == 8, "one cluster never hits same balloon twice")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 3])
	_at(game, "moab")
	game.projectiles.launch(Vector2(250, 350), Vector2.RIGHT, tower.stats, tower.id)
	game.projectiles.update(0.2)
	_check(game.combat.effects.size() == 9 and game.projectiles.projectiles.is_empty(), "children can expire in remaining part of birth step")
	for index in range(1, game.combat.effects.size()):
		_check(is_equal_approx((game.combat.effects[index].position as Vector2).distance_to(Vector2(265, 350)), 44.8), "cluster trajectory starts at birth contact, travels only fuse duration")
	game.free()

func _moabs() -> void:
	var cross: MainGame = _game()
	var mauler: TowerState = _tower(cross, [0, 3, 2])
	var shot: ProjectileState = cross.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, mauler.stats, mauler.id)
	_check(shot.attack.moab_bonus == 18 and shot.child_profile.moab_bonus == 0 and shot.child_profile.damage == 1, "Mauler bonus belongs only to primary explosion, no eightfold reapplication")
	cross.free()
	for kind in ["moab", "bfb", "zomg", "bad", "ddt", "ceramic"]:
		for armor in [false, true]:
			var game: MainGame = _game()
			var tower: TowerState = _tower(game, [2, 3, 0])
			var balloon: BalloonState = _at(game, kind, Vector2(300, 350), armor)
			var hp: int = balloon.shell_hp
			var attack: AttackSpec = tower.stats.make_attack()
			attack.source_id = tower.id
			var applied: int = game.combat.apply_hit(balloon.id, attack)
			var expected: int = 0 if kind == "ddt" else (2 if kind == "ceramic" else 20)
			_check(applied == expected and balloon.shell_hp == hp - expected, "Mauler ordinary/MOAB/composite armor " + kind)
			_check(tower.combat_stats.pops() == 0 and tower.combat_stats.gold_earned == 0, "Mauler HP damage never grants early rewards")
			_check(tower.combat_stats.moab_damage == (expected if kind != "ceramic" else 0), "Mauler MOAB stats use actual removed HP")
			game.free()
	for row: Array in [["moab", "ceramic", 4], ["bfb", "moab", 4], ["zomg", "bfb", 4]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, [0, 3, 2])
		var parent: BalloonState = _at(game, row[0], Vector2(300, 350), true)
		parent.shell_hp = 1
		var excluded: Dictionary = {}
		var attack: AttackSpec = tower.stats.make_attack()
		attack.source_id = tower.id
		_check(game.combat.apply_hit(parent.id, attack, 1.0, excluded) == 1, "MOAB overkill blocked from children")
		_check(game.balloons.balloons.size() == row[2] and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.definition.id == StringName(row[1]) and b.fortified and b.shell_hp == b.shell_max_hp), "all real fortified descendants intact")
		_check(tower.combat_stats.gold_earned == 1 and tower.combat_stats.pops() == 1 and excluded.size() == 5, "one shell reward and all child exclusions")
		game.free()

func _lifecycle() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 2])
	var shot: ProjectileState = game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	game.try_upgrade(tower, MainGame.BOMB.upgrade_at(0, 1))
	game.try_upgrade(tower, MainGame.BOMB.upgrade_at(0, 2))
	_check(shot.attack.damage == 1 and shot.child_profile.damage == 1 and tower.stats.damage == 2, "upgrade cannot mutate launched parent/child snapshot")
	game.towers.remove_tower(tower)
	_at(game, "blue")
	_ticks(game, 60)
	_check(game.projectiles.projectiles.is_empty() and tower.combat_stats.split_projectiles == 8 and tower.combat_stats.effective_damage > 0, "deleting tower preserves flying child attribution and finite lifetime")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 3])
	_at(game, "ceramic", Vector2(300, 350), false, true)
	game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	_ticks(game, 30)
	_check(tower.combat_stats.effective_damage == 0 and tower.combat_stats.split_projectiles == 0, "camo contact never triggers primary or children")
	game.free()
	game = _game()
	tower = _tower(game, [2, 0, 3])
	for index in range(100):
		_at(game, "moab")
		game.projectiles.launch(Vector2(300, 350), Vector2.RIGHT, tower.stats, tower.id)
	_ticks(game, 1)
	_check(tower.combat_stats.split_projectiles == 800 and game.projectiles.projectiles.size() == 800, "100 simultaneous blasts emit exactly800 independent children")
	_ticks(game, 120)
	_check(game.projectiles.projectiles.is_empty() and game.combat.effects.is_empty() and game.projectiles.split_effects.is_empty(), "simultaneous explosion stress drains all objects/effects")
	_check(MainGame.BOMB.damage == 1 and MainGame.BOMB.projectile_split == null and (load("res://data/projectiles/bomb_cluster.tres") as TowerDefinition).damage == 1, "stress preserves shared base resources")
	game.free()

func _battle(build: Array, speed: int, stats: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = stats
	var tower: TowerState = _tower(game, build)
	game.simulation_speed = speed
	for index in range(60):
		game.balloons.spawn(load("res://data/balloons/%s.tres" % ["pink", "black", "lead", "ceramic", "moab"][index % 5]), 400.0 + index * 2.0, false, index % 3 == 0, true)
	for frame in range(1200 / speed):
		game._process(MainGame.FIXED_STEP)
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, balloon.definition.id, balloon.shell_hp, balloon.distance])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Dictionary = {"combat": [game.economy.gold, game.economy.lives, live, game.projectiles._next_id], "damage": tower.combat_stats.effective_damage, "stats": tower.combat_stats.snapshot()}
	game.free()
	return result
