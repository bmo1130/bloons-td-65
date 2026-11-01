extends "res://tests/properties_visual.gd"

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	var buttons: Dictionary = game.hud._tower_buttons
	_check(buttons.size() == 4 and buttons[&"tack"].text.contains("260") and buttons[&"tack"].text.contains("R"), "fourth shop price/hotkey")
	var previous: float = 0.0
	for id in [&"dart",&"bomb",&"boomerang",&"tack"]:
		var rect: Rect2 = buttons[id].get_global_rect()
		_check(rect.position.y >= previous and rect.end.y <= game.hud._tower_stats.position.y, "all four rows fit without overlap")
		previous = rect.end.y
	await _capture("tack-shop-v015")
	_key(KEY_R)
	_check(game.building and game.selected_tower == MainGame.TACK, "native R selects tack")
	_click(Vector2(300,290))
	_key(KEY_ESCAPE)
	_click(Vector2(300,290))
	var tower: TowerState = game.selected_instance
	_check(tower != null and tower.definition == MainGame.TACK and game.economy.gold == 140, "native placement260 from normal400")
	_check(game.hud.upgrade_panel.target_button.disabled and not game.hud.upgrade_panel.ability_button.visible, "fixed radial target and no ability button")
	for path in range(3):
		if path > 0:
			_click(Vector2(1175,587))
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
			_click(game.hud._tower_buttons[&"tack"].get_global_rect().get_center())
			_click(Vector2(300,290))
			_key(KEY_ESCAPE)
			_click(Vector2(300,290))
			tower = game.selected_instance
		game.economy.earn(10000)
		for tier in range(1,4):
			var gold: int = game.economy.gold
			var preview: TowerDefinition = TowerStatResolver.preview(tower.definition,tower.tiers,tower.definition.upgrade_at(path,tier))
			_click(game.hud.upgrade_panel._buttons[path].get_global_rect().get_center())
			_check(tower.tiers[path] == tier and game.economy.gold == gold-MainGame.TACK.upgrade_at(path,tier).cost and tower.stats.damage == preview.damage and tower.stats.pierce == preview.pierce, "all9native buys exact cost/preview")
			var button: Button = game.hud.upgrade_panel._buttons[path]
			_check(button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x <= button.size.x-12, "upgrade title fully fits")
		var label: Label = game.hud.upgrade_panel._stats
		_check(Array(label.text.split("\n")).all(func(line:String)->bool:return label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x <= label.size.x), "all radial stat lines fully fit")
		_check(not game.hud.upgrade_panel._buttons[path].disabled and game.hud.upgrade_panel._buttons[path].text.contains("3→4"), "v016 exposes next tier4 after the fixed original tier3 domain")
		await _capture("tack-upgrade-path-%d-v015"%path)
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(144,618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check(lab != null and lab.get("preset_picker").item_count == 118 and lab.get("preset_picker").selected == 77, "native tack lab appended after77 existing presets")
	for index in range(77,95):
		if index != 77:
			await _pick(lab.get("preset_picker") as OptionButton,index)
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
			lab = _lab(game)
		tower = game.towers.towers[0]
		_check(tower.definition == MainGame.TACK and tower.tiers == PackedInt32Array(lab.get("TACK_BUILDS")[index-77]) and tower.combat_stats.invested_gold > 0, "18 real lab purchased builds")
		_check(game.hud.upgrade_panel.target_button.disabled and not game.hud.upgrade_panel.ability_button.visible, "all tack presets fixed target/no ability")
		_click(Vector2(566,199))
		var captured: bool = false
		for tick in range(240):
			game.simulation_step(MainGame.FIXED_STEP)
			if not captured and not game.projectiles.projectiles.is_empty():
				if index in [77,80,83,86,87,88,89,90,91,92,94]:
					for extra in range(5):
						game.simulation_step(MainGame.FIXED_STEP)
					await _capture("tack-flight-%d-v015"%index)
				captured = true
		_check(captured and tower.combat_stats.volleys > 0 and tower.combat_stats.effective_damage > 0, "all lab presets actually emit radial projectiles and damage")
		if index == 94:
			_check(game.towers.towers.size() == 4 and game.towers.towers.map(func(t:TowerState)->StringName:return t.definition.id).has(&"boomerang"), "real4tower mixed lab")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and game.towers.towers.is_empty() and game.projectiles.projectiles.is_empty() and not game.developer_mode, "normal restart preserves economy/campaign and clears state")
	var probe: RefCounted = load("res://tests/tack_tests.gd").new()
	probe._root = root
	var rows: Array = []
	for build: Array in probe.BUILDS:
		rows.append(probe.battle(build,1))
	_checks += probe._checks
	_failures += probe._failures
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmarks/tack-v016-legacy-crosspaths.json"))
	_check(JSON.parse_string(JSON.stringify(rows)) == reference.rows, "all6 complete20game second fingerprints match headless under real renderer")
	var file: FileAccess = FileAccess.open("res://benchmarks/tack-v016-legacy-render-crosspaths.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows},"\t")+"\n")
	file.close()
	print("TACK VISUAL RESULT: %d checks, %d failures"%[_checks,_failures])
	quit(0 if _failures == 0 else 1)


