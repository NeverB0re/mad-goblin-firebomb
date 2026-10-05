class_name Campaign
extends RefCounted
## 본편: 5개 월드 × 10개 진지 = 50개 (확장 기획서 11장).
##
## 월드마다 배울 것이 정해져 있고, 뒤로 갈수록 기본 난이도가 오른다.
## 기본 기믹은 고폭탄(기본 폭탄)이다: 먼저 "던지면 터지고 터지면 부서진다"를 배우고, 그다음에야 화염 항아리로
## "불은 맞닿은 것을 타고 번진다 = 간접 파괴"를 배운다. 폭탄은 가볍고 멀리 날아 다루기 쉽고, 화염 항아리는 묵직하다.
## - 1월드 점령당한 목책 마을: 폭탄으로 나무 망루 → 금 간 석벽(흰 돌·강철은 안 부서짐) → 지휘관 둘 → 금 간 기둥 하나 고르기
##   → 밧줄 끊어 쇠종 떨어뜨리기 → 화약통 연쇄. 그다음 화염 항아리: 폭탄이 안 통하는 강철 성벽 너머 짚 지붕 → 잇닿은 지붕 따라 번지는 불(+바람)
##   → 지원 → 클라이맥스(도화선).
## - 2월드 비 내리는 광산 도시: 늘 비가 와서 나무와 짚이 젖어 있다. 기름 단지를 먼저 깨뜨려야 탄다.
## - 3월드 밤의 철벽 관문: 늘 밤이다. 조명탄은 몇 초만, 떨어진 둘레만 비춘다 (비추는 동안 던진다, 한 발로 진지 전체를 못 비춘다).
##   그리고 밤의 인간들은 불빛을 보러 나온다: 강철 초소 안의 지휘관을 조명탄으로 꾀어내 화약통 곁이나 빈터에서 맞힌다.
## - 4월드 대공 요새: 높은 고지대에서 아주 먼 표적. 투척 구역 옆에 글라이더 폭격대가 대기하고, 조명탄이 떨어진 자리로 날아가
##   고블린이 폭탄을 안고 뛰어내린다. 아주 크게 터져 근처 지휘관을 한꺼번에 쓰러뜨리지만, 발리스타가 하나라도 서 있으면
##   글라이더가 격추되어 불시착한다(불발) → 발리스타부터 치운다.
## - 5월드 일반 진지는 앞 월드의 특성(비, 밤, 발리스타 폭격) 중 하나 이상이 섞인다. 밤과 발리스타는 같이 두지 않는다.
## - 최종 진지: 거대 로켓 한 발 (궁극기). 발리스타를 다 치운 뒤 옆의 빨간 발사 버튼을 누르면 남은 지휘관을 모두 날린다.
## - 5월드 왕국 성채: 지금까지 나온 기믹을 모두 섞고 지휘관 수를 늘린다.
## 난이도 기준: 거리, 쓰러뜨릴 지휘관 수, 노려야 할 표적의 크기, 궤도의 정확함 (높이 띄워 담 너머 좁은 곳에 떨어뜨리기 등).
## 바람은 월드 기믹이 아니라 난이도 조절 요소다: 1월드 후반(1-8)부터 모든 진지 들판에 고블린 전투 깃발이 서고, 펴진 천 폭 수(0~5단계)가 세기다.
## 페인트탄(기본 폭탄과 같은 궤적, 아무것도 안 부숨, 물감 자국만 남김)은 모든 진지에 준다: 기본 하나 + 지휘관 하나에 하나씩.
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
## 목표 건물(부품·발리스타 탑)을 짓는 배율. 부품 중심 기준으로 자리와 크기를 키운다 (인물 크기는 그대로라 천장이 넉넉해진다).
## 설계 풀이의 겨눌 곳도 같은 배율로 옮긴다.
const PART_SCALE := 1.2


## 부품 중심 c에서 off만큼 떨어진 곳 (부품 배율을 적용한 실제 자리)
static func part_at(c: Vector3, off: Vector3) -> Vector3:
	return c + off * PART_SCALE

const WORLDS := ["점령당한 목책 마을", "비 내리는 광산 도시", "밤의 철벽 관문", "대공 요새", "왕국 성채"]

## 월드 공통 환경 (진지마다 덮어쓸 수 있다)
const WORLD_RAIN := [false, true, false, false, false]
const WORLD_NIGHT := [false, false, true, false, false]

## parts: [[부품, 위치, {선택}], ...]. 부품 이름은 _part_<이름> 함수.
## wind: [단계 0~5, 방향 x, 방향 z] (방향은 바람이 불어 가는 쪽. +x = 오른쪽, +z = 고블린 쪽 = 맞바람).
## bombers: 대기 중인 글라이더 폭격 고블린 수 (조명탄 하나에 한 번). launch_button: 최종 진지의 거대 로켓 발사 버튼.
const STAGES := [
	# ---------- 1월드: 점령당한 목책 마을 (폭탄 = 파괴부터, 그다음 불 = 번지는 간접 파괴) ----------
	{"name": "마을 어귀 망루", "ammo": {"he": 2},
		"parts": [["tower", Vector3(0, 0, -32)]],
		"story": "인간들이 고블린 마을 어귀에 나무 망루를 세우고 지휘관이 올라가 마을을 내려다본다. 던지면 터지고, 터지면 부서진다. 다리를 날리든 지휘관 발치에 떨어뜨리든."},
	{"name": "금 간 석벽 초소", "ammo": {"he": 3},
		"parts": [["windowpost", Vector3(0, 0, -36)]],
		"story": "마을 우물가에 인간들이 쌓은 석벽 초소. 누렇게 바랜 금 간 앞벽은 폭탄에 부서지고, 청회색 강철 지붕은 꿈쩍도 안 한다. 벽부터 날리고 안으로."},
	{"name": "곡식 창고와 보초 망루", "ammo": {"he": 3},
		"parts": [["hut", Vector3(-6, 0, -36)], ["tower", Vector3(8, 0, -42), {"legs": 3.0}]],
		"story": "지휘관 둘: 하나는 곡식 창고 안에서 곡식을 세고(앞 창문이 열려 있다), 하나는 옆 보초 망루에 올라가 있다. 깃발 둘을 다 쓰러뜨려야 한다."},
	{"name": "흰 돌 망대", "ammo": {"he": 2},
		"parts": [["pillars", Vector3(0, 0, -38)]],
		"story": "반듯한 흰 돌은 무엇으로도 안 부서진다. 그런데 이 망대 기둥 넷 중 하나만 누렇게 금이 갔다. 그 하나만 부러뜨리면 망대가 그쪽으로 기운다."},
	{"name": "마을 종탑", "ammo": {"he": 2},
		"parts": [["bell", Vector3(0, 0, -38)]],
		"story": "마을 종탑 아래 석조 초소에 지휘관이 숨었다. 벽은 흰 돌이라 안 깨진다. 그런데 머리 위 나무 종틀에 커다란 쇠종이 밧줄 하나에 매달려 있다."},
	{"name": "고블린 화약 창고", "ammo": {"he": 2},
		"parts": [["powder", Vector3(-2, 0, -40)]],
		"story": "인간들이 고블린의 화약 창고 옆에 금 간 석재 망대를 세웠다. 창고 안 화약통에 폭탄이 닿으면 쾅, 쾅, 쾅. 그 화약이 누구 것이었는지 잊은 모양이다."},
	{"name": "강철 성벽 막사", "ammo": {"fire": 2},
		"parts": [["steelhut", Vector3(0, 0, -38)]],
		"story": "강철 성벽은 폭탄으로 못 뚫는다. 하지만 성벽 위로 솟은 막사 짚 지붕은 탄다. 새 탄: 화염 항아리. 묵직해서 덜 날아가지만, 불은 맞닿은 짚과 나무를 타고 번진다."},
	{"name": "짚 지붕 줄집", "ammo": {"fire": 2}, "wind": [2, 1, 0],
		"parts": [["rowhouses", Vector3(0, 0, -38)]],
		"story": "흰 돌담 안에 지붕이 잇닿은 짚 지붕 집 세 채, 집마다 지휘관이 하나. 한 채에 불이 붙으면 옆집으로 번진다. 산바람이 불기 시작했다: 들판의 깃발이 펴진 폭 수만큼 비켜 던진다. 이제부터는 늘 깃발을 본다."},
	{"name": "촌장 집 점령군 본부", "ammo": {"he": 2, "fire": 2}, "perch": 12.0, "wind": [2, 1, 0],
		"parts": [["fortress", Vector3(0, 0, -54)], ["pillars", Vector3(-15, 0, -44)]],
		"story": "점령군이 촌장 집 마당 흰 돌 성벽 안에 돌 망루를 세우고 본부로 쓴다. 망루 앞면은 창 난 돌벽이라 지휘관이 창으로만 보인다. 금 간 기둥 발치에는 마을에서 걷어 간 화약통, 강철 문 밑으로는 검정·노랑 도화선이 삐져나와 있고, 성문 앞에서 고블린 하나가 도화선을 가리키며 방방 뛴다. 부관은 옆 금 간 석재 망대에서 지켜본다."},
	{"name": "마을 정문 지원", "fixed": "ally", "ammo": {"he": 3, "fire": 2}, "wind": [2, 1, 0],
		"story": "클라이맥스: 인간들이 마을 정문을 강철 성문으로 닫아걸고, 지휘관이 성문 뒤에서 빗장을 붙들고 버틴다. 폭발통을 진 동료 고블린이 심지에 불을 붙이고 정문까지 걷는다(성문 앞에 닿으면 스스로 터진다). 길을 막은 병사들, 폭탄에는 끄떡없는 목책 망루의 통나무 문(불로), 금 간 석재 성벽(폭탄)을 차례로 치워 준다."},

	# ---------- 2월드: 비 내리는 광산 도시 (늘 비: 나무와 짚이 젖어 기름부터) ----------
	{"name": "연료 창고", "ammo": {"oil": 2, "fire": 2}, "wind": [0, 1, 0],
		"parts": [["oilhouse", Vector3(0, 0, -36)]],
		"story": "비 오는 광산 도시의 석조 연료 창고. 바깥 짚 더미에서 젖은 홈통이 안쪽 연료 배관까지 이어진다. 젖은 것은 기름 단지를 깨뜨려 적셔야 탄다."},
	{"name": "광부 숙소", "ammo": {"oil": 2, "fire": 2}, "wind": [1, -1, 0],
		"parts": [["barn", Vector3(0, 0, -38)]],
		"story": "인간들이 광부 숙소를 막사로 쓴다. 무거운 돌 지붕을 받친 판자 벽이 비에 흠뻑 젖었다. 벽이 타 없어지면 지붕이 내려앉는다."},
	{"name": "석탄 호퍼", "ammo": {"oil": 2, "fire": 2}, "wind": [1, 1, 0],
		"parts": [["hopper", Vector3(-3, 0, -40)]],
		"story": "지휘관이 석탄 호퍼 밑 돌 칸막이 안에서 비를 피한다. 머리 위에는 젖은 화약을 채운 쇠 통, 그 아래는 젖은 나무 다리 넷."},
	{"name": "무너진 갱도 입구", "ammo": {"he": 2, "oil": 1, "fire": 2}, "wind": [2, -1, 0],
		"parts": [["cave", Vector3(0, 0, -40), {"keg": true}]],
		"story": "갱도 입구의 석재 덮개가 금 간 돌기둥과 젖은 나무 버팀목에 얹혀 있다. 기둥은 폭탄, 젖은 버팀목은 기름과 불로."},
	{"name": "갱도 감시탑 둘", "ammo": {"oil": 3, "fire": 3}, "wind": [2, 1, 0],
		"parts": [["tower", Vector3(-9, 0, -38), {"parapet": true}], ["tower", Vector3(10, 0, -44), {"legs": 5.0, "parapet": true}]],
		"story": "갱도 양쪽 감시탑. 위에는 돌 난간을 둘러 폭발을 막지만, 탑 다리는 젖은 나무다."},
	{"name": "젖은 화약 창고", "ammo": {"he": 1, "oil": 3, "fire": 3}, "wind": [2, -1, 0],
		"parts": [["powder", Vector3(7, 0, -42)], ["tower", Vector3(-11, 0, -40), {"parapet": true}]],
		"story": "광산 발파용 화약을 넣어 둔 나무 창고와 건너편 감시탑. 폭탄 한 발이면 화약 창고는 터지지만 돌 난간 감시탑은 젖은 다리를 태워야 한다."},
	{"name": "선로 옆 호퍼와 숙소", "ammo": {"oil": 3, "fire": 3}, "wind": [3, 1, 0],
		"parts": [["hopper", Vector3(-10, 0, -44)], ["barn", Vector3(11, 0, -38)]],
		"story": "석탄 선로 옆에 호퍼와 감독관 숙소가 붙어 있다. 둘 다 젖었다."},
	{"name": "바람 부는 채석장", "ammo": {"he": 2, "oil": 2, "fire": 2}, "wind": [4, 1, 0],
		"parts": [["pillars", Vector3(-10, 0, -40)], ["tower", Vector3(11, 0, -44), {"legs": 5.0, "parapet": true}]],
		"story": "비바람 부는 채석장. 금 간 석재 망대 위 지휘관과 젖은 감시탑 위 부관."},
	{"name": "빗속 마당 막사", "ammo": {"he": 2, "oil": 3, "fire": 3}, "wind": [3, -1, 0],
		"parts": [["courtyard", Vector3(2, 0, -42)], ["barn", Vector3(-13, 0, -38)]],
		"story": "석벽 마당 안 젖은 막사와 바깥 광부 숙소. 벽을 부수고, 기름을 높이 띄워 막사에 붓고, 불을 넣는다."},
	{"name": "정련소", "ammo": {"he": 2, "oil": 4, "fire": 4}, "perch": 12.0, "wind": [3, 1, 0],
		"parts": [["fortress", Vector3(0, 0, -54), {"wet": true}], ["hopper", Vector3(-18, 0, -46)], ["barn", Vector3(15, 0, -46)]],
		"story": "클라이맥스: 정련소 석벽 안 젖은 증기탑 위의 지휘관, 석탄 호퍼 밑의 감독관, 숙소 안의 부관. 셋 다."},

	# ---------- 3월드: 밤의 철벽 관문 (늘 밤: 조명탄은 짧고 좁다. 불빛을 보면 인간들이 구경하러 나온다) ----------
	{"name": "어둠 속 망루", "ammo": {"he": 2, "flare": 2}, "wind": [1, 1, 0],
		"parts": [["tower", Vector3(0, 0, -40), {"legs": 5.0}]],
		"story": "달도 없는 밤. 관문 앞 망루가 어둠에 묻혔다. 조명탄은 몇 초만, 떨어진 둘레만 비춘다. 비추는 동안 던진다."},
	{"name": "불빛 구경꾼", "ammo": {"he": 2, "flare": 2}, "wind": [2, -1, 0],
		"parts": [["guardhouse", Vector3(0, 0, -40)]],
		"story": "사방이 강철인 초소, 문은 옆으로 나 있어 밖에서는 안이 안 보인다. 그런데 인간들은 밤하늘의 불빛을 못 참는다. 초소 문 앞에 조명탄을 떨어뜨리면 지휘관이 구경하러 걸어 나온다."},
	{"name": "금 간 석재 망대 둘", "ammo": {"he": 3, "flare": 2}, "wind": [2, 1, 0],
		"parts": [["pillars", Vector3(-8, 0, -40)], ["pillars", Vector3(9, 0, -47)]],
		"story": "관문 양쪽의 석재 망대. 망대마다 기둥 하나가 낡아 금이 갔다. 조명탄 하나로는 둘을 다 못 비춘다."},
	{"name": "관문 성벽 보행로", "ammo": {"he": 2, "flare": 1}, "wind": [2, -1, 1],
		"parts": [["rampart", Vector3(0, 0, -44)]],
		"story": "성벽 위 돌 보행로에 지휘관이 섰다. 바로 아래 밑동 한 칸이 낡아 금이 갔다. 그 칸이 무너지면 보행로째 떨어진다."},
	{"name": "강철 방벽과 숨은 화약통", "ammo": {"fire": 3, "flare": 1}, "wind": [3, 1, 0],
		"parts": [["kegyard", Vector3(0, 0, -46)]],
		"story": "지휘관 둘이 강철 방벽 뒤에서 작은 창으로 밖을 내다본다. 방벽 뒤 둘 사이에 큰 화약통을 숨겨 두었는데, 도화선이 방벽 옆으로 삐져나와 있다. 도화선 끝에 불을 붙이면 방벽도 지휘관도 한꺼번에 날아간다."},
	{"name": "병영 천막", "ammo": {"fire": 4, "flare": 2}, "wind": [3, -1, 0],
		"parts": [["tent", Vector3(-10, 0, -40)], ["tent", Vector3(1, 0, -47)], ["tent", Vector3(12, 0, -42)]],
		"story": "관문 안 병영에 짚 천막 셋, 천막마다 지휘관이 하나씩 잔다. 조명탄은 둘뿐: 두 천막 사이에 떨어뜨려 한 번에 비춘다."},
	{"name": "화약통 곁 초소", "ammo": {"he": 2, "fire": 2, "flare": 2}, "wind": [3, 1, -1],
		"parts": [["guardhouse", Vector3(-8, 0, -42), {"kegs": true, "door": 1}], ["crane", Vector3(10, 0, -48)]],
		"story": "강철 초소 문 앞에 화약통 더미. 불빛을 보러 나온 지휘관이 하필 그 곁에 선다. 건너편 기중기 밑에는 쇠 상자를 머리 위에 둔 공병대장."},
	{"name": "성벽과 망대", "ammo": {"he": 3, "fire": 2, "flare": 2}, "wind": [3, -1, 0],
		"parts": [["rampart", Vector3(-10, 0, -46)], ["pillars", Vector3(10, 0, -50)], ["tent", Vector3(0, 0, -38)]],
		"story": "성벽 보행로, 석재 망대, 그 앞 천막. 지휘관 셋."},
	{"name": "보급 마당", "ammo": {"he": 2, "fire": 3, "flare": 2}, "wind": [4, 1, 0],
		"parts": [["kegyard", Vector3(-9, 0, -48)], ["guardhouse", Vector3(11, 0, -42), {"door": -1}]],
		"story": "관문 보급 마당. 화약통을 숨긴 강철 방벽 뒤의 지휘관 둘과 강철 초소 안의 보급관. 보급관은 불빛 구경을 좋아한다."},
	{"name": "철벽 관문 본루", "ammo": {"he": 4, "fire": 2, "flare": 3}, "perch": 10.0, "wind": [4, -1, 0],
		"parts": [["fortress", Vector3(0, 0, -58)], ["windowpost", Vector3(-14, 0, -46)], ["guardhouse", Vector3(14, 0, -46), {"kegs": true, "door": -1}]],
		"story": "클라이맥스: 밤의 관문 본루. 안뜰 공성탑의 지휘관(도화선이 강철 문 밑으로), 석벽 초소의 부관, 화약통 곁 초소의 경비대장."},

	# ---------- 4월드: 대공 요새 (모든 진지에 글라이더 공수부대와 발리스타: 발리스타부터 치우고 조명탄으로 폭격을 부른다) ----------
	{"name": "먼 강철 벙커", "ammo": {"he": 1, "flare": 2}, "bombers": 2, "perch": 16.0, "wind": [1, 1, 0],
		"ballistas": [[Vector3(-6, 0, -46), "wood"]],
		"parts": [["bunker", Vector3(0, 0, -82)]],
		"story": "골짜기 건너 강철 벙커. 폭탄이 닿지도 않고 닿아도 안 부서진다. 글라이더를 멘 동료 고블린들이 옆 바위에서 기다린다: 조명탄을 벙커 근처에 떨어뜨리면 그 불빛을 보고 날아가 폭탄을 안고 뛰어내린다. 그런데 가까운 나무 발리스타가 서 있으면 글라이더를 쏘아 떨어뜨린다. 발리스타부터 날린다."},
	{"name": "석재 발리스타", "ammo": {"he": 2, "flare": 2}, "bombers": 2, "perch": 18.0, "wind": [2, 1, 0],
		"ballistas": [[Vector3(9, 0, -52), "stone"]],
		"parts": [["bunker", Vector3(-6, 0, -92)], ["hut", Vector3(2, 0, -97)]],
		"story": "금 간 석재 기둥 위의 발리스타. 흰 돌 기둥 셋은 꿈쩍도 안 한다: 금 간 기둥 하나를 골라 부순 뒤, 벙커와 오두막 사이에 조명탄을 떨어뜨린다."},
	{"name": "골짜기 건너 망루", "ammo": {"he": 3, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [3, 1, 0],
		"ballistas": [[Vector3(-9, 0, -54), "wood"]],
		"parts": [["bunker", Vector3(4, 0, -98)], ["tower", Vector3(-4, 0, -66), {"legs": 5.0}]],
		"story": "폭격 무리 밖에 홀로 선 망루의 포대장은 폭격이 닿지 않는다: 가벼운 폭탄으로 직접 닿는 거리(화염 항아리는 못 닿는다). 발리스타, 망루, 그리고 벙커에 조명탄."},
	{"name": "두 나무 발리스타", "ammo": {"he": 3, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [3, 1, 1],
		"ballistas": [[Vector3(-7, 0, -56), "wood"], [Vector3(8, 0, -60), "wood"]],
		"parts": [["bunker", Vector3(-6, 0, -98)], ["bunker", Vector3(6, 0, -94)]],
		"story": "나란히 선 벙커 둘을 나무 발리스타 둘이 지킨다. 하나라도 서 있으면 격추된다. 둘 다 날리고 두 벙커 사이에 조명탄."},
	{"name": "골짜기 오두막과 종탑", "ammo": {"he": 4, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(14, 0, -54), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -100)], ["hut", Vector3(-10, 0, -62)], ["bell", Vector3(8, 0, -66)]],
		"story": "요새 아래 골짜기 마을. 오두막 안의 지휘관과 종탑 초소 안의 부관은 사거리 끝에서 직접, 먼 벙커는 석재 발리스타를 치운 뒤 폭격으로."},
	{"name": "망대와 풍차", "ammo": {"he": 5, "flare": 2}, "bombers": 2, "perch": 22.0, "wind": [3, -1, 0],
		"ballistas": [[Vector3(0, 0, -60), "wood"], [Vector3(-12, 0, -54), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -104)], ["tent", Vector3(7, 0, -107)], ["pillars", Vector3(-16, 0, -64)], ["windmill", Vector3(12, 0, -64)]],
		"story": "옆바람이 부는 요새 앞 들판. 발리스타 둘 뒤로 석재 망대의 지휘관과 풍차 회랑의 부관, 그 너머 벙커 무리."},
	{"name": "요새 포대", "ammo": {"he": 4, "flare": 2}, "bombers": 2, "perch": 20.0, "wind": [4, 1, 0],
		"ballistas": [[Vector3(-10, 0, -58), "wood"], [Vector3(10, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -104)], ["tower", Vector3(9, 0, -100)], ["cave", Vector3(-8, 0, -100)]],
		"story": "나무와 석재 발리스타가 지키는 먼 벙커와 그 양옆 망루·감시굴. 셋이 한 무리라 폭격 한 번이면 끝난다."},
	{"name": "절벽 굴과 벙커", "ammo": {"he": 4, "flare": 2}, "bombers": 2, "perch": 18.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(-14, 0, -52), "stone"], [Vector3(18, 0, -66), "stone"]],
		"parts": [["cave", Vector3(-5, 0, -98)], ["bunker", Vector3(6, 0, -92)], ["rampart", Vector3(-2, 0, -62)]],
		"story": "절벽 밑 감시굴과 그 옆 벙커를 석재 발리스타 둘이 지킨다. 앞 성벽 보행로의 감시대장은 직접."},
	{"name": "세 발리스타", "ammo": {"he": 5, "flare": 2}, "bombers": 2, "perch": 22.0, "wind": [4, 1, -1],
		"ballistas": [[Vector3(-12, 0, -60), "wood"], [Vector3(12, 0, -58), "stone"], [Vector3(0, 0, -68), "wood"]],
		"parts": [["bunker", Vector3(-5, 0, -102)], ["bunker", Vector3(6, 0, -106)], ["tower", Vector3(16, 0, -66), {"legs": 5.0}]],
		"story": "발리스타 셋이 겹겹이 지키는 벙커 둘, 오른쪽 높은 망루의 관측병."},
	{"name": "대공 요새 본루", "ammo": {"he": 6, "flare": 2}, "bombers": 2, "perch": 25.0, "wind": [5, 1, 0],
		"ballistas": [[Vector3(-12, 0, -62), "wood"], [Vector3(12, 0, -60), "stone"], [Vector3(0, 0, -70), "wood"]],
		"parts": [["bunker", Vector3(0, 0, -110)], ["tower", Vector3(-9, 0, -106), {"legs": 5.0}], ["pillars", Vector3(-17, 0, -70)], ["windowpost", Vector3(16, 0, -72)]],
		"story": "클라이맥스: 발리스타 셋이 지키는 대공 요새 본루 벙커와 그 옆 망루의 포대장, 앞 들판의 석재 망대와 석벽 초소."},

	# ---------- 5월드: 왕국 성채 (모든 기믹, 지휘관 여럿) ----------
	{"name": "왕성 외곽 밤바람", "ammo": {"he": 2, "fire": 3, "flare": 2}, "night": true, "wind": [4, 1, 0],
		"parts": [["steelhut", Vector3(-11, 0, -40)], ["crane", Vector3(11, 0, -44)], ["tower", Vector3(0, 0, -52), {"legs": 5.0}]],
		"story": "밤바람 부는 왕성 외곽. 강철 성벽 뒤 막사, 기중기 밑, 높은 망루에 지휘관 셋."},
	{"name": "빗속 왕실 창고", "ammo": {"he": 3, "oil": 2, "fire": 2}, "rain": true, "wind": [3, -1, 0],
		"parts": [["barn", Vector3(-12, 0, -40)], ["hopper", Vector3(12, 0, -44)], ["windowpost", Vector3(0, 0, -38)]],
		"story": "비 오는 왕실 창고 거리. 젖은 창고, 석탄 호퍼, 석벽 초소에 지휘관 셋."},
	{"name": "밤의 왕실 마구간 마당", "ammo": {"he": 3, "fire": 3, "flare": 2}, "night": true, "wind": [4, -1, 0],
		"parts": [["courtyard", Vector3(0, 0, -44)], ["powder", Vector3(-17, 0, -40)], ["rowhouses", Vector3(14, 0, -40), {"count": 2}]],
		"story": "바람 부는 밤의 왕실 마구간 마당. 석벽 마당 막사, 화약 창고 옆 망대, 잇닿은 마부 집 두 채."},
	{"name": "빗속 밤의 채석장", "ammo": {"he": 2, "oil": 2, "fire": 5, "flare": 2}, "night": true, "rain": true, "wind": [4, 1, 0],
		"parts": [["cave", Vector3(0, 0, -46)], ["kegyard", Vector3(-15, 0, -42)], ["tower", Vector3(15, 0, -48), {"parapet": true}]],
		"story": "비 오는 밤의 성채 채석장. 감시굴, 화약통을 숨긴 강철 방벽 뒤의 둘(도화선은 기름 먹인 밧줄이라 비에도 탄다), 젖은 감시탑. 지휘관 넷."},
	{"name": "빗속 성채 포대", "ammo": {"he": 5, "flare": 2}, "bombers": 2, "rain": true, "perch": 20.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(0, 0, -64), "wood"], [Vector3(-12, 0, -56), "stone"], [Vector3(12, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(-8.5, 0, -96)], ["bunker", Vector3(8.5, 0, -100)], ["pillars", Vector3(0, 0, -104)]],
		"story": "비 오는 성채 포대. 발리스타 셋(젖은 나무 탑은 태우기보다 날리는 게 빠르다)이 지키는 벙커 둘과 그 뒤 석재 망대. 발리스타만 다 치우면 폭격 한 번으로 끝난다."},
	{"name": "밤바람 부는 종루 광장", "ammo": {"he": 3, "fire": 2, "flare": 2}, "night": true, "perch": 10.0, "wind": [5, 1, 0],
		"parts": [["rampart", Vector3(-12, 0, -46)], ["windmill", Vector3(12, 0, -50)], ["bell", Vector3(0, 0, -56)]],
		"story": "강풍 부는 밤의 성채 광장. 깃발이 끝까지 펴졌다. 성벽 보행로, 풍차 회랑, 종루 초소에 지휘관 셋."},
	{"name": "밤의 근위대 막사", "ammo": {"he": 2, "fire": 4, "flare": 3}, "night": true, "wind": [4, -1, 0],
		"parts": [["tent", Vector3(-12, 0, -38)], ["guardhouse", Vector3(-3, 0, -46), {"kegs": true, "door": 1}], ["steelhut", Vector3(12, 0, -42)], ["crane", Vector3(6, 0, -52)]],
		"story": "밤, 근위대 막사 구역. 천막, 화약통 곁 초소, 강철 성벽 뒤 막사, 기중기 밑. 지휘관 넷."},
	{"name": "빗속 정련 골목", "ammo": {"he": 1, "oil": 4, "fire": 4}, "rain": true, "perch": 10.0, "wind": [4, 1, 0],
		"parts": [["oilhouse", Vector3(-12, 0, -40)], ["hopper", Vector3(10, 0, -44)], ["tower", Vector3(0, 0, -52), {"parapet": true}]],
		"story": "비바람 부는 성채 정련 골목. 연료 창고, 석탄 호퍼, 젖은 감시탑."},
	{"name": "빗속 원거리 포대", "ammo": {"he": 5, "flare": 2}, "bombers": 2, "rain": true, "perch": 20.0, "wind": [4, -1, 0],
		"ballistas": [[Vector3(-10, 0, -58), "wood"], [Vector3(10, 0, -56), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -100)], ["windowpost", Vector3(-16, 0, -50)], ["tower", Vector3(16, 0, -54)]],
		"story": "비 오는 성채 포대. 발리스타 둘이 지키는 먼 벙커는 폭격으로, 가까운 석벽 초소와 젖은 망루는 직접."},
	{"name": "왕국 성채 본진", "ammo": {"he": 4, "fire": 4}, "launch_button": true, "perch": 20.0, "final": true, "wind": [5, 1, 0],
		"ballistas": [[Vector3(-12, 0, -56), "wood"], [Vector3(12, 0, -54), "stone"]],
		"parts": [["bunker", Vector3(0, 0, -96)], ["fortress", Vector3(-16, 0, -66)], ["pillars", Vector3(15, 0, -57)]],
		"story": "최종: 부족장이 갇힌 성채. 고블린들의 비장의 거대 로켓이 딱 한 발 있다. 발리스타를 모두 무너뜨린 뒤 옆의 크고 빨간 발사 버튼을 누르면, 성채에 남은 장군을 모두 한꺼번에 날려 버린다 (부족장이 휘말려도 고블린은 개의치 않는다)."},
]
const COUNT := 50

## 진지별 보조 목표 (별 셋째). 예상 정답과 다른 길, 정통 직격, 간접으로만, 적은 투척 등 진지에 맞춰 하나씩.
const BONUS := [
	# 1월드
	["direct"], ["ally"], ["window"], ["direct"], ["indirect"],
	["indirect"], ["throws", 1], ["throws", 1], ["without", "fire"], ["he_two"],
	# 2월드
	["window"], ["window"], ["window"], ["keg"], ["direct", 2],
	["direct", 2], ["window"], ["direct"], ["window"], ["window"],
	# 3월드
	["without", "flare"], ["direct"], ["direct", 2], ["throws", 1], ["throws", 1],
	["direct"], ["direct"], ["direct", 2], ["without", "he"], ["without", "fire"],
	# 4월드
	["no_shotdown"], ["throws", 1], ["no_shotdown"], ["sky_two"], ["direct"],
	["no_shotdown"], ["sky_two"], ["no_shotdown"], ["sky_two"], ["no_shotdown"],
	# 5월드
	["direct", 2], ["window"], ["direct", 2], ["he_two"], ["no_shotdown"],
	["direct"], ["direct", 2], ["window"], ["no_shotdown"], ["direct"],
]


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


## ---------- 별 평가 ----------
## 별 하나: 목표 달성(클리어). 별 둘: 폭탄을 남기고 클리어. 별 셋: 진지마다 하나씩 정한 보조 목표 (BONUS).
## 보조 목표 종류:
## - ["direct", n]: 폭탄·항아리 직격으로 n명(지휘관과 병사, 기본 1) 이상 잡기
## - ["window"]: 창문 난 건물 안의 지휘관을 창문으로 집어넣은 투척으로 잡기 (벽이 멀쩡할 때 방 안에 떨어진 투척)
## - ["ally"]: 아군 고블린과 싸우는 병사(ally_foe 메타)를 잡기
## - ["he_two"]: 쾅쾅알 하나로 둘 이상 (지휘관과 병사) 잡기
## - ["sky_two"]: 하늘쾅 한 발로 지휘관 둘 이상 (깃발 둘) 쓰러뜨리기
## - ["keg"]: 보조 목표 폭발통(bonus_keg 메타)을 터뜨리기
## - ["indirect"]: 모든 지휘관을 맞히지 않고 무너뜨리거나(깔림·추락) 태워서만
## - ["without", 탄종]: 그 탄종을 한 번도 안 던지고 (예상 정답과 다른 길)
## - ["throws", n]: 폭탄·항아리·기름 단지를 n번 이하로 던져서 (물감탄·조명탄은 안 셈)
## - ["no_shotdown"]: 글라이더를 하나도 안 떨어뜨리고
## - ["one_go"]: 지휘관 모두를 3초 안에 한꺼번에


static func bonus_of(i: int) -> Array:
	return BONUS[i]


static func bonus_text(i: int) -> String:
	var b := bonus_of(i)
	match b[0]:
		"direct":
			return Texts.t("bonus_direct") if b.size() < 2 else Texts.t("bonus_direct_n") % b[1]
		"window", "ally", "he_two", "sky_two", "keg":
			return Texts.t("bonus_" + str(b[0]))
		"indirect":
			return Texts.t("bonus_indirect")
		"without":
			return Texts.t("bonus_without_" + str(b[1]))
		"throws":
			return Texts.t("bonus_throws") % b[1]
		"no_shotdown":
			return Texts.t("bonus_no_shotdown")
		"one_go":
			return Texts.t("bonus_one_go")
	return ""


static func bonus_met(i: int, s: Stage) -> bool:
	var b := bonus_of(i)
	match b[0]:
		"direct":
			var need: int = b[1] if b.size() > 1 else 1
			return _foes(s).filter(func(a): return a.dead and a.defeat_cause == "direct").size() >= need
		"window":
			return s.commanders.any(func(c): return c.dead and c.throw_id >= 0 and c.throw_id == c.get_meta("window_tid", -2))
		"ally":
			return _foes(s).any(func(a): return a.dead and a.has_meta("ally_foe"))
		"he_two":
			var kills := {}
			for a in _foes(s):
				if a.dead and a.throw_id >= 0 and s.throw_kinds.get(a.throw_id, -1) == K.HE:
					kills[a.throw_id] = int(kills.get(a.throw_id, 0)) + 1
			return kills.values().any(func(n): return n >= 2)
		"sky_two":
			return s.best_strike >= 2
		"keg":
			return s.bonus_keg_blown
		"indirect":
			return s.commanders.all(func(c): return c.defeat_cause in ["fall", "crush", "fire"])
		"without":
			var kind: int = {"fire": K.FIRE, "he": K.HE, "oil": K.OIL, "flare": K.FLARE, "paint": K.PAINT}[b[1]]
			return int(s.thrown.get(kind, 0)) == 0
		"throws":
			var n := 0
			for k in [K.FIRE, K.HE, K.OIL]:
				n += int(s.thrown.get(k, 0))
			return n <= int(b[1])
		"no_shotdown":
			return s.shot_down == 0
		"one_go":
			var times: Array = s.commanders.map(func(c): return float(c.get_meta("down_at", 0.0)))
			return times.max() - times.min() <= 3.0
	return false


## 판정 대상 인간들 (지휘관, 병사, 궁병). 동료 고블린은 뺀다.
static func _foes(s: Stage) -> Array:
	return s.get_tree().get_nodes_in_group("actors").filter(func(a): return a is Commander or a is Guard)


## 이번 클리어로 받은 별 (비트: 1 = 목표 달성, 2 = 폭탄 남김, 4 = 보조 목표). 클리어했으니 1은 늘 켜진다.
static func star_bits(i: int, s: Stage) -> int:
	return 1 | (2 if s.total_ammo() > 0 else 0) | (4 if bonus_met(i, s) else 0)


## 바람 깃발 자리: 투척 구역에서 진지 쪽으로 7할쯤 간 길목에서 옆으로 비켜, 부품·발리스타에서 넉넉히 떨어진 땅.
## (멀리 있어야 조준할 때 진지와 함께 화면에 잡힌다. 투척 길목 한가운데는 피한다.)
static func banner_spot(d: Dictionary, pp: Vector3) -> Vector3:
	var spots := []
	for part in d.get("parts", []):
		spots.append(part[1])
	for b in d.get("ballistas", []):
		spots.append(b[0])
	var center := Vector3(0, 0, -40)
	if not spots.is_empty():
		center = Vector3.ZERO
		for p in spots:
			center += p
		center /= spots.size()
	var flat := Vector3(center.x - pp.x, 0, center.z - pp.z)
	var dir := flat.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var best := Vector3.ZERO
	var best_gap := -1.0
	for along in [0.7, 0.62, 0.78]:
		for off in [10.0, -10.0, 13.0, -13.0, 7.0, -7.0]:
			var q: Vector3 = Vector3(pp.x, 0, pp.z) + dir * flat.length() * float(along) + side * float(off)
			var gap := 999.0
			for p in spots:
				gap = minf(gap, Vector2(q.x - p.x, q.z - p.z).length())
			if gap > 9.0:
				return q
			if gap > best_gap:
				best_gap = gap
				best = q
	return best


## 지휘관 수 (부품마다 세우는 수의 합).
static func commander_count(i: int) -> int:
	var d: Dictionary = STAGES[i]
	if d.get("fixed", "") == "ally":
		return 1
	var n := 0
	for part in d.parts:
		n += _commanders_in(part)
	return n


## 페인트탄 수: 기본 하나 + 지휘관 하나에 하나씩.
static func paint_count(i: int) -> int:
	return 1 + commander_count(i)


static func build(i: int, s: Stage) -> void:
	var d: Dictionary = STAGES[i]
	s.world = world_of(i)
	s.outpost_props = true
	if d.get("fixed", "") == "ally":
		_ally_stage(s, label(i), d.name)
	else:
		s.begin(label(i), d.name, false)
		s.set_zone(Vector3(0, d.get("perch", HILL), d.get("zone", 0.0)), Vector2(3.0, 3.0))
		for b in d.get("ballistas", []):
			_frame(s, b[0])
			_ballista(s, b[0], b[1])
		for part in d.parts:
			var opts: Dictionary = part[2] if part.size() > 2 else {}
			_frame(s, part[1])
			Callable(Campaign, "_part_" + part[0]).call(s, part[1], opts)
		_frame(s, Vector3.ZERO, 1.0)
		if d.get("final", false):
			_cage(s, part_at(d.parts[0][1], Vector3(-6.5, 0, 1.0)))
		_extras(s, d, world_of(i), bonus_of(i)[0] == "ally")
		_frame(s, Vector3.ZERO, 1.0)
	s.ammo_slots.clear()
	var ammo_of := {"fire": FIRE, "he": HE, "oil": OIL, "flare": FLARE}
	for key in ["he", "fire", "oil", "flare"]:
		if d.ammo.has(key):
			s.add_ammo(ammo_of[key], d.ammo[key])
	s.add_ammo(PAINT, paint_count(i))
	s.add_bombers(d.get("bombers", 0))
	if d.get("launch_button", false):
		s.add_launch_button()
	s.wind = wind_of(i)
	if is_rain(i):
		s.make_rain()
		# 비 맞는 나무와 짚은 모두 젖는다 (화약통·연료관·도화선은 그대로)
		for st in s.structures:
			for b in st.blocks:
				if b.mat == M.KEG and not b.has_meta("dry"):
					b.set_meta("rain_wets", true)
				b.make_wet()
	if is_night(i):
		s.night = true
		_torches(s, d)
	if d.has("wind"):
		s.add_wind_banner(banner_spot(d, s.player.position))
	s.finish_build()
	s.stage_id = label(i)
	s.title = "%s · %s" % [label(i), d.name]


## 이제부터 짓는 것을 부품 중심 origin에서 k배로 키운다 (k = 1이면 그대로).
static func _frame(s: Stage, origin: Vector3, k := PART_SCALE) -> void:
	s.build_origin = origin
	s.build_scale = k


## 배경 고블린 (판정과 무관). 1월드의 화약통·폭발통 곁에서는 "여기야!" 하고 손짓하는 고블린 (휘말려도 개의치 않는다),
## 1월드에서는 인간 건물 앞에서 병사와 싸우거나 돌멩이를 던지는 마을 고블린.
## ally_foe: 첫 싸움 고블린의 상대를 진짜 병사로 (보조 목표 "아군 고블린 돕기").
static func _extras(s: Stage, d: Dictionary, world: int, ally_foe := false) -> void:
	var GE := GoblinExtra.Mode
	var n := 0
	for part in d.parts:
		var c: Vector3 = part[1]
		var opts: Dictionary = part[2] if part.size() > 2 else {}
		_frame(s, c)
		# 통을 가리켜 주는 고블린은 1월드에만 (그 뒤로는 스스로 찾는다)
		match part[0] if world == 0 else "":
			"powder":
				s.add_extra(c + Vector3(5.6, 0, 2.2), 200.0, GE.WAVE, c + Vector3(3.6, 0.5, -0.6))
			"fortress":
				if not opts.get("wet", false):
					# 성문 앞에서 방방 뛰며 도화선 끝을 가리킨다
					var fx := fort_fuse_x(c)
					s.add_extra(c + Vector3(fx + 2.6 * crack_side(c), 0, FORT_FUSE_Z + 0.6), 150.0 * crack_side(c) * -1.0, GE.WAVE, c + Vector3(fx, 0.1, FORT_FUSE_Z))
			"kegyard":
				s.add_extra(c + Vector3(KEG_FUSE_X + 1.0, 0, 5.0), 200.0, GE.WAVE, c + Vector3(KEG_FUSE_X, 0, 5.4))
			"hopper":
				var hs := _hopper_side(c)
				s.add_extra(c + Vector3(hs * 5.2, 0, 0.8), 210.0 * hs, GE.WAVE, c + Vector3(hs * 2.7, 0.6, -1.9))
		if world == 0 and n < 2 and part[0] != "fortress":
			var side := -1.0 if c.x > 0.0 else 1.0
			var fighter := s.add_extra(c + Vector3(side * 4.5, 0, 6.0), 90.0 * side, GE.FIGHT, Vector3.INF, ally_foe and n == 0)
			if fighter.real_foe:
				fighter.real_foe.set_meta("ally_foe", true)
			s.add_extra(c + Vector3(-side * 3.0, 0, 7.5), 0.0, GE.THROW)
			n += 1


## 부품마다 세우는 지휘관 수 (풀이에서 지휘관 번호를 셀 때 쓴다).
const COMMANDERS_OF := {"kegyard": 2}


static func _commanders_in(part: Array) -> int:
	if part[0] == "rowhouses":
		return (part[2] if part.size() > 2 else {}).get("count", 3)
	return COMMANDERS_OF.get(part[0], 1)


## 폭격 진지에서 첫 벙커 둘레 ROCKET_CLUSTER 안의 부품인지 (폭격 한 번으로 끝나는 무리).
static func _in_rocket_cluster(d: Dictionary, pos: Vector3) -> bool:
	if d.get("bombers", 0) <= 0:
		return false
	for part in d.parts:
		if part[0] == "bunker":
			return part[1].distance_to(pos) < ROCKET_CLUSTER
	return false


## 보조 목표 풀이 (테스트가 실제로 던져 본다): {진지: {부품 번호: [main 풀이도 이어 던질지, 단계...]}}.
## 단계의 목표: 정수 = 그 번호 지휘관, Vector3 = 부품 중심 기준 자리 (부품 배율 전), "ally_foe" = 아군 고블린과 싸우는 병사.
## 여기 없는 부품은 설계상 풀이 그대로 (그것만으로 보조 목표가 채워지는 진지는 아예 없다).
const BONUS_PLAN := {
	1: {0: [true, [K.HE, "ally_foe", false, 0.0]]},
	10: {0: [true, [K.FIRE, Vector3(0, 1.85, 3.0), false, 0.0]]},
	11: {0: [true, [K.FIRE, Vector3(-0.8, 1.45, 2.0), false, 0.0]]},
	12: {0: [true, [K.FIRE, HOPPER_WINDOW, false, 0.0]]},
	13: {0: [true, [K.FIRE, Vector3(1.3, 0.0, -1.6), false, 5.0]]},
	14: {0: [false, [K.FIRE, 0, false, 0.0]], 1: [false, [K.FIRE, 1, false, 0.0]]},
	15: {0: [false, [K.FIRE, 0, false, 0.0]], 1: [false, [K.FIRE, 1, false, 0.0]]},
	16: {0: [false, [K.FIRE, HOPPER_WINDOW, false, 0.0]]},
	18: {1: [false, [K.FIRE, Vector3(-0.8, 1.45, 2.0), false, 0.0]]},
	19: {1: [false, [K.FIRE, HOPPER_WINDOW, false, 0.0]]},
	22: {0: [false, [K.HE, 0, true, 0.0]], 1: [false, [K.HE, 1, true, 0.0]]},
	25: {1: [false, [K.FIRE, TENT_LEGS, false, 0.0]]},
	26: {1: [false, [K.HE, 1, true, 0.0]]},
	27: {0: [false, [K.HE, 0, false, 0.0]], 1: [false, [K.HE, 1, true, 0.0]]},
	40: {1: [false, [K.HE, 1, true, 0.0]], 2: [false, [K.HE, 2, false, 0.0]]},
	41: {1: [false, [K.FIRE, HOPPER_WINDOW, false, 0.0]]},
	42: {1: [false, [K.FIRE, 1, false, 0.0], [K.HE, Vector3(-4, 0.95, 3), false, 0.0]]},
	43: {1: [false, [K.HE, Vector3(0, 1.2, 0.8), true, 0.0]]},
	46: {1: [false, [K.FLARE, Vector3(5.2, 0.1, 1.2), false, 6.5], [K.HE, 1, false, 0.0]], 3: [false, [K.HE, 3, true, 0.0]]},
	47: {1: [false, [K.FIRE, HOPPER_WINDOW, false, 0.0]]},
	49: {2: [false, [K.HE, 2, true, 3.0]]},
}
## 호퍼 돌집 앞벽의 작은 창 가운데 (불항아리는 가파르게 떨어지므로 지휘관 가슴이 아니라 창을 겨눈다)
const HOPPER_WINDOW := Vector3(0, 1.3, 1.3)
## 천막 문 너머 지휘관의 다리 (가슴을 겨누면 가파르게 떨어지는 항아리가 앞벽 위에 걸린다)
const TENT_LEGS := Vector3(0, 0.3, -0.3)


## 설계상 풀이: [[탄종, 목표, 높이 띄우기, 던진 뒤 기다림(초)], ...] (테스트가 실제로 던져 본다).
## 목표가 정수면 그 번호 지휘관의 지금 자리. ["ally"]는 지원형 풀이.
## 순서: 발리스타 → 폭격 무리 밖의 부품 → 폭격 무리 한가운데에 조명탄 한 발 (발리스타가 다 쓰러진 뒤).
## 최종 진지: 발리스타 → ["button"] (발사 버튼을 누른다).
## bonus: 보조 목표 풀이 (BONUS_PLAN의 부품은 그 단계로 바꾸거나 앞에 붙인다).
static func plan(i: int, bonus := false) -> Array:
	var d: Dictionary = STAGES[i]
	if d.get("fixed", "") == "ally":
		# 병사 셋 한가운데 폭탄 → 망루 통나무 문에 불 → 금 간 성벽에 폭탄 → 동료가 성문 앞에서 스스로 터진다
		return [[K.HE, StageDefs._along(ALLY_PTS, ALLY_SOLDIERS) + Vector3(0, 0.6, 0.3), false, 0.0],
			[K.FIRE, StageDefs._along(ALLY_PTS, ALLY_TOWER) + Vector3(0, 1.2, 0), false, 0.0],
			[K.HE, StageDefs._along(ALLY_PTS, ALLY_WALL) + Vector3(0, 1.0, 0), false, 0.0]]
	var rain := is_rain(i)
	var out := []
	# 남은 폭탄 수: 폭탄 풀이를 고를 때마다 하나씩 쓴다 (모자라면 불 풀이)
	var budget: Dictionary = d.ammo.duplicate()
	for b in d.get("ballistas", []):
		var bp: Vector3 = b[0]
		if b[1] == "wood" and budget.get("he", 0) <= 0:
			if rain:
				out.append([K.OIL, part_at(bp, Vector3(0, 1.5, 1.4)), false, 0.3])
			out.append([K.FIRE, part_at(bp, Vector3(0, 1.5, 1.4)), false, 0.0])
		elif b[1] == "wood":
			# 나무 탑은 앞 다리 사이 가로대에 폭탄 한 발 (앞 다리 둘이 부러져 앞으로 넘어간다)
			out.append([K.HE, part_at(bp, Vector3(0, 1.5, 1.4)), false, 0.0])
			budget["he"] -= 1
		else:
			out.append([K.HE, part_at(bp, Vector3(crack_side(bp) * 1.2, 1.0, 1.7)), false, 0.0])
			budget["he"] = budget.get("he", 0) - 1
	if not out.is_empty():
		# 발리스타 탑이 다 타서 무너질 때까지 기다린다
		out[out.size() - 1][3] = 10.0
	var extra: Dictionary = BONUS_PLAN.get(i, {}) if bonus else {}
	if d.get("launch_button", false):
		for k in extra:
			out.append_array(_bonus_steps(extra[k], d.parts[k][1], budget))
		out.append(["button"])
		return out
	var ci := 0
	var cluster := []
	for k in d.parts.size():
		var part: Array = d.parts[k]
		var opts: Dictionary = part[2] if part.size() > 2 else {}
		if extra.has(k):
			out.append_array(_bonus_steps(extra[k], part[1], budget))
			if not extra[k][0]:
				ci += _commanders_in(part)
				continue
		if part[0] == "bunker" or _in_rocket_cluster(d, part[1]):
			cluster.append(part[1])
		else:
			out.append_array(_part_plan(part[0], part[1], opts, rain, ci, budget))
		ci += _commanders_in(part)
	if not cluster.is_empty():
		var center := Vector3.ZERO
		for p in cluster:
			center += p
		center /= cluster.size()
		out.append([K.FLARE, center + Vector3(0, 0.3, 0), false, 0.0])
	return out


## BONUS_PLAN 한 부품의 단계 (자리는 부품 배율만큼 키운다. 폭탄 수는 budget에서 뺀다).
static func _bonus_steps(entry: Array, c: Vector3, budget: Dictionary) -> Array:
	var out := []
	for step in entry.slice(1):
		var s: Array = step.duplicate()
		if s[1] is Vector3:
			s[1] = c + s[1] * PART_SCALE
		if s[0] == K.HE:
			budget["he"] = budget.get("he", 0) - 1
		out.append(s)
	return out


## 부품 하나의 설계상 풀이. ammo: 아직 남은 탄 수 (폭탄이 남았으면 폭탄 풀이, 없으면 불 풀이를 고른다).
## 고르는 동안 쓴 폭탄 수는 ammo에서 뺀다.
static func _part_plan(kind: String, c: Vector3, o: Dictionary, rain: bool, ci: int, ammo: Dictionary) -> Array:
	var out := []
	var he: bool = ammo.get("he", 0) > 0 and not o.get("burn", false)
	# 불 풀이 (비가 오면 젖은 것에 기름부터)
	var burn := func(at: Vector3, high := false) -> void:
		if rain:
			out.append([K.OIL, at, high, 0.3])
		out.append([K.FIRE, at, high, 0.0])
	match kind:
		"tower":
			if he:
				# 앞 다리 사이 가로대에 폭탄 → 앞 다리 둘이 부러져 망루가 앞으로 넘어간다
				out.append([K.HE, c + Vector3(0, 1.5, 1.5), false, 0.0])
			else:
				burn.call(c + Vector3(0, 1.5, 1.5))
		"hut":
			if he:
				# 앞 창문으로 넣는다 (안에서 터진다)
				out.append([K.HE, c + Vector3(0, 1.45, 2.0), false, 0.0])
			else:
				burn.call(c + Vector3(1.2, 1.0, 2.1))
		"shelter":
			out.append([K.FIRE, c + Vector3(0, 2.9, 0), false, 6.0])
			out.append([K.FIRE, ci, true, 0.0])
		"windowpost":
			out.append([K.HE, c + Vector3(1.2, 1.5, 2.8), false, 3.0])
			out.append([K.HE, ci, false, 0.0])
		"bell":
			# 쇠종을 매단 밧줄과 종틀
			if he:
				# 종을 매단 가로보 한가운데에 폭탄 → 밧줄이 끊기고 종이 아래로 떠밀려 지붕 구멍으로 곧장 떨어진다
				out.append([K.HE, c + Vector3(0, 8.2, -0.6), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(0, 6.0, -0.1), false, 0.0])
		"powder":
			if he:
				# 창고에 폭탄 → 화약통 연쇄 폭발 → 금 간 기둥이 부러진다
				out.append([K.HE, c + Vector3(3.6, 2.2, 0.4), false, 0.0])
			else:
				burn.call(c + Vector3(3.6, 2.2, 0.4))
		"windmill":
			if he:
				out.append([K.HE, c + Vector3(0, 5.5, 1.35), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(0, 5.5, 1.35), false, 0.0])
		"courtyard":
			out.append([K.HE, c + Vector3(0, 1.5, 4.7), false, 2.0])
			if rain:
				out.append([K.OIL, c + Vector3(0, 2.9, 0), true, 0.3])
			out.append([K.FIRE, ci, true, 0.0])
		"pillars":
			out.append([K.HE, c + Vector3(crack_side(c) * 1.4, 1.0, 1.9), false, 0.0])
		"fortress":
			if o.get("wet", false):
				out.append([K.OIL, c + Vector3(0, 1.5, 1.5), true, 0.3])
				out.append([K.FIRE, c + Vector3(0, 1.5, 1.5), true, 0.0])
			elif ammo.get("fire", 0) > 0:
				# 성벽 앞으로 빠져나온 도화선 끝에 불 → 화약통이 터져 금 간 기둥이 부러진다
				out.append([K.FIRE, c + Vector3(fort_fuse_x(c), 0.1, FORT_FUSE_Z - 0.4), false, 0.0])
			else:
				# 성벽 너머로 높이 띄워 화약통에 폭탄
				out.append([K.HE, c + Vector3(fort_fuse_x(c), 0.75, 2.3), true, 0.0])
		"oilhouse":
			out.append([K.OIL, c + Vector3(0.3, 0.3, 5.0), false, 0.3])
			out.append([K.FIRE, c + Vector3(0.3, 0.1, 6.8), false, 0.0])
		"barn":
			burn.call(c + Vector3(0, 1.0, 2.15))
		"hopper":
			if rain:
				# 젖은 화약통에 기름을 붓고 불
				out.append([K.OIL, c + Vector3(_hopper_side(c) * 2.7, 0.6, -1.9), false, 0.3])
				out.append([K.FIRE, c + Vector3(_hopper_side(c) * 2.7, 0.6, -1.9), false, 0.0])
			else:
				out.append([K.FIRE, c + Vector3(_hopper_side(c) * 2.7, 0.6, -1.9), false, 0.0])
		"cave":
			out.append([K.HE, c + Vector3(-3.2, 2.2, 2.05), false, 2.0])
			burn.call(c + Vector3(3.2, 2.2, 1.9))
		"steelhut":
			# 성벽 위로 솟은 짚 지붕에 불 → 막사가 타며 안의 지휘관도 탄다
			out.append([K.FIRE, c + Vector3(0, 2.9, -0.4), false, 0.0])
		"rowhouses":
			# 끝의 두 집 사이 지붕에 불 → 잇닿은 지붕과 벽을 타고 나머지 집으로 번진다
			var n: int = o.get("count", 3)
			out.append([K.FIRE, c + Vector3(-ROW_W * (n - 1) * 0.5 + ROW_W * 0.5, ROW_H + 0.3, 0), false, 0.0])
		"guardhouse":
			# 문 앞 구경 자리에 조명탄 → 지휘관이 걸어 나오면 (화약통 더미가 있으면 그 더미에) 폭탄
			var side: float = o.get("door", 1)
			out.append([K.FLARE, c + _guard_spot(side) + Vector3(0, 0.1, 0), false, 6.5])
			if o.get("kegs", false):
				out.append([K.HE if he else K.FIRE, c + _guard_spot(side) + Vector3(side * 1.4, 0.75, -0.6), false, 0.0])
			else:
				out.append([K.HE if he else K.FIRE, ci, false, 0.0])
		"crane":
			# 쇠 상자를 매단 팔 끝 (밧줄이 붙은 곳)
			out.append([K.HE if he else K.FIRE, c + Vector3(-0.3, 8.7, 0), false, 0.0])
		"rampart":
			out.append([K.HE, c + Vector3(0, 1.0, 1.7), false, 0.0])
		"kegyard":
			# 방벽 옆으로 삐져나온 도화선 끝에 불 → 숨은 화약통이 터져 방벽과 지휘관 둘이 한꺼번에 날아간다
			out.append([K.FIRE, c + Vector3(KEG_FUSE_X, 0.1, 4.8), false, 0.0])
		"tent":
			out.append([K.FIRE, c + Vector3(0, 2.4, 0), false, 0.0])
	for step in out:
		if step[0] == K.HE:
			ammo["he"] = ammo.get("he", 0) - 1
		# 겨눌 곳은 부품 배율만큼 중심에서 멀어진다
		if step[1] is Vector3:
			step[1] = c + (step[1] - c) * PART_SCALE
	return out


# ---------- 부품 (위치 c는 대개 지휘관 자리) ----------

## 나무 망루. 다리에 불이 붙으면 번져 올라가 지휘관이 떨어진다. parapet: 위 난간이 돌 (폭탄과 불을 막는다).
static func _part_tower(s: Stage, c: Vector3, o: Dictionary) -> void:
	var legs: float = o.get("legs", 4.0)
	var st := s.add_structure()
	# 돌 난간 망루는 판자벽을 돌로 바꾸고, 나무 망루는 낮은 목재 난간과 사다리
	StageDefs.watchtower(st, c, legs, 1.6, not o.get("parapet", false))
	# 지은 블록은 부품 배율(k)만큼 커져 있다
	var k := s.build_scale
	if o.get("parapet", false):
		for b in st.blocks.duplicate():
			if b.mat == M.WOOD_THIN and b.position.y > (legs + 0.4) * k and b.position.y < (legs + 1.8) * k and (b.size.x < 0.15 * k or b.size.z < 0.15 * k):
				st.blocks.erase(b)
				# 다시 지을 때 또 키워지지 않게 키우기 전 자리와 크기로
				var size: Vector3 = b.size / k
				var pos: Vector3 = s.build_origin + (b.position - s.build_origin) / k
				b.free()
				st.add_block(M.STONE, pos, size)
	# 나무 다리 넷 중 둘 이상을 잃으면 그쪽으로 기울어 넘어간다
	_legs(st, func(b): return b.mat == M.WOOD_BEAM and absf(b.size.y - legs * k) < 0.01, 1)
	s.add_commander(c + Vector3(0, legs + 0.3, 0), 180.0, Vector3(0.9, 0, 0.6))
	s.add_guard(c + Vector3(-4, 0, 3), 180.0)


## 짚 지붕 판자 오두막 (앞벽 가운데 창문). 벽이 타면 안의 지휘관도 탄다.
static func _part_hut(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	StageDefs.hut(st, c, 2.0, 2.6)
	var cm := s.add_commander(c + Vector3(0, 0, -0.3), 180.0, Vector3(2.8, 0, 1.0))
	_room(s, cm, c, Vector3(-1.8, 0, -1.8), Vector3(1.8, 2.6, 1.8), st)


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
	# 종틀 높이: 부품 배율로 키운 뒤에도 먼 투척 언덕에서 가로보에 닿게 (키운 뒤 약 9.6m)
	var top := 8.0
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
	m.scale = Vector3.ONE * b.size.x / 1.2
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
			_pillar(st, M.STEEL if sx == 1 and sz == crack_side(c) else M.STONE, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	var deck := st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	deck.support_ratio = 1.0
	StageDefs.deck_ladder(deck, -1.0)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.STONE, c + Vector3(sx * 1.6, h + 1.5, sz * 1.6), Vector3(0.3, 2.2, 0.3))
	st.add_block(M.STONE, c + Vector3(0, h + 2.75, 0), Vector3(3.6, 0.3, 3.6))
	_legs(st, func(b): return b.start_low < 0.05, 0)
	var shed := s.add_structure()
	StageDefs.hut(shed, c + Vector3(3.6, 0, 0.2), 1.4, 2.0)
	# 폭발물 창고 표시: 앞벽에 폭발 표지판
	var front: Block = null
	for blk in shed.blocks:
		if blk.mat == M.WOOD_THIN and blk.size.y > 1.5 and blk.position.z > c.z + 0.5 and blk.position.x < c.x + 3.5 and (front == null or blk.position.x > front.position.x):
			front = blk
	if front:
		Models.blast_sign(front, Vector3(0, 0.1, front.size.z * 0.5 + 0.03), 0.27 * s.build_scale)
	# 앞 창문(가운데)으로 폭발통이 보이게 가운데 통을 한 단 더 쌓는다
	for k in 3:
		shed.add_block(M.KEG, c + Vector3(2.85 + k * 0.75, 0.375, 0.5), Vector3(0.75, 0.75, 0.75))
	shed.add_block(M.KEG, c + Vector3(3.6, 1.125, 0.5), Vector3(0.75, 0.75, 0.75))
	for k in 2:
		shed.add_block(M.KEG, c + Vector3(3.225 + k * 0.75, 0.375, -0.3), Vector3(0.75, 0.75, 0.75))
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
	_legs(st, func(b): return b.mat == M.WOOD_BEAM and absf(b.size.y - post_h * s.build_scale) < 0.01, 1)
	# 날개 (장식)
	var sail := Node3D.new()
	sail.position = s.at(c + Vector3(0, roof_y - 0.6, -1.9))
	sail.scale = Vector3.ONE * s.build_scale
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
	# 마당을 두르는 흰 돌담 (앞벽만 낡아 금이 갔다)
	s.add_enclosure(c + Vector3(0, 0, 0.5), Vector2(4.5, 4.25), 3.0, "stone", 0.5)
	var cm := s.add_commander(c, 180.0, Vector3(3.0, 0, -0.5))
	# 방은 안쪽 막사 (앞 석벽 창과 막사 창을 둘 다 지나야 한다)
	_room(s, cm, c, Vector3(-1.8, 0, -1.8), Vector3(1.8, 2.6, 1.8), st)


## 석재 망대 (기둥 넷 위 석재 바닥과 난간). 앞 왼쪽 기둥 하나만 금이 갔다.
## 그 기둥 하나만 부러져도 바닥이 기울어 꼭대기 지휘관이 떨어진다.
static func _part_pillars(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var h := 4.5
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.CRACKED if sx == crack_side(c) and sz == 1 else M.STONE, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	var deck := st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	deck.support_ratio = 1.0
	StageDefs.deck_ladder(deck, -crack_side(c))
	for sz in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(0, h + 0.8, sz * 1.65), Vector3(3.6, 0.8, 0.3))
	_legs(st, func(b): return b.start_low < 0.05, 0)
	s.add_commander(c + Vector3(0, h + 0.4, 0), 180.0, Vector3(1.0, 0, 0.9))
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 금 간 기둥이 앞 왼쪽(-1)인지 앞 오른쪽(+1)인지: 부품 자리로 정한다 (늘 같은 다리가 아니게. 설계 풀이와 탑이 같은 값을 쓴다).
## 뒤쪽 다리는 앞 기둥에 가려 던져 맞힐 수 없으므로 고르지 않는다.
static func crack_side(c: Vector3) -> float:
	return -1.0 if hash(Vector2i(roundi(c.x), roundi(c.z))) % 2 == 0 else 1.0


## 공성탑 요새의 도화선이 성벽 앞으로 뻗어 나온 끝 z와 도화선 x (부품 중심 기준, 성벽은 +6).
## 도화선과 화약통은 금 간 기둥 쪽에 있다.
const FORT_FUSE_Z := 9.4


static func fort_fuse_x(c: Vector3) -> float:
	return crack_side(c) * 0.75


## 공성탑 요새: 앞 성벽(반듯한 흰 돌, 강철 문) 너머 안뜰의 망루.
## 기본: 흰 돌 망루 (기둥 넷 중 앞 왼쪽 하나만 금이 갔고, 위 앞면은 창 난 돌벽이라 창으로 지휘관만 보인다).
##   금 간 기둥 발치에 화약통, 검정·노랑 도화선이 강철 문 밑 틈으로 성벽 앞까지 빠져나와 있다.
##   도화선 끝에 불 → 화약통이 터져 금 간 기둥이 부러지고 망루가 기운다 (성벽 너머로 높이 띄워 기둥이나 화약통에 폭탄을 넣어도 된다).
## wet: 화약통 없이 돌 난간 두른 젖은 나무 탑 (기름과 불을 높이 띄워 넣는다).
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
	# 강철 문은 땅에서 살짝 떠 있다 (그 틈으로 도화선이 빠져나온다)
	wall.add_block(M.STEEL, Vector3(c.x, 1.675, wz), Vector3(2.25, 3.05, 0.5))
	wall.add_block(M.STONE, Vector3(c.x, 3.85, wz), Vector3(2.25, 1.3, 1.0))
	# 성벽이 안뜰을 두르고 있다 (양옆과 뒤로 이어지는 성벽, 판정 없는 배경)
	s.add_enclosure(c + Vector3(0, 0, -1.5), Vector2(10.125, 7.5), 4.5, "stone", 1.0)
	if o.get("wet", false):
		_part_tower(s, c, {"legs": 6.0, "parapet": true})
		s.add_guard(c + Vector3(5, 0, 2), 180.0)
		return
	var st := s.add_structure()
	var h := 6.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pillar(st, M.STEEL if sx == crack_side(c) and sz == 1 else M.STONE, c + Vector3(sx * 1.4, h * 0.5, sz * 1.4), Vector3(0.8, h, 0.8))
	var deck := st.add_block(M.STONE, c + Vector3(0, h + 0.2, 0), Vector3(3.6, 0.4, 3.6))
	deck.support_ratio = 1.0
	StageDefs.deck_ladder(deck, -crack_side(c))
	# 앞면: 창 난 돌벽 (창으로 지휘관이 보인다), 옆과 뒤는 낮은 돌 난간
	StageDefs.window_wall(st, M.STONE, c + Vector3(0, h + 0.4, 1.65), 3.6, [0.9, 0.6, 0.9], 5, [2], 0.3)
	st.add_block(M.STONE, c + Vector3(0, h + 0.8, -1.65), Vector3(3.6, 0.8, 0.3))
	for sx in [-1, 1]:
		st.add_block(M.STONE, c + Vector3(sx * 1.65, h + 0.8, 0), Vector3(0.3, 0.8, 3.0))
	_legs(st, func(b): return b.start_low < 0.05, 0)
	s.add_commander(c + Vector3(0, h + 0.4, -0.2), 180.0, Vector3(1.0, 0, -0.9))
	var yard := s.add_structure()
	var kegs: Array[Block] = []
	for k in 3:
		kegs.append(yard.add_block(M.KEG, c + Vector3(crack_side(c) * (1.5 - k * 0.75), 0.375, 2.3), Vector3(0.75, 0.75, 0.75)))
	# 도화선: 가운데 화약통에서 강철 문 밑 틈을 지나 성벽 앞까지 (끝에 불을 붙이면 타 들어가 화약통이 터진다)
	_fuse(yard, c + Vector3(fort_fuse_x(c), 0, 2.675), c + Vector3(fort_fuse_x(c), 0, FORT_FUSE_Z), 11, false, [kegs[1]])
	s.add_guard(c + Vector3(5, 0, 2), 180.0)


## 창문 판정용 방: 지휘관이 든 방(부품 기준 lo~hi)과 그 벽 (Stage._mark_window_entry).
static func _room(s: Stage, cm: Commander, c: Vector3, lo: Vector3, hi: Vector3, walls: Structure) -> void:
	var a := s.at(c + lo)
	cm.set_meta("room", AABB(a, s.at(c + hi) - a))
	cm.set_meta("room_walls", walls.blocks.duplicate())


## 석재 망대의 기둥: 강철 기둥은 폭발통 같은 큰 폭발에만 부러지지만 겉모양은 깨끗한 흰 석재로 맞춘다.
static func _pillar(st: Structure, mat: int, center: Vector3, size: Vector3) -> void:
	var b := st.add_block(mat, center, size)
	if mat == M.STEEL:
		b.look_like_stone()


## 도화선 한 줄 (a → b, 땅 위). 맞닿은 밧줄 토막을 따라 불이 번진다. 검정·노랑 줄무늬로 눈에 띈다.
## 조각끼리, 그리고 a 쪽 끝과 ends(그 끝에 닿은 화약통들)는 서로 불을 넘기도록 따로 이어 둔다
## (폭발에 밀려 떨어져 나가도 불은 끝까지 타 들어간다). wet: 비 오는 날 젖어서 기름을 묻혀야 탄다.
static func _fuse(st: Structure, a: Vector3, b: Vector3, n: int, wet := false, ends := []) -> void:
	var h := 0.12
	var d := b - a
	var seg := d.length() / n
	var along_x := absf(d.x) > absf(d.z)
	var pieces: Array[Block] = []
	for k in n:
		var p := a + d * ((k + 0.5) / n) + Vector3(0, h * 0.5, 0)
		var size := Vector3(seg, h, 0.14) if along_x else Vector3(0.14, h, seg)
		var blk := st.add_block(M.ROPE, p, size)
		blk.set_color(FUSE_BLACK if k % 2 == 0 else FUSE_YELLOW)
		if wet:
			blk.set_meta("rain_wets", true)
		pieces.append(blk)
	for k in n:
		if k > 0:
			pieces[k].fuse_links.append(pieces[k - 1])
		if k < n - 1:
			pieces[k].fuse_links.append(pieces[k + 1])
	for keg in ends:
		pieces[0].fuse_links.append(keg)


const FUSE_BLACK := Color(0.1, 0.09, 0.08)
const FUSE_YELLOW := Color(1.0, 0.8, 0.12)


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
	# 건물 앞으로 뻗은 도화선: 비에 젖어 기름을 묻혀야 타고, 타 들어가 안쪽 연료 배관에 불이 붙는다
	_fuse(st, c + Vector3(0.3, 0, half - 1.0), c + Vector3(0.3, 0, half + 4.0), 5, true)
	for i in 4:
		st.add_block(M.FUEL, c + Vector3(0.3, 0.15, half - 1.4 - i * 0.8), Vector3(0.3, 0.3, 0.8))
	var cm := s.add_commander(c + Vector3(-1.0, 0, -1.2), 180.0, Vector3(-1.2, 0, -0.4))
	_room(s, cm, c, Vector3(-2.4, 0, -2.4), Vector3(2.4, 3.0, 2.4), st)


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
	var cm := s.add_commander(c + Vector3(0, 0, -0.5), 180.0, Vector3(2.8, 0, 2.8))
	_room(s, cm, c, Vector3(-half + 0.2, 0, -half + 0.2), Vector3(half - 0.2, height, half - 0.2), st)
	s.add_guard(c + Vector3(4, 0, 3), 180.0)


## 석탄 호퍼: 돌집 안의 지휘관. 앞과 옆 벽, 지붕이 석재라 폭탄이 안 통하고 뒤쪽만 뚫려 있다.
## 앞벽 가운데 작은 창으로 안의 지휘관이 보인다 (창으로 집어넣으면 보조 목표).
## 화약통은 집 뒤 땅에 놓여 플레이어 쪽 집 옆으로 삐져나와 보인다. 통을 터뜨리면 뚫린 뒤쪽으로 폭풍이 들어가 지휘관이 쓰러진다.
## 비가 오면 화약통이 젖어 기름을 부어야 탄다.
static func _hopper_side(c: Vector3) -> float:
	return 1.0 if c.x <= 0.5 else -1.0


static func _part_hopper(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var side := _hopper_side(c)
	var house := s.add_structure()
	# 앞벽 가운데 폭탄이 겨우 들어가는 작은 창 (안의 지휘관이 보인다)
	StageDefs.window_wall(house, M.STONE, c + Vector3(0, 0, 1.15), 3.6, [1.0, 0.6, 0.8], 5, [2], 0.3)
	for sx in [-1, 1]:
		house.add_block(M.STONE, c + Vector3(sx * 1.65, 1.2, 0), Vector3(0.3, 2.4, 2.6))
	house.add_block(M.STONE, c + Vector3(0, 2.6, 0), Vector3(4.0, 0.4, 3.2))
	var yard := s.add_structure()
	var keg := yard.add_block(M.KEG, c + Vector3(side * 2.7, 0.6, -2.4), Vector3(1.2, 1.2, 1.2))
	keg.set_meta("rain_wets", true)
	var cm := s.add_commander(c + Vector3(0, 0, -0.5), 180.0, Vector3(0.0, 0, 0.8))
	_room(s, cm, c, Vector3(-1.5, 0, -1.3), Vector3(1.5, 2.4, 1.0), house)


## 절벽 밑 감시굴 (E6): 석재 덮개가 금 간 돌기둥(왼쪽)과 나무 버팀목(오른쪽)에만 얹혀 있다.
## o.keg: 갱도 입구 앞 돌무더기 위에 비 안 맞는 폭발통 (덮개와 앞 바위 사이 틈으로 불항아리를 넣어 통 앞 바닥에 떨어뜨리면 불웅덩이에 터진다: 보조 목표).
##   이때 지휘관은 불에 안 탄다 (불항아리 웅덩이로 먼저 쓰러지지 않게).
static func _part_cave(s: Stage, c: Vector3, o: Dictionary) -> void:
	# 무너진 갱도 입구: 절벽 한가운데 뚫린 검은 굴, 부러져 기운 나무 받침틀, 입구를 반쯤 메운 돌무더기
	var cliff := Color(0.55, 0.47, 0.43)
	var timber := Color(0.36, 0.24, 0.13)
	for sx in [-1.0, 1.0]:
		s.add_rock(c + Vector3(sx * 4.8, 6, -4.5), Vector3(5, 12, 4), cliff)
	s.add_rock(c + Vector3(0, 8.2, -4.5), Vector3(4.6, 7.6, 4), cliff)
	s.add_rock(c + Vector3(0, 13, -1.5), Vector3(14, 2, 4), Color(0.47, 0.4, 0.37))
	s.add_rock(c + Vector3(0, 2.2, -6.6), Vector3(4.6, 4.4, 1.8), cliff)
	s.add_prop(c + Vector3(0, 2.2, -5.65), Vector3(4.6, 4.4, 0.1), Color(0.03, 0.025, 0.025), false)
	for sx in [-1.0, 1.0]:
		s.add_prop(c + Vector3(sx * 2.25, 2.2, -4.0), Vector3(0.06, 4.4, 3.4), Color(0.08, 0.07, 0.06), false)
	s.add_prop(c + Vector3(-2.5, 1.8, -2.3), Vector3(0.4, 3.7, 0.4), timber, false).rotation.z = 0.1
	s.add_prop(c + Vector3(2.55, 1.0, -2.3), Vector3(0.4, 2.4, 0.4), timber, false).rotation.z = -0.6
	s.add_prop(c + Vector3(-0.7, 3.8, -2.3), Vector3(3.6, 0.4, 0.45), timber, false).rotation.z = -0.3
	s.add_rock(c + Vector3(1.3, 0.55, -3.6), Vector3(2.6, 1.1, 1.2), Color(0.5, 0.43, 0.39))
	s.add_rock(c + Vector3(-1.2, 0.4, -3.7), Vector3(1.8, 0.8, 1.0), Color(0.47, 0.4, 0.37))
	s.add_rock(c + Vector3(2.0, 1.3, -3.7), Vector3(1.4, 0.9, 0.9), Color(0.52, 0.45, 0.4))
	var st := s.add_structure()
	st.add_block(M.CRACKED, c + Vector3(-3.2, 1.4, 1.6), Vector3(0.9, 2.8, 0.9))
	st.add_block(M.WOOD_BEAM, c + Vector3(3.2, 1.4, 1.6), Vector3(0.55, 2.8, 0.55))
	var cover := st.add_block(M.STONE, c + Vector3(0, 3.2, -0.2), Vector3(7.4, 0.8, 4.6))
	cover.support_ratio = 0.5
	st.add_block(M.STONE, c + Vector3(-0.8, 3.95, -0.8), Vector3(1.6, 0.7, 1.4))
	st.add_block(M.STONE, c + Vector3(1.4, 3.85, 0.2), Vector3(1.1, 0.5, 1.0))
	s.add_rock(c + Vector3(0, 0.8, 2.8), Vector3(7.0, 1.6, 0.8), Color(0.5, 0.43, 0.4))
	var cm := s.add_commander(c + Vector3(0, 0, -0.8), 180.0, Vector3(1.0, 0, -0.6))
	if o.get("keg", false):
		cm.fireproof = true
		var keg := s.add_structure().add_block(M.KEG, c + Vector3(1.3, 1.6, -3.6), Vector3(1.0, 1.0, 1.0))
		keg.set_meta("bonus_keg", true)
		keg.set_meta("dry", true)


## 강철 성벽 뒤 나무 막사 (짚 지붕). 성벽은 폭탄으로 안 부서지지만 가운데 작은 창으로 막사 창 너머 지휘관이 보이고,
## 짚 지붕은 성벽보다 높아 밖에서 보인다. 지붕에 불을 붙이면 판자 벽으로 번져 앞벽 바로 뒤의 지휘관도 탄다.
static func _part_steelhut(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var wall := s.add_structure()
	StageDefs.window_wall(wall, M.STEEL, c + Vector3(0, 0, 3.2), 8.0, [1.2, 0.6, 0.8], 5, [2], 0.4)
	# 막사 마당을 두르는 강철 성벽 (앞벽에만 작은 창)
	s.add_enclosure(c + Vector3(0, 0, 0.2), Vector2(4.0, 3.2), 2.6, "steel", 0.4)
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
		# 양옆으로 이어지는 관문 성벽 (판정 없는 배경)
		s.add_wall_prop(c + Vector3(sx * 9.0, 2.15, 0.6), Vector3(10.0, 4.3, 1.6), "stone")
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
	# 보급 마당: 왼쪽과 뒤는 강철 방벽, 오른쪽 뒤에는 보급 상자 더미 (오른쪽 앞은 도화선이 빠져나가는 틈)
	s.add_enclosure(c + Vector3(0, 0, -0.6), Vector2(4.5, 3.6), 3.0, "steel", 0.4, "lb")
	for k in 3:
		s.add_wall_prop(c + Vector3(4.0 - (k % 2) * 0.2, 0.5 + (k / 2) * 1.0, -2.6 + (k % 2) * 1.1), Vector3(1.0, 1.0, 1.0), "plank", 0.2 * k)
	# 도화선: 화약통 오른쪽에서 방벽 뒤를 따라 끝까지, 방벽 끝을 돌아 앞으로 (맞닿은 밧줄 토막을 따라 불이 번진다)
	_fuse(yard, c + Vector3(0.5, 0, 1.4), c + Vector3(KEG_FUSE_X - 0.07, 0, 1.4), 8, false, [keg])
	_fuse(yard, c + Vector3(KEG_FUSE_X, 0, 1.33), c + Vector3(KEG_FUSE_X, 0, 5.6), 7)
	s.add_commander(c + Vector3(-2.25, 0, 0.8), 180.0, Vector3(-1.0, 0, -0.8))
	s.add_commander(c + Vector3(2.25, 0, 0.8), 180.0, Vector3(1.0, 0, -0.8))


## 짚 지붕 줄집 (불이 번지는 것을 배운다): 흰 돌 앞담 뒤에 통나무 벽 집이 나란히 붙어 있고 짚 지붕이 잇닿았다.
## (통나무 벽은 묵직한 화염 항아리에 맞아도 안 부서져서 불이 차례로 번진다.)
## 집마다 지휘관이 뒷벽에 붙어 선다. 흰 돌담이 폭발을 막아 폭탄으로는 한 채씩도 어렵지만, 한 채에 불이 붙으면
## 맞닿은 지붕과 벽을 타고 옆집으로 번진다. o.count: 집 수 (기본 3).
const ROW_W := 3.0
const ROW_H := 2.4


static func _part_rowhouses(s: Stage, c: Vector3, o: Dictionary) -> void:
	var n: int = o.get("count", 3)
	var st := s.add_structure()
	var half := ROW_W * 0.5
	var x0 := -ROW_W * (n - 1) * 0.5
	for k in n:
		var hc := c + Vector3(x0 + k * ROW_W, 0, 0)
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, hc + Vector3(0, ROW_H * 0.5, sz * (half - 0.1)), Vector3(ROW_W, ROW_H, 0.2))
		# 집 사이 벽은 하나씩 (양 끝은 바깥 벽)
		st.add_block(M.WOOD_BEAM, hc + Vector3(-half + 0.1, ROW_H * 0.5, 0), Vector3(0.2, ROW_H, ROW_W - 0.4))
		if k == n - 1:
			st.add_block(M.WOOD_BEAM, hc + Vector3(half - 0.1, ROW_H * 0.5, 0), Vector3(0.2, ROW_H, ROW_W - 0.4))
		st.add_block(M.STRAW, hc + Vector3(0, ROW_H + 0.15, 0), Vector3(ROW_W, 0.3, ROW_W + 0.3))
		s.add_commander(hc + Vector3(0, 0, -0.75), 180.0, Vector3(0.9, 0, 4.3))
	# 흰 돌 앞담 (허리 높이: 지붕과 벽은 보인다)과 집 뒤뜰을 두르는 낮은 돌담
	var wall := s.add_structure()
	wall.add_block(M.STONE, c + Vector3(0, 0.55, half + 1.2), Vector3(ROW_W * n + 1.0, 1.1, 0.5))
	s.add_enclosure(c + Vector3(0, 0, 0.0), Vector2(ROW_W * n * 0.5 + 0.5, half + 1.45), 1.1, "stone", 0.5)


## 강철 초소의 구경 자리 (부품 중심 기준): 문 밖 옆 빈터.
static func _guard_spot(side: float) -> Vector3:
	return Vector3(side * 5.2, 0, 1.2)


## 밤의 강철 초소 (구경꾼): 사방이 강철, 지붕도 강철이라 폭탄도 불도 안 통한다. 문은 옆으로 나 있어 밖에서 안이 안 보인다.
## 안의 지휘관은 조명탄 불빛이 문 밖 구경 자리 근처에 켜지면 걸어 나와 구경하다가, 꺼지면 다시 들어간다.
## o.door: 문 방향 (1 = 오른쪽, -1 = 왼쪽). o.kegs: 구경 자리 곁에 화약통 더미 (터뜨리면 구경꾼이 같이 날아간다).
static func _part_guardhouse(s: Stage, c: Vector3, o: Dictionary) -> void:
	var side: float = o.get("door", 1)
	var st := s.add_structure()
	var half := 1.7
	var h := 2.4
	var t := 0.3
	for sz in [-1, 1]:
		st.add_block(M.STEEL, c + Vector3(0, h * 0.5, sz * (half - t * 0.5)), Vector3(half * 2.0, h, t))
	var inner := half * 2.0 - t * 2.0
	# 막힌 옆벽
	st.add_block(M.STEEL, c + Vector3(-side * (half - t * 0.5), h * 0.5, 0), Vector3(t, h, inner))
	# 문 난 옆벽: 가운데 1.4m 문 + 문 위 상인방
	var door := 1.4
	var piece := (inner - door) * 0.5
	for sz in [-1, 1]:
		st.add_block(M.STEEL, c + Vector3(side * (half - t * 0.5), h * 0.5, sz * (door * 0.5 + piece * 0.5)), Vector3(t, h, piece))
	st.add_block(M.STEEL, c + Vector3(side * (half - t * 0.5), h - 0.15, 0), Vector3(t, 0.3, door))
	st.add_block(M.STEEL, c + Vector3(0, h + 0.15, 0), Vector3(half * 2.0 + 0.2, 0.3, half * 2.0 + 0.2))
	var spot := c + _guard_spot(side)
	var cm := s.add_commander(c + Vector3(-side * 0.4, 0, -0.5), 180.0, Vector3(-side * 2.6, 0, 2.4))
	cm.set_lure([cm.position, s.at(c + Vector3(side * 0.3, 0, 0)), s.at(c + Vector3(side * (half + 0.8), 0, 0)), s.at(spot)])
	if o.get("kegs", false):
		var yard := s.add_structure()
		for k in 3:
			var kp := spot + Vector3(side * 1.4, 0.375 + (0.75 if k == 2 else 0.0), -0.6 + (0.75 if k == 1 else 0.0) + (0.375 if k == 2 else 0.0))
			yard.add_block(M.KEG, kp, Vector3(0.75, 0.75, 0.75))


## 짚 천막: 짚 벽 셋과 문 난 앞벽, 짚 지붕. 지휘관이 안에서 잔다.
static func _part_tent(s: Stage, c: Vector3, _o: Dictionary) -> void:
	var st := s.add_structure()
	var h := 2.2
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


## ---------- 지원 진지 (1-10 마을 정문) ----------
## 폭발통을 진 동료 고블린이 마을 길을 따라 닫힌 강철 성문까지 걷는다. 걷기 시작하면 심지에 불이 붙어 타 들어가고,
## 성문 앞에 닿으면 스스로 터진다. 플레이어는 길을 막은 것을 차례로 치워 준다:
##   병사 셋(다가오면 창을 겨누고 싸우려 든다) → 목책 망루의 통나무 문(쇠사슬로 엮어 폭탄에는 끄떡없지만 불에는 탄다)
##   → 금 간 석재 성벽 (폭탄). 목책과 성벽은 양옆으로 길게 이어져 돌아갈 길이 없다.
## 지휘관은 성문 뒤에서 빗장을 붙들고 버틴다. 폭발통이 터지면 성문째 날아간다.
const ALLY_PTS := [Vector3(-12, 0, -14), Vector3(-5, 0, -28), Vector3(-1.5, 0, -42), Vector3(0, 0, -57.2)]
const ALLY_GATE_Z := -58.6
const ALLY_SOLDIERS := 11.0
const ALLY_TOWER := 24.0
const ALLY_WALL := 36.0


static func _ally_stage(s: Stage, id: String, title_text: String) -> void:
	s.begin(id, title_text, false)
	s.set_zone(Vector3(0, 8.0, 0), Vector2(3.0, 3.0))
	var pts: Array = ALLY_PTS
	# 성문: 흰 돌 성문 기둥과 양옆으로 길게 이어진 성벽, 닫힌 강철 성문 두 짝과 안쪽 나무 빗장
	var gate := Vector3(0, 0, ALLY_GATE_Z)
	var st := s.add_structure()
	# 성문은 동료의 폭발통으로만 부서진다 (플레이어의 투척과 떨어지는 잔해는 통하지 않는다)
	st.player_proof = true
	for sx in [-1, 1]:
		st.add_block(M.STONE, gate + Vector3(sx * 2.6, 2.75, 0), Vector3(1.6, 5.5, 2.0))
		st.add_block(M.STEEL, gate + Vector3(sx * 0.9, 2.0, 0.25), Vector3(1.8, 4.0, 0.3))
	st.add_block(M.STONE, gate + Vector3(0, 4.75, 0), Vector3(3.6, 1.5, 2.0))
	st.add_block(M.WOOD_BEAM, gate + Vector3(0, 1.6, -0.15), Vector3(3.4, 0.3, 0.3))
	for sx in [-1, 1]:
		s.add_wall_prop(gate + Vector3(sx * 13.4, 2.5, 0), Vector3(20.0, 5.0, 1.8), "stone")
		s.add_wall_prop(gate + Vector3(sx * 6.0, 3.5, 0), Vector3(2.4, 7.0, 2.6), "stone")
	var cm := s.add_commander(gate + Vector3(0, 0, -1.0), 180.0, Vector3(3.6, 0, -1.6))
	cm.hold_bar = true
	# 1) 병사 셋이 길을 막아선다
	var g := []
	for k in 3:
		var gp := StageDefs._along(pts, ALLY_SOLDIERS) + Vector3(-1.0 + k * 1.0, 0, (k % 2) * 0.6)
		g.append(s.add_guard(gp, 20.0, true))
	# 2) 목책 망루: 길 양옆으로 긴 통나무 목책, 길 위에는 망루와 통나무 문
	var tp := StageDefs._along(pts, ALLY_TOWER)
	# 길은 거의 앞뒤로 나 있어 문과 목책은 좌우(x)로 가로지른다
	var side := Vector3.RIGHT
	var tower := s.add_structure()
	for sx in [-1, 1]:
		tower.add_block(M.WOOD_BEAM, tp + side * sx * 1.5 + Vector3(0, 2.5, 0), Vector3(0.6, 5.0, 0.6))
	var doors := []
	for k in 4:
		var dp := tp + side * (-0.9 + k * 0.6) + Vector3(0, 1.3, 0)
		doors.append(tower.add_block(M.WOOD_BEAM, dp, Vector3(0.55, 2.6, 0.45)))
	tower.add_block(M.WOOD_THIN, tp + Vector3(0, 5.15, 0), Vector3(3.6, 0.3, 2.0))
	tower.add_block(M.STRAW, tp + Vector3(0, 6.95, 0), Vector3(3.8, 0.3, 2.4))
	for sx in [-1, 1]:
		tower.add_block(M.WOOD_THIN, tp + side * sx * 1.5 + Vector3(0, 6.05, 0), Vector3(0.25, 1.5, 0.25))
		s.add_wall_prop(tp + side * sx * 11.8 + Vector3(0, 1.6, 0), Vector3(20.0, 3.2, 0.5), "plank")
	# 3) 금 간 석재 성벽: 길을 가로지른 한 칸만 낡아 금이 갔고, 양옆은 흰 돌 성벽으로 길게 이어진다
	var wp := StageDefs._along(pts, ALLY_WALL)
	var wside := Vector3.RIGHT
	# 마을 정문: 금 간 석재 문짝 두 짝 (쇠 띠와 손잡이가 달린 문)
	var fence := s.add_structure()
	for sx in [-1.0, 1.0]:
		var leaf := fence.add_block(M.CRACKED, wp + wside * (sx * 0.75) + Vector3(0, 1.2, 0), Vector3(1.5, 2.4, 0.6))
		leaf.add_door_details(-sx)
	for sx in [-1, 1]:
		s.add_wall_prop(wp + wside * sx * 11.5 + Vector3(0, 1.4, 0), Vector3(20.0, 2.8, 0.8), "stone")
	var obstacles := [
		{"distance": ALLY_SOLDIERS, "cleared": func(): return g.all(func(x): return x.dead)},
		{"distance": ALLY_TOWER, "cleared": func(): return doors.all(func(x): return not is_instance_valid(x) or x.burnt or x.fallen)},
		{"distance": ALLY_WALL, "cleared": func(): return StageDefs._path_open(fence, pts, ALLY_WALL)},
	]
	var ally := s.add_ally(pts, 1.8, obstacles)
	ally.auto_fuse = true
	for x in g:
		x.watch = ally


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


## 밤: 지휘관 곁에는 불이 없다 (어둠 속 표적은 조명탄으로 비춰 봐야 보인다).
## 부품마다 앞 모서리에서 조금 떨어진 곳에 횃불 하나만 두어 진지가 어디쯤인지만 어렴풋이 보인다.
static func _torches(s: Stage, d: Dictionary) -> void:
	for part in d.get("parts", []):
		var c: Vector3 = part[1]
		var side := 1.0 if c.x <= 0.0 else -1.0
		s.add_torch(Vector3(c.x + side * 6.5, 0, c.z + 5.0))


## 대공 발리스타 탑. wood: 나무 다리 (불), stone: 석재 기둥 넷 중 앞 왼쪽 하나만 금이 갔다 (그 하나만 부러뜨리면 기운다).
static func _ballista(s: Stage, pos: Vector3, kind: String) -> void:
	var st := s.add_structure()
	var legs := 5.0
	var wood := kind == "wood"
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var leg_mat := M.WOOD_BEAM if wood else (M.CRACKED if sx == crack_side(pos) and sz == 1 else M.STONE)
			st.add_block(leg_mat, pos + Vector3(sx * 1.2, legs * 0.5, sz * 1.2), Vector3(0.5, legs, 0.5) if wood else Vector3(0.7, legs, 0.7))
	if wood:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, pos + Vector3(0, 1.5, sz * 1.2), Vector3(1.9, 0.25, 0.25))
	var deck := st.add_block(M.WOOD_THIN if wood else M.STONE, pos + Vector3(0, legs + 0.15, 0), Vector3(3.0, 0.3, 3.0))
	if not wood:
		deck.support_ratio = 1.0
	StageDefs.deck_ladder(deck, -crack_side(pos))
	var b := st.add_block(M.WOOD_BEAM, pos + Vector3(0, legs + 0.55, 0), Vector3(0.6, 0.5, 0.6))
	s.add_ballista(b)
	# 나무 탑은 다리 둘을 잃으면, 석재 탑은 금 간 기둥 하나만 잃어도 그쪽으로 기운다
	_legs(st, func(x): return x.start_low < 0.05, 1 if wood else 0)


## 부품의 다리 묶음 등록 (filter에 맞는 블록이 다리).
static func _legs(st: Structure, filter: Callable, max_lost: int) -> void:
	st.add_leg_group(st.blocks.filter(filter), max_lost)
