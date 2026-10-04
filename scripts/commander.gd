class_name Commander
extends Actor
## 인간 지휘관. 빨간 깃발 곁에서 으스대다가 위험이 닥치면 허둥대고 고함을 지른다 (대사 없음).
## 반응: 불이 가까우면 팔을 휘저으며 제자리 종종걸음, 근처 구조가 무너지면 두 팔을 들고 떤다.
## 구경꾼(lure_path가 있는 지휘관, 밤): 조명탄 불빛이 구경 자리(lure_path 끝) 근처에 켜지면 숨어 있던 곳에서 걸어 나와
## 손차양을 하고 불빛을 구경한다. 불빛이 꺼지고 조금 뒤에 다시 걸어 들어간다.

enum Mood { SWAGGER, PANIC, SHOUT, WALK, WATCH }

const PANIC_RANGE := 7.0
const SHOUT_RANGE := 9.0
## 구경 자리에서 이 거리 안에 켜진 조명탄을 보러 나온다
const LURE_RADIUS := 13.0
const WALK_SPEED := 2.4
## 불빛이 꺼진 뒤 들어가기 전까지 머뭇거리는 시간 (초)
const LINGER := 1.5

var mood: int = Mood.SWAGGER
## 성문 빗장을 두 손으로 붙들고 버틴다 (지원 진지)
var hold_bar := false
var _check := 0
## 구경 길: [숨은 자리, ..., 구경 자리] (월드 좌표). 비어 있으면 구경하지 않는다
var lure_path: Array = []
## 지금 향하는 길 위 점 번호와 방향 (+1 나감, -1 들어감, 0 멈춤)
var _lure_i := 0
var _lure_dir := 0
var _linger := 0.0
var _flare_at := Vector3.INF


func _init() -> void:
	super()
	set_visual(Models.commander())


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		return
	_check += 1
	if not lure_path.is_empty():
		_lure_step(delta)
		if _lure_dir != 0 or _lure_i > 0:
			return
	if _check % 6 == 0:
		mood = _sense()


## 켜진 조명탄 중 구경 자리 근처의 것 (없으면 INF).
func _lit_flare() -> Vector3:
	var spot: Vector3 = lure_path[lure_path.size() - 1]
	for f in get_tree().get_nodes_in_group("flare"):
		if f.is_lit() and Vector2(f.base().x - spot.x, f.base().z - spot.z).length() < LURE_RADIUS:
			return f.global_position
	return Vector3.INF


func _lure_step(delta: float) -> void:
	if _check % 6 == 0:
		_flare_at = _lit_flare()
	var last := lure_path.size() - 1
	if _flare_at != Vector3.INF:
		_linger = LINGER
		if _lure_i < last or _lure_dir < 0:
			_lure_dir = 1
	elif _lure_i > 0 or _lure_dir != 0:
		_linger -= delta
		if _linger <= 0.0:
			_lure_dir = -1
	if _lure_dir == 0:
		velocity.x = 0.0
		velocity.z = 0.0
		if _lure_i == last and _flare_at != Vector3.INF:
			mood = Mood.WATCH
			var to := _flare_at - global_position
			rotation.y = atan2(-to.x, -to.z)
		return
	var goal_i := _lure_i + _lure_dir
	var goal: Vector3 = lure_path[goal_i]
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	if to.length() < 0.12:
		_lure_i = goal_i
		if _lure_i == last or _lure_i == 0:
			_lure_dir = 0
			velocity.x = 0.0
			velocity.z = 0.0
			if _lure_i == 0:
				mood = Mood.SWAGGER
				rotation.y = _home_yaw
		return
	var step := to.normalized() * WALK_SPEED
	velocity.x = step.x
	velocity.z = step.z
	rotation.y = atan2(-step.x, -step.z)
	mood = Mood.WALK


var _home_yaw := 0.0


## 구경 길을 정한다 (points[0]은 지금 자리).
func set_lure(points: Array) -> void:
	lure_path = points
	_home_yaw = rotation.y


func _sense() -> int:
	var p := global_position
	for f in get_tree().get_nodes_in_group("fire_pool"):
		if f.global_position.distance_to(p) < PANIC_RANGE + f.radius:
			return Mood.PANIC
	for b in get_tree().get_nodes_in_group("blocks"):
		var block := b as Block
		if block.burning and block.global_position.distance_to(p) < PANIC_RANGE:
			return Mood.PANIC
		if block.fallen and block.linear_velocity.length() > 1.0 and block.global_position.distance_to(p) < SHOUT_RANGE:
			return Mood.SHOUT
	return Mood.SWAGGER


func _process(delta: float) -> void:
	super(delta)
	if dead or visual == null:
		return
	var t := _anim_t
	var arm_l: Node3D = visual.get_node("ArmL")
	var arm_r: Node3D = visual.get_node("ArmR")
	if hold_bar and mood == Mood.SWAGGER:
		# 두 팔을 앞으로 뻗어 빗장을 붙들고 등을 기댄 채 들썩
		visual.rotation = Vector3(-0.15, 0, sin(t * 3.0) * 0.04)
		visual.position = Vector3(0, absf(sin(t * 3.0)) * 0.03, 0)
		arm_l.rotation = Vector3(-1.45, 0, -0.15)
		arm_r.rotation = Vector3(-1.45, 0, 0.15)
		return
	match mood:
		Mood.SWAGGER:
			# 가슴을 내밀고 허리에 손, 거들먹거리며 들썩
			visual.rotation = Vector3(0.12, sin(t * 1.3) * 0.25, 0)
			visual.position = Vector3(0, absf(sin(t * 2.6)) * 0.05, 0)
			arm_l.rotation = Vector3(0, 0, -0.7)
			arm_r.rotation = Vector3(0, 0, 0.7)
		Mood.PANIC:
			# 팔을 휘저으며 제자리에서 종종걸음
			visual.rotation = Vector3(-0.1, sin(t * 9.0) * 0.5, 0)
			visual.position = Vector3(sin(t * 13.0) * 0.08, absf(sin(t * 16.0)) * 0.15, 0)
			arm_l.rotation = Vector3(0, 0, -1.8 - sin(t * 20.0) * 1.0)
			arm_r.rotation = Vector3(0, 0, 1.8 + sin(t * 20.0 + 1.0) * 1.0)
		Mood.WALK:
			# 종종걸음 (팔 흔들기)
			visual.rotation = Vector3(0.05, 0, sin(t * 10.0) * 0.06)
			visual.position = Vector3(0, absf(sin(t * 10.0)) * 0.08, 0)
			arm_l.rotation = Vector3(sin(t * 10.0) * 0.6, 0, -0.2)
			arm_r.rotation = Vector3(-sin(t * 10.0) * 0.6, 0, 0.2)
		Mood.WATCH:
			# 손차양을 하고 불빛을 올려다보며 고개를 갸웃
			visual.rotation = Vector3(-0.15, 0, sin(t * 1.5) * 0.08)
			visual.position = Vector3.ZERO
			arm_l.rotation = Vector3(0, 0, -0.3)
			arm_r.rotation = Vector3(-2.4, 0, 0.6)
		Mood.SHOUT:
			# 두 팔을 번쩍 들고 부들부들
			visual.rotation = Vector3(-0.2, 0, sin(t * 30.0) * 0.04)
			visual.position = Vector3(0, 0, 0)
			arm_l.rotation = Vector3(0, 0, -2.7)
			arm_r.rotation = Vector3(0, 0, 2.7)
