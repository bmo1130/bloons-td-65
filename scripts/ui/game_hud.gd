class_name GameHUD
extends CanvasLayer

signal build_requested
signal wave_requested
signal speed_requested
signal restart_requested

const INK: Color = Color("e9f3ef")
const MUTED: Color = Color("9ab2ad")
const MINT: Color = Color("8ce8bc")

var _root: Control
var _gold: Label
var _lives: Label
var _wave: Label
var _status: Label
var _hint: Label
var _build: Button
var _start: Button
var _speed: Button
var _result: Panel
var _result_title: Label
var _result_detail: Label
var _tower_definition: TowerDefinition
var _tower_stats: Label
var _tower_attack: Label

func _ready() -> void:
	_root = Control.new()
	_root.name = "HUD"
	_root.size = Vector2(1280, 720)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo"])
	var theme: Theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	_root.theme = theme
	add_child(_root)
	_panel(Rect2(24, 24, 1232, 80), Color("182d32"))
	_label("풍타디 6.5", Rect2(46, 30, 340, 40), 28, INK)
	_label("CORE COMBAT PROTOTYPE", Rect2(48, 72, 340, 20), 12, MUTED)
	_label("목숨", Rect2(622, 36, 80, 24), 14, MUTED)
	_lives = _label("20", Rect2(622, 61, 100, 30), 24, MINT)
	_label("골드", Rect2(790, 36, 80, 24), 14, MUTED)
	_gold = _label("200 G", Rect2(790, 61, 140, 30), 24, Color("f4d590"))
	_label("웨이브", Rect2(1008, 36, 120, 24), 14, MUTED)
	_wave = _label("0 / 3", Rect2(1008, 61, 180, 30), 24, INK)
	_panel(Rect2(984, 128, 272, 544), Color("182d32"))
	_label("방어 준비", Rect2(1008, 148, 224, 32), 22, INK)
	_label("타워를 설치해 경로를 지키세요", Rect2(1008, 184, 224, 24), 14, MUTED)
	_build = _button("다트 타워   ·   65 G  [D]", Rect2(1008, 228, 224, 52))
	_build.pressed.connect(func() -> void: build_requested.emit())
	_tower_stats = _label("", Rect2(1008, 294, 224, 24), 14, MUTED)
	_tower_attack = _label("", Rect2(1008, 322, 224, 24), 14, MUTED)
	_hint = _label("D 또는 타워 버튼으로 배치 시작\n초록 원: 설치 가능 / 빨강 원: 불가\n우클릭 또는 Esc: 배치 취소", Rect2(1008, 366, 224, 84), 13, MUTED)
	_status = _label("첫 웨이브를 시작하세요", Rect2(1008, 464, 224, 30), 15, MINT)
	_start = _button("웨이브 1 시작  [Space]", Rect2(1008, 506, 224, 48))
	_start.pressed.connect(func() -> void: wave_requested.emit())
	_speed = _button("속도 ×1", Rect2(1008, 568, 104, 38))
	_speed.pressed.connect(func() -> void: speed_requested.emit())
	var restart: Button = _button("다시 시작", Rect2(1122, 568, 110, 38))
	restart.pressed.connect(func() -> void: restart_requested.emit())
	_label("빨강 1겹 / 파랑 2겹 · 겹당 +1 G", Rect2(1008, 628, 224, 24), 12, MUTED)
	_label("입구", Rect2(40, 436, 72, 24), 13, MINT)
	_label("출구", Rect2(882, 160, 72, 24), 13, Color("f6b27a"))
	_label("자유 배치  /  길 위·타워 중첩 불가", Rect2(26, 686, 600, 22), 13, MUTED)
	_label("3개 웨이브를 버티면 승리", Rect2(984, 686, 272, 22), 13, MUTED)
	_create_result()

func set_stats(gold: int, lives: int) -> void:
	_gold.text = "%d G" % gold
	_lives.text = str(lives)
	_lives.modulate = Color("f67878") if lives <= 5 else Color.WHITE

func configure_tower(definition: TowerDefinition) -> void:
	_tower_definition = definition
	_tower_stats.text = "사거리 %d  ·  공격 간격 %.1f초" % [definition.attack_range, definition.fire_interval]
	_tower_attack.text = "앞선 풍선 우선 / 다트 피해 %d" % definition.damage
	_build.text = "%s   ·   %d G  [D]" % [definition.display_name, definition.cost]

func set_wave(number: int, total: int, active: bool, clear_reward: int = 0) -> void:
	_wave.text = "%d / %d" % [number, total]
	_start.disabled = active or number >= total
	_start.text = "웨이브 진행 중" if active else "웨이브 %d 시작  [Space]" % (number + 1)
	if active:
		_status.text = "풍선이 다가옵니다!"
	elif number == 0:
		_status.text = "첫 웨이브를 시작하세요"
	else:
		_status.text = "웨이브 완료  ·  보너스 +%d G" % clear_reward

func set_building(enabled: bool, hint: String) -> void:
	_build.text = "배치 중 · 클릭하여 설치  [D]" if enabled else "%s   ·   %d G  [D]" % [_tower_definition.display_name, _tower_definition.cost]
	_build.modulate = MINT if enabled else Color.WHITE
	_hint.text = hint

func set_speed(speed: int) -> void:
	_speed.text = "속도 ×%d" % speed

func show_result(won: bool, gold: int) -> void:
	_result.visible = true
	_result_title.text = "승리!" if won else "방어 실패"
	_result_title.modulate = MINT if won else Color("f67878")
	_result_detail.text = "3개 웨이브를 막았습니다. 남은 골드: %d G" % gold if won else "목숨을 모두 잃었습니다. 타워 위치를 바꿔보세요."
	_start.disabled = true
	_build.disabled = true
	_speed.disabled = true
	_status.text = "모든 웨이브 완료" if won else "게임 종료"

func _create_result() -> void:
	_result = _panel(Rect2(244, 280, 496, 188), Color("13272e"))
	_result.visible = false
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_title = Label.new()
	_result_title.position = Vector2(28, 18)
	_result_title.size = Vector2(440, 42)
	_result_title.add_theme_font_size_override("font_size", 30)
	_result.add_child(_result_title)
	_result_detail = Label.new()
	_result_detail.position = Vector2(28, 72)
	_result_detail.size = Vector2(440, 30)
	_result_detail.add_theme_font_size_override("font_size", 15)
	_result.add_child(_result_detail)
	var restart: Button = Button.new()
	restart.text = "다시 도전"
	restart.position = Vector2(28, 122)
	restart.size = Vector2(440, 42)
	_style_button(restart)
	_result.add_child(restart)
	restart.pressed.connect(func() -> void: restart_requested.emit())

func _label(text: String, rect: Rect2, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label

func _panel(rect: Rect2, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("2b4549")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	return panel

func _button(text: String, rect: Rect2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	_style_button(button)
	_root.add_child(button)
	return button

func _style_button(button: Button) -> void:
	# Space is the global wave shortcut, even after clicking a HUD button.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("35564f") if state in ["hover", "pressed"] else Color("24423e")
		if state == "disabled":
			style.bg_color = Color("203438")
		style.border_color = MINT if state in ["hover", "focus"] else Color("42655b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		button.add_theme_stylebox_override(state, style)
