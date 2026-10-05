class_name Texts
extends RefCounted
## 화면 문구 모음 (나중에 번역하기 쉽게 한 파일에 모은다).
## 화면 글자는 최소로: 탄종·남은 탄·폭격대는 그림(UiIcon)으로 보여 주고, 꼭 글로 적어야 하는 것(메뉴, 조작, 실패 원인)은
## 고블린 말투로 짧게 적는다. 실패 문구는 원인을 정확히 가리킨다.

const T := {
	# 고블린 외침
	"start": "부숴라!",
	"continue": "계속 부숴라!",
	"quit": "튀어!",
	"retry": "다시 던져!",
	"next": "다음 진지로!",
	"last_shot": "마지막 한 방이다!",
	"win": "박살!",
	"fail_ammo": "폭탄을 다 썼잖아!!",
	"fail_messenger": "전령이 도착했잖아!!",
	"kill_one": "하나 박살!",
	"button_fire": "발사!!!",
	"button_locked": "꼬챙이 쏘는 놈(발리스타)부터 부숴! 단추가 꿈쩍 안 해",
	"night_hint": "밤이다! 번쩍봉을 던지면 떨어진 자리가 한동안 환해진다. 비추는 동안 던져라",
	"button_guarded": "경비대장 둘이 발사대를 막고 있다! 그놈들부터 날려",
	# 메뉴 (그림으로 바꾸기 애매한 것은 고블린 말투로)
	"game_title": "미친 고블린",
	"game_subtitle": "부족장 내놔! 안 내놓으면, 펑!",
	"menu_start": "부수러 가자!",
	"menu_continue": "계속 부수자!",
	"menu_select": "어디 부술까?",
	"menu_opening": "어쩌다 이리 됐더라",
	"menu_settings": "이것저것 만지기",
	"menu_quit": "그만 잘래",
	"menu_back": "뒤로!",
	"menu_resume": "계속 던져!",
	"menu_restart": "처음부터 다시!",
	"menu_title": "첫 화면으로 도망!",
	"paused": "잠깐! 숨 좀 돌리자",
	"locked": "아직 꽁꽁",
	"set_sens": "눈알 굴리는 빠르기",
	"set_volume": "쾅! 소리 크기",
	"set_fullscreen": "화면 꽉 채우기",
	"set_reset": "처음부터 다시 하기 (저장 지우기)",
	"set_reset_confirm": "정말 다 지울래? 한 번 더 누르면 지워져!",
	"set_reset_done": "싹 지웠다! 처음부터 시작이야.",
	"menu_unlock_all": "[임시] 전체 개방",
	# 짧은 알림
	"empty_slot": "그건 다 던졌어!",
	"rocket_shot_down": "으악! 글라이더가 꼬챙이에 맞았다!!",
	"press_button": "E  빨간 단추 꾸욱!",
	"rocket_name": "왕큰펑",
	"airstrike_name": "하늘쾅",
	"skip_intro": "아무거나 누르면 건너뛰기",
	"any_key": "아무거나 눌러!",
	"help": "WASD 걷기 · 마우스 두리번 · 왼쪽 꾹 = 힘 모으기, 떼면 휙! · 오른쪽 = 눈 크게 / 그만 · 1~5·휠 폭탄 바꾸기 · R 다시 · Esc 잠깐",
	# 별 조건 (좌상단 목표)
	"goal_flags": "모든 깃발 꺾기",
	"goal_ammo": "폭탄 남기고 클리어하기",
	# 별 평가 보조 목표 (고블린 말투)
	"bonus_direct": "정통으로 맞히기",
	"bonus_direct_n": "직격으로 %d명 잡기",
	"bonus_window": "창문으로 집어넣기",
	"bonus_ally": "아군 고블린 돕기",
	"bonus_he_two": "쾅쾅알 하나로 병사 두 명 잡기",
	"bonus_sky_two": "하늘쾅 한 발로 깃발 두 개 꺾기",
	"bonus_keg": "폭발통 터트리기",
	"bonus_indirect": "맞히지 말고 무너뜨리거나 태워서만!",
	"bonus_without_fire": "화염 항아리 없이!",
	"bonus_without_he": "폭탄 없이!",
	"bonus_without_oil": "기름 단지 없이!",
	"bonus_without_flare": "조명탄 없이 깜깜한 채로!",
	"bonus_without_paint": "물감탄 없이 감으로!",
	"bonus_throws": "%d번만 던져서!",
	"bonus_one_throw": "한 발로 클리어하기",
	"bonus_no_shotdown": "글라이더 잃지 않기",
	"bonus_archer": "궁수 정통으로 맞히기",
	"bonus_archer_two": "궁수 둘 맞히기",
	"bonus_sky_three": "하늘쾅 한 발로 깃발 세 개 꺾기",
	"bonus_he_left": "쾅쾅알 %d개 남기기",
	"bonus_direct_on_rampart": "성문 지휘관 맞히기",
	"bonus_one_go": "한 방에 다 같이!",
	"opening_hint": "클릭 / 스페이스 ▶     Esc 건너뛰기",
}



static func t(key: String) -> String:
	return T.get(key, key)
