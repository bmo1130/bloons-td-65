class_name TowerState
extends RefCounted

enum TargetMode { FIRST, LAST, CLOSE, STRONG }
var target_mode: TargetMode = TargetMode.FIRST

# Shared definition is immutable. Only this instance owns tiers/resolved stats.
var definition: TowerDefinition
var id: int = 0
var combat_stats: TowerCombatStats
var stats: TowerDefinition
var tiers: PackedInt32Array = PackedInt32Array([0, 0, 0])
var spent_on_upgrades: int = 0
var position: Vector2
var cooldown: float = 0.0
var direction: Vector2 = Vector2.UP
var transformed_stats: TowerDefinition
var critical_counter: int = 0
var attack_counter: int = 0 # Successful volleys, independent of statistics.
var crit_flash: float = 0.0

func combat_definition() -> TowerDefinition:
	return transformed_stats if transformed_stats != null else stats

func _init(data: TowerDefinition, at: Vector2) -> void:
	definition = data
	stats = TowerStatResolver.resolve(data, tiers)
	position = at

func upgrade_text() -> String:
	return "%d-%d-%d" % [tiers[0], tiers[1], tiers[2]]
