class_name TowerUpgradePanel
extends Panel

signal purchase_requested(upgrade: UpgradeDefinition)
signal close_requested

const PATH_NAMES: Array[String] = ["상단 · 관통", "중단 · 연사", "하단 · 고화력"]
const PATH_COLORS: Array[Color] = [Color("79b8ff"), Color("ffc176"), Color("c0a0ff")]
var tower: TowerState
var system: UpgradeSystem
var _title: Label
var _stats: Label
var _policy: Label
var _buttons: Array[Button] = []
var _details: Array[Label] = []
var _next: Array[UpgradeDefinition] = [null, null, null]
var abilities: AbilitySystem
var ability_button: Button
var target_button: Button
var _elapsed: float = 0.0
var cache_previews: bool = true
var preview_rebuilds: int = 0
var profile_updates: bool = false
var refresh_usec: int = 0
var refresh_count: int = 0
var _cache_tower: TowerState
var _cache_stats: TowerDefinition
var _cache_permanent: TowerDefinition
var _changes: Dictionary = {}

func _ready() -> void:
	position = Vector2(992, 140)
	size = Vector2(248, 318)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("182d32")
	add_theme_stylebox_override("panel", background)
	_title = _label(Vector2(10, 4), Vector2(200, 24), 17)
	var close: Button = Button.new()
	close.text = "×"
	close.position = Vector2(214, 2)
	close.size = Vector2(26, 26)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: close_requested.emit())
	add_child(close)
	_stats = _label(Vector2(10, 32), Vector2(230, 66), 12)
	for path in range(3):
		var button: Button = Button.new()
		button.position = Vector2(10, 106 + path * 61)
		button.size = Vector2(228, 28)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", PATH_COLORS[path])
		button.add_theme_color_override("font_disabled_color", PATH_COLORS[path].darkened(0.2))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color("24423e") if state != "disabled" else Color("203438")
			style.border_color = PATH_COLORS[path].darkened(0.4)
			style.set_border_width_all(1)
			style.set_corner_radius_all(5)
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(_request.bind(path))
		add_child(button)
		_buttons.append(button)
		_details.append(_label(Vector2(10, 136 + path * 61), Vector2(228, 30), 10))
	_policy = _label(Vector2(10, 292), Vector2(230, 20), 11)
	ability_button = Button.new()
	ability_button.position = Vector2(0, 322)
	ability_button.size = Vector2(248, 38)
	ability_button.add_theme_font_size_override("font_size", 11)
	ability_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("23485a") if state != "disabled" else Color("203438")
		style.border_color = Color("78b8ed")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		ability_button.add_theme_stylebox_override(state, style)
	ability_button.pressed.connect(func() -> void:
		if abilities != null:
			abilities.activate(tower)
		refresh())
	add_child(ability_button)
	target_button = Button.new()
	target_button.position = Vector2(0, -32)
	target_button.size = Vector2(248, 28)
	target_button.add_theme_font_size_override("font_size", 12)
	target_button.focus_mode = Control.FOCUS_NONE
	target_button.pressed.connect(func() -> void:
		tower.target_mode = ((int(tower.target_mode) + 1) % TowerState.TargetMode.size()) as TowerState.TargetMode
		refresh())
	add_child(target_button)
	visible = false

func _process(delta: float) -> void:
	_elapsed += delta
	if visible and _elapsed >= 0.1:
		_elapsed = 0.0
		refresh()

func show_tower(selected: TowerState, upgrades: UpgradeSystem) -> void:
	tower = selected
	system = upgrades
	visible = tower != null
	refresh()

func refresh() -> void:
	if not visible or tower == null:
		return
	target_button.text = "조준: %s  [클릭 전환]" % TowerState.TargetMode.keys()[tower.target_mode].capitalize()
	var started: int = Time.get_ticks_usec() if profile_updates else 0
	var stats: TowerDefinition = tower.combat_definition()
	if _cache_tower != tower or _cache_stats != stats or _cache_permanent != tower.stats or not cache_previews:
		_changes.clear()
		_cache_tower = tower
		_cache_stats = stats
		_cache_permanent = tower.stats
	var main_path: int = UpgradePolicy.main_path(tower.tiers)
	var precise: bool = stats.fire_interval < 0.01 or (main_path >= 0 and tower.tiers[main_path] == 5)
	var interval_text: String = "%.4f" % stats.fire_interval if precise else ("%.3f" % stats.fire_interval if stats.fire_interval < 0.05 else "%.2f" % stats.fire_interval)
	_title.text = "%s  %s" % [tower.definition.display_name, tower.upgrade_text()]
	if main_path >= 0 and tower.tiers[main_path] == 5:
		_title.text = "%s %s" % [tower.definition.upgrade_at(main_path, 5).display_name, tower.upgrade_text()]
	_title.add_theme_font_size_override("font_size", 14 if main_path >= 0 and tower.tiers[main_path] == 5 else 17)
	_stats.text = "공격 %d · 관통 %d · 간격 %s초\n사거리 %d · 속도 %d · %d발 / %.0f°\n%s · 충돌 반경 %.1f%s" % [
		stats.damage, stats.pierce, interval_text, stats.attack_range,
		stats.projectile_speed, stats.projectile_count, stats.spread_degrees,
		AttackSpec.attribute_name(stats.attack_attribute), stats.projectile_radius,
		" · 폭발 %d" % stats.explosion_radius if stats.explosion_radius > 0.0 else ""]
	for path in range(3):
		var item: UpgradeDefinition = tower.definition.upgrade_at(path, tower.tiers[path] + 1)
		_next[path] = item
		var reason: String = system.error_for_path(tower, path)
		var current: String = "%s %d" % [PATH_NAMES[path], tower.tiers[path]]
		_buttons[path].disabled = not reason.is_empty()
		if item == null:
			_buttons[path].text = current + (" · 완료" if tower.tiers[path] >= UpgradePolicy.AVAILABLE_TIER else " · 준비 중")
			_details[path].text = reason
			_buttons[path].tooltip_text = reason
		else:
			if not _changes.has(item.id):
				var preview: TowerDefinition = TowerStatResolver.preview(tower.definition, tower.tiers, item)
				if tower.transformed_stats != null and abilities != null:
					preview = abilities.preview(tower, item)
				_changes[item.id] = stat_changes(stats, preview)
				preview_rebuilds += 1
			var changes: String = _changes[item.id]
			_buttons[path].text = "%s→%d · %s" % [current, item.tier, item.display_name]
			_details[path].text = "%s\n%d G · %s" % [changes, item.cost, "구매 가능" if reason.is_empty() else reason]
			_buttons[path].tooltip_text = "%s\n%s\n%s\n%d G · %s" % [item.display_name, item.description, changes, item.cost, reason]
		_details[path].tooltip_text = _buttons[path].tooltip_text
		_details[path].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_details[path].mouse_filter = Control.MOUSE_FILTER_PASS
	var main: int = UpgradePolicy.main_path(tower.tiers)
	_policy.text = "주력 미확정 · 최대 두 경로" if main < 0 else "%s 주력 · 보조 최대2" % PATH_NAMES[main].split(" · ")[0]
	_title.tooltip_text = "주력 미확정 · 두 경로 중 어느 쪽도 3티어 선택 가능" if main < 0 else "%s 주력 · 보조는 최대 2티어" % PATH_NAMES[main]
	var state: AbilityState = abilities.state_for(tower) if abilities != null else null
	ability_button.visible = state != null
	if state != null:
		ability_button.disabled = not abilities.enabled or state.cooldown_remaining > 0.000001
		var remaining: float = float(abilities.transformations[tower.id].remaining) if abilities.transformations.has(tower.id) else 0.0
		ability_button.text = "%s 발동 · %.0f초 / 최대 %d기" % [state.definition.display_name, state.definition.duration, state.definition.target_limit] if state.cooldown_remaining <= 0.000001 else "대기 %.1f초 · 변신 %.1f초" % [state.cooldown_remaining, remaining]
		ability_button.tooltip_text = "자신+가까운 적격 다트 · 상단3+/하단3+ 제외\n최초 대기 %.2f초 · 재사용 %.0f초 (시뮬레이션 시간)" % [state.definition.initial_cooldown, state.definition.cooldown]
	if tower.transformed_stats != null:
		_title.text += " [변신]"
	_stats.tooltip_text = "영구 공격: %d 피해 / 관통 %d / %.3f초\nCRIT: 매 %d번째 발사에 %d 피해" % [tower.stats.damage, tower.stats.pierce, tower.stats.fire_interval, tower.stats.critical_every, tower.stats.critical_damage]
	_stats.tooltip_text += "\n카모 탐지: %s · 공격 속성 면역은 별도 판정" % ("가능" if stats.detects_camo else "불가")
	if profile_updates:
		refresh_usec += Time.get_ticks_usec() - started
		refresh_count += 1

static func stat_changes(before: TowerDefinition, after: TowerDefinition) -> String:
	var parts: PackedStringArray = []
	var names: Array[String] = ["공격", "관통", "간격", "사거리", "속도", "반경", "길이", "발수", "확산", "각도", "속성", "폭발", "수명", "세라믹", "강화", "넉백 시간", "경량 넉백", "중량 넉백", "도탄 상한", "CRIT 주기", "CRIT 피해", "납 추가", "카모 감지"]
	for index in range(TowerStatResolver.FIELDS.size()):
		var field: StringName = TowerStatResolver.FIELDS[index]
		var first: float = float(before.get(field))
		var second: float = float(after.get(field))
		if is_equal_approx(first, second):
			continue
		if field == &"attack_attribute":
			parts.append("%s %s→%s" % [names[index], AttackSpec.attribute_name(int(first)), AttackSpec.attribute_name(int(second))])
		else:
			parts.append("%s %s→%s" % [names[index], str(snappedf(first, 0.001)), str(snappedf(second, 0.001))])
	return " · ".join(parts) if not parts.is_empty() else "외형 변경"

func _request(path: int) -> void:
	# Emit the exact displayed purchase, never an implicit "buy next" command.
	if _next[path] != null:
		purchase_requested.emit(_next[path])

func _label(at: Vector2, bounds: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.size = bounds
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
