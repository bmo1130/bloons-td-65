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
	_click(Vector2(780, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check(lab != null and (lab.get("preset_picker") as OptionButton).selected == 10 and (lab.get("type_picker") as OptionButton).selected == 11, "native MOAB laboratory opens through new button")
	_click(Vector2(566, 199))
	_check(game.balloons.balloons.size() == 1 and game.balloons.balloons[0].shell_hp == 200, "native basic dart MOAB200 spawn")
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	var blimp: BalloonState = game.balloons.balloons[0]
	_check(blimp.definition.moab_class and blimp.shell_hp < 200 and game.towers.towers[0].combat_stats.moab_damage > 0, "actual basic dart hits moving MOAB, independent HP statistics")
	game.combat.apply_hit(blimp.id, AttackSpec.new(60, 1, AttackSpec.Attribute.NORMAL))
	_check(blimp.damage_stage() >= 1, "real damage creates visible hull stage")
	lab.call("_process", 0.3)
	await _capture("moab-v010")
	var selected: TowerState = game.selected_instance
	for mode in [TowerState.TargetMode.LAST, TowerState.TargetMode.CLOSE, TowerState.TargetMode.STRONG, TowerState.TargetMode.FIRST]:
		_click(game.hud.upgrade_panel.target_button.global_position + Vector2(100, 12))
		_check(selected.target_mode == mode and not game.building and game.selected_instance == selected, "native target button cycles modes without placement")
	# Native preset selector retains all v0.9 entries; appended entries exercise
	# real purchases, tower combat and explicit debug shell-break action.
	await _pick(lab.get("preset_picker") as OptionButton, 11)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.towers.towers[0].upgrade_text() == "0-2-5" and game.towers.towers[0].combat_stats.moab_damage > 0, "Crossbow Master purchased and attacks blimp")
	await _pick(lab.get("preset_picker") as OptionButton, 12)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.towers.towers[0].upgrade_text() == "5-0-2" and game.towers.towers[0].combat_stats.moab_damage > 0, "Ultra actually damages blimp without knockback")
	await _pick(lab.get("preset_picker") as OptionButton, 13)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(548, 654))
	_click(game.hud.upgrade_panel.ability_button.global_position + Vector2(100, 15))
	_click(Vector2(566, 199))
	lab.call("_process", 0.3)
	await _capture("bfb-plasma-v010")
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.towers.towers.size() == 20 and game.towers.towers[0].transformed_stats != null and game.towers.towers[0].combat_stats.moab_damage > 0, "native charged Plasma20 damages BFB")
	await _pick(lab.get("preset_picker") as OptionButton, 17)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(664, 654)) # Pause without disabling controls.
	_click(Vector2(320, 198)) # Camo, independent of default Fortified.
	_click(Vector2(566, 199))
	blimp = game.balloons.balloons[0]
	_check(blimp.definition.id == &"zomg" and blimp.shell_hp == 8000 and blimp.camo and blimp.fortified, "native fortified camo ZOMG combinations")
	game.combat.apply_hit(blimp.id, _detecting_hit(4000))
	lab.call("_process", 0.3)
	_check((lab.get("specimen_status") as Label).text.contains("4000/8000") and blimp.damage_stage() == 2, "live HP HUD and staged fortified hull")
	await _capture("fortified-zomg-v010")
	for phase in range(3):
		_click(Vector2(664, 618))
	_check(game.balloons.balloons.size() == 64 and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.definition.id == &"ceramic" and b.fortified and b.camo and b.shell_hp == 20), "native shell-break reaches64 fortified camo ceramics without overkill")
	lab.call("_process", 0.3)
	await _capture("zomg-children-v010")
	await _pick(lab.get("preset_picker") as OptionButton, 18)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	_click(Vector2(664, 618))
	_check(game.balloons.balloons.size() == 40 and game.economy.total_earned == 10, "MOAB10 simultaneous shell break creates40 ceramics,10G")
	_click(Vector2(664, 618))
	_check(game.balloons.balloons.size() == 40 and game.economy.total_earned == 10, "repeated break cannot pay or split removed parents twice")
	await _pick(lab.get("preset_picker") as OptionButton, 19)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	_click(Vector2(664, 618))
	_check(game.balloons.balloons.size() == 16 and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.definition.id == &"moab"), "BFB4 native split creates16 MOABs")
	_click(Vector2(780, 654))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.balloons.balloons.is_empty() and game.battle_stats.total_pops == 0 and game.towers.towers[0].target_mode == TowerState.TargetMode.FIRST, "lab reset clears children and per-instance target mode/statistics")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20, "MOAB lab never alters normal campaign")
	print("V0.10 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _detecting_hit(amount: int) -> AttackSpec:
	var attack: AttackSpec = AttackSpec.new(amount, 1, AttackSpec.Attribute.NORMAL)
	attack.detects_camo = true
	return attack
