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
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.developer_mode and game.economy.gold > 90000 and game.towers.towers.size() == 6, "F6 opens isolated funded tier4 purchase scenario")
	for tower in game.towers.towers:
		_click(tower.position)
		var main: int = tower.tiers.find(3)
		var panel: TowerUpgradePanel = game.hud.upgrade_panel
		var item: UpgradeDefinition = panel._next[main]
		_check(game.selected_instance == tower and not panel._buttons[main].disabled and item.tier == 4 and panel._buttons[main].tooltip_text.contains(item.description), "native selection offers tier4 name description price")
		var before: int = game.economy.gold
		_click(Vector2(1116, 260 + main * 61))
		_check(tower.tiers[main] == 4 and game.economy.gold == before - item.cost and not game.building, "native tier4 button spends exact cost without placement")
		_check(panel._next[main].tier == 5 and not panel._buttons[main].disabled and panel._stats.text.contains("공격 %d" % tower.stats.damage), "tier4 now offers tier5 with actual combat stats displayed")
		await _capture("tier4-" + tower.upgrade_text())
	_key(KEY_SPACE)
	for tick in range(240):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.battle_stats.total_pops > 0, "purchased tier4 towers deal real damage")
	_click(Vector2(306, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(100, 653))
	for tick in range(20):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.any(func(shot: ProjectileState) -> bool: return shot.max_bounces > 0 and shot.bounces > 0), "native developer demo displays real map-edge ricochet")
	await _capture("juggernaut-v07")
	# Choose fanclub scenario with native controls.
	_click(Vector2(492, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var caster: TowerState = game.towers.towers[0]
	var second: TowerState = game.towers.towers[1]
	var panel: TowerUpgradePanel = game.hud.upgrade_panel
	_check(panel.ability_button.visible and panel.ability_button.disabled and panel.ability_button.text.contains("대기"), "ability UI displays initial charge")
	_click(Vector2(260, 653))
	_check(not panel.ability_button.disabled, "developer preparation advances real simulation cooldown")
	var count: int = game.towers.towers.size()
	_click(Vector2(1116, 481))
	_check(game.abilities.state_for(caster).last_targets.size() == 10 and game.towers.towers.size() == count and game.selected_instance == caster, "native ability click transforms ten without buying or deselecting")
	_check(panel._title.text.contains("변신") and panel._stats.text.contains("1발") and panel._stats.text.contains("관통 5") and panel._stats.text.contains("0.015초"), "selected panel shows exact temporary attack instead of permanent triple")
	_click(second.position)
	_click(Vector2(1116, 481))
	_check(game.abilities.transformations.size() == 12 and second.transformed_stats != null, "second native activation prefers still-untransformed targets and refreshes overlaps")
	_key(KEY_SPACE)
	for tick in range(240):
		game.simulation_step(MainGame.FIXED_STEP)
	game.hud.upgrade_panel.refresh()
	var firing_fans: int = 0
	for tower in game.towers.towers:
		if tower.transformed_stats != null and tower.combat_stats.projectiles > 0 and tower.combat_stats.projectiles == tower.combat_stats.volleys:
			firing_fans += 1
	_check(firing_fans > 0 and is_equal_approx(caster.combat_definition().fire_interval, 0.015), "transformed group emits rapid single darts, not rapid triple volleys")
	await _capture("fanclub-v07")
	_click(Vector2(1060, 587))
	_check(game.simulation_speed == 2, "speed input remains available with ability UI")
	for frame in range(12 * 30):
		game._process(MainGame.FIXED_STEP)
	_check(game.abilities.transformations.is_empty() and caster.transformed_stats == null and caster.stats.projectile_count == 3, "2x expiry restores original attacks")
	game.hud.upgrade_panel.refresh()
	_check(panel._stats.text.contains("3발") and panel.ability_button.text.contains("대기"), "UI recovers triple attack and remaining cooldown")
	_click(Vector2(682, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	caster = game.towers.towers[0]
	_key(KEY_SPACE)
	for tick in range(20 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
		if caster.crit_flash > 0.0:
			break
	_check(caster.combat_stats.critical_volleys == 1 and caster.crit_flash > 0.0, "real attacking sharpshooter produces first CRIT volley and effect")
	_click(Vector2(1225, 632))
	_check(game.hud.stats_panel.detail.visible and game.hud.stats_panel.detail_text.text.contains("CRIT 발사 1"), "expanded statistics displays critical volleys")
	await _capture("sharpshooter-v07")
	_click(Vector2(1175, 587))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.abilities.transformations.is_empty() and game.towers.towers[0].critical_counter == 0, "native restart clears timed effects and critical counters")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and game.towers.towers.is_empty(), "F6 returns to untouched normal economy and twenty waves")
	print("V0.7 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/%s.png" % name)) == OK, "native tier4 screenshot " + name)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.7 VISUAL FAIL: " + message)

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
