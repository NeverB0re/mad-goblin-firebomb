class_name OrbitCam
extends Camera3D
## 타이틀 뒤에서 멈춘 진지를 천천히 도는 카메라 (게임이 멈춰 있어도 돈다).

var center := Vector3.ZERO
var _t := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fov = 50.0
	far = 1500.0


func _process(delta: float) -> void:
	_t += delta
	var a := 0.6 + _t * 0.08
	global_position = center + Vector3(sin(a) * 36.0, 15.0, cos(a) * 36.0)
	look_at(center + Vector3.UP * 2.5, Vector3.UP)
