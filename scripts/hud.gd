class_name Hud
extends CanvasLayer
## 화면 중앙의 작은 점, 목표, 탄약, 클리어/실패 표시. 포물선이나 낙하 지점은 보여 주지 않는다.

var _title: Label
var _objective: Label
var _ammo: Label
var _banner: Label
var _sub: Label
var _toast: Label
var _help: Label
var _toast_time := 0.0
var _stage: Stage


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Apple SD Gothic Neo", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 20
	root.theme = theme
	add_child(root)

	# 조준점: 작은 점 하나
	var dot_bg := ColorRect.new()
	dot_bg.color = Color(0, 0, 0, 0.6)
	dot_bg.size = Vector2(6, 6)
	dot_bg.set_anchors_preset(Control.PRESET_CENTER)
	dot_bg.position = Vector2(-3, -3)
	dot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot_bg)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1)
	dot.size = Vector2(2, 2)
	dot.position = Vector2(2, 2)
	dot_bg.add_child(dot)

	_title = _label(root, 24)
	_title.position = Vector2(24, 18)
	_objective = _label(root, 18)
	_objective.position = Vector2(24, 52)

	_ammo = _label(root, 22)
	_ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_ammo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ammo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ammo.position = Vector2(-24, -24)

	_help = _label(root, 15)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.position = Vector2(24, -20)
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.text = "WASD 이동 · 마우스 시점 · 좌클릭 투척 · 우클릭 줌 · 1/2·휠 탄종 · R 재시작 · F1~F6 스테이지 · Esc 마우스 해제"

	_banner = _label(root, 64)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position = Vector2(0, -150)
	_sub = _label(root, 22)
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub.position = Vector2(0, -70)

	_toast = _label(root, 26)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position = Vector2(0, 60)


func _label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func bind(stage: Stage) -> void:
	_stage = stage
	_title.text = stage.title
	_objective.text = stage.objective
	_banner.text = ""
	_sub.text = ""
	_toast.text = ""
	stage.ammo_changed.connect(_refresh_ammo)
	stage.state_changed.connect(_on_state)
	stage.toast.connect(show_toast)
	_refresh_ammo()


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = 2.0


func _refresh_ammo() -> void:
	if not is_instance_valid(_stage):
		return
	var lines := PackedStringArray()
	for i in _stage.ammo_slots.size():
		var slot: Dictionary = _stage.ammo_slots[i]
		var mark := "▶ " if i == _stage.current_slot else "   "
		lines.append("%s%d  %s  × %d" % [mark, i + 1, slot.type.display_name, slot.count])
	_ammo.text = "\n".join(lines)


func _on_state(state: int, message: String) -> void:
	if state == Stage.State.CLEARED:
		_banner.text = "클리어"
		_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_sub.text = "%s · 투척 %d회\nEnter 다음 스테이지 · R 다시 하기" % [message, _stage.throws]
	else:
		_banner.text = "실패"
		_banner.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		_sub.text = "%s\nR 다시 하기" % message


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
