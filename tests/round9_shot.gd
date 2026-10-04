extends "res://tests/screenshot.gd"
## 0.9 확인용 (창 모드, 화면 밖): 벽에 묻은 기름, 연기알 궤적, 고블린식 탄 이름과 조명탄+글라이더 칸, 발리스타 궁병과 격추.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))

	# 2-2: 젖은 숙소 벽에 기름 단지
	main.load_stage(11)
	await _frames(10)
	var s: Stage = main.stage
	s.wind = Vector3.ZERO
	var c: Vector3 = Campaign.STAGES[11].parts[0][1]
	_throw(s, AmmoType.Kind.OIL, c + Vector3(0, 1.0, 2.15))
	await _real_wait(main, 3.5)
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.look_at_from_position(c + Vector3(3.0, 2.5, 7.0), c + Vector3(0, 1.0, 2.0))
	cam.current = true
	await _real_wait(main, 0.3)
	_save("r9_oil")
	cam.queue_free()
	s.player.camera.make_current()
	_select(s, AmmoType.Kind.OIL)
	_look(s, c + Vector3(0, 1.0, 0))
	await _real_wait(main, 0.3)
	_save("r9_hud_oil")

	# 1-1: 연기알 궤적 (날아가는 중, 떨어진 뒤)
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	c = s.commanders[0].global_position
	_throw(s, AmmoType.Kind.PAINT, c + Vector3(1.5, -3.0, 3.0))
	await _real_wait(main, 1.2)
	_look(s, c + Vector3(0, -1.0, 6.0))
	await _real_wait(main, 0.1)
	_save("r9_smoke_flight")
	await _real_wait(main, 2.5)
	_save("r9_smoke_after")

	# 4-3: 조명탄 칸의 글라이더 + 발리스타가 돌아 글라이더를 쏜다
	main.load_stage(32)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	_select(s, AmmoType.Kind.FLARE)
	_look(s, Vector3(-9, 4, -54))
	await _real_wait(main, 0.4)
	_save("r9_hud_w4")
	var bp: Vector3 = s.ballistas[0].global_position
	_throw(s, AmmoType.Kind.FLARE, Campaign.STAGES[32].parts[0][1] + Vector3(0, 2.7, 0))
	cam = Camera3D.new()
	s.add_child(cam)
	cam.look_at_from_position(bp + Vector3(7.0, 4.0, 9.0), bp + Vector3(0, 6.0, 0))
	cam.current = true
	var t := 0.0
	var shot := false
	while t < 12.0:
		await process_frame
		t += 1.0 / 60.0
		for n in s.get_children():
			if n is Bomber and n.get("_bolt") != null and is_instance_valid(n._bolt) and not shot:
				shot = true
				await _real_wait(main, 0.35)
				_save("r9_ballista_shot")
	quit()
