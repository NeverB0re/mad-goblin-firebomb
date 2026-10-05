extends "res://tests/screenshot.gd"
## 가까이서 확인용 (창 모드, 화면 밖). 인자: 진지 번호(0부터) 카메라dx dy dz 바라볼dx dy dz [이름] [p] (지휘관 첫째 기준 좌표, p면 플레이어 기준). 여러 장은 "/"로 이어 붙인다.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	var args := " ".join(OS.get_cmdline_user_args()).split("/")
	for one in args:
		var a: PackedStringArray = one.strip_edges().split(" ", false)
		var i := int(a[0])
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		s.wind = Vector3.ZERO
		main.hud.set_gameplay_visible(false)
		# 9번째 인자 p: 플레이어 기준 좌표
		var f: Vector3 = s.player.global_position if a.size() > 8 and a[8] == "p" else s.commanders[0].global_position
		var cam := Camera3D.new()
		cam.far = 1500.0
		s.add_child(cam)
		cam.look_at_from_position(f + Vector3(float(a[1]), float(a[2]), float(a[3])), f + Vector3(float(a[4]), float(a[5]), float(a[6])))
		cam.current = true
		await _real_wait(main, 0.4)
		_save("close_%s" % a[7])
	quit()
