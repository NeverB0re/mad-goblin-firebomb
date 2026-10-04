class_name FailurePictures
extends RefCounted
## 실패 그림. 상대의 해프닝으로 보이게 하고 플레이어를 놀리지 않는다.
## 월드마다 배경 색과 소품이 다르다 (목책 마을, 강철 관문, 광산 보일러, 밤의 발리스타, 성채).
##  0. 무너진 목책 앞에 주저앉은 고블린
##  1. 폭탄을 분해하다 부품을 늘어놓은 고블린
##  2. 서로 손가락질하며 탓하는 고블린 둘

const COUNT := 3


## 월드별 소품 (그림 뒤쪽).
static func _world_prop(r: Node3D, world: int) -> void:
	match world:
		1:
			var steel := Models.mat(Models.HUMAN_STEEL, 0.4, 0.6)
			Models.box(r, Vector3(5.0, 2.6, 0.3), Vector3(0, 1.3, -2.6), steel)
		2:
			var iron := Models.mat(Color(0.25, 0.24, 0.24), 0.5, 0.5)
			Models.cyl(r, 0.8, 0.8, 1.8, Vector3(2.2, 0.9, -2.2), iron, Vector3.ZERO, 10)
			Models.cyl(r, 0.15, 0.15, 2.5, Vector3(2.2, 2.6, -2.2), iron)
			var smoke := Fx.smoke_column(10)
			smoke.position = Vector3(2.2, 3.8, -2.2)
			r.add_child(smoke)
		3:
			var wood := Models.mat(Color(0.3, 0.2, 0.12))
			Models.box(r, Vector3(0.2, 3.0, 0.2), Vector3(-2.4, 1.5, -2.4), wood)
			Models.box(r, Vector3(1.6, 0.15, 0.15), Vector3(-2.4, 3.0, -2.4), wood, Vector3(0, 0, -0.4))
		4:
			r.add_child(Models.tower(4.0, Models.HUMAN_STEEL.lightened(0.2)))
			r.get_child(r.get_child_count() - 1).position = Vector3(2.6, 0, -3.0)


const SKY := [Color(0.62, 0.55, 0.5), Color(0.55, 0.6, 0.66), Color(0.45, 0.4, 0.38), Color(0.12, 0.13, 0.22), Color(0.5, 0.4, 0.5)]


static func build(vp: SubViewport, index: int, world := 0) -> void:
	_build(vp, index)
	var root: Node3D = vp.get_child(vp.get_child_count() - 1) if vp.get_child_count() > 0 else null
	if root:
		_world_prop(root, world)
		var env := root.find_children("*", "WorldEnvironment", true, false)
		if not env.is_empty():
			var e: Environment = env[0].environment
			e.background_color = SKY[world % SKY.size()]


static func _build(vp: SubViewport, index: int) -> void:
	var wood := Models.mat(Color(0.42, 0.27, 0.15))
	match index % COUNT:
		0:
			var r := Diorama.scene(vp, Color(0.62, 0.55, 0.5), Color(0.45, 0.4, 0.33), Vector3(1.0, 1.8, 4.2), Vector3(0, 0.8, 0))
			for i in 7:
				var x := -2.4 + i * 0.8
				var tilt: float = [0.0, 0.5, -0.9, 1.4, 0.2, -1.5, 0.3][i]
				Models.box(r, Vector3(0.22, 2.0, 0.22), Vector3(x, 1.0 - absf(tilt) * 0.35, -1.6), wood, Vector3(0, 0, tilt))
			var g := Diorama.place(Models.goblin(), r, Vector3(0, -0.45, 0), 0.0)
			g.rotation_degrees = Vector3(0, 0, 0)
			g.scale = Vector3(1.0, 0.8, 1.0)
			Diorama.arm(g, "ArmL", -0.4, 0.6)
			Diorama.arm(g, "ArmR", 0.4, 0.6)
			var head: Node3D = g.get_node("Head")
			head.rotation.x = 0.5
			var smoke := Fx.smoke_column(10)
			smoke.position = Vector3(-1.5, 0.5, -1.8)
			r.add_child(smoke)
		1:
			var r := Diorama.scene(vp, Color(0.55, 0.6, 0.66), Color(0.5, 0.44, 0.38), Vector3(0, 2.6, 3.2), Vector3(0, 0.3, 0))
			var g := Diorama.place(Models.goblin(), r, Vector3(0, -0.4, -0.5), 180.0)
			g.rotation.y = 0.0
			Diorama.arm(g, "ArmL", -0.3, -1.2)
			Diorama.arm(g, "ArmR", 0.3, -1.2)
			# 늘어놓은 폭탄 부품 (항아리 반쪽, 쇠테, 도화선, 톱니)
			var iron := Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.6)
			var band := Models.mat(Color(0.45, 0.42, 0.38), 0.5, 0.7)
			Models.ball(r, 0.25, Vector3(-0.8, 0.0, 0.4), iron)
			Models.cyl(r, 0.3, 0.3, 0.05, Vector3(0.7, 0.03, 0.5), band, Vector3(0.2, 0, 0))
			Models.cyl(r, 0.22, 0.22, 0.05, Vector3(0.3, 0.03, 0.9), band)
			Models.gear(r, 0.2, 0.05, Vector3(-0.3, 0.03, 0.9), band, iron)
			Models.box(r, Vector3(0.5, 0.02, 0.02), Vector3(0.9, 0.02, 0.1), Models.mat(Color(0.8, 0.75, 0.55)), Vector3(0, 0.6, 0))
			Diorama.place(Fx.ammo_model(AmmoType.Kind.HE, 2.0, false), r, Vector3(-0.2, 0.15, 0.2))
		_:
			var r := Diorama.scene(vp, Color(0.66, 0.58, 0.52), Color(0.48, 0.42, 0.35), Vector3(0, 1.8, 4.6), Vector3(0, 1.0, 0))
			var a := Diorama.place(Models.goblin(), r, Vector3(-0.9, 0, 0), 120.0)
			var b := Diorama.place(Models.goblin(), r, Vector3(0.9, 0, 0), -120.0)
			Diorama.arm(a, "ArmR", 0.0, -1.5)
			Diorama.arm(b, "ArmL", 0.0, -1.5)
			Diorama.arm(a, "ArmL", -0.6)
			Diorama.arm(b, "ArmR", 0.6)
			# 둘 다 그을린 얼굴 (검은 얼룩)
			var soot := Models.mat(Color(0.08, 0.07, 0.06))
			for g in [a, b]:
				var head: Node3D = g.get_node("Head")
				Models.box(head, Vector3(0.3, 0.12, 0.05), Vector3(0, -0.06, -0.24), soot)
			Models.box(r, Vector3(1.2, 0.6, 0.8), Vector3(0, 0.3, -1.5), wood, Vector3(0, 0, 0.3))
