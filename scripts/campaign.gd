class_name Campaign
extends RefCounted
## 본편: 5개 월드 × 10개 진지 = 50개 (확장 기획서 11장).
## 월드 안의 틀: 1~2 새 요소 소개, 3~6 유형을 번갈아 응용, 7 쉬어가기, 8~9 이전 요소 섞기, 10 클라이맥스.
## 진지마다 짧은 서사(story)가 있어서 구조물이 그 자리에 있는 이유가 말이 된다 (화면에는 글씨 없이 그림으로만).
##
## 각 진지는 검증된 배치 패턴(p)에 위치·높이·밤·바람·비·탄약을 얹어 만든다. plan()은 설계상 풀이 (테스트가 실제로 던져 본다).

const M := Block.Mat
const FIRE := preload("res://ammo/fire.tres")
const HE := preload("res://ammo/he.tres")
const OIL := preload("res://ammo/oil.tres")
const FLARE := preload("res://ammo/flare.tres")
const FLAREGUN := preload("res://ammo/flaregun.tres")
const K := AmmoType.Kind
const HILL := 6.0

const WORLDS := ["점령당한 목책 마을", "철벽 관문", "증기 광산 도시", "대공 요새", "왕국 성채"]

## 전령 경로 모양 (시험 스테이지 E3, E10에서 검증)
const RUN_A := StageDefs.E3_RUN
const RUN_B := StageDefs.E10_RUN

const STAGES := [
	# ---------- 1월드: 점령당한 목책 마을 (화염탄) ----------
	{"name": "마을 어귀 망루", "p": "watchtower", "c": Vector3(0, 0, -36), "ammo": {"fire": 4}, "villagers": 3,
		"story": "인간들이 고블린 마을 어귀에 나무 망루를 세우고 지휘관이 올라가 마을을 내려다본다. 마을 고블린들은 구경한다."},
	{"name": "빼앗긴 대장간", "p": "shelter", "c": Vector3(0, 0, -42), "ammo": {"fire": 5}, "villagers": 3,
		"story": "지휘관이 고블린 대장간 차양 아래 버티고 섰다. 대장간 앞은 목책으로 막았지만 문은 열려 있다."},
	{"name": "곡식 창고", "p": "barn", "c": Vector3(-4, 0, -40), "ammo": {"fire": 4}, "villagers": 4,
		"story": "인간들이 마을 곡식 창고를 막사로 쓴다. 지붕은 기와라 불이 안 붙지만 판자 벽은 잘 탄다."},
	{"name": "개울 다리의 전령", "p": "messenger", "run": RUN_A, "off": Vector3(0, 0, 4), "speed": 2.5, "ammo": {"fire": 6},
		"story": "고블린이 쳐들어오자 전령이 나팔탑으로 달려간다. 가는 길에 마을 개울의 나무다리를 건너야 한다."},
	{"name": "마을 종탑", "p": "bell", "c": Vector3(0, 0, -40), "ammo": {"fire": 4}, "villagers": 3,
		"story": "마을 종탑 아래 석조 초소에 지휘관이 숨었다. 머리 위 나무 종틀에는 커다란 쇠종이 밧줄 하나에 매달려 있다."},
	{"name": "고블린 화약 창고", "p": "powder", "c": Vector3(0, 0, -42), "ammo": {"fire": 4}, "villagers": 2,
		"story": "인간들이 고블린의 화약 창고 옆에 금 간 석재 망대를 세웠다. 그 화약이 누구 것이었는지 잊은 모양이다."},
	{"name": "추수 축제 무대", "p": "watchtower", "c": Vector3(6, 0, -38), "legs": 3.0, "ammo": {"fire": 4}, "villagers": 6,
		"story": "쉬어 가기: 지휘관이 고블린 추수 축제 무대 위에서 연설한다. 무대는 나무, 장식은 짚이다."},
	{"name": "건초 더미 옆 망루", "p": "watchtower", "c": Vector3(-5, 0, -44), "legs": 5.0, "stone_skirt": true, "hay": true, "ammo": {"fire": 4}, "villagers": 2,
		"story": "망루 다리 아래쪽을 돌담으로 둘러 불을 막았다. 하지만 바로 옆 말먹이 건초 더미가 다리에 붙어 쌓여 있다."},
	{"name": "두 마구간 사이의 전령", "p": "messenger", "run": RUN_B, "off": Vector3(0, 0, 10), "speed": 3.0, "ammo": {"fire": 5}, "stables": true,
		"story": "마구간 사이로 빠져나간 전령이 개울을 건너 나팔탑으로 달린다. 마구간이 길을 가려 창으로만 보인다."},
	{"name": "촌장 집 점령군 본부", "p": "fortress", "c": Vector3(0, 0, -62), "perch": 14.0, "ammo": {"fire": 5}, "villagers": 4,
		"story": "클라이맥스: 점령군이 촌장 집 마당에 나무 공성탑을 세우고 본부로 쓴다. 탑 발치에 마을에서 걷어 간 화약통이 쌓였다."},

	# ---------- 2월드: 철벽 관문 (고폭탄) ----------
	{"name": "관문 초소", "p": "windowpost", "ammo": {"he": 5},
		"story": "관문 앞 초소. 강철 지붕은 무엇으로도 안 부서지지만 앞벽은 금 간 석벽이다. 창문 너머로 지휘관이 보인다."},
	{"name": "석재 망대", "p": "pillars", "c": Vector3(0, 0, -38), "ammo": {"he": 3, "fire": 2},
		"story": "관문을 내려다보는 석재 망대. 오래돼 기둥마다 금이 갔다. 기둥이 부러지면 꼭대기 지휘관이 떨어진다."},
	{"name": "석벽 마당 막사", "p": "courtyard", "ammo": {"he": 2, "fire": 3},
		"story": "석벽으로 두른 마당 안에 나무 막사가 있다. 벽은 고폭탄으로, 막사는 화염탄으로."},
	{"name": "해자 다리의 전령", "p": "messenger", "run": RUN_A, "off": Vector3(2, 0, 2), "speed": 2.8, "ammo": {"he": 3, "fire": 3},
		"story": "관문 해자 위 나무다리를 건너 나팔탑으로 달리는 전령."},
	{"name": "절벽 감시굴", "p": "cave", "ammo": {"he": 4, "fire": 2},
		"story": "절벽 밑 감시굴에 지휘관이 숨었다. 머리 위 석재 덮개는 금 간 기둥과 나무 버팀목 둘에만 얹혀 있다."},
	{"name": "화약 수레 창고", "p": "powder", "c": Vector3(4, 0, -40), "ammo": {"fire": 3, "he": 2},
		"story": "관문으로 화약을 나르는 수레 창고가 금 간 석재 망대 발치에 있다."},
	{"name": "허수아비 훈련장", "p": "watchtower", "c": Vector3(0, 0, -36), "legs": 3.5, "ammo": {"he": 2, "fire": 3},
		"story": "쉬어 가기: 병사들이 짚 허수아비로 훈련하고, 지휘관은 나무 사열대에서 구경한다."},
	{"name": "강철 성벽 뒤 막사", "p": "steelhut", "c": Vector3(0, 0, -40), "ammo": {"fire": 4, "he": 1},
		"story": "강철 성벽은 어떤 폭탄도 못 뚫는다. 하지만 성벽 뒤 나무 막사는 짚 지붕이라, 지붕을 태우고 높이 띄워 넣으면 된다."},
	{"name": "관문 탑과 화약", "p": "pillars", "c": Vector3(-6, 0, -42), "kegs": true, "ammo": {"he": 2, "fire": 2},
		"story": "관문 탑 기둥 옆에 화약통이 쌓여 있다. 기둥을 직접 치거나 화약통을 터뜨린다."},
	{"name": "성문 앞 지원", "p": "ally", "ammo": {"he": 3, "fire": 3},
		"story": "클라이맥스: 폭발통을 진 동료가 철벽 관문까지 걷는다. 방패병, 나무 바리케이드, 금 간 석재 울타리를 치워 준다."},

	# ---------- 3월드: 증기 광산 도시 (기름탄) ----------
	{"name": "연료 창고", "p": "oilhouse", "ammo": {"oil": 3, "fire": 3},
		"story": "광산 도시의 연료 창고. 젖은 홈통이 바깥 짚 더미에서 안쪽 연료 배관까지 이어진다."},
	{"name": "빗속 광부 숙소", "p": "barn", "c": Vector3(0, 0, -38), "rain": true, "wet": true, "ammo": {"oil": 2, "fire": 3},
		"story": "비가 와서 숙소 판자 벽이 흠뻑 젖었다. 그냥은 안 탄다. 기름을 먼저 붓는다."},
	{"name": "광차 전령", "p": "messenger", "run": RUN_A, "off": Vector3(0, 0, 4), "speed": 3.0, "cart": true, "ammo": {"fire": 4, "oil": 2},
		"story": "전령이 광차를 타고 궤도를 따라 달린다. 궤도는 개울 위 나무 가대를 지난다."},
	{"name": "비 맞는 감시탑", "p": "watchtower", "c": Vector3(0, 0, -38), "rain": true, "wet": true, "ammo": {"oil": 2, "fire": 3},
		"story": "비에 젖은 감시탑 다리. 기름을 부어 불을 붙여야 한다."},
	{"name": "보일러 망대", "p": "powder", "c": Vector3(0, 0, -42), "pipe": true, "ammo": {"fire": 3, "oil": 2},
		"story": "망대 옆 보일러실 연료통이 연료관으로 바깥까지 이어진다. 연료관 끝에 불을 붙이면 보일러실이 터진다."},
	{"name": "무너진 갱도 입구", "p": "cave", "rain": true, "wet_brace": true, "ammo": {"he": 2, "oil": 2, "fire": 2},
		"story": "갱도 입구 덮개를 받친 버팀목이 비에 젖었다. 금 간 기둥은 고폭탄, 젖은 버팀목은 기름과 불로."},
	{"name": "석탄 적재대", "p": "watchtower", "c": Vector3(-4, 0, -36), "legs": 4.0, "ammo": {"fire": 3, "oil": 1},
		"story": "쉬어 가기: 지휘관이 마른 나무 석탄 적재대 위에서 감독한다."},
	{"name": "빗속 광차 전령", "p": "messenger", "run": RUN_B, "off": Vector3(0, 0, 10), "speed": 3.2, "cart": true, "rain": true, "ammo": {"fire": 4, "oil": 2},
		"story": "비 오는 날 광차를 탄 전령. 궤도 가대는 지붕 덮인 다리라 말라 있다."},
	{"name": "연료관 골목", "p": "oilhouse", "rain": true, "ammo": {"oil": 3, "fire": 3},
		"story": "비 오는 골목, 연료 창고의 젖은 홈통. 기름 길을 놓고 불을 붙인다."},
	{"name": "정련소", "p": "fortress", "c": Vector3(0, 0, -64), "perch": 16.0, "ammo": {"fire": 4, "oil": 2},
		"story": "클라이맥스: 정련소 안뜰 나무 증기탑 위의 지휘관. 탑 발치에 연료통이 쌓여 있다."},

	# ---------- 4월드: 대공 요새 (조명탄, 밤, 바람) ----------
	{"name": "밤의 진지", "p": "shelter", "c": Vector3(0, 0, -44), "night": true, "ammo": {"fire": 5, "flare": 3},
		"story": "요새 앞 밤의 진지. 횃불 몇 개뿐이라 조명탄으로 비춰 봐야 한다."},
	{"name": "바람 부는 사열대", "p": "watchtower", "c": Vector3(0, 0, -38), "wind": Vector3(2.0, 0, 0), "ammo": {"fire": 5},
		"story": "산바람이 부는 요새 사열대. 바람자루가 바람 방향과 세기를 알려 준다."},
	{"name": "발리스타 탑", "p": "watchtower", "c": Vector3(4, 0, -40), "legs": 5.0, "ballista_top": true, "ammo": {"fire": 4, "flare": 1},
		"story": "대공 발리스타를 얹은 나무 탑. 지휘관이 발리스타 곁에 서 있다."},
	{"name": "횃불 든 전령", "p": "messenger", "run": RUN_A, "off": Vector3(0, 0, 4), "speed": 2.6, "night": true, "torch": true, "ammo": {"fire": 5, "flare": 2},
		"story": "밤에 횃불을 든 전령이 다리를 건넌다. 횃불이 위치를 알려 준다."},
	{"name": "바람 속 화약고", "p": "powder", "c": Vector3(0, 0, -42), "wind": Vector3(-1.8, 0, 0), "ammo": {"fire": 4},
		"story": "바람 부는 요새 화약고와 금 간 석재 망대."},
	{"name": "밤의 감시굴", "p": "cave", "night": true, "ammo": {"he": 4, "fire": 2, "flare": 2},
		"story": "밤, 절벽 밑 감시굴. 조명탄으로 덮개 받침을 찾아 끊는다."},
	{"name": "보급 막사", "p": "barn", "c": Vector3(0, 0, -38), "night": true, "ammo": {"fire": 3, "flare": 2},
		"story": "쉬어 가기: 횃불이 켜진 보급 막사. 판자 벽이 잘 탄다."},
	{"name": "바람 속 석벽 초소", "p": "windowpost", "wind": Vector3(1.5, 0, 0), "ammo": {"he": 5},
		"story": "바람이 부는 강철 지붕 초소. 고폭탄도 바람에 밀린다."},
	{"name": "밤바람 전령", "p": "messenger", "run": RUN_B, "off": Vector3(0, 0, 10), "speed": 3.0, "night": true, "torch": true, "wind": Vector3(0, 0, 1.2), "ammo": {"fire": 5, "flare": 2},
		"story": "밤바람 속 전령이 다리를 건너 나팔탑으로 달린다."},
	{"name": "대공 요새 본루", "p": "fortress", "c": Vector3(0, 0, -64), "perch": 16.0, "night": true, "wind": Vector3(1.0, 0, 0), "ammo": {"fire": 5, "flare": 2},
		"story": "클라이맥스: 밤바람 속 요새 본루. 안뜰 공성탑 발치의 화약통에 불을 넣는다."},

	# ---------- 5월드: 왕국 성채 (플레어건, 탄도미사일) ----------
	{"name": "첫 표적 지정", "p": "bunker", "c": Vector3(0, 0, -40), "ammo": {"flaregun": 2},
		"story": "지휘관이 강철 벙커에 숨었다. 폭탄으로는 안 된다. 플레어건으로 표적을 찍으면 후방에서 미사일이 날아온다."},
	{"name": "나무 발리스타 하나", "p": "bunker", "c": Vector3(0, 0, -42), "ballistas": [[Vector3(-10, 0, -34), "wood"]], "ammo": {"fire": 3, "flaregun": 2},
		"story": "발리스타가 있으면 미사일을 쏘아 떨어뜨린다. 나무 발리스타 탑부터 태운다."},
	{"name": "석재 발리스타", "p": "bunker", "c": Vector3(0, 0, -42), "ballistas": [[Vector3(9, 0, -34), "stone"]], "ammo": {"he": 3, "flaregun": 2},
		"story": "금 간 석재 기둥 위의 발리스타. 고폭탄으로 기둥을 부순 뒤 표적을 찍는다."},
	{"name": "성 안 다리의 전령", "p": "messenger", "run": RUN_A, "off": Vector3(0, 0, 4), "speed": 3.0, "ammo": {"fire": 5},
		"story": "성 안 해자 다리를 건너 나팔탑으로 달리는 왕실 전령."},
	{"name": "두 발리스타", "p": "bunker", "c": Vector3(0, 0, -44), "ballistas": [[Vector3(-10, 0, -36), "wood"], [Vector3(10, 0, -36), "stone"]], "ammo": {"fire": 3, "he": 3, "flaregun": 2},
		"story": "나무 발리스타와 석재 발리스타가 벙커를 지킨다."},
	{"name": "지하 감옥 입구", "p": "bunker", "c": Vector3(0, 0, -40), "night": true, "ammo": {"flaregun": 2, "flare": 2},
		"story": "밤, 지하 감옥 입구의 강철 벙커. 조명탄으로 보고 표적을 찍는다."},
	{"name": "왕실 마구간", "p": "barn", "c": Vector3(0, 0, -40), "ammo": {"fire": 4},
		"story": "쉬어 가기: 왕실 마구간 판자 벽 안에서 쉬는 지휘관."},
	{"name": "왕성 성문 지원", "p": "ally", "ammo": {"he": 3, "fire": 3},
		"story": "동료가 폭발통을 지고 왕성 성문까지 간다."},
	{"name": "바람 속 발리스타", "p": "bunker", "c": Vector3(0, 0, -44), "wind": Vector3(1.5, 0, 0), "ballistas": [[Vector3(-11, 0, -36), "wood"], [Vector3(11, 0, -36), "wood"]], "ammo": {"fire": 4, "flaregun": 2},
		"story": "성벽 위 바람 속 나무 발리스타 둘."},
	{"name": "왕국 성채 본진", "p": "bunker", "c": Vector3(0, 0, -50), "perch": 12.0, "final": true,
		"ballistas": [[Vector3(-12, 0, -40), "wood"], [Vector3(12, 0, -40), "stone"], [Vector3(0, 0, -36), "stone"]], "ammo": {"fire": 3, "he": 4, "flaregun": 2},
		"story": "최종: 부족장이 갇힌 성채. 발리스타 셋을 모두 무너뜨리고 지휘관 벙커에 표적을 찍어 미사일을 떨어뜨린다 (부족장이 휘말려도 고블린은 개의치 않는다)."},
]
const COUNT := 50


static func label(i: int) -> String:
	return "%d-%d" % [i / 10 + 1, i % 10 + 1]


static func title(i: int) -> String:
	return STAGES[i].name


static func world_of(i: int) -> int:
	return i / 10


static func build(i: int, s: Stage) -> void:
	var d: Dictionary = STAGES[i]
	s.world = world_of(i)
	match d.p:
		"windowpost":
			StageDefs._e4(s)
		"courtyard":
			StageDefs._e5(s)
		"cave":
			_cave(s, d)
		"oilhouse":
			StageDefs._e7(s)
		"ally":
			StageDefs._e11(s)
		_:
			s.begin(label(i), d.name, false, Stage.Goal.MESSENGER if d.p == "messenger" else Stage.Goal.COMMANDER)
			s.set_zone(Vector3(0, d.get("perch", HILL), d.get("zone", 0.0)), Vector2(3.0, 3.0))
			Callable(Campaign, "_" + d.p).call(s, d)
	s.ammo_slots.clear()
	var ammo_of := {"fire": FIRE, "he": HE, "oil": OIL, "flare": FLARE, "flaregun": FLAREGUN}
	for key in ["fire", "he", "oil", "flare", "flaregun"]:
		if d.ammo.has(key):
			s.add_ammo(ammo_of[key], d.ammo[key])
	s.wind = d.get("wind", Vector3.ZERO)
	if s.wind != Vector3.ZERO:
		var pp := s.player.global_position
		s.add_windsock(Vector3(pp.x + 4.5, s.player.global_position.y - 0.0, pp.z - 2.0))
	if d.get("rain", false):
		s.make_rain()
	if d.get("night", false):
		s.night = true
		_torches(s)
	for k in d.get("villagers", 0):
		s.add_villager(Vector3(-16 + k * 6.0, 0, -20 - (k % 2) * 3), 180.0 + (k - 2) * 15.0)
	for b in d.get("ballistas", []):
		_ballista(s, b[0], b[1])
	s.finish_build()
	s.stage_id = label(i)
	s.title = "%s · %s" % [label(i), d.name]


## 설계상 풀이: [[탄종, 목표, 높이 띄우기, 던진 뒤 기다림(초)], ...] (테스트가 실제로 던져 본다).
## 목표가 INF면 지휘관의 지금 자리. ["ally"]는 지원형 풀이.
static func plan(i: int) -> Array:
	var d: Dictionary = STAGES[i]
	var c: Vector3 = d.get("c", Vector3.ZERO)
	var out := []
	for b in d.get("ballistas", []):
		var bp: Vector3 = b[0]
		if b[1] == "wood":
			out.append([K.FIRE, bp + Vector3(0, 1.5, 1.4), false, 9.0])
		else:
			out.append([K.HE, bp + Vector3(0, 1.0, 1.7), false, 3.0])
	match d.p:
		"watchtower":
			if d.get("wet", false):
				out.append([K.OIL, c + Vector3(0, 1.5, 1.6), false, 0.5])
			if d.get("hay", false):
				out.append([K.FIRE, c + Vector3(2.1, 1.6, 1.95), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(0, 1.5, 1.5), false, 0.0])
		"shelter":
			out.append([K.FIRE, c + Vector3(0, 2.9, 0), false, 6.0])
			out.append([K.FIRE, c + Vector3(0, 1.8, 0), true, 0.0])
		"barn":
			if d.get("wet", false):
				out.append([K.OIL, c + Vector3(0, 1.0, 2.15), false, 0.5])
			out.append([K.FIRE, c + Vector3(0, 1.0, 2.15), false, 0.0])
		"bell":
			out.append([K.FIRE, c + Vector3(0, 7.5, -0.1), false, 0.0])
		"powder":
			if d.get("pipe", false):
				out.append([K.FIRE, c + Vector3(3.0, 0.3, 6.6), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(3.6, 2.2, 0.4), false, 0.0])
		"pillars":
			out.append([K.HE, c + Vector3(0, 1.0, 1.9), false, 0.0])
		"steelhut":
			out.append([K.FIRE, c + Vector3(0, 2.9, -1.0), true, 4.0])
			out.append([K.FIRE, Vector3.INF, true, 0.0])
		"fortress":
			out.append([K.FIRE, c + Vector3(0, 0.7, 2.3), true, 0.0])
		"bunker":
			out.append([K.FLAREGUN, c + Vector3(0, 2.7, 0), false, 0.0])
		"messenger":
			out.append([K.FIRE, _bridge_of(d) + Vector3(0, 0.45, 0), false, 0.0])
		"windowpost":
			var e: Vector3 = StageDefs.COMMANDER[3]
			out.append([K.HE, e + Vector3(0, 1.5, 2.8), false, 3.0])
			out.append([K.HE, e + Vector3(0, 1.0, 0.2), false, 0.0])
		"courtyard":
			var e: Vector3 = StageDefs.COMMANDER[4]
			out.append([K.HE, e + Vector3(0, 1.5, 4.7), false, 2.0])
			out.append([K.FIRE, Vector3.INF, true, 0.0])
		"cave":
			var e: Vector3 = StageDefs.COMMANDER[5]
			out.append([K.HE, e + Vector3(-3.2, 2.2, 2.05), false, 2.0])
			if d.get("wet_brace", false):
				out.append([K.OIL, e + Vector3(3.2, 2.2, 1.9), false, 0.5])
			out.append([K.FIRE, e + Vector3(3.2, 2.2, 1.9), false, 0.0])
		"oilhouse":
			var e: Vector3 = StageDefs.COMMANDER[6]
			out.append([K.OIL, e + Vector3(0.3, 0.3, 5.0), false, 0.0])
			out.append([K.FIRE, e + Vector3(0.3, 1.0, 7.6), false, 0.0])
		"ally":
			out.append(["ally"])
	return out


static func _bridge_of(d: Dictionary) -> Vector3:
	var b := StageDefs.E3_BRIDGE if d.run == RUN_A else StageDefs.E10_BRIDGE
	return b + d.get("off", Vector3.ZERO)


static func _shift(pts: Array, off: Vector3) -> Array:
	var out := []
	for p in pts:
		out.append(p + off)
	return out


# ---------- 패턴 ----------

## 나무 망루 (축제 무대, 사열대, 적재대 등). 다리에 불이 붙으면 번져 올라가 지휘관이 탄다.
static func _watchtower(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var legs: float = d.get("legs", 4.0)
	var st := s.add_structure()
	StageDefs.watchtower(st, c, legs)
	if d.get("wet", false):
		for b in st.blocks:
			if b.mat == M.WOOD_BEAM or b.mat == M.WOOD_THIN:
				_wet(b)
	if d.get("stone_skirt", false):
		# 다리 아래쪽을 두른 돌담 (불이 땅에서 다리로 옮지 못하게)
		var wall := s.add_structure()
		for sz in [-1, 1]:
			wall.add_block(M.STONE, c + Vector3(0, 0.6, sz * 2.2), Vector3(4.6, 1.2, 0.3))
	if d.get("hay", false):
		# 다리에 붙여 쌓은 건초 더미 (불이 다리로 옮겨 붙는다)
		st.add_block(M.STRAW, c + Vector3(2.1, 1.0, 1.3), Vector3(1.0, 2.0, 1.2))
	if d.get("ballista_top", false):
		var b := st.add_block(M.WOOD_BEAM, c + Vector3(-0.9, legs + 0.55, -0.9), Vector3(0.5, 0.5, 0.5))
		s.add_ballista(b)
	s.add_commander(c + Vector3(0, legs + 0.3, 0), 180.0, Vector3(0.9, 0, 0.6))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 대장간 차양: 목책(문 열림) 뒤 석재 기둥 위 두꺼운 나무 지붕.
static func _shelter(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	StageDefs.palisade(st, c + Vector3(0, 0, 4.2), 7.0, 2.6, 1.6)
	StageDefs.shelter(st, c)
	s.add_commander(c)
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## 창고·숙소·막사: 판자 벽(창문 둘) + 기와(석재) 지붕. 벽이 타면 지휘관도 탄다. wet: 비에 젖은 벽.
static func _barn(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	var half := 2.0
	var height := 2.6
	for sz in [-1, 1]:
		for i in 5:
			var x := -half + (i + 0.5) * half * 2.0 / 5
			var w := half * 2.0 / 5
			if sz == 1 and (i == 1 or i == 3):
				st.add_block(M.WOOD_THIN, c + Vector3(x, 0.55, sz * (half - 0.1)), Vector3(w, 1.1, 0.2))
				st.add_block(M.WOOD_THIN, c + Vector3(x, (1.8 + height) * 0.5, sz * (half - 0.1)), Vector3(w, height - 1.8, 0.2))
				continue
			st.add_block(M.WOOD_THIN, c + Vector3(x, height * 0.5, sz * (half - 0.1)), Vector3(w, height, 0.2))
	for sx in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(sx * (half - 0.1), height * 0.5, 0), Vector3(0.2, height, half * 2.0 - 0.4))
	# 기와 지붕 (석재: 불이 안 붙는다)
	st.add_block(M.STONE, c + Vector3(0, height + 0.15, 0), Vector3(half * 2.0 + 0.3, 0.3, half * 2.0 + 0.3))
	if d.get("wet", false):
		for b in st.blocks:
			if b.mat == M.WOOD_THIN:
				_wet(b)
	s.add_commander(c + Vector3(0, 0, -0.5), 180.0, Vector3(2.8, 0, 2.8))
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 마을 종탑: 석조 초소 + 나무 종틀에 밧줄로 매단 쇠종. 밧줄을 태우면 종이 지붕을 뚫고 떨어진다.
static func _bell(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	var half := 2.2
	var wall_h := 2.6
	StageDefs.window_wall(st, M.STONE, c + Vector3(0, 0, half - 0.2), half * 2.0, [1.1, 0.7, 0.8], 5, [2], 0.4)
	st.add_block(M.STONE, c + Vector3(0, wall_h * 0.5, -half + 0.2), Vector3(half * 2.0, wall_h, 0.4))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * (half - 0.2), wall_h * 0.5, 0), Vector3(0.4, wall_h, half * 2.0 - 0.8))
	for i in 7:
		var x := -half + (i + 0.5) * half * 2.0 / 7
		st.add_block(M.WOOD_THIN, c + Vector3(x, wall_h + 0.08, 0), Vector3(half * 2.0 / 7, 0.16, half * 2.0))
	var frame := s.add_structure()
	var top := 9.5
	for sx in [-1, 1]:
		frame.add_block(M.WOOD_BEAM, c + Vector3(sx * 3.2, top * 0.5, -0.6), Vector3(0.4, top, 0.4))
	frame.add_block(M.WOOD_BEAM, c + Vector3(0, top + 0.2, -0.6), Vector3(6.8, 0.4, 0.4))
	var rope := frame.add_block(M.ROPE, c + Vector3(0, top - 0.9, -0.6), Vector3(0.15, 1.8, 0.15))
	rope.hanging = true
	var bell := frame.add_block(M.WEIGHT, c + Vector3(0, top - 2.4, -0.6), Vector3(1.2, 1.2, 1.2))
	bell.hanging = true
	_bell_look(bell)
	s.add_commander(c + Vector3(0, 0, -0.6), 180.0, Vector3(3.2, 0, 2.4))
	s.add_guard(c + Vector3(-5, 0, 2.5), 180.0)


## 쇳덩이를 청동 종 모양으로 꾸민다 (판정은 그대로 상자).
static func _bell_look(b: Block) -> void:
	var bronze := Models.mat(Color(0.72, 0.55, 0.22), 0.4, 0.7)
	for child in b.get_children():
		if child is MeshInstance3D:
			child.visible = false
	var m := Node3D.new()
	b.add_child(m)
	Models.cyl(m, 0.3, 0.75, 1.1, Vector3.ZERO, bronze, Vector3.ZERO, 12)
	Models.cyl(m, 0.78, 0.78, 0.1, Vector3(0, -0.55, 0), bronze, Vector3.ZERO, 12)
	Models.ball(m, 0.15, Vector3(0, -0.7, 0), Models.mat(Color(0.3, 0.25, 0.2)))


## 화약고 / 보일러 망대: 금 간 석재 망대 + 발치의 나무 창고 안 화약통. pipe: 창고까지 이어진 연료관.
static func _powder(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	var h := 4.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.STONE, c + Vector3(sx * 1.6, h + 1.5, sz * 1.6), Vector3(0.3, 2.2, 0.3))
	st.add_block(M.STONE, c + Vector3(0, h + 2.75, 0), Vector3(3.6, 0.3, 3.6))
	var shed := s.add_structure()
	StageDefs.hut(shed, c + Vector3(3.6, 0, 0.2), 1.4, 2.0)
	for k in 3:
		shed.add_block(M.KEG, c + Vector3(2.85 + k * 0.75, 0.375, -0.625), Vector3(0.75, 0.75, 0.75))
	if d.get("pipe", false):
		# 창고 앞벽에서 바깥으로 이어진 연료관. 끝에 불을 붙이면 창고까지 타 들어간다
		for k in 5:
			shed.add_block(M.FUEL, c + Vector3(3.0, 0.15, 1.8 + k * 1.0), Vector3(0.3, 0.3, 1.0))
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 금 간 석재 망대 (기둥 넷 위 석재 바닥과 난간). kegs: 기둥 옆 화약통.
static func _pillars(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	var h := 4.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	for sz in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(0, h + 0.8, sz * 1.65), Vector3(3.6, 0.8, 0.3))
	if d.get("kegs", false):
		for k in 2:
			st.add_block(M.KEG, c + Vector3(-2.3 - k * 0.75, 0.375, 1.4), Vector3(0.75, 0.75, 0.75))
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 강철 성벽 뒤 나무 막사 (짚 지붕). 성벽은 안 부서지니 높이 띄워 지붕에 떨어뜨린다.
static func _steelhut(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var wall := s.add_structure()
	StageDefs.steel_wall(wall, c + Vector3(0, 0, 4.0), 10.0, 3.5)
	var st := s.add_structure()
	StageDefs.hut(st, c + Vector3(0, 0, -1.0), 2.0, 2.6)
	s.add_commander(c + Vector3(0, 0, -1.0), 180.0, Vector3(3.0, 0, 1.0))
	s.add_guard(c + Vector3(-3.5, 0, 2.5), 180.0)


## 공성탑 요새 / 정련소 / 본루: 앞 성벽(반듯한 석재) 너머 안뜰의 나무 탑, 탑 발치의 화약통.
static func _fortress(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var wall := s.add_structure()
	var wz := c.z + 6.0
	for k in 9:
		var x := c.x - 9.0 + k * 2.25
		if k == 4:
			continue
		wall.add_block(M.STONE, Vector3(x, 2.25, wz), Vector3(2.25, 4.5, 1.0))
		if k % 2 == 0:
			wall.add_block(M.STONE, Vector3(x, 5.0, wz), Vector3(1.2, 1.0, 1.0))
	wall.add_block(M.STEEL, Vector3(c.x, 1.6, wz), Vector3(2.25, 3.2, 0.5))
	wall.add_block(M.STONE, Vector3(c.x, 3.85, wz), Vector3(2.25, 1.3, 1.0))
	var tower := s.add_structure()
	StageDefs.watchtower(tower, c, 6.0, 1.6)
	for k in 3:
		tower.add_block(M.KEG, c + Vector3(-0.75 + k * 0.75, 0.375, 2.3), Vector3(0.75, 0.75, 0.75))
	s.add_commander(c + Vector3(0, 6.3, 0), 180.0, Vector3(0.9, 0, 0.6))
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## 강철 벙커: 무엇으로도 안 부서진다. 플레어건으로 표적을 찍어 미사일을 부른다 (발리스타가 남아 있으면 요격당한다).
## final: 곁에 부족장이 갇힌 우리.
static func _bunker(s: Stage, d: Dictionary) -> void:
	var c: Vector3 = d.c
	var st := s.add_structure()
	var half := 2.2
	for sz in [-1, 1]:
		StageDefs.window_wall(st, M.STEEL, c + Vector3(0, 0, sz * (half - 0.2)), half * 2.0, [1.2, 0.4, 0.8], 5, [2] if sz == 1 else [], 0.4)
	for sx in [-1, 1]:
		st.add_block(M.STEEL, c + Vector3(sx * (half - 0.2), 1.2, 0), Vector3(0.4, 2.4, half * 2.0 - 0.8))
	st.add_block(M.STEEL, c + Vector3(0, 2.55, 0), Vector3(half * 2.0 + 0.4, 0.3, half * 2.0 + 0.4))
	s.add_commander(c + Vector3(0, 0, -0.4), 180.0, Vector3(3.0, 0, 2.6))
	s.add_guard(c + Vector3(-4, 0, 3.5), 180.0)
	s.add_guard(c + Vector3(4, 0, 3.5), 180.0)
	if d.get("final", false):
		# 부족장이 갇힌 우리 (판정과 무관한 장식)
		var cage := Node3D.new()
		cage.position = c + Vector3(-6.5, 0, 1.0)
		s.add_child(cage)
		cage.add_child(Models.chief())
		var bars := Models.mat(Models.HUMAN_STEEL.darkened(0.3), 0.4, 0.7)
		for k in 8:
			var a := TAU * k / 8.0
			Models.cyl(cage, 0.04, 0.04, 2.2, Vector3(cos(a) * 0.8, 1.1, sin(a) * 0.8), bars)
		Models.cyl(cage, 0.9, 0.9, 0.1, Vector3(0, 2.2, 0), bars, Vector3.ZERO, 10)


## 전령: 꺾은선 경로, 개울 위 나무다리, 목적지 나팔탑. stables: 길을 가리는 마구간. cart: 광차와 궤도.
static func _messenger(s: Stage, d: Dictionary) -> void:
	var off: Vector3 = d.get("off", Vector3.ZERO)
	var run := _shift(d.run, off)
	var a: bool = d.run == RUN_A
	s.add_messenger(run, d.speed, d.get("torch", false), d.get("cart", false))
	var start_i := StageDefs.E3_BRIDGE_START if a else StageDefs.E10_BRIDGE_START
	var end_i := StageDefs.E3_BRIDGE_END if a else StageDefs.E10_BRIDGE_END
	var deck := StageDefs.bridge(s, s.add_structure(), _bridge_of(d))
	s.add_bridge(deck, StageDefs._length_to(run, start_i), StageDefs._length_to(run, end_i))
	StageDefs.horn_tower(s, run[run.size() - 1] + (Vector3(3, 0, 2) if a else Vector3(-3, 0, -2)))
	if d.get("stables", false):
		StageDefs.stable(s.add_structure(), Vector3(15.5, 0, -36.8) + off)
		StageDefs.stable(s.add_structure(), Vector3(-9, 0, -48) + off)


## 동굴 (E6 배치). wet_brace: 비에 젖은 버팀목 (기름이 필요).
static func _cave(s: Stage, d: Dictionary) -> void:
	StageDefs._e6(s)
	if d.get("wet_brace", false):
		for st in s.structures:
			for b in st.blocks:
				if b.mat == M.WOOD_BEAM:
					_wet(b)


## 비에 젖은 목재로 바꾼다 (기름을 묻혀야 탄다).
static func _wet(b: Block) -> void:
	b.make_wet()


## 밤: 지휘관 곁과 진지 둘레의 횃불.
static func _torches(s: Stage) -> void:
	var c := Vector3(0, 0, -45)
	if s.commander:
		c = s.commander.global_position
	elif not s.messengers.is_empty():
		c = s.messengers[0].global_position
	c.y = 0.0
	for o in [Vector3(2.8, 0, 2.5), Vector3(-9, 0, 8), Vector3(10, 0, -6)]:
		s.add_torch(c + o)


## 대공 발리스타 탑. wood: 나무 다리 (불), stone: 금 간 석재 기둥 (고폭탄).
static func _ballista(s: Stage, pos: Vector3, kind: String) -> void:
	var st := s.add_structure()
	var legs := 5.0
	var wood := kind == "wood"
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM if wood else M.CRACKED, pos + Vector3(sx * 1.2, legs * 0.5, sz * 1.2), Vector3(0.5, legs, 0.5) if wood else Vector3(0.7, legs, 0.7))
	if wood:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, pos + Vector3(0, 1.5, sz * 1.2), Vector3(1.9, 0.25, 0.25))
	st.add_block(M.WOOD_THIN if wood else M.STONE, pos + Vector3(0, legs + 0.15, 0), Vector3(3.0, 0.3, 3.0))
	var b := st.add_block(M.WOOD_BEAM, pos + Vector3(0, legs + 0.55, 0), Vector3(0.6, 0.5, 0.6))
	s.add_ballista(b)
