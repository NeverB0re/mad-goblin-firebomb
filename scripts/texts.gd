class_name Texts
extends RefCounted
## 화면 문구 모음 (나중에 번역하기 쉽게 한 파일에 모은다).
## 고블린 외침은 짧게, 설정·탄 이름은 평범하고 정확하게, 실패 문구는 원인을 정확히 가리킨다.

const T := {
	# 고블린 외침
	"start": "공격!",
	"continue": "계속 공격!",
	"quit": "후퇴!",
	"retry": "다시 공격!",
	"next": "다음 진지로!",
	"last_shot": "마지막 한 방!",
	"win": "박살!",
	"fail_ammo": "폭탄을 다 썼잖아!!",
	"fail_messenger": "전령이 도착했잖아!!",
	# 메뉴
	"game_title": "미친 고블린",
	"game_subtitle": "부족장을 돌려받을 때까지, 펑!",
	"menu_start": "시작",
	"menu_continue": "이어서 공격",
	"menu_select": "진지 고르기",
	"menu_opening": "처음 이야기",
	"menu_settings": "설정",
	"menu_quit": "그만하기",
	"menu_back": "돌아가기",
	"menu_resume": "계속",
	"menu_restart": "다시 공격",
	"menu_title": "처음 화면으로",
	"paused": "잠깐!",
	"locked": "잠김",
	"best_left": "최고: 탄 %d발 남김",
	"set_sens": "마우스 감도",
	"set_volume": "소리 크기",
	"set_fullscreen": "전체 화면",
	# 평범한 안내
	"empty_slot": "이 탄은 다 썼다",
	"rocket_shot_down": "로켓이 발리스타에 맞았다!!",
	"rockets_left": "대기 중인 로켓",
	"ammo_left": "남은 탄",
	"any_key": "아무 키나 누르면 계속",
	"help": "WASD 이동 · 마우스 시점 · 좌클릭 누름 와인드업 / 뗌 투척 · 우클릭 4배 줌 / 투척 취소 · 1~5·휠 탄종 · R 재시작 · Esc 잠깐",
	"opening_hint": "클릭 / 스페이스 ▶     Esc 건너뛰기",
}


static func t(key: String) -> String:
	return T.get(key, key)
