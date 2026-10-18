class_name AbilityState
extends RefCounted

var definition: AbilityDefinition
var cooldown_remaining: float
var active_remaining: float = 0.0
var last_targets: PackedInt64Array = []

func _init(data: AbilityDefinition) -> void:
	definition = data
	cooldown_remaining = data.initial_cooldown
