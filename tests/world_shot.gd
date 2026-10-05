extends "res://tests/screenshot.gd"
## 월드 배경 확인용 (창 모드, 화면 밖): 월드마다 한 진지를 투척 언덕 시점과 위에서 내려다본 시점으로 찍는다.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	for i in [1, 13, 24, 33, 41]:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		var focus: Vector3 = s.commanders[0].global_position
		_look(s, focus + Vector3(0, 6, 0))
		await _real_wait(main, 0.3)
		_save("world_view_%d" % (Campaign.world_of(i) + 1))
		main.hud.set_gameplay_visible(false)
		var cam := Camera3D.new()
		cam.far = 1500.0
		s.add_child(cam)
		cam.look_at_from_position(s.player.global_position + Vector3(0, 30, 25), focus + Vector3(0, 0, -60))
		cam.current = true
		await _real_wait(main, 0.3)
		_save("world_wide_%d" % (Campaign.world_of(i) + 1))
	quit()
