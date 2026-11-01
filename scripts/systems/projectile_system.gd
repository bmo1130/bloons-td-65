class_name ProjectileSystem
extends Node2D

var balloon_system: BalloonSystem
var combat: CombatSystem
var battle_stats: BattleStatistics
var projectiles: Array[ProjectileState] = []
var pending_areas: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _event_cursor: int = -1
var _step_delta: float = 0.0
var instances_created: int = 0 # Actual ProjectileState constructors; auxiliary event IDs are separate.
var _next_id: int = 1
# Diagnostic count for checking that local shots avoid a full balloon scan.
var collision_checks: int = 0
var ricochet_bounds: Rect2 = GameRoute.BUILD_BOUNDS
var ricochet_obstacles: Array[Rect2] = [] # Projectile-only rectangular bumpers.
var split_effects: Array[Dictionary] = []
var profile_updates: bool = false
var profile_usec: Dictionary = {"trajectory": 0, "candidates": 0, "narrow": 0, "resolution": 0, "creation": 0, "removal": 0, "sort": 0}
var draw_usec: int = 0
const CURVE_SEGMENTS: int = 64
var trajectory_segments: int = 0
var chain_search_usec: int = 0
var chain_search_total_usec: int = 0
var trajectory_segments_total: int = 0
var flight_broadphase_enabled: bool = true # Exact conservative rejection, optional measurement control.
var trace: CombatTrace # Optional detailed diagnostic pass; never used by combat decisions.
var chain_cache_mode: int = 3 # 0 reference, 1 membership, 2 native ranking, 3 distance-first misses.
var _resolving: bool = false
var _chain_origin: Vector2 = Vector2.INF
var _chain_time: float = -1.0
var _chain_radius: float = -1.0
var _chain_max_id: int = -1
var _chain_candidates: Array[BalloonState] = []
var _chain_ordered: PackedFloat64Array
var _chain_groups: Dictionary = {} # Exact squared distance -> original candidate references.
var _chain_cache_uses: int = 0

func reset_profile() -> void:
	profile_usec = {"trajectory": 0, "candidates": 0, "narrow": 0, "resolution": 0, "creation": 0, "removal": 0, "sort": 0}
	chain_search_usec = 0

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
	var heading: Vector2 = _aim_direction(at, target, definition)
	var reach: float = -1.0
	if definition.flight_mode == TowerDefinition.Flight.CURVE:
		var aim: Vector3 = _curve_aim(at, target, definition)
		heading = Vector2(aim.x, aim.y)
		reach = aim.z
	var shot: ProjectileState = launch(at, heading, definition, source_id, false, reach)
	if shot != null:
		shot.target_id = target.id
		if battle_stats != null:
			battle_stats.record_volley(source_id)
	return shot

func fire_volley(at: Vector2, target: BalloonState, definition: TowerDefinition, source_id: int = 0, critical: bool = false, spawn_fraction: float = 0.0, recursive: bool = false, return_at: Vector2 = Vector2.INF, phase_degrees: float = 0.0) -> int:
	var radial: bool = definition.attack_pattern == TowerDefinition.AttackPattern.RADIAL
	var heading: Vector2 = Vector2.RIGHT if radial else _aim_direction(at, target, definition)
	var reach: float = -1.0
	if not radial and definition.flight_mode == TowerDefinition.Flight.CURVE:
		var aim: Vector3 = _curve_aim(at, target, definition)
		heading = Vector2(aim.x, aim.y)
		reach = aim.z
	var launched: int = 0
	for index in range(definition.projectile_count):
		var angle: float = definition.heading_offset_degrees
		if radial:
			angle += phase_degrees
			angle += 360.0 * index / definition.projectile_count
		elif definition.projectile_count > 1:
			angle += definition.spread_degrees * (float(index) / (definition.projectile_count - 1) - 0.5)
		var shot: ProjectileState = launch(at, heading.rotated(deg_to_rad(angle)), definition, source_id, false, reach, return_at)
		if shot != null:
			shot.target_id = target.id if target != null and not radial else -1
			shot.recursive = recursive
			shot.spawn_fraction = spawn_fraction
			shot.attack.critical = critical
			if critical:
				shot.attack.damage = definition.critical_damage
			launched += 1
	if launched > 0 and battle_stats != null:
		battle_stats.record_volley(source_id, critical)
	return launched

func launch(at: Vector2, direction: Vector2, definition: TowerDefinition, source_id: int = 0, split_child: bool = false, reach: float = -1.0, return_at: Vector2 = Vector2.INF) -> ProjectileState:
	if definition.pierce <= 0 or direction.is_zero_approx():
		return null
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	var shot: ProjectileState = ProjectileState.new(_next_id, at, direction, definition)
	instances_created += 1
	if shot.flight_mode == TowerDefinition.Flight.CURVE or shot.flight_mode == TowerDefinition.Flight.RETURN:
		_prepare_flight(shot, shot.flight_distance if reach < 0.0 else reach, at if return_at == Vector2.INF else return_at)
	shot.attack.source_id = source_id
	_next_id += 1
	projectiles.append(shot)
	if battle_stats != null:
		battle_stats.record_projectile(source_id, definition.pierce, split_child)
	if profile_updates:
		profile_usec.creation += Time.get_ticks_usec() - started
	return shot

func _curve_aim(at: Vector2, target: BalloonState, data: TowerDefinition) -> Vector3:
	var aim: Vector2 = target.position
	var reach: float = clampf(at.distance_to(aim), 32.0, data.flight_distance)
	if target.motion_duration > 0.0:
		for iteration in range(5):
			var a: float = reach * 0.5
			var b: float = data.curve_width
			# Half ellipse perimeter estimates arrival at the outward tip. The
			# actual flight/collision always uses the authored 64-segment path.
			var time: float = PI * 0.5 * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b))) / data.projectile_speed
			aim = balloon_system.route.position_at(maxf(0.0, target.distance - target.pending_push + target.speed * maxf(0.0, time - target.stun_remaining)))
			reach = clampf(at.distance_to(aim), 32.0, data.flight_distance)
	var heading: Vector2 = at.direction_to(aim)
	return Vector3(heading.x, heading.y, reach)

func _prepare_flight(shot: ProjectileState, reach: float, return_at: Vector2) -> void:
	var origin: Vector2 = shot.position
	shot.flight_points.append(origin)
	if shot.flight_mode == TowerDefinition.Flight.CURVE:
		for index in range(1, CURVE_SEGMENTS + 1):
			var phase: float = TAU * index / CURVE_SEGMENTS
			var local: Vector2 = Vector2(reach * (1.0 - cos(phase)) * 0.5, shot.curve_width * sin(phase))
			shot.flight_points.append(origin + shot.direction * local.x + shot.direction.orthogonal() * local.y)
	else:
		shot.flight_points.append(origin + shot.direction * reach)
	if shot.return_flight and shot.flight_points[-1].distance_squared_to(return_at) > 0.000001:
		shot.flight_points.append(return_at)

func _flight_trajectory(shot: ProjectileState, delta: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var from: float = shot.spawn_fraction
	var until: float = minf(1.0, from + maxf(0.0, shot.lifetime) / delta)
	shot.age_origin = shot.age - from * delta
	var at: Vector2 = shot.position
	while from < until and shot.flight_index + 1 < shot.flight_points.size():
		var destination: Vector2 = shot.flight_points[shot.flight_index + 1]
		var distance: float = at.distance_to(destination)
		if distance <= 0.000001:
			shot.flight_index += 1
			continue
		var heading: Vector2 = at.direction_to(destination)
		var span: float = minf(until - from, distance / (shot.speed * delta))
		var travel: Vector2 = heading * shot.speed * delta
		var end: Vector2 = at + travel * span
		segments.append({"at": at, "end": end, "start": at - travel * from, "travel": travel, "from": from, "until": from + span, "epoch": 0})
		shot.direction = heading
		from += span
		at = end
		if distance <= shot.speed * delta * span + 0.000001:
			shot.flight_index += 1
	shot.position = at
	shot.end_fraction = from
	shot.age += (from - shot.spawn_fraction) * delta
	shot.lifetime -= (from - shot.spawn_fraction) * delta
	if shot.flight_index + 1 >= shot.flight_points.size():
		shot.lifetime = 0.0
	shot.frame_segments = segments
	return segments

func update(delta: float) -> void:
	if delta <= 0.0:
		return
	_resolving = true
	collision_checks = 0
	trajectory_segments = 0
	for index in range(split_effects.size() - 1, -1, -1):
		split_effects[index].remaining -= delta
		if split_effects[index].remaining <= 0.0:
			split_effects.remove_at(index)
	var max_eligible_id: int = balloon_system.latest_id()
	_step_delta = delta
	var hits: Array[Dictionary] = pending_areas
	pending_areas = []
	_events = hits
	_event_cursor = -1
	combat.tick_sink = _queue_effect_tick
	combat.begin_effect_batch(delta)
	var queue_started: int = Time.get_ticks_usec() if trace != null else 0
	if trace != null:
		trace.add("event_arrays")
	for shot in projectiles:
		if shot.targeted_only:
			var target: BalloonState = balloon_system.find(shot.target_id)
			if target == null or not target.definition.moab_class:
				shot.remaining_pierce = 0
				continue
			shot.direction = shot.position.direction_to(target.position)
		_collect_hits(shot, delta, max_eligible_id, hits)
	if trace != null:
		trace.elapsed("queue_build_usec", queue_started)
		trace.add("initial_events", hits.size())
		trace.peak("queue_peak", hits.size())
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
		_event_cursor = cursor
		if hit.has("area"):
			_area_capacity(hit.area)
			combat.explode(hit.position, hit.area, hit.time, max_eligible_id, null, hit.visual)
			continue
		if hit.has("dot"):
			combat.apply_effect_tick(hit.dot, hit.time)
			continue
		var shot: ProjectileState = hit.shot
		if hit.has("revision") and hit.revision != shot.flight_revision:
			if trace != null:
				trace.add("invalid_revision")
			continue
		if trace != null:
			trace.add("events_processed")
			if trace.record_events:
				trace.events.append([shot.id, hit.balloon_id, hit.time, hit.get("expire", false)])
		if hit.get("expire", false):
			if shot.remaining_pierce <= 0:
				continue
			_end_burst(shot, hit.position, hit.time, max_eligible_id)
			if shot.timed_explosion:
				combat.explode(hit.position, shot.attack, hit.time, max_eligible_id, shot.hit_ids, shot.area_visual)
			_emit_splits(shot, hit.position, shot.direction, hit.time, delta, max_eligible_id, hits, cursor, true)
			shot.remaining_pierce = 0
			continue
		var balloon_id: int = hit.balloon_id
		if shot.remaining_pierce <= 0 or shot.was_hit(balloon_id, hit.epoch):
			if trace != null:
				trace.add("invalid_consumed_or_hit")
			continue
		var balloon: BalloonState = balloon_system.find(balloon_id)
		if balloon == null:
			if trace != null:
				trace.add("invalid_dead")
			if shot.flight_mode == TowerDefinition.Flight.CHAIN:
				_continue_chain(shot, hit, delta, max_eligible_id, hits, cursor)
			continue
		if shot.rehit_interval > 0.0 and not shot.can_rehit(balloon_id, shot.age_origin + hit.time * delta):
			_queue_rehit(shot, balloon, hit.time, delta, hits, cursor)
			continue
		if (shot.attack.moab_only and not balloon.definition.moab_class) or not combat.can_detect(balloon, shot.attack.detects_camo):
			continue # Invisible contacts cannot even trigger a bomb's explosion.
		if balloon.definition.radius != hit.radius:
			# An earlier dart can shrink a layer's circle. Recheck and reinsert the
			# later contact rather than granting a hit at the old, larger radius.
			var time: float = _contact_time(hit.start, hit.travel, shot, balloon, hit.from, hit.until)
			if time > hit.until:
				if shot.rehit_interval > 0.0:
					_queue_rehit(shot, balloon, hit.until, delta, hits, cursor)
				elif shot.flight_mode == TowerDefinition.Flight.CHAIN:
					_continue_chain(shot, hit, delta, max_eligible_id, hits, cursor)
				continue
			hit.radius = balloon.definition.radius
			hit.time = time
			hit.position = hit.start + hit.travel * time
			_insert_hit(hits, cursor, hit)
			continue
		if shot.attack.explosion_radius > 0.0:
			# The physical contact only triggers a blast: no separate direct damage.
			combat.explode(hit.position, shot.attack, hit.time, max_eligible_id, shot.hit_ids, shot.area_visual)
			shot.remaining_pierce = 0
		else:
			var exclusions: Dictionary = shot.hit_ids if shot.max_bounces <= 0 and shot.rehit_interval <= 0.0 else {}
			if combat.apply_hit(balloon_id, shot.attack, hit.time, exclusions) > 0:
				shot.remaining_pierce -= 1
			if shot.max_bounces > 0:
				shot.hit_epochs[balloon_id] = hit.epoch
				shot.hit_ids[balloon_id] = true
				for excluded_id: int in exclusions:
					if excluded_id != balloon_id:
						shot.child_ids[excluded_id] = true
			if shot.rehit_interval > 0.0:
				shot.hit_times[balloon_id] = shot.age_origin + hit.time * delta
				shot.hit_ids[balloon_id] = true
				for excluded_id: int in exclusions:
					if excluded_id != balloon_id:
						shot.child_ids[excluded_id] = true
		if shot.remaining_pierce == 0:
			shot.position = hit.position
			shot.end_fraction = hit.time
			_end_burst(shot, hit.position, hit.time, max_eligible_id)
		if shot.flight_mode == TowerDefinition.Flight.CHAIN:
			if shot.remaining_pierce > 0:
				_continue_chain(shot, hit, delta, max_eligible_id, hits, cursor)
			continue
		if shot.rehit_interval > 0.0 and shot.remaining_pierce > 0 and balloon_system.find(balloon_id) != null:
			_queue_rehit(shot, balloon, hit.time, delta, hits, cursor)
		_emit_splits(shot, hit.position, hit.travel.normalized(), hit.time, delta, max_eligible_id, hits, cursor, shot.remaining_pierce <= 0, shot.attack.explosion_radius > 0.0)
	if profile_updates:
		profile_usec.resolution += Time.get_ticks_usec() - profiled_at
		profiled_at = Time.get_ticks_usec()
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = projectiles[index]
		if shot.remaining_pierce <= 0 or shot.lifetime <= 0.0:
			projectiles.remove_at(index)
		elif shot.projectile_style >= TowerDefinition.ProjectileStyle.RANG and shot.projectile_style <= TowerDefinition.ProjectileStyle.KYLIE:
			shot.trail.append(shot.position)
			if shot.trail.size() > 12:
				shot.trail.remove_at(0)
	if profile_updates:
		profile_usec.removal += Time.get_ticks_usec() - profiled_at
	combat.finish_effect_batch()
	_events = []
	_event_cursor = -1
	_resolving = false
	if _chain_time >= 0.0:
		_chain_candidates.clear()
		_chain_ordered.clear()
		_chain_groups.clear()
		_chain_cache_uses = 0
		_chain_time = -1.0
	queue_redraw()

func _collect_hits(shot: ProjectileState, delta: float, max_id: int, hits: Array[Dictionary], first: int = -1) -> void:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	if shot.flight_mode == TowerDefinition.Flight.CHAIN:
		shot.age_origin = shot.age - shot.spawn_fraction * delta
		var target: BalloonState = balloon_system.find(shot.target_id)
		if target == null or target.id > max_id or _chain_excluded(shot, target.id, shot.spawn_fraction) or not combat.can_attack(target, shot.attack.attribute, shot.attack.detects_camo):
			target = _chain_target(shot, shot.spawn_fraction, max_id)
		if target == null:
			_end_burst(shot, shot.position, shot.spawn_fraction, max_id)
			shot.remaining_pierce = 0
			return
		var heading_started: int = Time.get_ticks_usec() if trace != null else 0
		shot.target_id = target.id
		shot.direction = shot.position.direction_to(target.position)
		if trace != null:
			trace.elapsed("chain_heading_usec", heading_started)
		shot.age_origin = shot.age - shot.spawn_fraction * delta
		shot.flight_revision += 1
	var segments: Array[Dictionary] = _trajectory(shot, delta)
	if trace != null:
		trace.add("segment_arrays")
		trace.add("segment_dictionaries", segments.size())
	trajectory_segments += segments.size()
	if profile_updates:
		trajectory_segments_total += segments.size()
	var queued: Dictionary = {} # At most one pending Kylie contact per ID.
	if shot.flight_mode == TowerDefinition.Flight.CHAIN:
		shot.age += (shot.end_fraction - shot.spawn_fraction) * delta
	if profile_updates:
		profile_usec.trajectory += Time.get_ticks_usec() - started
	for segment in segments:
		if shot.timed_explosion:
			continue # Fused cluster bombs travel before their independent AoE.
		var bounds_started: int = Time.get_ticks_usec() if trace != null else 0
		var bounds: Rect2 = Rect2(segment.at, Vector2.ZERO).expand(segment.end).grow(shot.radius)
		if trace != null:
			trace.elapsed("aabb_usec", bounds_started)
		if profile_updates:
			started = Time.get_ticks_usec()
		var candidates: Array[BalloonState] = []
		if shot.flight_mode == TowerDefinition.Flight.CHAIN:
			var target: BalloonState = balloon_system.find(shot.target_id)
			if target != null:
				candidates.append(target)
		else:
			candidates = balloon_system.candidates_in_rect(bounds)
		if profile_updates:
			profile_usec.candidates += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
		# The grid bounds contain every balloon motion point plus its radius.
		# A disjoint swept-shot AABB cannot touch; surviving blades still use
		# the unchanged exact relative-circle test and chronological event queue.
		for balloon in candidates:
			if flight_broadphase_enabled and (shot.flight_mode == TowerDefinition.Flight.CURVE or shot.flight_mode == TowerDefinition.Flight.RETURN or shot.projectile_style == TowerDefinition.ProjectileStyle.BLADE) and not bounds.intersects(balloon.broadphase_bounds, true):
				continue
			if shot.rehit_interval > 0.0 and queued.has(balloon.id):
				continue
			if shot.attack.moab_only and not balloon.definition.moab_class:
				continue
			if shot.targeted_only and balloon.id != shot.target_id:
				continue
			if shot.was_hit(balloon.id, segment.epoch) or balloon.id > max_id or balloon_system.find(balloon.id) == null:
				continue
			collision_checks += 1
			var from: float = segment.from
			if shot.rehit_interval > 0.0 and shot.hit_times.has(balloon.id):
				from = maxf(from, (float(shot.hit_times[balloon.id]) + shot.rehit_interval - shot.age_origin) / delta)
			var time: float = _contact_time(segment.start, segment.travel, shot, balloon, from, segment.until)
			if time <= segment.until:
				if trace != null:
					trace.add("event_dictionaries")
				var hit: Dictionary = {"time": time, "shot": shot, "balloon_id": balloon.id,
					"position": segment.start + segment.travel * time, "start": segment.start,
					"travel": segment.travel, "from": segment.from, "epoch": segment.epoch,
					"radius": balloon.definition.radius, "until": segment.until}
				if shot.flight_mode == TowerDefinition.Flight.CHAIN:
					hit.revision = shot.flight_revision
				if shot.rehit_interval > 0.0:
					queued[balloon.id] = true
				if first < 0:
					hits.append(hit)
				else:
					_insert_hit(hits, first, hit)
		if profile_updates:
			profile_usec.narrow += Time.get_ticks_usec() - started
	if (shot.split != null or shot.timed_explosion or shot.end_explosion != null or shot.flight_mode == TowerDefinition.Flight.CHAIN) and shot.lifetime <= 0.0:
		if trace != null:
			trace.add("event_dictionaries")
		var expiration: Dictionary = {"time": shot.end_fraction, "shot": shot, "balloon_id": 9223372036854775807,
			"position": shot.position, "expire": true}
		if shot.flight_mode == TowerDefinition.Flight.CHAIN:
			expiration.revision = shot.flight_revision
		if first < 0:
			hits.append(expiration)
		else:
			_insert_hit(hits, first, expiration)
	shot.spawn_fraction = 0.0

func _chain_target(shot: ProjectileState, time: float, max_id: int) -> BalloonState:
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	if trace != null:
		trace.query(shot.position, time, shot.chain_range)
	var candidates: Array[BalloonState] = _chain_candidates_at(shot, time, max_id)
	var best: BalloonState
	if chain_cache_mode >= 2 and _resolving and _chain_cache_uses >= 2:
		best = _chain_ordered_target(shot, time, max_id, candidates)
	elif chain_cache_mode >= 3:
		best = _chain_scan_nearest(shot, time, max_id, candidates)
	else:
		best = _chain_scan(shot, time, max_id, candidates)
	if profile_updates:
		var elapsed: int = Time.get_ticks_usec() - started
		chain_search_usec += elapsed
		chain_search_total_usec += elapsed
	return best

func _chain_scan_nearest(shot: ProjectileState, time: float, max_id: int, candidates: Array[BalloonState]) -> BalloonState:
	# Eligibility cannot change the winner unless this exact distance/ID beats
	# the best live candidate already found. No radius or precision is reduced.
	var started: int = Time.get_ticks_usec() if trace != null else 0
	var best: BalloonState
	var nearest: float = shot.chain_range * shot.chain_range
	for candidate in candidates:
		var distance: float = shot.position.distance_squared_to(candidate.position_at_time(time))
		if trace != null:
			trace.add("candidate_visits")
			trace.add("distance_calculations")
			trace.add("priority_comparisons")
		if distance > nearest or (distance == nearest and best != null and candidate.id >= best.id):
			if trace != null:
				trace.add("pruned_not_nearer")
			continue
		if candidate.id > max_id or _chain_excluded(shot, candidate.id, time) or balloon_system.find(candidate.id) == null or time > candidate.exit_time:
			if trace != null:
				trace.add("rejected_live_or_id")
			continue
		if not combat.can_attack(candidate, shot.attack.attribute, shot.attack.detects_camo):
			if trace != null:
				trace.add("rejected_immunity" if combat.can_detect(candidate, shot.attack.detects_camo) else "rejected_camo")
			continue
		best = candidate
		nearest = distance
		if trace != null:
			trace.add("eligible_candidates")
	if trace != null:
		trace.elapsed("chain_scan_usec", started)
	return best

func _chain_scan(shot: ProjectileState, time: float, max_id: int, candidates: Array[BalloonState]) -> BalloonState:
	var best: BalloonState
	var nearest: float = shot.chain_range * shot.chain_range
	var scan_started: int = Time.get_ticks_usec() if trace != null else 0
	for candidate in candidates:
		if trace != null:
			trace.add("candidate_visits")
		if candidate.id > max_id:
			if trace != null:
				trace.add("rejected_new_id")
			continue
		if _chain_excluded(shot, candidate.id, time):
			if trace != null:
				trace.add("rejected_hit")
			continue
		if balloon_system.find(candidate.id) == null or time > candidate.exit_time:
			if trace != null:
				trace.add("rejected_dead_or_exit")
			continue
		if not combat.can_attack(candidate, shot.attack.attribute, shot.attack.detects_camo):
			if trace != null:
				trace.add("rejected_immunity" if combat.can_detect(candidate, shot.attack.detects_camo) else "rejected_camo")
			continue
		var distance_started: int = Time.get_ticks_usec() if trace != null else 0
		var distance: float = shot.position.distance_squared_to(candidate.position_at_time(time))
		if trace != null:
			trace.elapsed("distance_usec", distance_started)
			trace.add("distance_calculations")
			trace.add("priority_comparisons")
			trace.add("eligible_candidates" if distance <= shot.chain_range * shot.chain_range else "rejected_distance")
		if distance < nearest or (distance == nearest and (best == null or candidate.id < best.id)):
			best = candidate
			nearest = distance
	if trace != null:
		trace.elapsed("chain_scan_usec", scan_started)
	return best

func _chain_ordered_target(shot: ProjectileState, time: float, max_id: int, candidates: Array[BalloonState]) -> BalloonState:
	# Motion is immutable inside this projectile batch. Only distances/IDs are
	# ranked: live HP/layer/camo/immunity/exclusions are checked on every lookup.
	if _chain_ordered.is_empty():
		var started: int = Time.get_ticks_usec() if trace != null else 0
		for candidate in candidates:
			var distance: float = shot.position.distance_squared_to(candidate.position_at_time(time))
			if not _chain_groups.has(distance):
				_chain_ordered.append(distance)
				_chain_groups[distance] = []
			_chain_groups[distance].append(candidate)
		if trace != null:
			trace.add("ranking_builds")
			trace.add("ranking_dictionaries")
			trace.add("ranking_arrays", _chain_ordered.size())
			trace.add("distance_calculations", candidates.size())
			trace.elapsed("ranking_build_usec", started)
			started = Time.get_ticks_usec()
		_chain_ordered.sort() # Native float64 order; IDs are compared live inside exact ties.
		if trace != null:
			trace.elapsed("ranking_sort_usec", started)
	var started: int = Time.get_ticks_usec() if trace != null else 0
	var best: BalloonState
	var limit: float = shot.chain_range * shot.chain_range
	for distance in _chain_ordered:
		if distance > limit:
			if trace != null:
				trace.add("rejected_distance")
			break
		for candidate: BalloonState in _chain_groups[distance]:
			if trace != null:
				trace.add("candidate_visits")
				trace.add("priority_comparisons")
			if candidate.id > max_id:
				if trace != null:
					trace.add("rejected_new_id")
				continue
			if _chain_excluded(shot, candidate.id, time):
				if trace != null:
					trace.add("rejected_hit")
				continue
			if balloon_system.find(candidate.id) == null or time > candidate.exit_time:
				if trace != null:
					trace.add("rejected_dead_or_exit")
				continue
			if not combat.can_attack(candidate, shot.attack.attribute, shot.attack.detects_camo):
				if trace != null:
					trace.add("rejected_immunity" if combat.can_detect(candidate, shot.attack.detects_camo) else "rejected_camo")
				continue
			if best == null or candidate.id < best.id:
				best = candidate
			if trace != null:
				trace.add("eligible_candidates")
		if best != null:
			break
	if trace != null:
		trace.elapsed("chain_scan_usec", started)
	return best

func _chain_candidates_at(shot: ProjectileState, time: float, max_id: int) -> Array[BalloonState]:
	var reusable: bool = chain_cache_mode > 0 and _resolving
	if reusable and _chain_origin == shot.position and _chain_time == time and _chain_radius == shot.chain_range and _chain_max_id == max_id:
		_chain_cache_uses += 1
		if trace != null:
			trace.add("candidate_cache_hits")
		return _chain_candidates
	var started: int = Time.get_ticks_usec() if trace != null else 0
	var candidates: Array[BalloonState] = balloon_system.candidates_in_rect(Rect2(shot.position, Vector2.ZERO).grow(shot.chain_range))
	if reusable:
		_chain_ordered.clear()
		_chain_groups.clear()
		_chain_cache_uses = 1
		_chain_origin = shot.position
		_chain_time = time
		_chain_radius = shot.chain_range
		_chain_max_id = max_id
		_chain_candidates = candidates
	if trace != null:
		trace.elapsed("chain_query_usec", started)
		trace.add("chain_grid_queries")
		trace.add("query_arrays")
		trace.add("query_seen_dictionaries")
		trace.add("candidate_count", candidates.size())
		trace.peak("candidate_max", candidates.size())
	return candidates

func _continue_chain(shot: ProjectileState, hit: Dictionary, delta: float, max_id: int, hits: Array[Dictionary], first: int) -> void:
	if trace != null:
		trace.add("chain_continuations")
	var refunded: float = maxf(0.0, shot.end_fraction - float(hit.time)) * delta
	shot.lifetime += refunded
	shot.age -= refunded
	shot.position = hit.position
	shot.spawn_fraction = hit.time
	shot.flight_revision += 1
	shot.age_origin = shot.age - hit.time * delta
	var target: BalloonState = _chain_target(shot, hit.time, max_id)
	if target == null:
		_end_burst(shot, hit.position, hit.time, max_id)
		shot.remaining_pierce = 0
		return
	shot.target_id = target.id
	_collect_hits(shot, delta, max_id, hits, first)

func _queue_rehit(shot: ProjectileState, balloon: BalloonState, after: float, delta: float, hits: Array[Dictionary], first: int) -> void:
	if shot.child_ids.has(balloon.id):
		return
	var from: float = after + 0.000000001
	if shot.hit_times.has(balloon.id):
		from = maxf(from, (float(shot.hit_times[balloon.id]) + shot.rehit_interval - shot.age_origin) / delta)
	for segment in shot.frame_segments:
		if segment.until < from:
			continue
		var time: float = _contact_time(segment.start, segment.travel, shot, balloon, maxf(from, segment.from), segment.until)
		if time <= segment.until:
			_insert_hit(hits, first, {"time": time, "shot": shot, "balloon_id": balloon.id, "position": segment.start + segment.travel * time,
				"start": segment.start, "travel": segment.travel, "from": maxf(from, segment.from), "until": segment.until, "epoch": 0, "radius": balloon.definition.radius})
			return

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
	if shot.flight_mode == TowerDefinition.Flight.CURVE or shot.flight_mode == TowerDefinition.Flight.RETURN:
		return _flight_trajectory(shot, delta)
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
	var started: int = Time.get_ticks_usec() if trace != null else 0
	var last: int = hits.size()
	while first < last:
		var middle: int = (first + last) / 2
		if _hit_before(hit, hits[middle]):
			last = middle
		else:
			first = middle + 1
	hits.insert(first, hit)
	if trace != null:
		trace.add("dynamic_events")
		trace.peak("queue_peak", hits.size())
		trace.elapsed("event_insert_usec", started)

func _hit_before(a: Dictionary, b: Dictionary) -> bool:
	if a.time != b.time:
		return a.time < b.time
	var first: int = a.order if a.has("order") else a.shot.id
	var second: int = b.order if b.has("order") else b.shot.id
	if first != second:
		return first < second
	return a.balloon_id < b.balloon_id

func _contact_time(start: Vector2, travel: Vector2, shot: ProjectileState, balloon: BalloonState, from: float = 0.0, until: float = 1.0) -> float:
	var started: int = Time.get_ticks_usec() if trace != null else 0
	if trace != null:
		trace.add("contact_calculations")
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
			if trace != null:
				trace.elapsed("contact_usec", started)
			return time if time <= balloon.exit_time else INF
	if trace != null:
		trace.elapsed("contact_usec", started)
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
		if shot.projectile_style == TowerDefinition.ProjectileStyle.METEOR:
			draw_line(shot.position - shot.direction * 26, shot.position, Color("e6532d"), 12, true)
			draw_circle(shot.position, shot.radius, Color("ffb33d"))
			draw_circle(shot.position - shot.direction * 2, shot.radius * 0.5, Color("fff0a1"))
		elif shot.projectile_style == TowerDefinition.ProjectileStyle.TACK:
			var color: Color = Color("ffd36b") if shot.attack.attribute == AttackSpec.Attribute.NORMAL else Color("e9edf5")
			draw_line(shot.position - shot.direction * shot.length, shot.position, color, shot.radius * 2, true)
		elif shot.projectile_style == TowerDefinition.ProjectileStyle.BLADE:
			var blade: PackedVector2Array = []
			for point in range(12):
				blade.append(shot.position + Vector2.from_angle(shot.age * 9.0 + point * TAU / 12.0) * shot.radius * (1.0 if point % 2 == 0 else 0.6))
			draw_colored_polygon(blade, Color("bedbe9"))
			draw_circle(shot.position, shot.radius * 0.2, Color("456477"))
		elif shot.projectile_style >= TowerDefinition.ProjectileStyle.RANG and shot.projectile_style <= TowerDefinition.ProjectileStyle.KYLIE:
			if shot.trail.size() > 1:
				draw_polyline(shot.trail, Color(1.0, 0.75, 0.35, 0.3), 2.0, true)
			var rotation: float = shot.age * TAU * 3.0
			var color: Color = Color("ffbd54") if shot.projectile_style == TowerDefinition.ProjectileStyle.RANG else Color("93c9ff")
			if shot.attack.attribute == AttackSpec.Attribute.NORMAL:
				color = Color("ff7054")
			if shot.attack.press_distance > 0.0:
				color = Color("ffd958")
				draw_arc(shot.position, shot.radius + 5, 0, TAU, 16, color, 2, true)
			if shot.projectile_style == TowerDefinition.ProjectileStyle.GLAIVE:
				for blade in range(3):
					var axis: Vector2 = Vector2.RIGHT.rotated(rotation + TAU * blade / 3.0)
					draw_line(shot.position - axis * 4.0, shot.position + axis * 11.0, Color("15252b"), 6.0, true)
					draw_line(shot.position, shot.position + axis * 10.0, color, 3.0, true)
			else:
				var axis: Vector2 = Vector2.RIGHT.rotated(rotation)
				var points: PackedVector2Array = PackedVector2Array([shot.position + axis.rotated(-0.85) * 13.0, shot.position, shot.position + axis.rotated(0.85) * 13.0])
				draw_polyline(points, Color("15252b"), 8.0, true)
				draw_polyline(points, color, 4.5 if shot.projectile_style == TowerDefinition.ProjectileStyle.KYLIE else 3.0, true)
		elif shot.max_bounces > 0:
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

func _chain_excluded(shot: ProjectileState, id: int, time: float) -> bool:
	if shot.rehit_interval <= 0.0:
		return shot.hit_ids.has(id)
	return not shot.can_rehit(id, shot.age_origin + time * _step_delta)

func queue_area(at: Vector2, profile: TowerDefinition, source: int, time: float) -> void:
	var attack: AttackSpec = profile.make_attack()
	attack.source_id = source
	pending_areas.append({"area": attack, "position": at, "time": time, "order": _next_id,
		"balloon_id": 0, "visual": profile.area_visual})
	_next_id += 1

func _queue_effect_tick(effect: Dictionary, time: float) -> void:
	var event: Dictionary = {"dot": effect, "time": time, "order": _next_id, "balloon_id": effect.id}
	_next_id += 1
	if _event_cursor < 0:
		_events.append(event)
	else:
		_insert_hit(_events, _event_cursor, event)

func _end_burst(shot: ProjectileState, at: Vector2, time: float, max_id: int) -> void:
	if shot.end_emitted or shot.end_explosion == null:
		return
	shot.end_emitted = true
	var attack: AttackSpec = shot.end_explosion.make_attack()
	attack.source_id = shot.attack.source_id
	# New shell IDs born this batch are excluded; existing survivors may receive
	# the intentional independent blast after the physical special hit.
	_area_capacity(attack)
	combat.explode(at, attack, time, max_id)

func _area_capacity(attack: AttackSpec) -> void:
	if battle_stats != null and battle_stats.enabled and battle_stats.records.has(attack.source_id):
		battle_stats.records[attack.source_id].pierce_available += attack.pierce
