class_name ProjectileSystem
extends Node2D

var balloon_system: BalloonSystem
var combat: CombatSystem
var battle_stats: BattleStatistics
var projectiles: Array[ProjectileState] = []
var _next_id: int = 1
# Diagnostic count for checking that local shots avoid a full balloon scan.
var collision_checks: int = 0
var ricochet_bounds: Rect2 = GameRoute.BUILD_BOUNDS
var ricochet_obstacles: Array[Rect2] = [] # Projectile-only rectangular bumpers.
var split_effects: Array[Dictionary] = []
var profile_updates: bool = false
var profile_usec: Dictionary = {"trajectory": 0, "candidates": 0, "narrow": 0, "resolution": 0, "creation": 0, "removal": 0, "sort": 0}
var draw_usec: int = 0

func reset_profile() -> void:
	profile_usec = {"trajectory": 0, "candidates": 0, "narrow": 0, "resolution": 0, "creation": 0, "removal": 0, "sort": 0}

func _aim_direction(at: Vector2, target: BalloonState, definition: TowerDefinition) -> Vector2:
	var aim: Vector2 = target.position
	# Lead along the actual route (including corners); the dart then flies straight.
	if target.motion_duration > 0.0 and definition.projectile_speed > 0.0:
		for iteration in range(5):
			var flight_time: float = at.distance_to(aim) / definition.projectile_speed
			var distance: float = target.distance + target.speed * flight_time
			if target.stun_remaining > 0.0:
				distance = target.distance + target.speed * maxf(0.0, flight_time - target.stun_remaining)
			if target.pending_push > 0.0:
				distance = maxf(0.0, distance - target.pending_push)
			aim = balloon_system.route.position_at(distance)
	return at.direction_to(aim)

func fire(at: Vector2, target: BalloonState, definition: TowerDefinition, source_id: int = 0) -> ProjectileState:
	var shot: ProjectileState = launch(at, _aim_direction(at, target, definition), definition, source_id)
	if shot != null:
		shot.target_id = target.id
		if battle_stats != null:
			battle_stats.record_volley(source_id)
	return shot

func fire_volley(at: Vector2, target: BalloonState, definition: TowerDefinition, source_id: int = 0, critical: bool = false, spawn_fraction: float = 0.0, recursive: bool = false) -> int:
	var heading: Vector2 = _aim_direction(at, target, definition)
	var launched: int = 0
	for index in range(definition.projectile_count):
		var angle: float = definition.heading_offset_degrees
		if definition.projectile_count > 1:
			angle += definition.spread_degrees * (float(index) / (definition.projectile_count - 1) - 0.5)
		var shot: ProjectileState = launch(at, heading.rotated(deg_to_rad(angle)), definition, source_id)
		if shot != null:
			shot.target_id = target.id
			shot.recursive = recursive
			shot.spawn_fraction = spawn_fraction
			shot.attack.critical = critical
			if critical:
				shot.attack.damage = definition.critical_damage
			launched += 1
	if launched > 0 and battle_stats != null:
		battle_stats.record_volley(source_id, critical)
	return launched

func launch(at: Vector2, direction: Vector2, definition: TowerDefinition, source_id: int = 0, split_child: bool = false) -> ProjectileState:
	if definition.pierce <= 0 or direction.is_zero_approx():
		return null
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	var shot: ProjectileState = ProjectileState.new(_next_id, at, direction, definition)
	shot.attack.source_id = source_id
	_next_id += 1
	projectiles.append(shot)
	if battle_stats != null:
		battle_stats.record_projectile(source_id, definition.pierce, split_child)
	if profile_updates:
		profile_usec.creation += Time.get_ticks_usec() - started
	return shot

func update(delta: float) -> void:
	if delta <= 0.0:
		return
	collision_checks = 0
	for index in range(split_effects.size() - 1, -1, -1):
		split_effects[index].remaining -= delta
		if split_effects[index].remaining <= 0.0:
			split_effects.remove_at(index)
	var max_eligible_id: int = balloon_system.latest_id()
	var hits: Array[Dictionary] = []
	for shot in projectiles:
		if shot.targeted_only:
			var target: BalloonState = balloon_system.find(shot.target_id)
			if target == null or not target.definition.moab_class:
				shot.remaining_pierce = 0
				continue
			shot.direction = shot.position.direction_to(target.position)
		_collect_hits(shot, delta, max_eligible_id, hits)
	# Resolve all darts chronologically, then by stable IDs for simultaneous hits.
	# Candidate arrays are snapshots; removal cannot invalidate their iteration.
	var profiled_at: int = Time.get_ticks_usec() if profile_updates else 0
	hits.sort_custom(_hit_before)
	if profile_updates:
		profile_usec.sort += Time.get_ticks_usec() - profiled_at
		profiled_at = Time.get_ticks_usec()
	var cursor: int = 0
	while cursor < hits.size():
		var hit: Dictionary = hits[cursor]
		cursor += 1
		var shot: ProjectileState = hit.shot
		if hit.get("expire", false):
			if shot.remaining_pierce <= 0:
				continue
			if shot.timed_explosion:
				combat.explode(hit.position, shot.attack, hit.time, max_eligible_id, shot.hit_ids)
			_emit_splits(shot, hit.position, shot.direction, hit.time, delta, max_eligible_id, hits, cursor, true)
			shot.remaining_pierce = 0
			continue
		var balloon_id: int = hit.balloon_id
		if shot.remaining_pierce <= 0 or shot.was_hit(balloon_id, hit.epoch):
			continue
		var balloon: BalloonState = balloon_system.find(balloon_id)
		if balloon == null:
			continue
		if not combat.can_detect(balloon, shot.attack.detects_camo):
			continue # Invisible contacts cannot even trigger a bomb's explosion.
		if balloon.definition.radius != hit.radius:
			# An earlier dart can shrink a layer's circle. Recheck and reinsert the
			# later contact rather than granting a hit at the old, larger radius.
			var time: float = _contact_time(hit.start, hit.travel, shot, balloon, hit.from, hit.until)
			if time > hit.until:
				continue
			hit.radius = balloon.definition.radius
			hit.time = time
			hit.position = hit.start + hit.travel * time
			_insert_hit(hits, cursor, hit)
			continue
		if shot.attack.explosion_radius > 0.0:
			# The physical contact only triggers a blast: no separate direct damage.
			combat.explode(hit.position, shot.attack, hit.time, max_eligible_id, shot.hit_ids)
			shot.remaining_pierce = 0
		else:
			var exclusions: Dictionary = shot.hit_ids if shot.max_bounces <= 0 else {}
			if combat.apply_hit(balloon_id, shot.attack, hit.time, exclusions) > 0:
				shot.remaining_pierce -= 1
			if shot.max_bounces > 0:
				shot.hit_epochs[balloon_id] = hit.epoch
				shot.hit_ids[balloon_id] = true
				for excluded_id: int in exclusions:
					if excluded_id != balloon_id:
						shot.child_ids[excluded_id] = true
		if shot.remaining_pierce == 0:
			shot.position = hit.position
			shot.end_fraction = hit.time
		_emit_splits(shot, hit.position, hit.travel.normalized(), hit.time, delta, max_eligible_id, hits, cursor, shot.remaining_pierce <= 0, shot.attack.explosion_radius > 0.0)
	if profile_updates:
		profile_usec.resolution += Time.get_ticks_usec() - profiled_at
		profiled_at = Time.get_ticks_usec()
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = projectiles[index]
		if shot.remaining_pierce <= 0 or shot.lifetime <= 0.0:
			projectiles.remove_at(index)
	if profile_updates:
		profile_usec.removal += Time.get_ticks_usec() - profiled_at
	queue_redraw()

func _collect_hits(shot: ProjectileState, delta: float, max_id: int, hits: Array[Dictionary], first: int = -1) -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	var segments: Array[Dictionary] = _trajectory(shot, delta)
	if profile_updates:
		profile_usec.trajectory += Time.get_ticks_usec() - started
	for segment in segments:
		if shot.timed_explosion:
			continue # Fused cluster bombs travel before their independent AoE.
		var bounds: Rect2 = Rect2(segment.at, Vector2.ZERO).expand(segment.end).grow(shot.radius)
		if profile_updates:
			started = Time.get_ticks_usec()
		var candidates: Array[BalloonState] = balloon_system.candidates_in_rect(bounds)
		if profile_updates:
			profile_usec.candidates += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
		for balloon in candidates:
			if shot.targeted_only and balloon.id != shot.target_id:
				continue
			if shot.was_hit(balloon.id, segment.epoch) or balloon.id > max_id or balloon_system.find(balloon.id) == null:
				continue
			collision_checks += 1
			var time: float = _contact_time(segment.start, segment.travel, shot, balloon, segment.from, segment.until)
			if time <= segment.until:
				var hit: Dictionary = {"time": time, "shot": shot, "balloon_id": balloon.id,
					"position": segment.start + segment.travel * time, "start": segment.start,
					"travel": segment.travel, "from": segment.from, "epoch": segment.epoch,
					"radius": balloon.definition.radius, "until": segment.until}
				if first < 0:
					hits.append(hit)
				else:
					_insert_hit(hits, first, hit)
		if profile_updates:
			profile_usec.narrow += Time.get_ticks_usec() - started
	if (shot.split != null or shot.timed_explosion) and shot.lifetime <= 0.0:
		var expiration: Dictionary = {"time": shot.end_fraction, "shot": shot, "balloon_id": 9223372036854775807,
			"position": shot.position, "expire": true}
		if first < 0:
			hits.append(expiration)
		else:
			_insert_hit(hits, first, expiration)
	shot.spawn_fraction = 0.0

func _emit_splits(shot: ProjectileState, at: Vector2, heading: Vector2, time: float, delta: float, max_id: int, hits: Array[Dictionary], first: int, force: bool, detonated: bool = false) -> void:
	if shot.split == null:
		return
	if shot.split.on_explosion and not detonated:
		return
	var used: int = shot.initial_pierce - shot.remaining_pierce
	while shot.split_bursts < shot.split.thresholds.size():
		var required: int = ceili(shot.initial_pierce * shot.split.thresholds[shot.split_bursts])
		if not force and used < required:
			break
		var phase: float = deg_to_rad(shot.split.burst_rotation_degrees * shot.split_bursts)
		shot.split_bursts += 1 # Commit before creating children, including forced expiration.
		for index in range(shot.split.count_per_burst):
			var direction: Vector2 = heading.rotated(phase + TAU * index / shot.split.count_per_burst)
			var child: ProjectileState = launch(at, direction, shot.child_profile, shot.attack.source_id, true)
			if child != null:
				child.spawn_fraction = time
				_collect_hits(child, delta, max_id, hits, first)
		split_effects.append({"position": at, "remaining": 0.14})
		if shot.recursive and shot.secondary_profile != null:
			# Exactly one additional ring of at most eight, committed with the base burst.
			for index in range(shot.split.secondary_count):
				var direction: Vector2 = heading.rotated(TAU * index / shot.split.secondary_count + PI / 8.0)
				var child: ProjectileState = launch(at, direction, shot.secondary_profile, shot.attack.source_id, true)
				if child != null:
					child.spawn_fraction = time
					_collect_hits(child, delta, max_id, hits, first)

func _trajectory(shot: ProjectileState, delta: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var from: float = shot.spawn_fraction
	var until: float = minf(1.0, from + maxf(0.0, shot.lifetime) / delta)
	var at: Vector2 = shot.position
	var bounds: Rect2 = ricochet_bounds.grow(-shot.radius)
	if shot.max_bounces > 0:
		at = at.clamp(bounds.position, bounds.end)
	while from < until:
		var travel: Vector2 = shot.direction * shot.speed * delta
		var span: float = until - from
		var tx: float = INF
		var ty: float = INF
		var obstacle_time: float = INF
		var obstacle_normal: Vector2 = Vector2.ZERO
		if shot.max_bounces > 0:
			if absf(travel.x) > 0.000001:
				tx = ((bounds.end.x if travel.x > 0.0 else bounds.position.x) - at.x) / travel.x
			if absf(travel.y) > 0.000001:
				ty = ((bounds.end.y if travel.y > 0.0 else bounds.position.y) - at.y) / travel.y
			for obstacle in ricochet_obstacles:
				var contact: Vector3 = _obstacle_contact(at, travel, obstacle.grow(shot.radius))
				if contact.x < obstacle_time:
					obstacle_time = contact.x
					obstacle_normal = Vector2(contact.y, contact.z)
		span = maxf(0.0, minf(span, minf(minf(tx, ty), obstacle_time)))
		var end: Vector2 = at + travel * span
		if span > 0.0000001:
			segments.append({"at": at, "end": end, "start": at - travel * from,
				"travel": travel, "from": from, "until": from + span, "epoch": shot.bounces})
		from += span
		at = end
		if from >= until - 0.0000001:
			break
		if shot.bounces >= shot.max_bounces:
			shot.lifetime = 0.0
			break
		if is_equal_approx(span, tx):
			shot.direction.x *= -1.0
		if is_equal_approx(span, ty):
			shot.direction.y *= -1.0
		if is_equal_approx(span, obstacle_time):
			shot.direction = shot.direction.bounce(obstacle_normal)
			at += obstacle_normal * 0.001
		shot.bounces += 1
	shot.position = at
	shot.end_fraction = from
	shot.lifetime -= delta * (1.0 - shot.spawn_fraction)
	return segments

func _obstacle_contact(at: Vector2, travel: Vector2, box: Rect2) -> Vector3:
	# Ray/slab entry. Newly emitted children inside a bumper may leave freely.
	if box.grow(-0.0001).has_point(at):
		return Vector3(INF, 0, 0)
	var enter: float = -INF
	var leave: float = INF
	var normal: Vector2 = Vector2.ZERO
	for axis in range(2):
		if absf(travel[axis]) < 0.000001:
			if at[axis] < box.position[axis] or at[axis] > box.end[axis]:
				return Vector3(INF, 0, 0)
			continue
		var near: float = (box.position[axis] - at[axis]) / travel[axis]
		var far: float = (box.end[axis] - at[axis]) / travel[axis]
		var sign: float = -1.0
		if near > far:
			var swap: float = near
			near = far
			far = swap
			sign = 1.0
		if near > enter:
			enter = near
			normal = Vector2.ZERO
			normal[axis] = sign
		leave = minf(leave, far)
	return Vector3(maxf(0.0, enter), normal.x, normal.y) if enter >= -0.000001 and leave >= maxf(0.0, enter) else Vector3(INF, 0, 0)

func _insert_hit(hits: Array[Dictionary], first: int, hit: Dictionary) -> void:
	var last: int = hits.size()
	while first < last:
		var middle: int = (first + last) / 2
		if _hit_before(hit, hits[middle]):
			last = middle
		else:
			first = middle + 1
	hits.insert(first, hit)

func _hit_before(a: Dictionary, b: Dictionary) -> bool:
	if a.time != b.time:
		return a.time < b.time
	var first: ProjectileState = a.shot
	var second: ProjectileState = b.shot
	if first.id != second.id:
		return first.id < second.id
	return a.balloon_id < b.balloon_id

func _contact_time(start: Vector2, travel: Vector2, shot: ProjectileState, balloon: BalloonState, from: float = 0.0, until: float = 1.0) -> float:
	var radius: float = shot.radius + balloon.definition.radius
	var points: PackedVector2Array = balloon.motion_points
	for index in range(points.size() - 1):
		var from_time: float = maxf(from, balloon.motion_times[index])
		var to_time: float = minf(until, balloon.motion_times[index + 1])
		var duration: float = to_time - from_time
		if duration <= 0.0:
			continue
		var point: Vector2 = balloon.position_at_time(from_time) if from > 0.0 else points[index]
		var end: Vector2 = balloon.position_at_time(to_time) if until < 1.0 else points[index + 1]
		var relative_start: Vector2 = start + travel * from_time - point
		var relative_travel: Vector2 = travel * duration - (end - point)
		var local_time: float = _circle_entry(relative_start, relative_travel, radius)
		if local_time <= 1.0:
			var time: float = from_time + local_time * duration
			return time if time <= balloon.exit_time else INF
	return INF

func _circle_entry(relative_start: Vector2, relative_travel: Vector2, radius: float) -> float:
	var c: float = relative_start.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var a: float = relative_travel.length_squared()
	if a <= 0.000001:
		return INF
	var b: float = relative_start.dot(relative_travel)
	var discriminant: float = b * b - a * c
	if discriminant < 0.0:
		return INF
	var time: float = (-b - sqrt(discriminant)) / a
	return time if time >= 0.0 and time <= 1.0 else INF

func _draw() -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	for obstacle in ricochet_obstacles:
		draw_rect(obstacle, Color("677781"))
		draw_rect(obstacle, Color("b9c7ce"), false, 2.0)
	for effect in split_effects:
		draw_arc(effect.position, 22.0 * (1.0 - effect.remaining / 0.28), 0, TAU, 16, Color(1, 0.7, 0.3, effect.remaining / 0.14), 2.0)
	for shot in projectiles:
		if shot.max_bounces > 0:
			draw_circle(shot.position, shot.radius, Color("364453"))
			for spike in range(8):
				var axis: Vector2 = Vector2.RIGHT.rotated(spike * TAU / 8.0)
				draw_line(shot.position + axis * shot.radius * 0.5, shot.position + axis * (shot.radius + 4.0), Color("e7d48a"), 3.0, true)
		elif shot.attack.explosion_radius > 0.0:
			draw_circle(shot.position, shot.radius + 1.0, Color("15252b"))
			draw_circle(shot.position, shot.radius, Color("f4b765"))
		elif shot.attack.attribute == AttackSpec.Attribute.PLASMA:
			draw_line(shot.position - shot.direction * 8.0, shot.position, Color("ab62ed"), shot.radius * 1.5, true)
			draw_circle(shot.position, shot.radius, Color("eed5ff"))
		else:
			draw_line(shot.position - shot.direction * shot.length, shot.position, Color("ffcf5d") if shot.attack.critical else Color("f7e9b7"), maxf(3.0, shot.radius), true)
			draw_circle(shot.position, shot.radius, Color("ffffff"))
	if profile_updates:
		draw_usec += Time.get_ticks_usec() - started
