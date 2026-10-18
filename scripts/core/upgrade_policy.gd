class_name UpgradePolicy
extends RefCounted

# Main path is derived only when a tier >= 3 exists; purchase order is irrelevant.
const AVAILABLE_TIER: int = 5
const FINAL_TIER: int = 5
const SECONDARY_TIER: int = 2

static func main_path(tiers: PackedInt32Array) -> int:
	for path in range(tiers.size()):
		if tiers[path] > SECONDARY_TIER:
			return path
	return -1

static func state_reason(tiers: PackedInt32Array, tier_limit: int = AVAILABLE_TIER) -> String:
	if tiers.size() != 3:
		return "올바르지 않은 강화 상태"
	var invested: int = 0
	var main_count: int = 0
	for tier in tiers:
		if tier < 0:
			return "올바르지 않은 강화 상태"
		if tier > tier_limit:
			return "현재 구현된 최대 티어 도달 (%d)" % tier_limit
		invested += 1 if tier > 0 else 0
		main_count += 1 if tier > SECONDARY_TIER else 0
	if invested > 2:
		return "세 번째 경로 잠김 · 최대 두 경로"
	if main_count > 1:
		return "다른 경로 주력 · 보조 최대2"
	return ""

static func reason(tower: TowerState, upgrade: UpgradeDefinition) -> String:
	if tower == null or upgrade == null:
		return "강화가 없습니다"
	var invalid_state: String = state_reason(tower.tiers)
	if not invalid_state.is_empty():
		return invalid_state
	if not tower.definition.upgrades.has(upgrade):
		return "이 타워의 강화가 아닙니다"
	if upgrade.path < 0 or upgrade.path >= 3 or upgrade.tier < 1:
		return "이번 버전에서 지원하지 않는 티어"
	if upgrade.tier > AVAILABLE_TIER:
		return "현재 구현된 최대 티어 도달 (%d)" % AVAILABLE_TIER
	if upgrade.tier <= tower.tiers[upgrade.path]:
		return "이미 구매한 티어입니다"
	if tower.tiers[upgrade.path] + 1 != upgrade.tier:
		return "선행 업그레이드 미구매"
	var next_tiers: PackedInt32Array = tower.tiers.duplicate()
	next_tiers[upgrade.path] = upgrade.tier
	var crosspath_reason: String = state_reason(next_tiers)
	if not crosspath_reason.is_empty():
		return crosspath_reason
	var owned: Array[StringName] = []
	for item in TowerStatResolver.acquired(tower.definition, tower.tiers):
		owned.append(item.id)
	for required in upgrade.prerequisites:
		if not owned.has(required):
			return "선행 강화가 필요합니다"
	if upgrade.cost <= 0:
		return "올바르지 않은 강화 비용"
	return ""
