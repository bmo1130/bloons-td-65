extends SceneTree

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _lab(game: MainGame) -> Node:
	for child in game.get_children():
		if child.has_method("spawn_selected"):
			return child
	return null

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(896, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check(lab != null and lab.get("type_picker") != null and game.waves.waves.is_empty(), "native specimen laboratory opens separately from campaign")
	_click(Vector2(566, 199))
	_check(game.balloons.balloons.size() == 10 and game.balloons.balloons.all(func(balloon: BalloonState) -> bool: return balloon.camo), "native default spawn creates ten camo instances")
	for step in range(60):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.projectiles._next_id == 1 and game.economy.total_earned == 0, "basic dart cannot target laboratory camo")
	# Native popup keyboard navigation chooses the second combat preset.
	await _pick(lab.get("preset_picker") as OptionButton, 1)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_check(game.towers.towers[0].upgrade_text() == "0-0-2", "native preset builds002 via real purchases")
	_click(Vector2(566, 199))
	for step in range(180):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.battle_stats.total_pops > 0 and game.towers.towers[0].stats.detects_camo, "002 actually hits camo in the rendered game")
	# Choose the fortified-lead/bomb preset by its popup keyboard index.
	await _pick(lab.get("preset_picker") as OptionButton, 4)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	var quantity: SpinBox = lab.get("quantity") as SpinBox
	var armor: CheckButton = lab.get("fortified_toggle") as CheckButton
	_check(game.towers.towers[0].definition == MainGame.BOMB and armor.button_pressed and not armor.disabled, "bomb and legal fortified lead preset")
	_click(Vector2(264, 190))
	_check(quantity.value == 11, "native quantity spinner changes spawn count")
	_click(Vector2(566, 199))
	_check(game.balloons.balloons.size() == 11 and game.balloons.balloons[0].shell_hp == 4, "native spawn count and fortified lead HP")
	for step in range(240):
		game.simulation_step(MainGame.FIXED_STEP)
		if game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.id == &"lead" and balloon.shell_hp < 4):
			break
	_check(game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.id == &"lead" and balloon.shell_hp < 4), "real bomb damage chips armored lead without premature split")
	await _capture("fortified-lead-v09")
	# Preset7: 502 versus fortified ceramic; enable camo as an independent toggle.
	await _pick(lab.get("preset_picker") as OptionButton, 7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(326, 199))
	_click(Vector2(566, 199))
	_check(game.towers.towers[0].upgrade_text() == "5-0-2" and game.balloons.balloons.all(func(balloon: BalloonState) -> bool: return balloon.camo and balloon.fortified and balloon.shell_hp == 20), "native independent camo and armor produce HP20 ceramics")
	for step in range(240):
		game.simulation_step(MainGame.FIXED_STEP)
		if game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.ceramic and balloon.shell_hp < balloon.shell_max_hp):
			break
	_check(game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.ceramic and balloon.shell_hp < balloon.shell_max_hp), "real Ultra attack produces visible ceramic damage state")
	await _capture("camo-fortified-ceramic-v09")
	# Pause retains damaged shells while showcasing the new colors/patterns.
	_click(Vector2(664, 654))
	var picker: OptionButton = lab.get("type_picker") as OptionButton
	for index in [6, 7, 8]:
		await _pick(picker, index)
		await process_frame # Window events are queued by Input.parse_input_event.
		_check(picker.selected == index and (lab.get("fortified_toggle") as CheckButton).disabled and not (lab.get("fortified_toggle") as CheckButton).button_pressed, "native type picker restricts fortification to eligible types")
		_click(Vector2(566, 199))
	_check(game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.id == &"white") and game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.id == &"zebra") and game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.definition.id == &"rainbow"), "all intermediate types playable from same laboratory")
	await _capture("bloon-properties-v09")
	_click(Vector2(780, 654))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.balloons.balloons.is_empty() and not game.experiment_paused and game.battle_stats.total_pops == 0, "native reset clears HP/attributes/children/pause/statistics")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and _lab(game) == null, "specimen controls and attributes never leak into normal mode")
	print("V0.9 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _pick(control: OptionButton, index: int) -> void:
	_click(control.global_position + control.size * 0.5)
	await process_frame
	var popup: PopupMenu = control.get_popup()
	popup.grab_focus()
	popup.set_focused_item(index)
	_key(KEY_ENTER, popup)

func _key(code: Key, viewport: Viewport = root) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.window_id = (viewport as Window).get_window_id()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	if viewport == root:
		viewport.push_input(event, true)
	else:
		Input.parse_input_event(event)
	event = InputEventKey.new()
	event.window_id = (viewport as Window).get_window_id()
	event.keycode = code
	if viewport == root:
		viewport.push_input(event, true)
	else:
		Input.parse_input_event(event)
	Input.flush_buffered_events()

func _click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	root.push_input(event, true)

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.9 VISUAL FAIL: " + label)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://test-results/%s.png" % label) == OK, "capture " + label)
