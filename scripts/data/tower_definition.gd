class_name TowerDefinition
extends Resource

@export var id: StringName
@export var display_name: String = "Dart tower"
@export var cost: int = 65
@export var radius: float = 20.0
@export var attack_range: float = 150.0
@export var fire_interval: float = 0.7
@export var damage: int = 1
@export var pierce: int = 2
@export var projectile_speed: float = 480.0
@export var projectile_radius: float = 2.5
@export var projectile_length: float = 10.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
@export var heading_offset_degrees: float = 0.0
@export var projectile_lifetime: float = 3.0
@export var attack_attribute: AttackSpec.Attribute = AttackSpec.Attribute.SHARP
@export var explosion_radius: float = 0.0
@export var ceramic_bonus: int = 0
@export var fortified_bonus: int = 0
@export var lead_bonus: int = 0
@export var moab_bonus: int = 0
@export var detects_camo: bool = false
@export var projectile_split: ProjectileSplitDefinition
@export var timed_explosion: bool = false
@export var targeted_only: bool = false
@export var stun_duration: float = 0.0
@export var stun_moab_duration: float = 0.0
@export var push_distance: float = 0.0
@export var push_moab_distance: float = 0.0
@export var frag_damage_bonus: int = 0
@export var recursive_every: int = 0
@export var upgrade_path_names: PackedStringArray = PackedStringArray(["상단 · 관통", "중단 · 연사", "하단 · 고화력"])
@export var knockback_duration: float = 0.0
@export var knockback_light: float = 0.0
@export var knockback_heavy: float = 0.0
@export var max_bounces: int = 0
@export var critical_every: int = 0
@export var critical_damage: int = 0
@export var ability: AbilityDefinition
@export var color: Color = Color("84dbbd")
@export var shortcut: String = "D"
@export var upgrades: Array[UpgradeDefinition] = []

func upgrade_at(path: int, tier: int) -> UpgradeDefinition:
	for upgrade in upgrades:
		if upgrade.path == path and upgrade.tier == tier:
			return upgrade
	return null

func max_upgrade_tier(path: int) -> int:
	var maximum: int = 0
	for upgrade in upgrades:
		if upgrade.path == path:
			maximum = maxi(maximum, upgrade.tier)
	return maximum

func make_attack() -> AttackSpec:
	var attack: AttackSpec = AttackSpec.new(damage, pierce, attack_attribute, explosion_radius)
	attack.ceramic_bonus = ceramic_bonus
	attack.fortified_bonus = fortified_bonus
	attack.lead_bonus = lead_bonus
	attack.moab_bonus = moab_bonus
	attack.detects_camo = detects_camo
	attack.knockback_duration = knockback_duration
	attack.knockback_light = knockback_light
	attack.knockback_heavy = knockback_heavy
	attack.stun_duration = stun_duration
	attack.stun_moab_duration = stun_moab_duration
	attack.push_distance = push_distance
	attack.push_moab_distance = push_moab_distance
	return attack
