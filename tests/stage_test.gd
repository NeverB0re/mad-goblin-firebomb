extends SceneTree
## 확장 스테이지 실행 테스트: E1~E11을 실제 와인드업 투척 경로(누름 → 최소 와인드업 → 놓기 → 릴리스 지연)로
## 풀어 보고, 승리(지휘관)·실패(탄약 소진, 전령 도착) 판정과 재시작 시간을 확인한다.
## 실행: Godot --headless --fixed-fps 60 --script res://tests/stage_test.gd

const G := 9.8
const MAX_TIME := 45.0
const C := StageDefs.COMMANDER

var _failures := 0
var _only := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_only = int(args[0])
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		_failures += 1
		print("  FAIL ", msg)


## 낮은 포물선(high면 높이 띄운 포물선)으로 target에 닿는 방향. 닿을 수 없으면 45도.
## 낮은 언덕에서 지붕 밑을 노릴 때는 높이 띄워 가파르게 떨어뜨린다.
static func aim(origin: Vector3, target: Vector3, v: float, high := false) -> Vector3:
	var flat := Vector2(target.x - origin.x, target.z - origin.z)
	var x := flat.length()
	var y := target.y - origin.y
	var disc := v * v * v * v - G * (G * x * x + 2.0 * y * v * v)
	var root := sqrt(maxf(disc, 0.0)) * (-1.0 if high else 1.0)
	var theta := atan((v * v - root) / (G * x)) if disc >= 0.0 else PI * 0.25
	var h := flat.normalized()
	return Vector3(h.x * cos(theta), sin(theta), h.y * cos(theta)).normalized()


static func reachable(origin: Vector3, target: Vector3, v: float) -> bool:
	var x := Vector2(target.x - origin.x, target.z - origin.z).length()
	var y := target.y - origin.y
	return v * v * v * v - G * (G * x * x + 2.0 * y * v * v) >= 0.0


static func flight_time(origin: Vector3, target: Vector3, dir: Vector3, v: float) -> float:
	var x := Vector2(target.x - origin.x, target.z - origin.z).length()
	return x / (v * Vector2(dir.x, dir.z).length()) / Projectile.FLIGHT_TIME_SCALE


## 전령이 지금(첫 투척 직전)부터 비행 시간 뒤에 있을 경로 위 지점. extra: 추가로 지난 시간.
func _lead_on_path(s: Stage, m: Messenger, extra: float) -> Vector3:
	var curve: Curve3D = (m.follow.get_parent() as Path3D).curve
	var t := 2.0
	var p := curve.sample_baked(0.0)
	for i in 8:
		p = curve.sample_baked(m.follow.progress + m.speed * (t + extra))
		var v := StageDefs.FIRE.throw_speed
		var dir := aim(s.player.throw_origin(), p + Vector3(0, 0.9, 0), v)
		t = flight_time(s.player.throw_origin(), p, dir, v)
	return p


func _select(s: Stage, kind: int) -> void:
	for i in s.ammo_slots.size():
		if s.ammo_slots[i].type.kind == kind:
			s.select_slot(i)
			return


func _point(s: Stage, target: Vector3, high := false) -> void:
	var v := s.current_ammo().throw_speed
	for i in 4:
		var dir := aim(s.player.throw_origin(), target, v, high)
		s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))


## 실제 입력 경로로 던진다: 와인드업 시작 → 바로 놓기 요청 → 손을 떠날 때까지 틱 진행.
func _throw(s: Stage, kind: int, target: Vector3, high := false) -> void:
	_select(s, kind)
	_point(s, target, high)
	var before := s.throws
	if not s.player.begin_windup():
		return
	s.player.request_release()
	var guard := 0
	while s.throws == before and guard < 120:
		await physics_frame
		guard += 1


## 날아가는 폭탄이 모두 떨어진 뒤부터 seconds 동안 기다린다.
func _wait(s: Stage, seconds: float) -> void:
	while not s._projectiles.is_empty() and s.state == Stage.State.PLAYING:
		await physics_frame
	var t := 0.0
	while t < seconds and s.state == Stage.State.PLAYING:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _new_stage(index: int) -> Stage:
	for c in root.get_children():
		if c is Stage:
			root.remove_child(c)
			c.queue_free()
	Engine.time_scale = 1.0
	var t0 := Time.get_ticks_usec()
	var stage := Stage.new()
	root.add_child(stage)
	StageDefs.build(index, stage)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var blocks := 0
	for st in stage.structures:
		blocks += st.blocks.size()
	_check(ms < 1000.0 and blocks <= 150, "%s 생성 %.1fms, 블록 %d개 (1초 이내, 150개 이하)" % [StageDefs.NAMES[index], ms, blocks])
	return stage


func _expect(s: Stage, want: int, label: String, limit := MAX_TIME, cause := "") -> void:
	var t0 := s.elapsed
	while s.state == Stage.State.PLAYING and s.elapsed - t0 < limit:
		await physics_frame
	# 히트스톱·승리 연출이 남긴 시간 배율을 되돌린다 (테스트는 연출 화면이 없다)
	Engine.time_scale = 1.0
	var names := ["진행 중", "승리", "실패"]
	var ok := s.state == want and (cause == "" or s.fail_cause == cause)
	var why: String = s.fail_cause
	if s.state == Stage.State.CLEARED:
		if s.commander:
			why = "지휘관: " + s.commander.defeat_cause
		elif not s.messengers.is_empty() and s.messengers[0].dead:
			why = "전령: " + s.messengers[0].defeat_cause
		else:
			why = "다리가 끊겨 전령이 멈춤"
	_check(ok, "%s → %s %s (투척 %d회, %.1f초)" % [label, names[s.state], why, s.throws, s.elapsed])


func _want(i: int) -> bool:
	return _only < 0 or _only == i


func _run() -> void:
	print("== 확장 스테이지 테스트 ==")
	Engine.max_fps = 0
	preload("res://scripts/main.gd").register_input()
	var s: Stage
	var K := AmmoType.Kind

	if _want(0):
		# E1: 차양을 태우고 직격
		s = _new_stage(0)
		await physics_frame
		await _throw(s, K.FIRE, C[0] + Vector3(0, 2.9, 0))
		await _wait(s, 6.0)
		_check(s.state == Stage.State.PLAYING, "E1 차양만 태워서는 끝나지 않는다 %s" % (s.commander.defeat_cause if s.commander.dead else ""))
		await _throw(s, K.FIRE, C[0] + Vector3(0, 1.8, 0), true)
		await _expect(s, Stage.State.CLEARED, "E1 차양 태우고 높이 띄워 직격")
		s = _new_stage(0)
		await physics_frame
		for i in 5:
			await _throw(s, K.FIRE, Vector3(0, 0, -20))
		await _expect(s, Stage.State.FAILED, "E1 전부 빗나감", MAX_TIME, "fail_ammo")

	if _want(1):
		# E2: 망루 다리의 가로대를 태우고 기다린다
		s = _new_stage(1)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(C[1].x, 1.5, C[1].z + 1.5))
		await _expect(s, Stage.State.CLEARED, "E2 망루 다리 점화 후 기다리기")

	if _want(2):
		# E3: 전령을 앞질러 맞힌다 (구불구불한 경로를 따라 비행 시간만큼 앞)
		s = _new_stage(2)
		await physics_frame
		var m: Messenger = s.messengers[0]
		await _throw(s, K.FIRE, _lead_on_path(s, m, 0.0) + Vector3(0, 0.9, 0))
		await _expect(s, Stage.State.CLEARED, "E3 전령 예측 투척", 10.0)
		_check(m.dead, "E3 전령이 쓰러짐 (%s)" % m.defeat_cause)
		# E3: 건너야 할 나무다리를 먼저 태운다 (두 번째 풀이)
		s = _new_stage(2)
		await physics_frame
		await _throw(s, K.FIRE, StageDefs.E3_BRIDGE + Vector3(0, 0.45, 0))
		await _expect(s, Stage.State.CLEARED, "E3 다리 먼저 태우기")
		_check(s.messengers[0].stranded, "E3 전령이 끊긴 다리 앞에서 멈춤")
		# E3: 아무것도 막지 않으면 전령이 도착해 실패
		s = _new_stage(2)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(-30, 0, -25))
		await _expect(s, Stage.State.FAILED, "E3 전령 방치", 60.0, "fail_messenger")
	if _want(3):
		# E4: 고폭탄으로 금 간 석벽 → 지휘관
		s = _new_stage(3)
		await physics_frame
		await _throw(s, K.HE, C[3] + Vector3(0, 1.5, 2.8))
		await _wait(s, 3.0)
		if s.state == Stage.State.PLAYING:
			await _throw(s, K.HE, C[3] + Vector3(0, 1.0, 0.2))
		await _expect(s, Stage.State.CLEARED, "E4 석벽 날리고 직격")
		# E4: 살짝 빗나간 고폭탄도 가까운 석벽에 금을 키운다 (끊기지는 않아도 약해진다)
		s = _new_stage(3)
		await physics_frame
		await _throw(s, K.HE, C[3] + Vector3(5.0, 0.0, 4.6))
		await _wait(s, 1.0)
		var worn := 0
		var fell := 0
		for blk in s.structures[0].blocks:
			if blk.mat == Block.Mat.CRACKED:
				if blk.integrity < 0.9:
					worn += 1
				if blk.fallen:
					fell += 1
		_check(worn > 0 and fell == 0, "E4 빗나간 고폭탄 → 석벽 %d개에 금이 커짐, 무너진 것 %d개" % [worn, fell])
		# 강철 지붕과 기둥은 고폭탄을 바로 맞아도 그대로다
		await _throw(s, K.HE, C[3] + Vector3(2.6, 3.3, -2.2))
		await _wait(s, 2.0)
		var steel_ok := true
		for blk in s.structures[0].blocks:
			if blk.mat == Block.Mat.STEEL and blk.fallen:
				steel_ok = false
		_check(steel_ok, "E4 강철 지붕은 고폭탄 직격에도 버틴다")

	if _want(4):
		# E5: 화염탄으로는 금 간 석벽이 안 부서진다 → 고폭탄으로 벽 → 화염탄으로 초소
		s = _new_stage(4)
		await physics_frame
		await _throw(s, K.FIRE, C[4] + Vector3(0, 2.0, 4.7))
		await _wait(s, 3.0)
		var wall_ok := true
		for st in s.structures:
			for blk in st.blocks:
				if blk.mat == Block.Mat.CRACKED and (blk.fallen or blk.burning):
					wall_ok = false
		_check(wall_ok and s.state == Stage.State.PLAYING, "E5 화염탄은 석벽을 못 뚫는다")
		await _throw(s, K.HE, C[4] + Vector3(0, 1.5, 4.7))
		await _wait(s, 2.0)
		# 날아든 벽 조각에 지휘관이 밀려났을 수 있으니 지금 자리를 노린다
		await _throw(s, K.FIRE, s.commander.global_position + Vector3(0, 1.2, 0), true)
		await _expect(s, Stage.State.CLEARED, "E5 벽 날리고 초소 태우기")

	if _want(5):
		# E6: 금 간 석재 기둥(고폭) + 목재 버팀목(화염) → 덮개에 깔림
		s = _new_stage(5)
		await physics_frame
		await _throw(s, K.HE, C[5] + Vector3(-3.2, 2.2, 2.05))
		await _wait(s, 2.0)
		_check(s.state == Stage.State.PLAYING, "E6 기둥 하나로는 덮개가 버틴다")
		await _throw(s, K.FIRE, C[5] + Vector3(3.2, 2.2, 1.9))
		await _expect(s, Stage.State.CLEARED, "E6 덮개 떨어뜨려 깔기")
		# 정면 바위턱 너머 직격·폭발은 막힌다. 가운데에 거듭 던지면 받침 둘이 조금씩 닳아 결국 덮개가 떨어질 수는 있다
		s = _new_stage(5)
		await physics_frame
		await _throw(s, K.HE, C[5] + Vector3(0, 1.6, 3.2))
		await _wait(s, 3.0)
		_check(s.state == Stage.State.PLAYING, "E6 바위턱 정면 고폭탄 한 발로는 지휘관이 무사 %s" % (s.commander.defeat_cause if s.commander.dead else ""))
		for i in 2:
			await _throw(s, K.HE, C[5] + Vector3(0, 1.6, 3.2))
		await _wait(s, 3.0)
		_check(not s.commander.dead or s.commander.defeat_cause == "crush", "E6 정면 고폭탄 3발은 지휘관에게 직접 닿지 않는다 (%s)" % s.commander.defeat_cause)

	if _want(6):
		# E7: 화염탄만으로는 젖은 홈통이 타지 않는다 → 기름을 붓고 짚에 점화
		s = _new_stage(6)
		await physics_frame
		await _throw(s, K.FIRE, C[6] + Vector3(0.3, 0.3, 3.8))
		await _wait(s, 10.0)
		_check(s.state == Stage.State.PLAYING, "E7 기름 없이 홈통 입구 화염탄 → 안까지 안 번진다")
		s = _new_stage(6)
		await physics_frame
		await _throw(s, K.OIL, C[6] + Vector3(0.3, 0.3, 5.0))
		await _throw(s, K.FIRE, C[6] + Vector3(0.3, 1.0, 7.6))
		await _expect(s, Stage.State.CLEARED, "E7 기름 붓고 짚에 점화")

	if _want(7):
		# E8: 조명탄으로 보고, 차양 → 직격
		s = _new_stage(7)
		await physics_frame
		await _throw(s, K.FLARE, C[7] + Vector3(0, 0, 2))
		_check(s.state == Stage.State.PLAYING, "E8 조명탄은 파괴력이 없다")
		await _throw(s, K.FIRE, C[7] + Vector3(0, 2.9, 0))
		await _wait(s, 6.0)
		await _throw(s, K.FIRE, C[7] + Vector3(0, 1.8, 0), true)
		await _expect(s, Stage.State.CLEARED, "E8 밤 진지")

	if _want(8):
		# E9: 아주 먼 지휘관 (최대 사거리 가까이), 차양 → 직격
		s = _new_stage(8)
		await physics_frame
		await physics_frame
		var dist := Vector2(C[8].x, C[8].z).distance_to(Vector2(s.player.global_position.x, s.player.global_position.z))
		_check(reachable(s.player.throw_origin(), C[8] + Vector3(0, 2.9, 0), StageDefs.FIRE.throw_speed) and dist > 65.0, "E9 %.0fm 떨어진 지휘관이 사거리 안" % dist)
		await _throw(s, K.FIRE, C[8] + Vector3(0, 2.9, 0))
		await _wait(s, 6.5)
		await _throw(s, K.FIRE, C[8] + Vector3(0, 1.8, 0))
		await _expect(s, Stage.State.CLEARED, "E9 먼 지휘관")

	if _want(9):
		# E10: 나무다리를 고폭탄으로 끊는다
		s = _new_stage(9)
		await physics_frame
		await _throw(s, K.HE, StageDefs.E10_BRIDGE + Vector3(0, 0.45, 0))
		await _expect(s, Stage.State.CLEARED, "E10 다리 끊기")
		# E10: 마구간 정면만 태우면 전령은 그대로 도착한다
		s = _new_stage(9)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(15.5, 2.0, -35.0))
		await _expect(s, Stage.State.FAILED, "E10 마구간만 태움 → 전령 도착", 60.0, "fail_messenger")
	if _want(10):
		# E11: 방패병(화염) → 바리케이드(고폭) → 석재 울타리(고폭, 살짝 빗나가도) → 성문 앞 폭발통(화염)
		s = _new_stage(10)
		await physics_frame
		var pts: Array = StageDefs.E11_PATH
		await _throw(s, K.FIRE, StageDefs._along(pts, 12.0) + Vector3(0, 0.5, 0))
		await _throw(s, K.HE, StageDefs._along(pts, 22.0) + Vector3(0, 0.7, 0.3))
		await _throw(s, K.HE, StageDefs._along(pts, 32.0) + Vector3(1.2, 0.0, 0.8))
		var ally: Ally = s.allies[0]
		var t := 0.0
		while not ally.at_gate and t < 60.0:
			await physics_frame
			t += 1.0 / 60.0
		_check(ally.at_gate, "E11 동료가 성문 앞에 도착 (%.1f초)" % t)
		await _throw(s, K.FIRE, ally.global_position + Vector3(0, 1.0, 0.5))
		await _expect(s, Stage.State.CLEARED, "E11 폭발통으로 성문 붕괴")
		var steel_gone := 0
		var stone_fell := 0
		for blk in s.structures[0].blocks:
			if blk.mat == Block.Mat.STEEL and blk.fallen:
				steel_gone += 1
			if blk.mat == Block.Mat.STONE and blk.fallen:
				stone_fell += 1
		_check(steel_gone >= 5 and stone_fell == 0, "E11 폭발통에 강철 문과 초소가 날아가고 흰 석재 기둥은 남는다 (강철 %d개, 석재 %d개)" % [steel_gone, stone_fell])
		# 성문은 플레이어의 고폭탄으로는 부서지지 않는다
		s = _new_stage(10)
		await physics_frame
		for i in 3:
			await _throw(s, K.HE, Vector3(0, 2.0, -59.0))
		await _wait(s, 4.0)
		var gate_ok := true
		for blk in s.structures[0].blocks:
			if blk.fallen:
				gate_ok = false
		_check(gate_ok and s.state == Stage.State.PLAYING, "E11 고폭탄 3발에도 성문과 초소가 버틴다")
		# 길을 열지 않으면 동료는 방패병 앞에서 기다린다
		s = _new_stage(10)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(20, 0, -20))
		await _wait(s, 15.0)
		ally = s.allies[0]
		_check(ally.blocked() and not ally.at_gate, "E11 막힌 동료는 멈춰 기다린다")

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
