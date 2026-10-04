class_name Bomber
extends Node3D
## 글라이더 폭격 고블린 (4·5월드). 투척 구역 옆에서 대기하다가 조명탄이 떨어지면 바위에서 뛰어올라 그 불빛 위까지 활공하고,
## 자기 몸통만 한 폭탄을 끌어안은 채 뛰어내린다. 아주 크게 터져 근처 지휘관을 엄폐와 상관없이 한꺼번에 쓰러뜨리고,
## 고블린 본인은 신나게 멀리 날아간다 (웃음소리는 나중에 붙인다).
## 대공 발리스타가 하나라도 남아 있으면 날아가는 도중 화살에 맞아 빙글빙글 불시착한다 (폭탄은 불발).
## 시간은 물리 틱으로 세서 언제나 같다.

signal exploded(pos: Vector3)

## 바위에서 도움닫기해 뛰어오르는 시간
const DELAY_TICKS := 30
const FLIGHT_TICKS := 150
## 뛰어내려 떨어지는 시간
const DROP_TICKS := 42
## 뛰어내리는 높이 (표적 위)
const RELEASE_HEIGHT := 14.0
const ARC := 10.0
const RADIUS := 14.0
const STRENGTH := 1400.0
## 엄폐와 상관없이 쓰러뜨리는 거리 (조명탄이 조금 빗나가도 진지가 끝나게)
const KILL_RADIUS := 12.0
const CRASH_TICKS := 60

var done := false
var _stage: Stage
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _release := Vector3.ZERO
var _tick := 0
var _intercept := false
var _model: Node3D
var _pilot: Node3D
var _phase := 0
var _phase_tick := 0
var _drop_from := Vector3.ZERO
var _crash_from := Vector3.ZERO
var _crash_to := Vector3.ZERO
var _fly_vel := Vector3.ZERO


func setup(stage: Stage, target: Vector3, from: Vector3, model: Node3D) -> void:
	_stage = stage
	_target = target
	_from = from
	_release = target + Vector3.UP * RELEASE_HEIGHT
	_intercept = stage.aa_alive()
	model.get_parent().remove_child(model)
	_model = model
	_model.transform = Transform3D.IDENTITY
	add_child(_model)
	_pilot = _model.get_node("Pilot")
	global_position = _from
	add_to_group("missile")
	Sfx.play(_stage, "windup", _from, 2.0)


func target_pos() -> Vector3:
	return _target


func _pos(k: float) -> Vector3:
	return _from.lerp(_release, k) + Vector3.UP * ARC * sin(PI * k)


func _face(dir: Vector3, bank: float) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.z)
	rotation.z = bank


func _physics_process(_delta: float) -> void:
	if done and _phase != 2:
		return
	_tick += 1
	match _phase:
		0:
			_glide()
		1:
			_drop()
		2:
			_after()
		3:
			_crash()


func _glide() -> void:
	if _tick < DELAY_TICKS:
		# 바위 끝에서 엉덩이를 흔들며 도움닫기
		_model.position = Vector3(0, absf(sin(_tick * 0.5)) * 0.25, -_tick * 0.03)
		return
	if _tick == DELAY_TICKS:
		_model.position = Vector3.ZERO
		Sfx.play(_stage, "flight", _from, 4.0)
	var k := float(_tick - DELAY_TICKS) / FLIGHT_TICKS
	var p := _pos(k)
	var ahead := _pos(minf(k + 0.02, 1.0)) - p
	global_position = p
	_face(ahead, sin(_tick * 0.09) * 0.15)
	if _intercept and k >= 0.5:
		# 발리스타 화살에 맞았다: 빙글빙글 돌며 불시착 (폭탄은 불발)
		_phase = 3
		_phase_tick = 0
		_crash_from = p
		var flat := Vector3(ahead.x, 0, ahead.z).normalized()
		_crash_to = Vector3(p.x, 0.0, p.z) + flat * 10.0
		Sfx.play(_stage, "break", p, 2.0)
		Fx.smoke_puff(_stage, p, 1.5)
		_stage.toast.emit(Texts.t("rocket_shot_down"))
		_stage.shot_down += 1
		return
	if k >= 1.0:
		# 표적 위: 폭탄을 끌어안고 뛰어내린다. 글라이더는 그대로 앞으로 날아가 버린다
		_phase = 1
		_phase_tick = 0
		var pilot_pos := _pilot.global_position
		_model.remove_child(_pilot)
		_stage.add_child(_pilot)
		_pilot.global_position = pilot_pos
		_drop_from = pilot_pos
		for arm_name in ["ArmL", "ArmR"]:
			var arm: Node3D = _pilot.get_node(arm_name)
			arm.rotation = Vector3(-2.6, 0, 0.3 if arm_name == "ArmL" else -0.3)


func _drop() -> void:
	_phase_tick += 1
	var k := float(_phase_tick) / DROP_TICKS
	# 빈 글라이더는 앞으로 미끄러지며 사라진다
	global_position += -global_transform.basis.z * 0.25 + Vector3.UP * 0.03
	_pilot.global_position = _drop_from.lerp(_target, k * k)
	_pilot.rotation.x = -k * 0.8
	if k >= 1.0:
		done = true
		remove_from_group("missile")
		_stage.rocket_strike(_target, RADIUS, STRENGTH, KILL_RADIUS)
		exploded.emit(_target)
		# 폭탄을 안고 뛰어내린 고블린은 폭발에 휘말려 신나게 멀리 날아간다 (웃음소리는 나중에)
		var bomb: Node3D = _pilot.get_node_or_null("Bomb")
		if bomb:
			bomb.visible = false
		_fly_vel = Vector3(0.4, 0, 1.0).normalized() * 9.0 + Vector3.UP * 16.0
		for arm_name in ["ArmL", "ArmR"]:
			var arm: Node3D = _pilot.get_node(arm_name)
			arm.rotation = Vector3(0, 0, -2.7 if arm_name == "ArmL" else 2.7)
		_phase = 2
		_phase_tick = 0


func _after() -> void:
	_phase_tick += 1
	var dt := 1.0 / Engine.physics_ticks_per_second
	global_position += -global_transform.basis.z * 0.3
	if is_instance_valid(_pilot):
		_fly_vel.y -= 9.8 * dt
		_pilot.global_position += _fly_vel * dt
		_pilot.rotation += Vector3(6.0, 9.0, 3.0) * dt
		if _pilot.global_position.y <= 0.0 and _fly_vel.y < 0.0:
			_pilot.global_position.y = 0.0
			_fly_vel = Vector3.ZERO
			_pilot.rotation = Vector3(-PI * 0.5, _pilot.rotation.y, 0)
	if _phase_tick > 240:
		set_physics_process(false)
		_model.visible = false


func _crash() -> void:
	_phase_tick += 1
	var k := float(_phase_tick) / CRASH_TICKS
	var p := _crash_from.lerp(_crash_to, k)
	p.y = _crash_from.y * (1.0 - k * k)
	global_position = p
	rotation.y += 0.25
	rotation.z = 0.6
	if k >= 1.0:
		done = true
		remove_from_group("missile")
		global_position = _crash_to
		rotation = Vector3(0.3, rotation.y, 0.5)
		# 쾅 대신 피식: 불발탄을 안고 엎어진다
		Sfx.play(_stage, "fizzle", _crash_to, 2.0)
		Sfx.play(_stage, "collapse", _crash_to, -6.0)
		Fx.smoke_puff(_stage, _crash_to, 1.2)
		exploded.emit(_crash_to)
