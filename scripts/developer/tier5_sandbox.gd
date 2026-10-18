extends Node

static var scenario_index: int = 0
static var specimen_index: int = 0
static var _command_line_applied: bool = false
const TITLES: Array[String] = ["직접5티어 / 유일성", "울트라 / 분열·범퍼", "플라즈마20기 / 중첩", "석궁의 대가 / CRIT", "5티어3종 혼합"]
var game: MainGame
var pause_button: Button
var type_picker: OptionButton
var preset_picker: OptionButton
var quantity: SpinBox
var camo_toggle: CheckButton
var fortified_toggle: CheckButton
var specimen_status: Label
var _status_elapsed: float = 0.0
var _spawn_batch: int = 0
const SPECIMENS: Array[String] = ["기본 다트 vs 카모", "002 다트 vs 카모", "400 vs 카모 납", "402 vs 카모 납", "폭탄 vs 강화 납", "기본 다트 vs 세라믹", "400 vs 세라믹", "502 vs 강화 세라믹", "052 팬클럽 vs 카모", "520 vs 세라믹 물량"]
const BALLOON_IDS: Array[String] = ["red", "blue", "green", "yellow", "pink", "black", "white", "zebra", "rainbow", "lead", "ceramic"]
const BALLOON_NAMES: Array[String] = ["빨강", "파랑", "초록", "노랑", "분홍", "검정", "하얀", "얼룩말", "무지개", "납", "세라믹"]

func _ready() -> void:
	game = get_parent() as MainGame
	if not _command_line_applied:
		_command_line_applied = true
		if OS.get_cmdline_user_args().has("--specimen-lab"):
			scenario_index = 5
	game.economy.gold = 200000
	game.economy.lives = 100000
	game.economy.changed.emit(game.economy.gold, game.economy.lives)
	var positions: Array[Vector2] = []
	for y in range(180, 640, 56):
		for x in range(80, 920, 56):
			var at: Vector2 = Vector2(x, y)
			if game.route.can_build(at, 20.0):
				positions.append(at)
	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da: float = a.distance_squared_to(Vector2(300, 330))
		var db: float = b.distance_squared_to(Vector2(300, 330))
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	var builds: Array = []
	match scenario_index:
		0:
			builds = [[4, 2, 0], [4, 0, 2], [2, 4, 0], [0, 4, 2], [2, 0, 4], [0, 2, 4]]
		1:
			builds = [[5, 2, 0], [4, 0, 2]]
			game.projectiles.ricochet_obstacles = [Rect2(450, 260, 20, 160)]
		2:
			builds = [[2, 5, 0], [0, 4, 2]]
			for index in range(20):
				builds.append([2, 2, 0] if index % 2 == 0 else [0, 0, 2])
			builds.append([3, 0, 0])
			builds.append([0, 0, 3])
		3:
			builds = [[2, 0, 5], [0, 2, 4]]
		4:
			builds = [[5, 2, 0], [2, 5, 0], [0, 2, 5]]
			for index in range(19):
				builds.append([2, 2, 0])
		5:
			builds = [[[0, 0, 0]], [[0, 0, 2]], [[4, 0, 0]], [[4, 0, 2]], [], [[0, 0, 0]], [[4, 0, 0]], [[5, 0, 2]], [[0, 5, 2], [0, 0, 2], [0, 0, 0]], [[5, 2, 0]]][specimen_index]
	for index in range(builds.size()):
		game.try_place_tower(positions[index])
		var tower: TowerState = game.towers.towers.back()
		for path in range(3):
			for tier in range(1, builds[index][path] + 1):
				game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	if scenario_index == 2:
		game.try_place_tower(positions[builds.size()], MainGame.BOMB)
	if scenario_index == 5 and specimen_index == 4:
		game.try_place_tower(positions[0], MainGame.BOMB)
	game.waves.waves.clear()
	game.hud.set_wave(0, 0, false)
	game.hud._start.disabled = false
	game.hud._start.text = "밀집150 소환 [Space]"
	game.hud.wave_requested.connect(spawn_default)
	for index in range(TITLES.size()):
		var button: Button = _button(TITLES[index], Vector2(28 + index * 187, 108), Vector2(181, 28))
		button.pressed.connect(_choose.bind(index))
	_button("밀집150", Vector2(28, 640)).pressed.connect(func() -> void: spawn_group("green", 150))
	_button("고속80", Vector2(144, 640)).pressed.connect(func() -> void: spawn_group("pink", 80))
	_button("납40", Vector2(260, 640)).pressed.connect(func() -> void: spawn_group("lead", 40))
	_button("검정80", Vector2(376, 640)).pressed.connect(func() -> void: spawn_group("black", 80))
	_button("능력 충전", Vector2(492, 640)).pressed.connect(charge)
	pause_button = _button("일시정지", Vector2(608, 640))
	pause_button.pressed.connect(func() -> void:
		game.experiment_paused = not game.experiment_paused
		pause_button.text = "계속" if game.experiment_paused else "일시정지")
	_button("초기화", Vector2(724, 640)).pressed.connect(func() -> void: game.get_tree().reload_current_scene.call_deferred())
	_button("선택 제거", Vector2(840, 640)).pressed.connect(func() -> void:
		if game.selected_instance != null:
			game.towers.remove_tower(game.selected_instance)
			game.select_instance(null)
			game.hud.upgrade_panel.refresh())
	_button("풍선 검사실", Vector2(840, 604)).pressed.connect(_choose.bind(5))
	if scenario_index == 5:
		_specimen_controls()
	game.hud._wave.text = "5티어 실험"
	game.hud._status.text = "실험 전용 · 일반 모드는 F6"
	game.hud._wave_help.text = "F6: 일반 / F7: 실험 전환"
	game.hud._hint.text = "200,000G · 제거 시 환급 없음\n능력 충전은 실험 전용입니다"
	game.select_instance(game.towers.towers[0])
	if scenario_index == 5:
		game.hud._status.text = "카모·외피 검사실 · 일반 모드는 F6"
		game.hud._wave.text = "풍선 검사실"
		game.hud._start.text = "선택 풍선 소환 [Space]"

func _specimen_controls() -> void:
	var backdrop: Panel = Panel.new()
	backdrop.position = Vector2(28, 144)
	backdrop.size = Vector2(932, 80)
	game.hud._root.add_child(backdrop)
	var presets: OptionButton = OptionButton.new()
	preset_picker = presets
	presets.position = Vector2(38, 148)
	presets.size = Vector2(310, 30)
	for title in SPECIMENS:
		presets.add_item(title)
	presets.selected = specimen_index
	presets.item_selected.connect(func(index: int) -> void:
		specimen_index = index
		game.get_tree().reload_current_scene.call_deferred())
	game.hud._root.add_child(presets)
	type_picker = OptionButton.new()
	type_picker.position = Vector2(38, 184)
	type_picker.size = Vector2(140, 30)
	for title in BALLOON_NAMES:
		type_picker.add_item(title)
	type_picker.selected = 9 if specimen_index in [2, 3, 4] else (10 if specimen_index in [5, 6, 7, 9] else 0)
	type_picker.item_selected.connect(func(_index: int) -> void: _allow_armor())
	game.hud._root.add_child(type_picker)
	quantity = SpinBox.new()
	quantity.position = Vector2(186, 184)
	quantity.size = Vector2(90, 30)
	quantity.min_value = 1
	quantity.max_value = 1000
	quantity.value = 100 if specimen_index == 9 else 10
	game.hud._root.add_child(quantity)
	camo_toggle = CheckButton.new()
	camo_toggle.text = "카모"
	camo_toggle.position = Vector2(282, 184)
	camo_toggle.button_pressed = specimen_index in [0, 1, 2, 3, 8]
	game.hud._root.add_child(camo_toggle)
	fortified_toggle = CheckButton.new()
	fortified_toggle.text = "강화"
	fortified_toggle.position = Vector2(392, 184)
	fortified_toggle.button_pressed = specimen_index in [4, 7]
	game.hud._root.add_child(fortified_toggle)
	_allow_armor()
	_button("선택 풍선 소환", Vector2(506, 184), Vector2(126, 30)).pressed.connect(spawn_selected)
	specimen_status = Label.new()
	specimen_status.position = Vector2(640, 148)
	specimen_status.size = Vector2(300, 66)
	specimen_status.add_theme_font_size_override("font_size", 12)
	game.hud._root.add_child(specimen_status)
	var note: Label = Label.new()
	note.text = "실험실: 자식별 잔여 피해 전달\n기존20웨이브: 분기 피해 중단 유지"
	note.position = Vector2(366, 148)
	note.add_theme_font_size_override("font_size", 11)
	game.hud._root.add_child(note)

func _allow_armor() -> void:
	if fortified_toggle == null:
		return
	var data: BalloonDefinition = load("res://data/balloons/%s.tres" % BALLOON_IDS[type_picker.selected])
	fortified_toggle.disabled = data.fortified_hp <= 0
	if fortified_toggle.disabled:
		fortified_toggle.button_pressed = false

func spawn_selected() -> void:
	if game.result != &"":
		return
	var data: BalloonDefinition = load("res://data/balloons/%s.tres" % BALLOON_IDS[type_picker.selected])
	for index in range(int(quantity.value)):
		game.balloons.spawn(data, 500.0 + (_spawn_batch % 6) * 60.0 + (index % 100) * 1.5, camo_toggle.button_pressed, fortified_toggle.button_pressed, true)
	_spawn_batch += 1

func _process(delta: float) -> void:
	if specimen_status == null:
		return
	_status_elapsed += delta
	if _status_elapsed < 0.2:
		return
	_status_elapsed = 0.0
	specimen_status.text = "활성 %d · 카모/강화는 독립 속성\nPops = 제거 외피 · 피해 = 실제 HP" % game.balloons.balloons.size()
	if not game.balloons.balloons.is_empty():
		var first: BalloonState = game.balloons.balloons[0]
		specimen_status.text += "\n예시 %s HP %d/%d · RBE %d/%d" % [first.definition.id, first.shell_hp, first.shell_max_hp, first.remaining_rbe(), first.total_rbe()]

func charge() -> void:
	for state: AbilityState in game.abilities.states.values():
		state.cooldown_remaining = 0.0
	game.abilities.changed.emit()

func spawn_group(type: String, count: int) -> void:
	if game.result != &"":
		return
	var definition: BalloonDefinition = load("res://data/balloons/%s.tres" % type)
	for index in range(count):
		game.balloons.spawn(definition, 500.0 + index * (1.5 if type == "green" else 4.0), false, false, scenario_index == 5)

func spawn_default() -> void:
	if scenario_index == 5:
		spawn_selected()
	else:
		spawn_group("green", 150)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		spawn_default()
		game.get_viewport().set_input_as_handled()

func _choose(index: int) -> void:
	scenario_index = index
	game.get_tree().reload_current_scene.call_deferred()

func _button(text: String, at: Vector2, bounds: Vector2 = Vector2(112, 28)) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = at
	button.size = bounds
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	game.hud._root.add_child(button)
	return button
