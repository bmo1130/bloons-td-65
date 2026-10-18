class_name ProjectileSystem
extends Node2D

var balloon_system: BalloonSystem
var projectiles: Array[ProjectileState] = []
var _next_id: int = 1
# Diagnostic count for checking that local shots avoid a full balloon scan.
var collision_checks: int = 0

func fire(at: Vector2, target: BalloonState, definition: TowerDefinition) -> ProjectileState:
	var aim: Vector2 = target.position
	# Lead along the actual route (including corners); the dart then flies straight.
	if target.motion_duration > 0.0 and definition.projectile_speed > 0.0:
		for iteration in range(5):
			var flight_time: float = at.distance_to(aim) / definition.projectile_speed
			aim = balloon_system.route.position_at(target.distance + target.definition.speed * flight_time)
	var shot: ProjectileState = launch(at, at.direction_to(aim), definition)
	if shot != null:
		shot.target_id = target.id
	return shot

func launch(at: Vector2, direction: Vector2, definition: TowerDefinition) -> ProjectileState:
	if definition.pierce <= 0 or direction.is_zero_approx():
		return null
	var shot: ProjectileState = ProjectileState.new(_next_id, at, direction, definition)
	_next_id += 1
	projectiles.append(shot)
	return shot

func update(delta: float) -> void:
	if delta <= 0.0:
		return
	collision_checks = 0
	var hits: Array[Dictionary] = []
	for shot in projectiles:
		var start: Vector2 = shot.position
		var displacement: Vector2 = shot.direction * shot.speed * delta
		var active_fraction: float = clampf(shot.lifetime / delta, 0.0, 1.0)
		var end: Vector2 = start + displacement * active_fraction
		var bounds: Rect2 = Rect2(start, Vector2.ZERO).expand(end).grow(shot.radius)
		for balloon in balloon_system.candidates_in_rect(bounds):
			if shot.hit_ids.has(balloon.id) or balloon_system.find(balloon.id) == null:
				continue
			collision_checks += 1
			var time: float = _contact_time(start, displacement, shot, balloon)
			if time <= active_fraction:
				hits.append({"time": time, "shot": shot, "balloon_id": balloon.id,
					"position": start + displacement * time, "start": start,
					"travel": displacement,
					"radius": balloon.definition.radius, "until": active_fraction})
		shot.position = end
		shot.lifetime -= delta
	# Resolve all darts chronologically, then by stable IDs for simultaneous hits.
	# Candidate arrays are snapshots; removal cannot invalidate their iteration.
	hits.sort_custom(_hit_before)
	var cursor: int = 0
	while cursor < hits.size():
		var hit: Dictionary = hits[cursor]
		cursor += 1
		var shot: ProjectileState = hit.shot
		var balloon_id: int = hit.balloon_id
		if shot.remaining_pierce <= 0 or shot.hit_ids.has(balloon_id):
			continue
		var balloon: BalloonState = balloon_system.find(balloon_id)
		if balloon == null:
			continue
		if balloon.definition.radius != hit.radius:
			# An earlier dart can shrink a layer's circle. Recheck and reinsert the
			# later contact rather than granting a hit at the old, larger radius.
			var time: float = _contact_time(hit.start, hit.travel, shot, balloon)
			if time > hit.until:
				continue
			hit.radius = balloon.definition.radius
			hit.time = time
			hit.position = hit.start + hit.travel * time
			_insert_hit(hits, cursor, hit)
			continue
		shot.hit_ids[balloon_id] = true
		shot.remaining_pierce -= 1
		balloon_system.damage(balloon_id, shot.damage)
		if shot.remaining_pierce == 0:
			shot.position = hit.position
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = projectiles[index]
		if shot.remaining_pierce <= 0 or shot.lifetime <= 0.0:
			projectiles.remove_at(index)
	queue_redraw()

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

func _contact_time(start: Vector2, travel: Vector2, shot: ProjectileState, balloon: BalloonState) -> float:
	var radius: float = shot.radius + balloon.definition.radius
	var points: PackedVector2Array = balloon.motion_points
	for index in range(points.size() - 1):
		var from_time: float = balloon.motion_times[index]
		var duration: float = balloon.motion_times[index + 1] - from_time
		if duration <= 0.0:
			continue
		var relative_start: Vector2 = start + travel * from_time - points[index]
		var relative_travel: Vector2 = travel * duration - (points[index + 1] - points[index])
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
	for shot in projectiles:
		draw_line(shot.position - shot.direction * 10.0, shot.position, Color("f7e9b7"), 3.0, true)
		draw_circle(shot.position, shot.radius, Color("ffffff"))
