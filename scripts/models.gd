class_name Models
extends RefCounted
## 단색 로우폴리 모델 모음: 고블린, 인간(징세관·병사·남작), 기계장치의 신 부품과 조립 신상, 요새 탑.
## 게임과 오프닝 컷만화가 같은 모델을 쓴다.

enum Part { HEART, ARM_L, HEAD, ARM_R, LEGS, TORSO }
const PART_NAMES := ["톱니 심장", "왼쪽 태엽 팔", "증기 머리", "오른쪽 태엽 팔", "황동 다리", "보일러 몸통"]
const PART_COUNT := 6

const GOLD := Color(0.97, 0.74, 0.16)
const GOBLIN_SKIN := Color(0.36, 0.56, 0.22)
const ENEMY_RED := Color(0.85, 0.12, 0.08)

enum Hat { NONE, HELMET, CROWN, TOP_HAT }


# ---------- 기본 도형 ----------

static func mat(color: Color, roughness := 0.85, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


static func gold_material() -> StandardMaterial3D:
	return mat(GOLD, 0.35, 0.5, 0.25)


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, segments := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, segments := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 3)
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 2
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## 톱니바퀴 (로컬 Y축이 회전축). 돌리려면 반환된 노드를 rotate_y 한다.
static func gear(parent: Node3D, radius: float, thick: float, pos: Vector3, m: Material, hub: Material, rot := Vector3.ZERO, teeth := 8) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation = rot
	parent.add_child(g)
	cyl(g, radius * 0.8, radius * 0.8, thick, Vector3.ZERO, m, Vector3.ZERO, 12)
	for i in teeth:
		var a := TAU * i / teeth
		box(g, Vector3(radius * 0.35, thick, radius * 0.3), Vector3(cos(a), 0, sin(a)) * radius * 0.88, m, Vector3(0, -a, 0))
	cyl(g, radius * 0.3, radius * 0.3, thick * 1.3, Vector3.ZERO, hub, Vector3.ZERO, 8)
	return g


# ---------- 기계장치의 신 ----------

## 신상 부품 하나. 약 0.8m 상자 안에 들어가고 원점이 중심이다.
static func idol_part(kind: int, gold: Material, dark: Material) -> Node3D:
	var root := Node3D.new()
	match kind:
		Part.HEART:
			gear(root, 0.38, 0.2, Vector3.ZERO, gold, dark, Vector3(PI * 0.5, 0, 0), 9).name = "Spin"
			ball(root, 0.1, Vector3(0, 0, 0.14), mat(Color(1.0, 0.3, 0.1), 0.4, 0.0, 1.5))
		Part.ARM_L, Part.ARM_R:
			var sx := -1.0 if kind == Part.ARM_L else 1.0
			ball(root, 0.16, Vector3(-sx * 0.1, 0.27, 0), gold)
			cyl(root, 0.09, 0.09, 0.32, Vector3(0, 0.1, 0), gold, Vector3(0, 0, sx * 0.4))
			gear(root, 0.1, 0.12, Vector3(sx * 0.07, -0.05, 0), dark, gold, Vector3(PI * 0.5, 0, 0), 6)
			cyl(root, 0.08, 0.07, 0.28, Vector3(sx * 0.1, -0.2, 0), gold)
			for cz in [-0.07, 0.07]:
				box(root, Vector3(0.05, 0.14, 0.05), Vector3(sx * 0.1, -0.38, cz), gold, Vector3(cz * 3.0, 0, 0))
		Part.HEAD:
			box(root, Vector3(0.6, 0.46, 0.5), Vector3(0, -0.08, 0), gold)
			for ex in [-0.14, 0.14]:
				cyl(root, 0.08, 0.08, 0.06, Vector3(ex, -0.04, 0.26), mat(Color(1.0, 0.45, 0.1), 0.4, 0.0, 2.0), Vector3(PI * 0.5, 0, 0))
			box(root, Vector3(0.36, 0.05, 0.04), Vector3(0, -0.22, 0.26), dark)
			cyl(root, 0.06, 0.08, 0.22, Vector3(0.17, 0.26, -0.05), dark)
			cyl(root, 0.012, 0.012, 0.18, Vector3(-0.15, 0.24, 0), dark)
			ball(root, 0.04, Vector3(-0.15, 0.34, 0), mat(Color(1.0, 0.3, 0.1), 0.4, 0.0, 1.5))
		Part.LEGS:
			box(root, Vector3(0.62, 0.14, 0.32), Vector3(0, 0.3, 0), gold)
			for lx in [-0.18, 0.18]:
				cyl(root, 0.1, 0.09, 0.5, Vector3(lx, 0.0, 0), gold)
				ball(root, 0.09, Vector3(lx, 0.02, 0.0), dark)
				box(root, Vector3(0.2, 0.1, 0.32), Vector3(lx, -0.3, 0.05), gold)
		Part.TORSO:
			cyl(root, 0.3, 0.34, 0.62, Vector3.ZERO, gold, Vector3.ZERO, 10)
			for by in [-0.2, 0.2]:
				cyl(root, 0.355, 0.355, 0.05, Vector3(0, by, 0), dark, Vector3.ZERO, 10)
			gear(root, 0.13, 0.08, Vector3(0, 0.0, 0.33), dark, gold, Vector3(PI * 0.5, 0, 0), 7)
			cyl(root, 0.05, 0.06, 0.2, Vector3(0.18, 0.4, 0), dark)
	return root


## 조립된 기계장치의 신 (높이 약 2.2m, 원점은 발바닥). missing에 든 부품은 빼고 만든다.
static func statue(gold: Material, dark: Material, missing: Array = []) -> Node3D:
	var root := Node3D.new()
	var layout := {
		Part.LEGS: [Vector3(0, 0.4, 0), 1.0],
		Part.TORSO: [Vector3(0, 1.05, 0), 1.0],
		Part.HEART: [Vector3(0, 1.1, 0.36), 0.55],
		Part.ARM_L: [Vector3(-0.55, 1.15, 0), 1.0],
		Part.ARM_R: [Vector3(0.55, 1.15, 0), 1.0],
		Part.HEAD: [Vector3(0, 1.62, 0), 0.9],
	}
	for kind in layout:
		if kind in missing:
			continue
		var p := idol_part(kind, gold, dark)
		p.position = layout[kind][0]
		p.scale = Vector3.ONE * layout[kind][1]
		p.name = "Part%d" % kind
		root.add_child(p)
	return root


# ---------- 인물 ----------

## 미친 발명가 고블린 (원점은 발바닥, -Z가 앞).
static func goblin(with_arms := true) -> Node3D:
	var root := Node3D.new()
	var skin := mat(GOBLIN_SKIN, 0.8)
	var cloth := mat(Color(0.36, 0.24, 0.14), 1.0)
	var eye := mat(Color(1.0, 0.85, 0.1), 0.5, 0.0, 1.0)
	capsule(root, 0.32, 1.1, Vector3(0, 0.75, 0.05), skin, Vector3(-0.3, 0, 0))
	box(root, Vector3(0.62, 0.5, 0.5), Vector3(0, 0.82, 0.02), cloth, Vector3(-0.3, 0, 0))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.5, -0.12)
	root.add_child(head)
	ball(head, 0.27, Vector3.ZERO, skin)
	for sx in [-1.0, 1.0]:
		cyl(head, 0.0, 0.09, 0.45, Vector3(sx * 0.33, 0.08, 0.02), skin, Vector3(0, 0, -sx * 1.25), 4)
		box(head, Vector3(0.08, 0.05, 0.03), Vector3(sx * 0.1, 0.05, -0.26), eye)
	# 발명가 고글
	box(head, Vector3(0.5, 0.06, 0.06), Vector3(0, 0.16, -0.2), cloth)
	if with_arms:
		for sx in [-1.0, 1.0]:
			var arm := Node3D.new()
			arm.name = "ArmL" if sx < 0 else "ArmR"
			arm.position = Vector3(sx * 0.36, 1.05, -0.05)
			root.add_child(arm)
			capsule(arm, 0.08, 0.6, Vector3(0, -0.25, 0), skin)
	return root


## 인간 (징세관, 병사, 남작). 원점은 발바닥, -Z가 앞.
static func human(body: Color, hat: int = Hat.NONE, size := 1.0, cape := Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	var m := mat(body, 0.7)
	capsule(root, 0.32, 1.35, Vector3(0, 0.68, 0), m)
	var head := ball(root, 0.2, Vector3(0, 1.58, 0), m)
	head.name = "HeadMesh"
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if sx < 0 else "ArmR"
		arm.position = Vector3(sx * 0.4, 1.25, 0)
		root.add_child(arm)
		capsule(arm, 0.08, 0.7, Vector3(0, -0.3, 0), m)
	if cape.a > 0.0:
		box(root, Vector3(0.75, 1.2, 0.06), Vector3(0, 0.75, 0.3), mat(cape, 0.9), Vector3(0.12, 0, 0))
	match hat:
		Hat.HELMET:
			var steel := mat(Color(0.55, 0.57, 0.6), 0.4, 0.6)
			cyl(root, 0.17, 0.23, 0.22, Vector3(0, 1.72, 0), steel)
			box(root, Vector3(0.05, 0.12, 0.05), Vector3(0, 1.9, 0), steel)
		Hat.CROWN:
			var g := gold_material()
			cyl(root, 0.2, 0.2, 0.12, Vector3(0, 1.8, 0), g)
			for i in 5:
				var a := TAU * i / 5.0
				box(root, Vector3(0.06, 0.12, 0.06), Vector3(cos(a) * 0.18, 1.9, sin(a) * 0.18), g)
		Hat.TOP_HAT:
			var black := mat(Color(0.08, 0.08, 0.1), 0.6)
			cyl(root, 0.26, 0.26, 0.03, Vector3(0, 1.74, 0), black)
			cyl(root, 0.16, 0.16, 0.32, Vector3(0, 1.9, 0), black)
	root.scale = Vector3.ONE * size
	return root


## 창 (병사용).
static func spear(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	s.rotation = rot
	parent.add_child(s)
	cyl(s, 0.03, 0.03, 2.2, Vector3(0, 1.1, 0), mat(Color(0.35, 0.24, 0.12)))
	cyl(s, 0.0, 0.07, 0.25, Vector3(0, 2.3, 0), mat(Color(0.7, 0.72, 0.75), 0.3, 0.7), Vector3.ZERO, 4)
	return s


## 남작의 요새 탑 (원점은 바닥).
static func tower(height := 3.0, color := Color(0.62, 0.62, 0.66)) -> Node3D:
	var root := Node3D.new()
	var stone := mat(color)
	box(root, Vector3(1.4, height, 1.4), Vector3(0, height * 0.5, 0), stone)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		box(root, Vector3(0.35, 0.4, 0.35), Vector3(cos(a) * 0.55, height + 0.2, sin(a) * 0.55), stone)
	var flag := mat(ENEMY_RED, 0.8)
	cyl(root, 0.025, 0.025, 1.0, Vector3(0, height + 0.5, 0), mat(Color(0.2, 0.2, 0.2)))
	box(root, Vector3(0.5, 0.3, 0.02), Vector3(0.25, height + 0.85, 0), flag)
	return root
