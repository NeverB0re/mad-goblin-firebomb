class_name Campaign
extends RefCounted
## 본편: 5개 월드 × 10개 진지 = 50개 (확장 기획서 11장).
##
## 월드마다 배울 것이 정해져 있고, 뒤로 갈수록 기본 난이도가 오른다.
## - 1월드 점령당한 목책 마을: 기본 설계를 모두 배운다 (나무·짚 태우기, 금 간 석벽 부수기, 강철, 매달린 쇳덩이, 화약통, 바람, 지원).
## - 2월드 비 내리는 광산 도시: 늘 비가 와서 나무와 짚이 젖어 있다. 기름병을 먼저 부어야 탄다.
## - 3월드 밤의 철벽 관문: 늘 밤이다. 조명탄으로 비춰 보며 던진다.
## - 4월드 대공 요새: 높은 고지대에서 아주 먼 표적. 투척 구역 옆에 글라이더 폭격대가 대기하고, 조명탄이 떨어진 자리로 날아가
##   고블린이 폭탄을 안고 뛰어내린다. 아주 크게 터져 근처 지휘관을 한꺼번에 쓰러뜨리지만, 발리스타가 하나라도 서 있으면
##   글라이더가 격추되어 불시착한다(불발) → 발리스타부터 치운다.
## - 5월드 일반 진지는 앞 월드의 특성(비, 밤, 발리스타 폭격) 중 하나 이상이 섞인다. 밤과 발리스타는 같이 두지 않는다.
## - 최종 진지: 거대 로켓 한 발 (궁극기). 발리스타를 다 치운 뒤 옆의 빨간 발사 버튼을 누르면 남은 지휘관을 모두 날린다.
## - 5월드 왕국 성채: 지금까지 나온 기믹을 모두 섞고 지휘관 수를 늘린다.
## 난이도 기준: 거리, 쓰러뜨릴 지휘관 수, 노려야 할 표적의 크기, 궤도의 정확함 (높이 띄워 담 너머 좁은 곳에 떨어뜨리기 등).
## 바람은 월드 기믹이 아니라 난이도 조절 요소다: 1월드 후반(1-7)부터 모든 진지에 바람자루가 서고, 펴진 마디 수(0~5단계)가 세기다.
## 페인트탄(화염탄과 같은 궤적, 아무것도 안 부숨, 물감 자국만 남김)은 모든 진지에 준다: 목표 하나에 하나씩 + 바람·거리·높이 띄우기만큼 더.
##
## 규칙: 한 번 쓴 진지 구성은 다시 쓰지 않는다 (같은 건물이 다른 조합의 일부로 다시 나올 수는 있다).
## 탄종은 그 진지를 푸는 데 필요한 것만 준다. 진지마다 짧은 서사(story)가 있어 건물이 그 자리에 있는 이유가 말이 된다.
## plan()은 설계상 풀이이고, tests/campaign_test.gd가 실제로 던져 본다.

const M := Block.Mat
const FIRE := preload("res://ammo/fire.tres")
const HE := preload("res://ammo/he.tres")
const OIL := preload("res://ammo/oil.tres")
const FLARE := preload("res://ammo/flare.tres")
const PAINT := preload("res://ammo/paint.tres")
const K := AmmoType.Kind
const HILL := 6.0
## 폭격 한 번이 맡는 거리: 첫 벙커에서 이만큼 안의 부품은 폭격으로 끝낸다 (설계상 풀이에서 따로 던지지 않는다)
const ROCKET_CLUSTER := 14.0

const WORLDS := ["점령당한 목책 마을", "비 내리는 광산 도시", "밤의 철벽 관문", "대공 요새", "왕국 성채"]

## 월드 공통 환경 (진지마다 덮어쓸 수 있다)
const WORLD_RAIN := [false, true, false, false, false]
const WORLD_NIGHT := [false, false, true, false, false]

## parts: [[부품, 위치, {선택}], ...]. 부품 이름은 _part_<이름> 함수.
## wind: [단계 0~5, 방향 x, 방향 z] (방향은 바람이 불어 가는 쪽. +x = 오른쪽, +z = 고블린 쪽 = 맞바람).
## bombers: 대기 중인 글라이더 폭격 고블린 수 (조명탄 하나에 한 번). launch_button: 최종 진지의 거대 로켓 발사 버튼.
const STAGES := [
	# ---------- 1월드: 점령당한 목책 마을 (기본 설계 익히기) ----------
	{"name": "마을 어귀 망루", "ammo": {"fire": 2}, "villagers": 3,
		"parts": [["tower", Vector3(0, 0, -32)]],
		"story": "인간들이 고블린 마을 어귀에 나무 망루를 세우고 지휘관이 올라가 마을을 내려다본다. 나무는 탄다. 페인트탄으로 먼저 떨어지는 자리를 재 볼 수 있다."},
	{"name": "빼앗긴 대장간", "ammo": {"fire": 3}, "villagers": 3,
		"parts": [["shelter", Vector3(2, 0, -36)]],
		"story": "지휘관이 고블린 대장간의 두꺼운 나무 차양 아래 버티고 섰다. 차양을 태워 없애고 높이 띄워 떨어뜨린다."},
	{"name": "곡식 창고와 보초 망루", "ammo": {"fire": 3}, "villagers": 4,
		"parts": [["hut", Vector3(-6, 0, -36)], ["tower", Vector3(8, 0, -42), {"legs": 3.0}]],
		"story": "지휘관 둘: 하나는 짚 지붕 곡식 창고 안에서 곡식을 세고, 하나는 옆 보초 망루에 올라가 있다. 깃발 둘을 다 쓰러뜨려야 한다."},
	{"name": "금 간 석벽 초소", "ammo": {"he": 3},
		"parts": [["windowpost", Vector3(0, 0, -36)]],
		"story": "마을 우물가에 인간들이 쌓은 석벽 초소. 앞벽은 낡아 금이 갔고(고폭탄으로 부서진다), 지붕은 강철이라 무엇으로도 안 부서진다."},
	{"name": "마을 종탑", "ammo": {"fire": 2}, "villagers": 3,
		"parts": [["bell", Vector3(0, 0, -38)]],
		"story": "마을 종탑 아래 석조 초소에 지휘관이 숨었다. 머리 위 나무 종틀에는 커다란 쇠종이 밧줄 하나에 매달려 있다."},
	{"name": "고블린 화약 창고", "ammo": {"fire": 2}, "villagers": 2,
		"parts": [["powder", Vector3(-2, 0, -40)]],
		"story": "인간들이 고블린의 화약 창고 옆에 금 간 석재 망대를 세웠다. 그 화약이 누구 것이었는지 잊은 모양이다."},
	{"name": "바람 부는 풍차", "ammo": {"fire": 3}, "villagers": 3, "wind": [3, 1, 0],
		"parts": [["windmill", Vector3(0, 0, -38)]],
		"story": "언덕 위 마을 풍차 꼭대기 나무 회랑에 지휘관이 올라섰다. 산바람이 불어 바람자루 마디가 셋 펴졌다. 바람만큼 비켜 던진다. 이제부터는 늘 바람자루를 본다."},
	{"name": "석벽 마당 막사", "ammo": {"he": 2, "fire": 2}, "villagers": 3, "wind": [2, -1, 0],
		"parts": [["courtyard", Vector3(0, 0, -40)]],
		"story": "금 간 석벽으로 두른 마당 안 나무 막사. 석벽의 좁은 창으로 안이 보인다. 벽은 고폭탄, 막사는 화염탄."},
	{"name": "마을 정문 지원", "fixed": "ally", "ammo": {"he": 3, "fire": 2}, "wind": [1, 1, 0],
		"story": "인간들이 마을 정문을 석재 성문으로 막았다. 폭발통을 진 동료 고블린이 정문까지 걷는다. 방패병, 나무 바리케이드, 금 간 석재 울타리를 치워 준다."},
	{"name": "촌장 집 점령군 본부", "ammo": {"fire": 2, "he": 2}, "villagers": 5, "perch": 12.0, "wind": [2, 1, 0],
		"parts": [["fortress", Vector3(0, 0, -58)], ["pillars", Vector3(-15, 0, -46)]],
		"story": "클라이맥스: 점령군이 촌장 집 마당에 나무 공성탑을 세우고 본부로 쓴다. 탑 발치에는 마을에서 걷어 간 화약통. 부관은 옆 금 간 석재 망대에서 지켜본다."},

	# ---------- 2월드: 비 내리는 광산 도시 (늘 비, 기름병) ----------
	{"name": "연료 창고", "ammo": {"oil": 2, "fire": 2}, "wind": [0, 1, 0],
		"parts": [["oilhouse", Vector3(0, 0, -38)]],
		"story": "비 오는 광산 도시의 석조 연료 창고. 바깥 짚 더미에서 젖은 홈통이 안쪽 연료 배관까지 이어진다. 젖은 것은 기름을 부어야 탄다."},
	{"name": "광부 숙소", "ammo": {"oil": 2, "fire": 2}, "wind": [1, -1, 0],
		"parts": [["barn", Vector3(0, 0, -40)]],
		"story": "인간들이 광부 숙소를 막사로 쓴다. 기와 지붕 아래 판자 벽이 비에 흠뻑 젖었다."},
	{"name": "석탄 호퍼", "ammo": {"oil": 2, "fire": 2}, "wind": [1, 1, 0],
		"parts": [["hopper", Vector3(-3, 0, -42)]],
		"story": "지휘관이 석탄 호퍼 밑 돌 칸막이 안에서 비를 피한다. 머리 위에는 석탄을 가득 채운 쇠 통, 그 아래는 젖은 나무 다리 넷."},
	{"name": "무너진 갱도 입구", "ammo": {"he": 2, "oil": 1, "fire": 2}, "wind": [2, -1, 0],
		"parts": [["cave", Vector3(0, 0, -40)]],
		"story": "갱도 입구의 석재 덮개가 금 간 돌기둥과 젖은 나무 버팀목에 얹혀 있다. 기둥은 고폭탄, 젖은 버팀목은 기름과 불로."},
	{"name": "갱도 감시탑 둘", "ammo": {"oil": 3, "fire": 3}, "wind": [2, 1, 0],
		"parts": [["tower", Vector3(-9, 0, -38), {"parapet": true}], ["tower", Vector3(10, 0, -46), {"legs": 5.0, "parapet": true}]],
		"story": "갱도 양쪽 감시탑. 위에는 돌 난간을 둘러 폭탄을 막지만, 탑 다리는 젖은 나무다."},
	{"name": "젖은 화약 창고", "ammo": {"oil": 3, "fire": 3}, "wind": [2, -1, 0],
		"parts": [["powder", Vector3(7, 0, -44)], ["tower", Vector3(-11, 0, -40), {"parapet": true}]],
		"story": "광산 발파용 화약을 넣어 둔 나무 창고가 비에 젖었다. 창고 옆 금 간 석재 망대에 지휘관, 건너편 감시탑에 부관."},
	{"name": "선로 옆 호퍼와 숙소", "ammo": {"oil": 3, "fire": 3}, "wind": [3, 1, 0],
		"parts": [["hopper", Vector3(-10, 0, -46)], ["barn", Vector3(11, 0, -40)]],
		"story": "석탄 선로 옆에 호퍼와 감독관 숙소가 붙어 있다. 둘 다 젖었다."},
	{"name": "바람 부는 채석장", "ammo": {"he": 2, "oil": 2, "fire": 2}, "wind": [4, 1, 0],
		"parts": [["pillars", Vector3(-10, 0, -42)], ["tower", Vector3(11, 0, -48), {"legs": 5.0, "parapet": true}]],
		"story": "비바람 부는 채석장. 금 간 석재 망대 위 지휘관과 젖은 감시탑 위 부관."},
	{"name": "빗속 마당 막사", "ammo": {"he": 2, "oil": 3, "fire": 3}, "wind": [3, -1, 0],
		"parts": [["courtyard", Vector3(2, 0, -46)], ["barn", Vector3(-13, 0, -40)]],
		"story": "석벽 마당 안 젖은 막사와 바깥 광부 숙소. 벽을 부수고, 기름을 높이 띄워 막사에 붓고, 불을 넣는다."},
	{"name": "정련소", "ammo": {"oil": 4, "fire": 4}, "perch": 12.0, "wind": [3, 1, 0],
		"parts": [["fortress", Vector3(0, 0, -60), {"wet": true}], ["hopper", Vector3(-15, 0, -50)], ["barn", Vector3(15, 0, -52)]],
		"story": "클라이맥스: 정련소 석벽 안 젖은 증기탑 위의 지휘관, 석탄 호퍼 밑의 감독관, 숙소 안의 부관. 셋 다."},

	# ---------- 3월드: 밤의 철벽 관문 (늘 밤, 조명탄) ----------
	{"name": "관문 앞 강철 막사", "ammo": {"fire": 2, "flare": 1}, "wind": [1, 1, 0],
		"parts": [["steelhut", Vector3(0, 0, -40)]],
		"story": "밤의 관문 앞. 강철 성벽은 폭탄으로는 못 뚫지만 작은 창으로 막사 안 지휘관이 보인다. 성벽 위로 솟은 짚 지붕에 불을 붙이면 막사째 탄다. 조명탄으로 비춰 본다."},
	{"name": "성벽 기중기", "ammo": {"fire": 2, "flare": 1}, "wind": [2, -1, 0],
		"parts": [["crane", Vector3(0, 0, -42)]],
		"story": "성벽 돌을 올리던 나무 기중기 아래, 가슴 높이 강철 방패 뒤에 지휘관이 섰다. 기중기 팔에는 쇠 상자가 밧줄 하나에 매달려 있다."},
	{"name": "금 간 석재 망대 둘", "ammo": {"he": 3, "flare": 1}, "wind": [2, 1, 0],
		"parts": [["pillars", Vector3(-8, 0, -40)], ["pillars", Vector3(9, 0, -47)]],
		"story": "관문 양쪽의 석재 망대. 망대마다 기둥 하나가 낡아 금이 갔다. 그 기둥을 찾는다."},
	{"name": "관문 성벽 보행로", "ammo": {"he": 2, "flare": 1}, "wind": [2, -1, 1],
		"parts": [["rampart", Vector3(0, 0, -44)]],
		"story": "성벽 위 돌 보행로에 지휘관이 섰다. 바로 아래 밑동 한 칸이 낡아 금이 갔다. 그 칸이 무너지면 보행로째 떨어진다."},
	{"name": "강철 방벽과 숨은 화약통", "ammo": {"fire": 3, "flare": 1}, "wind": [3, 1, 0],
		"parts": [["kegyard", Vector3(0, 0, -46)]],
		"story": "지휘관 둘이 강철 방벽 뒤에서 작은 창으로 밖을 내다본다. 방벽 뒤 둘 사이에 큰 화약통을 숨겨 두었는데, 도화선이 방벽 옆으로 삐져나와 있다. 도화선 끝에 불을 붙이면 방벽도 지휘관도 한꺼번에 날아간다."},
	{"name": "병영 천막", "ammo": {"fire": 4, "flare": 2}, "wind": [3, -1, 0],
		"parts": [["tent", Vector3(-10, 0, -42)], ["tent", Vector3(1, 0, -49)], ["tent", Vector3(12, 0, -44)]],
		"story": "관문 안 병영에 짚 천막 셋, 천막마다 지휘관이 하나씩 잔다. 어둠 속 거리가 다 다르다."},
	{"name": "기중기와 망루", "ammo": {"fire": 3, "flare": 1}, "wind": [3, 1, -1],
		"parts": [["crane", Vector3(-9, 0, -44)], ["tower", Vector3(10, 0, -50), {"legs": 5.0}]],
		"story": "밤에도 성벽 공사를 감독하는 지휘관과 높은 망루의 부관. 뒷바람이 비스듬히 분다."},
	{"name": "성벽과 망대", "ammo": {"he": 3, "fire": 2, "flare": 2}, "wind": [3, -1, 0],
		"parts": [["rampart", Vector3(-10, 0, -48)], ["pillars", Vector3(10, 0, -52)], ["tent", Vector3(0, 0, -40)]],
		"story": "성벽 보행로, 석재 망대, 그 앞 천막. 지휘관 셋."},
	{"name": "보급 마당", "ammo": {"fire": 4, "flare": 2}, "wind": [4, 1, 0],
		"parts": [["kegyard", Vector3(-9, 0, -50)], ["steelhut", Vector3(11, 0, -44)]],
		"story": "관문 보급 마당. 화약통을 숨긴 강철 방벽 뒤의 지휘관 둘과 강철 성벽 뒤 막사의 보급관."},
	{"name": "철벽 관문 본루", "ammo": {"fire": 3, "he": 3, "flare": 2}, "perch": 10.0, "wind": [4, -1, 0],
		"parts": [["fortress", Vector3(0, 0, -62)], ["windowpost", Vector3(-14, 0, -50)], ["crane", Vector3(14, 0, -52)]],
		"story": "클라이맥스: 밤의 관문 본루. 안뜰 공성탑의 지휘관, 석벽 초소의 부관, 기중기 밑의 공병대장."},

	# ---------- 4월드: 대공 요새 (장거리, 조명탄을 보고 날아오는 글라이더 폭격, 발리스타) ----------
	{"name": "먼 강철 벙커", "ammo": {"flare": 2}, "bombers": 2, "perch": 16.0, "wind": [2, 1, 0],
		"parts": [["bunker", Vector3(0, 0, -82)]],
		"story": "골짜기 건너 강철 벙커. 폭탄이 닿지도 않고 닿아도 안 부서진다. 글라이더를 멘 동료 고블린이 옆에서 기다린다. 조명탄을 벙커 근처에 떨어뜨리면 그 불빛을 보고 날아가 폭탄을 안고 뛰어내린다."},
	{"name": "골짜기 건너 망루", "ammo": {"fire": 3}, "perch": 20.0, "wind": [4, 1, 0],
		"parts": [["tower", Vector3(0, 0, -66), {"legs": 5.0}]],
		"story": "바람 부는 골짜기 건너 나무 망루. 화염탄이 겨우 닿는 거리다. 페인트탄으로 먼저 재 본다."},
	{"name": "나무 발리스타", "ammo": {"fire": 2, "flare": 2}, "bombers": 2, "perch": 18.0, "wind": [3, -1, 0],
		"ballistas": [[Vector3(-8, 0, -56), "wood"]],
		"parts": [["bunker", Vector3(0, 0, -92)], ["tent", Vector3(7, 0, -95)]],
		"story": "벙커와 옆 천막의 지휘관 둘은 폭격 한 번이면 끝난다. 하지만 발리스타가 서 있으면 글라이더를 쏘아 떨어뜨린다. 나무 발리스타 탑부터 태운다."},
	{"name": "석재 발리스타", "ammo": {"he": 2, "flare": 2}, "bombers": 2, "perch": 18.0, "wind": [3, 1, 0],
		"ballistas": [[Vector3(9, 0, -52), "stone"]],
		"parts": [["bunker", Vector3(-6, 0, -96)], ["hut", Vector3(2, 0, -101)]],
		"story": "금 간 석재 기둥 위의 발리스타. 고폭탄으로 금 간 기둥을 부순 뒤 벙커와 오두막 사이에 조명탄을 떨어뜨린다."},
	{"name": "골짜기 오두막과 종탑", "ammo": {"fire": 3}, "perch": 20.0, "wind": [4, -1, 0],
		"parts": [["hut", Vector3(-10, 0, -62)], ["bell", Vector3(12, 0, -66)]],
		"story": "요새 아래 골짜기 마을. 오두막 안의 지휘관과 종탑 초소 안의 부관. 둘 다 사거리 끝이다. 폭격대는 여기까지 오지 않는다."},
	{"name": "두 벙커", "ammo": {"fire": 3, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [3, 1, 1],
		"ballistas": [[Vector3(-7, 0, -56), "wood"], [Vector3(8, 0, -60), "wood"]],
		"parts": [["bunker", Vector3(-6, 0, -98)], ["bunker", Vector3(6, 0, -94)]],
		"story": "나란히 선 벙커 둘을 나무 발리스타 둘이 지킨다. 발리스타를 모두 태우고 두 벙커 사이에 조명탄을 떨어뜨린다."},
	{"name": "망대와 풍차", "ammo": {"he": 2, "fire": 3}, "perch": 22.0, "wind": [3, -1, 0],
		"parts": [["pillars", Vector3(-14, 0, -58)], ["windmill", Vector3(8, 0, -66)]],
		"story": "옆바람이 부는 요새 앞 들판. 석재 망대의 지휘관과 풍차 회랑의 부관."},
	{"name": "요새 포대", "ammo": {"fire": 3, "he": 2, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [4, 1, 0],
		"ballistas": [[Vector3(-10, 0, -58), "wood"], [Vector3(10, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -104)], ["tower", Vector3(9, 0, -100)]],
		"story": "나무와 석재 발리스타가 지키는 먼 벙커와 그 옆 망루의 포대장."},
	{"name": "절벽 굴과 벙커", "ammo": {"he": 3, "flare": 2}, "bombers": 2, "perch": 18.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(-14, 0, -52), "stone"]],
		"parts": [["cave", Vector3(-5, 0, -98)], ["bunker", Vector3(6, 0, -92)]],
		"story": "절벽 밑 감시굴과 그 옆 벙커. 석재 발리스타 하나가 지킨다."},
	{"name": "대공 요새 본루", "ammo": {"fire": 4, "he": 2, "flare": 2}, "bombers": 2, "perch": 25.0, "wind": [4, 1, 0],
		"ballistas": [[Vector3(-12, 0, -62), "wood"], [Vector3(12, 0, -60), "stone"], [Vector3(0, 0, -70), "wood"]],
		"parts": [["bunker", Vector3(0, 0, -110)], ["tower", Vector3(-9, 0, -106), {"legs": 5.0}]],
		"story": "클라이맥스: 발리스타 셋이 지키는 대공 요새 본루 벙커와 그 옆 망루의 포대장."},

	# ---------- 5월드: 왕국 성채 (모든 기믹, 지휘관 여럿) ----------
	{"name": "왕성 외곽 밤바람", "ammo": {"fire": 5, "flare": 2}, "night": true, "wind": [4, 1, 0],
		"parts": [["steelhut", Vector3(-11, 0, -44)], ["crane", Vector3(11, 0, -48)], ["tower", Vector3(0, 0, -56), {"legs": 5.0}]],
		"story": "밤바람 부는 왕성 외곽. 강철 성벽 뒤 막사, 기중기 밑, 높은 망루에 지휘관 셋."},
	{"name": "빗속 왕실 창고", "ammo": {"he": 3, "oil": 2, "fire": 2}, "rain": true, "wind": [3, -1, 0],
		"parts": [["barn", Vector3(-12, 0, -44)], ["hopper", Vector3(12, 0, -48)], ["windowpost", Vector3(0, 0, -40)]],
		"story": "비 오는 왕실 창고 거리. 젖은 창고, 석탄 호퍼, 석벽 초소에 지휘관 셋."},
	{"name": "밤의 왕실 마구간 마당", "ammo": {"he": 2, "fire": 4, "flare": 1}, "night": true, "wind": [4, -1, 0],
		"parts": [["courtyard", Vector3(0, 0, -48)], ["powder", Vector3(-17, 0, -42)], ["hut", Vector3(14, 0, -44)]],
		"story": "바람 부는 밤의 왕실 마구간 마당. 석벽 마당 막사, 화약 창고 옆 망대, 마부 오두막."},
	{"name": "빗속 밤의 채석장", "ammo": {"he": 2, "oil": 2, "fire": 5, "flare": 2}, "night": true, "rain": true, "wind": [4, 1, 0],
		"parts": [["cave", Vector3(0, 0, -50)], ["kegyard", Vector3(-15, 0, -44)], ["tower", Vector3(15, 0, -52), {"parapet": true}]],
		"story": "비 오는 밤의 성채 채석장. 감시굴, 화약통을 숨긴 강철 방벽 뒤의 둘(도화선은 기름 먹인 밧줄이라 비에도 탄다), 젖은 감시탑. 지휘관 넷."},
	{"name": "빗속 성채 포대", "ammo": {"he": 5, "oil": 1, "fire": 2, "flare": 2}, "bombers": 2, "rain": true, "perch": 20.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(0, 0, -64), "wood"], [Vector3(-12, 0, -56), "stone"], [Vector3(12, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(-7, 0, -96)], ["bunker", Vector3(7, 0, -100)], ["pillars", Vector3(0, 0, -104)]],
		"story": "비 오는 성채 포대. 발리스타 셋(나무 탑은 젖어 기름이 필요하다)이 지키는 벙커 둘과 그 뒤 석재 망대. 발리스타만 다 치우면 폭격 한 번으로 끝난다."},
	{"name": "밤바람 부는 종루 광장", "ammo": {"fire": 3, "he": 2, "flare": 1}, "night": true, "perch": 10.0, "wind": [5, 1, 0],
		"parts": [["rampart", Vector3(-12, 0, -48)], ["windmill", Vector3(12, 0, -52)], ["bell", Vector3(0, 0, -58)]],
		"story": "강풍 부는 밤의 성채 광장. 바람자루가 끝까지 펴졌다. 성벽 보행로, 풍차 회랑, 종루 초소에 지휘관 셋."},
	{"name": "밤의 근위대 막사", "ammo": {"fire": 6, "flare": 2}, "night": true, "wind": [4, -1, 0],
		"parts": [["tent", Vector3(-12, 0, -40)], ["tent", Vector3(-4, 0, -48)], ["steelhut", Vector3(12, 0, -44)], ["crane", Vector3(5, 0, -52)]],
		"story": "밤, 근위대 막사 구역. 천막 둘, 강철 성벽 뒤 막사, 기중기 밑. 지휘관 넷."},
	{"name": "빗속 정련 골목", "ammo": {"oil": 4, "fire": 4}, "rain": true, "wind": [4, 1, 0],
		"parts": [["oilhouse", Vector3(-12, 0, -42)], ["hopper", Vector3(10, 0, -46)], ["tower", Vector3(0, 0, -58), {"parapet": true}]],
		"story": "비바람 부는 성채 정련 골목. 연료 창고, 석탄 호퍼, 젖은 감시탑."},
	{"name": "빗속 원거리 포대", "ammo": {"fire": 3, "he": 4, "oil": 3, "flare": 2}, "bombers": 2, "rain": true, "perch": 20.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(-10, 0, -58), "wood"], [Vector3(10, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -100)], ["windowpost", Vector3(-16, 0, -50)], ["tower", Vector3(16, 0, -54)]],
		"story": "비 오는 성채 포대. 발리스타 둘이 지키는 먼 벙커는 폭격으로, 가까운 석벽 초소와 젖은 망루는 직접."},
	{"name": "왕국 성채 본진", "ammo": {"fire": 4, "he": 4}, "launch_button": true, "perch": 20.0, "final": true, "wind": [5, 1, 0],
		"ballistas": [[Vector3(-12, 0, -56), "wood"], [Vector3(12, 0, -54), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -96)], ["fortress", Vector3(-16, 0, -66)], ["pillars", Vector3(15, 0, -57)]],
		"story": "최종: 부족장이 갇힌 성채. 고블린들의 비장의 거대 로켓이 딱 한 발 있다. 발리스타를 모두 무너뜨린 뒤 옆의 크고 빨간 발사 버튼을 누르면, 성채에 남은 장군을 모두 한꺼번에 날려 버린다 (부족장이 휘말려도 고블린은 개의치 않는다)."},
]
const COUNT := 50


static func label(i: int) -> String:
	return "%d-%d" % [i / 10 + 1, i % 10 + 1]


static func title(i: int) -> String:
	return STAGES[i].name


static func world_of(i: int) -> int:
	return i / 10


static func is_rain(i: int) -> bool:
	return STAGES[i].get("rain", WORLD_RAIN[world_of(i)])


static func is_night(i: int) -> bool:
	return STAGES[i].get("night", WORLD_NIGHT[world_of(i)])


## 바람 (m/s²): 단계 × 한 단계 세기, 방향은 수평으로 정규화.
static func wind_of(i: int) -> Vector3:
	var w: Array = STAGES[i].get("wind", [0, 1, 0])
	var dir := Vector3(w[1], 0, w[2]).normalized()
	return dir * Stage.WIND_STEP * float(w[0])


## 지휘관 수 (부품마다 세우는 수의 합).
static func commander_count(i: int) -> int:
	var d: Dictionary = STAGES[i]
	if d.get("fixed", "") == "ally":
		return 1
	var n := 0
	for part in d.parts:
		n += COMMANDERS_OF.get(part[0], 1)
	return n


## 페인트탄 수: 기본 하나 + 지휘관 하나에 하나씩.
static func paint_count(i: int) -> int:
	return 1 + commander_count(i)


static func build(i: int, s: Stage) -> void:
	var d: Dictionary = STAGES[i]
	s.world = world_of(i)
	if d.get("fixed", "") == "ally":
		StageDefs._e11(s)
	else:
		s.begin(label(i), d.name, false)
		s.set_zone(Vector3(0, d.get("perch", HILL), d.get("zone", 0.0)), Vector2(3.0, 3.0))
		for b in d.get("ballistas", []):
			_ballista(s, b[0], b[1])
		for part in d.parts:
			var opts: Dictionary = part[2] if part.size() > 2 else {}
			var c0 := s.commanders.size()
			var st0 := s.structures.size()
			Callable(Campaign, "_part_" + part[0]).call(s, part[1], opts)
			var blocks := []
			for k in range(st0, s.structures.size()):
				blocks.append_array(s.structures[k].blocks)
			var alts := _needs(part[0], blocks, is_rain(i))
			# 폭격 무리 안의 지휘관은 폭격으로도, 최종 진지는 발사 버튼으로도 쓰러뜨릴 수 있다
			var extra := []
			if d.get("bombers", 0) > 0 and (part[0] == "bunker" or _in_rocket_cluster(d, part[1])):
				extra.append(Stage.NEED_BOMBER)
			if d.get("launch_button", false):
				extra.append(Stage.NEED_BUTTON)
			for kind in extra:
				var alt := [{"kinds": [kind]}]
				for b in s.ballistas:
					var wood: bool = b.mat == M.WOOD_BEAM and b.structure.blocks.any(func(x): return x.mat == M.WOOD_BEAM and x.size.y > 4.0)
					alt.append({"kinds": [K.FIRE, K.HE] if wood else [K.HE], "blocks": [b], "mode": "gone"})
				alts.append(alt)
			for k in range(c0, s.commanders.size()):
				s.set_needs(s.commanders[k], alts)
		if d.get("final", false):
			_cage(s, d.parts[0][1] + Vector3(-6.5, 0, 1.0))
		_extras(s, d, world_of(i))
	s.ammo_slots.clear()
	var ammo_of := {"fire": FIRE, "he": HE, "oil": OIL, "flare": FLARE}
	for key in ["fire", "he", "oil", "flare"]:
		if d.ammo.has(key):
			s.add_ammo(ammo_of[key], d.ammo[key])
	s.add_ammo(PAINT, paint_count(i))
	s.add_bombers(d.get("bombers", 0))
	if d.get("launch_button", false):
		s.add_launch_button()
	s.wind = wind_of(i)
	if d.has("wind"):
		var pp := s.player.position
		s.add_windsock(Vector3(pp.x + 4.5, pp.y, pp.z - 2.0))
	if is_rain(i):
		s.make_rain()
		# 비 맞는 나무와 짚은 모두 젖는다 (화약통·연료관·도화선은 그대로)
		for st in s.structures:
			for b in st.blocks:
				b.make_wet()
	if is_night(i):
		s.night = true
		_torches(s)
	for k in d.get("villagers", 0):
		s.add_villager(Vector3(-16 + k * 6.0, 0, -20 - (k % 2) * 3), 180.0 + (k - 2) * 15.0)
	s.finish_build()
	s.stage_id = label(i)
	s.title = "%s · %s" % [label(i), d.name]


## 배경 고블린 (판정과 무관). 화약통·폭발통 곁에서는 "여기야!" 하고 손짓하는 고블린 (휘말려도 개의치 않는다),
## 1월드에서는 인간 건물 앞에서 병사와 싸우거나 돌멩이를 던지는 마을 고블린.
static func _extras(s: Stage, d: Dictionary, world: int) -> void:
	var GE := GoblinExtra.Mode
	var n := 0
	for part in d.parts:
		var c: Vector3 = part[1]
		var opts: Dictionary = part[2] if part.size() > 2 else {}
		match part[0]:
			"powder":
				s.add_extra(c + Vector3(5.6, 0, 2.2), 200.0, GE.WAVE, c + Vector3(3.6, 0.5, -0.6))
			"fortress":
				if not opts.get("wet", false):
					# 성벽 위에 올라서서 안뜰의 화약통을 가리킨다
					s.add_extra(c + Vector3(2.25, 4.5, 6.0), 180.0, GE.WAVE, c + Vector3(0, 0.4, 2.3))
			"kegyard":
				s.add_extra(c + Vector3(KEG_FUSE_X + 1.0, 0, 5.0), 200.0, GE.WAVE, c + Vector3(KEG_FUSE_X, 0, 5.4))
			"hopper":
				s.add_extra(c + Vector3(2.7, 0, 1.8), 210.0, GE.WAVE, c + Vector3(0, 4.4, 0))
		if world == 0 and n < 2:
			var side := -1.0 if c.x > 0.0 else 1.0
			s.add_extra(c + Vector3(side * 4.5, 0, 6.0), 90.0 * side, GE.FIGHT)
			s.add_extra(c + Vector3(-side * 3.0, 0, 7.5), 0.0, GE.THROW)
			n += 1


## 부품의 지휘관을 쓰러뜨릴 수 있는 길들 (클리어 불가 판정용). 길 = 조건 묶음, 조건 = {kinds, blocks, mode}:
## kinds 중 하나라도 남아 있으면 되고, mode "gone"은 blocks가 다 없어졌으면, "oiled"는 하나라도 기름이 묻었거나 탔으면 이미 된 것.
## 일부러 너그럽게 잡는다: 정말 방법이 없을 때만 실패시킨다 (예: 금 간 석벽 초소에 고폭탄이 다 떨어짐, 비 오는데 기름이 다 떨어짐).
static func _needs(kind: String, blocks: Array, rain: bool) -> Array:
	var cracked := blocks.filter(func(b): return b.mat == M.CRACKED)
	var wet := blocks.filter(func(b): return b.mat in [M.WOOD_THIN, M.WOOD_BEAM, M.STRAW] or (b.mat == M.KEG and b.has_meta("rain_wets")))
	# 불로 태우는 길 (비가 오면 젖은 것에 기름부터)
	var burn := [{"kinds": [K.FIRE]}]
	if rain and not wet.is_empty():
		burn = [{"kinds": [K.OIL], "blocks": wet, "mode": "oiled"}, {"kinds": [K.FIRE]}]
	var he := [{"kinds": [K.HE]}]
	var any_bomb := [{"kinds": [K.HE, K.FIRE]}]
	var break_wall := {"kinds": [K.HE], "blocks": cracked, "mode": "gone"}
	match kind:
		"windowpost":
			# 금 간 앞벽을 고폭탄으로 날린 뒤에야 맞힐 수 있다
			return [[break_wall, any_bomb[0]]]
		"pillars", "rampart":
			return [any_bomb]
		"oilhouse":
			var trough := blocks.filter(func(b): return b.mat == M.WOOD_WET)
			return [[{"kinds": [K.OIL], "blocks": trough, "mode": "oiled"}, {"kinds": [K.FIRE]}]]
		"cave":
			var props := blocks.filter(func(b): return b.mat in [M.WOOD_BEAM, M.WOOD_WET])
			var by_he := [break_wall, {"kinds": [K.HE], "blocks": props, "mode": "gone"}]
			var by_fire := [break_wall] + burn
			return [by_he, by_fire]
		"bunker":
			# 강철 벙커는 폭격(또는 최종 로켓)으로만
			return []
	return [burn, he]


## 부품마다 세우는 지휘관 수 (풀이에서 지휘관 번호를 셀 때 쓴다).
const COMMANDERS_OF := {"kegyard": 2}


## 폭격 진지에서 첫 벙커 둘레 ROCKET_CLUSTER 안의 부품인지 (폭격 한 번으로 끝나는 무리).
static func _in_rocket_cluster(d: Dictionary, pos: Vector3) -> bool:
	if d.get("bombers", 0) <= 0:
		return false
	for part in d.parts:
		if part[0] == "bunker":
			return part[1].distance_to(pos) < ROCKET_CLUSTER
	return false


## 설계상 풀이: [[탄종, 목표, 높이 띄우기, 던진 뒤 기다림(초)], ...] (테스트가 실제로 던져 본다).
## 목표가 정수면 그 번호 지휘관의 지금 자리. ["ally"]는 지원형 풀이.
## 순서: 발리스타 → 폭격 무리 밖의 부품 → 폭격 무리 한가운데에 조명탄 한 발 (발리스타가 다 쓰러진 뒤).
## 최종 진지: 발리스타 → ["button"] (발사 버튼을 누른다).
static func plan(i: int) -> Array:
	var d: Dictionary = STAGES[i]
	if d.get("fixed", "") == "ally":
		return [["ally"]]
	var rain := is_rain(i)
	var out := []
	for b in d.get("ballistas", []):
		var bp: Vector3 = b[0]
		if b[1] == "wood":
			if rain:
				out.append([K.OIL, bp + Vector3(0, 1.5, 1.4), false, 0.3])
			out.append([K.FIRE, bp + Vector3(0, 1.5, 1.4), false, 0.0])
		else:
			out.append([K.HE, bp + Vector3(-1.2, 1.0, 1.7), false, 0.0])
	if not out.is_empty():
		# 발리스타 탑이 다 타서 무너질 때까지 기다린다
		out[out.size() - 1][3] = 10.0
	if d.get("launch_button", false):
		out.append(["button"])
		return out
	var ci := 0
	var cluster := []
	for part in d.parts:
		var opts: Dictionary = part[2] if part.size() > 2 else {}
		if part[0] == "bunker" or _in_rocket_cluster(d, part[1]):
			cluster.append(part[1])
		else:
			out.append_array(_part_plan(part[0], part[1], opts, rain, ci))
		ci += COMMANDERS_OF.get(part[0], 1)
	if not cluster.is_empty():
		var center := Vector3.ZERO
		for p in cluster:
			center += p
		center /= cluster.size()
		out.append([K.FLARE, center + Vector3(0, 0.3, 0), false, 0.0])
	return out


static func _part_plan(kind: String, c: Vector3, o: Dictionary, rain: bool, ci: int) -> Array:
	var out := []
	match kind:
		"tower":
			if rain:
				out.append([K.OIL, c + Vector3(0, 1.5, 1.6), false, 0.3])
			out.append([K.FIRE, c + Vector3(0, 1.5, 1.5), false, 0.0])
		"hut":
			if rain:
				out.append([K.OIL, c + Vector3(1.2, 1.0, 2.1), false, 0.3])
			out.append([K.FIRE, c + Vector3(1.2, 1.0, 2.1), false, 0.0])
		"shelter":
			out.append([K.FIRE, c + Vector3(0, 2.9, 0), false, 6.0])
			out.append([K.FIRE, ci, true, 0.0])
		"windowpost":
			out.append([K.HE, c + Vector3(1.2, 1.5, 2.8), false, 3.0])
			out.append([K.HE, ci, false, 0.0])
		"bell":
			out.append([K.FIRE, c + Vector3(0, 7.5, -0.1), false, 0.0])
		"powder":
			if rain:
				out.append([K.OIL, c + Vector3(3.6, 2.2, 0.4), false, 0.3])
			out.append([K.FIRE, c + Vector3(3.6, 2.2, 0.4), false, 0.0])
		"windmill":
			out.append([K.FIRE, c + Vector3(0, 5.5, 1.35), false, 0.0])
		"courtyard":
			out.append([K.HE, c + Vector3(0, 1.5, 4.7), false, 2.0])
			if rain:
				out.append([K.OIL, c + Vector3(0, 2.9, 0), true, 0.3])
			out.append([K.FIRE, ci, true, 0.0])
		"pillars":
			out.append([K.HE, c + Vector3(-1.4, 1.0, 1.9), false, 0.0])
		"fortress":
			if o.get("wet", false):
				out.append([K.OIL, c + Vector3(0, 1.5, 1.5), true, 0.3])
				out.append([K.FIRE, c + Vector3(0, 1.5, 1.5), true, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(0, 0.7, 2.3), true, 0.0])
		"oilhouse":
			out.append([K.OIL, c + Vector3(0.3, 0.3, 5.0), false, 0.3])
			out.append([K.FIRE, c + Vector3(0.3, 1.0, 7.6), false, 0.0])
		"barn":
			if rain:
				out.append([K.OIL, c + Vector3(0, 1.0, 2.15), false, 0.3])
			out.append([K.FIRE, c + Vector3(0, 1.0, 2.15), false, 0.0])
		"hopper":
			if rain:
				# 젖은 화약통에 기름을 붓고 불
				out.append([K.OIL, c + Vector3(0, 4.4, 0.75), false, 0.3])
				out.append([K.FIRE, c + Vector3(0, 4.4, 0.75), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(0, 1.5, 1.8), false, 0.0])
		"cave":
			out.append([K.HE, c + Vector3(-3.2, 2.2, 2.05), false, 2.0])
			if rain:
				out.append([K.OIL, c + Vector3(3.2, 2.2, 1.9), false, 0.3])
			out.append([K.FIRE, c + Vector3(3.2, 2.2, 1.9), false, 0.0])
		"steelhut":
			# 성벽 위로 솟은 짚 지붕에 불 → 막사가 타며 안의 지휘관도 탄다
			out.append([K.FIRE, c + Vector3(0, 2.9, -0.4), false, 0.0])
		"crane":
			# 쇠 상자를 매단 팔 끝 (밧줄이 붙은 곳)
			out.append([K.FIRE, c + Vector3(-0.3, 8.7, 0), false, 0.0])
		"rampart":
			out.append([K.HE, c + Vector3(0, 1.0, 1.7), false, 0.0])
		"kegyard":
			# 방벽 옆으로 삐져나온 도화선 끝에 불 → 숨은 화약통이 터져 방벽과 지휘관 둘이 한꺼번에 날아간다
			out.append([K.FIRE, c + Vector3(KEG_FUSE_X, 0.1, 4.8), false, 0.0])
		"tent":
			out.append([K.FIRE, c + Vector3(0, 1.9, 0), false, 0.0])
	return out


# ---------- 부품 (위치 c는 대개 지휘관 자리) ----------

## 나무 망루. 다리에 불이 붙으면 번져 올라가 지휘관이 떨어진다. parapet: 위 난간이 돌 (폭탄과 불을 막는다).
static func _part_tower(s: Stage, c: Vector3, o: Dictionary) -> void:
	var legs: float = o.get("legs", 4.0)
	var st := s.add_structure()
	StageDefs.watchtower(st, c, legs)
	if o.get("parapet", false):
		for b in st.blocks.duplicate():
			if b.mat == M.WOOD_THIN and b.position.y > legs + 0.4 and b.position.y < legs + 1.8 and (b.size.x < 0.15 or b.size.z < 0.15):
				st.blocks.erase(b)
				var size: Vector3 = b.size
				var pos: Vector3 = b.position
				b.free()
				st.add_block(M.STONE, pos, size)
	# 나무 다리 넷 중 둘 이상을 잃으면 그쪽으로 기울어 넘어간다
	_legs(st, func(b): return b.mat == M.WOOD_BEAM and absf(b.size.y - legs) < 0.01, 1)
	s.add_commander(c + Vector3(0, legs + 0.3, 0), 180.0, Vector3(0.9, 0, 0.6))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 짚 지붕 판자 오두막 (앞벽 가운데 창문). 벽이 타면 안의 지휘관도 탄다.
static func _part_hut(s: Stage, c: Vector3, _o: Dictionary) -> void:
	StageDefs.hut(s.add_structure(), c, 2.0, 2.6)
	s.add_commander(c + Vector3(0, 0, -0.3), 180.0, Vector3(2.8, 0, 1.0))


## 대장간 차양: 목책(문 열림) 뒤 석재 기둥 위 두꺼운 나무 지붕.
static func _part_shelter(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	StageDefs.palisade(st, c + Vector3(0, 0, 4.2), 7.0, 2.6, 1.6)
	StageDefs.shelter(st, c)
	s.add_commander(c)
	s.add_guard(c + Vector3(-5, 0, 2), 180.0)
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## 석벽 초소 (E4): 창문 난 금 간 석벽 + 강철 기둥과 강철 지붕. 고폭탄으로 벽을 날리고 직격한다.
static func _part_windowpost(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	# 눈높이의 좁은 창 (안이 보이지만 폭탄을 넣기는 어렵다)
	StageDefs.window_wall(st, M.CRACKED, c + Vector3(0, 0, 2.65), 6.0, [1.2, 0.45, 1.35], 5, [2], 0.5)
	for sx in [-1, 1]:
		for z in [1.9, -2.2]:
			st.add_block(M.STEEL, c + Vector3(sx * 2.6, 1.5, z), Vector3(0.5, 3.0, 0.5))
	st.add_block(M.STEEL, c + Vector3(0, 3.15, 0.0), Vector3(6.0, 0.3, 5.0))
	s.add_commander(c + Vector3(0, 0, -0.9), 180.0, Vector3(1.2, 0, -1.0))


## 종탑: 석조 초소 + 나무 종틀에 밧줄로 매단 쇠종. 밧줄을 태우면 종이 지붕을 뚫고 떨어진다.
static func _part_bell(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var half := 2.2
	var wall_h := 2.6
	StageDefs.window_wall(st, M.STONE, c + Vector3(0, 0, half - 0.2), half * 2.0, [1.1, 0.7, 0.8], 5, [2], 0.4)
	st.add_block(M.STONE, c + Vector3(0, wall_h * 0.5, -half + 0.2), Vector3(half * 2.0, wall_h, 0.4))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * (half - 0.2), wall_h * 0.5, 0), Vector3(0.4, wall_h, half * 2.0 - 0.8))
	# 나무 지붕. 가운데에 종 줄이 지나는 구멍 (종이 떨어지면 곧장 아래로)
	var hole := Vector2(-1.35, 0.15)
	for i in 7:
		var x := -half + (i + 0.5) * half * 2.0 / 7
		var w := half * 2.0 / 7
		if i >= 2 and i <= 4:
			var front := half - hole.y
			var back := hole.x + half
			st.add_block(M.WOOD_THIN, c + Vector3(x, wall_h + 0.08, hole.y + front * 0.5), Vector3(w, 0.16, front))
			st.add_block(M.WOOD_THIN, c + Vector3(x, wall_h + 0.08, -half + back * 0.5), Vector3(w, 0.16, back))
			continue
		st.add_block(M.WOOD_THIN, c + Vector3(x, wall_h + 0.08, 0), Vector3(w, 0.16, half * 2.0))
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


## 화약고: 석재 망대(창고 쪽 앞 기둥 하나만 금이 갔다) + 발치의 나무 창고 안 화약통.
## 창고가 타면 화약통이 터져 금 간 기둥이 부러지고, 기둥 하나만 잃어도 망대가 기운다.
static func _part_powder(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var h := 4.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED if sx == 1 and sz == 1 else M.STONE, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	var deck := st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	deck.support_ratio = 1.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.STONE, c + Vector3(sx * 1.6, h + 1.5, sz * 1.6), Vector3(0.3, 2.2, 0.3))
	st.add_block(M.STONE, c + Vector3(0, h + 2.75, 0), Vector3(3.6, 0.3, 3.6))
	_legs(st, func(b): return b.start_low < 0.05, 0)
	var shed := s.add_structure()
	StageDefs.hut(shed, c + Vector3(3.6, 0, 0.2), 1.4, 2.0)
	for k in 3:
		shed.add_block(M.KEG, c + Vector3(2.85 + k * 0.75, 0.375, -0.625), Vector3(0.75, 0.75, 0.75))
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 풍차: 돌 밑동 위 나무 기둥 넷이 받친 회랑 (지휘관이 그 위). 앞 기둥 사이 가로대에 불을 붙이면 회랑이 무너진다.
## 날개는 장식 (충돌 없음).
static func _part_windmill(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var base := 4.0
	st.add_block(M.STONE, c + Vector3(0, base * 0.5, 0), Vector3(3.0, base, 3.0))
	var post_h := 3.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, c + Vector3(sx * 1.2, base + post_h * 0.5, sz * 1.2), Vector3(0.35, post_h, 0.35))
	for sz in [-1, 1]:
		st.add_block(M.WOOD_BEAM, c + Vector3(0, base + 1.5, sz * 1.2), Vector3(2.05, 0.25, 0.25))
	var floor_y := base + post_h
	for i in 5:
		var x := -1.6 + (i + 0.5) * 3.2 / 5
		st.add_block(M.WOOD_THIN, c + Vector3(x, floor_y + 0.12, 0), Vector3(0.64, 0.24, 3.2))
	var roof_y := floor_y + 0.24 + 2.2
	for sx in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(sx * 1.45, floor_y + 0.24 + 1.1, -1.45), Vector3(0.2, 2.2, 0.2))
	st.add_block(M.STRAW, c + Vector3(0, roof_y + 0.15, -0.8), Vector3(3.6, 0.3, 2.0))
	_legs(st, func(b): return b.mat == M.WOOD_BEAM and absf(b.size.y - post_h) < 0.01, 1)
	# 날개 (장식)
	var sail := Node3D.new()
	sail.position = c + Vector3(0, roof_y - 0.6, -1.9)
	s.add_child(sail)
	var cloth := Models.mat(Color(0.88, 0.84, 0.74))
	var spar := Models.mat(Color(0.35, 0.24, 0.14))
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		Models.box(sail, Vector3(0.15, 5.0, 0.12), Vector3(sin(a), cos(a), 0) * 2.5, spar, Vector3(0, 0, -a))
		Models.box(sail, Vector3(0.9, 3.6, 0.04), Vector3(sin(a), cos(a), 0) * 2.9 + Vector3(cos(a), -sin(a), 0) * 0.5, cloth, Vector3(0, 0, -a))
	s.add_commander(c + Vector3(0.2, floor_y + 0.24, 0.4), 180.0, Vector3(-1.0, 0, 0.8))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 석벽 마당 막사 (E5): 좁은 창 난 금 간 석벽 + 안쪽 나무 막사.
static func _part_courtyard(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	StageDefs.window_wall(st, M.CRACKED, c + Vector3(0, 0, 4.5), 9.0, [2.0, 0.5, 1.5], 7, [3], 0.5)
	StageDefs.hut(st, c, 2.0, 2.6)
	s.add_commander(c, 180.0, Vector3(3.0, 0, -0.5))


## 석재 망대 (기둥 넷 위 석재 바닥과 난간). 앞 왼쪽 기둥 하나만 금이 갔다.
## 그 기둥 하나만 부러져도 바닥이 기울어 꼭대기 지휘관이 떨어진다.
static func _part_pillars(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var h := 4.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED if sx == -1 and sz == 1 else M.STONE, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	var deck := st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	deck.support_ratio = 1.0
	for sz in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(0, h + 0.8, sz * 1.65), Vector3(3.6, 0.8, 0.3))
	_legs(st, func(b): return b.start_low < 0.05, 0)
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 공성탑 요새: 앞 성벽(반듯한 석재, 강철 문) 너머 안뜰의 나무 탑.
## 기본은 탑 발치에 화약통 (높이 띄워 넣는다). wet: 화약통 없이 돌 난간 두른 탑 (기름과 불을 높이 띄워 넣는다).
static func _part_fortress(s: Stage, c: Vector3, o: Dictionary) -> void:
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
	var wet: bool = o.get("wet", false)
	_part_tower(s, c, {"legs": 6.0, "parapet": wet})
	if not wet:
		var tower: Structure = s.structures[s.structures.size() - 1]
		for k in 3:
			tower.add_block(M.KEG, c + Vector3(-0.75 + k * 0.75, 0.375, 2.3), Vector3(0.75, 0.75, 0.75))
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## 연료 창고 (E7): 석재 건물 안 지휘관과 연료 배관, 바깥 짚 더미에서 이어진 젖은 홈통.
static func _part_oilhouse(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var half := 3.0
	for x in [-2.25, 2.25]:
		st.add_block(M.STONE, c + Vector3(x, 1.5, half - 0.3), Vector3(1.5, 3.0, 0.6))
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
	st.add_block(M.STRAW, c + Vector3(0.3, 0.5, half + 4.6), Vector3(1.6, 1.0, 1.2))
	for i in 5:
		st.add_block(M.WOOD_WET, c + Vector3(0.3, 0.15, half + 3.5 - i * 1.0), Vector3(0.4, 0.3, 1.0))
	for i in 4:
		st.add_block(M.FUEL, c + Vector3(0.3, 0.15, half - 1.4 - i * 0.8), Vector3(0.3, 0.3, 0.8))
	s.add_commander(c + Vector3(-1.0, 0, -1.2), 180.0, Vector3(-1.2, 0, -0.4))


## 숙소·창고: 판자 벽(창문 둘) + 기와(석재) 지붕. 벽이 타면 안의 지휘관도 탄다.
static func _part_barn(s: Stage, c: Vector3, _o: Dictionary) -> void:
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
	st.add_block(M.STONE, c + Vector3(0, height + 0.15, 0), Vector3(half * 2.0 + 0.3, 0.3, half * 2.0 + 0.3))
	s.add_commander(c + Vector3(0, 0, -0.5), 180.0, Vector3(2.8, 0, 2.8))
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 석탄 호퍼: 나무 다리 넷 위 판자 바닥, 가운데는 석탄을 쏟는 구멍이 뚫렸고 그 위에 큰 화약통(발파용)이 걸쳐 있다.
## 지휘관은 그 밑 돌 칸막이 안 (폭탄과 불이 옆에서 직접 안 닿는다).
## 판자나 다리가 타서 불이 화약통에 옮겨 붙으면 머리 위에서 터진다 (구멍으로 그대로 내려친다).
## 비가 오면 화약통도 젖어 기름을 부어야 탄다. 다리를 둘 이상 잃으면 기울어 넘어간다.
static func _part_hopper(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var legs := 3.6
	var half := 1.8
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, c + Vector3(sx * (half - 0.2), legs * 0.5, sz * (half - 0.2)), Vector3(0.4, legs, 0.4))
	for sz in [-1, 1]:
		st.add_block(M.WOOD_BEAM, c + Vector3(0, 1.5, sz * (half - 0.2)), Vector3(half * 2.0 - 0.8, 0.25, 0.25))
	for i in 5:
		if i == 2:
			continue
		var x := -half + (i + 0.5) * half * 2.0 / 5
		st.add_block(M.WOOD_THIN, c + Vector3(x, legs + 0.15, 0), Vector3(half * 2.0 / 5, 0.3, half * 2.0))
	var keg := st.add_block(M.KEG, c + Vector3(0, legs + 0.3 + 0.5, 0), Vector3(1.4, 1.0, 1.4))
	keg.set_meta("rain_wets", true)
	_legs(st, func(b): return b.mat == M.WOOD_BEAM and absf(b.size.y - legs) < 0.01, 1)
	var booth := s.add_structure()
	# 돌 칸막이 (지휘관 키보다 높아 바깥 불길이 넘어오지 않는다. 쇠 통은 그 안으로 떨어진다)
	var bh := 1.9
	for sz in [-1, 1]:
		booth.add_block(M.STONE, c + Vector3(0, bh * 0.5, sz * 1.2), Vector3(2.7, bh, 0.3))
	for sx in [-1, 1]:
		booth.add_block(M.STONE, c + Vector3(sx * 1.2, bh * 0.5, 0), Vector3(0.3, bh, 2.1))
	s.add_commander(c, 180.0, Vector3(2.4, 0, 0.5))


## 절벽 밑 감시굴 (E6): 석재 덮개가 금 간 돌기둥(왼쪽)과 나무 버팀목(오른쪽)에만 얹혀 있다.
static func _part_cave(s: Stage, c: Vector3, _o: Dictionary) -> void:
	s.add_rock(c + Vector3(0, 6, -4.5), Vector3(14, 12, 4), Color(0.55, 0.47, 0.43))
	s.add_rock(c + Vector3(0, 13, -1.5), Vector3(14, 2, 4), Color(0.47, 0.4, 0.37))
	var st := s.add_structure()
	st.add_block(M.CRACKED, c + Vector3(-3.2, 1.4, 1.6), Vector3(0.9, 2.8, 0.9))
	st.add_block(M.WOOD_BEAM, c + Vector3(3.2, 1.4, 1.6), Vector3(0.55, 2.8, 0.55))
	var cover := st.add_block(M.STONE, c + Vector3(0, 3.2, -0.2), Vector3(7.4, 0.8, 4.6))
	cover.support_ratio = 0.5
	st.add_block(M.STONE, c + Vector3(-0.8, 3.95, -0.8), Vector3(1.6, 0.7, 1.4))
	st.add_block(M.STONE, c + Vector3(1.4, 3.85, 0.2), Vector3(1.1, 0.5, 1.0))
	s.add_rock(c + Vector3(0, 0.8, 2.8), Vector3(7.0, 1.6, 0.8), Color(0.5, 0.43, 0.4))
	s.add_commander(c + Vector3(0, 0, -0.8), 180.0, Vector3(1.0, 0, -0.6))


## 강철 성벽 뒤 나무 막사 (짚 지붕). 성벽은 폭탄으로 안 부서지지만 가운데 작은 창으로 막사 창 너머 지휘관이 보이고,
## 짚 지붕은 성벽보다 높아 밖에서 보인다. 지붕에 불을 붙이면 판자 벽으로 번져 앞벽 바로 뒤의 지휘관도 탄다.
static func _part_steelhut(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var wall := s.add_structure()
	StageDefs.window_wall(wall, M.STEEL, c + Vector3(0, 0, 3.2), 8.0, [1.2, 0.6, 0.8], 5, [2], 0.4)
	var st := s.add_structure()
	StageDefs.hut(st, c, 2.0, 2.6)
	s.add_commander(c + Vector3(0, 0, 1.0), 180.0, Vector3(3.0, 0, 1.0))
	s.add_guard(c + Vector3(-3.5, 0, 2.5), 180.0)


## 성벽 기중기: 나무 기둥과 팔, 팔 끝에 밧줄로 매단 쇠 상자. 지휘관은 그 밑 가슴 높이 강철 방패 뒤 (어깨와 머리가 보인다).
## 밧줄(또는 팔)을 태우면 상자가 떨어진다. 방패 너머로 높이 띄워 직접 맞힐 수도 있다.
static func _part_crane(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var shield := s.add_structure()
	StageDefs.steel_wall(shield, c + Vector3(0, 0, 1.3), 3.0, 1.3, 0.3)
	var st := s.add_structure()
	var top := 8.5
	st.add_block(M.STONE, c + Vector3(-3.0, 0.3, 0), Vector3(1.4, 0.6, 1.4))
	st.add_block(M.WOOD_BEAM, c + Vector3(-3.0, 0.6 + (top - 0.6) * 0.5, 0), Vector3(0.5, top - 0.6, 0.5))
	st.add_block(M.WOOD_BEAM, c + Vector3(-1.2, top + 0.2, 0), Vector3(4.2, 0.4, 0.4))
	var rope := st.add_block(M.ROPE, c + Vector3(0, top - 0.9, 0), Vector3(0.15, 1.8, 0.15))
	rope.hanging = true
	var crate := st.add_block(M.WEIGHT, c + Vector3(0, top - 2.4, 0), Vector3(1.2, 1.2, 1.2))
	crate.hanging = true
	s.add_commander(c, 180.0, Vector3(2.0, 0, -0.5))
	s.add_guard(c + Vector3(3.5, 0, 2.0), 180.0)


## 성벽 보행로: 흰 석재 성벽(2단)에 가운데 밑동 한 칸만 금이 갔다. 지휘관은 그 위 돌 보행로에 선다.
## 금 간 밑동이 부서지면 그 위 칸과 가운데 보행로가 통째로 떨어진다.
static func _part_rampart(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var cols := 5
	var w := 1.6
	for r in 2:
		for k in cols:
			var x := -w * cols * 0.5 + (k + 0.5) * w
			st.add_block(M.CRACKED if r == 0 and k == 2 else M.STONE, c + Vector3(x, 1.0 + r * 2.0, 0.6), Vector3(w, 2.0, 1.2))
	# 보행로는 세 토막 (가운데 토막은 가운데 칸 위에만 얹힌다)
	st.add_block(M.STONE, c + Vector3(0, 4.15, 0.6), Vector3(w, 0.3, 1.6))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * w * 1.5, 4.15, 0.6), Vector3(w * 2.0, 0.3, 1.6))
		for x in [1.8, 3.0]:
			st.add_block(M.STONE, c + Vector3(sx * x, 4.8, 1.25), Vector3(0.8, 1.0, 0.3))
	s.add_commander(c + Vector3(0, 4.3, 0.3), 180.0, Vector3(1.8, 0, -0.1))
	s.add_guard(c + Vector3(-5.5, 0, 3), 180.0)


## 숨은 화약통의 도화선이 방벽 옆으로 삐져나와 앞으로 뻗는 x 위치 (부품 중심 기준)
const KEG_FUSE_X := 5.06


## 강철 방벽과 숨은 화약통: 강철 방벽(눈높이의 작은 창 둘로 안의 지휘관 둘이 보인다) 뒤, 두 지휘관 사이에 큰 화약통을 숨겼다.
## 화약통은 밖에서 안 보이고, 밧줄 도화선이 방벽 오른쪽 끝을 돌아 앞으로 삐져나와 있다.
## 도화선 끝에 불을 붙이면 불이 몇 초 동안 타 들어가 화약통이 터진다: 방벽이 통째로 날아가고 곁의 지휘관 둘도 함께 날아간다.
## (높이 띄워 방벽 너머 화약통 곁에 바로 떨어뜨려도 된다. 어려울 뿐이다.)
static func _part_kegyard(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var wall := s.add_structure()
	StageDefs.window_wall(wall, M.STEEL, c + Vector3(0, 0, 3.0), 9.0, [1.3, 0.5, 1.2], 6, [1, 4], 0.4)
	var yard := s.add_structure()
	var keg := yard.add_block(M.KEG, c + Vector3(0, 0.5, 1.4), Vector3(1.0, 1.0, 0.8))
	keg.set_meta("blast", [9.0, 1000.0])
	# 도화선: 화약통 오른쪽에서 방벽 뒤를 따라 끝까지, 방벽 끝을 돌아 앞으로 (맞닿은 밧줄 토막을 따라 불이 번진다)
	var h := 0.1
	var n := 8
	var x0 := 0.5
	var seg := (KEG_FUSE_X - 0.06 - x0) / n
	for k in n:
		yard.add_block(M.ROPE, c + Vector3(x0 + (k + 0.5) * seg, h * 0.5, 1.4), Vector3(seg, h, 0.12))
	var z0 := 1.34
	var z1 := 5.6
	var m := 7
	var zseg := (z1 - z0) / m
	for k in m:
		yard.add_block(M.ROPE, c + Vector3(KEG_FUSE_X, h * 0.5, z0 + (k + 0.5) * zseg), Vector3(0.12, h, zseg))
	s.add_commander(c + Vector3(-2.25, 0, 0.8), 180.0, Vector3(-1.0, 0, -0.8))
	s.add_commander(c + Vector3(2.25, 0, 0.8), 180.0, Vector3(1.0, 0, -0.8))


## 짚 천막: 짚 벽 셋과 문 난 앞벽, 짚 지붕. 지휘관이 안에서 잔다.
static func _part_tent(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var h := 1.7
	st.add_block(M.STRAW, c + Vector3(0, h * 0.5, -1.2), Vector3(2.6, h, 0.2))
	for sx in [-1, 1]:
		st.add_block(M.STRAW, c + Vector3(sx * 1.2, h * 0.5, 0), Vector3(0.2, h, 2.2))
		st.add_block(M.STRAW, c + Vector3(sx * 0.85, h * 0.5, 1.2), Vector3(0.9, h, 0.2))
	st.add_block(M.STRAW, c + Vector3(0, h + 0.15, 0), Vector3(2.8, 0.3, 2.8))
	s.add_commander(c + Vector3(0, 0, -0.3), 180.0, Vector3(1.8, 0, 1.2))


## 강철 벙커: 무엇으로도 안 부서진다. 플레어건으로 표적을 찍어 미사일을 부른다 (발리스타가 남아 있으면 요격당한다).
static func _part_bunker(s: Stage, c: Vector3, _o: Dictionary) -> void:
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


## 부족장이 갇힌 우리 (판정과 무관한 장식, 최종 진지).
static func _cage(s: Stage, pos: Vector3) -> void:
	var cage := Node3D.new()
	cage.position = pos
	s.add_child(cage)
	cage.add_child(Models.chief())
	var bars := Models.mat(Models.HUMAN_STEEL.darkened(0.3), 0.4, 0.7)
	for k in 8:
		var a := TAU * k / 8.0
		Models.cyl(cage, 0.04, 0.04, 2.2, Vector3(cos(a) * 0.8, 1.1, sin(a) * 0.8), bars)
	Models.cyl(cage, 0.9, 0.9, 0.1, Vector3(0, 2.2, 0), bars, Vector3.ZERO, 10)


## 밤: 지휘관마다 곁에 횃불 하나, 진지 둘레에 둘.
static func _torches(s: Stage) -> void:
	var center := Vector3.ZERO
	for c in s.commanders:
		var p := c.position
		p.y = 0.0
		s.add_torch(p + Vector3(2.8, 0, 2.5))
		center += p
	if not s.commanders.is_empty():
		center /= s.commanders.size()
	for o in [Vector3(-12, 0, 8), Vector3(12, 0, -6)]:
		s.add_torch(center + o)
	# 발리스타 탑 발치에도 (폭격대를 부르기 전에 어디를 먼저 치워야 할지 보이게)
	for b in s.ballistas:
		var p := b.global_position if b.is_inside_tree() else b.position
		s.add_torch(Vector3(p.x + 2.0, 0, p.z + 2.0))


## 대공 발리스타 탑. wood: 나무 다리 (불), stone: 석재 기둥 넷 중 앞 왼쪽 하나만 금이 갔다 (그 하나만 부러뜨리면 기운다).
static func _ballista(s: Stage, pos: Vector3, kind: String) -> void:
	var st := s.add_structure()
	var legs := 5.0
	var wood := kind == "wood"
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var leg_mat := M.WOOD_BEAM if wood else (M.CRACKED if sx == -1 and sz == 1 else M.STONE)
			st.add_block(leg_mat, pos + Vector3(sx * 1.2, legs * 0.5, sz * 1.2), Vector3(0.5, legs, 0.5) if wood else Vector3(0.7, legs, 0.7))
	if wood:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, pos + Vector3(0, 1.5, sz * 1.2), Vector3(1.9, 0.25, 0.25))
	var deck := st.add_block(M.WOOD_THIN if wood else M.STONE, pos + Vector3(0, legs + 0.15, 0), Vector3(3.0, 0.3, 3.0))
	if not wood:
		deck.support_ratio = 1.0
	var b := st.add_block(M.WOOD_BEAM, pos + Vector3(0, legs + 0.55, 0), Vector3(0.6, 0.5, 0.6))
	s.add_ballista(b)
	# 나무 탑은 다리 둘을 잃으면, 석재 탑은 금 간 기둥 하나만 잃어도 그쪽으로 기운다
	_legs(st, func(x): return x.start_low < 0.05, 1 if wood else 0)


## 부품의 다리 묶음 등록 (filter에 맞는 블록이 다리).
static func _legs(st: Structure, filter: Callable, max_lost: int) -> void:
	st.add_leg_group(st.blocks.filter(filter), max_lost)
