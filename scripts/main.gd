class_name MainGame
extends Node2D

const DART: TowerDefinition = preload("res://data/towers/dart.tres")
const FIXED_STEP: float = 1.0 / 60.0

@onready var route: GameRoute = $Route
@onready var balloons: BalloonSystem = $Balloons
@onready var projectiles: ProjectileSystem = $Projectiles
@onready var towers: TowerSystem = $Towers
@onready var economy: GameEconomy = $Economy
@onready var waves: WaveSystem = $Waves
@onready var hud: GameHUD = $HUD

var building: bool = false
var result: StringName = &""
var simulation_speed: int = 1
var _accumulator: float = 0.0

func _ready() -> void:
	balloons.route = route
	projectiles.balloon_system = balloons
	towers.balloon_system = balloons
	towers.projectile_system = projectiles
	towers.preview_definition = DART
	waves.balloon_system = balloons
	balloons.layer_popped.connect(economy.earn)
	balloons.leaked.connect(economy.lose_lives)
	economy.changed.connect(hud.set_stats)
	economy.defeated.connect(func() -> void: _finish(false))
	waves.started.connect(_on_wave_started)
	waves.cleared.connect(_on_wave_cleared)
	waves.completed.connect(func() -> void: _finish(true))
	hud.build_requested.connect(_toggle_building)
	hud.wave_requested.connect(start_next_wave)
	hud.speed_requested.connect(_cycle_speed)
	hud.restart_requested.connect(_restart)
	hud.configure_tower(DART)
	economy.reset()
	hud.set_wave(0, waves.waves.size(), false)
	queue_redraw()

func _process(delta: float) -> void:
	_update_preview()
	if result != &"":
		return
	# Bounded catch-up avoids a large movement jump after dragging the window.
	_accumulator += minf(delta, 0.25) * simulation_speed
	while _accumulator >= FIXED_STEP:
		simulation_step(FIXED_STEP)
		_accumulator -= FIXED_STEP

func simulation_step(delta: float) -> void:
	if result != &"":
		return
	waves.update(delta)
	balloons.update(delta)
	if result != &"":
		return
	towers.update(delta)
	projectiles.update(delta)
	waves.check_cleared()

func start_next_wave() -> bool:
	if result != &"":
		return false
	return waves.start_next()

func placement_error(at: Vector2) -> String:
	if result != &"":
		return "게임이 종료되었습니다"
	if not route.can_build(at, DART.radius):
		return "길에서 떨어진 맵 안쪽에 설치하세요"
	if not towers.has_space(at, DART.radius):
		return "다른 타워와 너무 가깝습니다"
	if economy.gold < DART.cost:
		return "골드가 부족합니다 (%d G 필요)" % DART.cost
	return ""

func try_place_tower(at: Vector2) -> bool:
	if not placement_error(at).is_empty():
		return false
	if not economy.try_spend(DART.cost):
		return false
	towers.add_tower(at, DART)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_D:
				_toggle_building()
			KEY_SPACE:
				start_next_wave()
			KEY_ESCAPE:
				building = false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			building = false
		elif event.button_index == MOUSE_BUTTON_LEFT and building:
			var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			try_place_tower(at)

func _toggle_building() -> void:
	if result == &"":
		building = not building

func _update_preview() -> void:
	var at: Vector2 = get_global_mouse_position()
	towers.preview_visible = building and result == &"" and GameRoute.BUILD_BOUNDS.has_point(at)
	towers.preview_position = at
	var error: String = placement_error(at)
	towers.preview_valid = error.is_empty()
	towers.queue_redraw()
	var hint: String = "D 또는 타워 버튼으로 배치 시작\n초록 원: 설치 가능 / 빨강 원: 불가\n우클릭 또는 Esc: 배치 취소"
	if building:
		hint = "클릭하여 설치 · 연속 배치 가능\n우클릭 또는 Esc: 배치 취소\n" + ("설치 가능 · %d G" % DART.cost if error.is_empty() else error)
	hud.set_building(building, hint)

func _cycle_speed() -> void:
	if result != &"":
		return
	simulation_speed = simulation_speed % 3 + 1
	hud.set_speed(simulation_speed)

func _on_wave_started(number: int) -> void:
	hud.set_wave(number, waves.waves.size(), true)

func _on_wave_cleared(number: int, reward: int) -> void:
	economy.earn(reward)
	hud.set_wave(number, waves.waves.size(), false, reward)

func _finish(won: bool) -> void:
	if result != &"":
		return
	result = &"victory" if won else &"defeat"
	building = false
	towers.preview_visible = false
	towers.queue_redraw()
	hud.show_result(won, economy.gold)

func _restart() -> void:
	get_tree().reload_current_scene()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("101e25"))
	draw_style_box(_board_style(), GameRoute.BUILD_BOUNDS)
	for x in range(48, 952, 32):
		for y in range(152, 664, 32):
			draw_circle(Vector2(x, y), 1.0, Color("2d4847"))

func _board_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("203b39")
	style.border_color = Color("36534e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style
