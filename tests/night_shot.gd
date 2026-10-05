extends "res://tests/screenshot.gd"
## 밤 밝기 비교용 (창 모드, 화면 밖): 3-1, 3-6, 5-4를 투척 언덕 시점에서 지금 값과 후보값으로 찍는다.
## 후보: [이름, 달빛, 주변광, 지평선 하늘색]. 고른 값은 main.gd의 _apply_time_of_day에 넣는다.

const CANDIDATES := [
	["0_now", 0.012, 0.015, Color(0.012, 0.014, 0.03)],
	["1_a", 0.05, 0.03, Color(0.03, 0.036, 0.07)],
	["2_b", 0.065, 0.04, Color(0.04, 0.048, 0.09)],
	["3_c", 0.08, 0.05, Color(0.05, 0.06, 0.11)],
]


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	SaveData.night_seen = false
	for i in [20, 25, 43]:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		if i == 20:
			# 첫 밤 진지: 조작 안내 줄 자리에 번쩍봉 안내
			_save("night_3-1_hint")
		var focus := Vector3.ZERO
		for c in s.commanders:
			focus += c.global_position
		focus /= s.commanders.size()
		# 고블린 몸에 가리지 않게 투척 자리 머리 위 카메라로 진지 쪽을 본다
		main.hud.set_gameplay_visible(false)
		var cam := Camera3D.new()
		cam.far = 1500.0
		cam.fov = 50.0
		s.add_child(cam)
		cam.look_at_from_position(s.player.global_position + Vector3(0, 3.0, 0), focus + Vector3(0, 2, 0))
		cam.current = true
		for cand in CANDIDATES:
			main._sun.light_energy = cand[1]
			main._env.ambient_light_energy = cand[2]
			main._sky_mat.sky_horizon_color = cand[3]
			main._env.fog_light_color = cand[3] * 0.5
			await _real_wait(main, 0.3)
			_save("night_%s_%s" % [Campaign.label(i), cand[0]])
	# 고른 값(main.gd)에서 3-1 연기알 기둥이 밤에도 보이는지: 망루 앞 빈터에 던지고 기둥이 솟은 뒤 찍는다
	main.load_stage(20)
	await _frames(10)
	var s3: Stage = main.stage
	var at: Vector3 = Campaign.STAGES[20].parts[0][1] + Vector3(-6, 0, 6)
	_throw(s3, AmmoType.Kind.PAINT, at)
	await _real_wait(main, 4.0)
	main.hud.set_gameplay_visible(false)
	var cam3 := Camera3D.new()
	cam3.fov = 50.0
	s3.add_child(cam3)
	cam3.look_at_from_position(s3.player.global_position + Vector3(0, 3.0, 0), at + Vector3(0, 4, 0))
	cam3.current = true
	await _real_wait(main, 0.3)
	_save("night_3-1_smoke")
	quit()
