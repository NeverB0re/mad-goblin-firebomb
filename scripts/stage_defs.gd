class_name StageDefs
extends RefCounted
## 확장 테스트 스테이지 E1~E11 (확장 기획서 9장). 승리 조건은 모두 "지휘관을 쓰러뜨림".
## 플레이어(미친 고블린)는 투척 구역 앞쪽 끝에서 -Z 방향 아래쪽 인간 진지를 내려다본다.
## 인간 시설은 반듯하고 대칭인 규격품, 빨강은 깃발에만 쓴다.
## 각 스테이지는 "설계상 최소 투척 수 + 보정 여유 2~3발"로 탄을 준다.

const FIRE := preload("res://ammo/fire.tres")
const HE := preload("res://ammo/he.tres")
const OIL := preload("res://ammo/oil.tres")
const FLARE := preload("res://ammo/flare.tres")
const M := Block.Mat

const COUNT := 11
const NAMES := ["E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11"]

## 스테이지별 투척 구역 높이 (중간 높이도 섞는다). E9는 두 층 중 선택
const PERCH := [25.0, 14.0, 25.0, 20.0, 18.0, 25.0, 15.0, 22.0, 12.0, 20.0, 22.0]
const E9_FLOORS := [12.0, 22.0]
## 지휘관 위치
const COMMANDER := [
	Vector3(0, 0, -45), Vector3(0, 4.3, -40), Vector3(-6, 0, -58), Vector3(0, 0, -48), Vector3(0, 0, -52),
	Vector3(0, 0, -57), Vector3(0, 0, -44), Vector3(0, 0, -50), Vector3(0, 0, -106), Vector3(0, 0, -60), Vector3(0, 4.3, -62),
]
## 전령 경로 (E3, E10)
const E3_RUN := [Vector3(-26, 0, -40), Vector3(30, 0, -74)]
const E10_RUN := [Vector3(26, 0, -44), Vector3(-30, 0, -82)]
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
	s.set_zone(Vector3(0, PERCH[index], 0), Vector2(3.0, 3.0))


# ---------- 부품 세트 (본편 제작량을 줄이려고 재배치해 쓰는 조각들) ----------

## 목책: 뾰족한 목재 말뚝 한 줄.
static func palisade(st: Structure, c: Vector3, width: float, height := 2.6) -> void:
	var n := int(width / 0.35)
	for i in n:
		var x := c.x - width * 0.5 + (i + 0.5) * width / n
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

## 강철벽: 반듯한 강철 판을 격자로 쌓는다.
static func steel_wall(st: Structure, c: Vector3, width: float, height: float, thick := 0.4) -> void:
	var cols := int(roundf(width / 1.5))
	var rows := int(roundf(height / 1.0))
	for r in rows:
		for k in cols:
			var x := c.x - width * 0.5 + (k + 0.5) * width / cols
			st.add_block(M.STEEL, Vector3(x, (r + 0.5) * height / rows, c.z), Vector3(width / cols, height / rows, thick))


## 목재 망루: 하중 목재 다리 4개, 판자 바닥, 난간, 지붕. 지휘관은 바닥(높이 legs+0.3) 위에 선다.
static func watchtower(st: Structure, c: Vector3, legs := 4.0, half := 1.6) -> void:
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
	for sz in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(0, legs + 0.3 + rail * 0.5, sz * (half - 0.05)), Vector3(half * 2.0, rail, 0.1))
	for sx in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.05), legs + 0.3 + rail * 0.5, 0), Vector3(0.1, rail, half * 2.0 - 0.2))
	# 지붕 기둥과 지붕 (짚)
	var roof_h := legs + 0.3 + 2.4
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.15), legs + 0.3 + rail + (roof_h - legs - 0.3 - rail) * 0.5, sz * (half - 0.15)), Vector3(0.2, roof_h - legs - 0.3 - rail, 0.2))
	st.add_block(M.STRAW, c + Vector3(0, roof_h + 0.15, 0), Vector3(half * 2.0 + 0.4, 0.3, half * 2.0 + 0.4))


## 나무 봉화대: 다리 4개 + 짚 바구니. 다 타면 전령이 도착해도 지원을 부르지 못한다.
static func beacon(st: Structure, c: Vector3) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(sx * 0.6, 1.5, sz * 0.6), Vector3(0.25, 3.0, 0.25))
	st.add_block(M.WOOD_THIN, c + Vector3(0, 3.1, 0), Vector3(1.6, 0.2, 1.6))
	st.add_block(M.STRAW, c + Vector3(0, 3.6, 0), Vector3(1.2, 0.8, 1.2))


## 목재 초소 (지휘관이 안에 있는 오두막). 벽은 판자, 지붕은 짚.
static func hut(st: Structure, c: Vector3, half := 2.0, height := 2.6, wall := M.WOOD_THIN) -> void:
	for sz in [-1, 1]:
		var n := 5
		for i in n:
			var x := -half + (i + 0.5) * half * 2.0 / n
			st.add_block(wall, c + Vector3(x, height * 0.5, sz * (half - 0.1)), Vector3(half * 2.0 / n, height, 0.2))
	for sx in [-1, 1]:
		st.add_block(wall, c + Vector3(sx * (half - 0.1), height * 0.5, 0), Vector3(0.2, height, half * 2.0 - 0.4))
	st.add_block(M.STRAW, c + Vector3(0, height + 0.15, 0), Vector3(half * 2.0, 0.3, half * 2.0))


# ---------- 스테이지 ----------

## E1 직격형: 목책과 목재 차양 뒤의 지휘관, 고지대. 차양을 태우고 직격한다.
static func _e1(s: Stage) -> void:
	s.begin("E1", "E1 · 목책 진지", "깃발 옆 지휘관을 쓰러뜨려라 (목재 차양이 머리 위를 가린다)")
	_zone(s, 0)
	s.add_ammo(FIRE, 5)
	var c: Vector3 = COMMANDER[0]
	var st := s.add_structure()
	palisade(st, c + Vector3(0, 0, 4.2), 7.0)
	shelter(st, c)
	s.add_commander(c)
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## E2 연소형: 목재 망루 위의 지휘관. 다리에 불을 붙이고 번지기를 기다린다.
static func _e2(s: Stage) -> void:
	s.begin("E2", "E2 · 목재 망루", "망루를 태워 지휘관을 쓰러뜨려라 (불이 다가갈수록 지휘관이 허둥댄다)")
	_zone(s, 1)
	s.add_ammo(FIRE, 5)
	var c: Vector3 = COMMANDER[1]
	watchtower(s.add_structure(), Vector3(c.x, 0, c.z))
	s.add_commander(c, 180.0, Vector3(0.9, 0, 0.6))
	# 머리 위가 지붕으로 막혀 있어 직격은 어렵다. 다리를 태워 무너뜨린다
	s.add_guard(Vector3(-4, 0, c.z + 3), 180.0)


## E3 전령형: 옆으로 달리는 전령과 끝의 나무 봉화대. 전령을 맞히거나 봉화대를 먼저 태운다.
static func _e3(s: Stage) -> void:
	s.begin("E3", "E3 · 봉화대로 달리는 전령", "지휘관을 쓰러뜨려라. 전령이 봉화대에 닿으면 실패 (첫 투척과 함께 달린다)")
	_zone(s, 2)
	s.add_ammo(FIRE, 6)
	var c: Vector3 = COMMANDER[2]
	shelter(s.add_structure(), c)
	s.add_commander(c)
	s.add_messenger(E3_RUN[0], E3_RUN[1], 3.6)
	s.beacon = s.add_structure()
	beacon(s.beacon, E3_RUN[1] + Vector3(2.0, 0, -1.5))


## E4 직격형: 강철벽 뒤 지휘관. 고폭탄으로 벽을 날리고 직격한다 (강철 지붕이 높은 포물선을 막는다).
static func _e4(s: Stage) -> void:
	s.begin("E4", "E4 · 강철벽", "고폭탄으로 강철벽을 날리고 지휘관을 쓰러뜨려라")
	_zone(s, 3)
	s.add_ammo(HE, 5)
	var c: Vector3 = COMMANDER[3]
	var st := s.add_structure()
	# 강철벽은 지붕을 받치지 않는다 (벽을 날려도 지붕은 그대로라 한 번 더 던져야 한다)
	steel_wall(st, c + Vector3(0, 0, 2.6), 6.0, 2.8)
	# 강철 지붕: 기둥 넷에 얹힌다. 높은 포물선으로 벽 너머를 노리는 것을 막는다
	for sx in [-1, 1]:
		for z in [1.9, -2.2]:
			st.add_block(M.STEEL, c + Vector3(sx * 2.6, 1.5, z), Vector3(0.5, 3.0, 0.5))
	st.add_block(M.STEEL, c + Vector3(0, 3.15, 0.0), Vector3(6.0, 0.3, 5.0))
	s.add_commander(c, 180.0, Vector3(1.2, 0, -1.0))


## E5 직격형: 강철벽 + 안쪽 목재 초소. 고폭탄으로 벽, 화염탄으로 초소 (반대로 하면 불이 피식 꺼진다).
static func _e5(s: Stage) -> void:
	s.begin("E5", "E5 · 강철벽과 목재 초소", "벽을 먼저 날릴까, 초소를 먼저 태울까 (1~2 키로 탄종 교체)")
	_zone(s, 4)
	s.add_ammo(HE, 2)
	s.add_ammo(FIRE, 3)
	var c: Vector3 = COMMANDER[4]
	var st := s.add_structure()
	steel_wall(st, c + Vector3(0, 0, 4.5), 9.0, 4.0)
	hut(st, c, 2.0, 2.6)
	s.add_commander(c, 180.0, Vector3(3.0, 0, -0.5))


## E6 간접형: 절벽 밑 동굴 속 지휘관, 위에 석재 덮개. 덮개를 받치는 기둥(석재)과 버팀목(목재)을 친다.
static func _e6(s: Stage) -> void:
	s.begin("E6", "E6 · 절벽 밑 동굴", "직격은 안 된다. 머리 위 석재 덮개를 떨어뜨려라")
	_zone(s, 5)
	s.add_ammo(HE, 4)
	s.add_ammo(FIRE, 2)
	var c: Vector3 = COMMANDER[5]
	# 뒤쪽 절벽 (블록이 아닌 지형)
	s.add_prop(c + Vector3(0, 6, -4.5), Vector3(14, 12, 4), Color(0.33, 0.31, 0.3))
	s.add_prop(c + Vector3(0, 13, -1.5), Vector3(14, 2, 4), Color(0.28, 0.27, 0.26))
	var st := s.add_structure()
	# 덮개를 받치는 셋: 왼쪽 석재 기둥, 오른쪽 목재 버팀목, 뒤쪽 석재 벽 (둘을 잃으면 떨어진다)
	st.add_block(M.STONE, c + Vector3(-2.4, 1.4, 1.6), Vector3(0.8, 2.8, 0.8))
	st.add_block(M.WOOD_BEAM, c + Vector3(2.4, 1.4, 1.6), Vector3(0.5, 2.8, 0.5))
	st.add_block(M.STONE, c + Vector3(0, 1.4, -2.2), Vector3(5.6, 2.8, 0.8))
	# 덮개 (받침 셋 중 둘을 잃으면 떨어진다: 석재 기본 받침 비율 0.6)
	st.add_block(M.STONE, c + Vector3(0, 3.2, -0.2), Vector3(6.0, 0.8, 4.6))
	# 동굴 입구의 바위턱 (지형이라 부서지지 않는다. 정면 직격을 막는다)
	s.add_prop(c + Vector3(0, 0.8, 2.8), Vector3(7.0, 1.6, 0.8), Color(0.3, 0.28, 0.27))
	s.add_commander(c + Vector3(0, 0, -0.8), 180.0, Vector3(1.0, 0, -0.6))


## E7 연소형: 석재 건물 안의 지휘관, 내부 연료 배관, 바깥에 짚. 젖은 홈통에 기름을 붓고 점화한다.
static func _e7(s: Stage) -> void:
	s.begin("E7", "E7 · 연료 창고", "젖은 홈통에 기름을 부어 배관까지 불길을 이어라 (1~2 키로 탄종 교체)")
	_zone(s, 6)
	s.add_ammo(OIL, 3)
	s.add_ammo(FIRE, 3)
	var c: Vector3 = COMMANDER[6]
	var st := s.add_structure()
	# 석재 건물 (6 x 6, 높이 3, 석재 지붕). 앞벽 가운데 아래에 홈통이 지나는 구멍
	var half := 3.0
	for x in [-2.25, 2.25]:
		st.add_block(M.STONE, c + Vector3(x, 1.5, half - 0.3), Vector3(1.5, 3.0, 0.6))
	st.add_block(M.STONE, c + Vector3(0, 2.0, half - 0.3), Vector3(3.0, 2.0, 0.6))
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
	s.begin("E8", "E8 · 밤의 진지", "조명탄으로 진지를 밝히고 지휘관을 쓰러뜨려라 (1~2 키로 탄종 교체)", true)
	_zone(s, 7)
	s.add_ammo(FIRE, 5)
	s.add_ammo(FLARE, 3)
	var c: Vector3 = COMMANDER[7]
	var st := s.add_structure()
	palisade(st, c + Vector3(0, 0, 4.4), 8.0)
	shelter(st, c)
	s.add_commander(c)
	# 중요한 곳은 적의 불빛 안에, 나머지는 실루엣으로
	s.add_torch(c + Vector3(2.8, 0, 1.5))
	s.add_torch(c + Vector3(-9, 0, 8))
	s.add_torch(c + Vector3(10, 0, -6))
	s.add_guard(c + Vector3(-9, 0, 7), 180.0)
	s.add_guard(c + Vector3(9.5, 0, -5), 180.0)


## E9 높이 선택: 비계 2층(12m, 22m) 중 선택. 지휘관은 아래층 최대 사거리보다 조금 멀다.
static func _e9(s: Stage) -> void:
	s.begin("E9", "E9 · 높이 고르기", "E/Q 키로 비계를 오르내린다 (2.5초, 그동안 못 던진다)")
	s.set_zone(Vector3(0, E9_FLOORS[0], 0), Vector2(3.0, 3.0), E9_FLOORS)
	s.add_ammo(FIRE, 5)
	var c: Vector3 = COMMANDER[8]
	shelter(s.add_structure(), c)
	s.add_commander(c)


## E10 종합: 강철벽, 기름통 줄, 전령이 함께. 고폭탄으로 벽을 날리거나 기름통 줄에 불을 붙여 초소까지.
static func _e10(s: Stage) -> void:
	s.begin("E10", "E10 · 강철 관문 앞 초소", "지휘관을 쓰러뜨려라. 전령이 봉화대에 닿으면 실패 (1~2 키로 탄종 교체)")
	_zone(s, 9)
	s.add_ammo(HE, 3)
	s.add_ammo(FIRE, 4)
	var c: Vector3 = COMMANDER[9]
	var st := s.add_structure()
	steel_wall(st, c + Vector3(0, 0, 4.5), 9.0, 4.0)
	hut(st, c, 2.0, 2.6)
	# 벽 옆으로 돌아 초소까지 이어진 기름통 줄 (검정에 흰 띠)
	for i in 6:
		st.add_block(M.FUEL, c + Vector3(5.2, 0.4, 6.0 - i * 1.0), Vector3(0.8, 0.8, 1.0))
	for i in 2:
		st.add_block(M.FUEL, c + Vector3(4.0 - i * 1.0, 0.4, 0.5), Vector3(1.0, 0.8, 0.8))
	s.add_commander(c + Vector3(1.0, 0, 0.3), 180.0, Vector3(2.0, 0, -1.9))
	s.add_messenger(E10_RUN[0], E10_RUN[1], 3.4)
	s.beacon = s.add_structure()
	beacon(s.beacon, E10_RUN[1] + Vector3(-2.0, 0, -1.5))


## E11 지원형: 폭발통을 진 동료 고블린이 성문까지 걷는다. 방패병, 바리케이드, 쇠사슬 그물을 치워 길을 연다.
## 성문 앞에 닿으면 화염탄으로 폭발통을 터뜨린다. 지휘관은 성문 위에 서 있다.
static func _e11(s: Stage) -> void:
	s.begin("E11", "E11 · 성문 앞 지원", "동료의 길을 열고, 성문 앞에서 폭발통을 터뜨려라 (1~2 키로 탄종 교체)")
	_zone(s, 10)
	s.add_ammo(HE, 3)
	s.add_ammo(FIRE, 3)
	var gate := Vector3(0, 0, -60)
	var st := s.add_structure()
	# 성문: 석재 기둥 둘 + 강철 문짝 + 위의 석재 보행로 (지휘관이 그 위에 선다)
	for sx in [-1, 1]:
		st.add_block(M.STONE, gate + Vector3(sx * 2.5, 2.0, 0), Vector3(1.4, 4.0, 1.6))
		for k in 2:
			st.add_block(M.STONE, gate + Vector3(sx * (4.0 + k * 1.6), 2.0, 0), Vector3(1.6, 4.0, 1.6))
	st.add_block(M.STEEL, gate + Vector3(0, 1.75, 0.3), Vector3(3.6, 3.5, 0.3))
	st.add_block(M.STONE, gate + Vector3(0, 4.15, 0), Vector3(6.4, 0.3, 1.6))
	var pts: Array = E11_PATH
	# 길 위의 장애물: 방패병 둘 → 목재 바리케이드 → 쇠사슬 그물 (강철)
	var g1 := s.add_guard(_along(pts, 12.0) + Vector3(-0.5, 0, 0), 20.0, true)
	var g2 := s.add_guard(_along(pts, 12.0) + Vector3(0.6, 0, 0), 20.0, true)
	var barricade := s.add_structure()
	var bp := _along(pts, 22.0)
	for k in 4:
		barricade.add_block(M.WOOD_THIN, bp + Vector3(-1.5 + k * 1.0, 0.6, 0), Vector3(1.0, 1.2, 0.3))
	barricade.add_block(M.WOOD_THIN, bp + Vector3(0, 1.35, 0), Vector3(4.0, 0.3, 0.3))
	var net := s.add_structure()
	var np := _along(pts, 32.0)
	for sx in [-1, 1]:
		net.add_block(M.STEEL, np + Vector3(sx * 1.6, 1.0, 0), Vector3(0.3, 2.0, 0.3))
	for k in 3:
		net.add_block(M.STEEL, np + Vector3(0, 0.5 + k * 0.6, 0), Vector3(2.9, 0.08, 0.08))
	var obstacles := [
		{"distance": 12.0, "cleared": func(): return g1.dead and g2.dead},
		{"distance": 22.0, "cleared": func(): return _cleared(barricade)},
		{"distance": 32.0, "cleared": func(): return _cleared(net)},
	]
	s.add_ally(pts, 1.8, obstacles)
	s.add_commander(Vector3(0, 4.3, -60), 180.0, Vector3(1.8, 0, 0))


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


## 장애물 구조가 길에서 치워졌는지 (서 있는 블록이 하나도 없음).
static func _cleared(st: Structure) -> bool:
	for b in st.blocks:
		if not b.fallen and not b.burnt:
			return false
	return true
