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


## 낮은 포물선으로 target에 닿는 방향. 닿을 수 없으면 45도.
static func aim(origin: Vector3, target: Vector3, v: float) -> Vector3:
	var flat := Vector2(target.x - origin.x, target.z - origin.z)
	var x := flat.length()
	var y := target.y - origin.y
	var disc := v * v * v * v - G * (G * x * x + 2.0 * y * v * v)
	var theta := atan((v * v - sqrt(maxf(disc, 0.0))) / (G * x)) if disc >= 0.0 else PI * 0.25
	var h := flat.normalized()
	return Vector3(h.x * cos(theta), sin(theta), h.y * cos(theta)).normalized()


static func reachable(origin: Vector3, target: Vector3, v: float) -> bool:
	var x := Vector2(target.x - origin.x, target.z - origin.z).length()
	var y := target.y - origin.y
	return v * v * v * v - G * (G * x * x + 2.0 * y * v * v) >= 0.0


static func flight_time(origin: Vector3, target: Vector3, dir: Vector3, v: float) -> float:
	var x := Vector2(target.x - origin.x, target.z - origin.z).length()
	return x / (v * Vector2(dir.x, dir.z).length()) / Projectile.FLIGHT_TIME_SCALE


func _select(s: Stage, kind: int) -> void:
	for i in s.ammo_slots.size():
		if s.ammo_slots[i].type.kind == kind:
			s.select_slot(i)
			return


func _point(s: Stage, target: Vector3) -> void:
	var v := s.current_ammo().throw_speed
	for i in 4:
		var dir := aim(s.player.throw_origin(), target, v)
		s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))


## 실제 입력 경로로 던진다: 와인드업 시작 → 바로 놓기 요청 → 손을 떠날 때까지 틱 진행.
func _throw(s: Stage, kind: int, target: Vector3) -> void:
	_select(s, kind)
	_point(s, target)
	var before := s.throws
	if not s.player.begin_windup():
		return
	s.player.request_release()
	var guard := 0
	while s.throws == before and guard < 120:
		await physics_frame
		guard += 1


func _wait(s: Stage, seconds: float) -> void:
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
	var why: String = s.fail_cause if s.state != Stage.State.CLEARED else ("지휘관: " + s.commander.defeat_cause)
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
		await _throw(s, K.FIRE, C[0] + Vector3(0, 1.8, 0))
		await _expect(s, Stage.State.CLEARED, "E1 차양 태우고 직격")
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
		# E3: 봉화대를 먼저 태우고 지휘관 (두 번째 풀이)
		s = _new_stage(2)
		await physics_frame
		var b: Vector3 = StageDefs.E3_RUN[1] + Vector3(2.0, 3.6, -1.5)
		await _throw(s, K.FIRE, b + Vector3(0, 0, 0.6))
		await _throw(s, K.FIRE, C[2] + Vector3(0, 2.9, 0))
		await _wait(s, 6.0)
		await _throw(s, K.FIRE, C[2] + Vector3(0, 1.8, 0))
		await _expect(s, Stage.State.CLEARED, "E3 봉화대 태우고 지휘관")
		# E3: 전령을 앞질러 맞힌다 (첫 번째 풀이)
		s = _new_stage(2)
		await physics_frame
		var m: Messenger = s.messengers[0]
		var from: Vector3 = StageDefs.E3_RUN[0]
		var to: Vector3 = StageDefs.E3_RUN[1]
		var run := (to - from).normalized()
		var lead := 2.0
		var tgt := from
		for i in 6:
			tgt = from + run * m.speed * (lead + 0.75) + Vector3(0, 0.9, 0)
			var dir := aim(s.player.throw_origin(), tgt, 30.0)
			lead = flight_time(s.player.throw_origin(), tgt, dir, 30.0)
		await _throw(s, K.FIRE, tgt)
		await _wait(s, 3.0)
		_check(m.dead, "E3 전령 예측 투척으로 쓰러뜨림")
		# E3: 아무것도 막지 않으면 전령이 도착해 실패
		s = _new_stage(2)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(-30, 0, -25))
		await _expect(s, Stage.State.FAILED, "E3 전령 방치", MAX_TIME, "fail_messenger")

	if _want(3):
		# E4: 고폭탄으로 강철벽 → 지휘관
		s = _new_stage(3)
		await physics_frame
		await _throw(s, K.HE, C[3] + Vector3(0, 1.5, 2.8))
		await _wait(s, 3.0)
		if s.state == Stage.State.PLAYING:
			await _throw(s, K.HE, C[3] + Vector3(0, 1.0, 0.2))
		await _expect(s, Stage.State.CLEARED, "E4 강철벽 날리고 직격")

	if _want(4):
		# E5: 화염탄은 강철벽에서 피식 꺼진다 → 고폭탄으로 벽 → 화염탄으로 초소
		s = _new_stage(4)
		await physics_frame
		await _throw(s, K.FIRE, C[4] + Vector3(0, 2.0, 4.7))
		await _wait(s, 3.0)
		var wall_ok := true
		for st in s.structures:
			for blk in st.blocks:
				if blk.mat == Block.Mat.STEEL and (blk.fallen or blk.burning):
					wall_ok = false
		_check(wall_ok and s.state == Stage.State.PLAYING, "E5 화염탄은 강철벽을 못 뚫는다")
		await _throw(s, K.HE, C[4] + Vector3(0, 1.5, 4.7))
		await _wait(s, 2.0)
		await _throw(s, K.FIRE, C[4] + Vector3(0, 2.9, 0))
		await _expect(s, Stage.State.CLEARED, "E5 벽 날리고 초소 태우기")

	if _want(5):
		# E6: 석재 기둥(고폭) + 목재 버팀목(화염) → 덮개에 깔림
		s = _new_stage(5)
		await physics_frame
		await _throw(s, K.HE, C[5] + Vector3(-2.4, 1.4, 2.0))
		await _wait(s, 2.0)
		_check(s.state == Stage.State.PLAYING, "E6 기둥 하나로는 덮개가 버틴다")
		await _throw(s, K.FIRE, C[5] + Vector3(2.4, 1.4, 1.85))
		await _expect(s, Stage.State.CLEARED, "E6 덮개 떨어뜨려 깔기")
		# 정면 난간 너머 직격은 막힌다
		s = _new_stage(5)
		await physics_frame
		for i in 3:
			await _throw(s, K.HE, C[5] + Vector3(0, 1.6, 3.2))
		await _wait(s, 3.0)
		_check(s.state == Stage.State.PLAYING, "E6 바위턱 정면 고폭탄 3발로는 지휘관이 무사 %s" % (s.commander.defeat_cause if s.commander.dead else ""))

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
		await _throw(s, K.FIRE, C[7] + Vector3(0, 1.8, 0))
		await _expect(s, Stage.State.CLEARED, "E8 밤 진지")

	if _want(8):
		# E9: 아래층에서는 닿지 않고, 위층으로 올라가면 닿는다
		s = _new_stage(8)
		await physics_frame
		await physics_frame
		_check(not reachable(s.player.throw_origin(), C[8] + Vector3(0, 2.9, 0), 30.0), "E9 아래층에서는 사거리 밖")
		s.player.change_floor(1)
		_check(not s.player.begin_windup(), "E9 오르는 동안 던질 수 없다")
		await _wait(s, Player.CLIMB_TIME + 0.3)
		_check(reachable(s.player.throw_origin(), C[8] + Vector3(0, 2.9, 0), 30.0), "E9 위층에서는 사거리 안")
		await _throw(s, K.FIRE, C[8] + Vector3(0, 2.9, 0))
		await _wait(s, 6.5)
		await _throw(s, K.FIRE, C[8] + Vector3(0, 1.8, 0))
		await _expect(s, Stage.State.CLEARED, "E9 위층에서 차양 → 직격")

	if _want(9):
		# E10: 기름통 줄 끝에 불 → 초소까지 (전령이 오기 전에)
		s = _new_stage(9)
		await physics_frame
		await _throw(s, K.FIRE, C[9] + Vector3(5.2, 0.8, 6.5))
		await _expect(s, Stage.State.CLEARED, "E10 기름통 줄 점화")
		# E10: 고폭탄으로 벽 → 화염탄으로 초소
		s = _new_stage(9)
		await physics_frame
		await _throw(s, K.HE, C[9] + Vector3(0, 1.5, 4.7))
		await _wait(s, 1.5)
		await _throw(s, K.FIRE, C[9] + Vector3(0.5, 2.9, 0))
		await _expect(s, Stage.State.CLEARED, "E10 벽 날리고 초소")

	if _want(10):
		# E11: 방패병(화염) → 바리케이드(고폭) → 그물(고폭) → 성문 앞 폭발통(화염)
		s = _new_stage(10)
		await physics_frame
		var pts: Array = StageDefs.E11_PATH
		await _throw(s, K.FIRE, StageDefs._along(pts, 12.0) + Vector3(0, 0.5, 0))
		await _throw(s, K.HE, StageDefs._along(pts, 22.0) + Vector3(0, 0.7, 0.3))
		await _throw(s, K.HE, StageDefs._along(pts, 32.0) + Vector3(0, 1.0, 0.3))
		var ally: Ally = s.allies[0]
		var t := 0.0
		while not ally.at_gate and t < 60.0:
			await physics_frame
			t += 1.0 / 60.0
		_check(ally.at_gate, "E11 동료가 성문 앞에 도착 (%.1f초)" % t)
		await _throw(s, K.FIRE, ally.global_position + Vector3(0, 1.0, 0.5))
		await _expect(s, Stage.State.CLEARED, "E11 폭발통으로 성문 붕괴")
		# 길을 열지 않으면 동료는 방패병 앞에서 기다린다
		s = _new_stage(10)
		await physics_frame
		await _throw(s, K.FIRE, Vector3(20, 0, -20))
		await _wait(s, 15.0)
		ally = s.allies[0]
		_check(ally.blocked() and not ally.at_gate, "E11 막힌 동료는 멈춰 기다린다")

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
