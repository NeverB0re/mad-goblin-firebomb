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
	dot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot_bg)
	_place(dot_bg, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-3, -3, 3, 3))
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1)
	dot.size = Vector2(2, 2)
	dot.position = Vector2(2, 2)
	dot_bg.add_child(dot)

	_title = _label(root, 24)
	_place(_title, Vector4(0, 0, 0, 0), Vector4(24, 16, 900, 50))
	_objective = _label(root, 18)
	_place(_objective, Vector4(0, 0, 0, 0), Vector4(24, 52, 1100, 80))

	_ammo = _label(root, 22)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_ammo, Vector4(1, 1, 1, 1), Vector4(-600, -140, -24, -20))

	_help = _label(root, 15)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.text = "WASD 이동 · 마우스 시점 · 좌클릭 투척 · 우클릭 줌 · 1/2·휠 탄종 · R 재시작 · F1~F6 스테이지 · Esc 마우스 해제"
	_place(_help, Vector4(0, 1, 0, 1), Vector4(24, -50, 1000, -18))

	_banner = _label(root, 64)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner, Vector4(0, 0.5, 1, 0.5), Vector4(0, -220, 0, -130))
	_sub = _label(root, 22)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sub, Vector4(0, 0.5, 1, 0.5), Vector4(0, -125, 0, -50))

	_toast = _label(root, 26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_toast, Vector4(0, 0.5, 1, 0.5), Vector4(0, 50, 0, 95))


## 앵커(왼, 위, 오른, 아래)와 오프셋으로 배치한다.
func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w

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
