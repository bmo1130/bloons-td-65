class_name ProjectileState
extends RefCounted

var id: int
var position: Vector2
var direction: Vector2
# Aim provenance only; flight and collisions never depend on this target.
var target_id: int = -1
var speed: float
var attack: AttackSpec
var damage: int:
	get:
		return attack.damage
	set(value):
		attack.damage = value
var remaining_pierce: int
var radius: float
var length: float
var lifetime: float
var hit_ids: Dictionary = {}
var hit_epochs: Dictionary = {}
var child_ids: Dictionary = {}
var max_bounces: int = 0
var bounces: int = 0
var spawn_fraction: float = 0.0
var initial_pierce: int = 0
var split: ProjectileSplitDefinition
var child_profile: TowerDefinition
var split_bursts: int = 0
var end_fraction: float = 1.0
var timed_explosion: bool = false
var targeted_only: bool = false
var secondary_profile: TowerDefinition
var recursive: bool = false

func was_hit(balloon_id: int, epoch: int) -> bool:
	if max_bounces <= 0:
		return hit_ids.has(balloon_id)
	return child_ids.has(balloon_id) or int(hit_epochs.get(balloon_id, -1)) >= epoch

func _init(new_id: int, at: Vector2, heading: Vector2, data: TowerDefinition) -> void:
	id = new_id
	position = at
	direction = heading.normalized()
	speed = data.projectile_speed
	attack = data.make_attack()
	remaining_pierce = data.pierce
	initial_pierce = data.pierce
	radius = data.projectile_radius
	length = data.projectile_length
	lifetime = data.projectile_lifetime
	max_bounces = clampi(data.max_bounces, 0, 16)
	timed_explosion = data.timed_explosion
	targeted_only = data.targeted_only
	if data.projectile_split != null:
		split = data.projectile_split.duplicate() as ProjectileSplitDefinition
		child_profile = (split.child_projectile as TowerDefinition).duplicate() as TowerDefinition
		child_profile.projectile_speed = speed * split.child_speed_ratio
		child_profile.detects_camo = data.detects_camo
		if split.inherit_damage:
			child_profile.damage = data.damage + (data.frag_damage_bonus if not child_profile.timed_explosion else 0)
		if split.inherit_lifetime:
			child_profile.projectile_lifetime = data.projectile_lifetime
		if split.secondary_projectile != null:
			secondary_profile = (split.secondary_projectile as TowerDefinition).duplicate() as TowerDefinition
			secondary_profile.damage = data.damage
			secondary_profile.detects_camo = data.detects_camo
