extends "res://tests/screenshot.gd"
## 렌더링 확인용 (창 모드, 화면 밖): 본편 진지 몇 곳의 시작 화면과 첫 투척 결과를 저장한다.
## 인자: -- <진지 번호> ... (없으면 3-1, 3-5, 1-9)


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = true
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.test_mode = false
	main.menus.hide_all()
	paused = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var list := []
	for a in OS.get_cmdline_user_args():
		list.append(int(a))
	if list.is_empty():
		list = [20, 24, 8]
	for i in list:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		var c: Commander = s.commanders[0]
		_look(s, c.global_position + Vector3(0, 1.0, 0))
		await _real_wait(main, 0.6)
		_save("camp_%d_start" % i)
		var plan: Array = Campaign.plan(i)
		if plan[0][0] is String:
			continue
		var kind: int = AmmoType.Kind.FLARE if s.night else plan[0][0]
		var target: Vector3 = c.global_position + Vector3(0, 0, 3) if s.night else (plan[0][1] if plan[0][1] is Vector3 else c.global_position)
		_throw(s, kind, target)
		await _real_wait(main, 3.0)
		_look(s, c.global_position + Vector3(0, 1.0, 0))
		await _real_wait(main, 0.3)
		_save("camp_%d_after" % i)
	quit()
