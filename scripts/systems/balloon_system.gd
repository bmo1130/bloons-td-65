class_name BalloonSystem
extends Node2D

signal layer_popped(reward: int)
signal leaked(damage: int)

var route: GameRoute
var balloons: Array[BalloonState] = []
var _by_id: Dictionary = {}
var _next_id: int = 1

func spawn(definition: BalloonDefinition) -> BalloonState:
	var balloon: BalloonState = BalloonState.new(_next_id, definition, route.position_at(0))
	_next_id += 1
	balloons.append(balloon)
	_by_id[balloon.id] = balloon
	queue_redraw()
	return balloon

func find(id: int) -> BalloonState:
	return _by_id.get(id) as BalloonState

func update(delta: float) -> void:
	for index in range(balloons.size() - 1, -1, -1):
		var balloon: BalloonState = balloons[index]
		balloon.distance += balloon.definition.speed * delta
		if balloon.distance >= route.total_length:
			_remove(index)
			leaked.emit(balloon.definition.leak_damage)
		else:
			balloon.position = route.position_at(balloon.distance)
	queue_redraw()

func damage(id: int, amount: int) -> void:
	var balloon: BalloonState = find(id)
	if balloon == null:
		return
	for layer in range(maxi(0, amount)):
		var definition: BalloonDefinition = balloon.definition
		if definition.next_layer != null:
			balloon.definition = definition.next_layer
		else:
			_remove(balloons.find(balloon))
		layer_popped.emit(definition.pop_reward)
		if not _by_id.has(id):
			break
	queue_redraw()

func _remove(index: int) -> void:
	_by_id.erase(balloons[index].id)
	balloons.remove_at(index)

func _draw() -> void:
	for balloon in balloons:
		var at: Vector2 = balloon.position
		var radius: float = balloon.definition.radius
		draw_circle(at + Vector2(2, 4), radius + 2.0, Color(0.02, 0.07, 0.09, 0.3))
		draw_line(at + Vector2(0, radius), at + Vector2(-2, radius + 8), Color("e4e6d9"), 1.0, true)
		draw_circle(at, radius + 1.5, Color("17252c"))
		draw_circle(at, radius, balloon.definition.color)
		draw_circle(at + Vector2(-4, -4), radius * 0.26, Color(1, 1, 1, 0.4))
