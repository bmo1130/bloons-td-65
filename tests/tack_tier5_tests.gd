extends "res://tests/tack_tests.gd"

const HIGH: Array = [[4,2,0],[4,0,2],[2,4,0],[0,4,2],[2,0,4],[0,2,4],[5,2,0],[5,0,2],[2,5,0],[0,5,2],[2,0,5],[0,2,5]]
const HIGH_EXPECTED: Array = [[5,45,1,.315,31,6,0,5135],[7,30,1,.315,23,6,0,5030],[2,8,8,.63,46,5,0,4285],[2,8,12,1.12,46,5,0,4055],[1,2,16,.21,23,0,0,4580],[1,5,16,1.12/3,31,0,0,4455],[8,60,1,.1,43,6,4,50635],[10,45,1,.1,35,6,4,50530],[5,8,8,.63,46,2,0,19285],[5,8,12,1.12,46,2,0,19055],[1,2,32,.126,30,0,1,24580],[1,10,32,.224,50,0,1,24455]]

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("TACK TIER5 FAIL: "+message)

func run(window: Window) -> Dictionary:
	_root = window
	_high_catalog()
	_fire()
	_meteors()
	_maelstrom()
	_zone()
	_high_attributes()
	_new_boundaries()
	var rows: Array = []
	for build: Array in HIGH:
		var one: Dictionary = high_battle(build,1)
		_check(one == high_battle(build,2), "12crosspaths exact8game seconds1x/2x "+str(build))
		_check(one.combat == high_battle(build,1,false).combat, "12crosspaths optional statisticsOFF exact combat "+str(build))
		_check(one == high_battle(build,1,true,false), "12crosspaths conservative blade AABB ON/OFF full combat and statistics "+str(build))
		_check(one.damage > 0 and one.volleys > 0, "12crosspaths actual confirmed damage "+str(build))
		rows.append(one)
	var file: FileAccess = FileAccess.open("res://benchmarks/tack-v016-crosspaths.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seconds":8,"fixture":"50mixed bloons distance450+3i;camo/fortified;base injected,real upgrade transactions;one ready ability at0;no maintenance", "rows":rows},"\t")+"\n")
	file.close()
	print("TACK TIER5 TESTS: %d checks, %d failures"%[_checks,_failures])
	return {"checks":_checks,"failures":_failures}

func _signature(s: TowerDefinition) -> Array:
	var extra: Array = [_fields(s),s.attack_pattern]
	if s.aura_profile != null:
		var a: TowerDefinition = s.aura_profile as TowerDefinition
		extra.append([a.damage,a.pierce,a.explosion_radius,a.fire_interval,a.attack_attribute,a.moab_bonus])
	if s.secondary_attack != null:
		var a: TowerDefinition = s.secondary_attack as TowerDefinition
		var blast: TowerDefinition = a.end_explosion as TowerDefinition
		extra.append([a.damage,a.pierce,a.fire_interval,a.attack_attribute,a.detects_camo,a.projectile_speed,blast.damage,blast.pierce,blast.explosion_radius,blast.damage_over_time.family])
	if s.ability != null:
		var a: AbilityDefinition = s.ability
		extra.append([a.id,a.duration,a.cooldown,a.initial_cooldown,a.attack_interval,a.rotation_turns_per_second,_fields(a.attack_profile)])
	return extra

func _high_catalog() -> void:
	var count: int = 0
	for definition in MainGame.TOWER_CATALOG:
		count += definition.upgrades.size()
	_check(count == 60 and TACK.upgrades.size() == 15, "exact4x15=60catalog and15tack upgrades")
	for path in range(3):
		for tier in [4,5]:
			var item: UpgradeDefinition = TACK.upgrade_at(path,tier)
			_check(item.cost == [[3500,45500],[2700,15000],[3200,20000]][path][tier-4] and item.cost == item.reference_medium_cost, "six exact reference/adopted Medium costs")
			_check(item.prerequisites == [TACK.upgrade_at(path,tier-1).id], "six sequential prerequisites")
	for i in range(HIGH.size()):
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,HIGH[i])
		var other: MainGame = _game()
		var reverse: TowerState = _tower(other,HIGH[i],true)
		var s: TowerDefinition = tower.stats
		var e: Array = HIGH_EXPECTED[i]
		_check(tower.tiers == PackedInt32Array(HIGH[i]) and _signature(s) == _signature(reverse.stats), "12purchase orders equivalent including cloned attacks/abilities")
		_check(s.damage == e[0] and s.pierce == e[1] and s.projectile_count == e[2] and is_equal_approx(s.fire_interval,e[3]), "12independent damage/pierce/count/reload values")
		_check(s.attack_range == e[4]*4.6875 and s.attack_attribute == e[5] and s.moab_bonus == e[6] and tower.combat_stats.invested_gold == e[7], "12independent range/type/bonus/totalcost")
		var gold: int = game.economy.gold
		var stable: Array = _signature(s)
		var main: int = UpgradePolicy.main_path(tower.tiers)
		var secondary: int = Array(tower.tiers).find(2)
		_check(not game.try_upgrade(tower,TACK.upgrade_at(secondary,3)) and not game.try_upgrade(tower,TACK.upgrade_at(3-main-secondary,1)) and game.economy.gold == gold and _signature(tower.stats) == stable, "thirdpath and secondmain rejection atomic")
		if tower.tiers[main] == 4:
			var preview: TowerDefinition = TowerStatResolver.preview(TACK,tower.tiers,TACK.upgrade_at(main,5))
			_check(game.try_upgrade(tower,TACK.upgrade_at(main,5)) and _signature(tower.stats) == _signature(preview), "all6 tier4 to5 purchases exactly match full preview")
		game.free()
		other.free()
	var game: MainGame = _game()
	var first: TowerState = _tower(game,[5,2,0])
	var second: TowerState = _tower(game,[4,0,2])
	var gold: int = game.economy.gold
	_check(not game.try_upgrade(second,TACK.upgrade_at(0,5)) and game.economy.gold == gold and second.tiers[0] == 4, "samekind/path5global reservation and failed gold/state")
	_tower(game,[0,5,2])
	_tower(game,[0,2,5])
	_check(game.towers.tier5_registry.can_claim(&"tack",0,first.id), "own slot plus other two tier5 paths coexist")
	game.towers.remove_tower(first)
	_check(game.try_upgrade(second,TACK.upgrade_at(0,5)), "removal releases exact kind/path slot")
	game.free()
	game = _game()
	first = _tower(game,[0,0,3])
	game.economy.gold = 3199
	var before: TowerDefinition = first.stats
	_check(not game.try_upgrade(first,TACK.upgrade_at(2,4)) and game.economy.gold == 3199 and first.stats == before, "failed tier4 keeps funds and profile identity")
	game.free()
	var area: TowerDefinition = load("res://data/attacks/tack_ring.tres")
	var meteor: TowerDefinition = load("res://data/attacks/inferno_meteor.tres")
	var ability: AbilityDefinition = load("res://data/abilities/tack_5.tres")
	_check(area.damage == 5 and area.pierce == 30 and meteor.damage == 700 and meteor.pierce == 1 and ability.duration == 9 and ability.attack_interval == .045 and ability.attack_profile.pierce == 300, "no shared aura/meteor/ability Resource contamination")

func _fire() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[4,0,0])
	var a: BalloonState = _dummy(game,tower.position+Vector2(50,0))
	var b: BalloonState = _dummy(game,tower.position+Vector2(0,50))
	var outside: BalloonState = _dummy(game,tower.position+Vector2(130,0),1)
	tower.direction = Vector2(0.6,0.2)
	game.towers.update(.01)
	game.projectiles.update(.01)
	_check(a.shell_hp == 9995 and b.shell_hp == 9995 and outside.shell_hp == 10000, "one real circular fire pulse hits multiple inside,none outside")
	_check(game.projectiles.instances_created == 0 and game.projectiles.projectiles.is_empty() and tower.attack_counter == 1 and tower.combat_stats.volleys == 1 and game.combat.area_events == 1, "Ring replaces normal radial tacks;single area event not8ghostattacks")
	_check(tower.direction == Vector2(0.6,0.2) and game.combat.effects.is_empty(), "fixed orientation and persistent drawing without effect buildup")
	game.free()
	game = _game()
	tower = _tower(game,[4,0,0])
	var targets: Array[BalloonState] = []
	for i in range(35):
		targets.append(_dummy(game,tower.position+Vector2(50,0),1))
	game.towers.update(.01)
	game.projectiles.update(.01)
	for i in range(35):
		_check(targets[i].shell_hp == (9995 if i<30 else 10000), "range damage exact30budget/IDtie;one hit per pulse")
	game.free()
	game = _game()
	tower = _tower(game,[4,0,2])
	a = _dummy(game,tower.position+Vector2(50,0))
	for tick in range(600):
		game.towers.update(MainGame.FIXED_STEP)
		game.projectiles.update(MainGame.FIXED_STEP)
	_check(tower.attack_counter == 32 and a.shell_hp == 10000-32*7, "40210seconds exact32pulses,downcross increasesdamage not attackcount")
	game.free()

func _meteors() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[5,0,0])
	var target: BalloonState = _dummy(game,tower.position+Vector2(500,0))
	game.towers.update(.01)
	_check(game.projectiles.projectiles.size() == 1 and game.projectiles.projectiles[0].target_id == target.id and tower.attack_counter == 0, "meteor acquires valid target beyond flame independently")
	var shot: ProjectileState = game.projectiles.projectiles[0]
	_check(shot.damage == 700 and shot.attack.moab_bonus == 0 and shot.remaining_pierce == 1 and shot.lifetime == 25, "meteor separate direct700/no inherited+4/pierce/lifetime")
	game.projectiles.update(1.0)
	_check(target.shell_hp == 9250 and shot.end_emitted and game.projectiles.projectiles.is_empty(), "real homing contact700 plus exactly one50blast")
	_check(game.combat.damage_effects[target.id][&"inferno_burn"].attack.attribute == AttackSpec.Attribute.FIRE, "meteor explosionExplosive and independent burnFire types")
	game.towers.remove_tower(tower)
	game.projectiles.update(4.0)
	_check(target.shell_hp == 9050 and tower.combat_stats.effective_damage == 950 and game.combat.damage_effects.is_empty(), "four50burnticks retain removed owner and expire")
	game.free()
	game = _game()
	tower = _tower(game,[5,2,0])
	var a: BalloonState = _dummy(game,tower.position+Vector2(300,0))
	var b: BalloonState = _dummy(game,tower.position+Vector2(350,0))
	game.towers.update(.01)
	game.projectiles.update(1)
	_check(a.shell_hp == 9250 and b.shell_hp == 9250 and game.combat.area_events == 1, "520two direct hits then one independent explosion,not one per pierce")
	_check(game.projectiles.projectiles.is_empty(), "520 extra pierce chain stops and cleans up")
	game.free()
	game = _game()
	tower = _tower(game,[5,0,2])
	target = _dummy(game,tower.position+Vector2(300,0))
	game.towers.update(.01)
	_check(game.projectiles.projectiles[0].damage == 1000 and (tower.stats.secondary_attack as TowerDefinition).pierce == 1, "502only explicit meteor+300,independent from ring10")
	game.projectiles.update(1)
	_check(target.shell_hp == 8950, "5021000contact+50blast")
	game.free()
	game = _game()
	tower = _tower(game,[5,2,0])
	target = _dummy(game,tower.position+Vector2(400,0))
	game.towers.update(.01)
	game.balloons._remove(target.array_index)
	game.projectiles.update(.01)
	_check(game.projectiles.projectiles.is_empty(), "lost meteor target/no new valid target safely terminates")
	game.free()

func _maelstrom() -> void:
	for build: Array in [[0,4,0],[2,4,0],[0,4,2],[0,5,0],[2,5,0],[0,5,2]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var state: AbilityState = game.abilities.state_for(tower)
		_check(state != null and is_equal_approx(state.cooldown_remaining,20.0/3.0) and not game.abilities.activate(tower), "all6active profiles obey initial wait")
		state.cooldown_remaining = 0
		_check(game.abilities.activate(tower) and not game.abilities.activate(tower), "one activation,active reactivation rejected")
		game.abilities.update(.01)
		var n: int = 2 if build[1] == 4 else 4
		_check(game.projectiles.projectiles.size() == n and state.bursts_emitted == 1 and is_equal_approx(state.cooldown_remaining,19.99), "active firsthalfopen volley real2/4 independentblades")
		for i in range(n):
			var shot: ProjectileState = game.projectiles.projectiles[i]
			_check(shot.id == i+1 and shot.direction.is_equal_approx(Vector2.from_angle(TAU*i/n)) and shot.attack.source_id == tower.id, "ability exact initial directions/IDs/owner")
			_check(shot.damage == 2 and shot.initial_pierce == (100 if build[1]==4 else 300) and shot.attack.attribute == AttackSpec.Attribute.SHATTER and shot.attack.ceramic_bonus == (0 if build[1]==4 else 8), "ability independent2damage/pierce/type/ceramic,no maininheritance")
		var expected: int = int(ceil(state.definition.duration/state.definition.attack_interval-0.0000001))
		var duration: float = state.definition.duration
		for step in range(int(ceil((duration-.01)*60))):
			game.abilities.update(minf(MainGame.FIXED_STEP,maxf(0.0,duration-state.active_elapsed)))
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(state.bursts_emitted == expected and state.active_remaining < .000001, "finite ability exactceil(duration/interval)bursts,exclusive end")
		_check(tower.attack_counter == 0 and tower.combat_stats.volleys == expected and tower.combat_stats.secondary_projectiles == expected*n and tower.combat_stats.area_events == 0 and tower.combat_stats.dot_ticks == 0, "ability bursts/blades/primary/area/DoT statistics remain distinct")
		for step in range(181):
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(game.projectiles.projectiles.is_empty(), "all emitted blades expire after active duration")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,4,2])
	var state: AbilityState = game.abilities.state_for(tower)
	state.cooldown_remaining = 0
	game.abilities.activate(tower)
	game.abilities.update(1.0)
	game.projectiles.update(1.0) # Same simulation window as the ability births.
	var old_phase: float = state.burst_phase
	var old_clock: float = state.burst_cooldown
	var old_count: int = state.bursts_emitted
	var old_shot: ProjectileState = game.projectiles.projectiles[0]
	_check(game.try_upgrade(tower,TACK.upgrade_at(1,5)), "active042to052purchase")
	_check(is_equal_approx(state.active_remaining,11.0) and is_equal_approx(state.cooldown_remaining,19.0) and state.active_elapsed == 1.0 and state.bursts_emitted == old_count, "upgrade12minus1used time,notreset/duplicateability")
	_check(state.burst_phase == old_phase and state.burst_cooldown == old_clock and old_shot.initial_pierce == 100 and old_shot.attack.ceramic_bonus == 0, "phase/reload and already launched tier4 snapshot preserved")
	game.abilities.update(.05)
	game.projectiles.update(.05)
	_check(game.projectiles.projectiles.back().initial_pierce == 300 and game.projectiles.projectiles.back().attack.ceramic_bonus == 8, "onlyfuture volleys use upgraded abilityprofile")
	game.developer_mode = true
	game.experiment_paused = true
	var frozen: Array = [state.active_remaining,state.cooldown_remaining,state.burst_phase,game.projectiles._next_id]
	game.simulation_step(5)
	_check(frozen == [state.active_remaining,state.cooldown_remaining,state.burst_phase,game.projectiles._next_id], "pause freezes ability clock/emission/phase")
	game.towers.remove_tower(tower)
	_check(game.abilities.state_for(tower) == null and not game.abilities.activate(tower), "removed tower loses ability state/button source")
	game.projectiles.update(4)
	_check(game.projectiles.projectiles.is_empty(), "removed caster leaves only finite existing shots")
	game.free()

func _zone() -> void:
	for build: Array in [[0,0,4],[2,0,4],[0,0,5],[2,0,5],[0,2,5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var target: BalloonState = _dummy(game,tower.position+Vector2(50,0))
		for step in range(600):
			game.towers.update(MainGame.FIXED_STEP)
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(tower.attack_counter == int(ceil(10.0/tower.stats.fire_interval)), "highspeed radial exact10second volleys,no missed fastreload "+str(build))
		_check(target.shell_hp < 10000 and game.projectiles.projectiles.size() <= tower.stats.projectile_count*2, "live projectile count bounded bylife andinterval")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,5])
	var moab: BalloonState = _at(game,"bad",tower.position)
	var hp: int = moab.shell_hp
	game.towers.update(.01)
	_check(game.projectiles.projectiles.size() == 32, "Zone creates32real IDs,not AoE")
	for i in range(32):
		_check(game.projectiles.projectiles[i].direction.is_equal_approx(Vector2.from_angle(TAU*i/32)), "all32world directions match ports")
	game.projectiles.update(.01)
	_check(moab.shell_hp == hp-64 and tower.combat_stats.moab_damage == 64, "one large blimp can take32independent2damage contacts")
	game.projectiles.update(.01)
	_check(moab.shell_hp == hp-64, "same tack never re-hits same blimp")
	game.free()

func _high_attributes() -> void:
	for build: Array in HIGH:
		for kind in ["black","white","lead","ceramic","moab","bfb","zomg","ddt","bad"]:
			var game: MainGame = _game()
			var tower: TowerState = _tower(game,build)
			var target: BalloonState = _at(game,kind,tower.position+Vector2(50,0),true)
			var attack: AttackSpec = tower.stats.make_attack()
			attack.source_id = tower.id
			var expected: bool = kind != "ddt" and (kind != "lead" or build[0]>=4 or build[1]==5)
			var hp: int = target.shell_hp
			var gold: int = game.economy.gold
			var dealt: int = game.combat.apply_hit(target.id,attack)
			_check((dealt>0) == expected, "12crosspath type/camo immunity "+str(build)+kind)
			if kind in ["ceramic","moab","bfb","zomg","bad"]:
				var amount: int = tower.stats.damage + (tower.stats.ceramic_bonus if kind=="ceramic" else tower.stats.moab_bonus)
				_check(dealt == amount and target.shell_hp == hp-amount and tower.combat_stats.pops() == 0 and game.economy.gold == gold, "fortified shell confirmedHPonly,exactfirst bonus,no Pops/reward")
			game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[5,0,0])
	_at(game,"ddt",tower.position+Vector2(50,0))
	game.towers.update(.1)
	_check(game.projectiles.projectiles.is_empty() and game.projectiles.pending_areas.is_empty(), "Inferno no innate camo;DDT alone activates neither attack")
	var bad: BalloonState = _at(game,"bad",tower.position+Vector2(400,0))
	var hp: int = bad.shell_hp
	game.towers.update(.01)
	game.projectiles.update(1)
	game.projectiles.update(4)
	_check(bad.shell_hp == hp-950 and bad.stun_remaining == 0 and bad.pending_push == 0, "BAD accepts meteor/blast/burn damage independent ofcontrolimmunity")
	game.free()

func high_battle(build: Array,speed: int,statistics: bool = true,filtered: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = statistics
	game.projectiles.flight_broadphase_enabled = filtered
	var tower: TowerState = _tower(game,build)
	var state: AbilityState = game.abilities.state_for(tower)
	if state != null:
		state.cooldown_remaining = 0
		_check(game.abilities.activate(tower), "actual ready ability activation in crosspath battle")
	for i in range(50):
		game.balloons.spawn(load("res://data/balloons/%s.tres"%["green","lead","ceramic","moab","black"][i%5]),450.0+i*3.0,i%9==0,i%3==0,true)
	game.simulation_speed = speed
	for frame in range(480/speed):
		game._process(MainGame.FIXED_STEP)
	var live: Array = []
	for b in game.balloons.balloons:
		live.append([b.id,b.definition.id,b.shell_hp,b.distance,b.camo,b.fortified])
	live.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
	var status: Array = []
	if state != null:
		status = [state.definition.id,state.cooldown_remaining,state.active_remaining,state.active_elapsed,state.burst_cooldown,state.burst_phase,state.bursts_emitted]
	var auxiliary: Array = load("res://tests/boomerang_tier5_tests.gd").new().auxiliary_snapshot(game)
	var result: Dictionary = {"build":build,"combat":[live,game.economy.gold,game.economy.lives,game.projectiles._next_id,tower.attack_counter,status,auxiliary],"damage":tower.combat_stats.effective_damage,"pops":game.battle_stats.total_pops,"volleys":tower.combat_stats.volleys,"invested":tower.combat_stats.invested_gold}
	game.free()
	return result

func _new_boundaries() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[5,0,2])
	var moab: BalloonState = _at(game,"moab",tower.position+Vector2(400,0),true)
	moab.shell_hp = 1
	var gold: int = game.economy.gold
	var pops: int = game.battle_stats.total_pops
	game.towers.update(.01)
	game.projectiles.update(1.0)
	var children: Array[BalloonState] = game.balloons.balloons.filter(func(b:BalloonState)->bool:return b.definition.ceramic)
	_check(game.balloons.find(moab.id) == null and children.size() == 4, "real1000meteor breaks MOAB shell into exactly4ceramics")
	_check(game.economy.gold == gold+1 and game.battle_stats.total_pops == pops+1, "meteor overkill counts only removed shell,not child tree")
	_check(children.all(func(b:BalloonState)->bool:return b.fortified and b.shell_hp == b.shell_max_hp) and game.combat.damage_effects.is_empty(), "samebatch meteor explosion/burn cannot rehit newborn children")
	game.free()
	game = _game()
	tower = _tower(game,[4,0,0])
	tower.cooldown = .1575
	_check(game.try_upgrade(tower,TACK.upgrade_at(0,5)) and is_equal_approx(tower.cooldown,.05), "400to500 preserves50percentprimary reload,no free pulse")
	var data: BalloonDefinition = BalloonDefinition.new()
	data.immunity_mask = 1 << AttackSpec.Attribute.FIRE
	_check(not game.combat.can_damage(data,AttackSpec.Attribute.FIRE) and game.combat.can_damage(data,AttackSpec.Attribute.NORMAL) and game.combat.can_damage(data,AttackSpec.Attribute.SHARP), "generic fire immunity is separate;testtrait only,no new catalog bloon")
	game.free()
	game = _game()
	tower = _tower(game,[2,0,4])
	var target: BalloonState = _dummy(game,tower.position+Vector2(50,0))
	game.towers.update(.01)
	game.projectiles.update(.01)
	var shot: ProjectileState = game.projectiles.projectiles.back()
	var remaining: int = game.projectiles.projectiles.size()
	var hp: int = target.shell_hp
	_check(game.try_upgrade(tower,TACK.upgrade_at(2,5)) and game.projectiles.projectiles.size() == remaining and shot.speed == 360 and shot.initial_pierce == 2 and shot.attack.moab_bonus == 0, "active204to205onlyfuture32shotprofile;old16retain speed/pierce/bonus")
	game.towers.remove_tower(tower)
	game.projectiles.update(1)
	_check(game.projectiles.projectiles.is_empty() and target.shell_hp <= hp and tower.combat_stats.effective_damage > 0, "removed Zone upgrade keeps finite old projectiles and damage owner")
	game.free()
