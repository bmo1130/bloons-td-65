extends SceneTree

# Render a reproducible combat frame with a real display driver. This is an
# optional visual check, separate from the headless logic tests.
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: MainGame = load("res://tests/fixtures/v05_main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	preload("res://tests/fixtures/v02_config.gd").apply(game)
	await process_frame
	_click(Vector2(1120, 254))
	_check(game.building, "build button enables placement")
	_click(Vector2(156, 350))
	_check(game.economy.gold == 200, "mouse click on road spends nothing")
	for at in [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232)]:
		_click(at)
	_check(game.towers.towers.size() == 3 and game.economy.gold == 5, "mouse input places three towers")
	_key(KEY_ESCAPE)
	_check(not game.building, "escape cancels placement")
	_click(Vector2(1060, 587))
	_check(game.simulation_speed == 2, "speed button updates simulation speed")
	# Jump to the four-color wave and capture its actual dense combat.
	game.waves.current_wave = 2
	_key(KEY_SPACE)
	_check(game.waves.active, "space starts the wave")
	_check(game.simulation_speed == 2, "space does not activate the previously clicked button")
	var seen_colors: Dictionary = {}
	var pierced: bool = false
	var captured_four_colors: bool = false
	for tick in range(20 * 60):
		var previous_shots: Array[ProjectileState] = game.projectiles.projectiles.duplicate()
		game.simulation_step(1.0 / 60.0)
		for shot in previous_shots:
			pierced = pierced or shot.hit_ids.size() >= 2
		var colors: Dictionary = {}
		for balloon in game.balloons.balloons:
			colors[balloon.definition.id] = true
			seen_colors[balloon.definition.id] = true
		if colors.size() == 4 and not game.projectiles.projectiles.is_empty() and pierced:
			captured_four_colors = true
			break
	_check(not game.projectiles.projectiles.is_empty(), "combat frame contains a flying dart")
	_check(seen_colors.size() == 4, "all four balloon colors appear during combat")
	_check(pierced, "a real tower dart hits two distinct balloons in the dense wave")
	_check(captured_four_colors, "rendered combat frame contains all four colors")
	_check(game.hud._tower_attack.text.contains("공격력 1") and game.hud._tower_attack.text.contains("관통력 2"), "HUD exposes data-driven damage and pierce")
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(directory.path_join("combat.png"))
	print("VISUAL SMOKE: screenshot error=%d, balloons=%d, darts=%d" % [error, game.balloons.balloons.size(), game.projectiles.projectiles.size()])
	var previous_id: int = game.get_instance_id()
	_click(Vector2(1175, 587))
	await scene_changed
	var restarted: MainGame = current_scene as MainGame
	if restarted != null:
		preload("res://tests/fixtures/v02_config.gd").apply(restarted)
	_check(restarted != null and restarted.get_instance_id() != previous_id, "restart button reloads main scene")
	if restarted != null:
		_check(restarted.economy.gold == 200 and restarted.towers.towers.is_empty(), "restart restores initial state")
		_check(restarted.balloons.balloons.is_empty() and restarted.projectiles.projectiles.is_empty(), "restart clears balloons and piercing darts")
		_check(restarted.waves.current_wave == 0 and not restarted.waves.active and restarted.result == &"", "restart clears wave and result state")
		_check(restarted.balloons.candidates_in_rect(GameRoute.BUILD_BOUNDS).is_empty(), "restart clears spatial index")
		var balloon: BalloonState = restarted.balloons.spawn(preload("res://data/balloons/red.tres"))
		var shot: ProjectileState = restarted.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, MainGame.DART)
		_check(balloon.id == 1 and shot.id == 1 and shot.hit_ids.is_empty() and shot.remaining_pierce == 2, "restart resets IDs, hit history and pierce")
	print("VISUAL INPUT RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if error == OK and _failures == 0 else 1)

func _click(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
