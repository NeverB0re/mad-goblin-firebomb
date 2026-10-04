class_name SaveData
extends RefCounted
## 진행 상황과 설정 저장 (user://save.cfg). 모두 정적이라 어디서나 읽고 쓴다.

## 테스트는 다른 파일을 쓴다
static var path := "user://save.cfg"

## 열린 본편 스테이지 수 (최소 1)
static var unlocked := 1
## 시험 기간: 진행과 상관없이 모든 진지를 고를 수 있다 (출시 전에 false로 돌린다)
static var unlock_all := true


## 고를 수 있는 진지 수 (시험 기간에는 전부).
static func open_count() -> int:
	return Campaign.COUNT if unlock_all else unlocked
## 스테이지 번호 → 최고 기록 (클리어할 때 남은 탄 수, 클리어 못 했으면 없음)
static var best := {}
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
	opening_seen = bool(cfg.get_value("progress", "opening_seen", false))
	worlds_seen = cfg.get_value("progress", "worlds_seen", [])
	mouse_sens = float(cfg.get_value("settings", "mouse_sens", 1.0))
	volume = float(cfg.get_value("settings", "volume", 0.8))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "opening_seen", opening_seen)
	cfg.set_value("progress", "worlds_seen", worlds_seen)
	cfg.set_value("settings", "mouse_sens", mouse_sens)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(path)


## 클리어 기록: 다음 스테이지를 열고 최고 기록(남은 탄)을 갱신한다.
static func record_clear(index: int, ammo_left: int) -> void:
	unlocked = maxi(unlocked, index + 2)
	best[index] = maxi(int(best.get(index, -1)), ammo_left)
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
