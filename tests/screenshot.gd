extends SceneTree
## 렌더링 확인용 (창 모드): 각 스테이지의 와인드업 화면과 투척 결과, 승리 연출, 실패 그림을 저장한다.
## 실행: Godot --path . --script res://tests/screenshot.gd

const StageTest := preload("res://tests/stage_test.gd")
const C := StageDefs.COMMANDER


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _real_wait(main: Node, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame


func _aim(s: Stage, target: Vector3, high := false) -> void:
	var v := s.current_ammo().throw_speed
	for i in 4:
		var dir := StageTest.aim(s.player.throw_origin(), target, v, high)
		s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))


func _select(s: Stage, kind: int) -> void:
	for i in s.ammo_slots.size():
		if s.ammo_slots[i].type.kind == kind:
			s.select_slot(i)


func _throw(s: Stage, kind: int, target: Vector3, high := false) -> void:
	_select(s, kind)
	_aim(s, target, high)
	s.try_throw(s.player.throw_origin(), s.player.throw_direction())


func _look(s: Stage, target: Vector3) -> void:
	var to: Vector3 = target - s.player.head.global_position
	s.player.look_at_angles(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://tests/out/%s.png" % name)


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var K := AmmoType.Kind
	# [스테이지, 첫 투척 탄종, 목표, 결과까지 기다릴 시간]
	var shots := [
		[0, K.FIRE, C[0] + Vector3(0, 2.9, 0), 5.0],
		[1, K.FIRE, Vector3(C[1].x, 1.5, C[1].z + 1.5), 7.5],
		[2, K.FIRE, StageDefs.E3_BEACON + Vector3(0, 3.6, 0.6), 4.5],
		[3, K.HE, C[3] + Vector3(0, 1.5, 2.8), 4.5],
		[4, K.FIRE, C[4] + Vector3(0, 2.0, 4.7), 4.5],
		[5, K.HE, C[5] + Vector3(-3.2, 2.2, 2.05), 4.5],
		[6, K.OIL, C[6] + Vector3(0.3, 0.3, 5.0), 4.5],
		[7, K.FLARE, C[7] + Vector3(0, 0, 2), 6.0],
		[8, K.FIRE, C[8] + Vector3(0, 2.9, 0), 7.0],
		[9, K.FIRE, Vector3(-22.5, 0.8, -66.0), 5.0],
		[10, K.FIRE, StageDefs._along(StageDefs.E11_PATH, 12.0) + Vector3(0, 0.5, 0), 4.0],
	]
	for shot in shots:
		main.load_stage(shot[0])
		await _frames(10)
		var s: Stage = main.stage
		_select(s, shot[1])
		_aim(s, shot[2])
		s.player.begin_windup()
		await _frames(25)
		_save("E%d_a" % (shot[0] + 1))
		s.player.cancel_throw()
		await _frames(15)
		_throw(s, shot[1], shot[2])
		_look(s, shot[2])
		await _real_wait(main, shot[3])
		_save("E%d_b" % (shot[0] + 1))

	# 승리 연출: 쓰러진 방식별 (날아감 / 불탐 / 깔림 / 봉화대)
	var wins := [
		["fly", 0, [[K.FIRE, C[0] + Vector3(0, 2.9, 0), 9.0], [K.FIRE, C[0] + Vector3(0, 1.8, 0), 0.0, true]]],
		["burn", 1, [[K.FIRE, Vector3(C[1].x, 1.5, C[1].z + 1.5), 0.0]]],
		["crush", 5, [[K.HE, C[5] + Vector3(-3.2, 2.2, 2.05), 5.0], [K.FIRE, C[5] + Vector3(3.2, 2.2, 1.9), 0.0]]],
		["beacon", 2, [[K.FIRE, StageDefs.E3_BEACON + Vector3(0, 3.6, 0.6), 0.0]]],
		["night", 7, [[K.FIRE, C[7] + Vector3(0, 2.9, 0), 9.0], [K.FIRE, C[7] + Vector3(0, 1.8, 0), 0.0, true]]],
	]
	for w in wins:
		main.load_stage(w[1])
		await _frames(10)
		var sw: Stage = main.stage
		for t in w[2]:
			_throw(sw, t[0], t[1], t.size() > 3)
			_look(sw, t[1])
			await _real_wait(main, t[2])
		while sw.state == Stage.State.PLAYING:
			await process_frame
		await _real_wait(main, 0.9)
		_save("victory_%s_1" % w[0])
		while main.result and not main.result._ready_for_input:
			await process_frame
		_save("victory_%s_2" % w[0])
	# 실패 그림 (E1: 전부 빗나감)
	main.load_stage(0)
	await _frames(10)
	var s2: Stage = main.stage
	for i in 5:
		_throw(s2, K.FIRE, Vector3(0, 0, -15))
		await _frames(2)
	while s2.state == Stage.State.PLAYING:
		await process_frame
	await _real_wait(main, 1.6)
	_save("failure")
	Engine.time_scale = 1.0
	quit()
