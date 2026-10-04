class_name WindBanner
extends Node3D
## 바람 표시: 들판 한가운데 꽂힌 고블린 전투 깃발과 그 발치의 모닥불 (판정과 무관, 충돌 없음).
## 투척 구역에서 멀리, 진지 쪽으로 가는 길목 옆에 세워 조준할 때 늘 화면에 들어온다.
## - 깃발: 길게 늘어뜨린 천 다섯 폭. 펴진 폭 수가 바람 단계(0~5)다. 0단계면 깃대에 축 늘어진다.
##   펄럭이는 끝이 바람이 불어 가는 쪽을 가리킨다.
## - 모닥불 연기: 바람이 불어 가는 쪽으로 눕는다 (세기만큼 많이 눕는다). 밤에는 연기 대신 모닥불 불빛이 깃발을 비춘다.

const POLE := 10.0
const SEG := 1.5
const LEVELS := 5

var _segs: Array[Node3D] = []
var _level := 0
var _t := 0.0


func setup(wind: Vector3, level: int, night := false) -> WindBanner:
	_level = level
	var wood := Models.mat(Color(0.36, 0.24, 0.13))
	var bone := Models.mat(Color(0.92, 0.88, 0.76))
	# 삐뚤빼뚤 이어 붙인 나무 깃대와 버팀 밧줄 말뚝
	Models.cyl(self, 0.16, 0.22, POLE * 0.55, Vector3(0, POLE * 0.275, 0), wood, Vector3(0, 0, 0.02))
	Models.cyl(self, 0.12, 0.16, POLE * 0.5, Vector3(0.05, POLE * 0.75, 0), wood, Vector3(0, 0, -0.02))
	Models.box(self, Vector3(0.5, 0.2, 0.5), Vector3(0, POLE * 0.55, 0), Models.mat(Color(0.75, 0.62, 0.38)))
	# 꼭대기: 소뼈 해골과 뿔
	Models.ball(self, 0.32, Vector3(0, POLE + 0.25, 0), bone, 8)
	for sx in [-1, 1]:
		Models.cyl(self, 0.03, 0.09, 0.7, Vector3(sx * 0.4, POLE + 0.5, 0), bone, Vector3(0, 0, -sx * 0.9))
	# 천: 깃대 꼭대기에 매달고 바람이 불어 가는 쪽으로 뻗는다
	var arm := Node3D.new()
	arm.position = Vector3(0, POLE - 0.3, 0)
	add_child(arm)
	if level > 0:
		arm.rotation.y = atan2(-wind.x, -wind.z)
	var red := Models.mat(Color(0.82, 0.12, 0.08), 0.95)
	var cream := Models.mat(Color(0.95, 0.88, 0.7), 0.95)
	var parent: Node3D = arm
	for i in LEVELS:
		# 각 폭은 앞 폭 끝에 경첩처럼 붙는다 (펴진 폭은 수평, 나머지는 아래로 처진다)
		var hinge := Node3D.new()
		hinge.position = Vector3.ZERO if i == 0 else Vector3(0, 0, -SEG)
		parent.add_child(hinge)
		var w := 1.5 - i * 0.18
		Models.box(hinge, Vector3(0.06, w, SEG), Vector3(0, -w * 0.5, -SEG * 0.5), red if i % 2 == 0 else cream)
		if i == LEVELS - 1:
			# 꼬리는 두 갈래로 찢어져 있다
			for sz in [-1, 1]:
				Models.box(hinge, Vector3(0.05, w * 0.35, 0.7), Vector3(0, -w * (0.5 + sz * 0.3), -SEG - 0.3), red, Vector3(sz * 0.25, 0, 0))
		_segs.append(hinge)
		parent = hinge
	_pose(0.0)
	# 발치 모닥불과 바람 따라 눕는 연기
	var fire_pos := Vector3(1.6, 0, 1.2)
	for k in 6:
		var a := TAU * k / 6.0
		Models.box(self, Vector3(0.15, 0.15, 1.1), fire_pos + Vector3(cos(a) * 0.25, 0.12, sin(a) * 0.25), wood, Vector3(0.3, -a, 0))
	var flame := Fx.fire(Vector3(0.35, 0.2, 0.35), 24, 0.45)
	flame.position = fire_pos + Vector3(0, 0.3, 0)
	add_child(flame)
	if night:
		# 밤: 모닥불이 깃발을 아래에서 비춘다 (어둠 속에서도 바람을 읽게)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.6, 0.25)
		glow.light_energy = 3.0
		glow.omni_range = POLE + 3.0
		glow.omni_attenuation = 0.6
		glow.shadow_enabled = false
		glow.position = fire_pos + Vector3(0, 1.0, 0)
		add_child(glow)
		return self
	var smoke := Fx.smoke_column(20)
	smoke.position = fire_pos + Vector3(0, 0.8, 0)
	var pm: ParticleProcessMaterial = (smoke.process_material as ParticleProcessMaterial).duplicate()
	pm.gravity = Vector3(wind.x, 0.0, wind.z).normalized() * 0.35 * level + Vector3(0, 0.2, 0) if level > 0 else Vector3(0, 0.3, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	smoke.process_material = pm
	smoke.lifetime = 5.0
	add_child(smoke)
	return self


## 폭마다 처짐 각을 정한다. 펴진 폭도 살짝 물결친다.
func _pose(t: float) -> void:
	for i in _segs.size():
		var up := i < _level
		var droop := 0.05 if up else (1.45 if i == _level or (i == 0 and _level == 0) else 0.08)
		_segs[i].rotation = Vector3(-droop + (sin(t * 6.0 - i * 1.3) * 0.08 if up else 0.0), sin(t * 4.0 - i) * (0.12 if up else 0.03), 0)


func _process(delta: float) -> void:
	_t += delta
	_pose(_t)
