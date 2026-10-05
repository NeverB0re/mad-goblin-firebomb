class_name SaveData
extends RefCounted
## 진행 상황과 설정 저장 (user://save.cfg). 모두 정적이라 어디서나 읽고 쓴다.

## 테스트는 다른 파일을 쓴다
static var path := "user://save.cfg"

## 열린 본편 스테이지 수 (최소 1)
static var unlocked := 1
## 시험판 임시 기능: 진행과 상관없이 모든 진지를 고른다. 기본은 꺼짐이고, 타이틀 구석의 임시 버튼으로 켠다 (설정에 저장).
static var unlock_all := false


## 고를 수 있는 진지 수 (시험 기간에는 전부).
static func open_count() -> int:
	return Campaign.COUNT if unlock_all else unlocked
## 스테이지 번호 → 최고 기록 (클리어할 때 남은 탄 수, 클리어 못 했으면 없음)
static var best := {}
## 스테이지 번호 → 받은 별 (비트: 1 = 목표 달성, 2 = 폭탄 남김, 4 = 보조 목표). 한 번 받은 별은 다시 도전해도 남는다.
static var star_bits := {}
static var opening_seen := false
## 시작 컷을 본 월드 번호들
static var worlds_seen := []
## 설정
static var mouse_sens := 1.0
static var volume := 0.8
static var fullscreen := false
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	unlocked = maxi(1, int(cfg.get_value("progress", "unlocked", 1)))
	best = cfg.get_value("progress", "best", {})
	var old: Dictionary = cfg.get_value("progress", "stars", {})
	for k in old:
		# 옛 저장 (별 개수만 있던 것): 개수만큼 앞의 별부터 받은 것으로
		star_bits[k] = (1 << int(old[k])) - 1
	var bits: Dictionary = cfg.get_value("progress", "star_bits", {})
	for k in bits:
		star_bits[k] = int(star_bits.get(k, 0)) | int(bits[k])
	opening_seen = bool(cfg.get_value("progress", "opening_seen", false))
	worlds_seen = cfg.get_value("progress", "worlds_seen", [])
	mouse_sens = float(cfg.get_value("settings", "mouse_sens", 1.0))
	volume = float(cfg.get_value("settings", "volume", 0.8))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))
	unlock_all = bool(cfg.get_value("settings", "unlock_all", false))


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "star_bits", star_bits)
	cfg.set_value("progress", "opening_seen", opening_seen)
	cfg.set_value("progress", "worlds_seen", worlds_seen)
	cfg.set_value("settings", "mouse_sens", mouse_sens)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "unlock_all", unlock_all)
	cfg.save(path)


## 클리어 기록: 다음 스테이지를 열고 최고 기록(남은 탄)을 갱신하고, 이번에 받은 별(비트)을 이미 받은 별에 더한다.
## 더한 뒤의 별 비트를 돌려준다.
static func record_clear(index: int, ammo_left: int, bits := 1) -> int:
	unlocked = maxi(unlocked, index + 2)
	best[index] = maxi(int(best.get(index, -1)), ammo_left)
	star_bits[index] = int(star_bits.get(index, 0)) | bits
	save_all()
	return int(star_bits[index])


## 받은 별 개수 (0~3).
static func star_count(index: int) -> int:
	var b := int(star_bits.get(index, 0))
	return (b & 1) + ((b >> 1) & 1) + ((b >> 2) & 1)


## 진행 기록을 모두 지우고 처음부터 (설정 중 음량·감도·전체 화면은 남긴다). 전체 개방도 끈다.
static func reset_progress() -> void:
	unlocked = 1
	best = {}
	star_bits = {}
	opening_seen = false
	worlds_seen = []
	unlock_all = false
	save_all()


static func is_cleared(index: int) -> bool:
	return best.has(index)


## 설정을 실제로 적용한다 (음량, 전체 화면). 마우스 감도는 Player가 읽는다.
static func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(mode)
