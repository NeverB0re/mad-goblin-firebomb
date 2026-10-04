extends "res://tests/screenshot.gd"
## 0.7 개편 확인용 (창 모드, 화면 밖): 그림 HUD와 탄 모델, 들판의 바람 깃발, 밤의 구경꾼, 번지는 불.


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

	# 1-10: 그림 HUD (폭탄 고름) + 들고 있는 폭탄
	main.load_stage(9)
	await _frames(10)
	var s: Stage = main.stage
	_look(s, s.commanders[0].global_position)
	await _real_wait(main, 0.6)
	_save("rd_hud_bomb")
	# 화염 항아리로 바꿔 든 모습
	_select(s, AmmoType.Kind.FIRE)
	await _real_wait(main, 0.4)
	_save("rd_hud_fire")

	# 1-8: 투척 시점에서 보이는 바람 깃발과 줄집, 불을 붙인 뒤 번지는 모습
	main.load_stage(7)
	await _frames(10)
	s = main.stage
	_look(s, Campaign.STAGES[7].parts[0][1] + Vector3(0, 2.0, 0))
	await _real_wait(main, 0.8)
	_save("rd_banner")
	var plan: Array = Campaign.plan(7)
	s.wind = Vector3.ZERO
	_throw(s, plan[0][0], plan[0][1])
	await _real_wait(main, 3.2)
	_look(s, Campaign.STAGES[7].parts[0][1] + Vector3(0, 2.0, 0))
	await _real_wait(main, 0.1)
	_save("rd_rowfire")

	# 3-2: 캄캄한 초소 → 조명탄 → 걸어 나와 구경하는 지휘관
	main.load_stage(21)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var c: Vector3 = Campaign.STAGES[21].parts[0][1]
	var spot := c + Campaign._guard_spot(1.0)
	_look(s, c + Vector3(2.0, 1.0, 0))
	await _real_wait(main, 0.6)
	_save("rd_night_dark")
	_look(s, Campaign.banner_spot(Campaign.STAGES[21], s.player.position) + Vector3(0, 5.0, 0))
	await _real_wait(main, 0.3)
	_save("rd_night_banner")
	_look(s, c + Vector3(2.0, 1.0, 0))
	_throw(s, AmmoType.Kind.FLARE, spot + Vector3(0, 0.1, 0))
	await _real_wait(main, 7.0)
	_look(s, s.commanders[0].global_position + Vector3(0, 1.0, 0))
	await _real_wait(main, 0.3)
	_save("rd_lure")
	quit()
