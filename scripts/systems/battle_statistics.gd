class_name BattleStatistics
extends RefCounted

# Passive counters only. No target queries, decisions, event objects or callbacks.
# Source 0 means unowned/debug damage and is excluded from attributed totals.
var enabled: bool = true
var records: Dictionary = {}
var total_pops: int = 0

func register(id: int, definition: TowerDefinition) -> TowerCombatStats:
	var record: TowerCombatStats = TowerCombatStats.new()
	record.tower_id = id
	record.display_name = definition.display_name
	record.invested_gold = definition.cost
	records[id] = record
	return record

func record_volley(id: int, critical: bool = false) -> void:
	if enabled and records.has(id):
		records[id].volleys += 1
		records[id].critical_volleys += 1 if critical else 0

func record_projectile(id: int, capacity: int, split: bool = false) -> void:
	if enabled and records.has(id):
		records[id].projectiles += 1
		records[id].pierce_available += capacity
		records[id].split_projectiles += 1 if split else 0

func record_hit(id: int, normal: int, shells: int, immune: bool, critical: bool = false, actual_hp: int = -1, targets: int = 1, immune_count: int = -1) -> void:
	if not enabled or not records.has(id):
		return
	var record: TowerCombatStats = records[id]
	var removed: int = normal + shells
	var applied: int = removed if actual_hp < 0 else actual_hp
	if applied > 0:
		record.targets_damaged += targets
		record.pierce_used += 1
		record.normal_pops += normal
		record.shell_pops += shells
		record.effective_damage += applied
		record.critical_damage += applied if critical else 0
		total_pops += removed
	if immune:
		record.immune_contacts += 1 if immune_count < 0 else immune_count

func top_towers(limit: int = 3) -> Array[TowerCombatStats]:
	var ranking: Array[TowerCombatStats] = []
	for record: TowerCombatStats in records.values():
		ranking.append(record)
	ranking.sort_custom(func(a: TowerCombatStats, b: TowerCombatStats) -> bool:
		return a.pops() > b.pops() if a.pops() != b.pops() else a.tower_id < b.tower_id)
	ranking.resize(mini(limit, ranking.size()))
	return ranking
