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
	# 평범한 안내
	"weight_changed": "무게가 달라졌다",
	"empty_slot": "이 탄은 다 썼다",
	"climb_up": "위층으로",
	"climb_down": "아래층으로",
	"ammo_left": "남은 탄",
	"any_key": "아무 키나 누르면 계속",
	"help": "WASD 이동 · 마우스 시점 · 좌클릭 누름 와인드업 / 뗌 투척 · 우클릭 관찰 줌 / 투척 취소 · 1~4·휠 탄종 · Q/E 층 이동 · R 재시작 · F1~F11 스테이지 · Esc 마우스 해제",
	"opening_hint": "클릭 / 스페이스 ▶     Esc 건너뛰기",
}


static func t(key: String) -> String:
	return T.get(key, key)
