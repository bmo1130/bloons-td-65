class_name GameRoute
extends Node2D

const ROAD_WIDTH: float = 48.0
const BUILD_BOUNDS: Rect2 = Rect2(24, 128, 936, 544)
const PLACEMENT_MARGIN: float = 6.0

@export var points: PackedVector2Array = PackedVector2Array([
	Vector2(24, 480), Vector2(156, 480), Vector2(156, 240),
	Vector2(352, 240), Vector2(352, 552), Vector2(576, 552),
	Vector2(576, 332), Vector2(768, 332), Vector2(768, 204),
	Vector2(960, 204),
])
var total_length: float = 0.0
var _segment_lengths: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	for index in range(points.size() - 1):
		var length: float = points[index].distance_to(points[index + 1])
		_segment_lengths.append(length)
		total_length += length
	queue_redraw()

func position_at(distance: float) -> Vector2:
	var remaining: float = maxf(distance, 0.0)
	for index in range(_segment_lengths.size()):
		var length: float = _segment_lengths[index]
		if remaining <= length:
			return points[index].lerp(points[index + 1], remaining / maxf(length, 0.001))
		remaining -= length
	return points[points.size() - 1]

func distance_to_path(at: Vector2) -> float:
	var nearest: float = INF
	for index in range(points.size() - 1):
		var on_segment: Vector2 = Geometry2D.get_closest_point_to_segment(
			at, points[index], points[index + 1])
		nearest = minf(nearest, at.distance_to(on_segment))
	return nearest

func can_build(at: Vector2, radius: float) -> bool:
	return BUILD_BOUNDS.grow(-radius).has_point(at) and (
		distance_to_path(at) >= ROAD_WIDTH * 0.5 + radius + PLACEMENT_MARGIN)

func _draw() -> void:
	draw_polyline(points, Color("111d21"), ROAD_WIDTH + 10.0, true)
	draw_polyline(points, Color("b9a683"), ROAD_WIDTH, true)
	for point in points:
		draw_circle(point, ROAD_WIDTH * 0.5, Color("b9a683"))
	for step in range(24, int(total_length), 36):
		var at: Vector2 = position_at(float(step))
		var direction: Vector2 = position_at(float(step) + 3.0) - at
		draw_line(at, at + direction.normalized() * 10.0, Color("d4c5a6"), 2.0, true)
	draw_circle(points[0], 8.0, Color("8ce8bc"))
	draw_circle(points[points.size() - 1], 8.0, Color("f6b27a"))
