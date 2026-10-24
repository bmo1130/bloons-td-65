class_name UpgradeSystem
extends Node

signal upgraded(tower: TowerState)

var economy: GameEconomy
var tower_system: TowerSystem
var enabled: bool = true
var _purchasing: Dictionary = {}

func error_for_path(tower: TowerState, path: int) -> String:
	if tower == null or path < 0 or path >= 3:
		return "타워를 선택하세요"
	var item: UpgradeDefinition = tower.definition.upgrade_at(path, tower.tiers[path] + 1)
	if item != null:
		return error_for(tower, item)
	var maximum: int = tower.definition.max_upgrade_tier(path)
	if maximum > 0 and tower.tiers[path] >= maximum:
		return "현재 구현된 최대 티어 도달 (%d)" % maximum
	return "강화 정의 없음" if not tower.definition.upgrades.is_empty() else "이 타워는 아직 강화가 없습니다"

func error_for(tower: TowerState, upgrade: UpgradeDefinition) -> String:
	if not enabled:
		return "게임이 종료되었습니다"
	if tower == null or not tower_system.towers.has(tower):
		return "타워를 선택하세요"
	if _purchasing.has(tower.id):
		return "구매 처리 중"
	var reason: String = UpgradePolicy.reason(tower, upgrade)
	if not reason.is_empty():
		return reason
	if upgrade.tier == 5 and not tower_system.tier5_registry.can_claim(tower.definition.id, upgrade.path, tower.id):
		return "5티어 사용 중 · 같은 종류/경로 최대 %d개" % tower_system.tier5_registry.limit_for(tower.definition.id, upgrade.path)
	if economy.gold < upgrade.cost:
		return "자금 부족 · %d G 필요" % upgrade.cost
	return ""

func purchase(tower: TowerState, upgrade: UpgradeDefinition) -> bool:
	if not error_for(tower, upgrade).is_empty():
		return false
	var next_stats: TowerDefinition = TowerStatResolver.preview(tower.definition, tower.tiers, upgrade)
	_purchasing[tower.id] = true
	# Reserve before economy signals can re-enter the purchase API; roll back on failure.
	if upgrade.tier == 5 and not tower_system.tier5_registry.claim(tower.definition.id, upgrade.path, tower.id):
		_purchasing.erase(tower.id)
		return false
	if not economy.try_spend(upgrade.cost):
		if upgrade.tier == 5:
			tower_system.tier5_registry.release(tower.id)
		_purchasing.erase(tower.id)
		return false
	var old_interval: float = tower.stats.fire_interval
	var old_critical: int = tower.stats.critical_every
	var old_recursive: int = tower.stats.recursive_every
	tower.tiers[upgrade.path] = upgrade.tier
	tower.stats = next_stats
	tower.spent_on_upgrades += upgrade.cost
	if tower.combat_stats != null:
		tower.combat_stats.invested_gold += upgrade.cost
		tower.combat_stats.build = tower.upgrade_text()
	# Preserve reload progress instead of granting an extra shot on purchase.
	if tower.cooldown > 0.0:
		tower.cooldown *= tower.stats.fire_interval / old_interval
	if old_critical != tower.stats.critical_every:
		tower.critical_counter = 0
	if old_recursive != tower.stats.recursive_every:
		tower.attack_counter = 0
	if tower_system.abilities != null:
		tower_system.abilities.sync_tower(tower)
	tower_system.queue_redraw()
	_purchasing.erase(tower.id)
	upgraded.emit(tower)
	return true
