class_name AbilitySystem
extends Node

signal changed
var tower_system: TowerSystem
var economy: GameEconomy
const SCREEN_BOUNDS: Rect2 = Rect2(0, 0, 980, 720)
var _storm_running: bool = false
var enabled: bool = true
var states: Dictionary = {} # Caster ID -> cooldown/duration state, never tower refs.
var transformations: Dictionary = {} # Target ID -> {remaining, definition}.
var _serial: int = 0

func state_for(tower: TowerState) -> AbilityState:
	return states.get(tower.id) as AbilityState if tower != null else null

func sync_tower(tower: TowerState) -> void:
	if tower.stats.ability != null and not states.has(tower.id):
		states[tower.id] = AbilityState.new(tower.stats.ability)
	elif tower.stats.ability != null:
		# Buying the next ability tier preserves the already running cooldown.
		if tower.stats.ability.effect == AbilityDefinition.Effect.MOAB_MISSILE:
			states[tower.id].cooldown_remaining = minf(states[tower.id].cooldown_remaining, tower.stats.ability.cooldown)
		states[tower.id].definition = tower.stats.ability
	if transformations.has(tower.id):
		_refresh(tower, true)
	changed.emit()

func eligible(tower: TowerState, data: AbilityDefinition) -> bool:
	return tower.definition.id == data.tower_type and tower.tiers[0] < 3 and tower.tiers[2] < 3 and tower.tiers[1] <= data.max_middle_tier

func select_targets(caster: TowerState, data: AbilityDefinition) -> Array[TowerState]:
	var candidates: Array[TowerState] = []
	for tower in tower_system.towers:
		if tower != caster and eligible(tower, data):
			candidates.append(tower)
	candidates.sort_custom(func(a: TowerState, b: TowerState) -> bool:
		var a_active: bool = transformations.has(a.id)
		var b_active: bool = transformations.has(b.id)
		if data.prefer_untransformed and a_active != b_active:
			return not a_active
		var da: float = caster.position.distance_squared_to(a.position)
		var db: float = caster.position.distance_squared_to(b.position)
		return da < db if da != db else a.id < b.id)
	var targets: Array[TowerState] = []
	if eligible(caster, data):
		targets.append(caster)
	for tower in candidates:
		if targets.size() >= data.target_limit:
			break
		targets.append(tower)
	return targets

func activate(caster: TowerState) -> bool:
	var state: AbilityState = state_for(caster)
	if not enabled or state == null or not tower_system.towers.has(caster) or state.cooldown_remaining > 0.000001:
		return false
	if state.definition.effect == AbilityDefinition.Effect.LEAK_STORM:
		return false
	if state.definition.effect == AbilityDefinition.Effect.MOAB_MISSILE:
		var target: BalloonState = missile_target(caster)
		if target == null:
			return false # Empty/invisible screen never consumes cooldown.
		var shot: ProjectileState = tower_system.projectile_system.launch(caster.position, caster.position.direction_to(target.position), state.definition.attack_profile, caster.id)
		if shot == null:
			return false
		shot.target_id = target.id
		state.last_targets = PackedInt64Array([target.id])
		state.cooldown_remaining = state.definition.cooldown
		changed.emit()
		return true
	var targets: Array[TowerState] = select_targets(caster, state.definition)
	state.cooldown_remaining = state.definition.cooldown
	state.active_remaining = state.definition.duration
	state.last_targets.clear()
	_serial += 1
	for tower in targets:
		state.last_targets.append(tower.id)
		if not transformations.has(tower.id):
			transformations[tower.id] = {"leases": {}, "remaining": 0.0, "definition": null}
		var entry: Dictionary = transformations[tower.id]
		var key: String = "%d:%s" % [caster.id, state.definition.id]
		var old: AbilityDefinition = entry.definition
		entry.leases[key] = {"remaining": state.definition.duration, "definition": state.definition,
			"serial": _serial, "self_override": tower == caster and state.definition.self_overrides_stronger}
		_refresh(tower, old == null or old.priority <= state.definition.priority or tower == caster)
	changed.emit()
	return true

func missile_target(caster: TowerState) -> BalloonState:
	var state: AbilityState = state_for(caster)
	if state == null or state.definition.effect != AbilityDefinition.Effect.MOAB_MISSILE:
		return null
	var profile: TowerDefinition = state.definition.attack_profile
	var best: BalloonState
	for balloon in tower_system.balloon_system.balloons:
		if not balloon.definition.moab_class or balloon.exit_time <= 1.0 or not SCREEN_BOUNDS.has_point(balloon.position):
			continue
		if not tower_system.combat.can_attack(balloon, profile.attack_attribute, profile.detects_camo):
			continue
		if best == null or tower_system._prefer_target(balloon, best, caster):
			best = balloon
	return best

func before_leak(balloon: BalloonState) -> void:
	if not enabled or _storm_running or economy == null or economy.lives <= 0 or balloon.leak_damage() <= 0:
		return
	# Tower array/IDs are stable. One ready caster answers a pending leak; reserve
	# cooldown before damage signals. Newly split children stay in the leak queue.
	for caster in tower_system.towers:
		var state: AbilityState = state_for(caster)
		if state == null or state.definition.effect != AbilityDefinition.Effect.LEAK_STORM or state.cooldown_remaining > 0.000001:
			continue
		state.cooldown_remaining = state.definition.cooldown
		_storm_running = true
		var attack: AttackSpec = state.definition.attack_profile.make_attack()
		attack.source_id = caster.id
		var ids: PackedInt64Array = []
		for target in tower_system.balloon_system.balloons:
			if SCREEN_BOUNDS.has_point(target.position):
				ids.append(target.id)
		ids.sort()
		var excluded: Dictionary = {}
		for id in ids:
			tower_system.combat.apply_hit(id, attack, 1.0, excluded)
		tower_system.combat.effects.append({"position": Vector2(490, 360), "radius": 600.0, "remaining": 0.28})
		_storm_running = false
		changed.emit()
		return

func _apply(tower: TowerState, data: AbilityDefinition) -> void:
	var stats: TowerDefinition = transformed_definition(tower.stats, tower.tiers, data)
	tower.transformed_stats = stats
	# No immediate bonus shot and no inherited long triple-shot reload.
	tower.cooldown = stats.fire_interval
	tower_system.queue_redraw()

func transformed_definition(permanent: TowerDefinition, tiers: PackedInt32Array, data: AbilityDefinition) -> TowerDefinition:
	var stats: TowerDefinition = permanent.duplicate() as TowerDefinition
	stats.damage = data.transformed_damage
	stats.pierce += data.pierce_bonus
	stats.attack_attribute = data.attribute
	stats.projectile_count = 1
	stats.spread_degrees = 0.0
	stats.fire_interval = data.transformed_intervals[mini(tiers[1], data.transformed_intervals.size() - 1)]
	stats.attack_range = data.minimum_range + (data.eyesight_range if tiers[2] >= 2 else 0.0)
	stats.projectile_speed = maxf(stats.projectile_speed, data.projectile_speed)
	if tiers[2] >= 2:
		stats.projectile_speed *= data.eyesight_speed_multiplier
		stats.detects_camo = stats.detects_camo or data.grants_eyesight
	if data.projectile_lifetime > 0.0:
		stats.projectile_lifetime = data.projectile_lifetime * (data.eyesight_lifetime_multiplier if tiers[2] >= 2 else (data.long_range_lifetime_multiplier if tiers[2] >= 1 else 1.0))
	if data.projectile_radius > 0.0:
		stats.projectile_radius = data.projectile_radius
	stats.color = data.color
	return stats

func preview(tower: TowerState, upgrade: UpgradeDefinition) -> TowerDefinition:
	var permanent: TowerDefinition = TowerStatResolver.preview(tower.definition, tower.tiers, upgrade)
	var tiers: PackedInt32Array = tower.tiers.duplicate()
	tiers[upgrade.path] = upgrade.tier
	if transformations.has(tower.id) and tiers[0] < 3 and tiers[2] < 3:
		return transformed_definition(permanent, tiers, transformations[tower.id].definition)
	return permanent

func _refresh(tower: TowerState, force_reload: bool = false) -> void:
	var entry: Dictionary = transformations[tower.id]
	var best: Dictionary = {}
	for key: String in entry.leases.keys():
		var lease: Dictionary = entry.leases[key]
		if lease.remaining <= 0.000001 or not eligible(tower, lease.definition):
			entry.leases.erase(key)
			continue
		if best.is_empty() or lease.definition.priority > best.definition.priority or (lease.definition.priority == best.definition.priority and lease.serial > best.serial):
			best = lease
	# Source documents describe an SMFC leader's own later activation overriding
	# its Plasma form. A later Plasma activation overrides it again.
	for lease: Dictionary in entry.leases.values():
		if lease.self_override and (best.is_empty() or lease.serial > best.serial):
			best = lease
	if best.is_empty():
		_restore(tower)
		transformations.erase(tower.id)
		return
	var changed_profile: bool = entry.definition != best.definition
	entry.definition = best.definition
	entry.remaining = best.remaining
	if force_reload or changed_profile:
		_apply(tower, best.definition)

func _restore(tower: TowerState) -> void:
	tower.transformed_stats = null
	tower.cooldown = tower.stats.fire_interval
	tower_system.queue_redraw()

func remove_tower(id: int) -> void:
	states.erase(id)
	transformations.erase(id)
	# Other targets keep their timed effect when the caster is removed.
	changed.emit()

func update(delta: float) -> void:
	for state: AbilityState in states.values():
		var was_charging: bool = state.cooldown_remaining > 0.000001
		state.cooldown_remaining = maxf(0.0, state.cooldown_remaining - delta)
		state.active_remaining = maxf(0.0, state.active_remaining - delta)
		if was_charging and state.cooldown_remaining <= 0.000001:
			changed.emit()
	for id: int in transformations.keys():
		var entry: Dictionary = transformations[id]
		var expired: bool = false
		for lease: Dictionary in entry.leases.values():
			lease.remaining -= delta
			expired = expired or lease.remaining <= 0.000001
		entry.remaining = maxf(0.0, entry.remaining - delta)
		if expired:
			var tower: TowerState = tower_system.find(id)
			if tower != null:
				_refresh(tower)
			else:
				transformations.erase(id)
			changed.emit()
