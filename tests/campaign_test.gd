extends "res://tests/stage_test.gd"
## 본편 50개 진지 테스트: 모두 생성 시간·블록 수를 확인하고, 진지마다 설계상 풀이(Campaign.plan)를
## 실제 와인드업 투척 경로로 던져서 이기는지 본다. 바람이 부는 진지는 바람을 감안해 겨눈다.
## 인자: 월드 번호(1~5)를 주면 그 월드만. 실행: Godot --headless --fixed-fps 60 --script res://tests/campaign_test.gd -- 1


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


## 바람 속 궤적의 착탄점 (target 높이로 내려오는 순간).
static func _land(origin: Vector3, dir: Vector3, v: float, wind: Vector3, y: float) -> Vector3:
	var p := origin
	var vel := dir * v
	var dt := 1.0 / 240.0
	for i in 240 * 20:
		var nv := vel + (Vector3.DOWN * G + wind) * dt
		var np := p + (vel + nv) * 0.5 * dt
		if nv.y < 0.0 and np.y <= y:
			return np
		p = np
		vel = nv
	return p


## 바람을 감안한 겨눔: 바람 없이 겨눈 뒤 빗나간 만큼 겨눌 점을 옮기기를 되풀이한다.
func _point_wind(s: Stage, target: Vector3, high: bool) -> void:
	var v := s.current_ammo().throw_speed
	var aim_at := target
	for k in 8:
		for i in 4:
			var dir := aim(s.player.throw_origin(), aim_at, v, high)
			s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))
		var hit := _land(s.player.throw_origin(), s.player.throw_direction(), v, s.wind, target.y)
		var err := hit - target
		err.y = 0.0
		if err.length() < 0.05:
			break
		aim_at -= err


func _throw_plan(s: Stage, kind: int, target: Vector3, high: bool) -> void:
	_select(s, kind)
	if s.wind != Vector3.ZERO:
		_point_wind(s, target, high)
	else:
		_point(s, target, high)
	var before := s.throws
	if not s.player.begin_windup():
		return
	s.player.request_release()
	var guard := 0
	while s.throws == before and guard < 120:
		await physics_frame
		guard += 1


func _play(i: int) -> void:
	var s := _campaign(i)
	await physics_frame
	for step in Campaign.plan(i):
		if s.state != Stage.State.PLAYING:
			break
		if step[0] is String:
			await _ally(s)
			continue
		var target: Vector3 = step[1]
		if target == Vector3.INF:
			target = s.commander.global_position + Vector3(0, 1.2, 0)
		await _throw_plan(s, step[0], target, step[2])
		if step[3] > 0.0:
			await _wait(s, step[3])
	await _expect(s, Stage.State.CLEARED, "%s %s 풀이" % [Campaign.label(i), Campaign.title(i)], 60.0)


## 지원형 풀이 (E11 배치): 방패병(화염) → 바리케이드(고폭) → 울타리(고폭) → 성문 앞 폭발통(화염).
func _ally(s: Stage) -> void:
	var pts: Array = StageDefs.E11_PATH
	await _throw_plan(s, AmmoType.Kind.FIRE, StageDefs._along(pts, 12.0) + Vector3(0, 0.5, 0), false)
	await _throw_plan(s, AmmoType.Kind.HE, StageDefs._along(pts, 22.0) + Vector3(0, 0.7, 0.3), false)
	await _throw_plan(s, AmmoType.Kind.HE, StageDefs._along(pts, 32.0) + Vector3(1.2, 0.0, 0.8), false)
	var ally: Ally = s.allies[0]
	var t := 0.0
	while not ally.at_gate and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
	await _throw_plan(s, AmmoType.Kind.FIRE, ally.global_position + Vector3(0, 1.0, 0.5), false)


func _run() -> void:
	print("== 본편 50개 진지 테스트 ==")
	Engine.max_fps = 0
	preload("res://scripts/main.gd").register_input()
	var first := 0
	var last := Campaign.COUNT
	if _only > 0:
		first = (_only - 1) * 10
		last = first + 10
	for i in range(first, last):
		await _play(i)
	# 발리스타가 남아 있으면 미사일이 요격당한다 (5-2)
	if _only <= 0 or _only == 5:
		var s := _campaign(41)
		await physics_frame
		await _throw_plan(s, AmmoType.Kind.FLAREGUN, Campaign.STAGES[41].c + Vector3(0, 2.7, 0), false)
		await _wait(s, 4.0)
		_check(s.state == Stage.State.PLAYING and not s.commander.dead, "5-2 발리스타가 서 있으면 미사일이 요격당한다")
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
