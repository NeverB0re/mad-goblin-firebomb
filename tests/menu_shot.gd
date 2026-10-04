extends SceneTree
## 렌더링 확인용 (창 모드): 타이틀, 진지 고르기, 잠깐 메뉴, 새 본편 스테이지 시작 화면을 tests/out에 저장한다.

func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://tests/out/%s.png" % name)


func _run() -> void:
	SaveData.path = "user://test_save.cfg"
	SaveData.load_all()
	SaveData.opening_seen = true
	SaveData.unlocked = 6
	SaveData.best = {0: 3, 1: 1, 2: 4}
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	var main := current_scene
	_save("menu_title")
	main.menus.show_select(Menus.Screen.TITLE)
	await _frames(5)
	_save("menu_select")
	for i in [4, 9, 12]:
		main.menus.stage_chosen.emit(i)
		await _frames(20)
		var to: Vector3 = main.stage.commander.global_position - main.stage.player.head.global_position
		main.stage.player.look_at_angles(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		await _frames(10)
		_save("campaign_%d" % (i + 1))
	main._pause()
	await _frames(5)
	_save("menu_pause")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	quit()
