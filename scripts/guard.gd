class_name Guard
extends Actor
## 인간 병사 (방패병·감시병). 폭발이 가까우면 깜짝 놀라 펄쩍 뛰고 투구가 날아간다.
## 방패병은 동료 고블린의 길을 막는 장애물이다. 불, 폭발, 직격으로 쓰러진다.

var shield := false
var _helmet: Node3D
var _startle := 0.0
## 지켜보는 상대 (다가오는 동료 고블린). 가까워지면 그쪽을 보고 경계하다가, 더 가까우면 창을 찌르며 싸우려 든다
var watch: Node3D
const ALERT_RANGE := 12.0
const FIGHT_RANGE := 5.0
var _home_yaw := 0.0


func _init() -> void:
	super()
	add_to_group("soldiers")


## archer: 발리스타를 조종하는 궁병 (초록 두건과 망토, 등에 화살통).
func setup(with_shield: bool, archer := false) -> Guard:
	shield = with_shield
	_home_yaw = rotation.y
	if archer:
		set_visual(Models.human(Color(0.3, 0.42, 0.22), Models.Hat.NONE, 1.0, Color(0.22, 0.36, 0.18)))
		var green := Models.mat(Color(0.26, 0.4, 0.2), 0.95)
		var hood := Models.cyl(visual, 0.05, 0.27, 0.45, Vector3(0, 1.78, 0.03), green, Vector3.ZERO, 8)
		hood.name = "Hood"
		var leather := Models.mat(Color(0.42, 0.27, 0.15), 0.9)
		Models.cyl(visual, 0.1, 0.1, 0.6, Vector3(0.12, 1.25, 0.22), leather, Vector3(0, 0, 0.3), 8)
		for k in 3:
			Models.box(visual, Vector3(0.02, 0.25, 0.02), Vector3(0.18 + k * 0.04, 1.62, 0.22), Models.mat(Color(0.85, 0.8, 0.7)), Vector3(0, 0, 0.3))
		_helmet = null
		return self
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
	var arm_l: Node3D = visual.get_node("ArmL")
	var arm_r: Node3D = visual.get_node("ArmR")
	if is_instance_valid(watch) and _startle <= 0.0:
		var to := watch.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < ALERT_RANGE and d > 0.1:
			# 다가오는 고블린 쪽으로 몸을 돌린다
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 4.0, 0.0, 1.0))
			if d < FIGHT_RANGE:
				# 싸우려 든다: 오른팔로 창을 찌르고, 방패를 앞세워 들썩
				var t := _anim_t * 7.0
				arm_r.rotation = Vector3(-1.2 - maxf(sin(t), 0.0) * 0.9, 0, 0.2)
				arm_l.rotation = Vector3(-0.9, 0, -0.3)
				visual.position = Vector3(0, absf(sin(t)) * 0.08, -maxf(sin(t), 0.0) * 0.2)
			else:
				# 경계: 창을 겨누고 몸을 낮춘다
				arm_r.rotation = Vector3(-1.1, 0, 0.25)
				arm_l.rotation = Vector3(-0.6, 0, -0.3)
				visual.position = Vector3(0, -0.08, 0)
				visual.rotation.x = 0.12
			return
	if _startle > 0.0:
		_startle = maxf(0.0, _startle - delta * 2.0)
		visual.position.y = sin((1.0 - _startle) * PI) * 0.6 * _startle
		arm_l.rotation.z = -2.5 * _startle
		arm_r.rotation.z = 2.5 * _startle
