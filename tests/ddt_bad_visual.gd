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
	_click(Vector2(550, 618))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	var lab: Node = _lab(game)
	_check((lab.get("preset_picker") as OptionButton).selected == 21 and (lab.get("type_picker") as OptionButton).selected == 14, "native DDT/BAD lab entry and appended catalogue")
	_check((lab.get("camo_toggle") as CheckButton).button_pressed and (lab.get("camo_toggle") as CheckButton).disabled, "DDT intrinsic camo visible and cannot be accidentally omitted")
	_click(Vector2(566, 199))
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.balloons.balloons[0].shell_hp == 400 and game.projectiles._next_id == 1, "actual basic dart cannot target fast DDT")
	for index in [22, 23]:
		await _pick(lab.get("preset_picker") as OptionButton, index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		_click(Vector2(566, 199))
		for step in range(120):
			game.simulation_step(MainGame.FIXED_STEP)
		_check(game.balloons.balloons[0].shell_hp == 400 and game.projectiles._next_id == 1, "native SHARP/bomb cannot bypass composite DDT immunity")
	for index in [24, 25]:
		await _pick(lab.get("preset_picker") as OptionButton, index)
		await scene_changed
		game = current_scene as MainGame
		game.set_process(false)
		lab = _lab(game)
		_click(Vector2(566, 199))
		for step in range(120):
			game.simulation_step(MainGame.FIXED_STEP)
		_check(game.towers.towers[0].combat_stats.moab_damage > 0, "native402/005 actual projectiles hit fast camo DDT")
		if index == 24:
			lab.call("_process", 0.3)
			await _capture("ddt-juggernaut-v011")
	await _pick(lab.get("preset_picker") as OptionButton, 26)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(548, 654))
	_click(game.hud.upgrade_panel.ability_button.global_position + Vector2(100, 15))
	_click(Vector2(566, 199))
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.towers.towers[0].transformed_stats != null and game.towers.towers[0].combat_stats.moab_damage > 0, "native Plasma with detection hits DDT")
	_check(game.towers.towers.filter(func(t: TowerState) -> bool: return t.tiers[2] == 0).all(func(t: TowerState) -> bool: return t.combat_stats.volleys == 0), "blind Plasma recipients do not target camo descendants")
	await _pick(lab.get("preset_picker") as OptionButton, 27)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(664, 654))
	_click(Vector2(566, 199))
	_check(game.balloons.balloons.size() == 10 and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.camo and b.fortified and b.shell_hp == 800), "native ten fortified DDTs")
	_click(Vector2(432, 618)) # Explicit debug decamo, distinct from detection.
	_click(Vector2(664, 618)) # Split only current hulls.
	lab.call("_process", 0.3)
	_check(game.balloons.balloons.size() == 40 and game.balloons.balloons.all(func(b: BalloonState) -> bool: return not b.camo and b.regrow and b.fortified and b.shell_hp == 20), "native decamo DDT children do not regain camo, keep Regrow metadata")
	_check((lab.get("specimen_status") as Label).text.contains("재생1") and (lab.get("specimen_status") as Label).text.contains("미동작"), "visible Regrow marker and explicit unimplemented behavior")
	await _capture("ddt-regrow-children-v011")
	await _pick(lab.get("preset_picker") as OptionButton, 29)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(664, 654))
	_click(Vector2(566, 199))
	var target: BalloonState = game.balloons.balloons[0]
	_check(target.definition.id == &"bad" and target.shell_hp == 40000 and not target.camo and target.fortified and not (lab.get("camo_toggle") as CheckButton).disabled, "native fortified BAD default noncamo40000HP")
	var hit: AttackSpec = AttackSpec.new(20000, 1, AttackSpec.Attribute.NORMAL)
	game.combat.apply_hit(target.id, hit)
	lab.call("_process", 0.3)
	_check(target.damage_stage() == 2 and (lab.get("specimen_status") as Label).text.contains("20000/40000"), "native BAD damage stage and live HP")
	await _capture("fortified-bad-v011")
	_click(Vector2(664, 618))
	lab.call("_process", 0.3)
	_check(game.balloons.balloons.size() == 5 and game.balloons.balloons.filter(func(b: BalloonState) -> bool: return b.definition.id == &"ddt" and b.camo and b.fortified).size() == 3 and game.balloons.balloons.filter(func(b: BalloonState) -> bool: return b.definition.id == &"zomg" and not b.camo and b.fortified).size() == 2, "native BAD creates distinct fortified/camo defaults for both child types")
	await _capture("bad-mixed-children-v011")
	await _pick(lab.get("preset_picker") as OptionButton, 32)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	target = game.balloons.balloons[0]
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(target.shell_hp < 20000 and target.knockback_remaining == 0 and is_equal_approx(target.distance, 650 + 17.1 * 2), "actual Juggernaut damages BAD without displacement")
	await _pick(lab.get("preset_picker") as OptionButton, 33)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(game.towers.towers[1].position)
	_click(Vector2(548, 654))
	_click(game.hud.upgrade_panel.ability_button.global_position + Vector2(100, 15))
	_click(Vector2(566, 199))
	for step in range(120):
		game.simulation_step(MainGame.FIXED_STEP)
	_check(game.towers.towers.size() == 22 and game.towers.towers[0].combat_stats.moab_damage > 0 and game.towers.towers[1].combat_stats.moab_damage > 0 and game.towers.towers[2].combat_stats.moab_damage > 0, "three unique Tier5 paths all attack BAD in real game")
	await _pick(lab.get("preset_picker") as OptionButton, 34)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	lab = _lab(game)
	_click(Vector2(566, 199))
	_click(Vector2(664, 618))
	_check(game.balloons.balloons.size() == 15 and game.economy.total_earned == 3, "BAD3 native simultaneous split keeps all mixed children")
	_click(Vector2(780, 654))
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(game.balloons.balloons.is_empty() and game.battle_stats.total_pops == 0 and not game.experiment_paused, "native reset clears DDT/BAD descendants and flags")
	_key(KEY_F6)
	await scene_changed
	game = current_scene as MainGame
	game.set_process(false)
	_check(not game.developer_mode and game.economy.gold == 400 and game.economy.lives == 50 and game.waves.waves.size() == 20, "DDT/BAD laboratory never changes normal campaign")
	print("V0.11 VISUAL RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
