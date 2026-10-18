extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const STRATEGIES: Array[String] = ["dart_then_bomb", "mixed", "2-3-0", "3-2-0", "2-0-3"]
const BUILD_TIERS: Dictionary = {"0-0-0": [0, 0, 0], "2-3-0": [2, 3, 0], "0-3-2": [0, 3, 2],
	"3-2-0": [3, 2, 0], "3-0-2": [3, 0, 2], "2-0-3": [2, 0, 3], "0-2-3": [0, 2, 3]}

func create_game(window: Window) -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	window.add_child(game)
	game.set_process(false)
	return game

func upgrade_toward(game: MainGame, tower: TowerState, build: String) -> void:
	for path in range(3):
		for tier in range(tower.tiers[path] + 1, BUILD_TIERS[build][path] + 1):
			if not game.try_upgrade(tower, tower.definition.upgrade_at(path, tier)):
				return

func _place_next(game: MainGame, definition: TowerDefinition) -> bool:
	var priority: Array[Vector2] = [Vector2(250, 350), Vector2(250, 410), Vector2(460, 450), Vector2(672, 232),
		Vector2(460, 650), Vector2(704, 440), Vector2(80, 300), Vector2(860, 420), Vector2(460, 180)]
	for x in [80, 156, 250, 350, 460, 575, 672, 770, 860]:
		for y in [180, 300, 410, 450, 650]:
			priority.append(Vector2(x, y))
	for at in priority:
		if game.try_place_tower(at, definition):
			return true
	return false

func shop(game: MainGame, strategy: String, wave: int) -> void:
	var darts: int = 0
	var bombs: int = 0
	for tower in game.towers.towers:
		if tower.definition == MainGame.DART:
			darts += 1
		else:
			bombs += 1
	if darts == 0 and _place_next(game, MainGame.DART):
		darts += 1
	var desired_bombs: int = 1 if strategy == "mixed" or wave >= 11 else 0
	if wave >= 13:
		desired_bombs = 2 + maxi(0, (wave - 14) / 2)
	while bombs < desired_bombs and _place_next(game, MainGame.BOMB):
		bombs += 1
	var desired_darts: int = 1 + wave / 3 if wave < 12 else 4 + (wave - 12) * 2
	if strategy == "dart_then_bomb" and wave < 6:
		desired_darts = 1 + wave / 2
	while darts < desired_darts and _place_next(game, MainGame.DART):
		darts += 1
	if strategy == "dart_then_bomb" and wave < 6:
		return # Basic darts first; start upgrades in the speed/quantity phase.
	var build: String = strategy if BUILD_TIERS.has(strategy) else "2-3-0"
	for tower in game.towers.towers:
		if tower.definition == MainGame.DART:
			upgrade_toward(game, tower, build)

func campaign(window: Window, strategy: String, speed: int = 1, collect: bool = true) -> Dictionary:
	var game: MainGame = create_game(window)
	game.battle_stats.enabled = collect
	game.simulation_speed = speed
	var wave_results: Array[Dictionary] = []
	for number in range(1, 21):
		shop(game, strategy, number)
		game.start_next_wave()
		for frame in range(90 * 60 / speed):
			game._process(MainGame.FIXED_STEP)
			if game.result != &"":
				break
		wave_results.append({"wave": number, "lives": game.economy.lives, "gold": game.economy.gold,
			"pops": game.battle_stats.total_pops, "towers": game.towers.towers.size()})
		if game.result != &"":
			break
	var combat_result: Dictionary = {"result": game.result, "wave": game.waves.current_wave,
		"lives": game.economy.lives, "gold": game.economy.gold, "earned": game.economy.total_earned,
		"projectiles": game.projectiles._next_id - 1}
	var records: Array[Dictionary] = []
	for record: TowerCombatStats in game.battle_stats.records.values():
		records.append(record.snapshot())
	var report: Dictionary = {"strategy": strategy, "combat": combat_result, "pops": game.battle_stats.total_pops,
		"towers": records, "waves": wave_results}
	game.free()
	return report

func micro(window: Window, build: String, condition: String, at: Vector2) -> Dictionary:
	var cases: Dictionary = {"dense": [["green", 80, 0.025]], "fast": [["pink", 50, 0.1]],
		"black": [["black", 20, 0.16]], "lead": [["lead", 12, 0.35]],
		"mixed": [["lead", 6, 0.4], ["black", 8, 0.15], ["pink", 30, 0.07]]}
	var game: MainGame = create_game(window)
	game.economy.starting_gold = 500
	game.economy.starting_lives = 100000
	game.economy.reset()
	game.try_place_tower(at, MainGame.BOMB if build == "bomb" else MainGame.DART)
	var tower: TowerState = game.towers.towers[0]
	if build != "bomb":
		upgrade_toward(game, tower, build)
	var wave: WaveDefinition = WaveDefinition.new()
	wave.clear_reward = 0
	for row: Array in cases[condition]:
		var group: WaveGroup = WaveGroup.new()
		group.balloon = load("res://data/balloons/%s.tres" % row[0]) as BalloonDefinition
		group.count = row[1]
		group.interval = row[2]
		wave.groups.append(group)
	game.waves.waves = [wave]
	game.start_next_wave()
	for tick in range(60 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
		if game.result != &"":
			break
	var report: Dictionary = tower.combat_stats.snapshot()
	report.merge({"condition": condition, "position": [at.x, at.y], "budget": 500,
		"unspent_budget": 500 - tower.combat_stats.invested_gold, "leaked_layers": 100000 - game.economy.lives,
		"remaining_lives": game.economy.lives, "finished": game.result == &"victory"})
	game.free()
	return report
