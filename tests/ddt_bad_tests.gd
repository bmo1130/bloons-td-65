extends "res://tests/moab_tests.gd"

const DDT: BalloonDefinition = preload("res://data/balloons/ddt.tres")
const BAD: BalloonDefinition = preload("res://data/balloons/bad.tres")

func run(window: Window) -> Dictionary:
	_root = window
	_new_data()
	_tower_matrix()
	_birth_properties()
	_status_policy()
	_strong_order()
	_fast_contacts()
	_complete_ddt(false)
	_complete_ddt(true)
	_complete_bad(false)
	_complete_bad(true)
	_new_leaks()
	var one: Dictionary = _late_battle(1)
	_check(one == _late_battle(2), "DDT/BAD exact combat state and counters at1x/2x")
	_check(one.combat == _late_battle(1, false).combat, "new blimp combat independent from statistics")
	print("V0.11 BATTLE: %s" % one)
	print("V0.11 DDT BAD: %d checks, %d failures" % [_checks, _failures])
	return {"checks": _checks, "failures": _failures}

func _new_data() -> void:
	for row: Array in [[DDT, 400, 816, 1256, 381, 250.8], [BAD, 20000, 55760, 98360, 13346, 17.1]]:
		var data: BalloonDefinition = row[0]
		_check(data.shell_hp == row[1] and data.fortified_hp == row[1] * 2 and data.speed == row[5], "base/fortified HP and chosen speed: " + str(data.id))
		_check(data.total_rbe() == row[2] and data.total_rbe(true) == row[3] and data.layer_count() == row[4] and data.total_reward() == row[4], "RBE HP vs actual shells and reward: " + str(data.id))
		var game: MainGame = _game()
		var target: BalloonState = game.balloons.spawn(data)
		_check(target.camo == data.default_camo and target.shell_hp == row[1] and target.speed == data.speed, "intrinsic camo and generated HP/speed initialized from base")
		target.speed *= 1.2
		game.balloons.update(0.1)
		_check(is_equal_approx(target.distance, data.speed * 1.2 * 0.1) and data.speed == row[5], "generated movement value independent of immutable type")
		game.free()
	_check(DDT.default_camo and DDT.lead and DDT.moab_class and not BAD.default_camo and BAD.radius > ZOMG.radius, "DDT composite and BAD size/default camouflage")

func _tower_matrix() -> void:
	for build: Array in [[0, 0, 0], [0, 0, 2], [4, 0, 2], [0, 0, 5]]:
		var game: MainGame = _game()
		var tower: TowerState = _tower(game, build)
		var target: BalloonState = _at(game, DDT)
		var allowed: bool = build[0] == 4 or build[2] == 5
		_check((game.towers._first_in_range(tower) == target) == allowed, "actual tower DDT targeting " + tower.upgrade_text())
		var applied: int = game.combat.apply_hit(target.id, tower.stats.make_attack())
		_check((applied > 0) == allowed and target.shell_hp == 400 - applied, "actual tower profile DDT damage " + tower.upgrade_text())
		game.free()
	var game: MainGame = _game()
	game.towers.add_tower(Vector2(250, 350), MainGame.BOMB)
	var bomb: TowerState = game.towers.towers[0]
	var target: BalloonState = _at(game, DDT)
	_check(game.towers._first_in_range(bomb) == null and not game.combat.can_detect(target, false) and not game.combat.can_damage(DDT, AttackSpec.Attribute.EXPLOSIVE), "bomb blocked independently by camo and explosion immunity")
	for attribute in [AttackSpec.Attribute.SHARP, AttackSpec.Attribute.EXPLOSIVE, AttackSpec.Attribute.NORMAL, AttackSpec.Attribute.PLASMA]:
		var permitted: bool = attribute in [AttackSpec.Attribute.NORMAL, AttackSpec.Attribute.PLASMA]
		for detect in [false, true]:
			var hp: int = target.shell_hp
			var hit: AttackSpec = _attack(2, detect, attribute, bomb.id)
			var result: int = game.combat.apply_hit(target.id, hit)
			_check(result == (2 if permitted and detect else 0) and target.shell_hp == hp - result, "detection/type matrix independent")
	var layered: AttackSpec = _attack(2, true, AttackSpec.Attribute.NORMAL, bomb.id)
	layered.moab_bonus = 10
	layered.lead_bonus = 3
	layered.ceramic_bonus = 999
	layered.fortified_bonus = 5
	var armored: BalloonState = _at(game, DDT, false, true)
	_check(game.combat.apply_hit(armored.id, layered) == 20 and bomb.combat_stats.moab_damage == 24, "MOAB/lead/fortified bonuses, never ceramic bonus")
	var invisible_blast: AttackSpec = _attack(5, false, AttackSpec.Attribute.NORMAL, bomb.id)
	invisible_blast.explosion_radius = 100
	invisible_blast.pierce = 10
	var hp: int = target.shell_hp
	game.combat.explode(target.position, invisible_blast)
	_check(target.shell_hp == hp and bomb.combat_stats.gold_earned == 0 and bomb.combat_stats.pops() == 0, "blind AoE cannot damage DDT, no false Pops/cash")
	game.free()
	# Both recipients get the same Plasma type; their own detection remains distinct.
	game = _game()
	var caster: TowerState = _tower(game, [0, 5, 0])
	var seeing: TowerState = _tower(game, [0, 0, 2], Vector2(250, 410))
	var blind: TowerState = _tower(game, [0, 0, 0], Vector2(310, 410))
	game.abilities.update(17)
	_check(game.abilities.activate(caster), "Plasma ability activates for DDT test")
	target = _at(game, DDT)
	_check(game.combat.apply_hit(target.id, seeing.combat_definition().make_attack()) == 2 and game.combat.apply_hit(target.id, blind.combat_definition().make_attack()) == 0 and game.combat.apply_hit(target.id, caster.combat_definition().make_attack()) == 0, "Plasma type alone does not grant camo detection")
	game.abilities.update(15.1)
	_check(seeing.transformed_stats == null and not game.combat.can_attack(target, seeing.stats.attack_attribute, seeing.stats.detects_camo), "Plasma expiry restores SHARP immunity even with detection")
	game.free()

func _birth_properties() -> void:
	for armor in [false, true]:
		for decamo in [false, true]:
			var game: MainGame = _game()
			var parent: BalloonState = game.balloons.spawn(DDT, 640, false, armor, true)
			if decamo:
				parent.remove_camo()
			game.balloons.update(0.1, true)
			var at: Vector2 = parent.position_at_time(0.5)
			var distance: float = parent.distance_at_time(0.5)
			var excluded: Dictionary = {}
			_check(game.combat.apply_hit(parent.id, _attack(100000), 0.5, excluded) == (800 if armor else 400), "DDT overkill stops at hull")
			_check(game.balloons.balloons.size() == 4 and game.economy.total_earned == 1, "DDT produces exactly four ceramics/one hull reward")
			for child in game.balloons.balloons:
				_check(child.definition == CERAMIC and child.camo == (not decamo) and child.regrow and child.fortified == armor and child.shell_hp == (20 if armor else 10), "DDT live camo and Regrow metadata/armor birth")
				_check(child.position.is_equal_approx(at) and is_equal_approx(child.distance, distance) and excluded.has(child.id), "DDT child contact position/distance and same-attack exclusion")
			var child: BalloonState = game.balloons.balloons[0]
			game.combat.apply_hit(child.id, _attack(child.shell_hp))
			_check(game.balloons.balloons.filter(func(b: BalloonState) -> bool: return b.definition.id == &"rainbow").all(func(b: BalloonState) -> bool: return b.regrow and not b.fortified and b.camo == (not decamo)), "ceramic drops armor, independently keeps live camo/Regrow")
			game.balloons.resolve_leaks()
			game.free()
	var game: MainGame = _game()
	var parent: BalloonState = game.balloons.spawn(DDT, 500)
	game.combat.apply_hit(parent.id, _attack(400))
	var child: BalloonState = game.balloons.balloons[0]
	game.combat.apply_hit(child.id, _attack(5))
	game.balloons.update(3.0)
	_check(child.regrow and child.shell_hp == 5 and child.definition == CERAMIC, "Regrow is explicitly metadata only, no hidden healing")
	game.free()
	for armor in [false, true]:
		game = _game()
		parent = game.balloons.spawn(BAD, 650, false, armor, true)
		_check(not parent.camo and not parent.regrow, "BAD itself has neither intrinsic camo nor Regrow")
		game.combat.apply_hit(parent.id, _attack(100000))
		var kinds: Dictionary = {}
		for b in game.balloons.balloons:
			kinds[b.definition.id] = int(kinds.get(b.definition.id, 0)) + 1
			_check(b.fortified == armor and b.shell_hp == b.definition.max_hp(armor) and b.camo == (b.definition == DDT) and not b.regrow, "heterogeneous BAD birth uses each type's intrinsic properties")
		_check(kinds == {&"zomg": 2, &"ddt": 3} and game.economy.total_earned == 1 and game.combat.apply_hit(parent.id, _attack(99999)) == 0, "BAD mixed five children, single reward, stale ID safe")
		game.free()

func _status_policy() -> void:
	var game: MainGame = _game()
	var bad: BalloonState = _at(game, BAD)
	for effect in BalloonDefinition.StatusEffect.values():
		_check(not game.combat.can_apply_status(bad, effect), "BAD rejects generic movement/control/kill policy " + str(effect))
	var tower: TowerState = _tower(game, [4, 0, 2])
	var start: float = bad.distance
	var damage: int = game.combat.apply_hit(bad.id, tower.stats.make_attack())
	game.balloons.update(0.1)
	_check(damage == 2 and bad.shell_hp == 19998 and bad.knockback_remaining == 0 and is_equal_approx(bad.distance, start + 1.71), "Juggernaut damages BAD normally but cannot move it backwards")
	var hit: AttackSpec = _attack(2)
	hit.moab_bonus = 10
	hit.knockback_duration = 0.15
	hit.knockback_heavy = 3
	_check(game.combat.apply_hit(bad.id, hit) == 12 and bad.knockback_remaining == 0, "MOAB bonus independent of BAD control immunity")
	# Prove the new mask gates the real effect, independently of legacy bool.
	var guarded: BalloonDefinition = BAD.duplicate() as BalloonDefinition
	guarded.knockback_allowed = true
	var b: BalloonState = _at(game, guarded)
	game.combat.apply_hit(b.id, hit)
	_check(b.knockback_remaining == 0 and b.shell_hp == 19988, "status mask rejects actual knockback while damage still applies")
	var ordinary: BalloonDefinition = guarded.duplicate() as BalloonDefinition
	ordinary.status_immunity_mask = 0
	b = _at(game, ordinary)
	game.combat.apply_hit(b.id, hit)
	_check(b.knockback_remaining == 0.15, "policy uses effect flags, not BAD name branches")
	for attribute in [AttackSpec.Attribute.SHARP, AttackSpec.Attribute.EXPLOSIVE, AttackSpec.Attribute.NORMAL, AttackSpec.Attribute.PLASMA, AttackSpec.Attribute.COLD]:
		_check(game.combat.apply_hit(bad.id, _attack(1, true, attribute)) == 1, "BAD control immunity does not become attack-type immunity")
	game.free()

func _strong_order() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 5])
	tower.target_mode = TowerState.TargetMode.STRONG
	var highest: BalloonState = _at(game, BAD)
	var ddt: BalloonState = _at(game, DDT)
	var zomg: BalloonState = _at(game, ZOMG, false, true)
	_check(game.towers._first_in_range(tower) == highest and game.towers._prefer_target(ddt, zomg, tower), "BAD highest; DDT above fortified ZOMG regardless HP")
	highest.position = Vector2(950, 650)
	_check(game.towers._first_in_range(tower) == ddt, "Strong chooses in-range DDT")
	tower.stats.detects_camo = false
	_check(game.towers._first_in_range(tower) == zomg, "Strong skips invisible DDT")
	tower.stats.detects_camo = true
	tower.stats.attack_attribute = AttackSpec.Attribute.SHARP
	_check(game.towers._first_in_range(tower) == zomg, "Strong detection never bypasses DDT type immunity")
	game.free()

func _fast_contacts() -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	var ddt: BalloonState = game.balloons.spawn(DDT, 640)
	var profile: TowerDefinition = tower.stats.duplicate() as TowerDefinition
	profile.attack_attribute = AttackSpec.Attribute.NORMAL
	profile.detects_camo = true
	profile.pierce = 3
	var shot: ProjectileState = game.projectiles.launch(Vector2(250, 340), Vector2.RIGHT, profile, tower.id)
	game.balloons.update(0.2, true)
	game.projectiles.update(0.2)
	game.balloons.resolve_leaks()
	_check(ddt.shell_hp == 399 and shot.remaining_pierce == 2 and tower.combat_stats.moab_damage == 1, "fast crossing DDT swept contact and one pierce")
	game.projectiles.update(0.1)
	_check(ddt.shell_hp == 399, "same fast target cannot be hit twice by same shot")
	game.free()
	game = _game()
	tower = _tower(game, [0, 0, 0])
	var bad: BalloonState = _at(game, BAD)
	profile.damage = 99999
	profile.pierce = 20
	shot = game.projectiles.launch(bad.position, Vector2.RIGHT, profile, tower.id)
	game.projectiles.update(0.01)
	game.projectiles.update(0.1)
	_check(game.balloons.balloons.size() == 5 and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.shell_hp == b.shell_max_hp and shot.was_hit(b.id, 0)), "BAD shot excludes both child types permanently")
	_check(tower.combat_stats.pops() == 1 and tower.combat_stats.moab_damage == 20000 and tower.combat_stats.gold_earned == 1, "BAD huge overkill counts only real hull HP/one Pop/one gold")
	game.free()

func _complete_ddt(armor: bool) -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	game.balloons.spawn(DDT, 500, false, armor, true)
	for count in [4, 8, 16, 32, 64, 64, 64, 64, 64, 0]:
		for parent: BalloonState in game.balloons.balloons.duplicate():
			game.combat.apply_hit(parent.id, _attack(parent.shell_hp, true, AttackSpec.Attribute.NORMAL, tower.id))
		_check(game.balloons.balloons.size() == count and game.balloons.balloons.all(func(b: BalloonState) -> bool: return b.camo and b.regrow), "DDT full tree and metadata each generation")
	_check(game.economy.total_earned == 381 and tower.combat_stats.pops() == 381 and tower.combat_stats.effective_damage == (1256 if armor else 816) and tower.combat_stats.moab_damage == (800 if armor else 400), "full DDT actual damage/Pops/cash/MOAB damage separate")
	game.free()

func _complete_bad(armor: bool) -> void:
	var game: MainGame = _game()
	var tower: TowerState = _tower(game, [0, 0, 0])
	game.balloons.profile_changes = true
	game.balloons.spawn(BAD, 650, false, armor, true)
	for count in [5, 20, 56, 176, 352, 704, 1216, 2240, 2240, 2240, 2048, 2048, 0]:
		for parent: BalloonState in game.balloons.balloons.duplicate():
			game.combat.apply_hit(parent.id, _attack(parent.shell_hp, true, AttackSpec.Attribute.NORMAL, tower.id))
		_check(game.balloons.balloons.size() == count, "BAD heterogeneous complete tree count armor%s" % armor)
	_check(tower.combat_stats.effective_damage == (98360 if armor else 55760) and tower.combat_stats.moab_damage == (82400 if armor else 41200), "BAD complete real HP and MOAB subset")
	_check(tower.combat_stats.pops() == 13346 and game.economy.total_earned == 13346 and tower.combat_stats.gold_earned == 13346, "BAD complete actual13346Pops/gold, never RBE reward")
	_check(game.balloons.latest_id() == 4386 and game.balloons.removal_count == 4386 and game.balloons.peak_active_count == 2240, "BAD all4386 independent IDs removed, peak2240")
	game.free()

func _new_leaks() -> void:
	for definition in [DDT, BAD]:
		for armor in [false, true]:
			var game: MainGame = _game()
			var parent: BalloonState = game.balloons.spawn(definition, game.route.total_length - 0.1, false, armor)
			game.combat.apply_hit(parent.id, _attack(parent.shell_hp - 1))
			_check(parent.leak_damage() == definition.total_rbe(armor) and BalloonLeakPolicy.damage(parent) == parent.leak_damage(), "separate compatibility leak policy full type after damage")
			game.balloons.update(1, true)
			game.balloons.resolve_leaks()
			_check(game.economy.lives == 1000000 - definition.total_rbe(armor) and game.economy.total_earned == 0, "new blimp leak never counts prior HP loss as Pops/cash")
			game.free()
	var game: MainGame = _game()
	var parent: BalloonState = game.balloons.spawn(BAD, game.route.total_length, false, true)
	game.balloons.update(0.1, true)
	game.combat.apply_hit(parent.id, _attack(99999), parent.exit_time)
	game.balloons.resolve_leaks()
	_check(game.economy.lives == 1000000 - 58360 and game.economy.total_earned == 1 and game.balloons.balloons.is_empty(), "fortified BAD split at exit leaks only mixed children58360")
	game.free()

func _late_battle(speed: int, enabled: bool = true) -> Dictionary:
	var game: MainGame = _game()
	game.battle_stats.enabled = enabled
	_tower(game, [4, 0, 2])
	_tower(game, [0, 2, 5], Vector2(460, 450))
	var caster: TowerState = _tower(game, [0, 5, 2], Vector2(672, 232))
	game.abilities.update(17)
	game.abilities.activate(caster)
	game.balloons.spawn(BAD, 600)
	for index in range(10):
		game.balloons.spawn(DDT, 500 + index * 10, false, index % 2 == 0, true)
	for frame in range(360 / speed):
		for step in range(speed):
			game.simulation_step(MainGame.FIXED_STEP)
	var state: Array = []
	for b in game.balloons.balloons:
		state.append([b.id, b.definition.id, b.shell_hp, b.distance, b.camo, b.regrow, b.fortified])
	var counters: Array = []
	for record: TowerCombatStats in game.battle_stats.records.values():
		counters.append(record.snapshot())
	var report: Dictionary = {"combat": [game.economy.gold, game.economy.lives, game.balloons.latest_id(), state], "counters": counters}
	game.free()
	return report
