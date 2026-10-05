class_name OutpostProps
extends RefCounted
## 인간 전초기지 소품: 수레, 나무통, 상자, 짚단, 무기 거치대, 통나무 더미, 광차 (월드에 맞춰 고른다).
## 임무와 무관하지만 진짜 블록이라 폭발에 날아가고 불에 탄다 (타격감).
## 임무를 바꾸지 않게: 지휘관·병사·목표 건물에서 떨어뜨리고, 투척 언덕에서 각 마당으로 가는 시야 통로와 동료 길을 피한다.
## 소품마다 따로 구조물이라 불이 목표 건물로 번지지 않는다. 화약통(터지는 것)은 두지 않는다.

const FROM_ACTOR := 3.5
const FROM_BLOCK := 2.5
const FROM_PROP := 3.0
const PER_YARD := 3
const MAX_PROPS := 10

const M := Block.Mat
const WOOD := Color(0.5, 0.34, 0.2)
const IRON := Color(0.22, 0.22, 0.24)


## 소품을 놓고, 놓은 자리(나무를 피할 발치)를 돌려준다.
static func place(s: Stage, sc: Scenery) -> Array[Rect2]:
	var spots: Array[Rect2] = []
	var avoid := _avoid_points(s)
	var kinds: Array = ["cart", "hay", "crate", "barrels", "rack"]
	match s.world:
		1:
			kinds = ["orecart", "crate", "barrels", "timber"]
		2, 3, 4:
			kinds = ["rack", "barrels", "crate", "cart", "timber"]
	var placed: Array[Vector2] = []
	for y in sc.yards:
		var n := 0
		for attempt in 14:
			if n >= PER_YARD or placed.size() >= MAX_PROPS:
				break
			var a := sc.rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			var p: Vector2 = y.get_center() + dir * (maxf(y.size.x, y.size.y) * 0.5 + sc.rng.randf_range(2.5, 6.5))
			if not _ok(s, sc, p, avoid, placed):
				continue
			var kind: String = kinds[sc.rng.randi() % kinds.size()]
			var st := s.add_structure()
			st.set_meta("prop", kind)
			_build(st, kind, Vector3(p.x, 0, p.y), sc.rng)
			st.finalize()
			if s.rain:
				for b in st.blocks:
					b.make_wet()
			placed.append(p)
			spots.append(Rect2(p - Vector2(1.6, 1.6), Vector2(3.2, 3.2)))
			n += 1
	return spots


## 사람과 길: 지휘관·병사·배경 고블린·동료 자리, 길(Path3D) 위 점들
static func _avoid_points(s: Stage) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for n in s.get_children():
		if n is Actor or n is GoblinExtra:
			out.append(Vector2(n.position.x, n.position.z))
		elif n is Path3D:
			var curve: Curve3D = n.curve
			var len := curve.get_baked_length()
			var k := 0.0
			while k <= len:
				var q: Vector3 = n.transform * curve.sample_baked(k)
				out.append(Vector2(q.x, q.z))
				k += 1.0
	for c in s.commanders:
		out.append(Vector2(c.position.x, c.position.z))
	# 5월드 진지에 보관된 로켓 부품 받침
	for p in s.get_tree().get_nodes_in_group("rocket_part") if s.is_inside_tree() else []:
		out.append(Vector2(p.position.x, p.position.z))
	return out


static func _ok(s: Stage, sc: Scenery, p: Vector2, avoid: Array[Vector2], placed: Array[Vector2]) -> bool:
	if not sc.flat.grow(-3.0).has_point(p) or sc._in_yard(p, 1.5) or sc._in_corridor(p, 3.5):
		return false
	var pp := Vector2(s.player.position.x, s.player.position.z) if s.player else Vector2.ZERO
	if p.distance_to(pp) < 14.0:
		return false
	for q in avoid:
		if p.distance_to(q) < FROM_ACTOR:
			return false
	for q in placed:
		if p.distance_to(q) < FROM_PROP:
			return false
	for st in s.structures:
		for b in st.blocks:
			var hs := Vector2(b.size.x, b.size.z) * 0.5 + Vector2(FROM_BLOCK, FROM_BLOCK)
			if Rect2(Vector2(b.position.x, b.position.z) - hs, hs * 2.0).has_point(p):
				return false
	return true


static func _build(st: Structure, kind: String, o: Vector3, rng: RandomNumberGenerator) -> void:
	match kind:
		"crate":
			st.add_block(M.WOOD_THIN, o + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9))
			if rng.randf() < 0.6:
				st.add_block(M.WOOD_THIN, o + Vector3(1.0, 0.35, 0.1), Vector3(0.7, 0.7, 0.7))
			if rng.randf() < 0.5:
				st.add_block(M.WOOD_THIN, o + Vector3(0.05, 1.25, 0.0), Vector3(0.7, 0.7, 0.7))
		"barrels":
			var count := rng.randi_range(2, 3)
			for k in count:
				_barrel(st.add_block(M.WOOD_THIN, o + Vector3((k - (count - 1) * 0.5) * 0.8, 0.5, 0), Vector3(0.8, 1.0, 0.8)))
		"hay":
			st.add_block(M.STRAW, o + Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 1.0))
			if rng.randf() < 0.6:
				st.add_block(M.STRAW, o + Vector3(0.2, 1.3, 0), Vector3(1.3, 0.8, 0.9))
		"cart":
			for sz in [-1.0, 1.0]:
				_wheel(st.add_block(M.WOOD_BEAM, o + Vector3(0, 0.45, sz * 0.62), Vector3(0.9, 0.9, 0.16)))
			var bed := st.add_block(M.WOOD_THIN, o + Vector3(0, 1.0, 0), Vector3(2.2, 0.2, 1.4))
			# 손잡이 막대 (장식)
			for sz in [-0.45, 0.45]:
				Models.box(bed, Vector3(1.4, 0.08, 0.08), Vector3(1.6, -0.3, sz), _mat_of(bed), Vector3(0, 0, -0.35))
			# 짐: 짚단이나 나무통
			if rng.randf() < 0.5:
				st.add_block(M.STRAW, o + Vector3(-0.2, 1.45, 0), Vector3(1.2, 0.7, 1.0))
			else:
				_barrel(st.add_block(M.WOOD_THIN, o + Vector3(0.2, 1.55, 0), Vector3(0.75, 0.9, 0.75)))
		"orecart":
			var box := st.add_block(M.WOOD_BEAM, o + Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 1.0))
			for k in 4:
				Models.ball(box, 0.22 + 0.04 * k, Vector3(-0.4 + k * 0.27, 0.6, (k % 2) * 0.2 - 0.1), Models.mat(Color(0.42, 0.4, 0.4)))
			for sx in [-0.45, 0.45]:
				for sz in [-0.52, 0.52]:
					Models.cyl(box, 0.18, 0.18, 0.08, Vector3(sx, -0.45, sz), Models.mat(IRON), Vector3(PI * 0.5, 0, 0), 8)
		"timber":
			for sz in [-0.19, 0.19]:
				_log(st.add_block(M.WOOD_BEAM, o + Vector3(0, 0.19, sz), Vector3(2.6, 0.38, 0.38)))
			_log(st.add_block(M.WOOD_BEAM, o + Vector3(0.1, 0.57, 0), Vector3(2.4, 0.38, 0.38)))
		"rack":
			for sx in [-1.0, 1.0]:
				st.add_block(M.WOOD_THIN, o + Vector3(sx * 0.8, 0.75, 0), Vector3(0.15, 1.5, 0.15))
			var bar := st.add_block(M.WOOD_THIN, o + Vector3(0, 1.3, 0), Vector3(1.45, 0.12, 0.12))
			var steel := Models.mat(Models.HUMAN_STEEL, 0.4, 0.6)
			# 기대 세운 창 넷과 걸어 둔 방패
			for k in 4:
				var x := -0.55 + k * 0.37
				Models.box(bar, Vector3(0.05, 2.0, 0.05), Vector3(x, -0.25, 0.2), _mat_of(bar), Vector3(0.2, 0, 0))
				Models.cyl(bar, 0.0, 0.06, 0.25, Vector3(x, 0.85, 0.42), steel, Vector3(0.2, 0, 0), 4)
			Models.cyl(bar, 0.32, 0.32, 0.06, Vector3(0.0, -0.45, -0.12), Models.mat(Color(0.55, 0.15, 0.12)), Vector3(PI * 0.5, 0, 0), 10)


## 블록 겉모양을 바꿀 때: 블록 자신의 재질 (타면 같이 그을린다)
static func _mat_of(b: Block) -> Material:
	return b._material


static func _hide_box(b: Block) -> void:
	for child in b.get_children():
		if child is MeshInstance3D:
			child.visible = false


## 상자 블록을 둥근 나무통으로 (테 둘)
static func _barrel(b: Block) -> void:
	_hide_box(b)
	var h := b.size.y
	var r := b.size.x * 0.5
	Models.cyl(b, r * 0.92, r * 0.92, h, Vector3.ZERO, _mat_of(b), Vector3.ZERO, 10)
	Models.cyl(b, r * 1.02, r * 1.02, h * 0.36, Vector3.ZERO, _mat_of(b), Vector3.ZERO, 10)
	for y in [-0.32, 0.32]:
		Models.cyl(b, r * 0.97, r * 0.97, 0.06, Vector3(0, y * h, 0), Models.mat(IRON), Vector3.ZERO, 10)


## 상자 블록을 바퀴로 (z축이 굴대)
static func _wheel(b: Block) -> void:
	_hide_box(b)
	var r := b.size.x * 0.5
	Models.cyl(b, r, r, b.size.z, Vector3.ZERO, _mat_of(b), Vector3(PI * 0.5, 0, 0), 10)
	Models.cyl(b, r * 0.25, r * 0.25, b.size.z + 0.06, Vector3.ZERO, Models.mat(IRON), Vector3(PI * 0.5, 0, 0), 6)


## 상자 블록을 통나무로 (x축 방향)
static func _log(b: Block) -> void:
	_hide_box(b)
	Models.cyl(b, b.size.y * 0.5, b.size.y * 0.5, b.size.x, Vector3.ZERO, _mat_of(b), Vector3(0, 0, PI * 0.5), 7)
