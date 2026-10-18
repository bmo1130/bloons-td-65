class_name BalloonState
extends RefCounted

var id: int
var definition: BalloonDefinition
var distance: float = 0.0
var position: Vector2
var array_index: int = -1
var motion_points: PackedVector2Array
var motion_times: PackedFloat32Array = PackedFloat32Array([0.0, 1.0])
var motion_duration: float = 0.0
var exit_time: float = INF

func _init(new_id: int, data: BalloonDefinition, start_position: Vector2) -> void:
	id = new_id
	definition = data
	position = start_position
	motion_points = PackedVector2Array([start_position, start_position])

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
