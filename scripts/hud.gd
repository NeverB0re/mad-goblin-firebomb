class_name Hud
extends CanvasLayer
## 화면 중앙의 작은 점, 스테이지 번호, 탄약. 목표 문구·포물선·낙하 지점은 보여 주지 않는다
## (무엇을 해야 할지는 재질과 직접 던져 보며 알아낸다). 조작 안내는 첫 투척 뒤 사라진다.

var _title: Label
var _ammo: Label
var _banner: Label
var _sub: Label
var _toast: Label
var _help: Label
var _toast_time := 0.0
var _stage: Stage
var follow_cam: FollowCam
var _dot: Control
## 남은 지휘관 표시 (빨간 깃발 = 남음, 쓰러진 깃발 = 쓰러뜨림). 지휘관이 둘 이상일 때만
var _targets: HBoxContainer


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
	_dot = dot_bg
	dot_bg.color = Color(0, 0, 0, 0.6)
	dot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot_bg)
	_place(dot_bg, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-3, -3, 3, 3))
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1)
	dot.size = Vector2(2, 2)
	dot.position = Vector2(2, 2)
	# 마우스가 캡처되면 커서가 화면 중앙(이 점 위)에 있으므로 입력을 가로채지 않게 한다
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_bg.add_child(dot)

	_title = _label(root, 24)
	_place(_title, Vector4(0, 0, 0, 0), Vector4(24, 16, 900, 50))

	_targets = HBoxContainer.new()
	_targets.add_theme_constant_override("separation", 8)
	_targets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_targets)
	_place(_targets, Vector4(0, 0, 0, 0), Vector4(26, 56, 400, 90))

	_ammo = _label(root, 22)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_place(_ammo, Vector4(1, 1, 1, 1), Vector4(-600, -140, -24, -20))

	_help = _label(root, 15)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_help.modulate = Color(1, 1, 1, 0.75)
	_help.text = Texts.t("help")
	_place(_help, Vector4(0, 1, 0, 1), Vector4(24, -50, 1000, -18))

	_banner = _label(root, 64)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner, Vector4(0, 0.5, 1, 0.5), Vector4(0, -220, 0, -130))
	_sub = _label(root, 22)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sub, Vector4(0, 0.5, 1, 0.5), Vector4(0, -125, 0, -5))

	follow_cam = FollowCam.new()
	root.add_child(follow_cam)

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
	_title.text = stage.stage_id
	_help.visible = true
	stage.projectile_thrown.connect(func(_p): _help.visible = false)
	_banner.text = ""
	_sub.text = ""
	_toast.text = ""
	set_gameplay_visible(true)
	stage.ammo_changed.connect(_refresh_ammo)
	stage.state_changed.connect(_on_state)
	stage.toast.connect(show_toast)
	stage.targets_changed.connect(_refresh_targets)
	_refresh_targets()
	follow_cam.reset()
	stage.projectile_thrown.connect(follow_cam.track)
	stage.shake_requested.connect(follow_cam.shake)
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


func _refresh_targets() -> void:
	for c in _targets.get_children():
		c.queue_free()
	if not is_instance_valid(_stage) or _stage.commanders.size() < 2:
		return
	for c in _stage.commanders:
		_targets.add_child(_flag_icon(not c.dead))


## 작은 깃발 그림 (깃대 + 천). 쓰러뜨린 지휘관은 어둡게 눕힌다.
func _flag_icon(alive: bool) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(26, 30)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pole := ColorRect.new()
	pole.color = Color(0.15, 0.1, 0.05)
	pole.position = Vector2(4, 0)
	pole.size = Vector2(3, 30)
	box.add_child(pole)
	var cloth := ColorRect.new()
	cloth.color = Color(0.9, 0.12, 0.08) if alive else Color(0.3, 0.3, 0.3, 0.7)
	cloth.position = Vector2(7, 1)
	cloth.size = Vector2(17, 12)
	box.add_child(cloth)
	if not alive:
		box.pivot_offset = Vector2(5, 30)
		box.rotation = 1.2
		box.modulate = Color(1, 1, 1, 0.6)
	return box


## 승리·실패 화면은 ResultScreen이 그린다. 여기서는 아무것도 하지 않는다.
func _on_state(_state: int, _message: String) -> void:
	pass


## 승리 연출·실패 그림 동안에는 조준점, 탄약, 추적 화면을 숨긴다.
func set_gameplay_visible(on: bool) -> void:
	for n in [_title, _ammo, _help, _toast, _banner, _sub, _targets]:
		n.visible = on
	if _dot:
		_dot.visible = on
	if not on:
		follow_cam.reset()

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
