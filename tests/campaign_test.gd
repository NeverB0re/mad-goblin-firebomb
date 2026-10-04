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
			if step[0] == "button":
				_to_button(s)
				s.press_button()
			else:
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


## 최종 진지: 고블린을 발사 버튼 곁(투척 구역 왼쪽 끝)으로 옮긴다.
func _to_button(s: Stage) -> void:
	s.player.global_position = Vector3(s.player.zone_min.x, s.player.global_position.y, s._button.global_position.z)


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
	# 흰 석재는 화약통 폭발에도 안 부서진다 (1-9 돌 망루 화약통 옆 성벽)
	if _only <= 0 or _only == 1:
		var s := _campaign(8)
		await physics_frame
		for step in Campaign.plan(8):
			var target: Vector3 = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0) if step[1] is int else step[1]
			await _throw_plan(s, step[0], target, step[2])
		await _wait(s, 6.0)
		var stone_fell := 0
		for st in s.structures:
			# 다리 묶음이 있는 건물(금 간 기둥이 부러지면 통째로 기우는 망대)은 빼고 본다
			if not st.leg_groups.is_empty():
				continue
			for blk in st.blocks:
				if blk.mat == Block.Mat.STONE and blk.fallen and blk.start_low < 0.1:
					stone_fell += 1
		_check(stone_fell == 0, "1-9 화약통이 터져도 땅에 선 흰 석재는 그대로 (%d개 넘어짐)" % stone_fell)
	# 발리스타가 남아 있으면 글라이더가 격추되어 불시착한다 (4-3). 폭격대 한 명을 잃는다
	if _only <= 0 or _only == 4:
		var s := _campaign(32)
		await physics_frame
		var bombers := s.bombers_left()
		await _throw_plan(s, AmmoType.Kind.FLARE, Campaign.STAGES[32].parts[0][1] + Vector3(0, 2.7, 0), false)
		await _wait(s, 7.0)
		_check(s.state == Stage.State.PLAYING and s.commanders_left() == 2 and s.bombers_left() == bombers - 1, "4-3 발리스타가 서 있으면 글라이더가 격추된다 (폭격대 %d → %d)" % [bombers, s.bombers_left()])
	# 발리스타를 조종하는 궁병을 쓰러뜨리면 탑이 서 있어도 그 발리스타는 못 쏜다 (4-1)
	if _only <= 0 or _only == 4:
		var s := _campaign(30)
		await physics_frame
		var b: Block = s.ballistas[0]
		var op: Guard = b.get_meta("operator")
		var before := s.aa_alive()
		op.defeat("direct")
		_check(before and not s.aa_alive() and not b.fallen, "4-1 발리스타 궁병을 맞히면 탑이 서 있어도 발리스타가 멈춘다")
	# 폭격은 조명탄이 조금 빗나가도(무리 한가운데에서 5m) 무리 전체를 끝낸다 (4-6, 발리스타를 다 치운 뒤)
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
		await _expect(s, Stage.State.CLEARED, "4-6 조명탄이 5m 빗나가도 폭격 한 번으로 끝난다", 14.0)
	# 최종 진지: 발리스타가 서 있으면 발사 버튼 안전장치가 걸리고, 다 치우면 로켓 한 발로 남은 지휘관이 모두 쓰러진다
	if _only <= 0 or _only == 5:
		var s := _campaign(49)
		await physics_frame
		_to_button(s)
		var fired := s.press_button()
		_check(not fired and s.button_ready(), "5-10 발리스타가 서 있으면 발사 버튼이 안 눌린다")
	# 페인트탄은 아무것도 부수지 않고 물감 자국만 남기며, 페인트탄·조명탄만 남으면 실패한다 (3-6)
	if _only <= 0 or _only == 3:
		var s := _campaign(25)
		await physics_frame
		for k in 4:
			await _throw_plan(s, AmmoType.Kind.FIRE, Vector3(-30, 0, -20), false)
		await _throw_plan(s, AmmoType.Kind.PAINT, s.commanders[0].global_position + Vector3(0, 1.2, 0), false)
		await _wait(s, 2.0)
		var marks := s.get_tree().get_nodes_in_group("signal_smoke").size()
		_check(not s.commanders[0].dead and marks > 0, "3-6 연기알을 맞아도 지휘관은 멀쩡하고 신호 연기만 솟는다 (연기 %d)" % marks)
		await _expect(s, Stage.State.FAILED, "3-6 폭탄을 다 쓰고 연기알·조명탄만 남으면 실패", 20.0, "fail_ammo")
	# 남은 탄으로 더는 깰 수 없으면 실패: 2-1 연료 창고에서 기름병을 다 버리면 화염탄이 남아도 실패
	if _only <= 0 or _only == 2:
		var s := _campaign(10)
		await physics_frame
		for k in 2:
			await _throw_plan(s, AmmoType.Kind.OIL, Vector3(-30, 0, -20), false)
		await _expect(s, Stage.State.FAILED, "2-1 기름병을 다 버리면 화염탄이 남아도 실패", 20.0, "fail_stuck")
	# 3-3 금 간 석재 망대: 금 간 기둥 하나가 부러지면 망대가 그쪽으로 기울어 넘어간다 (밑으로 꺼지지 않는다)
	if _only <= 0 or _only == 3:
		var s := _campaign(22)
		await physics_frame
		var c: Vector3 = Campaign.STAGES[22].parts[0][1]
		var deck: Block
		for b in s.structures[0].blocks:
			if b.mat == Block.Mat.STONE and b.size.x > 3.0 and b.size.y < 0.5:
				deck = b
		await _throw_plan(s, AmmoType.Kind.HE, c + Vector3(-1.4, 1.0, 1.9), false)
		await _wait(s, 3.0)
		var moved := Vector3.ZERO if not is_instance_valid(deck) else deck.global_position - (c + Vector3(0, 4.7, 0))
		_check(moved.x < -0.8 and moved.z > 0.5, "3-3 금 간 앞 왼쪽 기둥이 부러지면 망대가 앞 왼쪽으로 기운다 (바닥 이동 %s)" % str(moved.snapped(Vector3.ONE * 0.1)))
	# 1-1 나무 망루: 한쪽 다리 둘이 타 없어지면 그쪽으로 넘어가 지휘관이 떨어진다
	if _only <= 0 or _only == 1:
		var s := _campaign(0)
		await physics_frame
		var c: Vector3 = Campaign.STAGES[0].parts[0][1]
		var legs: Array = s.structures[0].leg_groups[0].legs
		for b in legs:
			if b.position.x > c.x:
				b.ignite(4.0)
		await _wait(s, 12.0)
		_check(s.commanders[0].dead, "1-1 망루 오른쪽 다리 둘이 타면 넘어가 지휘관이 떨어진다 (%s)" % s.commanders[0].defeat_cause)
	# 데이터 규칙
	for i in Campaign.COUNT:
		var d: Dictionary = Campaign.STAGES[i]
		var paint := Campaign.paint_count(i)
		_check(paint == 1 + Campaign.commander_count(i) and (i < 7 or d.has("wind")),
			"%s 페인트탄 %d (지휘관 %d), 바람 %d단계" % [Campaign.label(i), paint, Campaign.commander_count(i), d.get("wind", [0])[0]])
		if Campaign.world_of(i) == 3 and (d.get("ballistas", []).is_empty() or d.get("bombers", 0) <= 0):
			_check(false, "%s 4월드 진지에 발리스타와 공수부대가 없다" % Campaign.label(i))
		if Campaign.bonus_text(i) == "":
			_check(false, "%s 보조 목표 문구가 없다" % Campaign.label(i))
		if Campaign.is_night(i) and not d.get("ballistas", []).is_empty():
			_check(false, "%s 밤 진지에 발리스타가 있다" % Campaign.label(i))
		if Campaign.world_of(i) == 4 and not d.get("final", false):
			var feature: bool = Campaign.is_night(i) or Campaign.is_rain(i) or not d.get("ballistas", []).is_empty()
			_check(feature, "%s 5월드 진지에 앞 월드 특성(비·밤·발리스타)이 있다" % Campaign.label(i))
	# 3-2 불빛 구경꾼: 조명탄이 없으면 강철 초소 안에 그대로, 문 앞에 켜지면 걸어 나와 구경하고, 꺼지면 다시 들어간다
	if _only <= 0 or _only == 3:
		var s := _campaign(21)
		await physics_frame
		var cm: Commander = s.commanders[0]
		var home := cm.global_position
		await _wait(s, 3.0)
		var stayed := cm.global_position.distance_to(home) < 0.2
		var c: Vector3 = Campaign.STAGES[21].parts[0][1]
		var spot := c + Campaign._guard_spot(1.0)
		await _throw_plan(s, AmmoType.Kind.FLARE, spot + Vector3(0, 0.1, 0), false)
		await _wait(s, 7.0)
		var out_d := Vector2(cm.global_position.x - spot.x, cm.global_position.z - spot.z).length()
		await _wait(s, 14.0)
		var back := cm.global_position.distance_to(home)
		_check(stayed and out_d < 0.6 and back < 0.6, "3-2 조명탄 불빛에 지휘관이 걸어 나와 구경하고(구경 자리까지 %.1fm), 꺼지면 들어간다 (집까지 %.1fm)" % [out_d, back])
	# 1-8 짚 지붕 줄집: 끝집 지붕 하나에 불을 붙이면 잇닿은 지붕을 타고 세 집 지휘관이 모두 쓰러진다
	if _only <= 0 or _only == 1:
		var s := _campaign(7)
		s.wind = Vector3.ZERO
		await physics_frame
		var step: Array = Campaign.plan(7)[0]
		await _throw_plan(s, step[0], step[1], step[2])
		await _expect(s, Stage.State.CLEARED, "1-8 끝집에 불 한 번 → 옆집으로 번져 지휘관 셋", 40.0)
	# 1-10 지원: 동료가 걷기 시작하면 심지가 타고, 성문 앞에 닿으면 플레이어가 안 터뜨려도 스스로 터져 빗장 잡은 지휘관이 날아간다
	if _only <= 0 or _only == 1:
		var s := _campaign(9)
		await physics_frame
		var steps := Campaign.plan(9)
		var ally: Ally = s.allies[0]
		for step in steps:
			await _throw_plan(s, step[0], step[1], step[2])
			await _wait(s, 1.0)
		var t := 0.0
		while not ally.at_gate and t < 60.0:
			await physics_frame
			t += 1.0 / 60.0
		var waited_alive := not s.commanders[0].dead and not ally.exploded
		await _expect(s, Stage.State.CLEARED, "1-10 동료가 성문 앞에서 스스로 터진다 (성문 앞까지 %.1f초, 도착 직후엔 아직 안 터짐 %s)" % [t, waited_alive], 10.0)
	# 시작 조망: 한 바퀴 돌고 투척 시점으로 내려오며, 건너뛸 수 있다
	if _only <= 0 or _only == 1:
		var s := _campaign(2)
		await physics_frame
		var cam := IntroCam.new()
		s.add_child(cam)
		cam.setup(s)
		var locked := s.player.input_locked
		await _wait(s, 1.0)
		cam.skip()
		await _wait(s, 1.0)
		_check(locked and not s.player.input_locked and not is_instance_valid(cam), "시작 조망 중엔 조작이 잠기고, 건너뛰면 투척 시점으로 돌아온다")
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
