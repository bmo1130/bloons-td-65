extends "res://tests/boomerang_tests.gd"

const TACK: TowerDefinition = preload("res://data/towers/tack.tres")
const FROZEN: BalloonDefinition = preload("res://tests/fixtures/frozen_immunity.tres")
const EXPECTED: Array = [[2,4,8,0.63,31,540,2],[2,1,12,0.63,23,360,2],[1,8,8,0.63,46,540,5],[1,8,12,1.12,46,540,5],[1,2,16,0.63,23,360,0],[1,5,16,1.12,31,540,0]]

func _tower(game: MainGame, build: Array, reverse: bool = false) -> TowerState:
	game.towers.add_tower(Vector2(300,290), TACK)
	var tower: TowerState = game.towers.towers.back()
	for path in ([2,1,0] if reverse else [0,1,2]):
		for tier in range(1,build[path]+1):
			_check(game.try_upgrade(tower,TACK.upgrade_at(path,tier)), "real tack purchase "+str(build))
	return tower

func run(window: Window) -> Dictionary:
	_root = window
	_catalog_tack()
	_radial()
	_contacts()
	_damage_types()
	_reload_lifecycle()
	_range_and_mixed()
	var rows: Array = []
	for build: Array in BUILDS:
		var row: Dictionary = battle(build,1)
		_check(row == battle(build,2), "equal20game seconds exact1x/2x "+str(build))
		_check(row.combat == battle(build,1,false).combat, "statisticsOFF preserves full combat "+str(build))
		_check(row.damage > 0 and row.volleys > 0, "crosspath actually damages "+str(build))
		rows.append(row)
	var file: FileAccess = FileAccess.open("res://benchmarks/tack-v015-crosspaths.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seconds":20,"fixture":"one tower300,290;50mixed balloons distance450+3i;camo/fortified;no maintenance;1x/2x/statsOFF exact", "rows":rows},"\t")+"\n")
	file.close()
	print("TACK TESTS: %d checks, %d failures"%[_checks,_failures])
	return {"checks":_checks,"failures":_failures}

func _catalog_tack() -> void:
	_check(MainGame.TOWER_CATALOG == [MainGame.DART,MainGame.BOMB,MainGame.BOOMERANG,TACK], "exact fourth catalog entry preserves prefix")
	_check(TACK.id == &"tack" and TACK.shortcut == "R" and TACK.cost == 260 and TACK.upgrades.size() == 9, "base price/hotkey/nine upgrades")
	_check(TACK.damage == 1 and TACK.pierce == 1 and TACK.projectile_count == 8 and TACK.fire_interval == 1.12 and TACK.attack_range == 23*4.6875 and not TACK.detects_camo, "independent base values")
	var original: Array = _fields(TACK)
	var costs: Array = [[150,300,600],[100,225,550],[110,110,450]]
	var refs: Array = [[150,220,600],[100,225,550],[150,150,450]]
	for item in TACK.upgrades:
		_check(item.cost == costs[item.path][item.tier-1] and item.reference_medium_cost == refs[item.path][item.tier-1], "adopted cost vs official56 reference")
		_check(item.prerequisites == ([] if item.tier == 1 else [TACK.upgrade_at(item.path,item.tier-1).id]), "sequential data prerequisite")
	for path in range(3):
		_check(TACK.max_upgrade_tier(path) == 3 and TACK.upgrade_at(path,4) == null, "no tack4/5 content")
	var legal: int = 0
	for a in range(4):
		for b in range(4):
			for c in range(4):
				var build: Array = [a,b,c]
				if not UpgradePolicy.state_reason(PackedInt32Array(build)).is_empty():
					continue
				legal += 1
				var game: MainGame = _game()
				var tower: TowerState = _tower(game,build)
				var reverse: TowerState = _tower(game,build,true)
				_check(tower.tiers == PackedInt32Array(build) and _fields(tower.stats) == _fields(reverse.stats), "34states order independent")
				var cost: int = 0
				for item in TowerStatResolver.acquired(TACK,tower.tiers):
					cost += item.cost
				_check(tower.spent_on_upgrades == cost and tower.combat_stats.invested_gold == 260+cost and game.economy.gold == 1000000-2*cost, "34state exact gold/statistics")
				for path in range(3):
					var next: UpgradeDefinition = TACK.upgrade_at(path,build[path]+1)
					if next != null and UpgradePolicy.state_reason(PackedInt32Array([a+int(path==0),b+int(path==1),c+int(path==2)])).is_empty():
						var preview: TowerDefinition = TowerStatResolver.preview(TACK,tower.tiers,next)
						var tiers: PackedInt32Array = tower.tiers.duplicate()
						tiers[path] += 1
						_check(_fields(preview) == _fields(TowerStatResolver.resolve(TACK,tiers)), "all legal next previews exact resolver")
				_check(_fields(TACK) == original and _fields(tower.stats) == _fields(TowerStatResolver.resolve(TACK,tower.tiers)), "immutable base and no repeated modifiers")
				game.free()
	_check(legal == 34, "exact34legal states")
	for index in range(BUILDS.size()):
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,BUILDS[index])
		var s: TowerDefinition = tower.stats
		var e: Array = EXPECTED[index]
		_check(s.damage == e[0] and s.pierce == e[1] and s.projectile_count == e[2] and s.projectile_speed == e[5] and s.attack_attribute == e[6], "six independent damage/pierce/count/speed/type expectations")
		_check(is_equal_approx(s.fire_interval,e[3]) and s.attack_range == e[4]*4.6875 and is_equal_approx(s.projectile_lifetime*s.projectile_speed,s.attack_range), "six independent interval/range/travel")
		var gold: int = game.economy.gold
		for path in range(3):
			var item: UpgradeDefinition = TACK.upgrade_at(path,3 if tower.tiers[path] > 0 else 1)
			_check(not game.try_upgrade(tower,item) and game.economy.gold == gold and tower.tiers == PackedInt32Array(BUILDS[index]), "duplicate/secondmain/thirdpath atomic rejection")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[2,2,0])
	_check(UpgradePolicy.main_path(tower.tiers) == -1 and game.try_upgrade(tower,TACK.upgrade_at(1,3)), "220 remains undecided until actual3")
	tower = _tower(game,[0,0,0])
	game.economy.gold = 149
	_check(not game.try_upgrade(tower,TACK.upgrade_at(0,1)) and game.economy.gold == 149 and tower.tiers == PackedInt32Array([0,0,0]), "insufficient funds atomic")
	game.economy.gold = 150
	var preview: TowerDefinition = TowerStatResolver.preview(TACK,tower.tiers,TACK.upgrade_at(0,1))
	_check(game.try_upgrade(tower,TACK.upgrade_at(0,1)) and game.economy.gold == 0 and _fields(tower.stats) == _fields(preview), "exact funds purchase equals preview")
	game.free()

func _radial() -> void:
	for build: Array in [[0,0,0],[0,0,1],[0,0,2],[0,0,3],[0,3,2]]:
		for mode in range(4):
			var game: MainGame = _game()
			var tower: TowerState = _tower(game,build)
			tower.target_mode = mode as TowerState.TargetMode
			tower.direction = Vector2(0.2,0.8)
			var direction: Vector2 = tower.direction
			_dummy(game,tower.position+Vector2(40,33))
			game.towers.update(MainGame.FIXED_STEP)
			var shots: Array[ProjectileState] = game.projectiles.projectiles
			_check(shots.size() == tower.stats.projectile_count and tower.combat_stats.volleys == 1 and tower.combat_stats.projectiles == shots.size(), "counted once as volley andNreal projectiles")
			_check(tower.direction == direction, "target mode never rotates tower")
			for index in range(shots.size()):
				var shot: ProjectileState = shots[index]
				_check(shot.id == index+1 and shot.direction.is_equal_approx(Vector2.from_angle(TAU*index/shots.size())) and shot.position == tower.position and shot.target_id == -1, "uniqueID fixed world angles and actual center origin")
				_check(shot.remaining_pierce == tower.stats.pierce and shot.attack.source_id == tower.id and shot.spawn_fraction == 0.0, "independent full pierce owner and initial birth time")
			if shots.size()>1:
				shots[0].hit_ids[99] = true
				_check(not shots[1].hit_ids.has(99), "no shared hit dictionary")
			game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,0])
	game.towers.update(10.0)
	_check(game.projectiles.projectiles.is_empty() and tower.cooldown == 0.0, "idle no volley debt")
	_at(game,"lead",tower.position+Vector2(50,0))
	_at(game,"red",tower.position+Vector2(45,0),false,true)
	game.towers.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.is_empty(), "immune lead and camo alone never activate")
	_at(game,"red",tower.position+Vector2(0,80))
	game.towers.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.size() == 8 and tower.attack_counter == 1, "attackable in range activates ready radial volley")
	game.free()
	game = _game()
	tower = _tower(game,[0,0,0])
	_at(game,"moab",tower.position+Vector2(tower.stats.attack_range+20,0))
	game.towers.update(MainGame.FIXED_STEP)
	_check(game.projectiles.projectiles.size() == 8, "common blimp circular boundary extends activation")
	game.free()

func _contacts() -> void:
	for build: Array in [[0,0,0],[3,0,0],[0,3,0],[0,0,3]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var target: BalloonState = _dummy(game,tower.position,20)
		game.projectiles.fire_volley(tower.position,null,tower.stats,tower.id)
		game.projectiles.update(0.01)
		_check(target.shell_hp == 10000-tower.stats.damage*tower.stats.projectile_count, "different real tacks may hit overlapping target once each")
		game.projectiles.update(0.01)
		_check(target.shell_hp == 10000-tower.stats.damage*tower.stats.projectile_count, "sameID never rehit by same projectile")
		for tick in range(60):
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(game.projectiles.projectiles.is_empty(), "all tacks and blades expire without residue")
		game.free()
	for p in [1,4,8]:
		var game: MainGame = _game()
		var stats: TowerDefinition = TowerStatResolver.resolve(TACK,PackedInt32Array([0,0,0]))
		stats.pierce = p
		stats.projectile_speed = 10000
		stats.projectile_lifetime = 1.0
		var targets: Array[BalloonState] = []
		for index in range(10):
			targets.append(_dummy(game,Vector2(330+index*10,290),1))
		var shot: ProjectileState = game.projectiles.launch(Vector2(300,290),Vector2.RIGHT,stats)
		game.projectiles.update(0.02)
		for index in range(10):
			_check(targets[index].shell_hp == 10000-int(index<p), "continuous fast collision and chronological nearest pierce")
		_check(shot.remaining_pierce == 0 and game.projectiles.projectiles.is_empty(), "per projectile pierce consumed exactly")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,0])
	var off_axis: BalloonState = _dummy(game,tower.position+Vector2.from_angle(PI/8)*90,1)
	game.projectiles.fire_volley(tower.position,null,tower.stats,tower.id)
	game.projectiles.update(1.0)
	_check(off_axis.shell_hp == 10000, "radial activation is not AoE or homing; gaps remain")
	var crossing: BalloonState = _dummy(game,Vector2(350,310),1)
	crossing.record_motion(PackedVector2Array([Vector2(350,270),Vector2(350,310)]),0.0)
	var fast: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	fast.projectile_speed = 100
	fast.projectile_lifetime = 2
	game.projectiles.launch(Vector2(300,290),Vector2.RIGHT,fast)
	game.projectiles.update(1.0)
	_check(crossing.shell_hp == 9999, "relative moving-circle continuous crossing")
	game.free()

func _damage_types() -> void:
	for build: Array in [[0,0,0],[3,0,0],[0,3,0],[0,0,3]]+BUILDS:
		for kind in ["black","white","lead","ceramic","moab","bfb","zomg","ddt","bad"]:
			var game: MainGame = _game()
			var tower: TowerState = _tower(game,build)
			var target: BalloonState = _at(game,kind,tower.position+Vector2(50,0),true)
			var attack: AttackSpec = tower.stats.make_attack()
			attack.source_id = tower.id
			var can_hit: bool = kind != "ddt" and (kind != "lead" or build[0] == 3)
			var hp: int = target.shell_hp
			var gold: int = game.economy.gold
			var dealt: int = game.combat.apply_hit(target.id,attack)
			_check((dealt>0) == can_hit, "independent immunity/camo predicate "+str(build)+kind)
			if kind in ["ceramic","moab","bfb","zomg","bad"]:
				_check(target.shell_hp == hp-tower.stats.damage and tower.combat_stats.effective_damage == tower.stats.damage and tower.combat_stats.pops() == 0 and game.economy.gold == gold, "fortified HP-only contact:no bonuses/rewards/Pops")
			game.free()
	var game: MainGame = _game()
	var stats: TowerDefinition = TowerStatResolver.resolve(TACK,PackedInt32Array([0,3,0]))
	var frozen: BalloonState = game.balloons.spawn(FROZEN,500)
	_check(not game.combat.can_attack(frozen,AttackSpec.Attribute.SHARP,false) and game.combat.apply_hit(frozen.id,stats.make_attack()) == 1, "Shatter damages frozen-immunity fixture;Sharp does not")
	var ddt: BalloonState = _at(game,"ddt",Vector2(350,290))
	var hot: AttackSpec = TowerStatResolver.resolve(TACK,PackedInt32Array([3,0,0])).make_attack()
	_check(game.combat.apply_hit(ddt.id,hot) == 0, "Normal without detection cannot damage DDT")
	hot.detects_camo = true
	_check(game.combat.apply_hit(ddt.id,hot) == 2, "explicit detection plusNormal hitsDDT")
	var blade: AttackSpec = stats.make_attack()
	blade.detects_camo = true
	_check(game.combat.apply_hit(ddt.id,blade) == 0, "detection cannot replace Shatter lead immunity")
	var balloon: BalloonState = _at(game,"moab",Vector2(350,290),true)
	balloon.shell_hp = 1
	var tower: TowerState = _tower(game,[3,2,0])
	var gold: int = game.economy.gold
	var pops: int = game.battle_stats.total_pops
	game.projectiles.launch(Vector2(300,290),Vector2.RIGHT,tower.stats,tower.id)
	game.projectiles.update(0.2)
	_check(game.balloons.find(balloon.id) == null and game.battle_stats.total_pops == pops+1 and game.economy.gold == gold+1, "MOAB shell removal counts exactly one reward/Pop")
	var ceramics: Array[BalloonState] = game.balloons.balloons.filter(func(b: BalloonState)->bool:return b.definition.id == &"ceramic")
	_check(ceramics.size() == 4 and ceramics.all(func(b: BalloonState)->bool:return b.fortified and b.shell_hp == b.shell_max_hp), "same projectile excludes newborn fortified four ceramics")
	game.free()

func _reload_lifecycle() -> void:
	for build: Array in [[0,0,0],[2,0,0],[0,0,3]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		_dummy(game,tower.position+Vector2(50,0))
		for tick in range(600):
			game.towers.update(MainGame.FIXED_STEP)
			game.projectiles.update(MainGame.FIXED_STEP)
		_check(tower.attack_counter == int(ceil(10.0/tower.stats.fire_interval)), "half-open reload10game seconds;Sprayer no hidden speedup")
		_check(game.projectiles.projectiles.size() <= tower.stats.projectile_count*2, "steady live projectile bound")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game,[0,0,0])
	var target: BalloonState = _dummy(game,tower.position+Vector2(50,0))
	game.projectiles.fire_volley(tower.position,null,tower.stats,tower.id)
	var shot: ProjectileState = game.projectiles.projectiles[0]
	for tier in range(1,4):
		game.try_upgrade(tower,TACK.upgrade_at(0,tier))
	game.towers.remove_tower(tower)
	game.projectiles.update(0.2)
	_check(shot.damage == 1 and shot.initial_pierce == 1 and shot.speed == 360 and shot.attack.attribute == AttackSpec.Attribute.SHARP and target.shell_hp == 9999, "launched immutable snapshot survives upgrade/removal")
	_check(tower.combat_stats.effective_damage == 1 and game.towers.towers.is_empty(), "removed tower retains confirmed owner statistics")
	game.projectiles.update(2)
	_check(game.projectiles.projectiles.is_empty(), "removed tower leaves no leaked projectiles")
	game.free()



func _range_and_mixed() -> void:
	for build: Array in [[0,0,0],[0,1,0],[0,2,0],[0,3,0]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,build)
		var s: TowerDefinition = tower.stats
		var shot: ProjectileState = game.projectiles.launch(tower.position,Vector2.RIGHT,s)
		game.projectiles.update(2.0)
		_check(is_equal_approx(shot.position.x-tower.position.x,s.attack_range) and game.projectiles.projectiles.is_empty(), "finite lifetime actual center travel follows upgraded range/speed")
		game.free()
	for blade in [false,true]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game,[0,3,0] if blade else [0,0,0])
		var near_line: BalloonState = _dummy(game,tower.position+Vector2(50,12),1)
		game.projectiles.launch(tower.position,Vector2.RIGHT,tower.stats)
		game.projectiles.update(0.2)
		_check(near_line.shell_hp == (9999 if blade else 10000), "blade actual wider circle differs from basic tack;visual rotation does not supply damage")
		game.free()
	var mixed: Dictionary = mixed_battle(1)
	_check(mixed == mixed_battle(2), "four tower mixed same20game seconds full1x/2x fingerprint")
	_check(mixed.combat == mixed_battle(1,false).combat, "four tower mixed statsOFF full fingerprint")

func mixed_battle(speed: int, statistics: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = statistics
	_tower(game,[0,2,3])
	var catalog: Array[TowerDefinition] = [MainGame.DART,MainGame.BOMB,MainGame.BOOMERANG]
	for index in range(3):
		game.towers.add_tower(Vector2(250+index*150,350),catalog[index])
		var tower: TowerState = game.towers.towers.back()
		var build: Array = [[2,3,0],[2,0,3],[3,2,0]][index]
		for path in range(3):
			for tier in range(1,build[path]+1):
				_check(game.try_upgrade(tower,catalog[index].upgrade_at(path,tier)), "mixed all real purchases")
	for index in range(120):
		game.balloons.spawn(load("res://data/balloons/%s.tres"%["ceramic","lead","moab","black","green"][index%5]),450.0+index*2.0,index%11==0,index%3==0,true)
	game.simulation_speed = speed
	for frame in range(1200/speed):
		game._process(MainGame.FIXED_STEP)
	var live: Array = []
	for b in game.balloons.balloons:
		live.append([b.id,b.definition.id,b.shell_hp,b.distance,b.camo,b.fortified])
	live.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
	var flights: Array = []
	for shot in game.projectiles.projectiles:
		flights.append([shot.id,shot.position,shot.remaining_pierce,shot.age,shot.hit_ids.duplicate(),shot.hit_times.duplicate()])
	var towers: Array = []
	for tower in game.towers.towers:
		towers.append([tower.id,tower.attack_counter,tower.cooldown])
	var result: Dictionary = {"combat":[live,flights,towers,game.economy.gold,game.economy.lives,game.projectiles._next_id],"pops":game.battle_stats.total_pops}
	game.free()
	return result
