extends SceneTree

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	_check(game.waves.waves.size() == 20 and game.hud._wave.text == "0 / 20", "real main scene exposes 20-wave campaign")
	_key(KEY_D)
	_click(Vector2(250, 350))
	_key(KEY_ESCAPE)
	_click(Vector2(250, 350))
	var tower: TowerState = game.selected_instance
	var record: TowerCombatStats = tower.combat_stats
	_check(game.hud.stats_panel.visible and game.hud.stats_panel.summary.text.contains("투자 65"), "tower selection shows statistics alongside upgrades")
	_click(Vector2(1116, 321))
	_check(record.invested_gold == 115 and game.hud.stats_panel.summary.text.contains("투자 115"), "native upgrade updates investment immediately")
	_key(KEY_SPACE)
	for tick in range(20 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
	game.hud.stats_panel._process(0.2)
	_check(record.pops() > 0 and record.volleys > 0 and game.hud.stats_panel.summary.text.contains("Pops %d" % record.pops()), "live shot/pop counters appear after real combat")
	_click(Vector2(1225, 632))
	_check(game.hud.stats_panel.detail.visible and game.hud.stats_panel.detail_text.text.contains("면역 접촉"), "details toggle exposes full statistics")
	var pops_before: int = record.pops()
	_click(Vector2(1116, 321))
	_check(tower.tiers[1] == 2 and record.pops() == pops_before and game.hud.stats_panel.detail.visible, "expanded statistics do not block upgrades or reset pops")
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/statistics-v06.png")) == OK, "live statistics screenshot saved")
	_click(Vector2(1175, 587))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.battle_stats.records.is_empty() and game.battle_stats.total_pops == 0 and game.towers._next_id == 1 and game.waves.waves.size() == 20, "restart clears statistics/IDs and preserves 20-wave mode")
	var scenarios: RefCounted = preload("res://tests/scenarios/balance_scenarios.gd").new()
	for wave in range(1, 21):
		scenarios.shop(game, "mixed", wave)
		game.start_next_wave()
		for frame in range(90 * 60):
			game._process(MainGame.FIXED_STEP)
			if game.result != &"":
				break
		if game.result != &"":
			break
	_check(game.result == &"victory" and game.waves.current_wave == 20 and game.hud._result.visible, "real renderer campaign reaches wave 20 victory")
	_check(game.hud._result_detail.text.contains("20 / 20") and game.hud._result_detail.text.contains("전체 Pops %d" % game.battle_stats.total_pops) and game.hud._result_detail.text.contains(str(game.economy.total_earned)), "results show actual wave/lives/earned gold/pops")
	_check(game.battle_stats.top_towers().size() == 3 and game.hud._result_ranking.text.count("#") == 3, "results show top three towers")
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/result-v06.png")) == OK, "wave 20 results screenshot saved")
	_click(Vector2(492, 501))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.economy.total_earned == 0 and game.battle_stats.records.is_empty() and not game.hud.stats_panel.visible, "result restart clears all statistics and earnings")
	game.waves.current_wave = 2
	game.economy.lose_lives(50)
	_check(game.result == &"defeat" and game.hud._result_title.text == "방어 실패" and game.hud._result_detail.text.contains("2 / 20"), "defeat result reports actual progress")
	print("V0.6 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
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
