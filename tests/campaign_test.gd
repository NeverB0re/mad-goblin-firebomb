extends "res://tests/stage_test.gd"
## 본편 스테이지 테스트: 13개 모두 생성 시간·블록 수, 새 연계 스테이지 셋(화약고, 매달린 추, 국경 요새)의 풀이.
## 시험 스테이지를 다시 쓰는 본편 스테이지의 풀이는 stage_test가 확인한다.
## 실행: Godot --headless --fixed-fps 60 --script res://tests/campaign_test.gd


func _campaign(index: int) -> Stage:
	for c in root.get_children():
		if c is Stage:
			root.remove_child(c)
			c.queue_free()
	Engine.time_scale = 1.0
	var t0 := Time.get_ticks_usec()
	var stage := Stage.new()
	root.add_child(stage)
	Campaign.build(index, stage)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var blocks := 0
	for st in stage.structures:
		blocks += st.blocks.size()
	_check(ms < 1000.0 and blocks <= 150 and stage.player != null,
		"%s %s 생성 %.1fms, 블록 %d개" % [Campaign.label(index), Campaign.title(index), ms, blocks])
	return stage


func _run() -> void:
	print("== 본편 스테이지 테스트 ==")
	Engine.max_fps = 0
	preload("res://scripts/main.gd").register_input()
	var K := AmmoType.Kind
	var s: Stage
	for i in Campaign.COUNT:
		s = _campaign(i)
		await physics_frame

	# 1-5 화약고: 창고 지붕에 불 → 화약통 폭발 → 망대 기둥이 부러져 지휘관이 떨어진다
	s = _campaign(4)
	await physics_frame
	var c: Vector3 = Campaign.POWDER_TOWER
	await _throw(s, K.FIRE, c + Vector3(3.6, 2.2, 0.4))
	await _expect(s, Stage.State.CLEARED, "1-5 화약 창고에 불 → 망대 붕괴")
	# 1-5: 망대 꼭대기 지붕 위 화염탄으로는 지휘관이 무사하다
	s = _campaign(4)
	await physics_frame
	await _throw(s, K.FIRE, c + Vector3(0, 7.0, 0))
	await _wait(s, 6.0)
	_check(s.state == Stage.State.PLAYING, "1-5 망대 지붕 화염탄 → 지휘관 무사 %s" % s.commander.defeat_cause)

	# 1-10 매달린 추: 밧줄(쇳덩이)에 불 → 쇳덩이가 지붕을 뚫고 떨어진다
	s = _campaign(9)
	await physics_frame
	c = Campaign.WEIGHT_HUT
	await _throw(s, K.FIRE, c + Vector3(0, 7.5, -0.1))
	await _expect(s, Stage.State.CLEARED, "1-10 밧줄을 태워 쇳덩이 떨어뜨리기")
	# 1-10: 석재 벽 앞에 던지면 아무 일도 없다
	s = _campaign(9)
	await physics_frame
	await _throw(s, K.FIRE, c + Vector3(1.5, 1.0, 2.3))
	await _wait(s, 6.0)
	_check(s.state == Stage.State.PLAYING, "1-10 석벽 앞 화염탄 → 지휘관 무사 %s" % s.commander.defeat_cause)

	# 1-13 국경 요새: 석벽 너머 화약통에 높이 띄워 넣는다 → 공성탑 붕괴
	s = _campaign(12)
	await physics_frame
	c = Campaign.FORTRESS
	var dist := Vector2(c.x, c.z).distance_to(Vector2(s.player.global_position.x, s.player.global_position.z))
	_check(dist > 65.0, "1-13 요새까지 %.0fm" % dist)
	await _throw(s, K.FIRE, c + Vector3(0, 0.7, 2.3), true)
	await _expect(s, Stage.State.CLEARED, "1-13 화약통으로 공성탑 무너뜨리기")
	# 1-13: 성벽 정면 고폭탄 두 발로는 성벽이 버틴다
	s = _campaign(12)
	await physics_frame
	for i in 2:
		await _throw(s, K.HE, c + Vector3(-4.5, 2.0, 6.6))
	await _wait(s, 3.0)
	var fallen := 0
	for blk in s.structures[0].blocks:
		if blk.fallen:
			fallen += 1
	_check(fallen == 0 and s.state == Stage.State.PLAYING, "1-13 성벽은 고폭탄에 버틴다 (무너진 블록 %d)" % fallen)

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
