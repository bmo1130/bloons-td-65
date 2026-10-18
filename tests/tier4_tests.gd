extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const RED: BalloonDefinition = preload("res://data/balloons/red.tres")
const LEAD: BalloonDefinition = preload("res://data/balloons/lead.tres")
const BLACK: BalloonDefinition = preload("res://data/balloons/black.tres")
const BUILDS: Array = [[4, 2, 0], [4, 0, 2], [2, 4, 0], [0, 4, 2], [2, 0, 4], [0, 2, 4]]
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_purchases()
	_juggernaut()
	_bounces()
	_fan_club()
	_critical()
	var normal: Dictionary = _timed_combat(1, true)
	_check(normal == _timed_combat(2, true), "tier4 transformations/crit/bounces: 1x and 2x exact outcomes")
	var no_stats: Dictionary = _timed_combat(1, false)
	_check(normal.combat == no_stats.combat, "tier4 battle decisions independent of statistics toggle")
	_check(_timed_sharpshooter(1) == _timed_sharpshooter(2), "critical firing cadence and damage also match 1x/2x when targets survive ten volleys")
	print("V0.7 COMBAT: %s" % normal)
	print("V0.7 TIER4: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 100000
	game.economy.lives = 100000
	return game

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.7 FAIL: " + message)

func _tower(game: MainGame, build: Array, at: Vector2 = Vector2(250, 350), reverse: bool = false) -> TowerState:
	game.towers.add_tower(at, MainGame.DART)
	var tower: TowerState = game.towers.towers.back()
	var paths: Array = [2, 1, 0] if reverse else [0, 1, 2]
	for path: int in paths:
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, MainGame.DART.upgrade_at(path, tier))
	return tower

func _fingerprint(stats: TowerDefinition) -> Array:
	var values: Array = []
	for field in TowerStatResolver.FIELDS:
		values.append(stats.get(field))
	return values

func _purchases() -> void:
	for build: Array in BUILDS:
		var game: MainGame = _game()
		var before: int = game.economy.gold
		var a: TowerState = _tower(game, build)
		var spent: int = a.spent_on_upgrades
		_check(a.tiers == PackedInt32Array(build) and game.economy.gold == before - spent, "six tier4 crosspaths purchase and debit")
		var b: TowerState = _tower(game, build, Vector2(400, 400), true)
		_check(_fingerprint(a.stats) == _fingerprint(b.stats), "tier4 secondary-first purchase order independence")
		var main: int = build.find(4)
		var secondary: int = build.find(2)
		var gold: int = game.economy.gold
		_check(not game.try_upgrade(a, MainGame.DART.upgrade_at(secondary, 3)) and not game.try_upgrade(a, MainGame.DART.upgrade_at(main, 4)) and game.economy.gold == gold, "tier4 rejects second main and duplicate without debit")
		game.free()
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [3, 0, 0])
	game.economy.gold = 1799
	_check(not game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 4)) and tower.tiers[0] == 3 and game.economy.gold == 1799, "tier4 insufficient funds leaves state intact")
	game.economy.gold = 1800
	_check(game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 4)) and game.economy.gold == 0, "tier4 exact funds")
	_check(not UpgradePolicy.state_reason(PackedInt32Array([4, 3, 0])).is_empty() and not UpgradePolicy.state_reason(PackedInt32Array([4, 1, 1])).is_empty(), "invalid 430 and 411 rejected")
	_check(not game.try_upgrade(_tower(game, [0, 0, 0]), MainGame.DART.upgrade_at(2, 4)), "tier4 cannot skip prerequisites")
	_check(MainGame.DART.damage == 1 and MainGame.DART.fire_interval == 0.7 and MainGame.DART.upgrade_at(1, 2).multipliers.fire_interval == 0.8, "existing shared balance data immutable")
	game.free()

func _layers(count: int, ceramic: bool = false, fortified: bool = false) -> BalloonDefinition:
	var top: BalloonDefinition
	for index in range(count):
		var layer: BalloonDefinition = BalloonDefinition.new()
		layer.next_layer = top
		layer.speed = 0.0
		top = layer
	top.ceramic = ceramic
	top.fortified = fortified
	return top

func _at(game: MainGame, data: BalloonDefinition, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 500.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _juggernaut() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [4, 2, 0])
	_check(tower.stats.attack_attribute == AttackSpec.Attribute.NORMAL and tower.stats.pierce == 60 and is_equal_approx(tower.stats.fire_interval, 0.68), "juggernaut Normal/pierce and secondary fire rate")
	for data in [RED, BLACK, LEAD]:
		_check(game.combat.can_damage(data, AttackSpec.Attribute.NORMAL), "Normal bypasses existing Sharp/Explosive immunities centrally")
	var lead: BalloonState = _at(game, LEAD, Vector2(400, 400))
	var gold: int = game.economy.gold
	_check(game.combat.apply_hit(lead.id, tower.stats.make_attack()) == 1 and game.economy.gold == gold + 1, "Normal lead shell still stops residual damage at split and pays once")
	for flags: Array in [[false, false, 2], [true, false, 5], [false, true, 4], [true, true, 7]]:
		var target: BalloonState = _at(game, _layers(20, flags[0], flags[1]), Vector2(500, 400))
		gold = game.economy.gold
		_check(game.combat.apply_hit(target.id, tower.stats.make_attack()) == flags[2] and game.economy.gold == gold + flags[2], "classification bonus sums once at contact, exact removed-layer gold")
		_check(target.knockback_remaining > 0.0 and target.knockback_multiplier == (2.0 if flags[0] or flags[1] else 4.0), "heavy and light knockback classification")
	var b: TowerState = _tower(game, [4, 0, 2])
	_check(b.stats.knockback_light == 6.0 and b.stats.knockback_heavy == 3.0 and b.stats.attack_range == 200, "402 knockback interaction and preserved range crosspath")
	var moving: BalloonState = game.balloons.spawn(load("res://data/balloons/pink.tres"), 410.0)
	game.combat.apply_hit(moving.id, tower.stats.make_attack())
	var distance: float = moving.distance
	game.balloons.update(0.1)
	_check(moving.distance < distance and moving.position == game.route.position_at(moving.distance) and moving.motion_points.size() == 3, "knockback moves backwards through a route corner")
	game.free()
	game = _game()
	var dense: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, PackedInt32Array([4, 0, 0]))
	dense.projectile_speed = 600.0
	for index in range(70):
		_at(game, _layers(3), Vector2(200 + index * 5, 300))
	gold = game.economy.gold
	var shot: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, dense)
	game.projectiles.update(0.8)
	_check(shot.hit_ids.size() == 60 and shot.remaining_pierce == 0 and game.economy.gold == gold + 120, "large juggernaut projectile actually pierces sixty dense targets with exact two-layer rewards")
	game.free()

func _bounce_case(step: float) -> Dictionary:
	var game: MainGame = _game()
	game.projectiles.ricochet_bounds = Rect2(0, 0, 120, 100)
	var stats: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, PackedInt32Array([4, 0, 0]))
	stats.damage = 1
	stats.projectile_radius = 2.0
	stats.projectile_speed = 100.0
	stats.projectile_lifetime = 5.0
	stats.max_bounces = 2
	stats.knockback_duration = 0.0
	var balloon: BalloonState = _at(game, _layers(20), Vector2(80, 50))
	var shot: ProjectileState = game.projectiles.launch(Vector2(40, 50), Vector2.RIGHT, stats)
	for tick in range(roundi(1.5 / step)):
		game.projectiles.update(step)
	var report: Dictionary = {"remaining": balloon.definition.layer_count(), "pierce": shot.remaining_pierce, "bounces": shot.bounces}
	_check(report.remaining == 18 and report.pierce == 58 and report.bounces == 1, "one hit per segment; same live ID rehit only after boundary bounce")
	game.projectiles.update(20.0)
	_check(game.projectiles.projectiles.is_empty() and shot.bounces <= 2 and balloon.definition.layer_count() >= 17, "lifetime and bounce cap bound rehit even for huge delta")
	game.free()
	return report

func _bounces() -> void:
	_check(_bounce_case(1.5) == _bounce_case(MainGame.FIXED_STEP), "piecewise ricochet matches small steps for stationary target")
	var game: MainGame = _game()
	var stats: TowerDefinition = TowerStatResolver.resolve(MainGame.DART, PackedInt32Array([4, 0, 0]))
	stats.projectile_speed = 1200.0
	stats.damage = 1
	stats.knockback_duration = 0.0
	var target: BalloonState = _at(game, LEAD, Vector2(920, 204))
	var shot: ProjectileState = game.projectiles.launch(Vector2(860, 204), Vector2.RIGHT, stats)
	game.projectiles.update(0.4)
	_check(game.balloons.find(target.id) == null and shot.child_ids.size() == 2 and game.balloons.balloons.size() == 2, "bounce does not rehit split descendants in the same attack")
	game.free()

func _fan_club() -> void:
	var game: MainGame = _game()
	var caster: TowerState = _tower(game, [2, 4, 0], Vector2(300, 300))
	var second: TowerState = _tower(game, [0, 4, 2], Vector2(350, 300))
	for index in range(12):
		_tower(game, [0, 2, 0], Vector2(250, 300) if index == 0 else Vector2(400 + index * 20, 300))
	var catapult: TowerState = _tower(game, [3, 0, 0])
	var crossbow: TowerState = _tower(game, [0, 0, 3])
	game.towers.add_tower(Vector2(300, 320), MainGame.BOMB)
	var bomb: TowerState = game.towers.towers.back()
	var state: AbilityState = game.abilities.state_for(caster)
	_check(state != null and not game.abilities.activate(caster), "ability initially charges instead of firing on purchase")
	game.abilities.update(50.0 / 3.0)
	_check(game.abilities.activate(caster) and state.last_targets.size() == 10 and state.last_targets[0] == caster.id, "fanclub includes self and closest 9 eligible targets")
	_check(state.last_targets[1] == second.id and state.last_targets[2] == 3, "equal-distance eligible targets ordered by stable tower ID")
	_check(not state.last_targets.has(catapult.id) and not state.last_targets.has(crossbow.id) and not state.last_targets.has(bomb.id), "catapults crossbows bombs excluded")
	_check(caster.stats.projectile_count == 3 and caster.transformed_stats.projectile_count == 1 and caster.transformed_stats.pierce == 5 and is_equal_approx(caster.transformed_stats.fire_interval, 0.015), "transformation single high-speed dart, crosspath pierce, permanent triple remains")
	_check(second.transformed_stats.attack_range == 225.0 and is_equal_approx(second.transformed_stats.fire_interval, 0.015), "other club retains its own crosspaths under transformation")
	_check(not game.abilities.activate(caster) and state.cooldown_remaining == 50.0, "repeated activation blocked without resetting duration")
	game.abilities.update(5.0)
	_check(game.abilities.activate(second) and game.abilities.transformations.size() == 14 and game.abilities.transformations[caster.id].remaining == 15.0 and state.active_remaining == 10.0, "second club prioritizes untransformed and refreshes existing targets independently of caster duration")
	_check(is_equal_approx(caster.transformed_stats.fire_interval, 0.015) and caster.transformed_stats.pierce == 5, "overlapping clubs never multiply bonuses")
	var plain: TowerState = game.towers.towers[2]
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 1))
	_check(plain.transformed_stats.pierce == 3 and plain.stats.pierce == 3, "eligible purchase recomputes temporary stats from immutable permanent stats")
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 2))
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 3))
	_check(plain.transformed_stats == null and not game.abilities.transformations.has(plain.id), "upgrade to excluded tier cancels transformation safely")
	game.towers.remove_tower(caster)
	_check(not game.abilities.states.has(caster.id) and second.transformed_stats != null, "caster removal retains other independent timed effects")
	var removed_id: int = game.towers.towers[3].id
	game.towers.remove_tower(game.towers.towers[3])
	_check(not game.abilities.transformations.has(removed_id), "target removal releases timed effect by ID")
	game.abilities.update(15.0)
	_check(game.abilities.transformations.is_empty() and second.transformed_stats == null and second.stats.projectile_count == 3 and second.cooldown == second.stats.fire_interval, "expiry restores original triple and reload, no permanent stacks")
	game.abilities.update(35.0)
	_check(game.abilities.activate(second), "cooldown counted from activation and ready at 50 seconds")
	_check(MainGame.DART.projectile_count == 1 and MainGame.DART.fire_interval == 0.7 and MainGame.DART.upgrade_at(1, 4).ability.duration == 15.0, "transformations never mutate shared definitions")
	game._finish(false)
	_check(not game.abilities.activate(second), "abilities blocked after game end")
	game.free()
	game = _game()
	_check(game.abilities.states.is_empty() and game.abilities.transformations.is_empty(), "new run clears ability state and effects")
	caster = _tower(game, [0, 4, 0])
	_at(game, _layers(20), caster.position + Vector2(50, 0))
	game.abilities.update(17.0)
	game.abilities.activate(caster)
	for tick in range(60):
		game.towers.update(MainGame.FIXED_STEP)
	_check(caster.combat_stats.volleys == 66 and caster.combat_stats.projectiles == 66, "0.015s transformed interval supports more than one shot per fixed tick, no 60Hz cap")
	game.free()

func _critical() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 2, 4])
	var target: BalloonState = _at(game, _layers(120), Vector2(290, 350))
	_check(tower.critical_counter == 0 and tower.stats.damage == 6 and is_equal_approx(tower.stats.fire_interval, 0.475 * 0.85 * 0.8), "sharpshooter purchase resets crit sequence, secondary attack rate preserved")
	var shots: Array[ProjectileState] = []
	for volley in range(1, 22):
		tower.cooldown = 0.0
		game.towers.update(MainGame.FIXED_STEP)
		var shot: ProjectileState = game.projectiles.projectiles.back()
		shots.append(shot)
		_check(shot.attack.damage == (50 if volley % 10 == 0 else 6) and shot.attack.critical == (volley % 10 == 0), "critical is every 10th firing including missed/in-flight darts")
	_check(tower.combat_stats.volleys == 21 and tower.combat_stats.critical_volleys == 2, "critical statistics count volleys not hits")
	_check(shots[9].damage == 50 and shots[0].damage == 6, "later firing does not mutate existing attack snapshots")
	var lead: BalloonState = _at(game, LEAD, Vector2(500, 400))
	_check(game.combat.apply_hit(lead.id, shots[9].attack) == 0 and lead.definition == LEAD, "critical Sharp still cannot damage lead")
	var excluded: Dictionary = {}
	_check(game.combat.apply_hit(target.id, shots[9].attack, 1.0, excluded) == 50 and game.combat.apply_hit(target.id, shots[9].attack, 1.0, excluded) == 0, "critical multi-layer damage only once per projectile target")
	game.try_upgrade(tower, MainGame.DART.upgrade_at(0, 1)) # Third path, rejected.
	_check(tower.critical_counter == 21, "failed purchase preserves critical counter")
	target.position = tower.position + Vector2(22, 0)
	target.record_motion(PackedVector2Array([target.position, target.position]), 0.0)
	tower.cooldown = 0.0
	game.towers.update(MainGame.FIXED_STEP)
	_check(tower.critical_counter == 21 and tower.combat_stats.volleys == 21, "zero-length muzzle aim creates no volley and does not advance critical counter")
	var other: TowerState = _tower(game, [2, 0, 4], Vector2(500, 500))
	_check(other.critical_counter == 0 and tower.critical_counter == 21, "critical counters independent per instance")
	game.free()

func _timed_combat(speed: int, statistics: bool) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = statistics
	game.simulation_speed = speed
	var caster: TowerState = _tower(game, [2, 4, 0])
	_tower(game, [0, 2, 0], Vector2(250, 410))
	_tower(game, [4, 0, 2], Vector2(460, 450))
	_tower(game, [0, 2, 4], Vector2(672, 440))
	game.abilities.update(17.0)
	game.abilities.activate(caster)
	for index in range(80):
		game.balloons.spawn(load("res://data/balloons/pink.tres"), index * 12.0)
	for frame in range(30 * 60 / speed):
		game._process(MainGame.FIXED_STEP)
	var counters: Array = []
	for record: TowerCombatStats in game.battle_stats.records.values():
		counters.append([record.volleys, record.projectiles, record.pops(), record.critical_volleys])
	var report: Dictionary = {"combat": [game.economy.gold, game.economy.lives, game.balloons.balloons.size(), game.projectiles.projectiles.size(), game.abilities.transformations.size()], "counters": counters}
	game.free()
	return report

func _timed_sharpshooter(speed: int) -> Array:
	var game: MainGame = _game()
	game.simulation_speed = speed
	var tower: TowerState = _tower(game, [0, 2, 4])
	game.balloons.spawn(_layers(500), 500.0)
	for frame in range(30 * 60 / speed):
		game._process(MainGame.FIXED_STEP)
	var record: TowerCombatStats = tower.combat_stats
	_check(record.critical_volleys >= 3 and record.pops() > 0, "timed sharpshooter exercise includes multiple critical impacts")
	var result: Array = [record.volleys, record.critical_volleys, record.pops(), game.economy.gold, tower.critical_counter]
	game.free()
	return result
