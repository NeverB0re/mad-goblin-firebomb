class_name Guard
extends Actor
## 인간 병사 (방패병·감시병). 폭발이 가까우면 깜짝 놀라 펄쩍 뛰고 투구가 날아간다.
## 방패병은 동료 고블린의 길을 막는 장애물이다. 불, 폭발, 직격으로 쓰러진다.

var shield := false
var _helmet: Node3D
var _startle := 0.0


func _init() -> void:
	super()
	add_to_group("soldiers")


func setup(with_shield: bool) -> Guard:
	shield = with_shield
	set_visual(Models.human(Models.HUMAN_STEEL, Models.Hat.HELMET))
	_helmet = visual.get_node_or_null("Helmet")
	if shield:
		var plate := Models.mat(Models.HUMAN_STEEL.darkened(0.2), 0.4, 0.6)
		Models.box(visual, Vector3(0.9, 1.3, 0.1), Vector3(0, 0.85, -0.45), plate)
		Models.box(visual, Vector3(0.1, 0.1, 0.05), Vector3(0, 0.95, -0.52), Models.mat(Color(0.8, 0.75, 0.55), 0.4, 0.6))
	return self


## 근처 폭발에 놀란다 (연출).
func startle(strength: float) -> void:
	if dead:
		return
	_startle = clampf(strength, 0.3, 1.0)
	if _helmet and _helmet.get_parent() == visual and strength > 0.6:
		var pos := _helmet.global_position
		visual.remove_child(_helmet)
		get_parent().add_child(_helmet)
		_helmet.global_position = pos
		var tw := _helmet.create_tween().set_parallel(true)
		tw.tween_property(_helmet, "global_position", pos + Vector3(0.4, 2.2, 0.3), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_helmet, "rotation", Vector3(4.0, 2.0, 1.0), 0.7)
		tw.chain().tween_property(_helmet, "global_position:y", 0.1, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _on_defeated(_cause: String) -> void:
	var fire := Fx.fire(Vector3(0.3, 0.6, 0.3), 16, 0.4)
	fire.position = Vector3(0, 0.9, 0)
	add_child(fire)
	Fx.free_after(fire, 4.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	super(delta)
	if dead or visual == null:
		return
	if _startle > 0.0:
		_startle = maxf(0.0, _startle - delta * 2.0)
		visual.position.y = sin((1.0 - _startle) * PI) * 0.6 * _startle
		var arm_l: Node3D = visual.get_node("ArmL")
		var arm_r: Node3D = visual.get_node("ArmR")
		arm_l.rotation.z = -2.5 * _startle
		arm_r.rotation.z = 2.5 * _startle
