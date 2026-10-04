class_name Hud
extends CanvasLayer
## 화면 중앙의 작은 점, 스테이지 번호, 탄약(그림 + 개수). 목표 문구·포물선·낙하 지점은 보여 주지 않는다
## (무엇을 해야 할지는 재질과 직접 던져 보며 알아낸다). 조작 안내는 첫 투척 뒤 사라진다.

var _title: Label
## 왼쪽 위 판 (진지 번호 + 보조 목표)
var _top: PanelContainer
## 별 셋째 칸 보조 목표 (☆ + 고블린 말)
var _bonus: Label
## 탄약 줄: 탄종 그림, 숫자 키, 남은 개수 (글자 대신 그림)
var _ammo: HBoxContainer
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
## 이미 쓰러진 것으로 표시한 지휘관 (새로 쓰러진 것만 튀게)
var _seen_dead := {}
## 발사 버튼 곁에서 뜨는 안내 (최종 진지)
var _prompt: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme(20)
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

	_top = PanelContainer.new()
	_top.add_theme_stylebox_override("panel", UiStyle.panel(0.55, 12, 9))
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top)
	_place(_top, Vector4(0, 0, 0, 0), Vector4(20, 16, 20, 16))
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(top_row)
	_title = UiStyle.label("", 24, UiStyle.GOLD, true)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_title)
	_bonus = _label(top_row, 16)
	_bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_targets = HBoxContainer.new()
	_targets.add_theme_constant_override("separation", 8)
	_targets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_targets)
	_place(_targets, Vector4(0, 0, 0, 0), Vector4(28, 70, 400, 104))

	_ammo = HBoxContainer.new()
	_ammo.alignment = BoxContainer.ALIGNMENT_END
	_ammo.add_theme_constant_override("separation", 6)
	_ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ammo)
	_place(_ammo, Vector4(1, 1, 1, 1), Vector4(-760, -170, -24, -16))

	var help_row := HBoxContainer.new()
	help_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help_row)
	_place(help_row, Vector4(0, 1, 0, 1), Vector4(20, -54, 1100, -18))
	_help = _label(help_row, 15)
	_help.add_theme_color_override("font_color", UiStyle.MUTED)
	_help.add_theme_stylebox_override("normal", UiStyle.panel(0.5, 10, 8))
	_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_help.text = Texts.t("help")

	_banner = _label(root, 64)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner, Vector4(0, 0.5, 1, 0.5), Vector4(0, -220, 0, -130))
	_sub = _label(root, 22)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_sub, Vector4(0, 0.5, 1, 0.5), Vector4(0, -125, 0, -5))

	follow_cam = FollowCam.new()
	root.add_child(follow_cam)

	_prompt = _label(root, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", UiStyle.GOLD)
	_prompt.text = Texts.t("press_button")
	_prompt.visible = false
	_place(_prompt, Vector4(0, 0.5, 1, 0.5), Vector4(0, 110, 0, 150))

	# 알림: 가운데 아래쪽의 작은 판 (글 길이에 맞춰 줄고 는다)
	var toast_row := CenterContainer.new()
	toast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_row)
	_place(toast_row, Vector4(0, 0.5, 1, 0.5), Vector4(0, 50, 0, 100))
	_toast = _label(toast_row, 24)
	_toast.add_theme_stylebox_override("normal", UiStyle.panel(0.6, 12, 10))
	_toast.modulate.a = 0.0


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
	var l := UiStyle.label("", font_size)
	parent.add_child(l)
	return l


func bind(stage: Stage) -> void:
	_stage = stage
	_seen_dead.clear()
	_title.text = stage.stage_id
	_help.visible = true
	stage.projectile_thrown.connect(func(_p): _help.visible = false)
	_banner.text = ""
	_sub.text = ""
	_toast.text = ""
	_toast.modulate.a = 0.0
	set_gameplay_visible(true)
	stage.ammo_changed.connect(_refresh_ammo)
	stage.state_changed.connect(_on_state)
	stage.toast.connect(show_toast)
	stage.targets_changed.connect(_refresh_targets)
	_refresh_targets()
	follow_cam.reset()
	stage.projectile_thrown.connect(follow_cam.track)
	stage.rocket_launched.connect(follow_cam.track_rocket)
	stage.bomber_launched.connect(follow_cam.track_bomber)
	stage.shake_requested.connect(follow_cam.shake)
	_refresh_ammo()


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_time = 2.0


func _refresh_ammo() -> void:
	if not is_instance_valid(_stage):
		return
	for c in _ammo.get_children():
		c.queue_free()
	for i in _stage.ammo_slots.size():
		var slot: Dictionary = _stage.ammo_slots[i]
		var icon_kind := UiIcon.of_ammo(slot.type.kind)
		var title: String = slot.type.display_name
		# 폭격 진지: 조명탄 칸 대신 글라이더 칸 (조명탄 하나 = 글라이더 폭격 한 번)
		if slot.type.kind == AmmoType.Kind.FLARE and _stage.bombers_total > 0:
			icon_kind = "bomber"
			title = Texts.t("airstrike_name")
		_ammo.add_child(_ammo_cell(icon_kind, slot.count, str(i + 1), i == _stage.current_slot, title))
	if _stage.button_ready():
		_ammo.add_child(_ammo_cell("rocket", 1, "E", false, Texts.t("rocket_name")))


## 탄약 한 칸: 위에 숫자 키, 가운데 그림, 그 아래 고블린식 이름과 ×개수. 고른 칸은 밝은 판 위에 크게, 다 쓴 칸은 흐리게.
func _ammo_cell(icon_kind: String, count: int, key: String, selected: bool, title := "") -> Control:
	var cell := PanelContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UiStyle.panel(0.8 if selected else 0.5, 12, 6.0)
	if selected:
		bg.border_color = UiStyle.GOLD
		bg.set_border_width_all(2)
	cell.add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(col)
	var top := _label(col, 14)
	top.text = key
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_color_override("font_color", UiStyle.MUTED)
	var row := HBoxContainer.new()
	row.name = "Icons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var icon := UiIcon.make(icon_kind, 56.0 if selected else 44.0)
	row.add_child(icon)
	if title != "":
		var name_l := _label(col, 15 if selected else 13)
		name_l.text = title
		if selected:
			name_l.add_theme_color_override("font_color", UiStyle.GOLD)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var n := _label(col, 22 if selected else 18)
	n.name = "Count"
	n.text = "×%d" % count
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if count <= 0:
		cell.modulate = Color(1, 1, 1, 0.35)
	cell.size_flags_vertical = Control.SIZE_SHRINK_END
	return cell


func _refresh_targets() -> void:
	for c in _targets.get_children():
		c.queue_free()
	if not is_instance_valid(_stage) or _stage.commanders.size() < 2:
		_seen_dead.clear()
		return
	for c in _stage.commanders:
		var icon := _flag_icon(not c.dead)
		_targets.add_child(icon)
		if c.dead and not _seen_dead.has(c):
			# 방금 쓰러뜨린 지휘관: 깃발 표시가 크게 튀었다가 자리에 눕고, 붉은 X가 그어진다
			_seen_dead[c] = true
			var x := Label.new()
			x.text = "X"
			x.add_theme_font_size_override("font_size", 30)
			x.add_theme_color_override("font_color", Color(1, 0.2, 0.1))
			x.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			x.add_theme_constant_override("outline_size", 6)
			x.position = Vector2(-2, -8)
			icon.add_child(x)
			var base_rot := icon.rotation
			icon.scale = Vector2.ONE * 2.4
			icon.rotation = 0.0
			var tw := icon.create_tween().set_parallel(true)
			tw.tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "rotation", base_rot, 0.5).set_delay(0.25)
		elif c.dead:
			icon.add_child(_x_mark())


func _x_mark() -> Label:
	var x := Label.new()
	x.text = "X"
	x.add_theme_font_size_override("font_size", 30)
	x.add_theme_color_override("font_color", Color(1, 0.2, 0.1, 0.8))
	x.position = Vector2(-2, -8)
	return x


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


## 보조 목표 한 줄 (빈 글이면 숨김).
func set_bonus(text: String) -> void:
	_bonus.text = ("☆ " + text) if text != "" else ""
	_bonus.visible = text != "" and _top.visible


## 승리·실패 화면은 ResultScreen이 그린다. 여기서는 아무것도 하지 않는다.
func _on_state(_state: int, _message: String) -> void:
	pass


## 승리 연출·실패 그림 동안에는 조준점, 탄약, 추적 화면을 숨긴다.
func set_gameplay_visible(on: bool) -> void:
	for n in [_top, _title, _bonus, _ammo, _help, _toast, _banner, _sub, _targets]:
		n.visible = on
	_bonus.visible = on and _bonus.text != ""
	if _dot:
		_dot.visible = on
	if not on:
		follow_cam.reset()

func _process(delta: float) -> void:
	_prompt.visible = is_instance_valid(_stage) and _title.visible and _stage.near_button()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.6, 0.0, 1.0)
