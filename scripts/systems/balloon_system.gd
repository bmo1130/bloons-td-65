class_name BalloonSystem
extends Node2D

signal layer_popped(reward: int)
signal leaked(damage: int)

var route: GameRoute
var combat: CombatSystem
var balloons: Array[BalloonState] = []
var _by_id: Dictionary = {}
var _next_id: int = 1
var _spatial: BalloonSpatialIndex = BalloonSpatialIndex.new()
var _spatial_dirty: bool = true
var _pending_leaks: Array[BalloonState] = []
var profile_spatial: bool = false
var profile_draw: bool = false
var draw_usec: int = 0
var profile_changes: bool = false
var spawn_usec: int = 0
var spawn_count: int = 0
var removal_usec: int = 0
var removal_count: int = 0
var peak_active_count: int = 0

func spawn(definition: BalloonDefinition, distance: float = 0.0, camo: bool = false, fortified: bool = false, spill: bool = false, regrow: bool = false) -> BalloonState:
	var started: int = Time.get_ticks_usec() if profile_changes else 0
	var balloon: BalloonState = BalloonState.new(_next_id, definition, route.position_at(distance))
	balloon.camo = camo or definition.default_camo
	balloon.regrow = regrow
	if fortified:
		balloon.set_layer(definition, true)
	balloon.spill_damage = balloon.spill_damage or spill
	balloon.distance = distance
	_next_id += 1
	balloon.array_index = balloons.size()
	balloons.append(balloon)
	_by_id[balloon.id] = balloon
	_spatial_dirty = true
	queue_redraw()
	if profile_changes:
		spawn_usec += Time.get_ticks_usec() - started
		spawn_count += 1
		peak_active_count = maxi(peak_active_count, balloons.size())
	return balloon

func find(id: int) -> BalloonState:
	return _by_id.get(id) as BalloonState

func update(delta: float, defer_leaks: bool = false) -> void:
	_pending_leaks.clear()
	for index in range(balloons.size() - 1, -1, -1):
		var balloon: BalloonState = balloons[index]
		var old_distance: float = balloon.distance
		balloon.motion_start_distance = old_distance
		var backwards: float = minf(delta, balloon.knockback_remaining)
		balloon.knockback_remaining = maxf(0.0, balloon.knockback_remaining - delta)
		balloon.distance = maxf(0.0, balloon.distance + balloon.speed * (
			delta - backwards - backwards * balloon.knockback_multiplier))
		balloon.exit_time = INF
		if balloon.distance >= route.total_length:
			if not defer_leaks:
				_remove(index)
				leaked.emit(balloon.leak_damage())
				continue
			balloon.exit_time = clampf((route.total_length - old_distance) / maxf(balloon.distance - old_distance, 0.000001), 0.0, 1.0)
			balloon.distance = route.total_length
			_pending_leaks.append(balloon)
		balloon.position = route.position_at(balloon.distance)
		balloon.record_motion(route.motion_between(old_distance, balloon.distance), delta, minf(balloon.exit_time, 1.0))
	_spatial_dirty = true
	queue_redraw()

func resolve_leaks() -> void:
	# Existing darts may hit before an exit within this step. Charge only the
	# layers that remain after these impacts, and never hit a balloon after exit.
	for balloon in _pending_leaks:
		if find(balloon.id) != null:
			_remove(balloon.array_index)
			leaked.emit(balloon.leak_damage())
	_pending_leaks.clear()

func candidates_in_rect(bounds: Rect2) -> Array[BalloonState]:
	_spatial.profiling = profile_spatial
	if _spatial_dirty:
		_spatial.rebuild(balloons)
		_spatial_dirty = false
	return _spatial.query(bounds)

func reset_spatial_metrics() -> void:
	_spatial.reset_metrics()

func spatial_metrics() -> Dictionary:
	return {"build_usec": _spatial.build_usec, "query_usec": _spatial.query_usec,
		"builds": _spatial.build_count, "queries": _spatial.query_count,
		"candidates": _spatial.candidate_count}

func damage(id: int, amount: int, attribute: AttackSpec.Attribute = AttackSpec.Attribute.SHARP) -> int:
	# Compatibility entry point for v0.1/v0.2 logic tests. All rules still go
	# through the same combat resolver used by direct hits and explosions.
	return combat.apply_hit(id, AttackSpec.new(amount, 1, attribute))

func latest_id() -> int:
	return _next_id - 1

func peel_layer(balloon: BalloonState, time: float, excluded: Dictionary) -> bool:
	var definition: BalloonDefinition = balloon.definition
	if not definition.split_children.is_empty():
		var distance: float = balloon.distance_at_time(time)
		var position: Vector2 = balloon.position_at_time(time)
		_remove(balloon.array_index)
		for child_definition: BalloonDefinition in definition.split_children:
			var child: BalloonState = spawn(child_definition, distance, balloon.camo, balloon.fortified and definition.inherit_fortified, balloon.spill_damage, balloon.regrow or definition.children_regrow)
			child.position = position
			child.record_motion(PackedVector2Array([position, position]), 0.0)
			# Children born exactly at the exit leak in this finalize. Those born
			# before a parent's future exit keep the normal stationary birth tick.
			if balloon.exit_time <= time + 0.000001:
				child.exit_time = balloon.exit_time
				child.distance = route.total_length
				_pending_leaks.append(child)
			excluded[child.id] = true
		return true
	if definition.next_layer != null:
		balloon.set_layer(definition.next_layer, balloon.fortified and definition.inherit_fortified)
	else:
		_remove(balloon.array_index)
	return false

func _remove(index: int) -> void:
	var started: int = Time.get_ticks_usec() if profile_changes else 0
	_by_id.erase(balloons[index].id)
	balloons[index].array_index = -1
	var last: BalloonState = balloons.pop_back()
	if index < balloons.size():
		balloons[index] = last
		last.array_index = index
	# Stale index entries are safe: consumers resolve IDs before applying hits.
	if profile_changes:
		removal_usec += Time.get_ticks_usec() - started
		removal_count += 1

func _draw() -> void:
	var started: int = Time.get_ticks_usec() if profile_draw else 0
	for balloon in balloons:
		var at: Vector2 = balloon.position
		var radius: float = balloon.definition.radius
		if balloon.definition.appearance >= 6:
			_draw_blimp(balloon)
			continue
		draw_circle(at + Vector2(2, 4), radius + 2.0, Color(0.02, 0.07, 0.09, 0.3))
		draw_line(at + Vector2(0, radius), at + Vector2(-2, radius + 8), Color("e4e6d9"), 1.0, true)
		draw_circle(at, radius + 1.5, Color("17252c"))
		draw_circle(at, radius, balloon.definition.color)
		draw_circle(at + Vector2(-4, -4), radius * 0.26, Color(1, 1, 1, 0.4))
		if balloon.definition.appearance == 1:
			draw_arc(at, radius - 3.0, 0.2, 2.9, 16, Color("dadbe4"), 2.0, true)
		elif balloon.definition.appearance == 2:
			draw_line(at + Vector2(-9, 0), at + Vector2(9, 0), Color("d4dae0"), 3.0, true)
			draw_circle(at + Vector2(5, 5), 2.0, Color("313d49"))
		elif balloon.definition.appearance == 3:
			for offset in [-7.0, 0.0, 7.0]:
				draw_line(at + Vector2(offset - 3, -9), at + Vector2(offset + 3, 9), Color("20252e"), 4.0, true)
		elif balloon.definition.appearance == 4:
			var rainbow: Array[Color] = [Color("f46c72"), Color("f5b75a"), Color("f3e878"), Color("71d99b"), Color("6ca5e7"), Color("bc83df")]
			for band in range(6):
				draw_arc(at, radius - band * 2.0, PI, TAU, 18, rainbow[band], 2.5, true)
		elif balloon.definition.appearance == 5:
			draw_arc(at, radius - 4, 0.2, 2.9, 20, Color("e9af74"), 2.0, true)
			if balloon.shell_hp < balloon.shell_max_hp:
				var crack: PackedVector2Array = PackedVector2Array([at + Vector2(-2, -11), at + Vector2(3, -4), at + Vector2(-3, 2), at + Vector2(5, 10)])
				draw_polyline(crack, Color("35281d"), 2.0, true)
				if balloon.shell_hp * 2 <= balloon.shell_max_hp:
					draw_line(at + Vector2(-3, 2), at + Vector2(-12, 7), Color("35281d"), 2.0, true)
		if balloon.camo:
			for patch in [Vector2(-7, -3), Vector2(5, 5), Vector2(2, -8)]:
				draw_circle(at + patch, 4.0, Color("304b37"))
			draw_arc(at, radius + 1, 0.2, 2.5, 14, Color("9cc58b"), 2.0, true)
		if balloon.fortified:
			for offset in [-6.0, 6.0]:
				draw_line(at + Vector2(-radius + 2, offset), at + Vector2(radius - 2, offset), Color("e2cdae"), 4.0, true)
				draw_circle(at + Vector2(radius - 5, offset), 1.7, Color("71675c"))
		if balloon.regrow:
			draw_arc(at, radius + 4, 3.5, 5.5, 12, Color("ee9ac5"), 1.5, true)
	if profile_draw:
		draw_usec += Time.get_ticks_usec() - started

func _draw_blimp(balloon: BalloonState) -> void:
	var r: float = balloon.definition.radius
	var direction: Vector2 = route.position_at(minf(route.total_length, balloon.distance + 1.0)) - route.position_at(maxf(0.0, balloon.distance - 1.0))
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	draw_set_transform(balloon.position, direction.angle())
	var hull: PackedVector2Array = PackedVector2Array()
	for index in range(40):
		var angle: float = TAU * index / 40.0
		hull.append(Vector2(cos(angle) * r, sin(angle) * r * 0.63))
	draw_colored_polygon(hull, balloon.definition.color)
	hull.append(hull[0])
	draw_polyline(hull, Color("111e29"), 2.5, true)
	# Tail fins and a bright nose make path direction visible at corners.
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7, 0), Vector2(-r, -r * 0.7), Vector2(-r * 0.35, -r * 0.35)]), Color("cfdae5"))
	draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7, 0), Vector2(-r, r * 0.7), Vector2(-r * 0.35, r * 0.35)]), Color("cfdae5"))
	draw_arc(Vector2.ZERO, r * 0.68, -0.55, 0.55, 12, Color("d9f4ff"), 3.0, true)
	for x in [-0.4, 0.2]:
		draw_line(Vector2(r * x, -r * 0.5), Vector2(r * x, r * 0.5), Color("d3e7df"), 3.0, true)
	if balloon.definition.appearance == 7:
		# Dark armored arrow/vent pattern, distinct from the blue MOAB.
		for x in [-0.45, -0.1, 0.25]:
			draw_line(Vector2(r * x, -r * 0.35), Vector2(r * (x + 0.15), r * 0.35), Color("121b24"), 5, true)
	elif balloon.definition.appearance == 8:
		draw_arc(Vector2.ZERO, r * 0.38, 0, TAU, 24, Color("d8a8ed"), 4, true)
		draw_line(Vector2(-r * 0.15, -r * 0.2), Vector2(r * 0.2, r * 0.2), Color("211c38"), 6, true)
	for stage in range(balloon.damage_stage()):
		var x: float = r * (-0.3 + stage * 0.3)
		draw_polyline(PackedVector2Array([Vector2(x - 5, -r * 0.4), Vector2(x + 3, -2), Vector2(x - 4, r * 0.35)]), Color("132020"), 3.0, true)
	if balloon.camo:
		for x in [-0.55, 0.0, 0.55]:
			draw_circle(Vector2(x * r, -r * 0.2), r * 0.17, Color("537d41"))
	if balloon.fortified:
		for y in [-0.25, 0.25]:
			draw_line(Vector2(-r * 0.78, y * r), Vector2(r * 0.78, y * r), Color("d9b98b"), 4.0, true)
			draw_circle(Vector2(r * 0.65, y * r), 2.5, Color("756555"))
	draw_set_transform(Vector2.ZERO)
	var bar: Rect2 = Rect2(balloon.position + Vector2(-r, r * 0.8), Vector2(r * 2, 4))
	draw_rect(bar, Color("142329"))
	bar.size.x *= float(balloon.shell_hp) / balloon.shell_max_hp
	draw_rect(bar, Color("8de0a0"))
