class_name ProjectileState
extends RefCounted

var id: int
var position: Vector2
var direction: Vector2
# Aim provenance only; flight and collisions never depend on this target.
var target_id: int = -1
var speed: float
var damage: int
var remaining_pierce: int
var radius: float
var lifetime: float
var hit_ids: Dictionary = {}

func _init(new_id: int, at: Vector2, heading: Vector2, data: TowerDefinition) -> void:
	id = new_id
	position = at
	direction = heading.normalized()
	speed = data.projectile_speed
	damage = data.damage
	remaining_pierce = data.pierce
	radius = data.projectile_radius
	lifetime = data.projectile_lifetime
