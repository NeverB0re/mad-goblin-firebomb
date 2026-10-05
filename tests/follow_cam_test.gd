extends "res://tests/screenshot.gd"
## 추적 화면 테스트 (창 모드, 화면 밖): 화면 크기, 착탄 직전 카메라 고정, 글라이더 폭격은 매달린 고블린을 따라가는지.

var _failures := 0


func _check(cond: bool, msg: String) -> void:
	print("  ", "PASS " if cond else "FAIL ", msg)
	if not cond:
		_failures += 1


func _run() -> void:
	print("== 추적 화면 테스트 ==")
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	_check(FollowCam.VIEW_SIZE.x < 512, "추적 화면이 예전(512×288)보다 작다 (%s)" % str(FollowCam.VIEW_SIZE))

	# 1-1: 쾅쾅알. 카메라는 폭탄을 바짝 따라가다 착탄 9m 앞에서 멈추고 폭탄을 계속 바라본다
	main.load_stage(0)
	await _frames(10)
	var s: Stage = main.stage
	s.wind = Vector3.ZERO
	var fc: FollowCam = main.hud.follow_cam
	var plan: Array = Campaign.plan(0)
	_throw(s, plan[0][0], plan[0][1])
	var proj: Projectile = null
	for i in 120:
		await process_frame
		if proj == null:
			for n in s.get_children():
				if n is Projectile:
					proj = n
		if proj and fc.visible:
			break
	_check(proj != null and fc.visible, "던지면 추적 화면이 켜진다")
	var frozen_at := -1.0
	var cam_prev := fc.camera().global_position
	var moved_after_freeze := 0.0
	var last_dist := INF
	var impact := []
	proj.impacted.connect(func(_p, pos, _n, _c): impact.append(pos))
	var frames_to_hit := 0
	while is_instance_valid(proj) and not proj.done and frames_to_hit < 600:
		await process_frame
		frames_to_hit += 1
		if not is_instance_valid(proj) or proj.done:
			break
		var cam := fc.camera().global_position
		if fc._frozen:
			if frozen_at < 0.0:
				frozen_at = proj.global_position.distance_to(proj.global_position + proj.velocity.normalized() * 0.0)
				last_dist = 0.0
				_save("follow_frozen")
			moved_after_freeze += cam.distance_to(cam_prev)
		cam_prev = cam
	await _frames(2)
	_check(frozen_at >= 0.0, "착탄 직전에 추적 카메라가 멈춘다")
	_check(moved_after_freeze < 0.05, "멈춘 뒤에는 카메라가 움직이지 않는다 (이동 %.3f m)" % moved_after_freeze)
	var impact_dist: float = fc.camera().global_position.distance_to(impact[0]) if not impact.is_empty() else -1.0
	_check(impact_dist > 5.0, "폭발은 5m보다 멀리서 보인다 (착탄 순간 거리 %.1f m)" % impact_dist)
	await _real_wait(main, 1.5)
	_save("follow_after")

	# 4-3: 글라이더 폭격. 추적 화면은 매달린 고블린을 따라간다
	main.load_stage(32)
	await _frames(10)
	s = main.stage
	s.wind = Vector3.ZERO
	fc = main.hud.follow_cam
	# 발리스타가 쏘지 못하게 궁병을 먼저 쓰러뜨린다
	for b in s.ballistas:
		var op: Guard = b.get_meta("operator", null)
		if op:
			op.defeat("direct")
	_throw(s, AmmoType.Kind.FLARE, Campaign.STAGES[32].parts[0][1] + Vector3(0, 2.7, 0))
	var bomber: Bomber = null
	for i in 400:
		await process_frame
		for n in s.get_children():
			if n is Bomber:
				bomber = n
		if bomber and fc.visible:
			break
	_check(bomber != null and fc.visible, "조명탄이 떨어지면 글라이더 추적 화면이 켜진다")
	var pilot_focus := false
	var glider_focus := false
	var stopped_far := false
	var t := 0
	while is_instance_valid(bomber) and not bomber.done and t < 900:
		await process_frame
		t += 1
		pilot_focus = pilot_focus or fc._focus == bomber.focus()
		glider_focus = glider_focus or (fc._focus == bomber and fc._focus != bomber.focus())
		if fc._frozen and not stopped_far:
			stopped_far = true
			_check(bomber.focus().global_position.distance_to(bomber.target_pos()) <= FollowCam.STOP_DISTANCE_BOMBER + 1.0, "글라이더 폭격도 폭발 직전(%.1f m)에 멈춘다" % bomber.focus().global_position.distance_to(bomber.target_pos()))
			_save("follow_bomber_frozen")
	_check(pilot_focus and not glider_focus, "추적 화면이 글라이더가 아니라 폭탄을 안은 고블린을 본다")
	_check(stopped_far, "글라이더 폭격 추적도 폭발 전에 카메라가 멈춘다")
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
