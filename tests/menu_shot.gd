extends SceneTree
## 렌더링 확인용 (창 모드): 타이틀, 진지 고르기, 잠깐 메뉴, 새 본편 스테이지 시작 화면을 tests/out에 저장한다.

func _initialize() -> void:
	# 사용자가 하던 작업을 가리거나 포커스를 빼앗지 않게 창을 화면 밖에 두고 포커스를 받지 않는다
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
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
	SaveData.unlocked = 50
	SaveData.best = {0: 3, 1: 1, 2: 4}
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(60)
	var main := current_scene
	_save("menu_title")
	main.menus.show_select(Menus.Screen.TITLE)
	await _frames(5)
	_save("menu_select")
	for i in [4, 21, 22, 31, 41, 49]:
		SaveData.worlds_seen = [0, 1, 2, 3, 4]
		main.menus.stage_chosen.emit(i)
		await _frames(30)
		var focus: Vector3 = main.stage.commander.global_position if main.stage.commander else main.stage.messengers[0].global_position
		var to: Vector3 = focus - main.stage.player.head.global_position
		main.stage.player.look_at_angles(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		await _frames(10)
		_save("campaign_%d" % (i + 1))
	main._pause()
	await _frames(5)
	_save("menu_pause")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.path))
	quit()
