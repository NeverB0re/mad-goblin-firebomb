extends "res://tests/screenshot.gd"
## 진지 불러오기 시간 측정 (창 모드, 화면 밖): load_stage 자체 시간 + 그 뒤 첫 프레임들의 시간.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	for i in [0, 1, 2, 11, 21, 32, 41, 49, 0]:
		var t0 := Time.get_ticks_usec()
		main.load_stage(i)
		var t1 := Time.get_ticks_usec()
		var frames := []
		var last := t1
		for f in 6:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(int((now - last) / 1000))
			last = now
		print("%s  load_stage %d ms, 첫 프레임들 %s ms" % [Campaign.label(i), (t1 - t0) / 1000, frames])
		await _frames(30)
	quit()
