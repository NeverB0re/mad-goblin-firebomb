class_name Campaign
extends RefCounted
## 본편 스테이지 (1장 국경 진지). 쉬운 것부터 어려운 것 순서로, 새 요소를 하나씩 배운다:
## 불(나무) → 높이 띄워 직격 → 전령·다리 → 고폭탄(금 간 석벽) → 연계 폭발 → 두 탄종 → 밤 → 받침 끊기
## → 기름 → 매달린 추 → 빠른 전령 → 동료 지원 → 먼 요새.
## 시험 스테이지(StageDefs E1~E11)에서 검증한 배치를 다시 쓰고, 연계 붕괴 스테이지 셋을 새로 만들었다.

const M := Block.Mat
const FIRE := StageDefs.FIRE
const HE := StageDefs.HE

## e: 다시 쓰는 시험 스테이지 번호, make: 새 스테이지 함수 이름
const STAGES := [
	{"name": "망루", "e": 1},
	{"name": "목책 진지", "e": 0},
	{"name": "다리를 건너는 전령", "e": 2},
	{"name": "석벽 초소", "e": 3},
	{"name": "화약고", "make": "_powder"},
	{"name": "마당 막사", "e": 4},
	{"name": "밤의 진지", "e": 7},
	{"name": "절벽 동굴", "e": 5},
	{"name": "연료 창고", "e": 6},
	{"name": "매달린 추", "make": "_weight"},
	{"name": "마구간 사이의 전령", "e": 9},
	{"name": "성문 앞 지원", "e": 10},
	{"name": "국경 요새", "make": "_fortress"},
]
const COUNT := 13

## 새 스테이지의 지휘관 위치 (테스트가 쓴다)
const POWDER_TOWER := Vector3(0, 0, -50)
const WEIGHT_HUT := Vector3(0, 0, -48)
const FORTRESS := Vector3(0, 0, -106)


static func label(i: int) -> String:
	return "1-%d" % (i + 1)


static func title(i: int) -> String:
	return STAGES[i].name


static func build(i: int, s: Stage) -> void:
	var def: Dictionary = STAGES[i]
	if def.has("e"):
		StageDefs.build(def.e, s)
	else:
		Callable(Campaign, def.make).call(s)
		s.finish_build()
	s.stage_id = label(i)
	s.title = "%s · %s" % [label(i), def.name]


static func _zone(s: Stage, height: float, z: float) -> void:
	s.set_zone(Vector3(0, height, z), Vector2(3.0, 3.0))


## 1-5 화약고 (연계): 금 간 석재 망대 위의 지휘관. 망대 발치의 나무 화약 창고를 태우면
## 화약통이 터지며 망대 기둥이 부러지고 지휘관이 떨어진다. 고폭탄으로 기둥을 직접 쳐도 된다.
## 망대 꼭대기는 석재 지붕이 덮어 위에서 불을 떨어뜨리기 어렵다.
static func _powder(s: Stage) -> void:
	s.begin("1-5", "화약고")
	_zone(s, StageDefs.HILL, -10.0)
	s.add_ammo(FIRE, 4)
	s.add_ammo(HE, 1)
	var c := POWDER_TOWER
	var st := s.add_structure()
	var h := 4.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	# 꼭대기 망루: 모서리 기둥 넷 + 석재 지붕 (사방이 트여 지휘관이 보인다)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.STONE, c + Vector3(sx * 1.6, h + 1.5, sz * 1.6), Vector3(0.3, 2.2, 0.3))
	st.add_block(M.STONE, c + Vector3(0, h + 2.75, 0), Vector3(3.6, 0.3, 3.6))
	# 망대 오른쪽 발치의 화약 창고 (판자 벽 + 짚 지붕, 앞에 창문) 안의 화약통 셋
	var shed := s.add_structure()
	StageDefs.hut(shed, c + Vector3(3.6, 0, 0.2), 1.4, 2.0)
	for k in 3:
		# 뒷벽에 붙여 쌓아 벽이 타면 불이 옮겨 붙는다
		shed.add_block(M.KEG, c + Vector3(2.85 + k * 0.75, 0.375, -0.625), Vector3(0.75, 0.75, 0.75))
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)
	s.add_guard(c + Vector3(6.5, 0, 3), 180.0)


## 1-10 매달린 추 (연계): 석재 막사 안의 지휘관. 막사 위 나무 기중기에 무거운 쇳덩이가 밧줄로 매달려 있다.
## 밧줄을 태우면 쇳덩이가 나무 지붕을 뚫고 떨어져 지휘관을 깔아뭉갠다.
## 지붕만 태우고 높이 띄워 넣는 풀이도 된다 (두 발).
static func _weight(s: Stage) -> void:
	s.begin("1-10", "매달린 추")
	_zone(s, StageDefs.HILL, -8.0)
	s.add_ammo(FIRE, 4)
	var c := WEIGHT_HUT
	var st := s.add_structure()
	# 막사: 석재 벽 (앞벽에 창문), 얇은 나무 지붕 판자
	var half := 2.2
	var wall_h := 2.6
	StageDefs.window_wall(st, M.STONE, c + Vector3(0, 0, half - 0.2), half * 2.0, [1.1, 0.7, 0.8], 5, [2], 0.4)
	st.add_block(M.STONE, c + Vector3(0, wall_h * 0.5, -half + 0.2), Vector3(half * 2.0, wall_h, 0.4))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * (half - 0.2), wall_h * 0.5, 0), Vector3(0.4, wall_h, half * 2.0 - 0.8))
	var n := 7
	for i in n:
		var x := -half + (i + 0.5) * half * 2.0 / n
		st.add_block(M.WOOD_THIN, c + Vector3(x, wall_h + 0.08, 0), Vector3(half * 2.0 / n, 0.16, half * 2.0))
	# 나무 기중기: 기둥 둘 + 가로대. 가로대 가운데에 밧줄과 쇳덩이 (매달린 물체)
	var crane := s.add_structure()
	var top := 9.5
	for sx in [-1, 1]:
		crane.add_block(M.WOOD_BEAM, c + Vector3(sx * 3.2, top * 0.5, -0.6), Vector3(0.4, top, 0.4))
	crane.add_block(M.WOOD_BEAM, c + Vector3(0, top + 0.2, -0.6), Vector3(6.8, 0.4, 0.4))
	var rope := crane.add_block(M.ROPE, c + Vector3(0, top - 0.9, -0.6), Vector3(0.15, 1.8, 0.15))
	rope.hanging = true
	var weight := crane.add_block(M.WEIGHT, c + Vector3(0, top - 1.8 - 0.6, -0.6), Vector3(1.2, 1.2, 1.2))
	weight.hanging = true
	s.add_commander(c + Vector3(0, 0, -0.6), 180.0, Vector3(3.2, 0, 2.4))
	s.add_guard(c + Vector3(-5, 0, 2.5), 180.0)


## 1-13 국경 요새 (원거리 + 연계): 고지대에서 아주 먼 요새. 높은 석벽 안뜰에 나무 공성탑이 서 있고
## 지휘관은 그 꼭대기에 있다. 탑 발치에 화약통이 쌓여 있어, 석벽 너머로 높이 띄워 넣으면 탑이 무너진다.
static func _fortress(s: Stage) -> void:
	s.begin("1-13", "국경 요새")
	_zone(s, 25.0, -36.0)
	s.add_ammo(FIRE, 5)
	s.add_ammo(HE, 2)
	var c := FORTRESS
	# 앞 성벽 (반듯한 석재, 위에 총안), 가운데 강철 문
	var wall := s.add_structure()
	var wz := c.z + 6.0
	for k in 9:
		var x := -9.0 + k * 2.25
		if k == 4:
			continue
		wall.add_block(M.STONE, Vector3(x, 2.25, wz), Vector3(2.25, 4.5, 1.0))
		if k % 2 == 0:
			wall.add_block(M.STONE, Vector3(x, 5.0, wz), Vector3(1.2, 1.0, 1.0))
	wall.add_block(M.STEEL, Vector3(0, 1.6, wz), Vector3(2.25, 3.2, 0.5))
	wall.add_block(M.STONE, Vector3(0, 3.85, wz), Vector3(2.25, 1.3, 1.0))
	# 안뜰의 나무 공성탑
	var tower := s.add_structure()
	StageDefs.watchtower(tower, c, 6.0, 1.6)
	# 탑 앞 발치에 쌓인 화약통
	for k in 3:
		tower.add_block(M.KEG, c + Vector3(-0.75 + k * 0.75, 0.375, 2.3), Vector3(0.75, 0.75, 0.75))
	s.add_commander(c + Vector3(0, 6.3, 0), 180.0, Vector3(0.9, 0, 0.6))
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)
	s.add_guard(Vector3(-6.75, 4.5, wz), 180.0)
