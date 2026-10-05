extends "res://tests/screenshot.gd"
## 깃발 가시성 확인용 (창 모드, 화면 밖): 스테이지마다 투척 시점에서 지휘관 쪽을 찍는다. 인자: 스테이지 번호들(0부터).


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		ids.append(int(a))
	for i in ids:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		var focus := Vector3.ZERO
		for c in s.commanders:
			focus += c.global_position
		focus /= s.commanders.size()
		_look(s, focus + Vector3(0, 5, 0))
		await _real_wait(main, 0.3)
		_save("flag_%s" % Campaign.label(i))
	quit()
