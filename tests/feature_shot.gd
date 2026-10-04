extends "res://tests/screenshot.gd"
## 렌더링 확인용 (창 모드, 화면 밖): 로켓 발사대·바람자루, 고폭탄 동심원, 페인트탄 자국, 로켓 비행과 폭발, 숨은 화약통 도화선.
## 화면만 저장한다 (판정은 campaign_test가 본다). 겨눔을 단순하게 하려고 바람은 끈다.


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

	# 4-3: 왼쪽 앞 로켓 발사대와 오른쪽 바람자루
	main.load_stage(32)
	await _frames(10)
	var s: Stage = main.stage
	var pp := s.player.global_position
	_look(s, pp + Vector3(-6.5, 0.5, -9.0))
	await _real_wait(main, 0.5)
	_save("feat_rocket_pad")
	_look(s, pp + Vector3(5.0, 3.0, -5.0))
	await _real_wait(main, 0.5)
	_save("feat_windsock")

	# 1-8: 고폭탄 동심원 (터진 직후)
	main.load_stage(7)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var plan: Array = Campaign.plan(7)
	var landed := [false]
	s.projectile_thrown.connect(func(p): p.impacted.connect(func(_a, _b, _c, _d): landed[0] = true))
	_throw(s, AmmoType.Kind.HE, plan[0][1])
	_look(s, plan[0][1])
	while not landed[0]:
		await process_frame
	await _real_wait(main, 0.45)
	_save("feat_he_rings")

	# 1-1: 페인트탄 자국
	main.load_stage(0)
	await _frames(10)
	s = main.stage
	var c: Vector3 = s.commanders[0].global_position
	_throw(s, AmmoType.Kind.PAINT, c + Vector3(0, -2.0, 2.0))
	await _real_wait(main, 2.0)
	_look(s, c + Vector3(0, -2.0, 0))
	await _real_wait(main, 0.2)
	_save("feat_paint")

	# 4-1: 조명탄 → 로켓 비행 (추적 화면) → 폭발
	main.load_stage(30)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	c = s.commanders[0].global_position
	_throw(s, AmmoType.Kind.FLARE, c + Vector3(0, 2.7, 0))
	await _real_wait(main, 4.2)
	_look(s, c)
	await _real_wait(main, 0.4)
	_save("feat_rocket_flight")
	var boomed := [false]
	for m in s.get_tree().get_nodes_in_group("missile"):
		m.exploded.connect(func(_p): boomed[0] = true)
	while not boomed[0]:
		await process_frame
	await _real_wait(main, 0.35)
	_save("feat_rocket_boom")

	# 3-5: 도화선에 불 → 타 들어가는 중 → 폭발 뒤
	main.load_stage(24)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	var k: Vector3 = Campaign.STAGES[24].parts[0][1]
	_throw(s, AmmoType.Kind.FLARE, k + Vector3(0, 0, 6))
	await _real_wait(main, 1.5)
	_throw(s, AmmoType.Kind.FIRE, k + Vector3(Campaign.KEG_FUSE_X, 0.1, 4.8))
	_look(s, k + Vector3(1.0, 1.0, 2.0))
	await _real_wait(main, 3.5)
	_save("feat_fuse_burning")
	await _real_wait(main, 4.0)
	_look(s, k + Vector3(0, 1.0, 0))
	await _real_wait(main, 0.6)
	_save("feat_fuse_after")
	quit()
