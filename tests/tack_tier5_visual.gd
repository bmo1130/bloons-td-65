extends "res://tests/properties_visual.gd"

func _run() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	var probe: RefCounted = load("res://tests/tack_tier5_tests.gd").new()
	for build: Array in probe.HIGH:
		_key(KEY_R)
		_click(Vector2(300,290))
		_key(KEY_ESCAPE)
		_click(Vector2(300,290))
		var tower: TowerState = game.selected_instance
		game.economy.earn(200000)
		_check(tower != null and tower.definition == MainGame.TACK,"native base260 placement")
		for path in range(3):
			for tier in range(1,build[path]+1):
				var gold: int = game.economy.gold
				var before: TowerDefinition = TowerStatResolver.preview(tower.definition,tower.tiers,tower.definition.upgrade_at(path,tier))
				var button: Button = game.hud.upgrade_panel._buttons[path]
				_check(not button.disabled,"real upgrade purchase is available")
				_click(button.get_global_rect().get_center())
				_check(tower.tiers[path] == tier and game.economy.gold == gold-MainGame.TACK.upgrade_at(path,tier).cost and tower.stats.damage == before.damage and tower.stats.pierce == before.pierce,"12crosspaths native6/7buys exactcost/preview")
		var panel: TowerUpgradePanel = game.hud.upgrade_panel
		_check(panel.target_button.disabled and panel.target_button.text.contains("360"),"all12 preserve fixed radial/area targeting")
		_check(panel._stats.mouse_filter == Control.MOUSE_FILTER_PASS and panel._stats.tooltip_text.contains("MOAB 추가 피해: +%d"%tower.stats.moab_bonus) and panel._stats.tooltip_text.contains("세라믹 추가 피해: +%d"%tower.stats.ceramic_bonus),"all12final-tier special descriptions accept mouse hover;not an ignored Label")
		var state: AbilityState = game.abilities.state_for(tower)
		if state != null:
			_check(panel.ability_button.visible and panel.ability_button.disabled,"ability initial wait visible")
			state.cooldown_remaining = 0
			panel.refresh()
			_click(panel.ability_button.get_global_rect().get_center())
			_check(state.active_remaining == state.definition.duration and panel.ability_button.disabled,"native ability button starts rotating independent attack")
			_key(KEY_A)
			_check(state.active_remaining == state.definition.duration,"Awhileactive cannot reset ability")
		else:
			_check(not panel.ability_button.visible,"no ability invented for fire or Zone")
		game.balloons.spawn(load("res://data/balloons/moab.tres"),650.0)
		for tick in range(180):
			game.simulation_step(MainGame.FIXED_STEP)
			if tick == 5:
				await _capture("tack-v016-native-%d%d%d"%build)
		_check(tower.combat_stats.effective_damage>0,"all12 real rendered combat damages targets")
		panel.refresh()
		_check(Array(panel._stats.text.split("\n")).all(func(line:String)->bool:return panel._stats.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,panel._stats.get_theme_font_size("font_size")).x <= panel._stats.size.x),"all12 actual stat lines fit")
		for button: Button in panel._buttons:
			_check(button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x <= button.size.x-12,"English upgrade names fit without clipping")
		_click(Vector2(1175,587))
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
	_key(KEY_F7)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_click(Vector2(144,618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check(lab.get("preset_picker").item_count == 118,"95old IDs unchanged,23new appended")
	for index in range(95,118):
		await _pick(lab.get("preset_picker") as OptionButton,index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		var tower: TowerState = game.towers.towers[0]
		var panel: TowerUpgradePanel = game.hud.upgrade_panel
		_check(game.hud._wave.text == "압정 슈터 검사실" and game.hud._status.text.contains("32방향"),"all23new scenarios use correct tack laboratory title/status")
		_check(tower.tiers == PackedInt32Array(lab.get("TACK_TIER5_BUILDS")[index-95]),"23appended presets actually buy exactbuilds")
		_check(tower.combat_stats.invested_gold > 0 and game.economy.gold < 200000,"preset uses actual purchase economy")
		var state: AbilityState = game.abilities.state_for(tower)
		if state != null:
			_check(panel.ability_button.visible and panel.ability_button.disabled,"laboratory active initial cooldown")
			_click(Vector2(548,654))
			panel.refresh()
			_check(not panel.ability_button.disabled,"native recharge prepares active")
			_key(KEY_A)
			panel.refresh()
			_check(state.active_remaining > 0 and panel.ability_button.disabled,"native A activates skill and shows active")
		_click(Vector2(566,199))
		_check(not game.balloons.balloons.is_empty(),"each new preset has real spawn input")
		for tick in range(180):
			game.simulation_step(MainGame.FIXED_STEP)
			if tick == 7:
				await _capture("tack-v016-preset-%d"%index)
		_check(tower.combat_stats.effective_damage>0,"each of23presets confirms fire/meteor/blade/radialdamage")
		if index == 117:
			_check(game.towers.towers.size() == 4,"fourkind high tier mixed purchase")
		if index == 110:
			_click(Vector2(664,654))
			var frozen: Array = [state.active_remaining,state.cooldown_remaining,state.bursts_emitted]
			game.simulation_step(2.0)
			_check(game.experiment_paused and frozen == [state.active_remaining,state.cooldown_remaining,state.bursts_emitted],"native pause freezes duration/cooldown/emissions")
			_click(Vector2(664,654))
			_click(Vector2(896,654))
			_check(game.abilities.state_for(tower) == null and game.towers.towers.is_empty() and not game.hud.upgrade_panel.visible,"native selected removal erases abilityUI/state")
			_click(Vector2(780,654))
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
			lab = _lab(game)
			_check(game.projectiles.projectiles.is_empty() and game.balloons.balloons.is_empty() and game.combat.damage_effects.is_empty(),"native laboratory reset clears attacks/DoT/balloons")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20 and game.towers.towers.is_empty(),"F6return preserves normal400/50/20campaign")
	probe._root = root
	var rows: Array = []
	for build: Array in probe.HIGH:
		rows.append(probe.high_battle(build,1))
	_checks += probe._checks
	_failures += probe._failures
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmarks/tack-v016-crosspaths.json"))
	_check(JSON.parse_string(JSON.stringify(rows)) == reference.rows,"all12complete8second fingerprints match headless under actual renderer")
	var file: FileAccess = FileAccess.open("res://benchmarks/tack-v016-render-crosspaths.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows},"\t")+"\n")
	file.close()
	print("TACK TIER5 VISUAL RESULT: %d checks, %d failures"%[_checks,_failures])
	quit(0 if _failures == 0 else 1)
