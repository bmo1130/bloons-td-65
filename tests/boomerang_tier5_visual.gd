extends "res://tests/properties_visual.gd"

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
	_click(Vector2(84,618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check((lab.get("preset_picker") as OptionButton).item_count == 95,"61 old presets plus16 appended")
	for index in range(61,77):
		await _pick(lab.get("preset_picker") as OptionButton,index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		var builds: Array = lab.get("BOOMERANG_TIER5_BUILDS")[index-61]
		_check(game.towers.towers.size()==builds.size(),"each high tier lab tower count via real purchase")
		for t in range(builds.size()):
			_check(game.towers.towers[t].tiers==PackedInt32Array(builds[t]),"each high tier preset exact real build")
		var tower: TowerState = game.towers.towers[0]
		var panel: TowerUpgradePanel = game.hud.upgrade_panel
		if index in [65,66,67]:
			_check(panel.ability_button.visible and panel.ability_button.disabled,"native charge initial waiting state")
			_click(Vector2(548,654))
			panel.refresh()
			_check(not panel.ability_button.disabled,"native lab charge prepares button")
			if index==65:
				_click(panel.ability_button.get_global_rect().get_center())
			else:
				_key(KEY_A)
			panel.refresh()
			var state: AbilityState = game.abilities.state_for(tower)
			_check(state.active_remaining>0 and panel.ability_button.disabled and panel.ability_button.text.contains("활성"),"native button/A activates self buff and marks active")
			_key(KEY_A)
			_check(state.active_remaining==state.definition.duration,"A during active cannot restart duration")
		else:
			_check(not panel.ability_button.visible,"no invented active ability for passive/secondary paths")
		_click(Vector2(566,199))
		_check(game.balloons.balloons.size()>0,"native spawn in each high tier preset")
		for tick in range(180):
			game.simulation_step(MainGame.FIXED_STEP)
		_check(game.battle_stats.total_pops>0 or tower.combat_stats.effective_damage>0,"each rendered preset really damages selected targets")
		panel.refresh()
		_check(Array(panel._stats.text.split("\n")).all(func(line:String)->bool:return panel._stats.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,panel._stats.get_theme_font_size("font_size")).x <= panel._stats.size.x),"high tier stat lines fit panel")
		await _capture("boomerang-v014-preset-%d"%index)
		if index==66:
			_click(Vector2(896,654))
			_check(game.abilities.states.is_empty() and game.towers.towers.is_empty(),"native selected removal clears ability")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.economy.gold==400 and game.economy.lives==50 and game.waves.waves.size()==20 and game.combat.damage_effects.is_empty() and game.projectiles.pending_areas.is_empty(),"native normal restart clears all auxiliary state and keeps economy")
	var suite: RefCounted = load("res://tests/boomerang_tier5_tests.gd").new()
	var cpu: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmarks/boomerang-v014-crosspaths.json"))
	for build: Array in suite.HIGH_BUILDS:
		if not game.towers.towers.is_empty():
			_click(Vector2(1175,587))
			await scene_changed
			game = current_scene as MainGame
			game.set_process(false)
		game.economy.earn(1000000)
		game.economy.lives = 1000000
		_key(KEY_W)
		_click(Vector2(250,350))
		_key(KEY_ESCAPE)
		_click(Vector2(250,350))
		var tower: TowerState = game.selected_instance
		for path in range(3):
			for tier in range(1,build[path]+1):
				var gold: int = game.economy.gold
				_click(Vector2(1116,260+path*61))
				_check(tower.tiers[path]==tier and game.economy.gold==gold-MainGame.BOOMERANG.upgrade_at(path,tier).cost,"all12 crosspaths native exact upgrade and debit")
		# Match CPU fixture's starting money (its helper adds tower directly).
		game.economy.gold += 315
		for index in range(120):
			game.balloons.spawn(load("res://data/balloons/%s.tres"%["green","ceramic","moab","bfb","lead","ddt"][index%6]),420+index*3,false,index%4==0,true)
		var state: AbilityState = game.abilities.state_for(tower)
		if state != null:
			state.cooldown_remaining = 0.0
			_key(KEY_A)
		for frame in range(720):
			game.simulation_step(MainGame.FIXED_STEP)
			if frame%120==0:
				await process_frame
		game.hud.upgrade_panel.refresh()
		var result: Dictionary = suite.snapshot_high(game,tower)
		var expected: Array = cpu.rows.filter(func(row:Dictionary)->bool:return PackedInt32Array(row.build)==PackedInt32Array(build))
		# Align the ordinary initial400G with the CPU fixture's laboratory funds.
		result.combat[0] -= 400
		_check(JSON.parse_string(JSON.stringify(result))==expected[0].result,"all12 actual rendered crosspaths equal CPU full logical result")
		await _capture("boomerang-v014-crosspath-%d%d%d"%build)
	print("BOOMERANG TIER5 VISUAL RESULT: %d checks, %d failures"%[_checks,_failures])
	quit(0 if _failures==0 else 1)
