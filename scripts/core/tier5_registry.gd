class_name Tier5Registry
extends RefCounted

# Map-owned slots, independent of tower implementation. Capacity is policy data.
signal changed
var default_limit: int = 1
var limits: Dictionary = {} # StringName tower kind -> path -> capacity.
var _owners: Dictionary = {} # Tower kind -> path -> {instance ID: true}.

func limit_for(kind: StringName, path: int) -> int:
	return int(limits.get(kind, {}).get(path, default_limit))

func owners(kind: StringName, path: int) -> Dictionary:
	return _owners.get(kind, {}).get(path, {}).duplicate()

func can_claim(kind: StringName, path: int, id: int) -> bool:
	var occupied: Dictionary = _owners.get(kind, {}).get(path, {})
	return occupied.has(id) or occupied.size() < limit_for(kind, path)

func claim(kind: StringName, path: int, id: int) -> bool:
	if not can_claim(kind, path, id):
		return false
	if not _owners.has(kind):
		_owners[kind] = {}
	if not _owners[kind].has(path):
		_owners[kind][path] = {}
	_owners[kind][path][id] = true
	changed.emit()
	return true

func release(id: int) -> void:
	var removed: bool = false
	for paths: Dictionary in _owners.values():
		for ids: Dictionary in paths.values():
			removed = ids.erase(id) or removed
	if removed:
		changed.emit()
