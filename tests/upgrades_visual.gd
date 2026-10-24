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
	for path in range(3):
		_key(KEY_D)
		_click(Vector2(250, 350))
		var tower: TowerState = game.towers.towers[0]
		_check(game.economy.gold == 335 and game.building, "placing dart retains continuous build mode")
		_click(Vector2(250, 350))
		_check(game.selected_instance == null and game.towers.towers.size() == 1 and game.economy.gold == 335, "placement overlap cannot select or buy twice")
		_key(KEY_ESCAPE)
		_click(Vector2(250, 350))
		_check(game.selected_instance == tower and game.hud.upgrade_panel.visible and not game.building, "mouse selects placed tower and opens upgrade UI")
		_check(game.towers.selected == tower and not game.towers.preview_visible, "selected range replaces placement preview")
		if path == 0:
			game.economy.gold = 44
			game.hud.set_stats(44, game.economy.lives)
			_check(game.hud.upgrade_panel._buttons[0].disabled and game.hud.upgrade_panel._details[0].text.contains("자금 부족"), "UI explains insufficient funds")
			_click(Vector2(1116, 260))
			_check(tower.tiers[0] == 0 and game.economy.gold == 44, "disabled purchase does not spend")
			game.economy.earn(291)
			_check(not game.hud.upgrade_panel._buttons[0].disabled, "gold signal immediately re-enables affordable upgrade")
		for tier in range(1, 4):
			var item: UpgradeDefinition = MainGame.DART.upgrade_at(path, tier)
			var before: int = game.economy.gold
			_click(Vector2(1116, 260 + path * 61))
			_check(tower.tiers[path] == tier and game.economy.gold == before - item.cost, "native upgrade button buys exact displayed tier")
			_check(game.selected_instance == tower and not game.building and game.towers.towers.size() == 1, "upgrade UI consumes click without placement or deselection")
			# v0.5 permits a second path; current affordability still controls the UI.
			var other_path: int = (path + 1) % 3
			_check(game.hud.upgrade_panel._buttons[other_path].disabled == (not game.upgrades.error_for_path(tower, other_path).is_empty()) and not game.hud.upgrade_panel._details[other_path].text.contains("잠김"), "second path UI agrees with crosspath policy and funds")
		_check(game.hud.upgrade_panel._title.text.contains(tower.upgrade_text()), "selected title shows exact upgrade state")
		_check(game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._next[path].tier == 4, "tier 3 now offers unaffordable tier 4")
		_check(game.hud.upgrade_panel._stats.text.contains("SHARP"), "upgrade info retains attack attribute")
		game.waves.current_wave = 3
		_key(KEY_SPACE)
		var seen: bool = false
		for tick in range(10 * 60):
			game.simulation_step(MainGame.FIXED_STEP)
			if not game.projectiles.projectiles.is_empty():
				seen = true
				break
		_check(seen, "upgraded tower fires in real pink wave")
		if seen:
			var shot: ProjectileState = game.projectiles.projectiles[0]
			if path == 0:
				_check(shot.radius == 7 and shot.length == 24, "renderer receives large dart geometry")
			elif path == 1:
				_check(game.projectiles.projectiles.size() == 3, "renderer receives three independent fan darts")
			else:
				_check(shot.damage == 2 and shot.speed == 660, "renderer receives enhanced power dart")
		# Let the fan leave the muzzle so the saved frame shows its spread.
		for tick in range(6):
			game.simulation_step(MainGame.FIXED_STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/upgrade-path-%d.png" % path)) == OK, "upgraded combat screenshot saved")
		_key(KEY_B)
		_check(game.selected_instance == null and not game.hud.upgrade_panel.visible and game.building, "B switches selection to bomb placement")
		_key(KEY_ESCAPE)
		_click(Vector2(250, 350))
		_click(Vector2(1218, 154))
		_check(game.selected_instance == null and not game.hud.upgrade_panel.visible, "close button clears placed tower selection")
		_click(Vector2(1175, 587))
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		await process_frame
		_check(game.economy.gold == 400 and game.towers.towers.is_empty() and game.selected_instance == null, "actual restart restores budget and clears upgraded towers/selection")
		_check(game.projectiles.projectiles.is_empty() and game.projectiles._next_id == 1 and not game.hud.upgrade_panel.visible, "actual restart clears volley IDs and upgrade panel")
	# v0.11 adds bomb offers using this same panel and purchase transaction.
	_key(KEY_B)
	_click(Vector2(250, 410))
	_key(KEY_ESCAPE)
	_click(Vector2(250, 410))
	_check(game.hud.upgrade_panel.visible and game.hud.upgrade_panel._stats.text.contains("폭발 68"), "bomb selection shows explosive radius and stats")
	_check(game.hud.upgrade_panel._buttons.all(func(button: Button) -> bool: return not button.disabled), "bomb offers all three affordable tier-one upgrades")
	_click(Vector2(820, 600))
	_check(game.selected_instance == null and not game.hud.upgrade_panel.visible, "empty map click clears selection")
	print("V0.4 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
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
