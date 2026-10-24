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
		var tower: TowerState = game.selected_instance
		_check(tower != null and tower.definition == MainGame.BOMB, "native bomb placement and selection")
		game.economy.earn(2000)
		for tier in range(1, 4):
			var before: int = game.economy.gold
			var item: UpgradeDefinition = MainGame.BOMB.upgrade_at(path, tier)
			_click(Vector2(1116, 260 + path * 61))
			_check(tower.tiers[path] == tier and game.economy.gold == before - item.cost, "all nine native bomb purchases")
		_check(not game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._buttons[path].text.contains("→4") and game.hud.upgrade_panel._details[path].text.contains("구매 가능"), "v0.12 native tier3 UI now offers tier4")
		_check(game.hud.upgrade_panel._stats.text.contains("EXPLOSIVE") and game.hud.upgrade_panel._buttons[path].text.contains(["폭발", "MOAB", "연쇄"][path]), "bomb-specific labels and damage type")
		if path == 1:
			_check(game.hud.upgrade_panel._stats.tooltip_text.contains("+18"), "MOAB bonus visible in tooltip")
		var target: BalloonState = game.balloons.spawn(load("res://data/balloons/moab.tres"), 500.0)
		target.position = Vector2(300, 350)
		target.record_motion(PackedVector2Array([target.position, target.position]), 0.0)
		game.projectiles.fire_volley(Vector2(280, 350), target, tower.stats, tower.id)
		for step in range(4):
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(not game.combat.effects.is_empty(), "upgraded bomb real rendered blast")
		await _capture("bomb-path-%d-v011" % path)
		if path == 2:
			for step in range(10):
				game.projectiles.update(MainGame.FIXED_STEP)
			await _capture("bomb-cluster-explosions-v011")
		_click(Vector2(1175, 587))
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		_check(game.economy.gold == 400 and game.towers.towers.is_empty() and game.projectiles.projectiles.is_empty() and game.combat.effects.is_empty(), "restart clears all bomb state and effects")
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(316, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check((lab.get("preset_picker") as OptionButton).selected == 35 and game.towers.towers[0].definition == MainGame.BOMB and game.towers.towers[0].tiers[0] == 3, "native bomb lab entry and actual purchases")
	for index in [36, 37, 38, 39, 40]:
		await _pick(lab.get("preset_picker") as OptionButton, index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		var tower: TowerState = game.towers.towers[0]
		_check(tower.definition == MainGame.BOMB and tower.tiers == PackedInt32Array(lab.get("BOMB_BUILDS")[index - 35]), "native bomb preset retains exact crosspath")
		_click(Vector2(566, 199))
		var captured: bool = false
		for step in range(240):
			game.simulation_step(MainGame.FIXED_STEP)
			if not captured and index == 37 and tower.combat_stats.split_projectiles > 0:
				await _capture("bomb-fragments-lab-v011")
				captured = true
			if not captured and index == 40 and game.combat.effects.size() > 1:
				await _capture("bomb-cluster-lab-v011")
				captured = true
		_check(tower.combat_stats.effective_damage > 0 and game.projectiles._next_id > 1, "each lab preset fires and damages real targets")
		if index in [37, 38, 40]:
			_check(tower.combat_stats.split_projectiles > 0, "real frag/cluster child projectiles in lab")
		if index in [37, 40]:
			_check(captured, "captured actual emitted children and overlapping explosions")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.waves.waves.size() == 20, "bomb sandbox budget cannot enter normal mode")
	print("BOMB VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
