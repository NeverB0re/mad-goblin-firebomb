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
		var hit := _land(s.player.throw_origin(), s.player.throw_direction(), v, s.wind * s.current_ammo().wind_factor, target.y)
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
	var log := []
	s.projectile_thrown.connect(func(p: Projectile):
		var kind: String = p.ammo.display_name
		p.impacted.connect(func(_p, pos: Vector3, _n, col: Object):
			var what := "없음"
			if col is Block:
				what = Block.Mat.keys()[col.mat] + str(col.global_position.snapped(Vector3.ONE * 0.1))
			elif col:
				what = col.get_class() + " " + str(col.name)
			log.append("%s → %s %s" % [kind, pos.snapped(Vector3.ONE * 0.1), what])))
	await physics_frame
	for step in Campaign.plan(i):
		if s.state != Stage.State.PLAYING:
			break
		if step[0] is String:
			await _ally(s)
			continue
		var target: Vector3
		if step[1] is int:
			target = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0)
		else:
			target = step[1]
		await _throw_plan(s, step[0], target, step[2])
		if step[3] > 0.0:
			await _wait(s, step[3])
	await _expect(s, Stage.State.CLEARED, "%s %s 풀이 (지휘관 %d)" % [Campaign.label(i), Campaign.title(i), s.commanders.size()], 60.0)
	if s.state != Stage.State.CLEARED:
		var left := []
		for k in s.commanders.size():
			if not s.commanders[k].dead:
				left.append(k)
		for line in log:
			print("    ", line)
		for k in left:
			print("    지휘관 %d 위치 %s" % [k, s.commanders[k].global_position.snapped(Vector3.ONE * 0.1)])
		print("    남은 지휘관 번호: ", left, "  남은 탄: ", s.ammo_slots.map(func(x): return "%s %d" % [x.type.display_name, x.count]))


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
	# 2월드는 비에 젖어 기름 없이 화염탄만으로는 안 풀린다 (기름 단계를 빼고 같은 자리에 화염탄만)
	if _only <= 0 or _only == 2:
		for i in [11, 12, 14, 16]:
			var s := _campaign(i)
			await physics_frame
			for step in Campaign.plan(i):
				if step[0] == AmmoType.Kind.FIRE:
					var target: Vector3 = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0) if step[1] is int else step[1]
					await _throw_plan(s, step[0], target, step[2])
			await _wait(s, 12.0)
			_check(s.state == Stage.State.PLAYING, "%s 기름 없이 화염탄만으로는 안 풀린다 (남은 지휘관 %d)" % [Campaign.label(i), s.commanders_left()])
	# 3-5: 화약 수레를 터뜨리면 강철 방벽이 날아가고, 방벽 뒤 지휘관은 아직 살아 있다
	if _only <= 0 or _only == 3:
		var s := _campaign(24)
		await physics_frame
		var c: Vector3 = Campaign.STAGES[24].parts[0][1]
		await _throw_plan(s, AmmoType.Kind.FIRE, c + Vector3(-1.5, 1.0, 3.3), false)
		await _wait(s, 6.0)
		_check(s.commanders_left() == 2, "3-5 강철 방벽 정면에 던진 불로는 아무도 안 쓰러진다 (남은 지휘관 %d)" % s.commanders_left())
		var walls := s.structures[0].blocks.size()
		await _throw_plan(s, AmmoType.Kind.FIRE, c + Vector3(Campaign.KEG_FUSE_X, 0.1, 4.8), false)
		await _wait(s, 1.0)
		_check(s.commanders_left() == 2, "3-5 도화선이 타 들어가는 동안은 아직 안 터진다")
		await _wait(s, 8.0)
		var blown := 0
		for blk in s.structures[0].blocks:
			if blk.fallen:
				blown += 1
		_check(blown >= walls / 2 and s.commanders_left() == 0, "3-5 도화선 → 숨은 화약통 폭발 → 강철 방벽 %d/%d조각 날아감, 남은 지휘관 %d" % [blown, walls, s.commanders_left()])
	# 흰 석재는 화약통 폭발에도 안 부서진다 (1-10 공성탑 화약통 옆 성벽)
	if _only <= 0 or _only == 1:
		var s := _campaign(9)
		await physics_frame
		for step in Campaign.plan(9):
			var target: Vector3 = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0) if step[1] is int else step[1]
			await _throw_plan(s, step[0], target, step[2])
		await _wait(s, 6.0)
		var stone_fell := 0
		for st in s.structures:
			for blk in st.blocks:
				if blk.mat == Block.Mat.STONE and blk.fallen and blk.start_low < 0.1:
					stone_fell += 1
		_check(stone_fell == 0, "1-10 화약통이 터져도 땅에 선 흰 석재는 그대로 (%d개 넘어짐)" % stone_fell)
	# 발리스타가 남아 있으면 로켓이 요격당한다 (4-3). 로켓은 한 발 준다
	if _only <= 0 or _only == 4:
		var s := _campaign(32)
		await physics_frame
		var rockets := s.rockets_left()
		await _throw_plan(s, AmmoType.Kind.FLARE, Campaign.STAGES[32].parts[0][1] + Vector3(0, 2.7, 0), false)
		await _wait(s, 5.0)
		_check(s.state == Stage.State.PLAYING and s.commanders_left() == 2 and s.rockets_left() == rockets - 1, "4-3 발리스타가 서 있으면 로켓이 요격당한다 (로켓 %d → %d)" % [rockets, s.rockets_left()])
	# 로켓은 조명탄이 조금 빗나가도(무리 한가운데에서 5m) 무리 전체를 끝낸다 (4-6, 발리스타를 다 치운 뒤)
	if _only <= 0 or _only == 4:
		var s := _campaign(35)
		await physics_frame
		var steps := Campaign.plan(35)
		for step in steps:
			if step[0] != AmmoType.Kind.FLARE:
				await _throw_plan(s, step[0], step[1], step[2])
				if step[3] > 0.0:
					await _wait(s, step[3])
		var aim: Vector3 = steps[steps.size() - 1][1] + Vector3(-2.0, 0.0, 4.5)
		await _throw_plan(s, AmmoType.Kind.FLARE, aim, false)
		await _expect(s, Stage.State.CLEARED, "4-6 조명탄이 5m 빗나가도 로켓 한 발로 끝난다", 12.0)
	# 페인트탄은 아무것도 부수지 않고 물감 자국만 남기며, 페인트탄·조명탄만 남으면 실패한다 (3-6)
	if _only <= 0 or _only == 3:
		var s := _campaign(25)
		await physics_frame
		for k in 4:
			await _throw_plan(s, AmmoType.Kind.FIRE, Vector3(-30, 0, -20), false)
		await _throw_plan(s, AmmoType.Kind.PAINT, s.commanders[0].global_position + Vector3(0, 1.2, 0), false)
		await _wait(s, 2.0)
		var marks := s.find_children("*", "Decal", false, false).filter(func(d): return d.texture_emission != null).size()
		_check(not s.commanders[0].dead and marks > 0, "3-6 페인트탄을 맞아도 지휘관은 멀쩡하고 물감 자국만 남는다 (자국 %d)" % marks)
		await _expect(s, Stage.State.FAILED, "3-6 폭탄을 다 쓰고 페인트탄·조명탄만 남으면 실패", 20.0, "fail_ammo")
	# 모든 진지에 페인트탄이 목표 수 이상 있고, 1-7부터는 모든 진지에 바람자루가 선다
	for i in Campaign.COUNT:
		var paint := Campaign.paint_count(i)
		var need := 1 if Campaign.STAGES[i].has("rockets") else Campaign.commander_count(i)
		_check(paint >= need and (i < 6 or Campaign.STAGES[i].has("wind")),
			"%s 페인트탄 %d (지휘관 %d), 바람 %d단계" % [Campaign.label(i), paint, Campaign.commander_count(i), Campaign.STAGES[i].get("wind", [0])[0]])
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
