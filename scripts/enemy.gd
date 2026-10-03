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

	_visual = Node3D.new()
	add_child(_visual)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.08)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.35
	cap.radial_segments = 8
	cap.rings = 2
	body.mesh = cap
	body.material_override = red
	body.position = Vector3(0, 0.68, 0)
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	sph.radial_segments = 8
	sph.rings = 4
	head.mesh = sph
	head.material_override = red
	head.position = Vector3(0, 1.58, 0)
	_visual.add_child(head)


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
	died.emit()


func _physics_process(delta: float) -> void:
	if not running or follow == null:
		return
	follow.progress += speed * delta
	if follow.progress_ratio >= 0.999:
		running = false
		has_escaped = true
		escaped.emit()
