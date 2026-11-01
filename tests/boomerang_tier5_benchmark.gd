extends "res://tests/chain_benchmark.gd"

var _high_fixture: bool = false
var _active_charge: bool = false
var _moab_fixture: bool = false
var _mix_fixture: bool = false
var _before_instances: int = 0
var _before_order_ids: int = 0
var _setup_done: bool = false

func _game() -> MainGame:
	var game: MainGame = super._game()
	if _high_fixture:
		# ONLY this explicit stress fixture allows10 same-path tier5s.
		game.towers.tier5_registry.limits = {&"boomerang": {0:10,1:10,2:10}}
		game.combat.profile_updates = true
		game.balloons.profile_changes = true
	_setup_done = false
	return game

func _maintain(game: MainGame,count: int) -> void:
	if not _moab_fixture:
		super._maintain(game,count)
		return
	# The MOAB-only stress maintainer drains real split children between steps;
	# this is not a full-lineage benchmark or an ordinary campaign fixture.
	for index in range(game.balloons.balloons.size()-1,-1,-1):
		if not game.balloons.balloons[index].definition.moab_class:
			game.balloons._remove(index)
	while game.balloons.balloons.size()>count:
		game.balloons._remove(game.balloons.balloons.size()-1)
	while game.balloons.balloons.size()<count:
		game.balloons.spawn(load("res://data/balloons/moab.tres"),600.0+(_serial%41)*0.5)
		_serial += 1

func _frame(game: MainGame,speed: int,count: int,frame: int) -> Dictionary:
	if _high_fixture and not _setup_done:
		_setup_done = true
		if _active_charge:
			for tower in game.towers.towers:
				var state: AbilityState = game.abilities.state_for(tower)
				state.cooldown_remaining = 0.0
				game.abilities.activate(tower)
		if _mix_fixture:
			for index in range(game.towers.towers.size()-1,2,-1):
				game.towers.remove_tower(game.towers.towers[index])
			var catalog: Array[TowerDefinition] = [MainGame.DART,MainGame.BOMB,MainGame.BOOMERANG]
			for index in range(3):
				game.towers.remove_tower(game.towers.towers[0])
				game.towers.add_tower(Vector2(250+index*75,300),catalog[index])
				var tower: TowerState = game.towers.towers.back()
				var build: Array = [[0,2,5],[0,2,5],[5,0,2]][index]
				for path in range(3):
					for tier in range(1,build[path]+1):
						if not game.try_upgrade(tower,catalog[index].upgrade_at(path,tier)):
							push_error("mixed fixture purchase failed")
			game.select_instance(game.towers.towers[0])
	var sample: Dictionary = super._frame(game,speed,count,frame)
	sample.projectile_allocations = game.projectiles.instances_created - _before_instances
	sample.auxiliary_order_ids = game.projectiles._next_id - _before_order_ids - int(sample.projectile_allocations)
	if _high_fixture:
		sample.aoe_query_ms = game.combat.profile_usec.aoe_query/1000.0
		sample.aoe_sort_ms = game.combat.profile_usec.aoe_sort/1000.0
		sample.aoe_damage_ms = game.combat.profile_usec.aoe_damage/1000.0
		sample.dot_schedule_ms = game.combat.profile_usec.dot_schedule/1000.0
		sample.dot_damage_ms = game.combat.profile_usec.dot_damage/1000.0
		sample.press_ms = game.combat.profile_usec.press/1000.0
		sample.effect_update_ms = game.combat.profile_usec.effect_update/1000.0
		sample.effect_apply_ms = game.combat.profile_usec.effect_apply/1000.0
		sample.dot_count = game.combat.damage_effects.size()
		sample.area_events = game.combat.area_events
		sample.dot_ticks = game.combat.dot_ticks
	return sample

func _reset_frame(game: MainGame) -> void:
	super._reset_frame(game)
	game.combat.reset_profile()
	_before_instances = game.projectiles.instances_created
	_before_order_ids = game.projectiles._next_id

func _run() -> void:
	_render = OS.get_cmdline_user_args().has("--render")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rows: Array[Dictionary] = []
	var modes: Array = [[[0,0,0],false,false,false],[[3,2,0],false,false,false],[[4,2,0],false,false,false],[[5,0,2],false,false,false],[[5,0,2],false,true,false],[[0,4,0],true,false,false],[[0,5,0],true,false,false],[[0,0,4],false,true,false],[[0,0,5],false,true,false],[[0,0,0],false,false,true]]
	for trial in range(2):
		for config: Array in modes:
			_high_fixture = config[0] not in [[0,0,0],[3,2,0]] or config[3]
			_active_charge = config[1]
			_moab_fixture = config[2]
			_mix_fixture = config[3]
			for speed in [1,2]:
				var row: Dictionary = await _boomerang_load(config[0],1000,speed)
				row.trial = trial
				if _moab_fixture and config[0] == [5,0,2]:
					row.mode += "_moab"
				if _mix_fixture:
					row.mode = "three_towers_mix"
				rows.append(row)
		_high_fixture = false
		_active_charge = false
		_moab_fixture = false
		_mix_fixture = false
		for speed in [1,2]:
			var row: Dictionary = await _bomb_load("bomb_blitz_mix10",1000,speed)
			row.trial = trial
			rows.append(row)
	var label: String = "render" if _render else "cpu"
	var file: FileAccess = FileAccess.open("res://benchmarks/%s-after-%s.json"%[_argument("--output-prefix","boomerang-v014"),label],FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":"v0.14","source_sha":{"projectiles":FileAccess.get_sha256("res://scripts/systems/projectile_system.gd"),"combat":FileAccess.get_sha256("res://scripts/systems/combat_system.gd"),"upgrades":FileAccess.get_sha256("res://scripts/systems/upgrade_system.gd"),"towers":FileAccess.get_sha256("res://scripts/systems/tower_system.gd")},"rows":rows,"rendered":_render,"engine":Engine.get_version_info().string,"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name() if _render else "headless","conditions":"1000 maintained/10towers except mixed3;30warm+120samples per trial;2trials=240pooled samples;1x/2x;CPU inclusive simulation+maintenance+HUD;render frame_post_draw wall VSyncOFF. 004/005 and extra502_shred stress maintain1000 real MOAB, draining split children between steps (not full lineage);others old pink/blue/yellow fixture. Tier5 stress registry capacity10 ONLY in fixture. Turbo/Perma active all measured duration. Full fingerprints include live balloons,projectiles;new suite verifies equal game time separately. No detailed CombatTrace;inclusive timers overlap. Projectile allocations count actual ProjectileState constructors;auxiliary_order_ids are scheduled area/DOT ordering proxies,not heap allocations."},"\t")+"\n")
	file.close()
	print("BOOMERANG TIER5 BENCHMARK COMPLETE: %d rows %s"%[rows.size(),label])
	quit()

func _report(game: MainGame, data: Dictionary, mode: String, count: int, speed: int) -> Dictionary:
	var row: Dictionary = super._report(game,data,mode,count,speed)
	if _high_fixture:
		var probe: RefCounted = load("res://tests/boomerang_tier5_tests.gd").new()
		row.fingerprint.append(probe.auxiliary_snapshot(game))
	return row
