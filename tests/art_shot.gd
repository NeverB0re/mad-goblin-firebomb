extends "res://tests/screenshot.gd"
## 그래픽 확인용 (창 모드, 화면 밖): 진지 구조물 근접샷과 캐릭터 근접샷을 저장한다.
## 인자: -- <진지 번호> ... (없으면 몇 곳)


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
		list = [0, 5, 13, 26, 36, 47]
	for i in list:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		main.hud.visible = false
		var c: Commander = s.commanders[0]
		var cam := Camera3D.new()
		s.add_child(cam)
		var pp := s.player.global_position
		var to := (pp - c.global_position)
		to.y = 0
		to = to.normalized()
		var side := Vector3(-to.z, 0, to.x)
		cam.look_at_from_position(c.global_position + to * 11.0 + side * 5.0 + Vector3(0, 4.5, 0), c.global_position + Vector3(0, 1.5, 0))
		cam.current = true
		await _real_wait(main, 0.5)
		_save("art_%d_struct" % i)
		# 플레이어 고블린 앞모습과 뒷모습
		cam.look_at_from_position(pp + Vector3(-1.6, 1.6, -3.2).rotated(Vector3.UP, s.player.rotation.y), pp + Vector3(0, 1.0, 0))
		await _real_wait(main, 0.3)
		_save("art_%d_player" % i)
		cam.queue_free()
		main.hud.visible = true
	quit()
