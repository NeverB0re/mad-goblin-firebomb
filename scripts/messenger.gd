class_name Messenger
extends Actor
## 지원을 부르러 목적지(봉화대·나팔탑)까지 정해진 직선 경로를 일정한 속도로 달리는 전령.
## 방향 전환이나 회피는 없어서 같은 판단에 같은 결과가 나온다. 밤에는 횃불을 들고 달린다.

signal arrived

var speed := 4.5
var follow: PathFollow3D
var running := false
var has_arrived := false


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


func _on_defeated(_cause: String) -> void:
	running = false
	var fire := Fx.fire(Vector3(0.3, 0.6, 0.3), 24, 0.4)
	fire.position = Vector3(0, 0.9, 0)
	add_child(fire)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", -PI * 0.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _physics_process(delta: float) -> void:
	super(delta)
	if not running or dead or follow == null:
		return
	follow.progress += speed * delta
	# 달리는 몸짓
	visual.position.y = absf(sin(_anim_t * 10.0)) * 0.12
	var arm_l: Node3D = visual.get_node("ArmL")
	arm_l.rotation.x = sin(_anim_t * 10.0) * 0.9
	if follow.progress_ratio >= 0.999:
		running = false
		has_arrived = true
		arrived.emit()
