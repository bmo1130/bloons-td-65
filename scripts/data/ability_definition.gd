class_name AbilityDefinition
extends Resource

enum Effect { FAN_TRANSFORM, MOAB_MISSILE, LEAK_STORM }
@export var attack_profile: TowerDefinition
@export var id: StringName
@export var display_name: String
@export var effect: Effect = Effect.FAN_TRANSFORM
@export var duration: float = 15.0
@export var cooldown: float = 50.0
@export var initial_cooldown: float = 50.0 / 3.0
@export var target_limit: int = 10
@export var tower_type: StringName = &"dart"
@export var transformed_intervals: PackedFloat32Array = PackedFloat32Array([0.06, 0.051, 0.04, 0.03, 0.015])
@export var minimum_range: float = 187.5
@export var eyesight_range: float = 37.5
@export var projectile_speed: float = 660.0
@export var priority: int = 1
@export var max_middle_tier: int = 4
@export var prefer_untransformed: bool = true
@export var self_overrides_stronger: bool = true
@export var transformed_damage: int = 1
@export var pierce_bonus: int = 0
@export var attribute: AttackSpec.Attribute = AttackSpec.Attribute.SHARP
@export var projectile_lifetime: float = 0.0 # Zero preserves the permanent profile.
@export var projectile_radius: float = 0.0
@export var long_range_lifetime_multiplier: float = 1.0
@export var eyesight_lifetime_multiplier: float = 1.0
@export var eyesight_speed_multiplier: float = 1.0
@export var grants_eyesight: bool = false
@export var color: Color = Color("66b8ff")
