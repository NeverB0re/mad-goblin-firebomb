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
	"fail_stuck": "이 폭탄으로는 더 못 깨잖아!!",
	"kill_one": "하나 박살!",
	"button_fire": "발사!!!",
	"button_locked": "꼬챙이 쏘는 놈(발리스타)부터 부숴! 단추가 꿈쩍 안 해",
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
	"menu_resume": "다시 던지자!",
	"menu_restart": "처음부터 다시!",
	"menu_title": "첫 화면으로 도망!",
	"paused": "잠깐! 숨 좀 돌리자",
	"locked": "아직 꽁꽁",
	"best_left": "제일 잘했을 때 %d발 남김",
	"set_sens": "눈알 굴리는 빠르기",
	"set_volume": "쾅! 소리 크기",
	"set_fullscreen": "화면 꽉 채우기",
	# 짧은 알림
	"empty_slot": "그건 다 던졌어!",
	"rocket_shot_down": "으악! 글라이더가 꼬챙이에 맞았다!!",
	"press_button": "E  빨간 단추 꾸욱!",
	"skip_intro": "아무거나 누르면 건너뛰기",
	"any_key": "아무거나 눌러!",
	"help": "WASD 걷기 · 마우스 두리번 · 왼쪽 꾹 = 힘 모으기, 떼면 휙! · 오른쪽 = 눈 크게 / 그만 · 1~5·휠 폭탄 바꾸기 · R 다시 · Esc 잠깐",
	"opening_hint": "클릭 / 스페이스 ▶     Esc 건너뛰기",
}



static func t(key: String) -> String:
	return T.get(key, key)
