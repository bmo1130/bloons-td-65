extends SceneTree

const BUILDS: Array = [[3, 2, 0], [2, 3, 0], [0, 3, 2], [2, 0, 3], [0, 2, 3], [3, 0, 2]]
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
	for build: Array in BUILDS:
		# Separate UI fixture credit; real-income campaigns are in crosspath_tests.
		game.economy.earn(1000)
		_key(KEY_D)
		_click(Vector2(250, 350))
		_key(KEY_ESCAPE)
		_click(Vector2(250, 350))
		var tower: TowerState = game.selected_instance
		_check(tower != null and not game.building, "crosspath panel selected through actual map input")
		if build[2] == 0:
			for path in [0, 1]:
				_buy_ui(game, path)
				_buy_ui(game, path)
			_check(tower.upgrade_text() == "2-2-0" and game.hud.upgrade_panel._policy.text.contains("미확정"), "UI leaves main undecided at 2-2-0")
			_check(not game.hud.upgrade_panel._buttons[0].disabled and not game.hud.upgrade_panel._buttons[1].disabled, "both tier-3 choices are offered at 2-2-0")
			_buy_ui(game, build.find(3))
		else:
			for path in range(3):
				for tier in range(build[path]):
					_buy_ui(game, path)
		var main: int = build.find(3)
		var secondary: int = build.find(2)
		var locked: int = build.find(0)
		_check(tower.tiers == PackedInt32Array(build) and game.hud.upgrade_panel._title.text.contains(tower.upgrade_text()), "crosspath tier state/title match actual purchases")
		_check(game.hud.upgrade_panel._details[secondary].text.contains("주력"), "UI explains other-main secondary limit")
		_check(game.hud.upgrade_panel._details[locked].text.contains("세 번째") and game.hud.upgrade_panel._buttons[locked].disabled, "UI explains third-path lock")
		_check(game.hud.upgrade_panel._next[main].tier == 4 and game.hud.upgrade_panel._details[main].text.contains("자금 부족"), "UI offers tier 4 with explicit cost reason")
		var before: int = game.economy.gold
		_click(Vector2(1116, 260 + locked * 61))
		_click(Vector2(1116, 260 + secondary * 61))
		_check(game.economy.gold == before and tower.tiers == PackedInt32Array(build), "clicking locked paths never spends gold")
		_check(game.hud.upgrade_panel._stats.text.contains("관통 %d" % tower.stats.pierce) and game.hud.upgrade_panel._stats.text.contains("간격 %.2f" % tower.stats.fire_interval) and game.hud.upgrade_panel._stats.text.contains("사거리 %d" % tower.stats.attack_range), "displayed final stats match combat data")
		game.waves.current_wave = 3
		_key(KEY_SPACE)
		for tick in range(10 * 60):
			game.simulation_step(MainGame.FIXED_STEP)
			if not game.projectiles.projectiles.is_empty():
				break
		_check(not game.projectiles.projectiles.is_empty(), "crosspath tower fires against real fast pink wave")
		for shot in game.projectiles.projectiles:
			_check(shot.damage == tower.stats.damage and shot.remaining_pierce == tower.stats.pierce and shot.speed == tower.stats.projectile_speed, "visible crosspath shots use selected final stats")
		for tick in range(6):
			game.simulation_step(MainGame.FIXED_STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/crosspath-%s.png" % tower.upgrade_text())) == OK, "crosspath combat screenshot saved")
		_click(Vector2(1175, 587))
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		await process_frame
		_check(game.economy.gold == 400 and game.selected_instance == null and game.towers.towers.is_empty() and game.projectiles._next_id == 1 and not game.hud.upgrade_panel.visible, "actual restart clears crosspaths, panel, projectiles and gold")
	# Multiple crosspath towers in one real render/input session.
	game.economy.earn(2000)
	var positions: Array[Vector2] = [Vector2(250, 350), Vector2(460, 450), Vector2(672, 232), Vector2(704, 440)]
	for index in range(4):
		_key(KEY_D)
		_click(positions[index])
		_key(KEY_ESCAPE)
		_click(positions[index])
		for path in range(3):
			for tier in range(BUILDS[index][path]):
				_buy_ui(game, path)
	_key(KEY_B)
	_click(Vector2(250, 410))
	_key(KEY_ESCAPE)
	_click(positions[1])
	game.waves.current_wave = 5
	_key(KEY_SPACE)
	var peak: int = 0
	for tick in range(12 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
		peak = maxi(peak, game.projectiles.projectiles.size())
	_check(game.towers.towers.size() == 5 and peak >= 3 and game.economy.lives > 0, "multiple crosspath towers and bomb survive mixed immunity/split combat")
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/crosspaths-mixed.png")) == OK, "multiple crosspath towers rendered without errors")
	print("V0.5 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _buy_ui(game: MainGame, path: int) -> void:
	var tower: TowerState = game.selected_instance
	var item: UpgradeDefinition = tower.definition.upgrade_at(path, tower.tiers[path] + 1)
	var before: int = game.economy.gold
	var old_stats: TowerDefinition = tower.stats
	var expected: TowerDefinition = TowerStatResolver.preview(tower.definition, tower.tiers, item)
	_check(not game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._buttons[path].text.contains("%d→%d" % [tower.tiers[path], item.tier]), "next-tier offer shows current and next tiers")
	_check(game.hud.upgrade_panel._details[path].text.contains(TowerUpgradePanel.stat_changes(old_stats, expected)), "visible pre/post delta uses final crosspath preview")
	_click(Vector2(1116, 260 + path * 61))
	_check(tower.tiers[path] == item.tier and game.economy.gold == before - item.cost, "actual button crosspath purchase spends exact price")
	_check(tower.stats.damage == expected.damage and tower.stats.pierce == expected.pierce and tower.stats.projectile_count == expected.projectile_count and tower.stats.fire_interval == expected.fire_interval, "UI preview equals resulting attack behavior")

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
