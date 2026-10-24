extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const BUILDS: Array = [[3, 0, 2], [2, 0, 3], [0, 3, 2], [0, 2, 3]]
const STRATEGIES: Array[String] = ["none", "top", "middle", "bottom", "cross"]
const PLACEMENT: Script = preload("res://tests/scenarios/balance_scenarios.gd")

func _game(window: Window) -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	window.add_child(game)
	game.set_process(false)
	return game

func micro(window: Window, build: Array, condition: String, speed: int = 1, recursive: bool = false, budget: int = 10000) -> Dictionary:
	var game: MainGame = _game(window)
	# Attack measurement fixture, separate from the normal-budget campaigns.
	game.economy.gold = budget
	game.towers.add_tower(Vector2(250, 350), MainGame.BOMB)
	var tower: TowerState = game.towers.towers[0]
	for path in range(3):
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.BOMB.upgrade_at(path, tier))
	var kind: String = condition if condition in ["black", "white", "lead", "ceramic", "ddt"] else "moab"
	var positions: Array[Vector2] = [Vector2(300, 350)]
	if condition in ["area", "sustained"]:
		positions.clear()
		for offset in [Vector2.ZERO, Vector2(45, 0), Vector2(0, 45), Vector2(45, 45)]:
			for index in range(4):
				positions.append(Vector2(300, 350) + offset)
	for at in positions:
		var balloon: BalloonState = game.balloons.spawn(load("res://data/balloons/%s.tres" % kind), 500.0, condition == "camo", condition == "ceramic", true)
		balloon.position = at
		balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	var origin: Vector2 = Vector2(250, 350) if condition == "incoming" else Vector2(300, 350)
	var legal: bool = game.combat.can_target(game.balloons.balloons[0], tower.stats)
	if condition != "sustained":
		var shot: ProjectileState = game.projectiles.launch(origin, Vector2.RIGHT, tower.stats, tower.id)
		shot.recursive = recursive
		game.battle_stats.record_volley(tower.id)
	for frame in range((600 if condition == "sustained" else 60) / speed):
		for step in range(speed):
			game.combat.update(MainGame.FIXED_STEP)
			if condition == "sustained":
				game.towers.update(MainGame.FIXED_STEP)
			game.projectiles.update(MainGame.FIXED_STEP)
	var live: Array = []
	for balloon in game.balloons.balloons:
		live.append([balloon.id, str(balloon.definition.id), balloon.shell_hp, balloon.fortified, balloon.camo])
	live.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var report: Dictionary = {"build": build, "condition": condition, "can_target": legal, "damage": tower.combat_stats.effective_damage,
		"moab_damage": tower.combat_stats.moab_damage, "pops": tower.combat_stats.pops(), "gold_earned": tower.combat_stats.gold_earned,
		"pierce_used": tower.combat_stats.pierce_used, "projectiles": tower.combat_stats.projectiles,
		"split_projectiles": tower.combat_stats.split_projectiles, "volleys": tower.combat_stats.volleys,
		"live": live, "projectiles_end": game.projectiles.projectiles.size(), "effects_end": game.combat.effects.size() + game.projectiles.split_effects.size()}
	game.free()
	return report

func _buy_next(game: MainGame, definition: TowerDefinition, wave: int, log: Array[Dictionary]) -> bool:
	var before: int = game.economy.gold
	var placed: bool = PLACEMENT.new()._place_next(game, definition)
	if not placed and game.economy.gold >= definition.cost:
		for y in range(160, 650, 56):
			for x in range(80, 920, 56):
				if game.try_place_tower(Vector2(x, y), definition):
					placed = true
					break
			if placed:
				break
	if not placed:
		return false
	var tower: TowerState = game.towers.towers.back()
	log.append({"wave": wave, "id": tower.id, "kind": str(definition.id), "position": [tower.position.x, tower.position.y], "cost": before - game.economy.gold, "balance": game.economy.gold})
	return true

func _shop(game: MainGame, strategy: String, wave: int, log: Array[Dictionary]) -> void:
	var darts: int = 0
	var bombs: Array[TowerState] = []
	for tower in game.towers.towers:
		if tower.definition == MainGame.DART:
			darts += 1
		else:
			bombs.append(tower)
	if darts == 0 and _buy_next(game, MainGame.DART, wave, log):
		darts += 1
	if bombs.is_empty() and _buy_next(game, MainGame.BOMB, wave, log):
		bombs.append(game.towers.towers.back())
	if strategy != "none":
		for index in range(bombs.size()):
			_upgrade_bomb(game, bombs[index], index, strategy, wave, log)
	# Spend remaining legal income rather than declaring a build weak while
	# hoarding cash behind an artificial unit cap. Shared 2-dart:1-bomb policy.
	while game.economy.gold >= MainGame.DART.cost:
		var definition: TowerDefinition = MainGame.DART if darts < bombs.size() * 2 or game.economy.gold < MainGame.BOMB.cost else MainGame.BOMB
		if not _buy_next(game, definition, wave, log):
			break
		if definition == MainGame.DART:
			darts += 1
		else:
			bombs.append(game.towers.towers.back())
			if strategy != "none":
				_upgrade_bomb(game, bombs.back(), bombs.size() - 1, strategy, wave, log)

func _upgrade_bomb(game: MainGame, tower: TowerState, index: int, strategy: String, wave: int, log: Array[Dictionary]) -> void:
	var build: Array = {"top": [3, 0, 0], "middle": [0, 3, 0], "bottom": [0, 0, 3], "cross": BUILDS[index % BUILDS.size()]}[strategy]
	for path in range(3):
		for tier in range(tower.tiers[path] + 1, build[path] + 1):
			var item: UpgradeDefinition = MainGame.BOMB.upgrade_at(path, tier)
			if not game.try_upgrade(tower, item):
				break
			log.append({"wave": wave, "id": tower.id, "upgrade": str(item.id), "cost": item.cost, "balance": game.economy.gold})

func campaign(window: Window, strategy: String, speed: int = 1) -> Dictionary:
	var game: MainGame = _game(window)
	game.simulation_speed = speed
	game.balloons.profile_changes = true
	var leaks: Dictionary = {"instances": 0, "rbe": 0}
	game.balloons.leaked.connect(func(amount: int) -> void:
		leaks.instances += 1
		leaks.rbe += amount)
	var log: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	for number in range(1, 21):
		_shop(game, strategy, number, log)
		game.start_next_wave()
		for frame in range(90 * 60 / speed):
			game._process(MainGame.FIXED_STEP)
			if game.result != &"":
				break
			# Next purchase/start is always on an integral simulation second.
			# Both speed settings receive identical inputs, even if a wave clears
			# during the first of a two-step frame.
			if not game.waves.active and (frame + 1) * speed % 60 == 0:
				break
		waves.append({"wave": number, "lives": game.economy.lives, "gold": game.economy.gold, "pops": game.battle_stats.total_pops})
		if game.result != &"" or game.waves.active:
			break
	var invested: int = 0
	var towers: Array[Dictionary] = []
	for tower: TowerState in game.towers.towers:
		invested += tower.combat_stats.invested_gold
		towers.append({"id": tower.id, "kind": str(tower.definition.id), "build": tower.upgrade_text(), "invested": tower.combat_stats.invested_gold, "pops": tower.combat_stats.pops()})
	var report: Dictionary = {"strategy": strategy, "result": str(game.result), "wave": game.waves.current_wave,
		"cost": invested, "earned": game.economy.total_earned, "pops": game.battle_stats.total_pops,
		"removed_instances": game.balloons.removal_count - leaks.instances, "leaked_instances": leaks.instances, "leaked_rbe": leaks.rbe,
		"lives": game.economy.lives, "gold": game.economy.gold, "towers": towers, "purchases": log, "waves": waves,
		"projectiles_created": game.projectiles._next_id - 1, "balloons_created": game.balloons.latest_id()}
	game.free()
	return report
