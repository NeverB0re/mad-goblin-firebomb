class_name IntroCam
extends Camera3D
## 진지 시작 조망: 진지 전체를 높은 곳에서 한 바퀴 돌며 보여 준 뒤, 고블린의 투척 시점으로 부드럽게 내려온다.
## 아무 키나 마우스 단추를 누르면 바로 투척 시점으로 넘어간다. 도는 동안 고블린은 움직이거나 던지지 않는다.

signal finished

const ORBIT_TIME := 5.0
const MOVE_TIME := 1.3
const SKIP_MOVE := 0.35

var _stage: Stage
var _center := Vector3.ZERO
var _radius := 40.0
var _height := 25.0
var _start_angle := 0.0
var _t := 0.0
var _move_from := Transform3D.IDENTITY
var _moving := false
var _move_t := 0.0
var _move_len := MOVE_TIME
var _done := false
var _ui: CanvasLayer


func setup(stage: Stage) -> void:
	_stage = stage
	var pts: Array[Vector3] = []
	for c in stage.commanders:
		pts.append(c.global_position)
	for b in stage.ballistas:
		pts.append(b.global_position)
	if pts.is_empty():
		pts.append(stage.player.global_position + Vector3(0, 0, -40))
	for p in pts:
		_center += p
	_center /= pts.size()
	_center.y = 2.0
	var spread := 10.0
	for p in pts:
		spread = maxf(spread, Vector2(p.x - _center.x, p.z - _center.z).length())
	_radius = spread + 24.0
	_height = 16.0 + spread * 0.6
	# 고블린 쪽에서 출발해 한 바퀴 돈다
	var pp := stage.player.global_position
	_start_angle = atan2(pp.x - _center.x, pp.z - _center.z)
	fov = 60.0
	far = 1500.0
	stage.player.input_locked = true
	_place(0.0)
	make_current()
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var title := Label.new()
	title.text = stage.title
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-400, 40)
	title.size = Vector2(800, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(title)
	var hint := Label.new()
	hint.text = Texts.t("skip_intro")
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-300, -60)
	hint.size = Vector2(600, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(hint)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "sans-serif"])
	title.add_theme_font_override("font", font)
	hint.add_theme_font_override("font", font)


func _place(k: float) -> void:
	var a := _start_angle + TAU * k
	global_position = _center + Vector3(sin(a) * _radius, _height, cos(a) * _radius)
	look_at(_center, Vector3.UP)


## 바로 투척 시점으로 (짧게 내려온다).
func skip() -> void:
	if _moving or _done:
		return
	_begin_move(SKIP_MOVE)


func _begin_move(seconds: float) -> void:
	_moving = true
	_move_t = 0.0
	_move_len = seconds
	_move_from = global_transform


func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		skip()


func _process(delta: float) -> void:
	if _done or not is_instance_valid(_stage) or _stage.player == null:
		return
	if not _moving:
		_t += delta
		var k := _t / ORBIT_TIME
		if k >= 1.0:
			_place(1.0)
			_begin_move(MOVE_TIME)
		else:
			# 느리게 시작해 느리게 끝나는 한 바퀴
			_place(k - sin(TAU * k) / TAU)
		return
	_move_t += delta
	var m := clampf(_move_t / _move_len, 0.0, 1.0)
	var e := m * m * (3.0 - 2.0 * m)
	var to := _stage.player.camera.global_transform
	global_transform = Transform3D(_move_from.basis.slerp(to.basis, e).orthonormalized(), _move_from.origin.lerp(to.origin, e))
	if m >= 1.0:
		_finish()


func _finish() -> void:
	_done = true
	_stage.player.input_locked = false
	_stage.player.camera.make_current()
	finished.emit()
	queue_free()
