class_name FollowCam
extends Control
## 화면 우상단의 작은 추적 화면. 화염병이 일정 거리 이상 날아가면 따라가며 보여 주고,
## 착탄 뒤에는 착탄점 주변을 잠시 비춰 결과(불, 붕괴)를 가까이서 보여 준다.

const START_DISTANCE := 20.0
const HOLD_TIME := 6.0
const VIEW_SIZE := Vector2i(512, 288)
const MARGIN := 20.0

var _viewport: SubViewport
var _camera: Camera3D
var _target: Projectile
var _origin := Vector3.ZERO
var _dir := Vector3.FORWARD
var _impact := Vector3.INF
var _hold := 0.0
var _cam_from := Vector3.ZERO
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -VIEW_SIZE.x - MARGIN
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = MARGIN + VIEW_SIZE.y

	var border := ColorRect.new()
	border.color = Color(0.05, 0.05, 0.05, 0.9)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -3
	border.offset_top = -3
	border.offset_right = 3
	border.offset_bottom = 3
	add_child(border)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 1500.0
	_camera.current = true
	_viewport.add_child(_camera)
	visible = false


func track(p: Projectile) -> void:
	_target = p
	_origin = p.global_position
	_dir = Vector3(p.velocity.x, 0, p.velocity.z).normalized()
	_impact = Vector3.INF
	_hold = 0.0
	_set_shown(false)
	p.impacted.connect(_on_impacted)


func camera() -> Camera3D:
	return _camera


func reset() -> void:
	_target = null
	_hold = 0.0
	_set_shown(false)


func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func _on_impacted(p: Projectile, pos: Vector3, _normal: Vector3, collider: Object) -> void:
	if p != _target or not visible or collider == null:
		return
	_impact = pos
	_hold = HOLD_TIME
	_cam_from = _camera.global_position
	shake(0.6)


func _set_shown(on: bool) -> void:
	visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 1.5)
	var s := _shake * _shake * 0.5
	_camera.h_offset = sin(_t * 53.0) * s
	_camera.v_offset = cos(_t * 41.0) * s

	if _hold > 0.0:
		# 착탄 뒤: 약간 물러서고 높아지며 착탄점을 비춘다
		_hold -= delta
		var k := clampf(1.0 - _hold / HOLD_TIME, 0.0, 1.0)
		var settle := 1.0 - pow(1.0 - minf(k * 3.0, 1.0), 3.0)
		var side := _dir.cross(Vector3.UP).normalized()
		var wide := _impact - _dir * 14.0 + side * 5.0 + Vector3.UP * 6.0
		_camera.global_position = _cam_from.lerp(wide, settle)
		_camera.look_at(_impact + Vector3.UP * 1.5, Vector3.UP)
		if _hold <= 0.0:
			_set_shown(false)
		return

	if is_instance_valid(_target) and not _target.done:
		var p := _target.global_position
		if not visible and Vector2(p.x - _origin.x, p.z - _origin.z).length() >= START_DISTANCE:
			_set_shown(true)
		if visible:
			# 화염병 뒤쪽 옆에서 따라가며 진행 방향 앞을 본다
			var side := _dir.cross(Vector3.UP).normalized()
			_camera.global_position = p - _dir * 6.0 + side * 2.0 + Vector3.UP * 1.5
			_camera.look_at(p + _dir * 4.0, Vector3.UP)
	elif visible:
		_set_shown(false)
