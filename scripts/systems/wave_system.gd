class_name WaveSystem
extends Node

signal started(number: int)
signal cleared(number: int, reward: int)
signal completed

@export var waves: Array[WaveDefinition] = []
var balloon_system: BalloonSystem
var current_wave: int = 0
var active: bool = false
var _group_index: int = 0
var _spawned_in_group: int = 0
var _until_spawn: float = 0.0

func start_next() -> bool:
	if active or current_wave >= waves.size():
		return false
	current_wave += 1
	_group_index = 0
	_spawned_in_group = 0
	active = true
	var groups: Array[WaveGroup] = waves[current_wave - 1].groups
	_until_spawn = groups[0].delay_before if not groups.is_empty() else 0.0
	started.emit(current_wave)
	return true

func update(delta: float) -> void:
	if not active:
		return
	var groups: Array[WaveGroup] = waves[current_wave - 1].groups
	_until_spawn -= delta
	while _group_index < groups.size() and _until_spawn <= 0.0:
		var group: WaveGroup = groups[_group_index]
		if _spawned_in_group < group.count:
			balloon_system.spawn(group.balloon)
			_spawned_in_group += 1
			_until_spawn += maxf(0.01, group.interval)
		if _spawned_in_group >= group.count:
			_group_index += 1
			_spawned_in_group = 0
			if _group_index < groups.size():
				_until_spawn += groups[_group_index].delay_before

func check_cleared() -> void:
	if not active:
		return
	var wave: WaveDefinition = waves[current_wave - 1]
	if _group_index < wave.groups.size() or not balloon_system.balloons.is_empty():
		return
	active = false
	cleared.emit(current_wave, wave.clear_reward)
	if current_wave == waves.size():
		completed.emit()
