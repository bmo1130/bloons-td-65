class_name ProjectileSplitDefinition
extends Resource

# Resource rather than self-referencing typed default prevents cyclic class loads.
@export var child_projectile: Resource
@export var thresholds: PackedFloat32Array = PackedFloat32Array([0.5, 1.0])
@export var count_per_burst: int = 6
@export var burst_rotation_degrees: float = 30.0
@export var child_speed_ratio: float = 0.5
@export var inherit_lifetime: bool = true
# Explosion children use the same launch/chronological contact queue as darts.
@export var on_explosion: bool = false
@export var inherit_damage: bool = false
@export var secondary_projectile: Resource # Optional bounded second ring; never recursively references itself.
@export_range(0, 8) var secondary_count: int = 0
