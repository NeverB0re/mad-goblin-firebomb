class_name StageDefs
extends RefCounted
## 확장 테스트 스테이지 E1~E11 (확장 기획서 9장). 승리 조건은 지휘관 쓰러뜨리기 (E3·E10은 전령 멈추기).
## 플레이어(미친 고블린)는 투척 구역에서 -Z 방향의 인간 진지를 내려다본다.
## 화면에 목표 문구는 없다. 무엇을 해야 할지는 재질로 보여 준다:
## 짚·나무 = 탄다, 금 간 석벽 = 고폭탄으로 부서진다, 반듯한 석재 = 버틴다, 강철 = 절대 안 부서진다.
## 인간 시설은 반듯하고 대칭인 규격품, 빨강은 깃발에만 쓴다.
## 각 스테이지는 "설계상 최소 투척 수 + 보정 여유 2~3발"로 탄을 준다.

const FIRE := preload("res://ammo/fire.tres")
const HE := preload("res://ammo/he.tres")
const OIL := preload("res://ammo/oil.tres")
const FLARE := preload("res://ammo/flare.tres")
const M := Block.Mat

const COUNT := 11
const NAMES := ["E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11"]

## 스테이지별 투척 구역 높이. 기본은 낮은 언덕, 아주 먼 표적(E9)만 고지대, 먼 종합 스테이지(E10)는 중간
const HILL := 6.0
const PERCH := [HILL, HILL, HILL, HILL, HILL, HILL, HILL, HILL, 25.0, 12.0, HILL]
## 스테이지별 투척 구역 앞뒤 위치. 폭탄이 무거워 사거리가 짧으니 진지 쪽으로 다가가 던진다
## (높이 띄워 던지게 하려고 표적은 대개 사거리의 3/4 안팎에 둔다)
const ZONE_Z := [0.0, 0.0, -10.0, -12.0, -14.0, -18.0, -4.0, -6.0, -36.0, -15.0, -10.0]
## 지휘관 위치 (E3·E10 전령 스테이지는 지휘관이 없다)
const COMMANDER := [
	Vector3(0, 0, -45), Vector3(0, 4.3, -40), Vector3(-6, 0, -58), Vector3(0, 0, -48), Vector3(0, 0, -52),
	Vector3(0, 0, -57), Vector3(0, 0, -44), Vector3(0, 0, -50), Vector3(0, 0, -106), Vector3(0, 0, -60), Vector3(0, 4.3, -62),
]
## 전령 경로 (E3, E10): 구불구불한 꺾은선. 뒤 스테이지일수록 빠르고 많이 꺾인다.
## 도중에 개울 위 나무다리를 건넌다 (다리 위는 상판 높이로 살짝 올라간다)
const E3_RUN := [Vector3(-26, 0, -34), Vector3(-14, 0, -42), Vector3(-18, 0, -50), Vector3(-4, 0, -54),
	Vector3(-4, 0, -56.5), Vector3(-4, 0.45, -57.5), Vector3(-4, 0.45, -62.5), Vector3(-4, 0, -63.5),
	Vector3(-4, 0, -66), Vector3(10, 0, -70), Vector3(24, 0, -64)]
const E3_SPEED := 2.6
const E3_BRIDGE := Vector3(-4, 0, -60)
## 다리 앞(이쪽 둑)과 끝(건너편 둑)이 경로의 몇 번째 점인지
const E3_BRIDGE_START := 4
const E3_BRIDGE_END := 7
const E10_RUN := [Vector3(30, 0, -26), Vector3(18, 0, -32), Vector3(26, 0, -40), Vector3(12, 0, -46),
	Vector3(12, 0, -47.5), Vector3(12, 0.45, -48.5), Vector3(12, 0.45, -53.5), Vector3(12, 0, -54.5),
	Vector3(12, 0, -58), Vector3(-2, 0, -60), Vector3(-10, 0, -52), Vector3(-18, 0, -64), Vector3(-25, 0, -70)]
const E10_SPEED := 3.4
const E10_BRIDGE := Vector3(12, 0, -51)
const E10_BRIDGE_START := 4
const E10_BRIDGE_END := 7
## 지원형 동료 경로 (E11): 투척 구역 아래에서 성문까지
const E11_PATH := [Vector3(-14, 0, -18), Vector3(-6, 0, -34), Vector3(0, 0, -58.3)]


static func build(index: int, s: Stage) -> void:
	match index:
		0: _e1(s)
		1: _e2(s)
		2: _e3(s)
		3: _e4(s)
		4: _e5(s)
		5: _e6(s)
		6: _e7(s)
		7: _e8(s)
		8: _e9(s)
		9: _e10(s)
		10: _e11(s)
	s.finish_build()


static func _zone(s: Stage, index: int) -> void:
	s.set_zone(Vector3(0, PERCH[index], ZONE_Z[index]), Vector2(3.0, 3.0))


# ---------- 부품 세트 (본편 제작량을 줄이려고 재배치해 쓰는 조각들) ----------

## 목책: 뾰족한 목재 말뚝 한 줄. gate: 가운데 열린 문 폭 (문 너머로 안이 보인다).
static func palisade(st: Structure, c: Vector3, width: float, height := 2.6, gate := 0.0) -> void:
	var n := int(width / 0.35)
	for i in n:
		var x := c.x - width * 0.5 + (i + 0.5) * width / n
		if absf(x - c.x) < gate * 0.5:
			continue
		st.add_block(M.WOOD_THIN, Vector3(x, height * 0.5, c.z), Vector3(width / n, height, 0.3))


## 차양 (지휘관 머리 위를 덮는 지붕). 석재 기둥 4개 + 석재 도리 2개 + 두꺼운 목재 지붕 판자.
## 판자는 모두 양쪽 도리에 걸쳐 있어서, 타면 그 자리에서 없어지고 지휘관 위로 떨어지지 않는다.
## 화염탄 충격으로는 부서지지 않는다 (지붕을 태운 뒤 한 번 더 던져야 한다).
static func shelter(st: Structure, c: Vector3, half := 2.4, height := 2.8) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.STONE, c + Vector3(sx * (half - 0.2), (height - 0.3) * 0.5, sz * (half - 0.2)), Vector3(0.4, height - 0.3, 0.4))
	for sz in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(0, height - 0.15, sz * (half - 0.2)), Vector3(half * 2.0, 0.3, 0.4))
	var n := int(half * 2.0 / 0.6)
	for i in n:
		var x := -half + (i + 0.5) * half * 2.0 / n
		st.add_block(M.WOOD_BEAM, c + Vector3(x, height + 0.06, 0), Vector3(half * 2.0 / n, 0.12, half * 2.0))

## 금 간 석벽: 누렇게 바랜 석재 판을 격자로 쌓는다. 고폭탄으로 부서진다.
static func cracked_wall(st: Structure, c: Vector3, width: float, height: float, thick := 0.5) -> void:
	var cols := int(roundf(width / 1.5))
	var rows := int(roundf(height / 1.0))
	for r in rows:
		for k in cols:
			var x := c.x - width * 0.5 + (k + 0.5) * width / cols
			st.add_block(M.CRACKED, Vector3(x, (r + 0.5) * height / rows, c.z), Vector3(width / cols, height / rows, thick))


## 강철벽: 반듯한 강철 판을 격자로 쌓는다. 무엇으로도 부서지지 않는 가림막.
static func steel_wall(st: Structure, c: Vector3, width: float, height: float, thick := 0.4) -> void:
	var cols := int(roundf(width / 1.5))
	var rows := int(roundf(height / 1.0))
	for r in rows:
		for k in cols:
			var x := c.x - width * 0.5 + (k + 0.5) * width / cols
			st.add_block(M.STEEL, Vector3(x, (r + 0.5) * height / rows, c.z), Vector3(width / cols, height / rows, thick))


## 목재 망루: 하중 목재 다리 4개, 판자 바닥, 난간, 지붕. 지휘관은 바닥(높이 legs+0.3) 위에 선다.
## open_rail: 판자벽 대신 낮은 목재 난간(윗난간·중간 난간·발판막이)과 옆에 기댄 사다리 (본편 망루).
static func watchtower(st: Structure, c: Vector3, legs := 4.0, half := 1.6, open_rail := false) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, c + Vector3(sx * (half - 0.2), legs * 0.5, sz * (half - 0.2)), Vector3(0.4, legs, 0.4))
	# 다리를 잇는 가로대 (불이 옮겨 가는 길)
	for sz in [-1, 1]:
		st.add_block(M.WOOD_BEAM, c + Vector3(0, 1.5, sz * (half - 0.2)), Vector3(half * 2.0 - 0.8, 0.25, 0.25))
	var n := 5
	for i in n:
		var x := -half + (i + 0.5) * half * 2.0 / n
		st.add_block(M.WOOD_THIN, c + Vector3(x, legs + 0.15, 0), Vector3(half * 2.0 / n, 0.3, half * 2.0))
	# 난간 (앞뒤, 옆)
	var rail := 1.3
	if open_rail:
		# 낮은 목재 난간: 윗난간, 중간 난간, 발판막이 (사이로 지휘관이 보인다)
		var floor_y := legs + 0.3
		for spec in [[1.05, 0.12], [0.55, 0.1], [0.12, 0.24]]:
			for sz in [-1, 1]:
				st.add_block(M.WOOD_THIN, c + Vector3(0, floor_y + spec[0], sz * (half - 0.05)), Vector3(half * 2.0 - 0.5, spec[1], 0.1))
			for sx in [-1, 1]:
				st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.05), floor_y + spec[0], 0), Vector3(0.1, spec[1], half * 2.0 - 0.5))
	else:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(0, legs + 0.3 + rail * 0.5, sz * (half - 0.05)), Vector3(half * 2.0, rail, 0.1))
		for sx in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.05), legs + 0.3 + rail * 0.5, 0), Vector3(0.1, rail, half * 2.0 - 0.2))
	# 지붕 기둥과 지붕 (짚)
	var roof_h := legs + 0.3 + 2.4
	# 지붕 기둥은 판자벽 위에서, 열린 난간이면 바닥에서부터 (난간이 기둥에 붙는다)
	var post_from := legs + 0.3 + (0.0 if open_rail else rail)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.15), (post_from + roof_h) * 0.5, sz * (half - 0.15)), Vector3(0.2, roof_h - post_from, 0.2))
	st.add_block(M.STRAW, c + Vector3(0, roof_h + 0.15, 0), Vector3(half * 2.0 + 0.4, 0.3, half * 2.0 + 0.4))
	_ladder(st, c, legs, half)


## 망루 오른쪽에 기댄 나무 사다리 (장식: 충돌·판정 없음). 바닥 판자에 붙어 있어 망루가 무너지면 같이 넘어간다.
## 석재·발리스타 망대의 바닥(host) 옆에 기댄 사다리. side: +1이면 +x 쪽, -1이면 -x 쪽. 장식이라 충돌·판정 없음.
static func deck_ladder(host: Block, side: float) -> void:
	var top := Vector3(host.position.x + side * (host.size.x * 0.5 - 0.1), host.position.y + host.size.y * 0.5 - 0.05, host.position.z)
	var foot := Vector3(top.x + side * top.y * 0.18, 0.0, top.z)
	var ladder := Node3D.new()
	host.add_child(ladder)
	var along := top - foot
	var placed := Transform3D(Basis(Vector3.BACK, -atan2(along.x, along.y)), (foot + top) * 0.5)
	ladder.transform = host.transform.affine_inverse() * placed
	var length := along.length()
	var wood := Models.mat(Color(0.5, 0.34, 0.2))
	for sz in [-1, 1]:
		Models.box(ladder, Vector3(0.09, length, 0.09), Vector3(0, 0, sz * 0.34), wood)
	var rungs := int(length / 0.4)
	for i in rungs:
		Models.box(ladder, Vector3(0.06, 0.06, 0.76), Vector3(0, -length * 0.5 + (i + 0.6) * length / rungs, 0), wood)


static func _ladder(st: Structure, c: Vector3, legs: float, half: float) -> void:
	var k: float = st.stage.build_scale if st.stage else 1.0
	var plank: Block = null
	for b in st.blocks:
		if b.mat == M.WOOD_THIN and absf(b.size.y - 0.3 * k) < 0.01 and (plank == null or b.position.x > plank.position.x):
			plank = b
	if plank == null:
		return
	var foot := Vector3(c.x + (half + 0.8) * k, 0.0, c.z)
	var top := Vector3(c.x + (half + 0.05) * k, (legs + 1.0) * k, c.z)
	var ladder := Node3D.new()
	plank.add_child(ladder)
	# 진지 좌표로 세운 뒤 판자 기준으로 바꾼다 (짓는 동안은 아직 장면에 안 들어가 있을 수 있다. 구조물은 원점에 있다)
	var along := top - foot
	var placed := Transform3D(Basis(Vector3.BACK, -atan2(along.x, along.y)), (foot + top) * 0.5)
	ladder.transform = plank.transform.affine_inverse() * placed
	var length := along.length()
	var wood := Models.mat(Color(0.5, 0.34, 0.2))
	for sz in [-1, 1]:
		Models.box(ladder, Vector3(0.09, length, 0.09), Vector3(0, 0, sz * 0.28 * k), wood)
	var rungs := int(length / 0.4)
	for i in rungs:
		Models.box(ladder, Vector3(0.06, 0.06, 0.62 * k), Vector3(0, -length * 0.5 + (i + 0.6) * length / rungs, 0), wood)


## 창문 달린 벽 (x축 방향). heights: 아래부터 줄 높이 [아래, 창문 줄, 위], windows: 창문을 낼 칸 번호.
## 창문으로 안이 보이지만, 창으로 폭탄을 넣기는 어렵다.
static func window_wall(st: Structure, mat: int, c: Vector3, width: float, heights: Array, cols: int, windows: Array, thick := 0.4) -> void:
	var y := 0.0
	for r in heights.size():
		var h: float = heights[r]
		for k in cols:
			if r == 1 and k in windows:
				continue
			var x := c.x - width * 0.5 + (k + 0.5) * width / cols
			st.add_block(mat, Vector3(x, c.y + y + h * 0.5, c.z), Vector3(width / cols, h, thick))
		y += h


## 마구간: 판자 앞벽(창문 둘)과 옆벽, 짚 지붕. 뒤는 트여 있어 그 뒤로 지나가는 사람이 창문으로만 언뜻 보인다.
static func stable(st: Structure, c: Vector3, width := 7.0, depth := 3.6) -> void:
	window_wall(st, M.WOOD_THIN, c + Vector3(0, 0, depth * 0.5 - 0.1), width, [1.0, 0.7, 0.8], 7, [1, 5], 0.2)
	for sx in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(sx * (width * 0.5 - 0.1), 1.25, -0.1), Vector3(0.2, 2.5, depth - 0.2))
	st.add_block(M.STRAW, c + Vector3(0, 2.65, -0.1), Vector3(width + 0.4, 0.3, depth))


## 개울 위 나무다리 (z 방향). 상판 판자 5장은 양끝 둑의 말뚝에만 얹혀 있어, 하나만 타거나 끊겨도 건널 수 없다.
## 상판 블록들을 돌려준다.
static func bridge(s: Stage, st: Structure, c: Vector3, length := 5.0, width := 2.4) -> Array:
	# 개울 (충돌 없는 물빛 띠)
	s.add_prop(c + Vector3(0, 0.02, 0), Vector3(20.0, 0.04, 4.0), Color(0.25, 0.42, 0.55), false)
	var deck: Array = []
	var n := 5
	for i in n:
		var z := c.z - length * 0.5 + (i + 0.5) * length / n
		deck.append(st.add_block(M.WOOD_THIN, Vector3(c.x, 0.35, z), Vector3(width, 0.2, length / n)))
	for sz in [-1, 1]:
		for sx in [-1, 1]:
			st.add_block(M.WOOD_BEAM, Vector3(c.x + sx * (width * 0.5 - 0.2), 0.125, c.z + sz * (length * 0.5 - 0.5)), Vector3(0.3, 0.25, 0.3))
	# 난간
	for sx in [-1, 1]:
		st.add_block(M.WOOD_THIN, Vector3(c.x + sx * (width * 0.5 - 0.05), 0.75, c.z), Vector3(0.1, 0.6, length))
	return deck


## 전령의 목적지 나팔탑 (지형: 부서지지 않는다).
static func horn_tower(s: Stage, c: Vector3) -> void:
	s.add_prop(c + Vector3(0, 2.5, 0), Vector3(2.2, 5.0, 2.2), Color(0.7, 0.7, 0.72))
	s.add_prop(c + Vector3(0, 5.3, 0), Vector3(2.8, 0.6, 2.8), Color(0.5, 0.52, 0.58))
	var flag := Models.flag()
	flag.position = c + Vector3(0.8, 5.6, 0.8)
	s.add_child(flag)


## 경로 점 index까지의 거리.
static func _length_to(pts: Array, index: int) -> float:
	var d := 0.0
	for i in range(1, index + 1):
		d += (pts[i - 1] as Vector3).distance_to(pts[i])
	return d


## 목재 초소 (지휘관이 안에 있는 오두막). 벽은 판자, 지붕은 짚. 앞벽 가운데에 창문.
static func hut(st: Structure, c: Vector3, half := 2.0, height := 2.6, wall := M.WOOD_THIN) -> void:
	for sz in [-1, 1]:
		var n := 5
		for i in n:
			var x := -half + (i + 0.5) * half * 2.0 / n
			var w := half * 2.0 / n
			if sz == 1 and i == n / 2:
				st.add_block(wall, c + Vector3(x, 0.55, sz * (half - 0.1)), Vector3(w, 1.1, 0.2))
				st.add_block(wall, c + Vector3(x, (1.8 + height) * 0.5, sz * (half - 0.1)), Vector3(w, height - 1.8, 0.2))
				continue
			st.add_block(wall, c + Vector3(x, height * 0.5, sz * (half - 0.1)), Vector3(w, height, 0.2))
	for sx in [-1, 1]:
		st.add_block(wall, c + Vector3(sx * (half - 0.1), height * 0.5, 0), Vector3(0.2, height, half * 2.0 - 0.4))
	st.add_block(M.STRAW, c + Vector3(0, height + 0.15, 0), Vector3(half * 2.0, 0.3, half * 2.0))


# ---------- 스테이지 ----------

## E1 직격형: 목책(가운데 문이 열려 안이 보임)과 목재 차양 아래의 지휘관. 차양을 태우고 높이 띄워 직격한다.
static func _e1(s: Stage) -> void:
	s.begin("E1", "E1 · 목책 진지")
	_zone(s, 0)
	s.add_ammo(FIRE, 5)
	var c: Vector3 = COMMANDER[0]
	var st := s.add_structure()
	palisade(st, c + Vector3(0, 0, 4.2), 7.0, 2.6, 1.6)
	shelter(st, c)
	s.add_commander(c)
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## E2 연소형: 목재 망루 위의 지휘관. 다리에 불을 붙이고 번지기를 기다린다.
static func _e2(s: Stage) -> void:
	s.begin("E2", "E2 · 목재 망루")
	_zone(s, 1)
	s.add_ammo(FIRE, 5)
	var c: Vector3 = COMMANDER[1]
	watchtower(s.add_structure(), Vector3(c.x, 0, c.z))
	s.add_commander(c, 180.0, Vector3(0.9, 0, 0.6))
	# 머리 위가 지붕으로 막혀 있어 직격은 어렵다. 다리를 태워 무너뜨린다
	s.add_guard(Vector3(-4, 0, c.z + 3), 180.0)


## E3 전령형: 지원을 부르러 나팔탑으로 달리는 전령을 멈춘다 (지휘관 없음).
## 전령을 앞질러 맞히거나, 건너야 할 개울의 나무다리를 먼저 태운다. 첫 전령 스테이지라 느리고 완만하게 꺾인다.
static func _e3(s: Stage) -> void:
	s.begin("E3", "E3 · 다리를 건너는 전령", false, Stage.Goal.MESSENGER)
	_zone(s, 2)
	s.add_ammo(FIRE, 6)
	s.add_messenger(E3_RUN, E3_SPEED)
	s.add_bridge(bridge(s, s.add_structure(), E3_BRIDGE), _length_to(E3_RUN, E3_BRIDGE_START), _length_to(E3_RUN, E3_BRIDGE_END))
	horn_tower(s, E3_RUN[E3_RUN.size() - 1] + Vector3(3, 0, 2))


## E4 직격형: 강철 지붕 초소, 앞은 창문 난 금 간 석벽. 지휘관이 창으로 보인다. 고폭탄으로 벽을 날리고 직격한다 (강철 지붕이 높은 포물선을 막는다).
static func _e4(s: Stage) -> void:
	s.begin("E4", "E4 · 석벽 뒤 지휘관")
	_zone(s, 3)
	s.add_ammo(HE, 5)
	var c: Vector3 = COMMANDER[3]
	var st := s.add_structure()
	# 석벽은 지붕을 받치지 않는다 (벽을 날려도 지붕은 그대로라 한 번 더 던져야 한다)
	window_wall(st, M.CRACKED, c + Vector3(0, 0, 2.65), 6.0, [1.0, 0.8, 1.0], 5, [2], 0.5)
	# 강철 지붕: 기둥 넷에 얹힌다. 높은 포물선으로 벽 너머를 노리는 것을 막는다
	for sx in [-1, 1]:
		for z in [1.9, -2.2]:
			st.add_block(M.STEEL, c + Vector3(sx * 2.6, 1.5, z), Vector3(0.5, 3.0, 0.5))
	st.add_block(M.STEEL, c + Vector3(0, 3.15, 0.0), Vector3(6.0, 0.3, 5.0))
	s.add_commander(c, 180.0, Vector3(1.2, 0, -1.0))


## E5 직격형: 금 간 석벽 + 안쪽 목재 초소. 고폭탄으로 벽, 화염탄으로 초소.
static func _e5(s: Stage) -> void:
	s.begin("E5", "E5 · 석벽과 목재 초소")
	_zone(s, 4)
	s.add_ammo(HE, 2)
	s.add_ammo(FIRE, 3)
	var c: Vector3 = COMMANDER[4]
	var st := s.add_structure()
	# 마당을 두른 석벽 (눈높이의 좁은 창 너머로 막사가 보인다)
	window_wall(st, M.CRACKED, c + Vector3(0, 0, 4.5), 9.0, [2.0, 0.5, 1.5], 7, [3], 0.5)
	hut(st, c, 2.0, 2.6)
	s.add_commander(c, 180.0, Vector3(3.0, 0, -0.5))


## E6 간접형: 절벽 밑 동굴 속 지휘관. 머리 위 무거운 석재 덮개가 앞쪽 받침 둘에만 얹혀 있다.
## 왼쪽은 금 간 석재 기둥(고폭탄), 오른쪽은 나무 버팀목(화염탄). 둘 다 없애면 덮개가 떨어져 깔린다.
## 덮개는 반듯한 석재라 직접 맞혀도 안 부서지고, 바위턱이 정면 직격을 막는다.
static func _e6(s: Stage) -> void:
	s.begin("E6", "E6 · 절벽 밑 동굴")
	_zone(s, 5)
	s.add_ammo(HE, 4)
	s.add_ammo(FIRE, 2)
	var c: Vector3 = COMMANDER[5]
	# 뒤쪽 절벽 (블록이 아닌 지형). 덮개 뒤끝이 절벽에 닿아 있다
	s.add_prop(c + Vector3(0, 6, -4.5), Vector3(14, 12, 4), Color(0.33, 0.31, 0.3))
	s.add_prop(c + Vector3(0, 13, -1.5), Vector3(14, 2, 4), Color(0.28, 0.27, 0.26))
	var st := s.add_structure()
	# 받침 둘은 멀리 떨어져 있어 가운데에 한 발로 둘 다 끊을 수 없다
	st.add_block(M.CRACKED, c + Vector3(-3.2, 1.4, 1.6), Vector3(0.9, 2.8, 0.9))
	st.add_block(M.WOOD_BEAM, c + Vector3(3.2, 1.4, 1.6), Vector3(0.55, 2.8, 0.55))
	# 덮개: 받침 둘 중 하나만 남아도 버티고, 둘 다 잃으면 떨어진다
	var cover := st.add_block(M.STONE, c + Vector3(0, 3.2, -0.2), Vector3(7.4, 0.8, 4.6))
	cover.support_ratio = 0.5
	# 덮개 위 바위 (무게가 실린 게 보이게. 덮개와 함께 떨어진다)
	st.add_block(M.STONE, c + Vector3(-0.8, 3.95, -0.8), Vector3(1.6, 0.7, 1.4))
	st.add_block(M.STONE, c + Vector3(1.4, 3.85, 0.2), Vector3(1.1, 0.5, 1.0))
	# 동굴 입구의 바위턱 (지형이라 부서지지 않는다. 정면 직격을 막는다)
	s.add_prop(c + Vector3(0, 0.8, 2.8), Vector3(7.0, 1.6, 0.8), Color(0.3, 0.28, 0.27))
	s.add_commander(c + Vector3(0, 0, -0.8), 180.0, Vector3(1.0, 0, -0.6))


## E7 연소형: 석재 건물 안의 지휘관, 내부 연료 배관, 바깥에 짚. 젖은 홈통에 기름을 붓고 점화한다.
static func _e7(s: Stage) -> void:
	s.begin("E7", "E7 · 연료 창고")
	_zone(s, 6)
	s.add_ammo(OIL, 3)
	s.add_ammo(FIRE, 3)
	var c: Vector3 = COMMANDER[6]
	var st := s.add_structure()
	# 석재 건물 (6 x 6, 높이 3, 석재 지붕). 앞벽 가운데 아래에 홈통이 지나는 구멍
	var half := 3.0
	for x in [-2.25, 2.25]:
		st.add_block(M.STONE, c + Vector3(x, 1.5, half - 0.3), Vector3(1.5, 3.0, 0.6))
	# 앞벽 가운데 위쪽: 창문 (1.0 x 0.7)
	st.add_block(M.STONE, c + Vector3(0, 1.25, half - 0.3), Vector3(3.0, 0.5, 0.6))
	for x in [-1.0, 1.0]:
		st.add_block(M.STONE, c + Vector3(x, 1.85, half - 0.3), Vector3(1.0, 0.7, 0.6))
	st.add_block(M.STONE, c + Vector3(0, 2.6, half - 0.3), Vector3(3.0, 0.8, 0.6))
	st.add_block(M.STONE, c + Vector3(-0.9, 0.5, half - 0.3), Vector3(1.2, 1.0, 0.6))
	st.add_block(M.STONE, c + Vector3(1.2, 0.5, half - 0.3), Vector3(0.6, 1.0, 0.6))
	st.add_block(M.STONE, c + Vector3(0, 1.5, -half + 0.3), Vector3(6.0, 3.0, 0.6))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * (half - 0.3), 1.5, 0), Vector3(0.6, 3.0, half * 2.0 - 1.2))
	st.add_block(M.STONE, c + Vector3(0, 3.2, 0), Vector3(6.0, 0.4, 6.0))
	# 바깥의 짚 더미 → 젖은 홈통 (밖 4칸 + 벽 구멍 1칸) → 연료 배관 (안쪽, 지휘관 곁까지).
	# 젖은 홈통은 기름을 묻혀야 탄다. 배관은 석재 벽 안쪽이라 바깥 불웅덩이가 직접 닿지 않는다
	st.add_block(M.STRAW, c + Vector3(0.3, 0.5, half + 4.6), Vector3(1.6, 1.0, 1.2))
	for i in 5:
		st.add_block(M.WOOD_WET, c + Vector3(0.3, 0.15, half + 3.5 - i * 1.0), Vector3(0.4, 0.3, 1.0))
	for i in 4:
		st.add_block(M.FUEL, c + Vector3(0.3, 0.15, half - 1.4 - i * 0.8), Vector3(0.3, 0.3, 0.8))
	s.add_commander(c + Vector3(-1.0, 0, -1.2), 180.0, Vector3(-1.2, 0, -0.4))


## E8 밤 직격형: 횃불 몇 개만 켜진 진지. 조명탄으로 보고 맞힌다.
static func _e8(s: Stage) -> void:
	s.begin("E8", "E8 · 밤의 진지", true)
	_zone(s, 7)
	s.add_ammo(FIRE, 5)
	s.add_ammo(FLARE, 3)
	var c: Vector3 = COMMANDER[7]
	var st := s.add_structure()
	palisade(st, c + Vector3(0, 0, 4.4), 8.0, 2.6, 1.6)
	shelter(st, c)
	s.add_commander(c)
	# 중요한 곳은 적의 불빛 안에, 나머지는 실루엣으로
	s.add_torch(c + Vector3(2.8, 0, 1.5))
	s.add_torch(c + Vector3(-9, 0, 8))
	s.add_torch(c + Vector3(10, 0, -6))
	s.add_guard(c + Vector3(-9, 0, 7), 180.0)
	s.add_guard(c + Vector3(9.5, 0, -5), 180.0)


## E9 원거리: 고지대에서 아주 먼 지휘관 (거의 최대 사거리). 거리를 격해 맞히는 쾌감 확인용.
## 이후 본편에서는 이 정도 거리를 뒤 스테이지의 난이도 요소로 쓴다.
static func _e9(s: Stage) -> void:
	s.begin("E9", "E9 · 먼 진지")
	_zone(s, 8)
	# 멀리 나는 가벼운 폭탄으로만 닿는다 (묵직한 화염 항아리는 못 닿는다)
	s.add_ammo(HE, 5)
	var c: Vector3 = COMMANDER[8]
	shelter(s.add_structure(), c)
	s.add_commander(c)

## E10 종합 (전령형 응용): 더 빠르고 많이 꺾이는 전령. 마구간 둘이 길을 가려 창문으로만 언뜻 보인다.
## 개울 위 나무다리를 끊거나(화염·고폭) 마구간 사이로 나온 전령을 맞힌다.
static func _e10(s: Stage) -> void:
	s.begin("E10", "E10 · 마구간 사이의 전령", false, Stage.Goal.MESSENGER)
	_zone(s, 9)
	s.add_ammo(HE, 3)
	s.add_ammo(FIRE, 4)
	stable(s.add_structure(), Vector3(15.5, 0, -36.8))
	stable(s.add_structure(), Vector3(-9, 0, -48))
	s.add_messenger(E10_RUN, E10_SPEED)
	s.add_bridge(bridge(s, s.add_structure(), E10_BRIDGE), _length_to(E10_RUN, E10_BRIDGE_START), _length_to(E10_RUN, E10_BRIDGE_END))
	horn_tower(s, E10_RUN[E10_RUN.size() - 1] + Vector3(-3, 0, -2))


## E11 지원형: 폭발통을 진 동료 고블린이 성문까지 걷는다. 방패병, 나무 바리케이드, 금 간 석재 울타리를 치워 길을 연다.
## 동료가 지나갈 가운데 폭만 트이면 된다 (양 끝 조각이 남아도 지나간다).
## 성문 앞에 닿으면 화염탄으로 폭발통을 터뜨린다. 지휘관은 성문 위에 서 있다.
static func _e11(s: Stage) -> void:
	s.begin("E11", "E11 · 성문 앞 지원")
	_zone(s, 10)
	s.add_ammo(HE, 3)
	s.add_ammo(FIRE, 3)
	var gate := Vector3(0, 0, -60)
	var st := s.add_structure()
	# 성문은 동료의 폭발통으로만 부서진다 (플레이어의 투척과 떨어지는 잔해는 통하지 않는다)
	st.player_proof = true
	# 성문: 흰 석재 기둥과 성벽(무엇으로도 안 부서짐) + 강철 문짝 + 문짝 위 강철 보행로와 초소 (지휘관이 그 안에 선다).
	# 폭발통이 터지면 강철 문짝과 보행로·초소가 통째로 날아가고 흰 석재 기둥만 남는다
	for sx in [-1, 1]:
		st.add_block(M.STONE, gate + Vector3(sx * 2.5, 2.0, 0), Vector3(1.4, 4.0, 1.6))
		for k in 2:
			st.add_block(M.STONE, gate + Vector3(sx * (4.0 + k * 1.6), 2.0, 0), Vector3(1.6, 4.0, 1.6))
		# 기둥 위 석재 보행로 (양쪽)
		st.add_block(M.STONE, gate + Vector3(sx * 4.4, 4.15, 0), Vector3(4.8, 0.3, 1.6))
	st.add_block(M.STEEL, gate + Vector3(0, 2.0, 0.3), Vector3(3.6, 4.0, 0.3))
	# 가운데 강철 보행로 (문짝 위에만 얹힌다)
	st.add_block(M.STEEL, gate + Vector3(0, 4.15, 0), Vector3(3.6, 0.3, 1.6))
	# 보행로 위 강철 초소: 앞벽 + 양옆 벽 + 지붕 (뒤는 트임). 지휘관을 직접 맞힐 수 없다
	st.add_block(M.STEEL, gate + Vector3(0, 5.4, 0.65), Vector3(2.7, 2.2, 0.3))
	for sx in [-1, 1]:
		st.add_block(M.STEEL, gate + Vector3(sx * 1.5, 5.4, 0), Vector3(0.3, 2.2, 1.6))
	st.add_block(M.STEEL, gate + Vector3(0, 6.65, 0), Vector3(3.3, 0.3, 1.6))
	var pts: Array = E11_PATH
	# 길 위의 장애물: 방패병 둘 → 목재 바리케이드 → 금 간 석재 울타리
	var g1 := s.add_guard(_along(pts, 12.0) + Vector3(-0.5, 0, 0), 20.0, true)
	var g2 := s.add_guard(_along(pts, 12.0) + Vector3(0.6, 0, 0), 20.0, true)
	var barricade := s.add_structure()
	var bp := _along(pts, 22.0)
	for k in 4:
		barricade.add_block(M.WOOD_THIN, bp + Vector3(-1.5 + k * 1.0, 0.6, 0), Vector3(1.0, 1.2, 0.3))
	barricade.add_block(M.WOOD_THIN, bp + Vector3(0, 1.35, 0), Vector3(4.0, 0.3, 0.3))
	var fence := s.add_structure()
	var fp := _along(pts, 32.0)
	for k in 3:
		for r in 2:
			fence.add_block(M.CRACKED, fp + Vector3(-1.0 + k * 1.0, 0.45 + r * 0.9, 0), Vector3(1.0, 0.9, 0.4))
	var obstacles := [
		{"distance": 12.0, "cleared": func(): return g1.dead and g2.dead},
		{"distance": 22.0, "cleared": func(): return _path_open(barricade, pts, 22.0)},
		{"distance": 32.0, "cleared": func(): return _path_open(fence, pts, 32.0)},
	]
	s.add_ally(pts, 1.8, obstacles)
	s.add_commander(Vector3(0, 4.3, -60.2), 180.0, Vector3(2.2, 0, 0))


## 경로를 따라 거리 d인 지점.
static func _along(pts: Array, d: float) -> Vector3:
	var left := d
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg := a.distance_to(b)
		if left <= seg:
			return a.lerp(b, left / seg)
		left -= seg
	return pts[pts.size() - 1]


## 동료가 지나갈 폭의 절반
const HALF_PASS := 0.45


## 경로 거리 d 지점에서 동료가 지나갈 폭에 서 있는 블록이 없는지 (길이 트였는지).
## 무너진 잔해는 넘어간다. 양 끝 조각만 남았으면 트인 것으로 본다.
static func _path_open(st: Structure, pts: Array, d: float) -> bool:
	var center := _along(pts, d)
	var ahead := _along(pts, d + 0.5) - center
	ahead.y = 0.0
	var side := ahead.normalized().cross(Vector3.UP)
	for b in st.blocks:
		if b.fallen or b.burnt:
			continue
		var lateral := absf((b.global_position - center).dot(side))
		var half := (absf(side.x) * b.size.x + absf(side.z) * b.size.z) * 0.5
		if lateral - half < HALF_PASS:
			return false
	return true
