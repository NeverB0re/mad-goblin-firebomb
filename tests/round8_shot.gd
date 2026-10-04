extends "res://tests/screenshot.gd"
## 0.8 개편 확인용 (창 모드, 화면 밖): 1-9 돌 망루와 도화선, 1-10 지원 진지, 별 결과 화면, 4월드.


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

	# 1-9: 투척 시점 + 도화선 끝과 손짓하는 고블린
	main.load_stage(8)
	await _frames(10)
	var s: Stage = main.stage
	var c: Vector3 = Campaign.STAGES[8].parts[0][1]
	_look(s, c + Vector3(0, 4.0, 0))
	await _real_wait(main, 0.6)
	_save("r8_fortress")
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.look_at_from_position(c + Vector3(6.0, 3.5, 14.0), c + Vector3(-0.5, 1.0, 7.0))
	cam.current = true
	await _real_wait(main, 0.5)
	_save("r8_fuse")
	cam.look_at_from_position(c + Vector3(-7.0, 9.0, 4.0), c + Vector3(0, 5.0, 0))
	await _real_wait(main, 0.3)
	_save("r8_tower")
	cam.queue_free()

	# 1-10: 동료가 병사 앞에 다가갔을 때, 망루 문, 성문
	main.load_stage(9)
	await _frames(10)
	s = main.stage
	var ally: Ally = s.allies[0]
	ally.start()
	await _real_wait(main, 4.5)
	cam = Camera3D.new()
	s.add_child(cam)
	cam.look_at_from_position(ally.global_position + Vector3(5.0, 3.0, 4.0), ally.global_position + Vector3(0, 1.0, -2.0))
	cam.current = true
	await _real_wait(main, 0.3)
	_save("r8_guards")
	var tp := StageDefs._along(Campaign.ALLY_PTS, Campaign.ALLY_TOWER)
	cam.look_at_from_position(tp + Vector3(6.0, 5.0, 12.0), tp + Vector3(0, 2.5, 0))
	await _real_wait(main, 0.3)
	_save("r8_tower_gate")
	cam.look_at_from_position(Vector3(5.0, 6.0, Campaign.ALLY_GATE_Z + 14.0), Vector3(0, 2.0, Campaign.ALLY_GATE_Z))
	await _real_wait(main, 0.3)
	_save("r8_gate")
	cam.queue_free()

	# 1-1 승리 → 별 결과 화면 (마우스 포인터와 버튼)
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var plan: Array = Campaign.plan(0)
	_throw(s, plan[0][0], plan[0][1])
	await _real_wait(main, 9.0)
	_save("r8_result")

	# 4-1: 나무 발리스타와 먼 벙커
	main.load_stage(30)
	await _frames(10)
	s = main.stage
	_look(s, Vector3(-3, 0, -60))
	await _real_wait(main, 0.6)
	_save("r8_w4")
	quit()
