extends RefCounted

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const PMFC: AbilityDefinition = preload("res://data/abilities/plasma_fan_club.tres")
var _root: Window
var _checks: int = 0
var _failures: int = 0

func run(window: Window) -> Dictionary:
	_root = window
	_registry()
	_ultra()
	_plasma()
	_crossbow()
	_cache()
	var normal: Dictionary = _battle(1, true)
	_check(normal == _battle(2, true), "tier5 child emissions and mixed ability battle exact 1x/2x outcomes")
	_check(normal.combat == _battle(1, false).combat, "statistics do not affect tier5 combat")
	_check(normal == _battle(1, true, false), "UI batching and preview caching do not affect tier5 combat or any counter")
	print("V0.8 BATTLE: %s" % normal)
	print("V0.8 TIER5: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("V0.8 FAIL: " + message)

func _game() -> MainGame:
	var game: MainGame = MAIN.instantiate() as MainGame
	_root.add_child(game)
	game.set_process(false)
	game.economy.gold = 1000000
	game.economy.lives = 1000000
	return game

func _tower(game: MainGame, build: Array, at: Vector2 = Vector2(250, 350), reverse: bool = false, definition: TowerDefinition = null) -> TowerState:
	var data: TowerDefinition = MainGame.DART if definition == null else definition
	game.towers.add_tower(at, data)
	var tower: TowerState = game.towers.towers.back()
	var paths: Array = [2, 1, 0] if reverse else [0, 1, 2]
	for path: int in paths:
		for tier in range(1, build[path] + 1):
			game.try_upgrade(tower, data.upgrade_at(path, tier))
	return tower

func _layers(count: int) -> BalloonDefinition:
	var top: BalloonDefinition
	for index in range(count):
		var layer: BalloonDefinition = BalloonDefinition.new()
		layer.next_layer = top
		layer.speed = 0.0
		top = layer
	return top

func _at(game: MainGame, data: BalloonDefinition, at: Vector2) -> BalloonState:
	var balloon: BalloonState = game.balloons.spawn(data, 500.0)
	balloon.position = at
	balloon.record_motion(PackedVector2Array([at, at]), 0.0)
	return balloon

func _stats(data: TowerDefinition) -> Array:
	var values: Array = []
	for field in TowerStatResolver.FIELDS:
		values.append(data.get(field))
	return values

func _registry() -> void:
	for build: Array in [[5, 2, 0], [5, 0, 2], [2, 5, 0], [0, 5, 2], [2, 0, 5], [0, 2, 5]]:
		var game: MainGame = _game()
		var a: TowerState = _tower(game, build)
		var b: TowerState = _tower(game, [mini(build[0], 4), mini(build[1], 4), mini(build[2], 4)], Vector2(400, 400), true)
		var path: int = build.find(5)
		var item: UpgradeDefinition = MainGame.DART.upgrade_at(path, 5)
		_check(a.tiers == PackedInt32Array(build) and a.spent_on_upgrades >= item.cost and a.combat_stats.invested_gold == 65 + a.spent_on_upgrades, "all six tier5 crosspaths buy and track exact investment")
		var gold: int = game.economy.gold
		var before: TowerDefinition = b.stats
		_check(game.upgrades.error_for(b, item).contains("5티어 사용 중") and not game.try_upgrade(b, item) and b.stats == before and game.economy.gold == gold, "same main tier5 slot blocks other crosspath without spending or stats changes")
		var resolved: Array = _stats(a.stats)
		game.towers.remove_tower(a)
		_check(game.try_upgrade(b, item) and _stats(b.stats) == resolved and game.economy.gold == gold - item.cost, "remove releases slot and secondary-first purchase resolves identically")
		_check(not game.try_upgrade(b, item) and not game.try_upgrade(b, MainGame.DART.upgrade_at(build.find(2), 3)), "duplicate and second-main tier3 blocked after tier5")
		game.free()
	var game: MainGame = _game()
	for build in [[5, 0, 0], [0, 5, 0], [0, 0, 5]]:
		var tower: TowerState = _tower(game, build)
		_check(tower.tiers == PackedInt32Array(build), "three different tier5 paths coexist")
	var another: TowerDefinition = MainGame.DART.duplicate() as TowerDefinition
	another.id = &"another_kind"
	_check(_tower(game, [5, 0, 0], Vector2.ZERO, false, another).tiers[0] == 5, "registry keyed by tower kind, reusable beyond dart")
	game.towers.tier5_registry.limits[&"dart"] = {0: 2}
	_check(_tower(game, [5, 0, 0]).tiers[0] == 5 and _tower(game, [5, 0, 0]).tiers[0] == 4, "policy capacity can be two without hardcoded monkey knowledge")
	_check(not UpgradePolicy.state_reason(PackedInt32Array([5, 3, 0])).is_empty() and not UpgradePolicy.state_reason(PackedInt32Array([5, 1, 1])).is_empty(), "illegal crosspaths remain blocked")
	game.free()
	game = _game()
	var a: TowerState = _tower(game, [4, 0, 0])
	var b: TowerState = _tower(game, [4, 0, 0])
	var item: UpgradeDefinition = MainGame.DART.upgrade_at(0, 5)
	game.economy.gold = item.cost - 1
	_check(not game.try_upgrade(a, item) and game.towers.tier5_registry.owners(&"dart", 0).is_empty(), "insufficient gold never reserves a slot")
	game.economy.gold = item.cost
	game.economy.lives = 0 # Deliberate transaction failure after slot reservation.
	_check(not game.try_upgrade(a, item) and game.towers.tier5_registry.owners(&"dart", 0).is_empty() and game.economy.gold == item.cost, "failed economy transaction rolls reservation back")
	game.economy.lives = 100
	var attempts: Array[bool] = []
	game.economy.changed.connect(func(_gold: int, _lives: int) -> void:
		attempts.append(game.try_upgrade(a, item))
		attempts.append(game.try_upgrade(b, item)))
	_check(game.try_upgrade(a, item) and attempts == [false, false] and game.economy.gold == 0, "reentrant gold signal cannot double-purchase same tower or bypass global slot")
	game.free()
	game = _game()
	_check(game.towers.tier5_registry.owners(&"dart", 0).is_empty(), "new map resets global slots")
	game.free()

func _ultra() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [5, 0, 0])
	var data: TowerDefinition = tower.stats
	_check(data.damage == 5 and data.pierce == 210 and data.fire_interval == 1.0 and data.attack_attribute == AttackSpec.Attribute.NORMAL, "ultra base damage pierce cadence Normal")
	for flags: Array in [[false, false, false, 5], [true, false, false, 13], [false, true, false, 10], [false, false, true, 25], [true, true, true, 38]]:
		var target_data: BalloonDefinition = _layers(80)
		target_data.ceramic = flags[0]
		target_data.fortified = flags[1]
		target_data.lead = flags[2]
		var target: BalloonState = _at(game, target_data, Vector2(700, 400))
		var gold: int = game.economy.gold
		_check(game.combat.apply_hit(target.id, data.make_attack()) == flags[3] and game.economy.gold == gold + flags[3], "ultra classification bonuses apply once and pay only actual layers")
	var mini_data: BalloonDefinition = _layers(30)
	mini_data.ceramic = true
	mini_data.fortified = true
	var mini_target: BalloonState = _at(game, mini_data, Vector2(700, 400))
	var mini_attack: AttackSpec = (data.projectile_split.child_projectile as TowerDefinition).make_attack()
	mini_attack.source_id = tower.id
	var mini_gold: int = game.economy.gold
	_check(game.combat.apply_hit(mini_target.id, mini_attack) == 7 and game.economy.gold == mini_gold + 7 and tower.combat_stats.pops() == 7, "mini ceramic and fortified bonuses award seven real layers once to original tower")
	game.free()
	game = _game()
	tower = _tower(game, [5, 0, 0])
	for index in range(105):
		_at(game, _layers(120), Vector2(200 + index * 0.1, 300))
	var parent: ProjectileState = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats, tower.id)
	game.projectiles.update(0.3)
	_check(parent.remaining_pierce == 105 and parent.split_bursts == 1 and tower.combat_stats.split_projectiles == 6, "exact 50 percent consumes 105 and releases six once")
	_check(tower.combat_stats.volleys == 0 and tower.combat_stats.projectiles == 7 and tower.combat_stats.pierce_available == 510, "generated children add projectile/pierce budget, not tower volleys")
	for index in range(105):
		_at(game, _layers(120), Vector2(300 + index * 0.1, 300))
	game.projectiles.update(0.3)
	_check(parent.remaining_pierce == 0 and parent.split_bursts == 2 and tower.combat_stats.split_projectiles == 12, "100 percent releases six more, independently of child hits")
	game.projectiles.update(1.5)
	_check(parent.split_bursts == 2 and tower.combat_stats.split_projectiles == 12, "parent expiration cannot duplicate either burst")
	_check(tower.combat_stats.pops() == game.economy.total_earned and tower.combat_stats.pierce_used <= tower.combat_stats.pierce_available, "split damage attribution matches gold and finite pierce budget")
	game.free()
	game = _game()
	tower = _tower(game, [5, 0, 0])
	parent = game.projectiles.launch(Vector2(400, 600), Vector2.UP, tower.stats, tower.id)
	game.projectiles.update(1.1)
	_check(parent.split_bursts == 2 and tower.combat_stats.split_projectiles == 12, "lifetime with zero hits emits all twelve remaining children")
	_check(game.projectiles.projectiles.size() == 12, "expiry children remain alive for their own lifetime")
	var directions: Array[Vector2] = []
	var first_child: ProjectileState = game.projectiles.projectiles[0]
	for child in game.projectiles.projectiles:
		directions.append(child.direction)
		_check(child.id != parent.id and child.initial_pierce == 50 and child.damage == 2 and child.split == null and child.attack.attribute == AttackSpec.Attribute.NORMAL, "each mini has independent ID and exact nonrecursive profile")
	_check(directions.size() == 12 and directions.all(func(direction: Vector2) -> bool: return direction.is_normalized()), "two radial phases produce twelve normalized directions")
	first_child.hit_ids[987] = true
	_check(not game.projectiles.projectiles[1].hit_ids.has(987), "mini projectile hit histories are independent")
	game.free()
	game = _game()
	tower = _tower(game, [5, 0, 0])
	for index in range(210):
		_at(game, _layers(120), Vector2(200 + index * 0.1, 300))
	parent = game.projectiles.launch(Vector2(100, 300), Vector2.RIGHT, tower.stats, tower.id)
	game.projectiles.update(0.4)
	_check(parent.split_bursts == 2 and tower.combat_stats.split_projectiles == 12, "one frame crossing both thresholds emits exactly twelve")
	game.free()
	_obstacles_and_rehits()

func _obstacles_and_rehits() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [5, 0, 0])
	var mini: TowerDefinition = tower.stats.projectile_split.child_projectile as TowerDefinition
	var target: BalloonState = _at(game, _layers(30), Vector2(400, 300))
	game.projectiles.ricochet_obstacles = [Rect2(440, 260, 20, 80)]
	var shot: ProjectileState = game.projectiles.launch(Vector2(350, 300), Vector2.RIGHT, mini, tower.id)
	game.projectiles.update(0.8)
	_check(shot.bounces >= 1 and shot.remaining_pierce == 48 and target.definition.layer_count() == 26, "small juggernaut re-hits same ID after real obstacle reflection")
	var escaping: ProjectileState = game.projectiles.launch(Vector2(433, 350), Vector2.LEFT, mini)
	game.projectiles.update(0.01)
	_check(escaping.direction.x < 0 and escaping.bounces == 0, "projectile departing obstacle surface does not reflect back inside")
	game.free()

func _plasma() -> void:
	var game: MainGame = _game()
	var leader: TowerState = _tower(game, [2, 5, 0], Vector2(300, 300))
	var smfc: TowerState = _tower(game, [0, 4, 2], Vector2(350, 300))
	for index in range(22):
		_tower(game, [0, 0, 0], Vector2(400 + index * 12, 300))
	var excluded: TowerState = _tower(game, [3, 0, 0])
	game.abilities.update(17.0)
	_check(game.abilities.activate(leader) and game.abilities.state_for(leader).last_targets.size() == 20, "Plasma includes self and nearest nineteen eligible darts")
	_check(not game.abilities.state_for(leader).last_targets.has(excluded.id) and leader.transformed_stats.damage == 2 and leader.transformed_stats.pierce == 8, "Plasma excludes catapult and preserves leader pierce crosspath")
	var plain: TowerState = game.towers.towers[2]
	_check(plain.transformed_stats.pierce == 5 and is_equal_approx(plain.transformed_stats.fire_interval, 0.03) and plain.transformed_stats.attack_range == 187.5, "unupgraded recipient has 2 damage 5 pierce 0.03 seconds and original40 scaled range")
	_check(smfc.transformed_stats.projectile_count == 1 and smfc.stats.projectile_count == 3 and leader.stats.projectile_count == 3, "tier5 transformation never mutates normal triple attacks")
	var purple: BalloonDefinition = _layers(4)
	purple.immunity_mask = 1 << AttackSpec.Attribute.PLASMA
	_check(not game.combat.can_damage(purple, AttackSpec.Attribute.PLASMA) and game.combat.can_damage(purple, AttackSpec.Attribute.NORMAL), "Plasma distinct from Normal and future purple immunity is data driven")
	var lead: BalloonState = _at(game, load("res://data/balloons/lead.tres"), Vector2(700, 400))
	_check(game.combat.apply_hit(lead.id, plain.transformed_stats.make_attack()) == 1, "Plasma can peel real lead shell without overkill leaking into children")
	game.abilities.update(5.0)
	_check(game.abilities.activate(smfc) and smfc.transformed_stats.attack_attribute == AttackSpec.Attribute.SHARP and plain.transformed_stats.attack_attribute == AttackSpec.Attribute.PLASMA, "SMFC self-activation exception does not downgrade other Plasma recipients")
	game.abilities.update(10.0)
	_check(plain.transformed_stats != null and plain.transformed_stats.attack_attribute == AttackSpec.Attribute.SHARP and leader.transformed_stats == null, "Plasma expiry falls back to an unexpired weaker lease; leader tier5 excluded from SMFC")
	game.abilities.update(5.0)
	_check(game.abilities.transformations.is_empty() and smfc.stats.projectile_count == 3, "all overlapping forms restore at their own expiration")
	game.abilities.update(30.0)
	_check(game.abilities.activate(leader), "Plasma ready again fifty seconds from activation")
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 1))
	_check(plain.transformed_stats.pierce == 6, "eligible purchase during Plasma recomputes from permanent stats")
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 2))
	game.try_upgrade(plain, MainGame.DART.upgrade_at(0, 3))
	_check(plain.transformed_stats == null, "ineligible tier3 upgrade cancels all transformation leases")
	game.towers.remove_tower(leader)
	_check(not game.abilities.states.has(leader.id) and smfc.transformed_stats != null, "tier5 caster removal releases state/slot but recipients retain timed Plasma")
	game.abilities.update(15.0)
	_check(game.abilities.transformations.is_empty() and MainGame.DART.damage == 1 and PMFC.transformed_damage == 2, "expiry after removal restores immutable data")
	game.free()
	game = _game()
	smfc = _tower(game, [0, 4, 0])
	game.abilities.update(17.0)
	game.abilities.activate(smfc)
	game.abilities.update(5.0)
	game.try_upgrade(smfc, MainGame.DART.upgrade_at(1, 5))
	_check(game.abilities.state_for(smfc).definition == PMFC and game.abilities.state_for(smfc).cooldown_remaining == 45.0 and smfc.transformed_stats == null, "SMFC to PMFC upgrade preserves cooldown and does not convert an old cast for free")
	game.free()

func _crossbow() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [2, 0, 4])
	tower.critical_counter = 7
	game.try_upgrade(tower, MainGame.DART.upgrade_at(2, 5))
	_check(tower.critical_counter == 0 and tower.stats.damage == 8 and tower.stats.critical_damage == 80 and tower.stats.critical_every == 5, "Crossbow Master purchase starts a new five-volley sequence")
	_check(tower.stats.pierce == 21 and tower.stats.attack_range == 375.0 and tower.stats.detects_camo and tower.stats.attack_attribute == AttackSpec.Attribute.NORMAL, "205 uses original pierce21 Normal and80 scaled range, camo metadata")
	var target: BalloonState = _at(game, _layers(300), Vector2(290, 350))
	var critical: ProjectileState
	for volley in range(1, 11):
		tower.cooldown = 0.0
		game.towers.update(MainGame.FIXED_STEP)
		var shot: ProjectileState = game.projectiles.projectiles.back()
		_check(shot.damage == (80 if volley % 5 == 0 else 8), "Crossbow Master five-volley critical cadence")
		if volley == 5:
			critical = shot
	var ids: Dictionary = {}
	game.combat.apply_hit(target.id, critical.attack, 1.0, ids)
	game.combat.apply_hit(target.id, critical.attack, 1.0, ids)
	_check(tower.combat_stats.critical_volleys == 2 and tower.combat_stats.critical_damage == 80 and tower.combat_stats.pops() == 80, "critical damage stats use actual removed layers once, not nominal damage per volley")
	var lead: BalloonState = _at(game, load("res://data/balloons/lead.tres"), Vector2(700, 400))
	_check(game.combat.apply_hit(lead.id, critical.attack) == 1 and tower.combat_stats.critical_damage == 81, "Normal critical pops lead shell, records one effective damage rather than eighty")
	game.free()
	game = _game()
	tower = _tower(game, [0, 2, 5])
	_check(tower.stats.pierce == 8 and is_equal_approx(tower.stats.fire_interval, 0.2375 * 0.85 * 2.0 / 3.0), "025 attack speed original crosspath mapping is isolated to tier5")
	game.free()

func _cache() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [2, 4, 0])
	game.select_instance(tower)
	var panel: TowerUpgradePanel = game.hud.upgrade_panel
	var count: int = panel.preview_rebuilds
	var text: String = panel._details[1].text
	for reward in range(100):
		game.economy.earn(1)
	_check(panel.preview_rebuilds == count and panel._details[1].text == text, "gold-only UI refresh reuses identical resolved upgrade preview")
	game.abilities.update(17.0)
	game.abilities.activate(tower)
	_check(panel.preview_rebuilds > count and panel._stats.text.contains("0.015초"), "transformation invalidates preview cache and displays actual temporary attack")
	panel.cache_previews = false
	panel.refresh()
	var uncached: String = panel._details[0].text
	panel.cache_previews = true
	panel.refresh()
	_check(panel._details[0].text == uncached, "cached and uncached preview produce identical UI")
	var old_text: String = game.hud._gold.text
	var old_gold: int = game.economy.gold
	game.hud.begin_combat_update()
	game.economy.earn(7)
	_check(game.economy.gold == old_gold + 7 and game.hud._gold.text == old_text, "combat UI batching never delays economy mutations")
	game.hud.end_combat_update()
	_check(game.hud._gold.text == "%d G" % game.economy.gold, "combat UI flush shows exact final gold")
	game.economy.lives = 1
	game.balloons.spawn(load("res://data/balloons/red.tres"), game.route.total_length - 0.1)
	game.simulation_step(MainGame.FIXED_STEP)
	_check(game.result == &"defeat" and game.hud._lives.text == "0" and not game.hud._in_combat_update, "defeat flushes batched UI and leaves no deferred state")
	game.free()

func _battle(speed: int, stats_enabled: bool, optimized_ui: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.hud.batch_combat_updates = optimized_ui
	game.hud.upgrade_panel.cache_previews = optimized_ui
	game.simulation_speed = speed
	game.battle_stats.enabled = stats_enabled
	var club: TowerState = _tower(game, [2, 5, 0])
	_tower(game, [5, 2, 0], Vector2(460, 450))
	_tower(game, [0, 2, 5], Vector2(672, 440))
	for index in range(4):
		_tower(game, [2, 2, 0], Vector2(250 + index * 80, 410))
	game.abilities.update(17.0)
	game.abilities.activate(club)
	for index in range(160):
		game.balloons.spawn(load("res://data/balloons/pink.tres"), index * 8.0)
	for frame in range(20 * 60 / speed):
		game._process(MainGame.FIXED_STEP)
	var counters: Array = []
	for record: TowerCombatStats in game.battle_stats.records.values():
		counters.append([record.volleys, record.projectiles, record.split_projectiles, record.pops(), record.critical_volleys, record.critical_damage])
	var report: Dictionary = {"combat": [game.economy.gold, game.economy.lives, game.balloons.balloons.size(), game.projectiles.projectiles.size(), game.abilities.transformations.size()], "counters": counters}
	game.free()
	return report
