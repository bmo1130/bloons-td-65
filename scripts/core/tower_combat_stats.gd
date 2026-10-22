class_name TowerCombatStats
extends RefCounted

var tower_id: int
var display_name: String
var build: String = "0-0-0"
var invested_gold: int
var volleys: int = 0
var critical_volleys: int = 0
var critical_damage: int = 0
var split_projectiles: int = 0
var projectiles: int = 0
var targets_damaged: int = 0
var normal_pops: int = 0
var shell_pops: int = 0
var effective_damage: int = 0
var moab_damage: int = 0
var gold_earned: int = 0
var immune_contacts: int = 0
var pierce_available: int = 0
var pierce_used: int = 0

func pops() -> int:
	return normal_pops + shell_pops

func pops_per_gold() -> float:
	return float(pops()) / invested_gold if invested_gold > 0 else 0.0

func pierce_utilization() -> float:
	return float(pierce_used) / pierce_available if pierce_available > 0 else 0.0

func snapshot() -> Dictionary:
	return {"id": tower_id, "name": display_name, "build": build, "invested_gold": invested_gold,
		"volleys": volleys, "critical_volleys": critical_volleys, "critical_damage": critical_damage, "projectiles": projectiles, "split_projectiles": split_projectiles, "targets_damaged": targets_damaged,
		"normal_pops": normal_pops, "shell_pops": shell_pops, "pops": pops(),
		"effective_damage": effective_damage, "moab_damage": moab_damage, "gold_earned": gold_earned, "immune_contacts": immune_contacts,
		"pierce_available": pierce_available, "pierce_used": pierce_used,
		"pops_per_gold": pops_per_gold(), "pierce_utilization": pierce_utilization()}
