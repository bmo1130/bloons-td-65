class_name BalloonDefinition
extends Resource

# Shared type data. Camo/fortification/remaining HP belong to BalloonState.
@export_range(1, 100000) var shell_hp: int = 1
@export_range(0, 100000) var fortified_hp: int = 0
@export var inherit_fortified: bool = false
@export var spill_damage: bool = false
@export var ceramic: bool = false
@export var fortified: bool = false
@export var heavy: bool = false
@export var lead: bool = false
@export var knockback_allowed: bool = true
@export var moab_class: bool = false
# Absolute boundary: ordinary attacks never spill through this shell, even in
# the laboratory's otherwise spilling lineage. No tower-name checks needed.
@export var blocks_child_damage: bool = false
@export var strength_rank: int = 0
@export var default_camo: bool = false
@export var children_regrow: bool = false
# Effect eligibility only. Slow/stun/freeze/instakill/capture mechanics are not
# implemented; future effects must query the same policy as knockback.
enum StatusEffect { SLOW, STUN, FREEZE, KNOCKBACK, FORCED_MOVEMENT, INSTANT_KILL, CAPTURE }
@export_flags("Slow", "Stun", "Freeze", "Knockback", "Forced movement", "Instant kill", "Capture") var status_immunity_mask: int = 0

@export var id: StringName
@export var color: Color = Color.RED
@export var speed: float = 95.0
@export var radius: float = 13.0
@export var pop_reward: int = 1
@export var next_layer: BalloonDefinition
# Resource avoids a Godot 4.7 self-typed array default retaining this script at
# shutdown. Entries are BalloonDefinition assets, checked by the data tests.
@export var split_children: Array[Resource] = []
@export_flags("SHARP", "EXPLOSIVE", "NORMAL", "PLASMA", "COLD") var immunity_mask: int = 0
@export_enum("Round", "Banded", "Metal", "Zebra", "Rainbow", "Ceramic", "Blimp", "DDT", "BAD") var appearance: int = 0

# The data chain is the single source of truth for remaining layers and leaks.
var leak_damage: int:
	get:
		return total_rbe()

func layer_count() -> int:
	var count: int = 1
	if not split_children.is_empty():
		for child: BalloonDefinition in split_children:
			count += child.layer_count()
	elif next_layer != null:
		count += next_layer.layer_count()
	return count

func max_hp(is_fortified: bool = false) -> int:
	return fortified_hp if is_fortified and fortified_hp > 0 else shell_hp

func total_rbe(is_fortified: bool = false) -> int:
	var value: int = max_hp(is_fortified)
	if not split_children.is_empty():
		for child: BalloonDefinition in split_children:
			value += child.total_rbe(is_fortified and inherit_fortified)
	elif next_layer != null:
		value += next_layer.total_rbe(is_fortified and inherit_fortified)
	return value

func total_reward() -> int:
	var value: int = pop_reward
	if not split_children.is_empty():
		for child: BalloonDefinition in split_children:
			value += child.total_reward()
	elif next_layer != null:
		value += next_layer.total_reward()
	return value
