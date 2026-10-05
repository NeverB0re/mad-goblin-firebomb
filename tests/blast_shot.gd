extends "res://tests/screenshot.gd"
## 폭발 연출 확인용 (창 모드, 화면 밖): 고폭탄이 터진 뒤 몇 순간을 찍는다. 인자: 진지 번호(0부터)


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	var i := int(OS.get_cmdline_user_args()[0])
	main.load_stage(i)
	await _frames(10)
	var s: Stage = main.stage
	s.wind = Vector3.ZERO
	main.hud.set_gameplay_visible(false)
	var target: Vector3 = s.commanders[0].global_position + Vector3(0, -2.0, 3.0)
	target.y = maxf(target.y, 0.5)
	var hit := [false]
	s.projectile_thrown.connect(func(p): p.impacted.connect(func(_p, _pos, _n, _c): hit[0] = true))
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.look_at_from_position(target + Vector3(6, 6, 16), target + Vector3(0, 1.5, 0))
	cam.current = true
	_throw(s, AmmoType.Kind.HE, target)
	while not hit[0]:
		await process_frame
	var t0 := Time.get_ticks_msec()
	for t in [0.3, 0.45, 0.6, 0.8, 1.2]:
		while Time.get_ticks_msec() - t0 < t * 1000.0:
			await process_frame
		_save("blast_%.2f" % t)
	quit()
