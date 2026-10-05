extends "res://tests/screenshot.gd"
## 풍경 비교용 (창 모드, 화면 밖): 몇 진지를 고정 카메라로 찍는다 (풍경 생성 코드를 바꾼 전후 비교).


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	for i in [0, 21, 32, 49]:
		main.load_stage(i)
		await _frames(5)
		main.hud.set_gameplay_visible(false)
		var cam := Camera3D.new()
		main.stage.add_child(cam)
		cam.look_at_from_position(Vector3(0, 30, 30), Vector3(0, 0, -50))
		cam.current = true
		await _frames(5)
		_save("scenery_%d" % i)
	quit()
