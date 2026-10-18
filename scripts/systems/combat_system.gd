class_name CombatSystem
extends Node2D

signal exploded(position: Vector2, radius: float)

var balloon_system: BalloonSystem
var battle_stats: BattleStatistics
var effects: Array[Dictionary] = []
var aoe_candidates: int = 0

func can_damage(definition: BalloonDefinition, attribute: AttackSpec.Attribute) -> bool:
	return (definition.immunity_mask & (1 << attribute)) == 0

func can_detect(balloon: BalloonState, detects_camo: bool) -> bool:
	return not balloon.camo or detects_camo

func can_attack(balloon: BalloonState, attribute: AttackSpec.Attribute, detects_camo: bool = false) -> bool:
	return can_detect(balloon, detects_camo) and can_damage(balloon.definition, attribute)

func apply_hit(id: int, attack: AttackSpec, time: float = 1.0, excluded_ids: Variant = null) -> int:
	var excluded: Dictionary = {} if excluded_ids == null else excluded_ids
	var balloon: BalloonState = balloon_system.find(id)
	if balloon == null or excluded.has(id):
		return 0
	excluded[id] = true
	var original: BalloonDefinition = balloon.definition
	var armored: bool = balloon.fortified
	var damage: int = attack.damage + (attack.ceramic_bonus if original.ceramic else 0) + (attack.fortified_bonus if armored else 0) + (attack.lead_bonus if original.lead else 0)
	# One compact accumulator per contact, shared through the data tree. Children
	# do not create more attack events or consume additional pierce.
	var result: Array[int] = [0, 0, 0, 0, 0, 0] # normal shells actual_hp reward immune damaged_ids
	_damage_layers(balloon, maxi(0, damage), attack, time, excluded, result)
	if result[2] > 0 and balloon_system.find(id) != null and original.knockback_allowed and attack.knockback_duration > 0.0:
		# Motion already resolved this tick is immutable. Status starts next tick.
		balloon.knockback_remaining = maxf(balloon.knockback_remaining, attack.knockback_duration)
		var heavy: bool = original.heavy or original.ceramic or armored
		balloon.knockback_multiplier = maxf(0.0, attack.knockback_heavy if heavy else attack.knockback_light)
	if result[3] > 0:
		balloon_system.layer_popped.emit(result[3])
	if battle_stats != null:
		battle_stats.record_hit(attack.source_id, result[0], result[1], result[4] > 0, attack.critical, result[2], result[5], result[4])
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
			if balloon.spill_damage and amount > 0:
				var last_child: int = balloon_system.latest_id()
				for child_id in range(first_child, last_child + 1):
					var child: BalloonState = balloon_system.find(child_id)
					if child != null:
						_damage_layers(child, amount, attack, time, excluded, result)
			return
		if balloon_system.find(balloon.id) == null:
			return

func explode(center: Vector2, attack: AttackSpec, time: float = 1.0, max_id: int = 2147483647, excluded_ids: Variant = null) -> Array[int]:
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
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
	var hit_ids: Array[int] = []
	for candidate in candidates:
		if hit_ids.size() >= attack.pierce:
			break
		var id: int = candidate.id
		if excluded.has(id):
			continue
		if apply_hit(id, attack, time, excluded) > 0:
			hit_ids.append(id)
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
	for effect in effects:
		var alpha: float = clampf(effect.remaining / 0.28, 0.0, 1.0)
		draw_circle(effect.position, effect.radius, Color(1.0, 0.65, 0.23, alpha * 0.13))
		draw_arc(effect.position, effect.radius * (1.0 - alpha * 0.25), 0.0, TAU, 48, Color(1.0, 0.77, 0.37, alpha), 2.5, true)
