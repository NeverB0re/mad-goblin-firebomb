class_name Enemy
extends CharacterBody3D
## 정해진 직선 경로를 일정한 속도로 달아나는 적. 방향 전환이나 회피는 없다.
## 화염병 직격이나 불웅덩이를 지나가면 불이 붙어 쓰러진다.

signal died
signal escaped

var speed := 5.0
var follow: PathFollow3D
var running := false
var dead := false
var has_escaped := false
var _visual: Node3D
var _part: Node3D
var _t := 0.0


func _init() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	# 남작의 징세관: 빨간 단색 인형에 실크해트
	_visual = Models.human(Models.ENEMY_RED, Models.Hat.TOP_HAT)
	add_child(_visual)


## 훔친 신상 부품을 머리 위로 들고 달린다. 쓰러지면 떨어뜨린다.
func carry_part(kind: int) -> Enemy:
	_part = Models.idol_part(kind, Models.gold_material(), Models.mat(Color(0.2, 0.17, 0.12), 0.5, 0.4))
	_part.position = Vector3(0, 2.25, 0)
	_part.scale = Vector3.ONE * 0.8
	_visual.add_child(_part)
	for arm_name in ["ArmL", "ArmR"]:
		var arm: Node3D = _visual.get_node(arm_name)
		arm.rotation.z = (PI * 0.85) * (-1.0 if arm_name == "ArmL" else 1.0)
	return self


func start() -> void:
	if not dead and not has_escaped:
		running = true


func ignite() -> void:
	if dead or has_escaped:
		return
	dead = true
	running = false
	var fire := Fx.fire(Vector3(0.3, 0.6, 0.3), 24, 0.4)
	fire.position = Vector3(0, 0.9, 0)
	add_child(fire)
	# 쓰러진다
	var tw := create_tween()
	tw.tween_property(_visual, "rotation:x", -PI * 0.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _part:
		# 들고 있던 부품이 앞으로 굴러 떨어진다
		var held := _part
		var world_pos := held.global_position
		_visual.remove_child(held)
		add_child(held)
		held.global_position = world_pos
		var pt := create_tween().set_parallel(true)
		pt.tween_property(held, "position", Vector3(0, 0.35, -1.6), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pt.tween_property(held, "rotation", Vector3(-PI, 0.4, 0.3), 0.6)
	died.emit()


func _physics_process(delta: float) -> void:
	if not running or follow == null:
		return
	follow.progress += speed * delta
	# 달리는 몸짓
	_t += delta
	_visual.position.y = absf(sin(_t * 10.0)) * 0.12
	if follow.progress_ratio >= 0.999:
		running = false
		has_escaped = true
		escaped.emit()
