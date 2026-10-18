class_name BalloonDefinition
extends Resource

@export var id: StringName
@export var color: Color = Color.RED
@export var speed: float = 95.0
@export var radius: float = 13.0
@export var pop_reward: int = 1
@export var next_layer: BalloonDefinition

# The data chain is the single source of truth for remaining layers and leaks.
var leak_damage: int:
	get:
		return layer_count()

func layer_count() -> int:
	var count: int = 0
	var layer: BalloonDefinition = self
	while layer != null:
		count += 1
		layer = layer.next_layer
	return count
