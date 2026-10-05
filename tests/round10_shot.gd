extends "res://tests/screenshot.gd"
## 0.10 확인용 (창 모드, 화면 밖): 새 HUD와 하늘쾅 칸, 연두 연기알 궤적, 승리·실패 화면.


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

	# 4-3: 하늘쾅 칸 (조명탄 칸 자리)
	main.load_stage(32)
	await _frames(10)
	var s: Stage = main.stage
	s.wind = Vector3.ZERO
	main.hud.set_goals(Campaign.bonus_text(32), 1)
	_select(s, AmmoType.Kind.FLARE)
	_look(s, Vector3(-9, 4, -54))
	await _real_wait(main, 0.6)
	_save("r10_hud_w4")

	# 1-1: 연기알 궤적 (날아가는 중, 떨어진 뒤)
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var c: Vector3 = s.commanders[0].global_position
	_throw(s, AmmoType.Kind.PAINT, c + Vector3(1.5, -3.0, 3.0))
	await _real_wait(main, 1.2)
	_look(s, c + Vector3(0, -1.0, 6.0))
	await _real_wait(main, 0.1)
	_save("r10_smoke_flight")
	var side := Camera3D.new()
	s.add_child(side)
	side.look_at_from_position(c + Vector3(-9.0, 2.0, 14.0), c + Vector3(0, -1.0, 9.0))
	side.current = true
	await _real_wait(main, 0.2)
	_save("r10_smoke_side")
	side.queue_free()
	s.player.camera.make_current()
	await _real_wait(main, 2.3)
	_save("r10_smoke_after")

	# 1-1 승리 → 결과 화면
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var plan: Array = Campaign.plan(0)
	_throw(s, plan[0][0], plan[0][1])
	await _real_wait(main, 9.0)
	_save("r10_result")
	main.result.close()
	main.result = null

	# 실패 화면
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	s.state_changed.emit(Stage.State.FAILED, "폭탄이 다 떨어졌다!")
	await _real_wait(main, 2.0)
	_save("r10_fail")
	quit()
