extends "res://tests/boomerang_tests.gd"

const HIGH_BUILDS: Array = [[4,2,0],[4,0,2],[5,2,0],[5,0,2],[2,4,0],[0,4,2],[2,5,0],[0,5,2],[2,0,4],[0,2,4],[2,0,5],[0,2,5]]
var measurements: Array[Dictionary] = []

func run(window: Window) -> Dictionary:
	_root = window
	_catalog_high()
	_micro_high()
	_effect_boundaries()
	_orbit()
	_effects()
	_press()
	_press_rehit()
	_end_blast()
	_abilities_high()
	_chain_high()
	for build: Array in HIGH_BUILDS:
		var one: Dictionary = _battle_high(build, 1)
		_check(one == _battle_high(build, 2), "high tier exact fixed-step1x/2x " + str(build))
		_check(one.combat == _battle_high(build, 1, false).combat, "high tier statistics OFF preserves combat " + str(build))
		_check(one.damage > 0 and one.volleys > 0, "all12 purchased crosspaths cause real damage " + str(build))
		if build[0] >= 4:
			_check(one == _battle_high(build,1,true,0), "high tier live rehit eligibility matches uncached reference " + str(build))
		measurements.append({"build": build, "result": one})
	var file: FileAccess = FileAccess.open("res://benchmarks/boomerang-v014-crosspaths.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": measurements, "conditions": "Real purchases;one tower at250,350;120mixed moving blooms;12 game seconds;1x/2x identical fixed ticks;ability charged and activated;not campaign balance"}, "\t") + "\n")
	file.close()
	print("BOOMERANG TIER5 TESTS: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _catalog_high() -> void:
	var base: TowerDefinition = MainGame.BOOMERANG
	_check(base.upgrades.size() == 15, "exact15 upgrades with original9 unchanged")
	var floor_profile: TowerDefinition = TowerDefinition.new()
	floor_profile.fire_interval = 0.001
	_check(TowerStatResolver.resolve(floor_profile,PackedInt32Array([0,0,0])).fire_interval == 0.05 and TowerStatResolver.resolve(base,PackedInt32Array([0,5,0])).fire_interval == 0.03, "existing .05 floor preserved; only new Perma data permits .03")
	for path in range(3):
		for tier in [4,5]:
			var item: UpgradeDefinition = base.upgrade_at(path,tier)
			_check(item != null and item.cost == [[2000,32500],[4200,35000],[2700,50000]][path][tier-4] and item.reference_medium_cost == item.cost, "six declared Medium prices")
			_check(item.prerequisites == [base.upgrade_at(path,tier-1).id], "high tier data prerequisite")
	for build: Array in HIGH_BUILDS:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var spent: int = tower.spent_on_upgrades
		var reversed: TowerState = _tower(game,[0,0,0])
		# Tier5 same slot is intentionally occupied, compare synthesis before claim.
		var reverse_stats: TowerDefinition = TowerStatResolver.resolve(base,PackedInt32Array(build))
		_check(tower.tiers == PackedInt32Array(build) and _fields(tower.stats) == _fields(reverse_stats), "twelve purchased states equal canonical synthesis")
		var expected_cost: int = 0
		for path in range(3):
			for tier in range(1,build[path]+1):
				expected_cost += base.upgrade_at(path,tier).cost
		_check(spent == expected_cost, "exact total real purchase cost " + str(build))
		var main: int = UpgradePolicy.main_path(tower.tiers)
		var gold: int = game.economy.gold
		_check(not game.try_upgrade(tower,base.upgrade_at(main,tower.tiers[main])) and gold == game.economy.gold, "duplicate high tier transaction atomic")
		for path in range(3):
			if path != main:
				_check(not game.try_upgrade(tower,base.upgrade_at(path,3)), "second main forbidden")
		game.towers.remove_tower(tower)
		for path in [2,1,0]:
			for tier in range(1,build[path]+1):
				_check(game.try_upgrade(reversed,base.upgrade_at(path,tier)), "reverse order real purchase succeeds after release")
		_check(_fields(reversed.stats) == _fields(reverse_stats), "reverse purchase and repeated resolve never accumulates")
		game.free()
	for path in range(3):
		var game: MainGame = _game()
		var build: Array = [0,0,0]
		build[path] = 5
		var first: TowerState = _tower(game,build)
		build[path] = 4
		var second: TowerState = _tower(game,build)
		var gold: int = game.economy.gold
		_check(not game.try_upgrade(second,base.upgrade_at(path,5)) and second.tiers[path] == 4 and gold == game.economy.gold and game.towers.tier5_registry.owners(&"boomerang",path).size() == 1, "global same-path tier5 atomic failure")
		game.towers.remove_tower(first)
		_check(game.try_upgrade(second,base.upgrade_at(path,5)), "remove releases exact boomerang slot")
		game.free()
	var game: MainGame = _game()
	for build: Array in [[5,0,0],[0,5,0],[0,0,5]]:
		_check(_tower(game,build).tiers == PackedInt32Array(build), "three distinct tier5 paths coexist")
	game.free()
	game = _game()
	_check(game.towers.tier5_registry.owners(&"boomerang",0).is_empty() and MainGame.BOOMERANG.damage == 1, "fresh map clears slots and immutable base")
	game.free()

func _orbit() -> void:
	for build: Array in [[5,0,0],[5,0,2]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		tower.cooldown = 1000.0
		var target: BalloonState = _dummy(game,tower.position + Vector2(100,0))
		target.camo = true
		var hp: int = target.shell_hp
		for tick in range(60):
			game.towers.update(1.0/60)
			game.projectiles.update(1.0/60)
		_check(game.combat.area_events == 20 and hp-target.shell_hp == (80 if build[2] == 0 else 100), "three orbit visuals generate exactly20 radius events/second, own camo")
		_check(tower.combat_stats.volleys == 0 and tower.combat_stats.projectiles == 0 and tower.combat_stats.area_events == 20, "area events are not primary volleys/projectiles")
		_check(game.combat.effects.is_empty() and game.projectiles.pending_areas.is_empty(), "continuous aura adds no exploding visual/projectile accumulation")
		var aura: TowerDefinition = tower.stats.aura_profile as TowerDefinition
		_check(is_equal_approx(aura.explosion_radius,140.625 if build[2] == 0 else 187.03125) and aura.detects_camo and not tower.stats.detects_camo, "orbit radius and own detection stay independent")
		for kind in ["black","white","lead","ddt"]:
			var balloon: BalloonState = _at(game,kind,tower.position + Vector2(80,0))
			_check(game.combat.can_attack(balloon,aura.attack_attribute,aura.detects_camo) == (build[2] == 2 or kind in ["black","white"]), "orbit current attribute " + kind)
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[5,0,2])
	var aura: TowerDefinition = tower.stats.aura_profile as TowerDefinition
	for index in range(205):
		_dummy(game,tower.position + Vector2(index%10,index/10))
	_check(game.combat.explode(tower.position,aura.make_attack(),1,2147483647,null,false).size() == 200, "orbit pierce200 independent of visualcount")
	game.free()

func _effects() -> void:
	var game: MainGame = _game()
	# Explicit effect-ownership fixture only; ordinary global capacity remains1.
	game.towers.tier5_registry.limits = {&"boomerang": {0:2}}
	var first: TowerState = _tower(game,[5,0,2])
	var second: TowerState = _tower(game,[5,0,2])
	var target: BalloonState = _dummy(game,Vector2(320,350))
	target.definition.moab_class = true
	target.definition.status_immunity_mask = 127
	var hit: AttackSpec = first.stats.make_attack()
	hit.source_id = first.id
	_check(game.combat.apply_hit(target.id,hit) == 7 and game.combat.damage_effects[target.id].size() == 1, "valid MOAB hit adds Shred even when all controls immune")
	var hp: int = target.shell_hp
	game.projectiles.update(0.999)
	_check(target.shell_hp == hp, "Shred not before1s")
	game.projectiles.update(0.001)
	_check(target.shell_hp == hp-100 and first.combat_stats.dot_ticks == 1, "Shred tick100 at exact1s to first owner")
	var refresh: AttackSpec = first.stats.make_attack()
	refresh.source_id = second.id
	game.combat.apply_hit(target.id,refresh)
	var effect: Dictionary = game.combat.damage_effects[target.id][&"shred"]
	_check(effect.attack.source_id == first.id and effect.expires == 11.0 and effect.next == 2.0, "nonstack refresh preserves first owner and tick phase")
	game.towers.remove_tower(first)
	game.projectiles.update(1.0)
	_check(first.combat_stats.dot_ticks == 2 and second.combat_stats.dot_ticks == 0, "DOT attribution survives owner removal")
	target.camo = true
	hp = target.shell_hp
	game.projectiles.update(1.0)
	_check(target.shell_hp == hp, "Shred rechecks current camo each tick")
	target.camo = false
	target.definition.immunity_mask = 1 << AttackSpec.Attribute.NORMAL
	game.projectiles.update(1.0)
	_check(target.shell_hp == hp, "Shred rechecks current attribute immunity")
	target.definition.immunity_mask = 0
	var layer: BalloonDefinition = BalloonDefinition.new()
	layer.shell_hp = 10000
	target.set_layer(layer)
	game.projectiles.update(1.0)
	_check(target.shell_hp == 10000 and game.combat.damage_effects.is_empty(), "shell transition clears effects without child inheritance")
	var burn: AttackSpec = (load("res://data/attacks/domination_blast.tres") as TowerDefinition).make_attack()
	burn.source_id = second.id
	game.combat.apply_hit(target.id,burn)
	game.combat.apply_hit(target.id,burn)
	hp = target.shell_hp
	game.projectiles.update(4.0)
	_check(target.shell_hp == hp-200 and second.combat_stats.dot_ticks == 4 and game.combat.damage_effects.is_empty(), "burn50/sec4s nonstack and exact cleanup")
	# New effects created in a long projectile batch also insert their later ticks.
	var shot_profile: TowerDefinition = TowerDefinition.new()
	shot_profile.projectile_speed = 100.0
	shot_profile.projectile_lifetime = 5.0
	shot_profile.damage_over_time = load("res://data/effects/burn.tres")
	var shot: ProjectileState = game.projectiles.launch(target.position-Vector2(20,0),Vector2.RIGHT,shot_profile,second.id)
	hp = target.shell_hp
	game.projectiles.update(2.5)
	_check(target.shell_hp == hp-101 and shot.remaining_pierce == 1, "mid-batch DOT scheduling respects actual contact time and two later ticks")
	game.free()

func _press() -> void:
	for build: Array in [[0,0,4],[2,0,4],[0,2,4],[0,0,5],[2,0,5],[0,2,5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var special: TowerDefinition = tower.stats.secondary_attack as TowerDefinition
		_check(special != null and special.fire_interval == (6.0 if build==[0,2,4] else (3.0 if build==[0,2,5] else (10.0 if build[2]==4 else 5.0))), "independent special reload not ordinary modifier")
		_check(special.pierce == (420 if build==[2,0,4] else (520 if build==[2,0,5] else (200 if build[2]==4 else 300))), "special crosspath capacity")
		for kind in ["moab","bfb","zomg","ddt","bad"]:
			var balloon: BalloonState = _at(game,kind,Vector2(300,350))
			balloon.remove_camo()
			var hit: AttackSpec = special.make_attack()
			hit.source_id = tower.id
			for index in range(3):
				game.combat.apply_hit(balloon.id,hit)
			_check(is_equal_approx(balloon.pending_press,0.0 if kind=="bad" else special.press_distance*balloon.definition.press_multiplier*3.0), "three additive Press contacts and resistance " + kind)
			_check(balloon.stun_remaining == (0.25 if build[2]==5 and kind!="bad" else 0.0), "stun independent of BAD damage immunity")
			_check(game.combat.can_target(balloon,special) == (kind!="bad" or build[2]==5), "Press excludes BAD; Domination damages BAD")
			balloon.camo = true
			_check(not game.combat.can_target(balloon,special), "no hidden special camo detection")
			balloon.camo = false
			balloon.pending_push = 20.0
			balloon.pending_press += 1000.0
		game.balloons.update(0.0,true)
		_check(game.balloons.balloons.all(func(b: BalloonState)->bool: return b.distance == 0.0 and b.pending_press == 0.0 and b.pending_push == 0.0), "Crush max + additive Press applied once and clamp to route start")
		game.free()

func _end_blast() -> void:
	for build: Array in [[0,0,5],[2,0,5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var special: TowerDefinition = tower.stats.secondary_attack as TowerDefinition
		var blast: TowerDefinition = special.end_explosion as TowerDefinition
		_check(blast.damage == 100 and blast.pierce == (50 if build[0]==2 else 40) and blast.explosion_radius == (351.5625 if build[0]==2 else 234.375), "205 own radius/pierce data")
		var at: Vector2 = Vector2(100,350)
		var target: BalloonState = _dummy(game,at+Vector2(special.flight_distance,0))
		var shot: ProjectileState = game.projectiles.launch(at,Vector2.RIGHT,special,tower.id)
		game.projectiles.update(1.0)
		_check(shot.end_emitted and game.combat.area_events == 1 and game.projectiles.projectiles.is_empty(), "Domination reaches end -> exactly one blast, no lingering projectile")
		_check(target.shell_hp == 9900 and game.combat.damage_effects[target.id].has(&"burn"), "special excludes ordinary physical target but endpoint blast damages and burns")
		game.projectiles.update(5.0)
		_check(game.combat.area_events == 1 and target.shell_hp == 9700 and game.combat.damage_effects.is_empty(), "no repeat blast and burn expires")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,5])
	var special: TowerDefinition = (tower.stats.secondary_attack as TowerDefinition).duplicate(true)
	special.pierce = 1
	var balloon: BalloonState = _dummy(game,Vector2(300,350))
	balloon.definition.moab_class = true
	game.projectiles.launch(Vector2(250,350),Vector2.RIGHT,special,tower.id)
	game.projectiles.update(2)
	_check(game.combat.area_events == 1 and balloon.shell_hp <= 9875, "pierce exhaustion detonates once, intentional direct plus blast")
	game.free()

func _abilities_high() -> void:
	for build: Array in [[0,4,0],[0,4,2],[2,4,0],[0,5,0],[0,5,2],[2,5,0]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var permanent: Array = _fields(tower.stats)
		var state: AbilityState = game.abilities.state_for(tower)
		_check(state != null and state.cooldown_remaining == 15.0 and not game.abilities.activate(tower), "real purchase preserves tier4 initial15s through tier5 upgrade")
		game.abilities.update(state.cooldown_remaining)
		_check(game.abilities.activate(tower) and not game.abilities.activate(tower), "self buff activates without target and cannot repeat")
		_check(tower.combat_definition().damage == (tower.stats.damage + (1 if build[1]==4 else 10)) and tower.combat_definition().fire_interval == 0.03, "Turbo / latest Perma additive damage and exactly.03 without double speed")
		_check(_fields(tower.stats) == permanent and state.last_targets == PackedInt64Array([tower.id]), "self buff never changes shared permanent/other towers")
		var duration: float = state.active_remaining
		game.abilities.update(duration)
		_check(tower.transformed_stats == null and _fields(tower.combat_definition()) == permanent and is_equal_approx(state.cooldown_remaining,state.definition.cooldown-duration), "expiration restores permanent and simulation cooldown")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,4,2])
	var state: AbilityState = game.abilities.state_for(tower)
	state.cooldown_remaining = 0
	game.abilities.activate(tower)
	game.abilities.update(2)
	tower.cooldown = 0.02
	_check(game.try_upgrade(tower,MainGame.BOOMERANG.upgrade_at(1,5)) and game.abilities.state_for(tower)==state and state.active_remaining==8 and state.cooldown_remaining==40 and tower.combat_definition().damage==18, "active040->050 preserves ID,state,time,clamps cooldown and upgrades snapshot")
	_check(is_equal_approx(tower.cooldown,0.02), "active upgrade preserves effective reload phase exactly once")
	game.towers.remove_tower(tower)
	_check(game.abilities.states.is_empty() and tower.transformed_stats==null, "remove clears self ability and transformation")
	game.free()
	for statistics in [true,false]:
		game = _game()
		game.battle_stats.enabled = statistics
		tower = _tower(game,[0,5,2])
		_dummy(game,Vector2(300,350))
		game.towers.update(1.0)
		_check(tower.attack_counter==34 and game.projectiles.projectiles.size()==34, ".03 reload emits34 fractional independent shots over half-open1s, statistics="+str(statistics))
		var fractions: Dictionary = {}
		for shot in game.projectiles.projectiles:
			fractions[shot.spawn_fraction] = true
		_check(fractions.size()==34 and game.projectiles.projectiles[0].hit_ids != {1:true}, "highspeed no frame cap/shared hit history")
		game.free()

func _chain_high() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[4,2,0])
	for index in range(65):
		_dummy(game,Vector2(300+index*2,350))
	var shot: ProjectileState = game.projectiles.fire(Vector2(250,350),game.balloons.balloons[0],tower.stats,tower.id)
	game.projectiles.update(1.0)
	_check(shot.hit_ids.size()==60 and shot.remaining_pierce==0 and tower.combat_stats.targets_damaged==60, "MOAR physically hits60 unique IDs and ends")
	game.free()
	game = _game()
	tower = _tower(game,[5,0,2])
	var a: BalloonState = _dummy(game,Vector2(300,350))
	var b: BalloonState = _dummy(game,Vector2(1000,350))
	var profile: TowerDefinition = tower.stats.duplicate()
	profile.projectile_speed = 600.0
	shot = game.projectiles.fire(Vector2(250,350),a,profile,tower.id)
	game.projectiles.update(4.0)
	_check(tower.combat_stats.targets_damaged>=3 and shot.hit_times.size()==2, "Lord physically revisits after >=.6s instead of permanent-ID exclusion")
	_check(shot.can_rehit(a.id,float(shot.hit_times[a.id])+0.6) and not shot.can_rehit(a.id,float(shot.hit_times[a.id])+0.599), "Lord exact.6 rehit boundary")
	game.free()

func _battle_high(build: Array, speed: int, statistics: bool = true, search_mode: int = 3) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = statistics
	game.projectiles.chain_cache_mode = search_mode
	var tower: TowerState = _tower(game,build)
	for index in range(120):
		game.balloons.spawn(load("res://data/balloons/%s.tres" % ["green","ceramic","moab","bfb","lead","ddt"][index%6]),420+index*3,false,index%4==0,true)
	var state: AbilityState = game.abilities.state_for(tower)
	if state != null:
		state.cooldown_remaining = 0.0
		game.abilities.activate(tower)
	for frame in range(720/speed):
		for step in range(speed):
			game.simulation_step(1.0/60)
	var result: Dictionary = snapshot_high(game,tower)
	game.free()
	return result

func snapshot_high(game: MainGame, tower: TowerState) -> Dictionary:
	var live: Array = []
	for b in game.balloons.balloons:
		live.append([b.id,b.definition.id,b.shell_hp,b.distance,b.stun_remaining,b.pending_press])
	live.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
	var result: Dictionary = {"combat":[game.economy.gold,game.economy.lives,live,tower.attack_counter,game.balloons.latest_id(),auxiliary_snapshot(game)],"damage":tower.combat_stats.effective_damage,"volleys":tower.combat_stats.volleys,"cost":tower.spent_on_upgrades+315,"secondary":tower.combat_stats.secondary_projectiles,"areas":tower.combat_stats.area_events,"ticks":tower.combat_stats.dot_ticks}
	return result

func _micro_high() -> void:
	var expected: Array = [[1,60,.225,0,1],[2,60,.4,0,1],[6,60,.225,0,10],[7,60,.4,0,12],[1,13,.15,1,0],[2,4,.15,1,0],[4,13,.03,2,0],[8,4,.03,2,0],[2,27,1.2,0,0],[2,18,.675,0,0],[12,81,.6,0,0],[12,54,.3375,0,0]]
	for index in range(HIGH_BUILDS.size()):
		var build: Array = HIGH_BUILDS[index]
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var row: Array = expected[index]
		_check(tower.stats.damage==row[0] and tower.stats.pierce==row[1] and is_equal_approx(tower.stats.fire_interval,row[2]), "independent adopted12 crosspath main damage/pierce/reload expectations")
		for moab in [false,true]:
			var balloon: BalloonState = _dummy(game,Vector2(300,350))
			balloon.definition.moab_class = moab
			balloon.definition.ceramic = not moab
			var hit: AttackSpec = tower.stats.make_attack()
			hit.source_id = tower.id
			var hp: int = balloon.shell_hp
			var damage: int = game.combat.apply_hit(balloon.id,hit)
			_check(damage==row[0]+(row[3] if moab else row[4]) and hp-balloon.shell_hp==damage, "actual ceramic/MOAB contact bonus once " + str(build))
			_check(tower.combat_stats.pops()==0, "HP-only high tier damage awards no Pops/gold")
		game.free()
	_check((load("res://data/attacks/domination_blast.tres") as TowerDefinition).pierce==40 and (load("res://data/attacks/domination_blast.tres") as TowerDefinition).explosion_radius==234.375, "205 never mutates shared external blast Resource")
	var state: AbilityState = AbilityState.new(load("res://data/abilities/boomerang_5.tres"))
	_check(state.cooldown_remaining==10.0, "Perma initial profile10s, actual040 purchase wait is preserved separately")

func _effect_boundaries() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[5,0,2])
	var a: BalloonState = _dummy(game,Vector2(300,350))
	var b: BalloonState = _dummy(game,Vector2(400,350))
	a.definition.moab_class = true
	b.definition.moab_class = true
	game.projectiles.fire(Vector2(250,350),a,tower.stats,tower.id)
	game.projectiles.update(.4)
	_check(game.combat.damage_effects.has(a.id) and not game.combat.damage_effects.has(b.id), "one Lord projectile Shreds its first surviving MOAB only")
	var burn: AttackSpec = (load("res://data/attacks/domination_blast.tres") as TowerDefinition).make_attack()
	burn.source_id = tower.id
	game.combat.apply_hit(a.id,burn)
	_check(game.combat.damage_effects[a.id].size()==2, "Shred and burn are independent families on same outer shell")
	var hp: int = a.shell_hp
	game.projectiles.update(1.0)
	_check(a.shell_hp==hp-150, "coexisting Shred100 and burn50 both damage once")
	game.balloons._remove(a.array_index)
	game.projectiles.update(1.0)
	_check(not game.combat.damage_effects.has(a.id), "explicit target deletion drops all shell effect references")
	var moab: BalloonState = _at(game,"moab",Vector2(350,350),true)
	var hit: AttackSpec = tower.stats.make_attack()
	hit.source_id = tower.id
	game.combat.apply_hit(moab.id,hit)
	moab.shell_hp = 50
	var gold: int = game.economy.gold
	var pops: int = tower.combat_stats.pops()
	game.projectiles.update(1.0)
	_check(game.balloons.find(moab.id)==null and not game.combat.damage_effects.has(moab.id), "Shred destroys fortified outer shell and cleans first source")
	_check(game.balloons.balloons.filter(func(target: BalloonState)->bool:return target.definition.ceramic and target.fortified).size()==4 and tower.combat_stats.pops()==pops+1 and game.economy.gold==gold+1, "one outer Pop/reward, four fortified children, no repeated DoT inheritance")
	game.free()
	game = _game()
	tower = _tower(game,[0,0,4])
	var _normal: BalloonState = _dummy(game,Vector2(300,350))
	game.towers.update(0.1)
	_check(game.projectiles.projectiles.size()>0 and tower.secondary_cooldown==0.0, "ordinary Kylie fires at normal while MOAB special stays ready")
	var moab_target: BalloonState = _dummy(game,Vector2(320,350))
	moab_target.definition.moab_class = true
	game.balloons._spatial_dirty = true
	var primary: float = tower.cooldown
	game.towers.update(0.1)
	_check(game.projectiles.projectiles.any(func(shot:ProjectileState)->bool:return shot.attack.moab_only) and tower.cooldown<primary and tower.secondary_cooldown>9, "special fires during independent ordinary reload")
	tower.secondary_cooldown = 8.0
	game.try_upgrade(tower,MainGame.BOOMERANG.upgrade_at(2,5))
	_check(is_equal_approx(tower.secondary_cooldown,4.0), "004 to005 preserves independent secondary reload progress instead of resetting or inheriting10s")
	game.free()

func auxiliary_snapshot(game: MainGame) -> Array:
	var statuses: Array = []
	for balloon in game.balloons.balloons:
		statuses.append([balloon.id,balloon.shell_generation,balloon.camo,balloon.fortified,balloon.knockback_remaining,balloon.knockback_multiplier,balloon.stun_remaining,balloon.pending_push,balloon.pending_press])
	statuses.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
	var effects: Array = []
	var ids: Array = game.combat.damage_effects.keys()
	ids.sort()
	for id: int in ids:
		var families: Array = game.combat.damage_effects[id].keys()
		families.sort()
		for family: StringName in families:
			var effect: Dictionary = game.combat.damage_effects[id][family]
			effects.append([id,family,effect.shell.id,effect.generation,effect.next,effect.expires,effect.interval,effect.attack.damage,effect.attack.source_id,effect.attack.attribute,effect.attack.detects_camo])
	var towers: Array = []
	for tower in game.towers.towers:
		towers.append([tower.id,tower.cooldown,tower.secondary_cooldown,tower.aura_cooldown,tower.attack_counter])
	var abilities: Array = []
	ids = game.abilities.states.keys()
	ids.sort()
	for id: int in ids:
		var state: AbilityState = game.abilities.states[id]
		abilities.append([id,state.definition.id,state.cooldown_remaining,state.active_remaining])
	var flights: Array = []
	for shot in game.projectiles.projectiles:
		var hit_ids: Array = shot.hit_ids.keys()
		hit_ids.sort()
		var children: Array = shot.child_ids.keys()
		children.sort()
		flights.append([shot.id,shot.position.x,shot.position.y,shot.direction.x,shot.direction.y,shot.speed,shot.attack.damage,shot.attack.source_id,shot.attack.attribute,shot.remaining_pierce,shot.lifetime,shot.age,hit_ids,children,shot.hit_times,shot.attack.dot_consumed,shot.end_emitted])
	return [game.combat.effect_clock,statuses,effects,towers,abilities,flights]

func _press_rehit() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,4])
	var profile: TowerDefinition = (tower.stats.secondary_attack as TowerDefinition).duplicate()
	profile.projectile_speed = 1.0
	var target: BalloonState = _dummy(game,Vector2(250,350),500.0)
	target.definition.moab_class = true
	var shot: ProjectileState = game.projectiles.launch(target.position,Vector2.RIGHT,profile,tower.id)
	game.projectiles.update(0.099999)
	_check(target.shell_hp==9995 and is_equal_approx(target.pending_press,9.375), "physical special does not rehit before.1s")
	game.projectiles.update(0.200002)
	_check(target.shell_hp==9980 and shot.remaining_pierce==196 and is_equal_approx(target.pending_press,37.5) and float(shot.hit_times[target.id])>=0.3, "physical special schedules four.1s contacts and additive Press in long step")
	game.free()
