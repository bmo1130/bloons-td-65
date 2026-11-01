class_name DamageOverTimeDefinition
extends Resource

@export var attribute_override: int = -1 # -1 keeps the original impact type.
@export var color: Color = Color.TRANSPARENT # Optional generic effect marker.
@export var family: StringName
@export var damage: int = 1
@export var interval: float = 1.0
@export var duration: float = 4.0
@export var moab_only: bool = false
