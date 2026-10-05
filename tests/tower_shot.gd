extends "res://tests/screenshot.gd"
## 망루 확인용 (창 모드, 화면 밖): 1-1 나무 망루(낮은 난간과 사다리)를 가까이서.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	main.load_stage(0)
	await _frames(10)
	main.hud.set_gameplay_visible(false)
	var c: Vector3 = Campaign.STAGES[0].parts[0][1]
	var cam := Camera3D.new()
	main.stage.add_child(cam)
	cam.look_at_from_position(c + Vector3(7.5, 5.0, 9.0), c + Vector3(0, 3.5, 0))
	cam.current = true
	await _real_wait(main, 0.4)
	_save("tower_close")
	cam.look_at_from_position(c + Vector3(0, 7.0, 16.0), c + Vector3(0, 4.0, 0))
	await _real_wait(main, 0.2)
	_save("tower_front")
	quit()
