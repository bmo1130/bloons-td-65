class_name CombatSystem
extends Node2D

signal exploded(position: Vector2, radius: float)

# Sparse shell-bound effects. No per-balloon Node/Timer; ownership is first application.
var damage_effects: Dictionary = {} # ID -> family -> live snapshot.
var tick_sink: Callable
var effect_clock: float = 0.0
var _batch_start: float = 0.0
var _batch_delta: float = 0.0
var area_events: int = 0
var dot_ticks: int = 0
var balloon_system: BalloonSystem
var battle_stats: BattleStatistics
var effects: Array[Dictionary] = []
var aoe_candidates: int = 0
var profile_updates: bool = false
var profile_usec: Dictionary = {"aoe_query": 0, "aoe_sort": 0, "aoe_damage": 0, "dot_schedule": 0, "dot_damage": 0, "press": 0, "effect_update": 0, "effect_apply": 0}
var profile_counts: Dictionary = {"explosions": 0, "aoe_entries": 0, "contacts": 0}
var draw_usec: int = 0
var trace: CombatTrace # Same optional observer as ProjectileSystem, never a combat input.

func reset_profile() -> void:
	profile_usec = {"aoe_query": 0, "aoe_sort": 0, "aoe_damage": 0, "dot_schedule": 0, "dot_damage": 0, "press": 0, "effect_update": 0, "effect_apply": 0}
	profile_counts = {"explosions": 0, "aoe_entries": 0, "contacts": 0}
	draw_usec = 0

func can_damage(definition: BalloonDefinition, attribute: AttackSpec.Attribute) -> bool:
	# Shatter breaks frozen/sharp-only protection, but never acquires lead popping.
	# This is a damage-type rule over immutable traits, not a tower/type-name test.
	if attribute == AttackSpec.Attribute.SHATTER and definition.lead:
		return false
	return (definition.immunity_mask & (1 << attribute)) == 0

func can_detect(balloon: BalloonState, detects_camo: bool) -> bool:
	return not balloon.camo or detects_camo

func can_attack(balloon: BalloonState, attribute: AttackSpec.Attribute, detects_camo: bool = false) -> bool:
	return can_detect(balloon, detects_camo) and can_damage(balloon.definition, attribute)

func can_target(balloon: BalloonState, profile: TowerDefinition) -> bool:
	if profile.moab_only and not balloon.definition.moab_class:
		return false
	if profile.requires_press_target and not can_apply_status(balloon, BalloonDefinition.StatusEffect.FORCED_MOVEMENT):
		return false
	if can_attack(balloon, profile.attack_attribute, profile.detects_camo):
		return true
	var split: ProjectileSplitDefinition = profile.projectile_split
	if split != null and split.on_explosion:
		var child: TowerDefinition = split.child_projectile as TowerDefinition
		return child != null and can_attack(balloon, child.attack_attribute, profile.detects_camo)
	return false

func can_apply_status(balloon: BalloonState, effect: BalloonDefinition.StatusEffect, supports_moab: bool = false) -> bool:
	if (balloon.definition.status_immunity_mask & (1 << effect)) != 0:
		return false
	return effect != BalloonDefinition.StatusEffect.KNOCKBACK or balloon.definition.knockback_allowed or (supports_moab and balloon.definition.moab_class)

func apply_hit(id: int, attack: AttackSpec, time: float = 1.0, excluded_ids: Variant = null) -> int:
	if profile_updates:
		profile_counts.contacts += 1
	var excluded: Dictionary = {} if excluded_ids == null else excluded_ids
	var balloon: BalloonState = balloon_system.find(id)
	if balloon == null or excluded.has(id) or (attack.moab_only and not balloon.definition.moab_class):
		return 0
	excluded[id] = true
	var original: BalloonDefinition = balloon.definition
	var armored: bool = balloon.fortified
	var damage: int = attack.damage + (attack.ceramic_bonus if original.ceramic else 0) + (attack.fortified_bonus if armored else 0) + (attack.lead_bonus if original.lead else 0) + (attack.moab_bonus if original.moab_class else 0)
	# One compact accumulator per contact, shared through the data tree. Children
	# do not create more attack events or consume additional pierce.
	var result: Array[int] = [0, 0, 0, 0, 0, 0, 0] # normal shells actual_hp reward immune damaged_ids moab_hp
	var damage_started: int = Time.get_ticks_usec() if trace != null else 0
	_damage_layers(balloon, maxi(0, damage), attack, time, excluded, result)
	if trace != null:
		trace.elapsed("damage_layers_usec", damage_started)
		trace.add("damage_attempts")
		if result[2] > 0:
			trace.add("damage_confirmed")
	if result[2] > 0 and balloon_system.find(id) != null and original.knockback_allowed and can_apply_status(balloon, BalloonDefinition.StatusEffect.KNOCKBACK) and attack.knockback_duration > 0.0:
		# Motion already resolved this tick is immutable. Status starts next tick.
		balloon.knockback_remaining = maxf(balloon.knockback_remaining, attack.knockback_duration)
		var heavy: bool = original.heavy or original.ceramic or armored
		balloon.knockback_multiplier = maxf(0.0, attack.knockback_heavy if heavy else attack.knockback_light)
	if result[2] > 0 and balloon_system.find(id) != null:
		var moab: bool = balloon.definition.moab_class
		var stun: float = attack.stun_moab_duration if moab else attack.stun_duration
		if stun > 0.0 and can_apply_status(balloon, BalloonDefinition.StatusEffect.STUN):
			balloon.stun_remaining = maxf(balloon.stun_remaining, stun)
		var push: float = attack.push_moab_distance if moab else attack.push_distance
		if push > 0.0 and can_apply_status(balloon, BalloonDefinition.StatusEffect.KNOCKBACK, attack.push_moab_distance > 0.0):
			balloon.pending_push = maxf(balloon.pending_push, push)
	if result[2] > 0 and balloon_system.find(id) != null:
		if attack.press_distance > 0.0 and balloon.definition.moab_class and can_apply_status(balloon, BalloonDefinition.StatusEffect.FORCED_MOVEMENT):
			var press_started: int = Time.get_ticks_usec() if profile_updates else 0
			balloon.pending_press += attack.press_distance * balloon.definition.press_multiplier
			if profile_updates:
				profile_usec.press += Time.get_ticks_usec() - press_started
		if balloon.definition == original and attack.damage_over_time != null and not attack.dot_consumed:
			if not attack.damage_over_time.moab_only or original.moab_class:
				_attach_effect(balloon, attack, time)
				if attack.dot_first_moab:
					attack.dot_consumed = true
	var statistics_started: int = Time.get_ticks_usec() if trace != null else 0
	if result[3] > 0:
		balloon_system.layer_popped.emit(result[3])
	if battle_stats != null:
		battle_stats.record_hit(attack.source_id, result[0], result[1], result[4] > 0, attack.critical, result[2], result[5], result[4], result[6], result[3])
	if trace != null:
		trace.elapsed("rewards_statistics_usec", statistics_started)
	balloon_system.queue_redraw()
	return result[2]

func _damage_layers(balloon: BalloonState, amount: int, attack: AttackSpec, time: float, excluded: Dictionary, result: Array[int]) -> void:
	var counted: bool = false
	while amount > 0:
		var data: BalloonDefinition = balloon.definition
		# Camo and type immunity remain independent, including overflow children.
		if not can_attack(balloon, attack.attribute, attack.detects_camo):
			result[4] += 1
			return
		var applied: int = mini(amount, balloon.shell_hp)
		balloon.shell_hp -= applied
		amount -= applied
		result[2] += applied
		if data.moab_class:
			result[6] += applied
		if applied > 0 and not counted:
			result[5] += 1
			counted = true
		if balloon.shell_hp > 0:
			return
		var shell: bool = not data.split_children.is_empty()
		result[1 if shell else 0] += 1
		result[3] += data.pop_reward
		var first_child: int = balloon_system.latest_id() + 1
		var branched: bool = balloon_system.peel_layer(balloon, time, excluded)
		if branched:
			if balloon.spill_damage and not data.blocks_child_damage and amount > 0:
				var last_child: int = balloon_system.latest_id()
				for child_id in range(first_child, last_child + 1):
					var child: BalloonState = balloon_system.find(child_id)
					if child != null:
						_damage_layers(child, amount, attack, time, excluded, result)
			return
		if balloon_system.find(balloon.id) == null:
			return

func explode(center: Vector2, attack: AttackSpec, time: float = 1.0, max_id: int = 2147483647, excluded_ids: Variant = null, visual: bool = true) -> Array[int]:
	area_events += 1
	_count_auxiliary(attack.source_id, &"area_events")
	var profiled_at: int = Time.get_ticks_usec() if profile_updates else 0
	var excluded: Dictionary = {} if excluded_ids == null else excluded_ids
	var radius: float = maxf(0.0, attack.explosion_radius)
	var candidates: Array[Dictionary] = []
	var bounds: Rect2 = Rect2(center, Vector2.ZERO).grow(radius)
	# Freeze membership before any damage/splitting. The cap also excludes every
	# child born during the current projectile batch, even from another blast.
	for balloon in balloon_system.candidates_in_rect(bounds):
		aoe_candidates += 1
		if balloon.id > max_id or excluded.has(balloon.id) or balloon_system.find(balloon.id) == null:
			continue
		if time > balloon.exit_time:
			continue
		var distance_squared: float = center.distance_squared_to(balloon.position_at_time(time))
		if distance_squared <= radius * radius:
			candidates.append({"id": balloon.id, "distance": distance_squared})
	if profile_updates:
		profile_usec.aoe_query += Time.get_ticks_usec() - profiled_at
		profile_counts.explosions += 1
		profile_counts.aoe_entries += candidates.size()
		profiled_at = Time.get_ticks_usec()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
	if profile_updates:
		profile_usec.aoe_sort += Time.get_ticks_usec() - profiled_at
		profiled_at = Time.get_ticks_usec()
	var hit_ids: Array[int] = []
	for candidate in candidates:
		if hit_ids.size() >= attack.pierce:
			break
		var id: int = candidate.id
		if excluded.has(id):
			continue
		if apply_hit(id, attack, time, excluded) > 0:
			hit_ids.append(id)
	if profile_updates:
		profile_usec.aoe_damage += Time.get_ticks_usec() - profiled_at
	if visual:
		effects.append({"position": center, "radius": radius, "remaining": 0.28})
		exploded.emit(center, radius)
	queue_redraw()
	return hit_ids

func update(delta: float) -> void:
	aoe_candidates = 0
	for index in range(effects.size() - 1, -1, -1):
		effects[index].remaining -= delta
		if effects[index].remaining <= 0.0:
			effects.remove_at(index)
	queue_redraw()

func _draw() -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	for effect in effects:
		var alpha: float = clampf(effect.remaining / 0.28, 0.0, 1.0)
		draw_circle(effect.position, effect.radius, Color(1.0, 0.65, 0.23, alpha * 0.13))
		draw_arc(effect.position, effect.radius * (1.0 - alpha * 0.25), 0.0, TAU, 48, Color(1.0, 0.77, 0.37, alpha), 2.5, true)
	for id: int in damage_effects:
		var balloon: BalloonState = balloon_system.find(id)
		if balloon != null:
			if damage_effects[id].has(&"shred"):
				draw_arc(balloon.position, balloon.definition.radius + 4.0, 0, PI * 1.5, 16, Color("94eafa"), 2, true)
			if damage_effects[id].has(&"burn"):
				draw_arc(balloon.position, balloon.definition.radius + 7.0, PI * 0.5, TAU, 16, Color("ff9d48"), 2, true)
			for family: StringName in damage_effects[id]:
				var tint: Color = damage_effects[id][family].get("color", Color.TRANSPARENT)
				if tint.a > 0.0:
					draw_arc(balloon.position, balloon.definition.radius+7.0,0,TAU,16,tint,2,true)

	if profile_updates:
		draw_usec += Time.get_ticks_usec() - started

func _attach_effect(balloon: BalloonState, attack: AttackSpec, time: float) -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	var data: DamageOverTimeDefinition = attack.damage_over_time
	var now: float = _batch_start + time * _batch_delta if _batch_delta > 0.0 else effect_clock
	if not damage_effects.has(balloon.id):
		damage_effects[balloon.id] = {}
	var families: Dictionary = damage_effects[balloon.id]
	var effect: Dictionary = families.get(data.family, {})
	if effect.is_empty() or effect.generation != balloon.shell_generation or effect.shell != balloon.definition or effect.expires < now - 0.000000001:
		var kind: AttackSpec.Attribute = attack.attribute if data.attribute_override < 0 else data.attribute_override as AttackSpec.Attribute
		var tick: AttackSpec = AttackSpec.new(data.damage, 1, kind)
		tick.source_id = attack.source_id
		tick.detects_camo = attack.detects_camo
		effect = {"id": balloon.id, "family": data.family, "shell": balloon.definition,
			"generation": balloon.shell_generation, "attack": tick, "color": data.color, "interval": maxf(0.001, data.interval),
			"next": now + maxf(0.001, data.interval), "expires": now + data.duration}
		families[data.family] = effect
	else:
		# Refresh expiration, never reset tick phase or steal the original owner.
		effect.expires = maxf(effect.expires, now + data.duration)
	if tick_sink.is_valid():
		_schedule_effect(effect)
	if profile_updates:
		profile_usec.effect_apply += Time.get_ticks_usec() - started

func _schedule_effect(effect: Dictionary) -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	while effect.next <= effect_clock + 0.000000001 and effect.next <= effect.expires + 0.000000001:
		tick_sink.call(effect, clampf((effect.next - _batch_start) / _batch_delta, 0.0, 1.0))
		effect.next += effect.interval
	if profile_updates:
		profile_usec.dot_schedule += Time.get_ticks_usec() - started

func begin_effect_batch(delta: float) -> void:
	var started: int = Time.get_ticks_usec() if profile_updates and not damage_effects.is_empty() else 0
	_batch_start = effect_clock
	_batch_delta = delta
	effect_clock += delta
	var ids: Array = damage_effects.keys()
	ids.sort()
	for id: int in ids:
		var families: Array = damage_effects[id].keys()
		families.sort()
		for family: StringName in families:
			_schedule_effect(damage_effects[id][family])
	if started > 0:
		profile_usec.effect_update += Time.get_ticks_usec() - started

func apply_effect_tick(effect: Dictionary, time: float) -> void:
	var balloon: BalloonState = balloon_system.find(effect.id)
	if balloon == null or balloon.definition != effect.shell or balloon.shell_generation != effect.generation or time > balloon.exit_time:
		return
	dot_ticks += 1
	_count_auxiliary(effect.attack.source_id, &"dot_ticks", 1)
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	apply_hit(balloon.id, effect.attack, time)
	if profile_updates:
		profile_usec.dot_damage += Time.get_ticks_usec() - started

func finish_effect_batch() -> void:
	var started: int = Time.get_ticks_usec() if profile_updates and not damage_effects.is_empty() else 0
	for id: int in damage_effects.keys():
		var balloon: BalloonState = balloon_system.find(id)
		if balloon == null:
			damage_effects.erase(id)
			continue
		for family: StringName in damage_effects[id].keys():
			var effect: Dictionary = damage_effects[id][family]
			if effect.expires <= effect_clock + 0.000000001 or effect.shell != balloon.definition or effect.generation != balloon.shell_generation:
				damage_effects[id].erase(family)
		if damage_effects[id].is_empty():
			damage_effects.erase(id)
	if started > 0:
		profile_usec.effect_update += Time.get_ticks_usec() - started
	tick_sink = Callable()
	_batch_delta = 0.0

func _count_auxiliary(source: int, field: StringName, capacity: int = 0) -> void:
	if battle_stats != null and battle_stats.enabled and battle_stats.records.has(source):
		var stats: TowerCombatStats = battle_stats.records[source]
		stats.set(field, stats.get(field) + 1)
		stats.pierce_available += capacity
