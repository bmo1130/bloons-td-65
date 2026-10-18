class_name BalloonDefinition
extends Resource

@export var id: StringName
@export var color: Color = Color.RED
@export var speed: float = 95.0
@export var radius: float = 13.0
@export var leak_damage: int = 1
@export var pop_reward: int = 1
@export var next_layer: BalloonDefinition
