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


## 화면 전환(막 덮기 → 진지 만들기 → 막 걷기)이 끝날 때까지 기다린다. 막이 덮였었는지 돌려준다.
func _settle(main: Node) -> bool:
	var dark := false
	for i in 600:
		await process_frame
		if main._curtain and main._curtain.color.a > 0.5:
			dark = true
		if not main._changing and (main._curtain == null or main._curtain.color.a == 0.0) and i > 3:
			break
	return dark


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
	var dark := await _settle(main)
	_check(dark and not paused and main.stage.stage_id == "1-1" and main.menus.screen == Menus.Screen.NONE, "시작 → 막 → 1-1 (%s)" % main.stage.stage_id)
	# 진지 시작 조망: 아무 키나 누르면 건너뛰고 투척 시점으로 (그동안 고블린 조작은 잠긴다)
	var intro_locked: bool = main.stage.player.input_locked
	await _key(KEY_SPACE)
	await _frames(40)
	_check(intro_locked and not main.stage.player.input_locked and main.stage.player.camera.current, "시작 조망 → 아무 키로 건너뛰기 → 투척 시점")
	await _key(KEY_ESCAPE)
	_check(paused and main.menus.screen == Menus.Screen.PAUSE and Texts.t("menu_resume") == "계속 던져!", "Esc → 잠깐 메뉴 (계속 던져!)")
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
	dark = await _settle(main)
	_check(dark and main.stage.stage_id == "1-2" and not paused, "진지 고르기 → 막 → 1-2")
	# 잠깐 메뉴의 처음부터 다시 → 막 → 같은 진지를 새로
	var old: Node = main.stage
	main._pause()
	await _frames(3)
	main.menus.restart_requested.emit()
	dark = await _settle(main)
	_check(dark and main.stage != old and main.stage.stage_id == "1-2" and not paused and main.menus.screen == Menus.Screen.NONE, "처음부터 다시 → 막 → 1-2를 새로")
	# R키 바로 다시
	old = main.stage
	await _key(KEY_R)
	dark = await _settle(main)
	_check(dark and main.stage != old and main.stage.stage_id == "1-2", "R → 막 → 1-2를 새로")
	# 승리 → "다음 진지로!" → 잠깐 어두워졌다가 1-3이 밝아진다
	main.stage.commander.defeat("direct")
	for i in 1200:
		if main.result and main.result._ready_for_input:
			break
		await process_frame
	main.result._choose("next")
	dark = await _settle(main)
	_check(dark and main.stage.stage_id == "1-3", "다음 진지로 → 막 → 1-3 (%s)" % main.stage.stage_id)
	# 실패 → 다시 던져 → 막 → 같은 진지를 새로
	old = main.stage
	main.stage.state_changed.emit(Stage.State.FAILED, "시험")
	for i in 600:
		if main.result and main.result._ready_for_input:
			break
		await process_frame
	main.result._choose("retry")
	dark = await _settle(main)
	_check(dark and main.stage != old and main.stage.stage_id == "1-3", "실패 → 다시 던져 → 막 → 1-3을 새로")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
