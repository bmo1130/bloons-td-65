class_name TowerStatsPanel
extends Panel

var tower: TowerState
var summary: Label
var detail: Panel
var detail_text: Label
var _elapsed: float = 0.0

func _ready() -> void:
	position = Vector2(984, 614)
	size = Vector2(272, 58)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("182d32")
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	summary = Label.new()
	summary.position = Vector2(16, 1)
	summary.size = Vector2(200, 56)
	summary.add_theme_font_size_override("font_size", 11)
	add_child(summary)
	var button: Button = Button.new()
	button.text = "상세"
	button.position = Vector2(216, 5)
	button.size = Vector2(46, 26)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(func() -> void: detail.visible = not detail.visible; refresh())
	add_child(button)
	detail = Panel.new()
	detail.position = Vector2(-298, -486)
	detail.size = Vector2(282, 340)
	detail.add_theme_stylebox_override("panel", style)
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail)
	detail_text = Label.new()
	detail_text.position = Vector2(14, 10)
	detail_text.size = Vector2(254, 320)
	detail_text.add_theme_font_size_override("font_size", 13)
	detail.add_child(detail_text)
	detail.visible = false
	visible = false

func select(selected: TowerState) -> void:
	tower = selected
	visible = tower != null
	detail.visible = false
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= 0.2:
		_elapsed = 0.0
		refresh()

func refresh() -> void:
	if tower == null or tower.combat_stats == null:
		return
	var record: TowerCombatStats = tower.combat_stats
	summary.text = "Pops %d · 발사 %d\n투자 %d G · Pops/G %.2f\n관통 %d/%d (%.1f%%)" % [record.pops(), record.volleys,
		record.invested_gold, record.pops_per_gold(), record.pierce_used, record.pierce_available, record.pierce_utilization() * 100]
	if detail.visible:
		detail_text.text = "%s #%d · %s\n일반 겹 %d · 특수 외피 %d\n전체 Pops / 유효 피해 %d / %d\n발사 %d · 투사체 %d\n피해 적용 대상 %d회\n면역 접촉 %d회\n투자 %d G · Pops/G %.3f\n관통 사용 %d / 부여 %d\n활용률 %.2f%%\n\n비행 중 관통도 분모에 포함\n같은 대상도 별개 공격이면 재집계" % [record.display_name, record.tower_id, record.build,
			record.normal_pops, record.shell_pops, record.pops(), record.effective_damage, record.volleys, record.projectiles,
			record.targets_damaged, record.immune_contacts, record.invested_gold, record.pops_per_gold(),
			record.pierce_used, record.pierce_available, record.pierce_utilization() * 100]
		detail_text.text += "\nCRIT 발사 %d회 · 유효 피해 %d\n분열탄 %d (발사 횟수와 별도)" % [record.critical_volleys, record.critical_damage, record.split_projectiles]
		detail_text.text += "\nMOAB 외피 피해 %d · 획득 %d G" % [record.moab_damage, record.gold_earned]
