class_name CombatTrace
extends RefCounted

# Explicitly enabled diagnostic pass. Numbers are per benchmark frame and
# inclusive timers overlap; allocation counts are proxies, not a heap trace.
var values: Dictionary = {}
var last_origin: Vector2 = Vector2.INF
var last_time: float = -1.0
var last_range: float = -1.0
var record_events: bool = false
var events: Array[Array] = []

func reset() -> void:
	values.clear()
	events.clear()
	last_origin = Vector2.INF
	last_time = -1.0
	last_range = -1.0

func add(key: String, amount: float = 1.0) -> void:
	values[key] = float(values.get(key, 0.0)) + amount

func peak(key: String, amount: float) -> void:
	values[key] = maxf(float(values.get(key, 0.0)), amount)

func elapsed(key: String, started: int) -> void:
	add(key, Time.get_ticks_usec() - started)

func query(origin: Vector2, time: float, radius: float) -> void:
	add("searches")
	if origin == last_origin and time == last_time and radius == last_range:
		add("identical_queries")
	last_origin = origin
	last_time = time
	last_range = radius
