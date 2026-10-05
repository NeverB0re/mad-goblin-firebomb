class_name Scenery
extends RefCounted
## 진지 둘레 풍경 (로우폴리 목업): 구릉 지형, 건물 밑 흙마당과 흙길, 나무·바위·풀, 울타리, 먼 산과 구름.
## 월드마다 배경이 다르다: 1 고블린 평원(낮은 초록 언덕, 고블린 흙집과 목책, 토템), 2 광산 도시(가까이 솟은 험한 바위 산줄기,
## 절벽의 광산 입구), 3 인간 요새 근처(멀리 어두운 요새 성벽과 탑), 4 대공 요새(야영지 천막, 더 가까운 요새 성벽과 깃발), 5 왕국 성채.
## 게임플레이를 해치지 않게: 진지(구조물·인물·투척 언덕)를 감싼 평지 안은 높이 0 그대로 평평하고,
## 큰 나무와 건물은 그 밖에, 투척 언덕과 각 구조물 사이 시야 통로를 피해서 둔다. 풍경 소품은 충돌이 없다.
## 평지 밖 구릉만 충돌이 있다 (멀리 빗나간 폭탄이 언덕 속으로 사라지지 않게. 평지 높이보다 낮게 두어 블록과는 닿지 않는다).

const FLAT_MARGIN := 16.0
const SPAN := 170.0
const STEP := 3.0

var s: Stage
var flat: Rect2
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var yards: Array[Rect2] = []
var roads: Array = []  # [Vector2, Vector2]
var corridors: Array = []  # [Vector2, Vector2]
var mat: StandardMaterial3D
var grass := Color(0.42, 0.62, 0.24)
var grass2 := Color(0.56, 0.68, 0.28)
var dirt := Color(0.86, 0.64, 0.34)
var rock := Color(0.55, 0.47, 0.43)
var visuals := true
## 전초기지 소품 발치 (나무와 풀을 두지 않는다)
var prop_spots: Array[Rect2] = []


static func build(stage: Stage) -> void:
	var sc := Scenery.new()
	sc.s = stage
	sc._build()


func _build() -> void:
	visuals = DisplayServer.get_name() != "headless"
	noise.seed = 1234 + s.world * 17
	noise.frequency = 0.012
	rng.seed = hash(s.stage_id)
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	if s.rain:
		grass = Color(0.3, 0.48, 0.24)
		grass2 = Color(0.38, 0.54, 0.26)
		dirt = Color(0.42, 0.33, 0.23)
	elif s.world == 3:
		# 4월드 (먼 거리 진지): 메마른 고원
		grass = Color(0.55, 0.64, 0.3)
		grass2 = Color(0.66, 0.66, 0.36)
	_measure()
	_collision()
	# 소품은 진짜 블록이라 화면 없이(테스트)도 짓는다
	if s.outpost_props:
		prop_spots = OutpostProps.place(s, self)
	if not visuals:
		return
	var ground := s.get_node_or_null("Ground")
	if ground:
		for c in ground.get_children():
			if c is MeshInstance3D:
				c.visible = false
	var turf := s.get_node_or_null("Turf") as MeshInstance3D
	if turf and s.rain:
		(turf.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(0.72, 0.8, 0.95)
	_terrain()
	_mountains()
	_trees()
	_ground_cover()
	_fences()
	_settlement()
	_clouds()


# ---------- 진지 넓이 ----------

func _measure() -> void:
	var pts: Array[Vector2] = []
	var pp := s.player.position if s.player else Vector3.ZERO
	pts.append(Vector2(pp.x, pp.z))
	for st in s.structures:
		var r := Rect2()
		var first := true
		for b in st.blocks:
			var p := Vector2(b.position.x, b.position.z)
			var hs := Vector2(b.size.x, b.size.z) * 0.5
			var br := Rect2(p - hs, hs * 2.0)
			r = br if first else r.merge(br)
			first = false
			pts.append(p)
		if not first:
			yards.append(r.grow(2.5))
	for c in s.get_children():
		if c is Path3D:
			for i in c.curve.point_count:
				var q: Vector3 = c.transform * c.curve.get_point_position(i)
				pts.append(Vector2(q.x, q.z))
		elif c is Actor or c is GoblinExtra:
			pts.append(Vector2(c.position.x, c.position.z))
	for c in s.commanders:
		var cp: Vector3 = c.global_position if c.is_inside_tree() else c.position
		pts.append(Vector2(cp.x, cp.z))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	flat = r.grow(FLAT_MARGIN)
	# 시야 통로: 투척 언덕에서 각 마당까지
	var me := Vector2(pp.x, pp.z)
	for y in yards:
		corridors.append([me, y.get_center()])
	# 흙길: 마당끼리 가까운 순서로 잇고, 가장 먼 마당에서 진지 밖으로
	if not yards.is_empty():
		var done: Array[Vector2] = [yards[0].get_center()]
		var left: Array[Vector2] = []
		for k in range(1, yards.size()):
			left.append(yards[k].get_center())
		while not left.is_empty():
			var best := [INF, 0, 0]
			for i in done.size():
				for j in left.size():
					var dd := done[i].distance_to(left[j])
					if dd < best[0]:
						best = [dd, i, j]
			roads.append([done[best[1]], left[best[2]]])
			done.append(left[best[2]])
			left.remove_at(best[2])
		var far := done[0]
		for c in done:
			if c.distance_to(me) > far.distance_to(me):
				far = c
		var away := (far - me).normalized()
		var side := Vector2(-away.y, away.x) * (1.0 if fposmod(far.x, 2.0) < 1.0 else -1.0)
		roads.append([far, far + (away * 0.6 + side * 0.8).normalized() * 140.0])
		roads.append([far, far + (away * 0.8 - side * 0.6).normalized() * 140.0])


func _outside(x: float, z: float) -> float:
	var dx := maxf(flat.position.x - x, x - flat.end.x)
	var dz := maxf(flat.position.y - z, z - flat.end.y)
	return Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length()


func height(x: float, z: float) -> float:
	var d := _outside(x, z)
	if d <= 0.0:
		return 0.0
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var n2 := noise.get_noise_2d(x * 3.1 + 50.0, z * 3.1) * 0.5 + 0.5
	var h := pow(d, 1.3) * 0.075 * (0.55 + n) + smoothstep(0.0, 25.0, d) * (n2 * 4.0 + n * 6.0)
	# 1월드 고블린 평원은 낮고 완만하게
	if s.world == 0:
		h *= 0.35
	# 흙길은 언덕을 깎아 지나간다
	if _road_dist(x, z) < 4.0:
		h *= 0.75
	return h


func _road_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for r in roads:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, r[0], r[1]).distance_to(p))
	return best


func _in_yard(p: Vector2, grow := 0.0) -> bool:
	for y in yards:
		if y.grow(grow).has_point(p):
			return true
	return false


func _in_corridor(p: Vector2, width: float) -> bool:
	for c in corridors:
		if Geometry2D.get_closest_point_to_segment(p, c[0], c[1]).distance_to(p) < width:
			return true
	return false


# ---------- 지형 ----------

func _grid() -> Rect2:
	return flat.grow(SPAN)


func _collision() -> void:
	var g := _grid()
	var nx := int(g.size.x / STEP) + 1
	var nz := int(g.size.y / STEP) + 1
	var data := PackedFloat32Array()
	data.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := g.position.x + i * STEP
			var z := g.position.y + j * STEP
			var h := height(x, z)
			# 평지는 진짜 땅(높이 0)보다 낮게: 블록과 폭탄은 원래 땅에 닿는다
			data[j * nx + i] = (h if h > 0.3 else -0.3) / STEP
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "Hills"
	body.collision_layer = 1
	body.add_to_group("ground")
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * STEP
	cs.position = Vector3(g.position.x + (nx - 1) * STEP * 0.5, 0, g.position.y + (nz - 1) * STEP * 0.5)
	body.add_child(cs)
	s.add_child(body)


func _ground_color(mid: Vector3, n: Vector3) -> Color:
	var p := Vector2(mid.x, mid.z)
	var col: Color
	if n.y < 0.72:
		col = rock
	elif _in_yard(p, -0.5 + noise.get_noise_2d(mid.x * 9.0, mid.z * 9.0) * 1.5) or _road_dist(mid.x, mid.z) < 1.8 + noise.get_noise_2d(mid.x * 5.0, mid.z * 5.0) * 0.8:
		col = dirt
	else:
		var t := clampf(noise.get_noise_2d(mid.x * 2.5, mid.z * 2.5) * 0.9 + 0.5, 0.0, 1.0)
		col = grass.lerp(grass2, t)
		if mid.y > 30.0:
			col = col.lerp(rock.lightened(0.15), clampf((mid.y - 30.0) / 25.0, 0.0, 0.7))
	var k := (LowPoly.h1(mid, 4.0) - 0.5) * 0.1
	return col.lightened(k) if k > 0.0 else col.darkened(-k)


func _terrain() -> void:
	var g := _grid()
	var nx := int(g.size.x / STEP) + 1
	var nz := int(g.size.y / STEP) + 1
	var pts := PackedVector3Array()
	pts.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := g.position.x + i * STEP
			var z := g.position.y + j * STEP
			# 격자를 살짝 비틀어 삼각형 모양이 제각각이게 (평지 높이는 0 그대로)
			x += (LowPoly.h1(Vector3(i, 0, j), 1.0) - 0.5) * STEP * 0.5
			z += (LowPoly.h1(Vector3(i, 0, j), 2.0) - 0.5) * STEP * 0.5
			pts[j * nx + i] = Vector3(x, height(x, z), z)
	var b := LowPoly.Builder.new()
	for j in nz - 1:
		for i in nx - 1:
			var a := pts[j * nx + i]
			var c1 := pts[j * nx + i + 1]
			var c2 := pts[(j + 1) * nx + i + 1]
			var d := pts[(j + 1) * nx + i]
			var tris := [[a, c1, c2], [a, c2, d]] if (i + j) % 2 == 0 else [[a, c1, d], [c1, c2, d]]
			for t in tris:
				var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
				if n.y < 0.0:
					n = -n
				b.tri(t[0], t[1], t[2], _ground_color(mid, n), Vector3.UP)
	_add_mesh(b.commit(mat))


func _add_mesh(m: Mesh, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(mi)
	return mi


func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, height(p.x, p.y), p.y)


# ---------- 먼 산과 구름 ----------

func _mountains() -> void:
	var b := LowPoly.Builder.new()
	var c := flat.get_center()
	var pp := s.player.position
	var fwd := (c - Vector2(pp.x, pp.z)).normalized()
	if fwd == Vector2.ZERO:
		fwd = Vector2(0, -1)
	var base_r := maxf(flat.size.length() * 0.5, 60.0) + SPAN + 40.0
	# [개수, 높이, 밑둘레 반지름, 꼭대기 비율, 더 가까이(m), 산 색, 꼭대기 색]
	var look: Array = [14, Vector2(70.0, 150.0), Vector2(60.0, 110.0), Vector2(0.04, 0.14), 0.0, Color(0.56, 0.47, 0.45), Color(0.74, 0.66, 0.6)]
	match s.world:
		0:
			# 고블린 평원: 낮고 둥근 초록 언덕만 멀리
			look = [16, Vector2(22.0, 45.0), Vector2(70.0, 120.0), Vector2(0.35, 0.55), 0.0, Color(0.42, 0.58, 0.3), Color(0.5, 0.66, 0.34)]
		1:
			# 광산 도시: 가까이 빽빽하게 솟은 뾰족하고 험한 바위 산줄기
			look = [24, Vector2(130.0, 240.0), Vector2(40.0, 75.0), Vector2(0.02, 0.07), 45.0, Color(0.42, 0.38, 0.36), Color(0.62, 0.6, 0.6)]
	var rock_col: Color = look[5]
	var top_col: Color = look[6]
	if s.rain:
		rock_col = rock_col.lerp(Color(0.42, 0.42, 0.44), 0.6)
		top_col = top_col.lerp(Color(0.6, 0.6, 0.62), 0.6)
	var count: int = look[0]
	var h_range: Vector2 = look[1]
	var r_range: Vector2 = look[2]
	var top_ratio: Vector2 = look[3]
	var nearer: float = look[4]
	for i in count:
		var a := (float(i) / count) * TAU + rng.randf_range(-0.15, 0.15)
		var dir := Vector2(cos(a), sin(a))
		var dist := base_r - nearer + rng.randf_range(0.0, 120.0)
		var p := c + dir * dist
		var r := rng.randf_range(r_range.x, r_range.y)
		var h := rng.randf_range(h_range.x, h_range.y) * (1.15 if dir.dot(fwd) > 0.3 else 0.85)
		var cone := CylinderMesh.new()
		cone.top_radius = r * rng.randf_range(top_ratio.x, top_ratio.y)
		cone.bottom_radius = r
		cone.height = h
		cone.radial_segments = 7
		cone.rings = 3
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, h * 0.5 - 6.0, p.y))
		b.add_prim(cone, xf, rock_col, 0.12, r * 0.09, float(i))
		# 밝은 꼭대기
		var top := CylinderMesh.new()
		top.top_radius = cone.top_radius
		top.bottom_radius = lerpf(cone.top_radius, r, 0.3)
		top.height = h * 0.3
		top.radial_segments = 7
		top.rings = 1
		b.add_prim(top, xf.translated(Vector3(0, h * 0.36, 0)), top_col, 0.1, r * 0.03, float(i) + 0.5)
	var mi := _add_mesh(b.commit(mat), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _clouds() -> void:
	if s.night:
		return
	var b := LowPoly.Builder.new()
	var c := flat.get_center()
	for i in 9:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(120.0, 320.0)
		var y := rng.randf_range(55.0, 95.0)
		var sc := rng.randf_range(4.0, 8.0)
		for k in 4:
			var sp := SphereMesh.new()
			sp.radius = 1.0
			sp.height = 2.0
			sp.radial_segments = 6
			sp.rings = 3
			var o := Vector3((k - 1.5) * 1.5, (rng.randf() - 0.3) * 0.7, rng.randf_range(-0.7, 0.7)) * sc
			var r := (1.5 - absf(k - 1.5) * 0.3) * sc
			b.add_prim(sp, Transform3D(Basis.from_scale(Vector3(r, r * 0.65, r)), Vector3(p.x, y, p.y) + o), Color(1, 1, 1) if not s.rain else Color(0.7, 0.72, 0.76), 0.04, 0.2, float(i * 4 + k))
	_add_mesh(b.commit(mat), false)


# ---------- 나무, 바위, 풀 ----------

func _near_prop(p: Vector2, grow := 0.0) -> bool:
	for r in prop_spots:
		if r.grow(grow).has_point(p):
			return true
	return false


func _tree_ok(p: Vector2) -> bool:
	if _near_prop(p, 2.0):
		return false
	if flat.grow(-6.0).has_point(p) and not _far_band(p):
		return false
	if _in_corridor(p, 9.0) or _in_yard(p, 6.0) or _road_dist(p.x, p.y) < 4.0:
		return false
	var pp := s.player.position
	if p.distance_to(Vector2(pp.x, pp.z)) < 14.0:
		return false
	return true


## 평지 안쪽이라도 맨 가장자리 띠는 나무를 둘 수 있다
func _far_band(p: Vector2) -> bool:
	var inner := flat.grow(-FLAT_MARGIN * 0.45)
	return not inner.has_point(p)


func _pine(b: LowPoly.Builder, p: Vector3, sc: float, seed: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18 * sc
	trunk.bottom_radius = 0.26 * sc
	trunk.height = 1.4 * sc
	trunk.radial_segments = 5
	trunk.rings = 0
	b.add_prim(trunk, Transform3D(Basis(), p + Vector3(0, 0.6 * sc, 0)), Color(0.42, 0.27, 0.16), 0.1)
	var greens := [Color(0.16, 0.38, 0.22), Color(0.2, 0.45, 0.25), Color(0.25, 0.52, 0.27)]
	if s.world == 3:
		greens = [Color(0.22, 0.38, 0.2), Color(0.27, 0.44, 0.22), Color(0.32, 0.5, 0.24)]
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = (1.6 - i * 0.4) * sc
		cone.height = 2.1 * sc
		cone.radial_segments = 6
		cone.rings = 0
		var basis := Basis(Vector3.UP, seed + i * 0.6)
		b.add_prim(cone, Transform3D(basis, p + Vector3(0, (1.9 + i * 1.15) * sc, 0)), greens[i], 0.12, 0.08 * sc, seed + i)


func _leafy(b: LowPoly.Builder, p: Vector3, sc: float, seed: float, autumn: bool) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14 * sc
	trunk.bottom_radius = 0.28 * sc
	trunk.height = 2.4 * sc
	trunk.radial_segments = 5
	trunk.rings = 1
	var lean := Basis(Vector3(1, 0, 0.5).normalized(), (LowPoly.h1(p) - 0.5) * 0.3)
	b.add_prim(trunk, Transform3D(lean, p + Vector3(0, 1.1 * sc, 0)), Color(0.45, 0.3, 0.18), 0.1, 0.05 * sc, seed)
	var palette := [Color(0.95, 0.68, 0.22), Color(0.92, 0.5, 0.18), Color(0.98, 0.8, 0.32)] if autumn else [Color(0.42, 0.64, 0.24), Color(0.52, 0.7, 0.26), Color(0.36, 0.56, 0.22)]
	var top := p + lean * Vector3(0, 2.3 * sc, 0)
	for k in 4:
		var sp := SphereMesh.new()
		sp.radius = 1.0
		sp.height = 2.0
		sp.radial_segments = 6
		sp.rings = 3
		var a := seed * 3.0 + k * 1.9
		var o := Vector3(cos(a) * 0.9, 0.4 + (k % 2) * 0.7, sin(a) * 0.9) * sc if k > 0 else Vector3(0, 0.9 * sc, 0)
		var r := (1.35 if k == 0 else 0.95) * sc
		b.add_prim(sp, Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)), top + o), palette[k % 3], 0.1, 0.22, seed + k)


func _rock_at(b: LowPoly.Builder, p: Vector3, sc: float, seed: float) -> void:
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 6
	sp.rings = 3
	var basis := Basis(Vector3.UP, seed) * Basis.from_scale(Vector3(sc, sc * 0.6, sc * 0.85))
	b.add_prim(sp, Transform3D(basis, p + Vector3(0, sc * 0.15, 0)), rock.lightened(0.08), 0.14, 0.3, seed)


func _trees() -> void:
	var b := LowPoly.Builder.new()
	var g := _grid().grow(-20.0)
	var autumn_ratio := 0.0 if s.rain else (0.35 if s.world in [0, 2] else 0.15)
	var placed := 0
	var tries := 0
	while placed < 260 and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(g.position.x, g.end.x), rng.randf_range(g.position.y, g.end.y))
		if not _tree_ok(p):
			continue
		var gp := _on_ground(p)
		if gp.y > 40.0:
			continue
		# 덤불숲처럼 모여 자라게: 노이즈가 높은 곳에 많이
		var dens := noise.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.5 + 0.5
		if rng.randf() > dens * 1.2:
			continue
		var sc := rng.randf_range(0.9, 1.6)
		var seed := float(placed)
		var gpd := gp - Vector3(0, 0.15, 0)
		if rng.randf() < 0.55:
			_pine(b, gpd, sc, seed)
		else:
			_leafy(b, gpd, sc * 0.9, seed, rng.randf() < autumn_ratio)
		placed += 1
	for i in 70:
		var p := Vector2(rng.randf_range(g.position.x, g.end.x), rng.randf_range(g.position.y, g.end.y))
		if not _tree_ok(p) and not _far_band(p):
			continue
		if _in_corridor(p, 5.0) or _in_yard(p, 3.0):
			continue
		_rock_at(b, _on_ground(p), rng.randf_range(0.5, 2.2), float(i))
	_add_mesh(b.commit(mat))


## 평지 위 풀 무더기·꽃·조약돌 (낮아서 조준을 가리지 않는다).
func _ground_cover() -> void:
	var b := LowPoly.Builder.new()
	var g := flat.grow(30.0)
	var flower_cols := [Color(0.98, 0.9, 0.35), Color(0.95, 0.95, 0.95), Color(0.9, 0.45, 0.55)]
	for i in 420:
		var p := Vector2(rng.randf_range(g.position.x, g.end.x), rng.randf_range(g.position.y, g.end.y))
		if _in_yard(p, 0.8) or _road_dist(p.x, p.y) < 2.2 or _near_prop(p):
			continue
		var gp := _on_ground(p)
		var r := rng.randf()
		if r < 0.6:
			for k in 4:
				var blade := CylinderMesh.new()
				blade.top_radius = 0.0
				blade.bottom_radius = 0.07
				blade.height = rng.randf_range(0.35, 0.6)
				blade.radial_segments = 3
				blade.rings = 0
				var a := k * 1.6 + rng.randf()
				var tilt := Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.35)
				b.add_prim(blade, Transform3D(tilt, gp + Vector3(cos(a) * 0.1, blade.height * 0.45, sin(a) * 0.1)), grass.darkened(0.12), 0.1)
		elif r < 0.8 and not s.rain:
			var fc: Color = flower_cols[rng.randi() % 3]
			for k in 3:
				var o := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
				var st := CylinderMesh.new()
				st.top_radius = 0.01
				st.bottom_radius = 0.015
				st.height = 0.3
				st.radial_segments = 3
				st.rings = 0
				b.add_prim(st, Transform3D(Basis(), gp + o + Vector3(0, 0.15, 0)), grass.darkened(0.2), 0.0)
				var bl := SphereMesh.new()
				bl.radius = 0.07
				bl.height = 0.1
				bl.radial_segments = 5
				bl.rings = 2
				b.add_prim(bl, Transform3D(Basis(), gp + o + Vector3(0, 0.32, 0)), fc, 0.06)
		elif r < 0.9:
			_rock_at(b, gp - Vector3(0, 0.05, 0), rng.randf_range(0.12, 0.35), float(i))
		elif not _in_corridor(p, 4.0) and not flat.grow(-8.0).has_point(p):
			# 덤불
			for k in 3:
				var sp := SphereMesh.new()
				sp.radius = 1.0
				sp.height = 2.0
				sp.radial_segments = 6
				sp.rings = 3
				var r2 := rng.randf_range(0.45, 0.8)
				b.add_prim(sp, Transform3D(Basis.from_scale(Vector3(r2, r2 * 0.8, r2)), gp + Vector3((k - 1) * 0.6, r2 * 0.5, rng.randf_range(-0.3, 0.3))), grass.darkened(0.15).lerp(Color(0.25, 0.45, 0.2), 0.4), 0.1, 0.12, float(i * 3 + k))
	_add_mesh(b.commit(mat), false)


# ---------- 울타리, 마을 ----------

## 마당 뒤쪽(투척 언덕 반대편)과 옆을 두르는 나무 울타리. 낮고 충돌이 없다.
func _fences() -> void:
	var b := LowPoly.Builder.new()
	var pp := Vector2(s.player.position.x, s.player.position.z)
	var wood := Color(0.5, 0.34, 0.2) if not s.rain else Color(0.3, 0.23, 0.18)
	for y in yards:
		var r: Rect2 = y.grow(2.5)
		var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for e in 4:
			var a: Vector2 = cs[e]
			var c: Vector2 = cs[(e + 1) % 4]
			var mid := (a + c) * 0.5
			# 투척 언덕 쪽 변은 비워 둔다
			if mid.distance_to(pp) < y.get_center().distance_to(pp):
				continue
			var n := maxi(1, int(a.distance_to(c) / 2.2))
			for k in n + 1:
				var p := a.lerp(c, float(k) / n)
				if _road_dist(p.x, p.y) < 2.0 or _blocked(p):
					continue
				_box(b, wood, Transform3D(Basis(Vector3.UP, rng.randf() * 0.2), Vector3(p.x, 0.5, p.y)), Vector3(0.14, 1.0, 0.14), 0.03)
				if k < n:
					var q := a.lerp(c, (k + 1.0) / n)
					if _road_dist(q.x, q.y) < 2.0 or _blocked(q):
						continue
					var dv := q - p
					var basis := Basis(Vector3.UP, -atan2(dv.y, dv.x))
					for hy in [0.45, 0.8]:
						_box(b, wood.lightened(0.08), Transform3D(basis, Vector3((p.x + q.x) * 0.5, hy, (p.y + q.y) * 0.5)), Vector3(dv.length(), 0.08, 0.06), 0.02)
	_add_mesh(b.commit(mat))


func _blocked(p: Vector2) -> bool:
	for st in s.structures:
		for bl in st.blocks:
			var hs := Vector2(bl.size.x, bl.size.z) * 0.5 + Vector2(0.8, 0.8)
			if Rect2(Vector2(bl.position.x, bl.position.z) - hs, hs * 2.0).has_point(p):
				return true
	return false


## 색을 입힌 모서리 깎은 상자.
func _box(b: LowPoly.Builder, c: Color, xf: Transform3D, size: Vector3, bevel: float) -> void:
	var saved := b.base
	b.base = c
	b.chamfer_box(xf, size, bevel)
	b.base = saved


func _settlement() -> void:
	var b := LowPoly.Builder.new()
	var pp := Vector2(s.player.position.x, s.player.position.z)
	# 진지 밖으로 나가는 흙길 가에 짓는다
	var spots: Array[Vector2] = []
	for r in roads.slice(roads.size() - 2):
		var a: Vector2 = r[0]
		var dir: Vector2 = (r[1] - r[0]).normalized()
		var side := Vector2(-dir.y, dir.x)
		for k in 5:
			var t := 22.0 + k * 13.0
			for sd in [-1.0, 1.0]:
				var p: Vector2 = a + dir * t + side * sd * rng.randf_range(7.0, 11.0)
				if flat.grow(4.0).has_point(p):
					continue
				if _in_corridor(p, 12.0) or p.distance_to(pp) < 25.0 or height(p.x, p.y) > 6.0:
					continue
				spots.append(p)
	match s.world:
		0:
			# 고블린 평원: 둥근 흙집과 목책, 토템 기둥
			for p in spots.slice(0, 7):
				_goblin_hut(b, p)
			_palisade_ring(b, pp)
		1:
			for p in spots.slice(0, 6):
				_house(b, p, pp, true)
			_mine(b, pp)
		2:
			for p in spots.slice(0, 5):
				_house(b, p, pp)
			_fort_line(b, pp, 70.0, 0.75)
		3:
			for p in spots.slice(0, 8):
				_tent(b, p)
			_fort_line(b, pp, 45.0, 1.0)
		4:
			_castle(b, pp)
	_add_mesh(b.commit(mat))


## 1월드: 고블린 흙집 (둥근 흙벽, 짚 원뿔 지붕, 낮은 문)
func _goblin_hut(b: LowPoly.Builder, p: Vector2) -> void:
	var gy := height(p.x, p.y)
	var r := rng.randf_range(1.8, 2.6)
	var wall := CylinderMesh.new()
	wall.top_radius = r * 0.95
	wall.bottom_radius = r
	wall.height = 1.6
	wall.radial_segments = 8
	wall.rings = 0
	b.add_prim(wall, Transform3D(Basis(), Vector3(p.x, gy + 0.8, p.y)), Color(0.6, 0.44, 0.3), 0.1, 0.06, p.x)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = r * 1.25
	roof.height = r * 1.2
	roof.radial_segments = 8
	roof.rings = 1
	b.add_prim(roof, Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(p.x, gy + 1.6 + roof.height * 0.5, p.y)), Color(0.82, 0.68, 0.36), 0.12, 0.12, p.y)
	var door_dir := Vector2(rng.randf_range(-1, 1), 1.0).normalized()
	var dp := p + door_dir * r * 0.98
	_box(b, Color(0.25, 0.17, 0.1), Transform3D(Basis(Vector3.UP, atan2(door_dir.x, door_dir.y)), Vector3(dp.x, gy + 0.5, dp.y)), Vector3(0.7, 1.0, 0.1), 0.02)


## 1월드: 진지 뒤 멀리 고블린 마을을 두르는 뾰족한 목책 (군데군데 끊긴 곳)과 토템 기둥
func _palisade_ring(b: LowPoly.Builder, pp: Vector2) -> void:
	var c := flat.get_center()
	var away := (c - pp).normalized()
	var center := c + away * (flat.size.length() * 0.5 + 30.0)
	var wood := Color(0.48, 0.33, 0.2)
	var radius := 26.0
	for k in 64:
		if k % 13 == 0:
			continue
		var a := TAU * k / 64.0
		var q := center + Vector2(cos(a), sin(a)) * radius
		if _in_corridor(q, 10.0) or flat.grow(6.0).has_point(q):
			continue
		var gy := height(q.x, q.y)
		var hgt := rng.randf_range(2.4, 3.2)
		var stake := CylinderMesh.new()
		stake.top_radius = 0.0
		stake.bottom_radius = 0.2
		stake.height = 0.6
		stake.radial_segments = 5
		stake.rings = 0
		_box(b, wood, Transform3D(Basis(Vector3.UP, a), Vector3(q.x, gy + hgt * 0.5, q.y)), Vector3(0.36, hgt, 0.36), 0.04)
		b.add_prim(stake, Transform3D(Basis(), Vector3(q.x, gy + hgt + 0.3, q.y)), wood.lightened(0.1), 0.05)
	# 토템: 쌓은 머리 셋과 뿔
	var tp := center - away * (radius - 4.0)
	if not _in_corridor(tp, 8.0):
		var gy := height(tp.x, tp.y)
		_box(b, Color(0.4, 0.28, 0.16), Transform3D(Basis(), Vector3(tp.x, gy + 2.5, tp.y)), Vector3(0.6, 5.0, 0.6), 0.05)
		for k in 3:
			_box(b, [Color(0.45, 0.62, 0.28), Color(0.75, 0.3, 0.2), Color(0.85, 0.75, 0.4)][k], Transform3D(Basis(), Vector3(tp.x, gy + 1.4 + k * 1.3, tp.y)), Vector3(1.0, 1.0, 1.0), 0.12)
		for sx in [-1.0, 1.0]:
			_box(b, Color(0.92, 0.88, 0.78), Transform3D(Basis(Vector3.BACK, sx * 0.5), Vector3(tp.x + sx * 0.75, gy + 5.0, tp.y)), Vector3(0.18, 1.0, 0.18), 0.03)


## 2월드: 진지 뒤 산기슭의 광산 입구 (바위 절벽에 뚫린 검은 굴, 나무 받침틀, 레일과 광차, 버력 더미)
func _mine(b: LowPoly.Builder, pp: Vector2) -> void:
	var c := flat.get_center()
	var away := (c - pp).normalized()
	var side := Vector2(-away.y, away.x)
	for k in 2:
		var base := c + away * (flat.size.length() * 0.5 + 38.0 + k * 22.0) + side * (18.0 if k == 0 else -26.0)
		var gy := height(base.x, base.y)
		var yaw := -atan2(away.x, -away.y)
		var basis := Basis(Vector3.UP, yaw + PI)
		var o := Vector3(base.x, gy, base.y)
		var rock := Color(0.4, 0.37, 0.35)
		# 절벽 (울퉁불퉁한 바위 덩어리)
		var cliff := MeshInstance3D.new()
		cliff.mesh = LowPoly.rock_mesh(Vector3(24.0, 15.0, 9.0), base.x + base.y, false)
		cliff.material_override = Models.mat(rock, 1.0)
		cliff.transform = Transform3D(basis, o + basis * Vector3(0, 6.5, 4.6))
		s.add_child(cliff)
		# 검은 굴 입구
		_box(b, Color(0.04, 0.03, 0.03), Transform3D(basis, o + basis * Vector3(0, 1.8, -0.02)), Vector3(3.6, 3.6, 0.2), 0.05)
		# 나무 받침틀 (기둥 둘과 인방)
		var timber := Color(0.42, 0.28, 0.16)
		for sx in [-1.0, 1.0]:
			_box(b, timber, Transform3D(basis, o + basis * Vector3(sx * 2.0, 2.0, -0.25)), Vector3(0.4, 4.0, 0.4), 0.04)
		_box(b, timber, Transform3D(basis, o + basis * Vector3(0, 4.15, -0.25)), Vector3(4.8, 0.45, 0.5), 0.04)
		# 레일과 광차
		for sx in [-0.5, 0.5]:
			_box(b, Color(0.35, 0.33, 0.32), Transform3D(basis, o + basis * Vector3(sx, 0.08, -4.5)), Vector3(0.08, 0.1, 9.0), 0.01)
		for z in range(1, 9):
			_box(b, timber.darkened(0.2), Transform3D(basis, o + basis * Vector3(0, 0.04, -z * 1.0)), Vector3(1.5, 0.08, 0.25), 0.01)
		_box(b, Color(0.3, 0.28, 0.27), Transform3D(basis, o + basis * Vector3(0, 0.75, -5.5)), Vector3(1.3, 0.9, 1.8), 0.06)
		_box(b, Color(0.55, 0.48, 0.38), Transform3D(basis, o + basis * Vector3(0, 1.25, -5.5)), Vector3(1.1, 0.3, 1.6), 0.15)
		# 버력 더미
		var heap := CylinderMesh.new()
		heap.top_radius = 0.6
		heap.bottom_radius = 4.0
		heap.height = 2.6
		heap.radial_segments = 7
		heap.rings = 1
		b.add_prim(heap, Transform3D(basis, o + basis * Vector3(5.5, 1.2, -3.0)), Color(0.5, 0.45, 0.4), 0.12, 0.3, base.x)


## 3·4월드: 진지 뒤로 멀리 이어진 어두운 인간 요새 성벽과 네모 탑 (밤에는 탑 꼭대기에 불빛). dist: 진지 가장자리에서의 거리
func _fort_line(b: LowPoly.Builder, pp: Vector2, dist: float, scale: float) -> void:
	var c := flat.get_center()
	var away := (c - pp).normalized()
	var side := Vector2(-away.y, away.x)
	var base := c + away * (flat.size.length() * 0.5 + dist)
	var stone := Color(0.5, 0.5, 0.52)
	var yaw := -atan2(side.y, side.x)
	var basis := Basis(Vector3.UP, yaw)
	var gy := height(base.x, base.y)
	var wall_len := 140.0
	var wh := 10.0 * scale
	_box(b, stone, Transform3D(basis, Vector3(base.x, gy + wh * 0.5, base.y)), Vector3(wall_len, wh, 4.0), 0.3)
	var n := 22
	for k in n:
		var t := -wall_len * 0.5 + wall_len * (k + 0.5) / n
		var q := base + side * t
		_box(b, stone, Transform3D(basis, Vector3(q.x, gy + wh + 0.6, q.y)), Vector3(wall_len / n * 0.55, 1.2, 4.2), 0.1)
	for k in 6:
		var t := -wall_len * 0.5 + wall_len * (k + 0.5) / 6.0
		var q := base + side * t
		var th := (16.0 if k % 2 == 0 else 13.0) * scale
		_box(b, stone.darkened(0.08), Transform3D(basis, Vector3(q.x, gy + th * 0.5, q.y)), Vector3(6.0, th, 6.0), 0.2)
		for e in 4:
			var ex := (e - 1.5) * 1.5
			_box(b, stone.darkened(0.08), Transform3D(basis, Vector3(q.x, gy + th + 0.5, q.y) + Vector3(side.x, 0, side.y) * ex), Vector3(0.8, 1.0, 6.0), 0.05)
		if s.night:
			_box(b, Color(2.2, 1.3, 0.5), Transform3D(basis, Vector3(q.x, gy + th + 0.4, q.y)), Vector3(0.8, 0.8, 0.8), 0.05)
		else:
			_box(b, Models.FLAG_RED, Transform3D(basis, Vector3(q.x, gy + th + 3.0, q.y) + Vector3(side.x, 0, side.y) * 0.9), Vector3(1.8, 1.1, 0.1), 0.02)
			_box(b, Color(0.3, 0.3, 0.3), Transform3D(basis, Vector3(q.x, gy + th + 2.0, q.y)), Vector3(0.15, 3.0, 0.15), 0.01)


## stone: 광산 도시의 어두운 돌집 (회색 벽, 짙은 지붕)
func _house(b: LowPoly.Builder, p: Vector2, look: Vector2, stone := false) -> void:
	var gy := height(p.x, p.y)
	var yaw := -atan2(look.y - p.y, look.x - p.x) + PI * 0.5 + rng.randf_range(-0.3, 0.3)
	var basis := Basis(Vector3.UP, yaw)
	var o := Vector3(p.x, gy, p.y)
	var w := rng.randf_range(3.6, 5.0)
	var d := rng.randf_range(3.0, 4.0)
	var wall := Color(0.93, 0.86, 0.72) if not s.rain else Color(0.7, 0.66, 0.58)
	if stone:
		wall = Color(0.55, 0.53, 0.5)
	var beam := Color(0.45, 0.3, 0.18)
	var roof: Color = [Color(0.78, 0.3, 0.2), Color(0.62, 0.38, 0.28), Color(0.85, 0.55, 0.3)][rng.randi() % 3]
	if stone:
		roof = [Color(0.3, 0.3, 0.33), Color(0.36, 0.3, 0.27)][rng.randi() % 2]
	_box(b, wall, Transform3D(basis, o + basis * Vector3(0, 1.3, 0)), Vector3(w, 2.6, d), 0.05)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(b, beam, Transform3D(basis, o + basis * Vector3(sx * w * 0.5, 1.35, sz * d * 0.5)), Vector3(0.22, 2.7, 0.22), 0.04)
	_box(b, beam.darkened(0.2), Transform3D(basis, o + basis * Vector3(0, 0.9, -d * 0.5 - 0.03)), Vector3(0.9, 1.7, 0.08), 0.02)
	_box(b, Color(0.3, 0.36, 0.42), Transform3D(basis, o + basis * Vector3(w * 0.28, 1.6, -d * 0.5 - 0.03)), Vector3(0.6, 0.6, 0.06), 0.02)
	var pr := PrismMesh.new()
	pr.size = Vector3(d + 0.8, 1.7, w + 0.6)
	b.add_prim(pr, Transform3D(basis * Basis(Vector3.UP, PI * 0.5), o + basis * Vector3(0, 3.45, 0)), roof, 0.08)
	_box(b, Color(0.55, 0.5, 0.48), Transform3D(basis, o + basis * Vector3(w * 0.3, 4.0, d * 0.15)), Vector3(0.5, 1.2, 0.5), 0.04)


func _tent(b: LowPoly.Builder, p: Vector2) -> void:
	var gy := height(p.x, p.y)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = rng.randf_range(1.8, 2.6)
	cone.height = rng.randf_range(2.6, 3.4)
	cone.radial_segments = 6
	cone.rings = 0
	var cloth: Color = [Color(0.88, 0.84, 0.72), Color(0.46, 0.55, 0.66), Color(0.8, 0.76, 0.62)][rng.randi() % 3]
	b.add_prim(cone, Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(p.x, gy + cone.height * 0.5, p.y)), cloth, 0.1)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 1.0
	pole.radial_segments = 4
	pole.rings = 0
	b.add_prim(pole, Transform3D(Basis(), Vector3(p.x, gy + cone.height + 0.3, p.y)), Color(0.4, 0.28, 0.16))


## 5월드: 진지 뒤로 보이는 흰 성채 (성벽과 탑).
func _castle(b: LowPoly.Builder, pp: Vector2) -> void:
	var c := flat.get_center()
	var away := (c - pp).normalized()
	var side := Vector2(-away.y, away.x)
	var base := c + away * (flat.size.length() * 0.5 + 45.0)
	var stone := Color(0.85, 0.82, 0.76) if not s.rain else Color(0.62, 0.62, 0.62)
	var yaw := -atan2(side.y, side.x)
	var basis := Basis(Vector3.UP, yaw)
	var gy := height(base.x, base.y)
	var wall_len := 90.0
	_box(b, stone, Transform3D(basis, Vector3(base.x, gy + 6.0, base.y)), Vector3(wall_len, 12.0, 4.0), 0.3)
	var n := 13
	for k in n:
		var t := -wall_len * 0.5 + wall_len * (k + 0.5) / n
		var q := base + side * t
		_box(b, stone, Transform3D(basis, Vector3(q.x, gy + 12.6, q.y)), Vector3(wall_len / n * 0.55, 1.4, 4.2), 0.1)
	for k in 5:
		var t := -wall_len * 0.5 + wall_len * k / 4.0
		var q := base + side * t
		var hgt := 22.0 if k == 2 else 17.0
		var cyl := CylinderMesh.new()
		cyl.top_radius = 4.0
		cyl.bottom_radius = 4.4
		cyl.height = hgt
		cyl.radial_segments = 8
		cyl.rings = 0
		b.add_prim(cyl, Transform3D(Basis(), Vector3(q.x, gy + hgt * 0.5, q.y)), stone, 0.08)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 5.0
		cone.height = 6.0
		cone.radial_segments = 8
		cone.rings = 0
		b.add_prim(cone, Transform3D(Basis(), Vector3(q.x, gy + hgt + 3.0, q.y)), Color(0.3, 0.38, 0.6), 0.08)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.1
		pole.bottom_radius = 0.1
		pole.height = 3.0
		pole.radial_segments = 4
		pole.rings = 0
		b.add_prim(pole, Transform3D(Basis(), Vector3(q.x, gy + hgt + 7.0, q.y)), Color(0.3, 0.3, 0.3))
		_box(b, Models.FLAG_RED, Transform3D(basis, Vector3(q.x, gy + hgt + 7.8, q.y) + Vector3(side.x, 0, side.y) * 1.0), Vector3(2.0, 1.2, 0.1), 0.02)
