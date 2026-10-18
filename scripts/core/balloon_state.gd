class_name BalloonState
extends RefCounted

var id: int
var definition: BalloonDefinition
var distance: float = 0.0
var position: Vector2

func _init(new_id: int, data: BalloonDefinition, start_position: Vector2) -> void:
	id = new_id
	definition = data
	position = start_position
