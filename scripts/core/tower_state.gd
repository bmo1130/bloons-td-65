class_name TowerState
extends RefCounted

# Instance state stays separate from shared, immutable base stats. Future upgrade
# selections can live here and produce resolved stats without changing targeting.
var definition: TowerDefinition
var position: Vector2
var cooldown: float = 0.0
var direction: Vector2 = Vector2.UP

func _init(data: TowerDefinition, at: Vector2) -> void:
	definition = data
	position = at
