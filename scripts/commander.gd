class_name Commander
extends Actor
## 인간 지휘관. 빨간 깃발 곁에서 으스대다가 위험이 닥치면 허둥대고 고함을 지른다 (대사 없음).
## 반응: 불이 가까우면 팔을 휘저으며 제자리 종종걸음, 근처 구조가 무너지면 두 팔을 들고 떤다.

enum Mood { SWAGGER, PANIC, SHOUT }

const PANIC_RANGE := 7.0
const SHOUT_RANGE := 9.0

var mood: int = Mood.SWAGGER
var _check := 0


func _init() -> void:
	super()
	set_visual(Models.commander())


func _physics_process(delta: float) -> void:
	super(delta)
	if dead:
		return
	_check += 1
	if _check % 6 == 0:
		mood = _sense()


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
		Mood.SHOUT:
			# 두 팔을 번쩍 들고 부들부들
			visual.rotation = Vector3(-0.2, 0, sin(t * 30.0) * 0.04)
			visual.position = Vector3(0, 0, 0)
			arm_l.rotation = Vector3(0, 0, -2.7)
			arm_r.rotation = Vector3(0, 0, 2.7)
