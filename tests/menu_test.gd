extends SceneTree
## 게임 흐름 테스트 (창 모드): 타이틀 → 시작(오프닝 건너뜀) → 1-1, Esc 잠깐/계속, 클리어 기록 저장, 스테이지 선택.
## 실제 저장 파일 대신 user://test_save.cfg를 쓴다.

var _failures := 0


func _initialize() -> void:
	# 사용자가 하던 작업을 가리거나 포커스를 빼앗지 않게 창을 화면 밖에 두고 포커스를 받지 않는다
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		_failures += 1
		print("  FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)


func _run() -> void:
	print("== 게임 흐름 테스트 ==")
	SaveData.path = "user://test_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	SaveData.load_all()
	SaveData.opening_seen = true
	SaveData.worlds_seen = [0, 1, 2, 3, 4]
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var main := current_scene
	_check(main.menus.screen == Menus.Screen.TITLE and paused, "타이틀 화면, 뒤의 진지는 멈춤")
	main.menus.start_requested.emit()
	await _frames(10)
	_check(not paused and main.stage.stage_id == "1-1" and main.menus.screen == Menus.Screen.NONE, "시작 → 1-1 (%s)" % main.stage.stage_id)
	# 진지 시작 조망: 아무 키나 누르면 건너뛰고 투척 시점으로 (그동안 고블린 조작은 잠긴다)
	var intro_locked: bool = main.stage.player.input_locked
	await _key(KEY_SPACE)
	await _frames(40)
	_check(intro_locked and not main.stage.player.input_locked and main.stage.player.camera.current, "시작 조망 → 아무 키로 건너뛰기 → 투척 시점")
	await _key(KEY_ESCAPE)
	_check(paused and main.menus.screen == Menus.Screen.PAUSE, "Esc → 잠깐 메뉴")
	await _key(KEY_ESCAPE)
	_check(not paused and main.menus.screen == Menus.Screen.NONE, "Esc → 계속")
	# 클리어 → 다음 스테이지가 열리고 기록이 저장된다
	main.stage.commander.defeat("direct")
	await _frames(5)
	_check(SaveData.unlocked == 2 and SaveData.is_cleared(0), "1-1 클리어 → 1-2 열림, 기록 저장")
	var cfg := ConfigFile.new()
	_check(cfg.load(SaveData.path) == OK and int(cfg.get_value("progress", "unlocked", 0)) == 2, "저장 파일에 진행이 남음")
	Engine.time_scale = 1.0
	main.show_title()
	await _frames(5)
	main.menus.show_select(Menus.Screen.TITLE)
	await _frames(5)
	main.menus.stage_chosen.emit(1)
	await _frames(10)
	_check(main.stage.stage_id == "1-2" and not paused, "진지 고르기 → 1-2")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
