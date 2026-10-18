class_name TowerSystem
extends Node2D

var balloon_system: BalloonSystem
var projectile_system: ProjectileSystem
var towers: Array[TowerState] = []
var preview_visible: bool = false
var preview_valid: bool = false
var preview_position: Vector2
var preview_definition: TowerDefinition

func has_space(at: Vector2, radius: float) -> bool:
	for tower in towers:
		if at.distance_to(tower.position) < radius + tower.definition.radius + 8.0:
			return false
	return true

func add_tower(at: Vector2, definition: TowerDefinition) -> void:
	towers.append(TowerState.new(definition, at))
	queue_redraw()

func update(delta: float) -> void:
	for tower in towers:
		tower.cooldown -= delta
		if tower.cooldown > 0.0:
			continue
		var target: BalloonState = _first_in_range(tower)
		if target == null:
			tower.cooldown = 0.1
			continue
		tower.direction = tower.position.direction_to(target.position)
		projectile_system.fire(tower.position + tower.direction * 22.0, target, tower.definition)
		tower.cooldown = tower.definition.fire_interval
	queue_redraw()

func _first_in_range(tower: TowerState) -> BalloonState:
	var first: BalloonState = null
	var range_squared: float = tower.definition.attack_range * tower.definition.attack_range
	# Scan only when ready to fire; no physics objects or per-frame target searches.
	for balloon in balloon_system.balloons:
		if tower.position.distance_squared_to(balloon.position) <= range_squared:
			if first == null or balloon.distance > first.distance:
				first = balloon
	return first

func _draw() -> void:
	for tower in towers:
		_draw_tower(tower.position, tower.direction, Color("84dbbd"))
	if preview_visible and preview_definition != null:
		var color: Color = Color("84dbbd") if preview_valid else Color("f67878")
		draw_circle(preview_position, preview_definition.attack_range, Color(color, 0.08))
		draw_arc(preview_position, preview_definition.attack_range, 0, TAU, 64, Color(color, 0.5), 1.5, true)
		_draw_tower(preview_position, Vector2.UP, Color(color, 0.75))

func _draw_tower(at: Vector2, direction: Vector2, color: Color) -> void:
	draw_circle(at + Vector2(2, 5), 22.0, Color(0.02, 0.07, 0.09, 0.4))
	draw_circle(at, 21.0, Color("152c32"))
	draw_circle(at, 17.0, color)
	draw_arc(at, 17.0, 0, TAU, 32, Color("d1fff0"), 1.5, true)
	draw_line(at, at + direction * 28.0, Color("152c32"), 10.0, true)
	draw_line(at + direction * 12.0, at + direction * 27.0, Color("e5fff4"), 4.0, true)
	draw_circle(at, 7.0, Color("274b4f"))
