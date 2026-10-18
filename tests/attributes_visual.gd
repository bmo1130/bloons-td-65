extends SceneTree

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: MainGame = load("res://tests/fixtures/v05_main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	_check(game.economy.gold == 400 and game.economy.lives == 50, "v0.3 play defaults")
	_click(Vector2(1120, 294))
	_check(game.building and game.selected_tower == MainGame.BOMB, "catalog button selects bomb")
	_check(game.hud._tower_attribute.text.contains("EXPLOSIVE") and game.hud._tower_attribute.text.contains("68"), "bomb info shows attribute and radius")
	_key(KEY_D)
	_check(game.selected_tower == MainGame.DART and game.hud._tower_attribute.text.contains("SHARP"), "D selects sharp dart")
	_key(KEY_B)
	_check(game.selected_tower == MainGame.BOMB and game.building, "B selects bomb placement")
	_click(Vector2(250, 410))
	_check(game.towers.towers.size() == 1 and game.economy.gold == 250, "bomb placement spends data cost")
	_key(KEY_D)
	for at in [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232)]:
		_click(at)
	_check(game.towers.towers.size() == 4 and game.economy.gold == 55, "mixed placement succeeds without overlaps")
	_click(Vector2(156, 350))
	_check(game.economy.gold == 55, "invalid placement remains free")
	_key(KEY_B)
	_key(KEY_ESCAPE)
	_check(not game.building, "escape cancels bomb placement")
	game.waves.current_wave = 5
	_key(KEY_SPACE)
	_check(game.waves.active and game.waves.current_wave == 6, "sixth mixed wave starts from keyboard")
	var seen: Dictionary = {}
	var capture: bool = false
	for tick in range(20 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
		for balloon in game.balloons.balloons:
			seen[balloon.definition.id] = true
		if seen.has(&"lead") and seen.has(&"black") and seen.has(&"pink") and not game.combat.effects.is_empty():
			capture = true
			break
	_check(capture, "mixed wave produces lead, black, pink and visible blast")
	_check(game.towers.towers[0].definition == MainGame.BOMB, "bomb tower remains distinct from dart towers")
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(directory)
	var error: Error = root.get_texture().get_image().save_png(directory.path_join("combat-v03.png"))
	_check(error == OK, "v0.3 combat screenshot saved")
	_click(Vector2(1175, 587))
	await scene_changed
	var restarted: MainGame = current_scene as MainGame
	_check(restarted.economy.gold == 400 and restarted.economy.lives == 50 and restarted.waves.waves.size() == 6, "restart restores full v0.3 campaign defaults")
	_check(restarted.combat.effects.is_empty() and restarted.balloons.balloons.is_empty() and restarted.projectiles.projectiles.is_empty(), "restart clears blasts, descendants and projectiles")
	_check(restarted.selected_tower == MainGame.DART and not restarted.building, "restart resets catalog selection")
	print("V0.3 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)

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

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event, true)
