class_name BalloonState
extends RefCounted

var knockback_remaining: float = 0.0
var knockback_multiplier: float = 0.0
var camo: bool = false
var regrow: bool = false # Inherited metadata only until the Regrow version.
var fortified: bool = false
var spill_damage: bool = false
var shell_hp: int = 1
var shell_max_hp: int = 1
var speed: float = 95.0 # Spawned/layer value; Definition remains base data.

var id: int
var definition: BalloonDefinition
var distance: float = 0.0
var position: Vector2
var array_index: int = -1
var motion_points: PackedVector2Array
var motion_times: PackedFloat32Array = PackedFloat32Array([0.0, 1.0])
var motion_duration: float = 0.0
var exit_time: float = INF
var motion_start_distance: float = 0.0

func _init(new_id: int, data: BalloonDefinition, start_position: Vector2) -> void:
	id = new_id
	definition = data
	camo = data.default_camo
	speed = data.speed
	spill_damage = data.spill_damage
	# Legacy fortified classification remains a test hook; normal instances use
	# the allowed fortified_hp data and set_layer(), never mutate a Resource.
	fortified = data.fortified
	shell_max_hp = data.max_hp(fortified)
	shell_hp = shell_max_hp
	position = start_position
	motion_points = PackedVector2Array([start_position, start_position])

func set_layer(data: BalloonDefinition, armor: bool = false) -> void:
	definition = data
	speed = data.speed
	fortified = armor and data.fortified_hp > 0
	shell_max_hp = data.max_hp(fortified)
	shell_hp = shell_max_hp

func total_rbe() -> int:
	return definition.total_rbe(fortified)

func remaining_rbe() -> int:
	return total_rbe() - (shell_max_hp - shell_hp)

func leak_damage() -> int:
	return BalloonLeakPolicy.damage(self)

func damage_stage() -> int:
	return clampi(floori(float(shell_max_hp - shell_hp) * 4.0 / maxi(1, shell_max_hp)), 0, 3)

func remove_camo() -> void:
	camo = false # Descendants inherit the live instance flag at split time.

func record_motion(points: PackedVector2Array, delta: float, until_fraction: float = 1.0) -> void:
	motion_points = points
	motion_duration = delta
	motion_times = PackedFloat32Array([0.0])
	var length: float = 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
		motion_times.append(length)
	if length > 0.0:
		for index in range(1, motion_times.size()):
			motion_times[index] = motion_times[index] / length * until_fraction
	else:
		motion_times[motion_times.size() - 1] = until_fraction

func position_at_time(time: float) -> Vector2:
	if motion_duration <= 0.0:
		return position
	for index in range(motion_points.size() - 1):
		var until: float = motion_times[index + 1]
		if time <= until:
			var span: float = until - motion_times[index]
			var weight: float = clampf((time - motion_times[index]) / maxf(span, 0.000001), 0.0, 1.0)
			return motion_points[index].lerp(motion_points[index + 1], weight)
	return position

func distance_at_time(time: float) -> float:
	if motion_duration <= 0.0:
		return distance
	var weight: float = clampf(time / maxf(minf(exit_time, 1.0), 0.000001), 0.0, 1.0)
	return lerpf(motion_start_distance, distance, weight)
