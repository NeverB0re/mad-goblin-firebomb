class_name FollowCam
extends Control
## 화면 우상단의 작은 추적 화면. 폭탄이 손을 떠나는 순간부터 바짝 붙어 따라가며(흔들리고 기울며) 궤적을 보여 주고,
## 착탄 뒤에는 착탄점 주변을 잠시 비춰 결과(불, 붕괴)를 가까이서 보여 준다.
## 조명탄은 따라가지 않는다. 대신 조명탄을 보고 날아가는 로켓을 뒤에서 따라간다.

const START_DISTANCE := 0.0
const HOLD_TIME := 6.0
const VIEW_SIZE := Vector2i(512, 288)
const MARGIN := 20.0

var _viewport: SubViewport
var _camera: Camera3D
## 따라가는 것: 투척체(Projectile) 또는 로켓(Missile). 둘 다 done이 있다
var _target: Node3D
var _rocket := false
var _last_pos := Vector3.ZERO
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
	_begin(p, Vector3(p.velocity.x, 0, p.velocity.z), false)
	p.impacted.connect(_on_impacted)


## 조명탄을 보고 발사대를 떠난 로켓을 따라간다.
func track_rocket(m: Missile) -> void:
	_begin(m, m.target_pos() - m.global_position, true)
	m.exploded.connect(_on_rocket_exploded.bind(m))


## 조명탄을 보고 날아오른 글라이더 폭격 고블린을 따라간다.
func track_bomber(b: Bomber) -> void:
	_begin(b, b.target_pos() - b.global_position, true)
	b.exploded.connect(_on_rocket_exploded.bind(b))


func _begin(node: Node3D, heading: Vector3, rocket: bool) -> void:
	_target = node
	_rocket = rocket
	_origin = node.global_position
	_last_pos = _origin
	heading.y = 0.0
	_dir = heading.normalized() if heading.length() > 0.01 else Vector3.FORWARD
	_impact = Vector3.INF
	_hold = 0.0
	_set_shown(false)


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
	_hold_at(pos)
	shake(0.6 if p.ammo.kind != AmmoType.Kind.HE else 1.0)


func _on_rocket_exploded(pos: Vector3, m: Node3D) -> void:
	if m != _target or not visible:
		return
	_hold_at(pos)
	shake(1.0)


func _hold_at(pos: Vector3) -> void:
	_impact = pos
	_hold = HOLD_TIME
	_cam_from = _camera.global_position


func _set_shown(on: bool) -> void:
	visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 1.2)

	if _hold > 0.0:
		# 착탄 뒤: 약간 물러서고 높아지며 착탄점을 비춘다 (로켓은 훨씬 멀리서 크게)
		_hold -= delta
		var k := clampf(1.0 - _hold / HOLD_TIME, 0.0, 1.0)
		var settle := 1.0 - pow(1.0 - minf(k * 3.0, 1.0), 3.0)
		var side := _dir.cross(Vector3.UP).normalized()
		var far := 2.6 if _rocket else 1.0
		var wide := _impact - _dir * 10.0 * far + side * 3.5 * far + Vector3.UP * 4.5 * far
		_camera.global_position = _cam_from.lerp(wide, settle)
		_camera.look_at(_impact + Vector3.UP * 1.5 * far, Vector3.UP)
		_apply_shake(0.0)
		if _hold <= 0.0:
			_set_shown(false)
		return

	if is_instance_valid(_target) and not _target.get("done"):
		var p := _target.global_position
		if not visible and Vector2(p.x - _origin.x, p.z - _origin.z).length() >= START_DISTANCE:
			_set_shown(true)
		if visible:
			var vel := (p - _last_pos) / maxf(delta, 0.001)
			_last_pos = p
			var side := _dir.cross(Vector3.UP).normalized()
			if _rocket:
				# 로켓 꽁무니 옆뒤에서 (불꽃이 화면을 가리지 않게) 표적 쪽을 본다
				var fwd := vel.normalized() if vel.length() > 0.5 else _dir
				_camera.global_position = p - fwd * 10.0 + side * 4.0 + Vector3.UP * 3.0
				_camera.look_at(p + fwd * 12.0, Vector3.UP)
				_apply_shake(0.5)
			else:
				# 폭탄에 바짝 붙어 옆뒤에서 따라가며 진행 방향 앞을 본다
				_camera.global_position = p - _dir * 2.6 + side * 0.9 + Vector3.UP * 0.7
				_camera.look_at(p + _dir * 5.0 + Vector3.DOWN * 0.3, Vector3.UP)
				_apply_shake(0.25)
	elif visible:
		_set_shown(false)


## 흔들림: 착탄 충격(_shake)과 날아가는 동안의 잔떨림(base), 기울기(롤)로 속도감을 준다.
func _apply_shake(base: float) -> void:
	var s := _shake * _shake * 0.9 + base * 0.06
	_camera.h_offset = sin(_t * 53.0) * s + sin(_t * 17.0) * s * 0.5
	_camera.v_offset = cos(_t * 41.0) * s
	_camera.rotate_object_local(Vector3.FORWARD, sin(_t * 3.1) * 0.06 * base + sin(_t * 47.0) * _shake * _shake * 0.05)
