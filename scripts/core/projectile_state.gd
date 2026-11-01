class_name ProjectileState
extends RefCounted

var end_explosion: TowerDefinition
var end_emitted: bool = false
var return_flight: bool = true
var area_visual: bool = true
var dot_applied: bool = false
var id: int
var position: Vector2
var direction: Vector2
# Straight shots keep aim provenance; chain/missile modes track this live ID.
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
var flight_mode: TowerDefinition.Flight = TowerDefinition.Flight.STRAIGHT
var flight_distance: float = 0.0
var curve_width: float = 0.0
var rehit_interval: float = 0.0
var chain_range: float = 0.0
var projectile_style: TowerDefinition.ProjectileStyle = TowerDefinition.ProjectileStyle.DEFAULT
var flight_points: PackedVector2Array
var flight_index: int = 0
var age: float = 0.0
var age_origin: float = 0.0
var hit_times: Dictionary = {} # Kylie time policy, never bounce epochs/statistics.
var frame_segments: Array[Dictionary] = []
var flight_revision: int = 0 # Invalidates a chain's former planned contacts.
var trail: PackedVector2Array # Render only, at most12 actual end-of-step positions.

func can_rehit(balloon_id: int, at_time: float) -> bool:
	return not child_ids.has(balloon_id) and (not hit_times.has(balloon_id) or at_time + 0.00000001 >= float(hit_times[balloon_id]) + rehit_interval)

func was_hit(balloon_id: int, epoch: int) -> bool:
	if rehit_interval > 0.0:
		return child_ids.has(balloon_id)
	if max_bounces <= 0:
		return hit_ids.has(balloon_id)
	return child_ids.has(balloon_id) or int(hit_epochs.get(balloon_id, -1)) >= epoch

func _init(new_id: int, at: Vector2, heading: Vector2, data: TowerDefinition) -> void:
	end_explosion = (data.end_explosion as TowerDefinition).duplicate(true) if data.end_explosion != null else null
	return_flight = data.return_flight
	area_visual = data.area_visual
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
	flight_mode = data.flight_mode
	flight_distance = data.flight_distance
	curve_width = data.curve_width
	rehit_interval = data.rehit_interval
	chain_range = data.chain_range
	projectile_style = data.projectile_style
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
