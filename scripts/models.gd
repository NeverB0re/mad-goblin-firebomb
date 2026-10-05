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
	# 로우폴리 메시의 면마다 다른 밝기(정점 색)를 곱한다
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


static func gold_material() -> StandardMaterial3D:
	return mat(GOLD, 0.35, 0.5, 0.25)


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.cached("box:%s" % str(size.snapped(Vector3.ONE * 0.001)), func():
		var b := LowPoly.Builder.new()
		b.chamfer_box(Transform3D.IDENTITY, size, minf(0.05, minf(size.x, minf(size.y, size.z)) * 0.15))
		return b.commit())
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, segments := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.cached("cyl:%.3f:%.3f:%.3f:%d" % [r_top, r_bottom, h, segments], func():
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bottom
		cm.height = h
		cm.radial_segments = segments
		cm.rings = 0
		return LowPoly.flat(cm))
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, segments := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.cached("ball:%.3f:%d" % [r, segments], func():
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = segments
		sm.rings = maxi(segments / 2, 3)
		return LowPoly.flat(sm))
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.cached("cap:%.3f:%.3f" % [r, h], func():
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = h
		cm.radial_segments = 8
		cm.rings = 1
		return LowPoly.flat(cm))
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

## 늘린 공 (타원체).
## 폭발 표지: 뾰족한 별 모양 판 (+Z를 바라본다, 양면).
static func burst(parent: Node3D, r: float, pos: Vector3, rot: Vector3, m: Material, points := 8) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for i in points * 2:
		var a := PI * i / points
		var rr := r if i % 2 == 0 else r * 0.5
		verts.append(Vector3(sin(a) * rr, cos(a) * rr, 0))
	for i in points * 2:
		idx.append_array([0, 1 + (i + 1) % (points * 2), 1 + i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3(0, 0, 1))
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if m is StandardMaterial3D:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## 폭발통의 표지: 보랏빛 쇠테 둘과 네 면의 노란 폭발 마크 (반지름 r, 높이 h인 통의 겉에).
static func keg_marks(parent: Node3D, r: float, h: float) -> void:
	var hoop := mat(Color(0.42, 0.3, 0.62), 0.6, 0.3)
	for y in [-0.36, 0.36]:
		cyl(parent, r * 1.03, r * 1.03, h * 0.1, Vector3(0, h * y, 0), hoop, Vector3.ZERO, 10)
	var disc := mat(Color(0.42, 0.3, 0.62), 0.6)
	var star := mat(Color(1.0, 0.82, 0.15), 0.5, 0.0, 0.25)
	var radius := h * 0.3
	for k in 4:
		var a := k * PI * 0.5
		var out := Vector3(sin(a), 0, cos(a))
		cyl(parent, radius, radius, 0.04, out * (r * 0.97), disc, Vector3(PI * 0.5, a, 0), 12)
		burst(parent, radius * 0.85, out * (r + 0.03), Vector3(0, a, 0), star)


## 폭발물 보관 표지판: 보랏빛 원판에 노란 폭발 마크 (+Z를 바라본다).
static func blast_sign(parent: Node3D, pos: Vector3, radius: float) -> void:
	var disc := cyl(parent, radius, radius, 0.05, pos, mat(Color(0.42, 0.3, 0.62), 0.6), Vector3(PI * 0.5, 0, 0), 12)
	burst(parent, radius * 0.85, pos + Vector3(0, 0, 0.04), Vector3.ZERO, mat(Color(1.0, 0.82, 0.15), 0.5, 0.0, 0.25))
	disc.name = "BlastSign"


static func blob(parent: Node3D, r: float, pos: Vector3, m: Material, scl := Vector3.ONE, rot := Vector3.ZERO, segments := 8) -> MeshInstance3D:
	var mi := ball(parent, r, pos, m, segments)
	mi.scale = scl
	mi.rotation = rot
	return mi


## 미친 발명가 고블린 (원점은 발바닥, -Z가 앞). 플레이어가 늘 등 뒤에서 보므로 등짐·고글 끈·귀를 자세히.
## 노드: Head (머리, 목 위), ArmL/ArmR (어깨, 팔은 아래로 늘어짐)
## basket: 등에 쾅쾅알을 가득 담은 바구니를 멘다 (플레이어).
static func goblin(with_arms := true, basket := false) -> Node3D:
	var root := Node3D.new()
	var skin := mat(GOBLIN_SKIN, 0.8)
	var skin_dark := mat(GOBLIN_SKIN.darkened(0.2), 0.8)
	var ear_in := mat(Color(0.78, 0.5, 0.42), 0.8)
	var cloth := mat(Color(0.42, 0.28, 0.16), 1.0)
	var leather := mat(Color(0.55, 0.35, 0.18), 0.9)
	var leather_dark := mat(Color(0.3, 0.19, 0.11), 0.9)
	var patch := mat(Color(0.72, 0.6, 0.38), 1.0)
	var brass := mat(Color(0.82, 0.62, 0.25), 0.35, 0.6)
	var lens := mat(Color(0.45, 0.85, 0.9), 0.2, 0.0, 0.4)
	var eye := mat(Color(1.0, 0.85, 0.1), 0.5, 0.0, 1.0)
	var black := mat(Color(0.05, 0.04, 0.04), 0.6)
	var tooth := mat(Color(0.95, 0.92, 0.78), 0.6)
	var glass := mat(Color(0.3, 0.5, 0.25), 0.25)
	var rag := mat(Color(0.86, 0.8, 0.62), 1.0)
	# 다리: 휜 짧은 다리와 큰 맨발 (발가락 셋)
	for sx in [-1.0, 1.0]:
		capsule(root, 0.1, 0.48, Vector3(sx * 0.17, 0.3, 0.03), skin, Vector3(0, 0, sx * 0.12))
		blob(root, 0.13, Vector3(sx * 0.19, 0.07, -0.08), skin_dark, Vector3(1.0, 0.55, 1.6))
		for k in 3:
			blob(root, 0.045, Vector3(sx * 0.19 + (k - 1) * 0.065, 0.05, -0.27), skin_dark, Vector3(1, 0.8, 1.3), Vector3.ZERO, 6)
	# 누더기 반바지와 허리띠 (버클, 주머니)
	cyl(root, 0.33, 0.36, 0.3, Vector3(0, 0.55, 0.04), cloth, Vector3(-0.1, 0, 0), 8)
	box(root, Vector3(0.18, 0.14, 0.03), Vector3(0.15, 0.6, -0.31), patch, Vector3(0, 0, 0.2))
	cyl(root, 0.37, 0.37, 0.08, Vector3(0, 0.7, 0.04), leather_dark, Vector3(-0.15, 0, 0), 8)
	box(root, Vector3(0.12, 0.1, 0.04), Vector3(0, 0.71, -0.33), brass)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.16, 0.16, 0.1), Vector3(sx * 0.3, 0.64, -0.2), leather, Vector3(0, sx * 0.6, 0))
	# 구부정한 몸통 (불룩한 배) + 앞이 트인 가죽 조끼
	blob(root, 0.36, Vector3(0, 0.95, 0.02), skin, Vector3(1.0, 1.05, 0.88), Vector3(-0.3, 0, 0))
	var vest := Node3D.new()
	vest.position = Vector3(0, 1.0, 0.08)
	vest.rotation = Vector3(-0.32, 0, 0)
	root.add_child(vest)
	box(vest, Vector3(0.62, 0.46, 0.06), Vector3(0, -0.02, 0.07), leather)
	for sx in [-1.0, 1.0]:
		box(vest, Vector3(0.22, 0.48, 0.14), Vector3(sx * 0.24, 0, -0.2), leather, Vector3(0, sx * 0.25, 0))
	# 가슴의 탄띠 (작은 병들)
	var band := Node3D.new()
	band.position = Vector3(0, 1.0, -0.22)
	band.rotation = Vector3(-0.25, 0, 0.75)
	root.add_child(band)
	box(band, Vector3(0.09, 0.8, 0.05), Vector3.ZERO, leather_dark)
	for k in 3:
		cyl(band, 0.035, 0.04, 0.12, Vector3(0, -0.2 + k * 0.2, -0.05), glass, Vector3.ZERO, 6)
	if basket:
		_bomb_basket(root, leather, leather_dark)
	# 머리
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.5, -0.12)
	root.add_child(head)
	blob(head, 0.28, Vector3.ZERO, skin, Vector3(1.0, 0.95, 1.05))
	blob(head, 0.17, Vector3(0, -0.12, -0.12), skin, Vector3(1.25, 0.8, 1.0))
	# 긴 귀 (안쪽 분홍), 오른쪽 귀에 놋쇠 귀걸이
	for sx in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(sx * 0.25, 0.06, 0.02)
		ear.rotation = Vector3(0.15, sx * -0.2, -sx * 1.2)
		head.add_child(ear)
		cyl(ear, 0.0, 0.12, 0.55, Vector3(0, 0.25, 0), skin, Vector3.ZERO, 4)
		cyl(ear, 0.0, 0.07, 0.4, Vector3(0, 0.22, -0.035), ear_in, Vector3.ZERO, 4)
		if sx > 0.0:
			cyl(ear, 0.045, 0.045, 0.02, Vector3(0, 0.1, 0.06), brass, Vector3(PI * 0.5, 0, 0), 6)
	# 갈고리 코, 눈(검은 눈동자), 찌푸린 눈썹, 이빨 드러낸 웃음
	cyl(head, 0.0, 0.075, 0.28, Vector3(0, -0.04, -0.33), skin_dark, Vector3(-1.75, 0, 0), 5)
	for sx in [-1.0, 1.0]:
		blob(head, 0.065, Vector3(sx * 0.11, 0.04, -0.24), eye, Vector3(1.1, 0.8, 0.6), Vector3.ZERO, 6)
		box(head, Vector3(0.035, 0.05, 0.02), Vector3(sx * 0.11, 0.04, -0.29), black)
		box(head, Vector3(0.14, 0.035, 0.04), Vector3(sx * 0.11, 0.12, -0.25), skin_dark, Vector3(0, 0, sx * 0.35))
	box(head, Vector3(0.2, 0.04, 0.03), Vector3(0, -0.17, -0.25), black)
	for k in 2:
		cyl(head, 0.0, 0.025, 0.06, Vector3(-0.05 + k * 0.1, -0.15, -0.26), tooth, Vector3(PI, 0, 0), 4)
	# 이마의 고글과 뒤통수까지 두른 끈, 정수리의 머리털 한 줌
	cyl(head, 0.285, 0.285, 0.07, Vector3(0, 0.13, 0.0), leather_dark, Vector3(-0.15, 0, 0), 8)
	for sx in [-1.0, 1.0]:
		cyl(head, 0.075, 0.075, 0.06, Vector3(sx * 0.1, 0.18, -0.25), brass, Vector3(PI * 0.5 - 0.3, 0, 0), 8)
		cyl(head, 0.055, 0.055, 0.065, Vector3(sx * 0.1, 0.18, -0.255), lens, Vector3(PI * 0.5 - 0.3, 0, 0), 8)
	for k in 3:
		cyl(head, 0.0, 0.035, 0.14, Vector3((k - 1) * 0.06, 0.27, 0.06 + k * 0.03), skin_dark, Vector3(0.5 + k * 0.25, 0, (k - 1) * 0.5), 4)
	if with_arms:
		for sx in [-1.0, 1.0]:
			var arm := Node3D.new()
			arm.name = "ArmL" if sx < 0 else "ArmR"
			arm.position = Vector3(sx * 0.36, 1.08, -0.05)
			root.add_child(arm)
			goblin_arm(arm, skin, skin_dark, leather_dark)
	return root


## 등에 멘 바구니: 엮은 버들 통에 쾅쾅알이 삐죽삐죽, 어깨끈 둘.
static func _bomb_basket(root: Node3D, strap: Material, strap_dark: Material) -> void:
	var wicker := mat(Color(0.72, 0.52, 0.28), 1.0)
	var wicker_dark := mat(Color(0.5, 0.34, 0.17), 1.0)
	var pack := Node3D.new()
	pack.name = "Basket"
	pack.position = Vector3(0, 0.95, 0.48)
	pack.rotation = Vector3(-0.25, 0, 0)
	root.add_child(pack)
	cyl(pack, 0.3, 0.24, 0.5, Vector3.ZERO, wicker, Vector3.ZERO, 8)
	for y in [-0.17, 0.0, 0.17]:
		cyl(pack, 0.3 - (0.06 * (0.25 - y) / 0.5), 0.3 - (0.06 * (0.25 - y) / 0.5), 0.05, Vector3(0, y, 0), wicker_dark, Vector3.ZERO, 8)
	cyl(pack, 0.32, 0.32, 0.05, Vector3(0, 0.26, 0), wicker_dark, Vector3.ZERO, 8)
	# 쾅쾅알 다섯 알 (까만 폭탄 + 심지)
	for k in 5:
		var a := TAU * k / 4.0
		var p := Vector3(cos(a) * 0.15, 0.3, sin(a) * 0.15) if k < 4 else Vector3(0, 0.36, 0)
		var bomb := Fx.ammo_model(AmmoType.Kind.HE, 1.1, false)
		bomb.position = p
		pack.add_child(bomb)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.08, 0.5, 0.05), Vector3(sx * 0.2, 1.12, 0.12), strap, Vector3(-0.3, 0, sx * 0.1))
		box(root, Vector3(0.1, 0.1, 0.06), Vector3(sx * 0.22, 0.88, 0.3), strap_dark)


## 고블린 팔 (어깨가 원점, 아래로 늘어짐): 마른 팔, 가죽 손목 띠, 큰 손과 엄지.
static func goblin_arm(arm: Node3D, skin: Material, skin_dark: Material, wrap: Material) -> void:
	ball(arm, 0.1, Vector3.ZERO, skin, 6)
	capsule(arm, 0.075, 0.55, Vector3(0, -0.27, 0), skin)
	cyl(arm, 0.085, 0.085, 0.08, Vector3(0, -0.46, 0), wrap, Vector3.ZERO, 6)
	blob(arm, 0.1, Vector3(0, -0.6, -0.01), skin_dark, Vector3(0.9, 1.1, 0.7), Vector3.ZERO, 6)
	cyl(arm, 0.0, 0.035, 0.12, Vector3(0, -0.58, -0.08), skin_dark, Vector3(-1.2, 0, 0), 4)


## 인간 (병사, 전령, 징세관, 남작). 원점은 발바닥, -Z가 앞.
## 누비 웃옷 위에 청회색 흉갑, 허리띠, 장화, 장갑. 노드: ArmL/ArmR, HeadMesh, (투구면) Helmet
static func human(body: Color, hat: int = Hat.NONE, size := 1.0, cape := Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	var m := mat(body, 0.7)
	var steel := mat(body.lightened(0.25), 0.35, 0.6)
	var quilt := mat(Color(0.78, 0.72, 0.6), 0.95)
	var quilt_line := mat(Color(0.66, 0.6, 0.48), 0.95)
	var trousers := mat(Color(0.3, 0.27, 0.25), 0.95)
	var boot := mat(Color(0.25, 0.17, 0.11), 0.8)
	var belt := mat(Color(0.32, 0.2, 0.12), 0.8)
	var skin := mat(Color(0.94, 0.76, 0.62), 0.8)
	var hair := mat(Color(0.4, 0.26, 0.15), 0.9)
	var black := mat(Color(0.08, 0.07, 0.07), 0.6)
	for sx in [-1.0, 1.0]:
		capsule(root, 0.1, 0.6, Vector3(sx * 0.14, 0.5, 0), trousers)
		cyl(root, 0.12, 0.13, 0.32, Vector3(sx * 0.14, 0.16, 0), boot, Vector3.ZERO, 6)
		box(root, Vector3(0.18, 0.08, 0.3), Vector3(sx * 0.14, 0.04, -0.06), boot)
	# 누비 웃옷 (줄무늬 누빔), 그 위에 흉갑과 앞자락
	cyl(root, 0.3, 0.34, 0.5, Vector3(0, 0.95, 0), quilt, Vector3.ZERO, 8)
	for k in 3:
		cyl(root, 0.345, 0.345, 0.03, Vector3(0, 0.78 + k * 0.12, 0), quilt_line, Vector3.ZERO, 8)
	cyl(root, 0.27, 0.3, 0.42, Vector3(0, 1.27, 0), steel, Vector3.ZERO, 8)
	box(root, Vector3(0.36, 0.5, 0.05), Vector3(0, 0.9, -0.33), m)
	box(root, Vector3(0.12, 0.12, 0.02), Vector3(0, 1.3, -0.3), mat(Color(0.9, 0.9, 0.85), 0.6))
	cyl(root, 0.35, 0.35, 0.07, Vector3(0, 1.08, 0), belt, Vector3.ZERO, 8)
	box(root, Vector3(0.09, 0.08, 0.04), Vector3(0, 1.08, -0.35), gold_material())
	cyl(root, 0.08, 0.1, 0.12, Vector3(0, 1.52, 0), skin, Vector3.ZERO, 6)
	var head := ball(root, 0.19, Vector3(0, 1.66, 0), skin)
	head.name = "HeadMesh"
	cyl(root, 0.0, 0.04, 0.09, Vector3(0, 1.64, -0.19), skin, Vector3(-PI * 0.5, 0, 0), 4)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.04, 0.04, 0.02), Vector3(sx * 0.07, 1.69, -0.18), black)
	if hat == Hat.NONE:
		blob(root, 0.2, Vector3(0, 1.73, 0.03), hair, Vector3(1.0, 0.6, 1.0))
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if sx < 0 else "ArmR"
		arm.position = Vector3(sx * 0.4, 1.38, 0)
		root.add_child(arm)
		blob(arm, 0.15, Vector3.ZERO, steel, Vector3(1.0, 0.7, 1.0))
		capsule(arm, 0.08, 0.6, Vector3(0, -0.28, 0), quilt)
		cyl(arm, 0.09, 0.09, 0.12, Vector3(0, -0.5, 0), boot, Vector3.ZERO, 6)
		ball(arm, 0.08, Vector3(0, -0.6, 0), boot, 6)
	if cape.a > 0.0:
		box(root, Vector3(0.75, 1.25, 0.05), Vector3(0, 0.82, 0.32), mat(cape, 0.9), Vector3(0.12, 0, 0))
		box(root, Vector3(0.78, 0.06, 0.07), Vector3(0, 1.45, 0.25), gold_material())
	match hat:
		Hat.HELMET:
			var helmet := Node3D.new()
			helmet.name = "Helmet"
			helmet.position = Vector3(0, 1.74, 0)
			root.add_child(helmet)
			# 챙 넓은 철모 + 코 가리개
			cyl(helmet, 0.16, 0.21, 0.2, Vector3(0, 0.02, 0), steel, Vector3.ZERO, 8)
			cyl(helmet, 0.3, 0.3, 0.03, Vector3(0, -0.07, 0), steel, Vector3.ZERO, 8)
			box(helmet, Vector3(0.04, 0.16, 0.03), Vector3(0, -0.12, -0.21), steel)
			box(helmet, Vector3(0.05, 0.12, 0.05), Vector3(0, 0.17, 0), steel)
		Hat.CROWN:
			var g := gold_material()
			cyl(root, 0.2, 0.2, 0.12, Vector3(0, 1.82, 0), g)
			for i in 5:
				var a := TAU * i / 5.0
				box(root, Vector3(0.06, 0.12, 0.06), Vector3(cos(a) * 0.18, 1.92, sin(a) * 0.18), g)
		Hat.TOP_HAT:
			var hat_black := mat(Color(0.08, 0.08, 0.1), 0.6)
			cyl(root, 0.26, 0.26, 0.03, Vector3(0, 1.76, 0), hat_black)
			cyl(root, 0.16, 0.16, 0.32, Vector3(0, 1.92, 0), hat_black)
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


## 고블린 로켓 (조명탄 불빛을 보고 날아가는 거대 로켓). 원점이 몸통 가운데, +Y가 머리. 길이 약 5.6m.
## 쇠 몸통에 가죽끈과 놋쇠 테, 빨간 탄두에 노란 이빨 무늬, 아래는 나무 날개 넷과 굵은 도화선.
static func rocket() -> Node3D:
	var root := Node3D.new()
	var iron := mat(Color(0.16, 0.16, 0.17), 0.5, 0.5)
	var brass := mat(Color(0.75, 0.58, 0.25), 0.4, 0.7)
	var leather := mat(Color(0.42, 0.26, 0.14), 0.9)
	var red := mat(Color(0.85, 0.12, 0.08), 0.6)
	var yellow := mat(Color(0.98, 0.82, 0.2), 0.6)
	var wood := mat(Color(0.45, 0.3, 0.17))
	cyl(root, 0.5, 0.55, 4.0, Vector3.ZERO, iron, Vector3.ZERO, 10)
	cyl(root, 0.0, 0.5, 1.3, Vector3(0, 2.65, 0), red, Vector3.ZERO, 10)
	# 탄두 아래 노란 톱니 (고블린이 그린 이빨)
	for k in 8:
		var a := k * TAU / 8.0
		box(root, Vector3(0.18, 0.28, 0.04), Vector3(cos(a) * 0.5, 1.95, sin(a) * 0.5), yellow, Vector3(0, -a + PI * 0.5, PI * 0.25))
	for y in [-1.4, 0.0, 1.4]:
		cyl(root, 0.56, 0.56, 0.12, Vector3(0, y, 0), brass, Vector3.ZERO, 10)
	for y in [-0.7, 0.7]:
		cyl(root, 0.535, 0.535, 0.18, Vector3(0, y, 0), leather, Vector3(0.0, 0.0, 0.12 * y), 10)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		box(root, Vector3(0.1, 1.4, 0.9), Vector3(cos(a) * 0.75, -1.6, sin(a) * 0.75), wood, Vector3(0, -a, 0))
	cyl(root, 0.3, 0.4, 0.4, Vector3(0, -2.2, 0), iron, Vector3.ZERO, 8)
	cyl(root, 0.03, 0.03, 0.5, Vector3(0.1, -2.5, 0), mat(Color(0.85, 0.8, 0.65)), Vector3(0, 0, 0.6))
	return root


## 글라이더 폭격 고블린: 엉성한 나무 살에 천을 덧댄 삼각 글라이더(Wing) 밑에 매달린 고블린(Pilot)이
## 자기 몸통만 한 폭탄(Bomb)을 끌어안고 있다. 원점은 발바닥, -Z가 앞.
static func glider_goblin() -> Node3D:
	var root := Node3D.new()
	var pilot := goblin()
	pilot.name = "Pilot"
	root.add_child(pilot)
	for arm_name in ["ArmL", "ArmR"]:
		var arm: Node3D = pilot.get_node(arm_name)
		arm.rotation = Vector3(-1.2, 0, 0.5 if arm_name == "ArmL" else -0.5)
	var bomb := Node3D.new()
	bomb.name = "Bomb"
	bomb.position = Vector3(0, 0.85, -0.45)
	pilot.add_child(bomb)
	var iron := mat(Color(0.1, 0.1, 0.11), 0.5, 0.5)
	ball(bomb, 0.38, Vector3.ZERO, iron, 10)
	cyl(bomb, 0.4, 0.4, 0.08, Vector3.ZERO, mat(Color(0.75, 0.6, 0.25), 0.4, 0.6), Vector3(0.3, 0, 0), 10)
	cyl(bomb, 0.03, 0.03, 0.3, Vector3(0.1, 0.45, 0), mat(Color(0.85, 0.8, 0.65)), Vector3(0, 0, -0.5))
	var wing := Node3D.new()
	wing.name = "Wing"
	wing.position = Vector3(0, 2.4, 0.1)
	root.add_child(wing)
	var spar := mat(Color(0.42, 0.28, 0.15))
	var cloth := mat(Color(0.86, 0.3, 0.18), 0.9)
	var patch := mat(Color(0.9, 0.82, 0.62), 0.9)
	# 삼각 날개: 가운데 용골 + 양 날개 살 + 천 두 장 (조각을 덧댄 자국)
	box(wing, Vector3(0.08, 0.08, 2.6), Vector3(0, 0, 0.2), spar)
	for sx in [-1.0, 1.0]:
		box(wing, Vector3(0.07, 0.07, 2.9), Vector3(sx * 1.1, -0.05, 0.6), spar, Vector3(0, sx * 0.75, 0))
		box(wing, Vector3(1.9, 0.03, 1.9), Vector3(sx * 0.95, 0.0, 0.75), cloth, Vector3(0, sx * 0.78, sx * 0.08))
		box(wing, Vector3(0.5, 0.035, 0.4), Vector3(sx * 0.9, 0.01, 0.9), patch, Vector3(0, sx * 0.4, sx * 0.08))
	# 매달린 줄과 손잡이 막대
	for sx in [-0.4, 0.4]:
		cyl(wing, 0.015, 0.015, 1.0, Vector3(sx * 0.6, -0.5, -0.1), spar, Vector3(0, 0, sx))
	box(wing, Vector3(0.9, 0.06, 0.06), Vector3(0, -1.0, -0.1), spar)
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