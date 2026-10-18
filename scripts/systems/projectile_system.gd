class_name ProjectileSystem
extends Node2D

var balloon_system: BalloonSystem
var projectiles: Array[ProjectileState] = []

func fire(at: Vector2, target: BalloonState, definition: TowerDefinition) -> void:
	projectiles.append(ProjectileState.new(at, target, definition))

func update(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = projectiles[index]
		var target: BalloonState = balloon_system.find(shot.target_id)
		shot.lifetime -= delta
		if target == null or shot.lifetime <= 0.0:
			projectiles.remove_at(index)
			continue
		shot.direction = shot.position.direction_to(target.position)
		var travel: float = shot.speed * delta
		if shot.position.distance_to(target.position) <= travel + target.definition.radius:
			balloon_system.damage(shot.target_id, shot.damage)
			projectiles.remove_at(index)
		else:
			shot.position += shot.direction * travel
	queue_redraw()

func _draw() -> void:
	for shot in projectiles:
		draw_line(shot.position - shot.direction * 10.0, shot.position, Color("f7e9b7"), 3.0, true)
		draw_circle(shot.position, 2.5, Color("ffffff"))
