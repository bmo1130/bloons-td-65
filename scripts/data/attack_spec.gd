class_name AttackSpec
extends RefCounted

# Attribution never participates in damage/targeting decisions.
enum Attribute { SHARP, EXPLOSIVE, NORMAL, PLASMA, COLD, SHATTER }

var damage_over_time: DamageOverTimeDefinition
var dot_consumed: bool = false
var dot_first_moab: bool = false
var moab_only: bool = false
var press_distance: float = 0.0
var damage: int
var pierce: int
var attribute: Attribute
var explosion_radius: float
var source_id: int = 0
var ceramic_bonus: int = 0
var fortified_bonus: int = 0
var lead_bonus: int = 0
var moab_bonus: int = 0
var knockback_duration: float = 0.0
var knockback_light: float = 0.0
var knockback_heavy: float = 0.0
var critical: bool = false
var detects_camo: bool = false
var stun_duration: float = 0.0
var stun_moab_duration: float = 0.0
var push_distance: float = 0.0
var push_moab_distance: float = 0.0

func _init(amount: int = 1, limit: int = 1, kind: Attribute = Attribute.SHARP, blast_radius: float = 0.0) -> void:
	damage = amount
	pierce = limit
	attribute = kind
	explosion_radius = blast_radius

static func attribute_name(kind: Attribute) -> String:
	return Attribute.keys()[kind]
