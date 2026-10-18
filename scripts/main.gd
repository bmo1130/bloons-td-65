class_name MainGame
extends Node2D

const DART: TowerDefinition = preload("res://data/towers/dart.tres")
const BOMB: TowerDefinition = preload("res://data/towers/bomb.tres")
const TOWER_CATALOG: Array[TowerDefinition] = [DART, BOMB]
const FIXED_STEP: float = 1.0 / 60.0
const LEGACY_WAVES: Array[WaveDefinition] = [preload("res://data/waves/wave_01.tres"), preload("res://data/waves/wave_02.tres"),
	preload("res://data/waves/wave_03.tres"), preload("res://data/waves/wave_04.tres"), preload("res://data/waves/wave_05.tres"), preload("res://data/waves/wave_06.tres")]
@export var regression_six_waves: bool = false
@export var developer_mode: bool = false
@export var tier5_developer: bool = false
var experiment_paused: bool = false
var battle_stats: BattleStatistics = BattleStatistics.new()
var abilities: AbilitySystem

@onready var route: GameRoute = $Route
@onready var balloons: BalloonSystem = $Balloons
@onready var projectiles: ProjectileSystem = $Projectiles
@onready var towers: TowerSystem = $Towers
@onready var economy: GameEconomy = $Economy
@onready var waves: WaveSystem = $Waves
@onready var hud: GameHUD = $HUD
@onready var combat: CombatSystem = $Combat
@onready var upgrades: UpgradeSystem = $Upgrades

var building: bool = false
var selected_tower: TowerDefinition = DART
var selected_instance: TowerState
var result: StringName = &""
var simulation_speed: int = 1
var _accumulator: float = 0.0
var profile_simulation: bool = false
var step_metrics: Dictionary = {}

func _ready() -> void:
	abilities = AbilitySystem.new()
	abilities.tower_system = towers
	add_child(abilities)
	towers.abilities = abilities
	if regression_six_waves:
		waves.waves.assign(LEGACY_WAVES)
	balloons.route = route
	balloons.combat = combat
	combat.balloon_system = balloons
	combat.battle_stats = battle_stats
	projectiles.balloon_system = balloons
	projectiles.combat = combat
	projectiles.battle_stats = battle_stats
	towers.balloon_system = balloons
	towers.projectile_system = projectiles
	towers.combat = combat
	towers.battle_stats = battle_stats
	towers.preview_definition = DART
	upgrades.economy = economy
	upgrades.tower_system = towers
	upgrades.upgraded.connect(func(_tower: TowerState) -> void:
		hud.upgrade_panel.refresh()
		hud.stats_panel.refresh())
	abilities.changed.connect(func() -> void: hud.upgrade_panel.refresh())
	hud.upgrade_panel.abilities = abilities
	waves.balloon_system = balloons
	balloons.layer_popped.connect(economy.earn)
	balloons.leaked.connect(economy.lose_lives)
	economy.changed.connect(hud.set_stats)
	economy.defeated.connect(func() -> void: _finish(false))
	waves.started.connect(_on_wave_started)
	waves.cleared.connect(_on_wave_cleared)
	waves.completed.connect(func() -> void: _finish(true))
	hud.tower_requested.connect(select_tower)
	hud.wave_requested.connect(start_next_wave)
	hud.speed_requested.connect(_cycle_speed)
	hud.restart_requested.connect(_restart)
	hud.upgrade_requested.connect(func(item: UpgradeDefinition) -> void: try_upgrade(selected_instance, item))
	hud.selection_closed.connect(func() -> void: select_instance(null))
	hud.developer_requested.connect(_toggle_developer)
	hud.tier5_requested.connect(_toggle_tier5)
	hud.configure_catalog(TOWER_CATALOG)
	hud.configure_tower(selected_tower)
	economy.reset()
	hud.set_wave(0, waves.waves.size(), false)
	if developer_mode:
		var scenario: Node = load("res://scripts/developer/tier5_sandbox.gd" if tier5_developer else "res://scripts/developer/tier4_sandbox.gd").new()
		add_child(scenario)
	queue_redraw()

func _process(delta: float) -> void:
	_update_preview()
	if result != &"" or (developer_mode and experiment_paused):
		return
	# Bounded catch-up avoids a large movement jump after dragging the window.
	_accumulator += minf(delta, 0.25) * simulation_speed
	while _accumulator >= FIXED_STEP:
		simulation_step(FIXED_STEP)
		_accumulator -= FIXED_STEP

func simulation_step(delta: float) -> void:
	if result != &"" or (developer_mode and experiment_paused):
		return
	var started: int = Time.get_ticks_usec() if profile_simulation else 0
	if projectiles.profile_updates:
		projectiles.reset_profile()
	hud.begin_combat_update()
	combat.update(delta)
	abilities.update(delta)
	waves.update(delta)
	# Fire at the beginning of the step, then move both balloons and darts over
	# the same interval. A newly fired dart never replays earlier balloon motion.
	var towers_at: int = Time.get_ticks_usec() if profile_simulation else 0
	towers.update(delta)
	if profile_simulation:
		var now: int = Time.get_ticks_usec()
		step_metrics["tower_usec"] = now - towers_at
		step_metrics["spawn_towers_usec"] = now - started
		started = now
	balloons.update(delta, true)
	if profile_simulation:
		var now: int = Time.get_ticks_usec()
		step_metrics["movement_usec"] = now - started
		started = now
	if result != &"":
		hud.end_combat_update()
		return
	projectiles.update(delta)
	if profile_simulation:
		var now: int = Time.get_ticks_usec()
		step_metrics["projectile_combat_usec"] = now - started
		started = now
	balloons.resolve_leaks()
	if result == &"":
		waves.check_cleared()
	hud.end_combat_update()
	if profile_simulation:
		step_metrics["finalize_usec"] = Time.get_ticks_usec() - started

func start_next_wave() -> bool:
	if result != &"":
		return false
	return waves.start_next()

func placement_error(at: Vector2, definition: TowerDefinition = null) -> String:
	if definition == null:
		definition = selected_tower
	if result != &"":
		return "게임이 종료되었습니다"
	if not route.can_build(at, definition.radius):
		return "길에서 떨어진 맵 안쪽에 설치하세요"
	if not towers.has_space(at, definition.radius):
		return "다른 타워와 너무 가깝습니다"
	if economy.gold < definition.cost:
		return "골드가 부족합니다 (%d G 필요)" % definition.cost
	return ""

func try_place_tower(at: Vector2, definition: TowerDefinition = null) -> bool:
	if definition == null:
		definition = selected_tower
	if not placement_error(at, definition).is_empty():
		return false
	if not economy.try_spend(definition.cost):
		return false
	towers.add_tower(at, definition)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F6:
				_toggle_developer()
			KEY_F7:
				_toggle_tier5()
			KEY_SPACE:
				start_next_wave()
			KEY_ESCAPE:
				building = false
				select_instance(null)
		for definition in TOWER_CATALOG:
			if event.keycode == definition.shortcut.unicode_at(0):
				select_tower(definition)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			building = false
			select_instance(null)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if building:
				try_place_tower(at)
			else:
				select_instance(towers.tower_at(at))

func select_instance(tower: TowerState) -> void:
	selected_instance = tower if towers.towers.has(tower) else null
	towers.selected = selected_instance
	if selected_instance != null:
		building = false
		towers.preview_visible = false
	hud.show_selection(selected_instance, upgrades)
	towers.queue_redraw()

func try_upgrade(tower: TowerState, item: UpgradeDefinition) -> bool:
	return upgrades.purchase(tower, item)

func _toggle_building() -> void:
	select_tower(DART)

func select_tower(definition: TowerDefinition) -> void:
	if result != &"":
		return
	select_instance(null)
	building = not building if selected_tower == definition else true
	selected_tower = definition
	towers.preview_definition = definition
	hud.configure_tower(definition)

func _update_preview() -> void:
	var at: Vector2 = get_global_mouse_position()
	towers.preview_visible = building and result == &"" and GameRoute.BUILD_BOUNDS.has_point(at)
	towers.preview_position = at
	var error: String = placement_error(at)
	towers.preview_valid = error.is_empty()
	towers.queue_redraw()
	var hint: String = "타워 클릭: 강화 · D/B: 설치\n우클릭 또는 Esc: 취소"
	if building:
		hint = ("설치 가능 · %d G" % selected_tower.cost if error.is_empty() else error) + "\n우클릭 또는 Esc: 배치 취소"
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
	upgrades.enabled = false
	abilities.enabled = false
	hud.upgrade_panel.refresh()
	towers.preview_visible = false
	towers.queue_redraw()
	hud.show_result(won, economy.gold)
	hud.show_combat_result(waves.current_wave, waves.waves.size(), economy.lives, economy.total_earned, battle_stats)

func _restart() -> void:
	get_tree().reload_current_scene()

func _toggle_developer() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn" if developer_mode else "res://scenes/tier4_sandbox.tscn")

func _toggle_tier5() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn" if tier5_developer else "res://scenes/tier5_sandbox.tscn")

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
