class_name LowPoly
extends RefCounted
## 로우폴리 그래픽 도구 (목업 단계): 면마다 평평한 법선, 면마다 조금씩 다른 밝기, 모서리를 깎은 상자.
## 메시의 정점 색은 밝기(흰색 근처)만 담고, 실제 색은 재질 albedo가 곱해 준다
## (그래서 불에 그을림·기름 묻음처럼 재질 색을 바꾸는 기존 코드가 그대로 동작한다).
## 같은 모양은 캐시해서 다시 쓴다.

static var _cache := {}
## 기본 도형(원기둥·구)의 단위 크기 꼭짓점과 순서. 모양 비율이 같으면 다시 만들지 않고 크기만 곱해 쓴다
## (풍경의 풀잎·나무·덤불 수천 개를 진지마다 새로 만들던 것이 불러오기 시간의 대부분이었다).
static var _prim_cache := {}


## [단위 꼭짓점, 순서, 크기] — 원래 꼭짓점 = 단위 꼭짓점 * 크기
static func _prim_arrays(mesh: Mesh) -> Array:
	var key := ""
	var scale := Vector3.ONE
	var unit: PrimitiveMesh
	if mesh is CylinderMesh:
		var m := mesh as CylinderMesh
		var r := maxf(m.top_radius, m.bottom_radius)
		key = "c%.4f,%.4f,%d,%d" % [m.top_radius / r, m.bottom_radius / r, m.radial_segments, m.rings]
		scale = Vector3(r, m.height, r)
		if not _prim_cache.has(key):
			var u := CylinderMesh.new()
			u.top_radius = m.top_radius / r
			u.bottom_radius = m.bottom_radius / r
			u.height = 1.0
			u.radial_segments = m.radial_segments
			u.rings = m.rings
			unit = u
	elif mesh is SphereMesh:
		var m := mesh as SphereMesh
		key = "s%.4f,%d,%d,%s" % [m.height / m.radius, m.radial_segments, m.rings, m.is_hemisphere]
		scale = Vector3.ONE * m.radius
		if not _prim_cache.has(key):
			var u := SphereMesh.new()
			u.radius = 1.0
			u.height = m.height / m.radius
			u.radial_segments = m.radial_segments
			u.rings = m.rings
			u.is_hemisphere = m.is_hemisphere
			unit = u
	if key == "":
		var arr := mesh.surface_get_arrays(0)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or idx.is_empty():
			idx = PackedInt32Array(range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
		return [arr[Mesh.ARRAY_VERTEX], idx, Vector3.ONE]
	if not _prim_cache.has(key):
		var arr := unit.surface_get_arrays(0)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or idx.is_empty():
			idx = PackedInt32Array(range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
		_prim_cache[key] = [arr[Mesh.ARRAY_VERTEX], idx]
	var c: Array = _prim_cache[key]
	return [c[0], c[1], scale]


static func h1(v: Vector3, s := 0.0) -> float:
	return fposmod(sin(v.dot(Vector3(12.9898, 78.233, 37.719)) + s) * 43758.5453, 1.0)


static func h3(v: Vector3, s := 0.0) -> Vector3:
	return Vector3(h1(v, s), h1(v, s + 1.7), h1(v, s + 3.1)) * 2.0 - Vector3.ONE


## 밝기 k(-1~1 정도)만큼 흰색을 밝히거나 어둡게 한 정점 색.
static func shade(k: float) -> Color:
	var v := clampf(1.0 + k, 0.0, 2.0)
	return Color(v, v, v)


## 캐시된 메시 (key가 같으면 make를 다시 부르지 않는다).
static func cached(key: String, make: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key]


## 기본 도형 메시를 면마다 평평하게 바꾼다. jitter: 꼭짓점을 흔드는 정도 (같은 자리 꼭짓점은 같이 움직인다).
static func flat(mesh: Mesh, tint := 0.06, jitter := 0.0, seed := 0.0) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx == null or idx.is_empty():
		idx = PackedInt32Array(range(vs.size()))
	var b := Builder.new()
	var pv := PackedVector3Array()
	pv.resize(vs.size())
	for i in vs.size():
		pv[i] = vs[i] + (h3(vs[i].snapped(Vector3.ONE * 0.001), seed) * jitter if jitter > 0.0 else Vector3.ZERO)
	for t in range(0, idx.size(), 3):
		var a := pv[idx[t]]
		var c1 := pv[idx[t + 1]]
		var c2 := pv[idx[t + 2]]
		var hint := ns[idx[t]] + ns[idx[t + 1]] + ns[idx[t + 2]]
		b.tri(a, c1, c2, shade((h1((a + c1 + c2) / 3.0, seed + 5.0) - 0.5) * 2.0 * tint), hint)
	return b.commit()


## 삼각형을 모아 면마다 평평한 메시를 만든다.
class Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	## 정점 색의 바탕 (흰색이면 재질 색을 그대로 쓰고, 풍경처럼 재질 하나를 나눠 쓰면 실제 색)
	var base := Color.WHITE

	func col(k: float) -> Color:
		var v := clampf(1.0 + k, 0.0, 2.0)
		return Color(base.r * v, base.g * v, base.b * v)

	## 기본 도형 메시(Primitive)를 xf로 옮겨 면마다 평평하게 붙인다.
	func add_prim(mesh: Mesh, xf: Transform3D, color: Color, tint := 0.08, jitter := 0.0, seed := 0.0) -> void:
		var arrs := LowPoly._prim_arrays(mesh)
		var vs: PackedVector3Array = arrs[0]
		var idx: PackedInt32Array = arrs[1]
		var sc: Vector3 = arrs[2]
		var pv := PackedVector3Array()
		pv.resize(vs.size())
		for i in vs.size():
			var v := vs[i] * sc
			pv[i] = xf * (v + LowPoly.h3(v.snapped(Vector3.ONE * 0.001), seed) * jitter) if jitter > 0.0 else xf * v
		var center := xf.origin
		var saved := base
		base = color
		for t in range(0, idx.size(), 3):
			var a := pv[idx[t]]
			var b := pv[idx[t + 1]]
			var c := pv[idx[t + 2]]
			var mid := (a + b + c) / 3.0
			tri(a, b, c, col((LowPoly.h1(mid, seed + 5.0) - 0.5) * 2.0 * tint), mid - center)
		base = saved

	## hint: 바깥쪽 방향 (감기는 순서를 여기에 맞춘다)
	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			return
		n = n.normalized()
		if n.dot(hint) < 0.0:
			n = -n
			var t := b
			b = c
			c = t
		# 임시 배열 없이 하나씩 (수만 번 불려서 차이가 크다)
		verts.append(a)
		verts.append(b)
		verts.append(c)
		normals.append(n)
		normals.append(n)
		normals.append(n)
		colors.append(col)
		colors.append(col)
		colors.append(col)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint: Vector3) -> void:
		tri(a, b, c, col, hint)
		tri(a, c, d, col, hint)

	## 모서리를 깎은 상자. xf: 위치·회전, k: 밝기, bevel: 깎는 폭
	func chamfer_box(xf: Transform3D, size: Vector3, bevel: float, k := 0.0, edge_k := 0.05, seed := 0.0) -> void:
		var h := size * 0.5
		var bv := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
		var g := func(axis: int, s: Vector3) -> Vector3:
			# 모서리 s의 꼭짓점 중 axis 쪽 면에 놓인 것
			var p := Vector3(s.x * (h.x - bv), s.y * (h.y - bv), s.z * (h.z - bv))
			p[axis] = s[axis] * h[axis]
			return xf * p
		var center := xf.origin
		var cyc := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for side in [-1.0, 1.0]:
				var pts := []
				for c in cyc:
					var s := Vector3.ZERO
					s[axis] = side
					s[u] = c.x
					s[v] = c.y
					pts.append(g.call(axis, s))
				var fc: Vector3 = (pts[0] + pts[2]) * 0.5
				quad(pts[0], pts[1], pts[2], pts[3], col(k + (LowPoly.h1(fc, seed) - 0.5) * 0.08), fc - center)
		if bv <= 0.001:
			return
		# 모서리 띠 12개
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for su in [-1.0, 1.0]:
				for sv in [-1.0, 1.0]:
					var sp := Vector3.ZERO
					sp[u] = su
					sp[v] = sv
					sp[axis] = 1.0
					var sm := sp
					sm[axis] = -1.0
					var a: Vector3 = g.call(u, sp)
					var b: Vector3 = g.call(v, sp)
					var c: Vector3 = g.call(v, sm)
					var d: Vector3 = g.call(u, sm)
					var fc := (a + c) * 0.5
					quad(a, b, c, d, col(k + edge_k), fc - center)
		# 꼭짓점 삼각형 8개
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var s := Vector3(sx, sy, sz)
					var a: Vector3 = g.call(0, s)
					var b: Vector3 = g.call(1, s)
					var c: Vector3 = g.call(2, s)
					tri(a, b, c, col(k + edge_k), (a + b + c) / 3.0 - center)

	## 각기둥 (로컬 Y축 방향). radii: 아래에서 위로 고리마다 반지름, 높이는 고르게 나눈다
	func prism(xf: Transform3D, radii: Array, height: float, seg: int, k := 0.0, seed := 0.0, cap := true) -> void:
		var rings := []
		var n := radii.size()
		for i in n:
			var y := -height * 0.5 + height * i / float(n - 1)
			var ring := []
			for j in seg:
				var a := TAU * j / seg + PI / seg
				ring.append(xf * Vector3(cos(a) * radii[i], y, sin(a) * radii[i]))
			rings.append(ring)
		var axis := xf.basis.y.normalized()
		for i in n - 1:
			for j in seg:
				var j2 := (j + 1) % seg
				var a: Vector3 = rings[i][j]
				var b: Vector3 = rings[i][j2]
				var c: Vector3 = rings[i + 1][j2]
				var d: Vector3 = rings[i + 1][j]
				var mid := (a + c) * 0.5
				var off := mid - xf.origin
				var hint := off - axis * off.dot(axis)
				quad(a, b, c, d, col(k + (LowPoly.h1(mid, seed) - 0.5) * 0.12), hint)
		if cap:
			for end in [0, n - 1]:
				var ring: Array = rings[end]
				var cc := Vector3.ZERO
				for p in ring:
					cc += p
				cc /= ring.size()
				var dir := -axis if end == 0 else axis
				for j in seg:
					tri(cc, ring[j], ring[(j + 1) % seg], col(k + 0.06), dir)

	func commit(material: Material = null) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_COLOR] = colors
		var m := ArrayMesh.new()
		if verts.is_empty():
			return m
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if material:
			m.surface_set_material(0, material)
		return m


# ---------- 블록 모양 (충돌 상자 크기는 그대로, 겉모양만) ----------

## style: "plank" 나무(판자·각목), "stone" 석재, "cracked" 금 간 석재, "straw" 짚, "steel", "keg" 통, "plain"
## seed: 같은 크기라도 모양을 달리할 때 (금 간 석재는 블록마다 부서진 모양이 다르다)
static func block_mesh(style: String, size: Vector3, seed := 0) -> Mesh:
	var key := "blk:%s:%s:%d" % [style, str(size.snapped(Vector3.ONE * 0.01)), seed]
	return cached(key, func(): return _make_block(style, size, seed))


static func _make_block(style: String, size: Vector3, extra_seed := 0) -> ArrayMesh:
	var b := Builder.new()
	var seed := size.x * 3.7 + size.y * 1.3 + size.z * 2.1 + extra_seed * 0.37
	match style:
		"plank":
			_wood(b, size, seed)
		"stone", "cracked":
			_masonry(b, size, seed, style == "cracked")
		"straw":
			_straw(b, size, seed)
		"keg":
			var r := minf(size.x, size.z) * 0.5
			b.prism(Transform3D.IDENTITY, [r * 0.86, r * 0.97, r, r * 0.97, r * 0.86], size.y, 10, 0.0, seed)
		"steel":
			b.chamfer_box(Transform3D.IDENTITY, size, 0.035, 0.0, 0.08, seed)
		_:
			b.chamfer_box(Transform3D.IDENTITY, size, minf(size.x, minf(size.y, size.z)) * 0.12, 0.0, 0.05, seed)
	return b.commit()


static func _axes(size: Vector3) -> Array:
	var ax := [0, 1, 2]
	ax.sort_custom(func(a, c): return size[a] < size[c])
	return ax  # [가장 얇은, 중간, 가장 긴]


## 나무: 얇고 넓으면 판자 여러 장, 아니면 모서리를 굵게 깎은 각목 (멀리서 통나무처럼).
static func _wood(b: Builder, size: Vector3, seed: float) -> void:
	var ax := _axes(size)
	var t: int = ax[0]
	var m: int = ax[1]
	var l: int = ax[2]
	if size[m] > 0.5 and size[t] < size[m] * 0.5:
		var n := clampi(roundi(size[m] / 0.32), 2, 24)
		for i in n:
			var s := size
			s[m] = size[m] / n
			var p := Vector3.ZERO
			p[m] = -size[m] * 0.5 + s[m] * (i + 0.5)
			# 판자마다 두께·길이가 아주 조금씩 다르다
			s[t] *= 0.9 + h1(Vector3(i, 0, seed)) * 0.1
			s[l] -= h1(Vector3(i, 1, seed)) * minf(0.08, size[l] * 0.05)
			var k := (h1(Vector3(i, 2, seed)) - 0.5) * 0.24
			b.chamfer_box(Transform3D(Basis(), p), s, minf(0.04, s[m] * 0.18), k, 0.08, seed + i)
	else:
		var bev := minf(size[t], size[m]) * 0.2
		b.chamfer_box(Transform3D.IDENTITY, size, bev, 0.0, 0.07, seed)


## 석재: 높이와 길이가 제각각인 다듬은 돌을 엇갈려 쌓고, 돌 사이 줄눈은 어둡게 들어가 보인다. 군데군데 이끼가 낀다.
## rough(금 간 석재): 돌이 둘로 쪼개져 틈이 벌어지고, 조금씩 비뚤어지거나 튀어나오고, 모서리가 닳아 둥글며,
## 윗단은 깨져 낮아지거나 빠져 들쭉날쭉하고, 양 끝 돌은 이가 빠졌다. 이끼가 더 많다. 넓고 얇은 판은 바닥돌 격자.
static func _masonry(b: Builder, size: Vector3, seed: float, rough: bool) -> void:
	var ax := _axes(size)
	if ax[0] == 1 and size.y < 0.6 and minf(size.x, size.z) > 1.2:
		var nx := clampi(roundi(size.x / 0.9), 1, 8)
		var nz := clampi(roundi(size.z / 0.9), 1, 8)
		b.chamfer_box(Transform3D.IDENTITY, size * Vector3(0.99, 0.9, 0.99), 0.02, -0.45, 0.0, seed)
		for i in nx:
			for j in nz:
				var s := Vector3(size.x / nx - 0.03, size.y, size.z / nz - 0.03)
				var p := Vector3(-size.x * 0.5 + size.x / nx * (i + 0.5), 0, -size.z * 0.5 + size.z / nz * (j + 0.5))
				_stone(b, Transform3D(Basis(), p), s, h1(Vector3(i, j, seed)), 0.15 if rough else 0.06, rough)
		return
	var l := 0 if size.x >= size.z else 2
	var t := 2 if l == 0 else 0
	var gap := 0.05 if rough else 0.025
	# 줄눈 안쪽 어두운 속 (윗단이 깨진 금 간 석재는 속도 윗단만큼 낮다)
	var rows := clampi(roundi(size.y / 0.5), 1, 12)
	var heights := []
	var total := 0.0
	for r in rows:
		var hh := 0.75 + h1(Vector3(r, 3, seed)) * 0.5
		heights.append(hh)
		total += hh
	for r in rows:
		heights[r] = heights[r] / total * size.y
	# 속은 돌 모서리 깎인 깊이보다 깊이 들어가 있어야 돌이 온전히 보인다
	var core := size
	core[l] -= 0.18 if rough else 0.1
	core[t] -= 0.18 if rough else 0.1
	core.y -= heights[rows - 1] * 0.6 if rough and rows > 1 else 0.02
	b.chamfer_box(Transform3D(Basis(), Vector3(0, (core.y - size.y) * 0.5, 0)), core, 0.02, -0.35, 0.0, seed)
	var base_len := clampf(size[l] / maxf(1.0, roundf(size[l] / 0.85)), 0.45, 1.3)
	# 너무 많으면 돌을 키운다
	while rows * ceili(size[l] / (base_len * 0.75) + 1.0) > 80:
		base_len *= 1.4
	var y := -size.y * 0.5
	for r in rows:
		var rh: float = heights[r]
		var top := r == rows - 1 and rows > 1
		var cur := -size[l] * 0.5
		var i := 0
		while cur < size[l] * 0.5 - 0.01:
			var hv := Vector3(r, i, seed)
			var ln := base_len * (0.65 + h1(hv, 1.0) * 0.7)
			if i == 0 and r % 2 == 1:
				ln *= 0.5
			ln = minf(ln, size[l] * 0.5 - cur)
			if size[l] * 0.5 - cur - ln < base_len * 0.3:
				ln = size[l] * 0.5 - cur
			var cell_lo := cur
			cur += ln
			i += 1
			var lo := cell_lo + gap * 0.5
			var hi := cell_lo + ln - gap * 0.5
			var y0 := y + gap * 0.5
			var y1 := y + rh - gap * 0.5
			if rough:
				# 양 끝 돌은 이가 빠지고, 윗단은 깨져 낮아지거나 빠진다
				if cell_lo <= -size[l] * 0.5 + 0.01:
					lo += h1(hv, 2.0) * 0.08
				if cur >= size[l] * 0.5 - 0.01:
					hi -= h1(hv, 3.0) * 0.08
				if top:
					var broke := h1(hv, 4.0)
					if broke < 0.18:
						continue
					if broke < 0.6:
						y1 -= rh * (0.25 + h1(hv, 5.0) * 0.45)
			if hi - lo < 0.15 or y1 - y0 < 0.1:
				continue
			var pieces := [[lo, hi]]
			if rough and h1(hv, 6.0) < 0.28 and hi - lo > 0.6:
				# 둘로 쪼개져 틈이 벌어졌다
				var cut := lerpf(lo, hi, 0.3 + h1(hv, 7.0) * 0.4)
				pieces = [[lo, cut - 0.03], [cut + 0.03, hi]]
			for pc in pieces:
				var sz := size
				sz[l] = pc[1] - pc[0]
				sz.y = y1 - y0
				var p := Vector3.ZERO
				p[l] = (pc[0] + pc[1]) * 0.5
				p.y = (y0 + y1) * 0.5
				var basis := Basis()
				if rough:
					# 조금씩 비뚤어지고 앞뒤로 튀어나온다
					var tilt := (h1(Vector3(pc[0], r, seed), 8.0) - 0.5) * 0.14
					var turn := (h1(Vector3(pc[0], r, seed), 11.0) - 0.5) * 0.12
					basis = Basis(Vector3.UP, turn) * Basis(Vector3.BACK if l == 0 else Vector3.RIGHT, tilt)
					p[t] += (h1(Vector3(pc[0], r, seed), 9.0) - 0.5) * 0.06
				_stone(b, Transform3D(basis, p), sz, h1(Vector3(pc[0], r, seed), 10.0), 0.2 if rough else 0.08, rough)
		y += rh


## 돌 한 덩이: 밝기가 조금씩 다르고, 가끔 이끼가 낀다 (moss: 이끼 낄 확률). 금 간 돌은 모서리가 닳아 둥글다.
static func _stone(b: Builder, xf: Transform3D, size: Vector3, r: float, moss: float, rough: bool) -> void:
	var saved := b.base
	if r < moss:
		b.base = Color(0.86, 0.94, 0.72)
	var bevel := minf(0.06 if rough else 0.04, minf(size.x, minf(size.y, size.z)) * 0.25)
	b.chamfer_box(xf, size, bevel, (fposmod(r * 7.3, 1.0) - 0.5) * (0.24 if rough else 0.14), -0.04, r * 31.0)
	b.base = saved


## 짚: 층층이 겹친 다발 (층마다 조금씩 튀어나온다).
static func _straw(b: Builder, size: Vector3, seed: float) -> void:
	var rows := clampi(roundi(size.y / 0.22), 1, 12)
	var rh := size.y / rows
	for r in rows:
		var s := Vector3(size.x, rh, size.z)
		var grow := 0.04 if r % 2 == 0 else 0.0
		s.x += grow
		s.z += grow
		var p := Vector3(0, -size.y * 0.5 + rh * (r + 0.5), 0)
		b.chamfer_box(Transform3D(Basis(), p), s, minf(0.07, rh * 0.35), (h1(Vector3(r, 3, seed)) - 0.5) * 0.2 + (0.04 if grow > 0.0 else -0.04), 0.1, seed + r)


# ---------- 바위 ----------

## 각진 바위 덩어리 (윗면이 평평해서 올라설 수 있다). 크기는 충돌 상자와 거의 같다.
static func rock_mesh(size: Vector3, seed: float, flat_top := true) -> ArrayMesh:
	var sm := BoxMesh.new()
	sm.size = size
	sm.subdivide_width = clampi(int(size.x / 1.6), 1, 8)
	sm.subdivide_depth = clampi(int(size.z / 1.6), 1, 8)
	sm.subdivide_height = clampi(int(size.y / 1.6), 1, 8)
	var arr := sm.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var h := size * 0.5
	var pv := PackedVector3Array()
	pv.resize(vs.size())
	for i in vs.size():
		var v := vs[i]
		var key := v.snapped(Vector3.ONE * 0.001)
		var j := h3(key, seed) * minf(0.35 + maxf(size.x, size.z) * 0.03, 0.9)
		# 윗면은 높이를 그대로 두고, 옆면은 바깥으로 울퉁불퉁
		if flat_top and absf(v.y - h.y) < 0.001:
			j.y = 0.0
			j.x *= 0.4
			j.z *= 0.4
		# 바닥은 조금 넓게 퍼진다
		var spread := 1.0 + (h.y - v.y) / maxf(size.y, 0.01) * 0.12
		pv[i] = Vector3(v.x * spread, v.y, v.z * spread) + j
	var b := Builder.new()
	for t in range(0, idx.size(), 3):
		var a := pv[idx[t]]
		var c1 := pv[idx[t + 1]]
		var c2 := pv[idx[t + 2]]
		var hint := ns[idx[t]] + ns[idx[t + 1]] + ns[idx[t + 2]]
		var mid := (a + c1 + c2) / 3.0
		# 윗면은 밝게, 아래로 갈수록 어둡게
		var k := (h1(mid, seed) - 0.5) * 0.16 + (0.08 if hint.y > 2.0 else (mid.y / maxf(size.y, 0.01)) * 0.12)
		b.tri(a, c1, c2, shade(k), hint)
	return b.commit()
