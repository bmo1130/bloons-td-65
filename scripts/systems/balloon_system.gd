class_name BalloonSystem
extends Node2D

signal layer_popped(reward: int)
signal leaked(damage: int)

var route: GameRoute
var balloons: Array[BalloonState] = []
var _by_id: Dictionary = {}
var _next_id: int = 1
var _spatial: BalloonSpatialIndex = BalloonSpatialIndex.new()
var _spatial_dirty: bool = true
var _pending_leaks: Array[BalloonState] = []

func spawn(definition: BalloonDefinition) -> BalloonState:
	var balloon: BalloonState = BalloonState.new(_next_id, definition, route.position_at(0))
	_next_id += 1
	balloon.array_index = balloons.size()
	balloons.append(balloon)
	_by_id[balloon.id] = balloon
	_spatial_dirty = true
	queue_redraw()
	return balloon

func find(id: int) -> BalloonState:
	return _by_id.get(id) as BalloonState

func update(delta: float, defer_leaks: bool = false) -> void:
	_pending_leaks.clear()
	for index in range(balloons.size() - 1, -1, -1):
		var balloon: BalloonState = balloons[index]
		var old_distance: float = balloon.distance
		balloon.distance += balloon.definition.speed * delta
		balloon.exit_time = INF
		if balloon.distance >= route.total_length:
			if not defer_leaks:
				_remove(index)
				leaked.emit(balloon.definition.leak_damage)
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
			leaked.emit(balloon.definition.leak_damage)
	_pending_leaks.clear()

func candidates_in_rect(bounds: Rect2) -> Array[BalloonState]:
	if _spatial_dirty:
		_spatial.rebuild(balloons)
		_spatial_dirty = false
	return _spatial.query(bounds)

func damage(id: int, amount: int) -> int:
	var balloon: BalloonState = find(id)
	if balloon == null:
		return 0
	var removed_layers: int = 0
	var reward: int = 0
	for layer in range(maxi(0, amount)):
		var definition: BalloonDefinition = balloon.definition
		removed_layers += 1
		reward += definition.pop_reward
		if definition.next_layer != null:
			balloon.definition = definition.next_layer
		else:
			_remove(balloon.array_index)
			break
	# Finish mutations before notifying listeners; overkill never pays twice.
	if reward > 0:
		layer_popped.emit(reward)
	queue_redraw()
	return removed_layers

func _remove(index: int) -> void:
	_by_id.erase(balloons[index].id)
	balloons[index].array_index = -1
	var last: BalloonState = balloons.pop_back()
	if index < balloons.size():
		balloons[index] = last
		last.array_index = index
	# Stale index entries are safe: consumers resolve IDs before applying hits.

func _draw() -> void:
	for balloon in balloons:
		var at: Vector2 = balloon.position
		var radius: float = balloon.definition.radius
		draw_circle(at + Vector2(2, 4), radius + 2.0, Color(0.02, 0.07, 0.09, 0.3))
		draw_line(at + Vector2(0, radius), at + Vector2(-2, radius + 8), Color("e4e6d9"), 1.0, true)
		draw_circle(at, radius + 1.5, Color("17252c"))
		draw_circle(at, radius, balloon.definition.color)
		draw_circle(at + Vector2(-4, -4), radius * 0.26, Color(1, 1, 1, 0.4))
