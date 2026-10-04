class_name Villager
extends Node3D
## 구경하는 마을 고블린 (1월드 장식). 평소엔 손뼉을 치고, 무언가 무너지면 펄쩍 뛰며 환호한다.

var _t := 0.0
var _cheer := 0.0
var _body: Node3D


func _ready() -> void:
	add_to_group("villagers")
	_body = Models.goblin()
	add_child(_body)
	_t = position.x * 0.7


func cheer() -> void:
	_cheer = 2.0


func _process(delta: float) -> void:
	_t += delta
	_cheer = maxf(0.0, _cheer - delta)
	var arm_l: Node3D = _body.get_node("ArmL")
	var arm_r: Node3D = _body.get_node("ArmR")
	if _cheer > 0.0:
		_body.position.y = absf(sin(_t * 9.0)) * 0.5
		arm_l.rotation.z = -2.7
		arm_r.rotation.z = 2.7
	else:
		_body.position.y = 0.0
		var clap := sin(_t * 10.0) * 0.35
		arm_l.rotation = Vector3(-1.3, 0, -0.4 - clap)
		arm_r.rotation = Vector3(-1.3, 0, 0.4 + clap)
