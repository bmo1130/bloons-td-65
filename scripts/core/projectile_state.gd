class_name ProjectileState
extends RefCounted

var position: Vector2
var direction: Vector2
var target_id: int
var speed: float
var damage: int
var lifetime: float = 3.0

func _init(at: Vector2, target: BalloonState, data: TowerDefinition) -> void:
	position = at
	direction = at.direction_to(target.position)
	target_id = target.id
	speed = data.projectile_speed
	damage = data.damage
