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
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var initial_investment: int = 0
	for tower: TowerState in game.towers.towers:
		initial_investment += tower.definition.cost + tower.spent_on_upgrades
	_check(game.tier5_developer and game.towers.towers.size() == 6 and game.economy.gold == 200000 - initial_investment, "F7 opens separately funded tier5 experiment with real pre-purchase costs")
	var originals: Array[TowerState] = game.towers.towers.duplicate()
	var a: TowerState = originals[0]
	_click(a.position)
	var panel: TowerUpgradePanel = game.hud.upgrade_panel
	_check(panel._next[0].tier == 5 and panel._buttons[0].tooltip_text.contains("15000"), "tier5 original name description and cost offered")
	var gold: int = game.economy.gold
	_click(Vector2(1116, 260))
	_check(a.tiers[0] == 5 and game.economy.gold == gold - 15000 and panel._buttons[0].text.contains("완료"), "native buy tier5 debits and shows final state")
	_click(originals[1].position)
	gold = game.economy.gold
	_check(panel._buttons[0].disabled and panel._details[0].text.contains("5티어 사용 중"), "other crosspath shows global slot lock")
	_click(Vector2(1116, 260))
	_check(game.economy.gold == gold and originals[1].tiers[0] == 4, "locked native tier5 click never spends")
	_click(a.position)
	_click(Vector2(896, 654))
	_check(game.towers.find(a.id) == null and game.selected_instance == null, "developer removal releases selected tower safely")
	_click(originals[1].position)
	_check(not panel._buttons[0].disabled, "slot returns to other tower immediately")
	_click(Vector2(1116, 260))
	_check(originals[1].tiers[0] == 5, "native repurchase after removal")
	for pair: Array in [[originals[2], 1], [originals[4], 2]]:
		var tower: TowerState = pair[0]
		var path: int = pair[1]
		_click(tower.position)
		gold = game.economy.gold
		var item: UpgradeDefinition = panel._next[path]
		_click(Vector2(1116, 260 + path * 61))
		_check(tower.tiers[path] == 5 and game.economy.gold == gold - item.cost, "different tier5 main paths coexist via native purchases")
	_check(originals[4].stats.pierce == 21 and panel._stats.text.contains("0.2375초") and panel._title.text.contains("석궁의 대가"), "205 actual stats and original upgrade name visible")
	await _capture("tier5-purchase-v08")
	_click(Vector2(306, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(84, 654))
	for tick in range(180):
		game.simulation_step(MainGame.FIXED_STEP)
		if game.towers.towers[0].combat_stats.split_projectiles > 0:
			break
	_check(game.towers.towers[0].combat_stats.split_projectiles >= 6 and not game.projectiles.split_effects.is_empty(), "real Ultra attack produces split effect and child projectiles")
	_check(not game.projectiles.ricochet_obstacles.is_empty(), "experiment has visible projectile-only bumper")
	await _capture("ultra-juggernaut-v08")
	_click(Vector2(492, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var leader: TowerState = game.towers.towers[0]
	var smfc: TowerState = game.towers.towers[1]
	panel = game.hud.upgrade_panel
	_check(panel.ability_button.disabled and panel._title.text.contains("플라즈마"), "Plasma leader shows initial charge and name")
	_click(Vector2(548, 654))
	_check(not panel.ability_button.disabled and panel.ability_button.text.contains("20기"), "lab charge exposes data-driven twenty-target ability button")
	_click(Vector2(1116, 481))
	_check(game.abilities.state_for(leader).last_targets.size() == 20 and panel._stats.text.contains("PLASMA") and panel._stats.text.contains("0.0075초"), "native ability transforms twenty with exact temporary data")
	_click(Vector2(84, 654))
	for tick in range(20):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(leader.combat_stats.projectiles > 0 and game.projectiles.projectiles.any(func(shot: ProjectileState) -> bool: return shot.attack.attribute == AttackSpec.Attribute.PLASMA), "Plasma transformed towers actually fire visible Plasma projectiles")
	await _capture("plasma-fanclub-v08")
	_click(Vector2(664, 654))
	var remaining: float = game.abilities.state_for(leader).cooldown_remaining
	var pops: int = game.battle_stats.total_pops
	game._process(0.25)
	_check(game.experiment_paused and game.abilities.state_for(leader).cooldown_remaining == remaining and game.battle_stats.total_pops == pops, "pause freezes combat and ability simulation timers")
	_click(Vector2(664, 654))
	_click(smfc.position)
	_click(Vector2(1116, 481))
	_check(smfc.transformed_stats.attack_attribute == AttackSpec.Attribute.SHARP and leader.transformed_stats.attack_attribute == AttackSpec.Attribute.PLASMA, "native four/five overlap follows self-activation policy")
	_click(leader.position)
	_click(Vector2(1060, 587))
	for frame in range(15 * 30):
		game._process(MainGame.FIXED_STEP)
	_check(game.abilities.transformations.is_empty() and leader.stats.projectile_count == 3 and leader.transformed_stats == null, "2x expiry restores all twenty original attacks")
	_click(Vector2(780, 654))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.abilities.transformations.is_empty() and game.towers.towers[0].combat_stats.projectiles == 0 and game.towers.tier5_registry.owners(&"dart", 1).size() == 1, "reset recreates experiment and single slot without old timers or stats")
	_click(Vector2(682, 122))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	leader = game.towers.towers[0]
	_click(Vector2(84, 654))
	for tick in range(15 * 60):
		game.simulation_step(MainGame.FIXED_STEP)
		if leader.crit_flash > 0.0:
			break
	for tick in range(12):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(leader.combat_stats.critical_volleys > 0 and leader.crit_flash > 0.0, "Crossbow Master actually fires a critical and retains visible effect")
	_click(Vector2(1225, 632))
	_check(game.hud.stats_panel.detail.visible and game.hud.stats_panel.detail_text.text.contains("유효 피해"), "critical effective damage available in statistics")
	await _capture("crossbow-master-v08")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and game.towers.tier5_registry.owners(&"dart", 0).is_empty(), "F6 returns to untouched normal campaign with empty tier5 slots")
	print("V0.8 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://test-results/%s.png" % name)) == OK, "capture " + name)

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.8 VISUAL FAIL: " + message)

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
