extends "res://tests/properties_visual.gd"

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	for path in range(3):
		_key(KEY_B)
		_click(Vector2(250, 350))
		_key(KEY_ESCAPE)
		_click(Vector2(250, 350))
		game.economy.earn(100000)
		var tower: TowerState = game.selected_instance
		_check(tower != null and tower.definition == MainGame.BOMB, "native bomb selection for high-tier purchases")
		for tier in range(1, 6):
			var gold: int = game.economy.gold
			_click(Vector2(1116, 260 + path * 61))
			_check(tower.tiers[path] == tier and game.economy.gold == gold - MainGame.BOMB.upgrade_at(path, tier).cost, "all fifteen upgrades via native button and exact debit")
			if path == 1 and tier == 4:
				_check(game.hud.upgrade_panel.ability_button.disabled and game.hud.upgrade_panel.ability_button.text.contains("대상 없음"), "Assassin ready but empty screen disables button")
				game.balloons.spawn(load("res://data/balloons/bfb.tres"), 1400.0)
				game.hud.upgrade_panel.refresh()
				_check(not game.hud.upgrade_panel.ability_button.disabled, "global MOAB enables ability outside attack range")
				_click(Vector2(1116, 480))
				_check(game.abilities.state_for(tower).cooldown_remaining == 30.0 and game.projectiles.projectiles.size() == 1, "native active button launches one real missile")
				_check(game.hud.upgrade_panel.ability_button.disabled and game.hud.upgrade_panel.ability_button.text.contains("30.0"), "running cooldown disables and displays seconds")
				await _capture("bomb-assassin-v012")
		_check(game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._buttons[path].text.contains("완료") and game.hud.upgrade_panel._details[path].text.contains("(5)"), "each path completes at five")
		if path == 1:
			_check(game.abilities.states.size() == 1 and game.abilities.state_for(tower).cooldown_remaining == 10.0, "native4-to5 replaces active and clamps cooldown")
			game.abilities.update(10.0)
			game.hud.upgrade_panel.refresh()
			_key(KEY_A)
			_check(game.abilities.state_for(tower).cooldown_remaining == 10.0 and game.projectiles.projectiles.size() == 2, "A hotkey activates selected Eliminator")
			await _capture("bomb-eliminator-v012")
		elif path == 2:
			_check(not game.hud.upgrade_panel.ability_button.visible and game.hud.upgrade_panel.passive_status.visible and not game.hud._status.visible, "Blitz displays unobscured passive status without active button")
			_key(KEY_A)
			_check(game.abilities.state_for(tower).cooldown_remaining == 0.0, "passive ignores active hotkey")
			await _capture("bomb-blitz-ui-v012")
		_click(Vector2(1175, 587))
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(316, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	for index in range(41, 47):
		await _pick(lab.get("preset_picker") as OptionButton, index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		var tower: TowerState = game.towers.towers[0]
		_check(tower.tiers == PackedInt32Array(lab.get("BOMB_BUILDS")[index - 35]) and game.selected_instance == tower, "six high-tier F7 presets purchased and selected")
		_click(Vector2(566, 199))
		if index in [43, 44]:
			game.hud.upgrade_panel.refresh()
			_key(KEY_A)
			_check(game.abilities.state_for(tower).cooldown_remaining > 0.0, "native ability usable in each missile laboratory")
		elif index == 46:
			_click(Vector2(664, 618))
		var saw_control: bool = false
		var saw_children: bool = false
		for step in range(240):
			game.simulation_step(MainGame.FIXED_STEP)
			saw_control = saw_control or game.balloons.balloons.any(func(balloon: BalloonState) -> bool: return balloon.stun_remaining > 0.0)
			saw_children = saw_children or tower.combat_stats.split_projectiles >= 16
			if (index in [41, 42] and saw_control) or (index == 45 and saw_children) or (index in [43, 44, 46] and step == 20):
				await _capture("bomb-lab-%d-v012" % index)
				break
		_check(tower.combat_stats.effective_damage > 0, "each high-tier preset deals real damage")
		if index in [41, 42]:
			_check(saw_control, "rendered Impact and Crush show real stun state")
		if index == 45:
			_check(saw_children and tower.attack_counter >= 2, "recursive laboratory reaches second volley and child ring")
		if index == 46:
			_check(game.abilities.state_for(tower).cooldown_remaining > 0.0 and not game.hud.upgrade_panel.ability_button.visible, "native leak demo triggers passive with no active button")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.economy.gold == 400 and game.towers.towers.is_empty() and game.abilities.states.is_empty(), "normal-mode restart clears sandbox abilities, counters and budget")
	print("BOMB TIER5 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
