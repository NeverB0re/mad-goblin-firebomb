class_name Messenger
extends Actor
## 지원을 부르러 목적지(나팔탑)까지 정해진 꺾은선 경로를 일정한 속도로 달리는 전령.
## 방향 전환이나 회피는 없어서 같은 판단에 같은 결과가 나온다. 밤에는 횃불을 들고 달린다.
## 건너야 할 다리가 끊기면 그 자리에서 멈춰 양팔을 휘저으며 허둥댄다.

signal arrived

var speed := 4.5
var follow: PathFollow3D
var running := false
var has_arrived := false
var stranded := false


func _init() -> void:
	super()
	uses_gravity = false
	set_visual(Models.human(Models.HUMAN_STEEL, Models.Hat.NONE, 0.95))


func carry_torch() -> void:
	var arm: Node3D = visual.get_node("ArmR")
	arm.rotation.z = 2.6
	var torch := Models.torch(0.6)
	torch.position = Vector3(0, -0.6, 0)
	arm.add_child(torch)


func start() -> void:
	if not dead and not has_arrived:
		running = true


## 광차를 탄 전령 (3월드): 몸 아래에 쇠테 두른 나무 광차.
func ride_cart() -> void:
	var cart := Node3D.new()
	cart.name = "Cart"
	add_child(cart)
	var wood := Models.mat(Color(0.4, 0.28, 0.17))
	var iron := Models.mat(Color(0.28, 0.28, 0.3), 0.5, 0.6)
	Models.box(cart, Vector3(1.1, 0.7, 1.5), Vector3(0, 0.55, 0), wood)
	Models.box(cart, Vector3(1.15, 0.08, 1.55), Vector3(0, 0.88, 0), iron)
	for sx in [-0.45, 0.45]:
		for sz in [-0.5, 0.5]:
			Models.cyl(cart, 0.2, 0.2, 0.1, Vector3(sx, 0.2, sz), iron, Vector3(0, 0, PI * 0.5))
	visual.position.y = 0.45


## 다리가 끊겨 오도 가도 못한다.
func strand() -> void:
	running = false
	stranded = true


## 쓰러진 모습(날아가기·불타기·깔리기)은 승리 연출이 원인에 맞게 정한다.
func _on_defeated(_cause: String) -> void:
	running = false


func _physics_process(delta: float) -> void:
	super(delta)
	if stranded and not dead:
		# 양팔을 번갈아 휘저으며 제자리에서 동동 구른다
		visual.position.y = absf(sin(_anim_t * 14.0)) * 0.08
		(visual.get_node("ArmL") as Node3D).rotation.z = -2.4 + sin(_anim_t * 16.0) * 0.5
		(visual.get_node("ArmR") as Node3D).rotation.z = 2.4 + sin(_anim_t * 16.0 + 1.5) * 0.5
		return
	if not running or dead or follow == null:
		return
	follow.progress += speed * delta
	# 달리는 몸짓 (광차는 덜컹거린다)
	var base := 0.45 if has_node("Cart") else 0.0
	visual.position.y = base + absf(sin(_anim_t * 10.0)) * (0.04 if base > 0.0 else 0.12)
	var arm_l: Node3D = visual.get_node("ArmL")
	arm_l.rotation.x = sin(_anim_t * 10.0) * 0.9
	if follow.progress_ratio >= 0.999:
		running = false
		has_arrived = true
		arrived.emit()
