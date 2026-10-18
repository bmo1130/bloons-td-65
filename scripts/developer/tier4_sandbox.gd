extends Node

# Isolated developer economy/content. No normal campaign resource is modified.
static var scenario_index: int = 0
const BUILDS: Array = [[4, 2, 0], [4, 0, 2], [2, 4, 0], [0, 4, 2], [2, 0, 4], [0, 2, 4]]
const TITLES: Array[String] = ["직접 4티어 구매", "저거너트 / 도탄", "팬클럽 2기 / 10기 변신", "명사수 / CRIT", "6개 교차 경로"]
var game: MainGame
var bounce_button: Button
var wait_button: Button

func _ready() -> void:
	game = get_parent() as MainGame
	game.economy.gold = 100000
	game.economy.lives = 100000
	game.economy.changed.emit(game.economy.gold, game.economy.lives)
	var positions: Array[Vector2] = []
	for y in range(180, 640, 56):
		for x in range(80, 920, 56):
			var at: Vector2 = Vector2(x, y)
			if game.route.can_build(at, 20.0):
				positions.append(at)
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(Vector2(360, 340)) < b.distance_squared_to(Vector2(360, 340)))
	var builds: Array = []
	match scenario_index:
		0:
			builds = [[3, 2, 0], [3, 0, 2], [2, 3, 0], [0, 3, 2], [2, 0, 3], [0, 2, 3]]
		1:
			builds = [[4, 2, 0], [4, 0, 2]]
		2:
			builds = [[2, 4, 0], [0, 4, 2], [2, 2, 0], [0, 2, 2], [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0], [3, 0, 0], [0, 0, 3]]
		3:
			builds = [[2, 0, 4], [0, 2, 4]]
		4:
			builds = BUILDS
	for index in range(builds.size()):
		game.try_place_tower(positions[index])
		var tower: TowerState = game.towers.towers.back()
		for path in range(3):
			for tier in range(1, builds[index][path] + 1):
				game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	if scenario_index == 2:
		game.try_place_tower(positions[builds.size()], MainGame.BOMB)
	var waves: Array[WaveDefinition] = []
	for type: String in ["green", "pink", "lead", "black", "pink"]:
		var wave: WaveDefinition = WaveDefinition.new()
		var group: WaveGroup = WaveGroup.new()
		group.balloon = load("res://data/balloons/%s.tres" % type) as BalloonDefinition
		group.count = 240 if type != "lead" else 40
		group.interval = 0.08
		wave.groups = [group]
		wave.clear_reward = 0
		waves.append(wave)
	game.waves.waves = waves
	game.hud.set_wave(0, waves.size(), false)
	for index in range(TITLES.size()):
		var button: Button = _button(TITLES[index], Vector2(28 + index * 187, 108), Vector2(181, 28))
		button.pressed.connect(_choose.bind(index))
	bounce_button = _button("경계 도탄 시연", Vector2(28, 640), Vector2(150, 28))
	bounce_button.pressed.connect(_bounce_demo)
	wait_button = _button("준비 시간 +17초", Vector2(184, 640), Vector2(150, 28))
	wait_button.pressed.connect(func() -> void:
		for tick in range(17 * 60):
			game.simulation_step(MainGame.FIXED_STEP))
	var label: Label = Label.new()
	label.text = "개발자 전용 100,000G · 타워 클릭→구매/능력 · Space: 밀집 웨이브 · F6: 일반 모드"
	label.position = Vector2(340, 645)
	label.add_theme_font_size_override("font_size", 12)
	game.hud._root.add_child(label)
	game.select_instance(game.towers.towers[0])

func _button(text: String, at: Vector2, bounds: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = bounds
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	game.hud._root.add_child(button)
	return button

func _choose(index: int) -> void:
	scenario_index = index
	game.get_tree().reload_current_scene.call_deferred()

func _bounce_demo() -> void:
	var stats: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, PackedInt32Array([4, 0, 2]))
	# Real map boundary, real swept collisions; no target-following shortcut.
	var target: BalloonState = game.balloons.spawn(load("res://data/balloons/pink.tres"), game.route.total_length - 64)
	game.projectiles.launch(target.position - Vector2(70, 0), Vector2.RIGHT, stats)
