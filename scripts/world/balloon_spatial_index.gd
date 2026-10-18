class_name BalloonSpatialIndex
extends RefCounted

# Cached until movement/spawning; shared by tower queries and all darts.
# Swept bounds include path corners, so fast moving circles remain candidates.
const CELL_SIZE: float = 64.0
var _cells: Dictionary = {}
var profiling: bool = false
var build_usec: int = 0
var query_usec: int = 0
var build_count: int = 0
var query_count: int = 0
var candidate_count: int = 0

func reset_metrics() -> void:
	build_usec = 0
	query_usec = 0
	build_count = 0
	query_count = 0
	candidate_count = 0

func rebuild(balloons: Array[BalloonState]) -> void:
	var started: int = Time.get_ticks_usec() if profiling else 0
	_cells.clear()
	for balloon in balloons:
		var bounds: Rect2 = Rect2(balloon.position, Vector2.ZERO)
		for point in balloon.motion_points:
			bounds = bounds.expand(point)
		bounds = bounds.grow(balloon.definition.radius)
		var first: Vector2i = _cell(bounds.position)
		var last: Vector2i = _cell(bounds.end)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var key: Vector2i = Vector2i(x, y)
				if not _cells.has(key):
					_cells[key] = []
				_cells[key].append(balloon)
	if profiling:
		build_usec += Time.get_ticks_usec() - started
		build_count += 1

func query(bounds: Rect2) -> Array[BalloonState]:
	var started: int = Time.get_ticks_usec() if profiling else 0
	var result: Array[BalloonState] = []
	var seen: Dictionary = {}
	var first: Vector2i = _cell(bounds.position)
	var last: Vector2i = _cell(bounds.end)
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var key: Vector2i = Vector2i(x, y)
			for balloon: BalloonState in _cells.get(key, []):
				if not seen.has(balloon.id):
					seen[balloon.id] = true
					result.append(balloon)
	if profiling:
		query_usec += Time.get_ticks_usec() - started
		query_count += 1
		candidate_count += result.size()
	return result

func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL_SIZE), floori(at.y / CELL_SIZE))
