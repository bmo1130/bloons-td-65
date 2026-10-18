class_name UpgradeDefinition
extends Resource

# Replace this path's earlier modifiers for these fields, then compose secondary
# path modifiers normally. This avoids a tier-4 override erasing crosspaths.
@export var replacement_values: Dictionary = {}
@export var interactions: Array[Dictionary] = []
@export var ability: AbilityDefinition
@export var projectile_split: ProjectileSplitDefinition

@export var id: StringName
@export var display_name: String
@export_range(0, 2) var path: int = 0
@export_range(1, 5) var tier: int = 1
@export var cost: int = 50
@export var reference_medium_cost: int = 0
@export var reference_version: String = ""
@export_multiline var description: String
@export var prerequisites: Array[StringName] = []
# Keys are TowerStatResolver.FIELDS. All effects are composed from the base,
# never from the last resolved value. Overrides also describe reusable volleys.
@export var additions: Dictionary = {}
@export var multipliers: Dictionary = {}
@export var overrides: Dictionary = {}
@export var visual_color: Color = Color.TRANSPARENT
