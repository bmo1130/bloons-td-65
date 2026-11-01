extends "res://tests/properties_visual.gd"

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	var buttons: Dictionary = game.hud._tower_buttons
	_check(buttons.size() == 4 and buttons[&"boomerang"].text.contains("315") and buttons[&"boomerang"].text.contains("W"), "third shop button exposes correct price/hotkey")
	_check(buttons[&"dart"].get_global_rect().end.y <= buttons[&"bomb"].get_global_rect().position.y and buttons[&"bomb"].get_global_rect().end.y <= buttons[&"boomerang"].get_global_rect().position.y and buttons[&"boomerang"].get_global_rect().end.y <= game.hud._tower_stats.position.y, "all three shop rows and stats visible without overlap or scrolling")
	await _capture("boomerang-shop-v013")
	_click(buttons[&"boomerang"].get_global_rect().get_center())
	_check(game.building and game.selected_tower == MainGame.BOOMERANG, "native third catalog button selects boomerang")
	_click(Vector2(250, 350))
	_key(KEY_ESCAPE)
	_click(Vector2(250, 350))
	var tower: TowerState = game.selected_instance
	_check(tower != null and tower.definition == MainGame.BOOMERANG and game.economy.gold == 85, "native placement deducts315 from normal400G")
	game.economy.earn(10000)
	for path in range(3):
		if path > 0:
			_click(Vector2(1175, 587))
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
			_key(KEY_W)
			_check(game.building and game.selected_tower == MainGame.BOOMERANG, "W selects new tower while D/B/A/Space remain available")
			_click(Vector2(250, 350))
			_key(KEY_ESCAPE)
			_click(Vector2(250, 350))
			tower = game.selected_instance
			game.economy.earn(10000)
		for tier in range(1, 4):
			var gold: int = game.economy.gold
			_click(Vector2(1116, 260 + path * 61))
			_check(tower.tiers[path] == tier and game.economy.gold == gold - MainGame.BOOMERANG.upgrade_at(path, tier).cost, "all nine real upgrade buttons and exact debit")
			var button: Button = game.hud.upgrade_panel._buttons[path]
			_check(button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x <= button.size.x - 12.0, "upgrade button name is fully readable without clipping")
		_check(not game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._buttons[path].text.contains("3→4"), "v014 intentionally exposes next tier4 after original tier3 purchases")
		_check(game.hud.upgrade_panel._stats.tooltip_text.contains("궤도:") and game.hud.upgrade_panel._stats.tooltip_text.contains("수명"), "selected tower shows trajectory and lifetime data")
		var stats_label: Label = game.hud.upgrade_panel._stats
		_check(Array(stats_label.text.split("\n")).all(func(line: String) -> bool: return stats_label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, stats_label.get_theme_font_size("font_size")).x <= stats_label.size.x), "all three actual stat lines fit the selection panel")
		await _capture("boomerang-upgrade-path-%d-v013" % path)
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(84, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check((lab.get("preset_picker") as OptionButton).item_count == 95 and (lab.get("preset_picker") as OptionButton).selected == 47, "original47 preset indices retained and14new appended")
	for index in range(47, 61):
		if index != 47:
			await _pick(lab.get("preset_picker") as OptionButton, index)
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
			lab = _lab(game)
		tower = game.towers.towers[0]
		_check(tower.definition == MainGame.BOOMERANG and tower.tiers == PackedInt32Array(lab.get("BOOMERANG_BUILDS")[index - 47]), "each new laboratory actually purchases exact build")
		_click(Vector2(566, 199))
		var captured: bool = false
		var outbound: bool = false
		var returned: bool = false
		for step in range(180):
			game.simulation_step(MainGame.FIXED_STEP)
			for shot in game.projectiles.projectiles:
				outbound = outbound or shot.flight_index == 0
				returned = returned or (shot.flight_mode == TowerDefinition.Flight.RETURN and shot.flight_index == 1)
				if not captured and shot.trail.size() >= 8 and index in [47, 48, 49, 50, 51, 52, 53, 54, 55, 56]:
					await _capture("boomerang-flight-%d-v013" % index)
					captured = true
		if index == 57:
			_check(tower.combat_stats.effective_damage == 0 and game.projectiles._next_id == 1, "native camo preset rejects all undetected targets")
		else:
			_check(tower.combat_stats.effective_damage > 0 and tower.combat_stats.volleys > 0, "each other preset fires and damages actual targets")
		if index in [47, 49, 50, 53, 54, 55, 56]:
			_check(captured, "rendered curve/Kylie/Bionic trail captured")
		if index in [48, 51, 52]:
			_check(captured, "actual physically moving ricochet captured")
		if index in [50, 55, 56]:
			_check(outbound and returned, "visible Kylie outward and return phases")
		if index == 48:
			_check(tower.combat_stats.targets_damaged > tower.combat_stats.volleys, "real ricocheting glaives damage multiple separate IDs")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and game.projectiles.projectiles.is_empty(), "restart returns to normal economy/campaign and clears flights/statistics")
	print("BOOMERANG VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
