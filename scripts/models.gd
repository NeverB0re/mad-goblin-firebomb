class_name Models
extends RefCounted
## 단색 로우폴리 모델 모음: 고블린(부족장 포함), 인간(병사·지휘관), 깃발, 횃불, 요새 탑.
## 게임과 오프닝 컷만화가 같은 모델을 쓴다.

const GOLD := Color(0.97, 0.74, 0.16)
const GOBLIN_SKIN := Color(0.36, 0.56, 0.22)
## 인간 진영: 깨끗한 청회색 강철 (빨강은 깃발에만 쓴다)
const HUMAN_STEEL := Color(0.46, 0.55, 0.66)
const FLAG_RED := Color(0.9, 0.08, 0.06)

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
			var steel := mat(Color(0.62, 0.66, 0.72), 0.35, 0.7)
			var helmet := Node3D.new()
			helmet.name = "Helmet"
			helmet.position = Vector3(0, 1.72, 0)
			root.add_child(helmet)
			cyl(helmet, 0.17, 0.23, 0.22, Vector3.ZERO, steel)
			box(helmet, Vector3(0.05, 0.12, 0.05), Vector3(0, 0.18, 0), steel)
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
	var flag := mat(FLAG_RED, 0.8)
	cyl(root, 0.025, 0.025, 1.0, Vector3(0, height + 0.5, 0), mat(Color(0.2, 0.2, 0.2)))
	box(root, Vector3(0.5, 0.3, 0.02), Vector3(0.25, height + 0.85, 0), flag)
	return root


## 인간 지휘관: 반듯한 강철 갑옷, 깃털 장식 투구, 짙은 남색 망토. 조금 더 크다.
static func commander() -> Node3D:
	var root := human(HUMAN_STEEL.lightened(0.1), Hat.HELMET, 1.15, Color(0.12, 0.16, 0.3))
	var helmet: Node3D = root.get_node("Helmet")
	var plume := mat(Color(0.95, 0.85, 0.3), 0.8)
	for i in 3:
		box(helmet, Vector3(0.06, 0.28, 0.06), Vector3(0, 0.3, 0.05 + i * 0.07), plume, Vector3(-0.3 - i * 0.25, 0, 0))
	# 가슴의 금색 훈장 (규격품 느낌의 반듯한 장식)
	box(root, Vector3(0.18, 0.18, 0.04), Vector3(0, 1.15, -0.32), gold_material())
	return root


## 지휘관 곁의 빨간 깃발. "Cloth" 노드를 흔들어 펄럭이게 한다 (천 시뮬레이션 없음).
static func flag(height := 4.0) -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.05, 0.06, height, Vector3(0, height * 0.5, 0), mat(Color(0.3, 0.3, 0.32), 0.5, 0.5))
	ball(root, 0.09, Vector3(0, height + 0.05, 0), gold_material())
	var cloth := Node3D.new()
	cloth.name = "Cloth"
	cloth.position = Vector3(0.05, height - 0.55, 0)
	root.add_child(cloth)
	var red := mat(FLAG_RED, 0.8, 0.0, 0.25)
	box(cloth, Vector3(1.3, 0.85, 0.03), Vector3(0.65, 0, 0), red)
	return root


## 횃불 (밤 스테이지). 둘레 몇 m만 밝히는 작은 불빛 (그림자 없음) + 발광 재질과 빛 웅덩이.
## 대략의 위치만 알려 주고, 건물 재질까지 알아보려면 조명탄이 필요하다.
static func torch(height := 1.8) -> Node3D:
	var root := Node3D.new()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position = Vector3(0, height + 0.3, 0)
	root.add_child(light)
	cyl(root, 0.04, 0.05, height, Vector3(0, height * 0.5, 0), mat(Color(0.3, 0.2, 0.1)))
	var flame := mat(Color(1.0, 0.6, 0.15), 0.5, 0.0, 4.0)
	cyl(root, 0.0, 0.12, 0.3, Vector3(0, height + 0.15, 0), flame, Vector3.ZERO, 6)
	# 바닥에 퍼지는 빛 웅덩이 (발광 원판, 가산 혼합)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.55, 0.2, 0.35)
	cyl(root, 3.5, 3.5, 0.02, Vector3(0, 0.03, 0), glow, Vector3.ZERO, 16)
	var cone := StandardMaterial3D.new()
	cone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone.albedo_color = Color(1.0, 0.6, 0.25, 0.12)
	cyl(root, 0.15, 2.0, height + 0.3, Vector3(0, (height + 0.3) * 0.5, 0), cone, Vector3.ZERO, 12)
	var fire := Fx.fire(Vector3(0.05, 0.05, 0.05), 10, 0.25)
	fire.position = Vector3(0, height + 0.2, 0)
	root.add_child(fire)
	return root


## 고블린 부족장: 깃털 머리장식과 뼈 목걸이.
static func chief() -> Node3D:
	var root := goblin()
	var head: Node3D = root.get_node("Head")
	var colors := [Color(0.95, 0.75, 0.2), Color(0.3, 0.6, 0.85), Color(0.95, 0.95, 0.9)]
	for i in 5:
		var a := -0.8 + i * 0.4
		box(head, Vector3(0.07, 0.45, 0.03), Vector3(sin(a) * 0.2, 0.42, 0.08), mat(colors[i % 3], 0.8), Vector3(0, 0, -a * 0.6))
	for i in 5:
		var a := -1.0 + i * 0.5
		box(root, Vector3(0.06, 0.12, 0.06), Vector3(sin(a) * 0.3, 1.15, -0.3 + absf(a) * 0.08), mat(Color(0.95, 0.93, 0.85)))
	return root