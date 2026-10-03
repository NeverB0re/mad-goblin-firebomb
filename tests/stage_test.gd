extends SceneTree
## 스테이지 실행 테스트: 각 스테이지를 실제 플레이어 투척 경로로 풀어 보고 클리어/실패 판정과
## 재시작 시간을 확인한다.
## 실행: Godot --headless --fixed-fps 60 --script res://tests/stage_test.gd

const G := 9.8
const MAX_TIME := 50.0
const D := StageDefs.DIST

var _failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		_failures += 1
		print("  FAIL ", msg)


## 낮은 포물선으로 target에 닿는 방향.
static func aim(origin: Vector3, target: Vector3, v: float) -> Vector3:
	var flat := Vector2(target.x - origin.x, target.z - origin.z)
	var x := flat.length()
	var y := target.y - origin.y
	var disc := v * v * v * v - G * (G * x * x + 2.0 * y * v * v)
	var theta := atan((v * v - sqrt(maxf(disc, 0.0))) / (G * x))
	var h := flat.normalized()
	return Vector3(h.x * cos(theta), sin(theta), h.y * cos(theta)).normalized()


static func flight_time(origin: Vector3, target: Vector3, dir: Vector3, v: float) -> float:
	var x := Vector2(target.x - origin.x, target.z - origin.z).length()
	# 비행 시계 배율만큼 실제 시간은 더 걸린다
	return x / (v * Vector2(dir.x, dir.z).length()) / Projectile.FLIGHT_TIME_SCALE


func _point_player(stage: Stage, target: Vector3) -> void:
	var v := stage.current_ammo().throw_speed
	for i in 4:
		var dir := aim(stage.player.throw_origin(), target, v)
		stage.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))


func _throw_at(stage: Stage, target: Vector3) -> bool:
	_point_player(stage, target)
	return stage.try_throw(stage.player.throw_origin(), stage.player.throw_direction())


func _wait(stage: Stage, seconds: float) -> void:
	var t := 0.0
	while t < seconds and stage.state == Stage.State.PLAYING:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _new_stage(index: int) -> Stage:
	for c in root.get_children():
		if c is Stage:
			root.remove_child(c)
			c.queue_free()
	var t0 := Time.get_ticks_usec()
	var stage := Stage.new()
	root.add_child(stage)
	StageDefs.build(index, stage)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(ms < 1000.0, "%s 생성 %.1fms (1초 이내)" % [StageDefs.NAMES[index], ms])
	return stage


func _expect(stage: Stage, want: int, label: String, limit := MAX_TIME) -> void:
	var t0 := stage.elapsed
	while stage.state == Stage.State.PLAYING and stage.elapsed - t0 < limit:
		await physics_frame
	var names := ["진행 중", "클리어", "실패"]
	_check(stage.state == want, "%s → %s (투척 %d회, %.1f초)" % [label, names[stage.state], stage.throws, stage.elapsed])


func _run() -> void:
	print("== 스테이지 테스트 ==")
	Engine.max_fps = 0
	preload("res://scripts/main.gd").register_input()
	var s: Stage

	# T1: 창고 앞 도리를 맞힌다
	s = _new_stage(0)
	await physics_frame
	_throw_at(s, Vector3(0, 2.7, -D[0] + 1.5))
	await _expect(s, Stage.State.CLEARED, "T1 창고 위쪽 명중")

	# T1 실패: 전부 20m 앞에 던진다
	s = _new_stage(0)
	await physics_frame
	for i in 5:
		_throw_at(s, Vector3(0, 0, -D[0] + 20.0))
		await _wait(s, 0.7)
	await _expect(s, Stage.State.FAILED, "T1 전부 빗나감")

	# T2: 앞쪽 가로대를 태워 두 기둥에 불을 옮긴다
	s = _new_stage(1)
	await physics_frame
	_throw_at(s, Vector3(0, 1.4, -D[1] + 1.4))
	await _expect(s, Stage.State.CLEARED, "T2 가로대 점화")

	# T2: 석재만 맞히면 무너지지 않는다
	s = _new_stage(1)
	await physics_frame
	for i in 5:
		_throw_at(s, Vector3(0, 8.5, -D[1] + 1.8))
		await _wait(s, 0.7)
	await _expect(s, Stage.State.FAILED, "T2 석재만 명중")

	# T3: 밧줄의 어느 높이를 맞혀도 추가 떨어져 코어를 쳐내야 한다
	for y in [13.8, 13.0, 12.2, 11.4, 10.8]:
		s = _new_stage(2)
		await physics_frame
		_throw_at(s, Vector3(0, y, -D[2] - 0.8))
		await _expect(s, Stage.State.CLEARED, "T3 밧줄 y=%.1f 명중" % y)
	s = _new_stage(2)
	await physics_frame
	_throw_at(s, Vector3(0, 11.2, -D[2] - 0.05))
	await _expect(s, Stage.State.CLEARED, "T3 추 앞면 명중")

	# T3: 벽만 맞히면 무너지지 않는다
	s = _new_stage(2)
	await physics_frame
	for i in 4:
		_throw_at(s, Vector3(0, 4.0, -D[2] + 0.55))
		await _wait(s, 0.7)
	await _expect(s, Stage.State.FAILED, "T3 벽만 명중")

	# T4: 적의 이동을 예측해 앞에 던진다
	s = _new_stage(3)
	await physics_frame
	var e: Enemy = s.enemies[0]
	var curve := e.follow.get_parent().curve as Curve3D
	var from := curve.get_point_position(0)
	var to := curve.get_point_position(1)
	var run_dir := (to - from).normalized()
	var lead_t := 2.0
	var target := from
	for i in 6:
		target = from + run_dir * e.speed * lead_t + Vector3(0, 0.9, 0)
		var dir := aim(s.player.throw_origin(), target, 40.0)
		lead_t = flight_time(s.player.throw_origin(), target, dir, 40.0)
	_throw_at(s, target)
	await _expect(s, Stage.State.CLEARED, "T4 예측 투척")

	# T4: 적이 지금 있는 곳에 던지면 놓친다
	s = _new_stage(3)
	await physics_frame
	e = s.enemies[0]
	for i in 6:
		_throw_at(s, e.global_position + Vector3(0, 0.9, 0) - run_dir * 3.0)
		await _wait(s, 1.0)
	await _expect(s, Stage.State.FAILED, "T4 뒤쪽 투척")

	# T5: 중량 화염병으로 같은 가로대
	s = _new_stage(4)
	await physics_frame
	_throw_at(s, Vector3(0, 1.4, -D[4] + 1.4))
	await _expect(s, Stage.State.CLEARED, "T5 중량 가로대 점화")

	# T6: 화약통
	s = _new_stage(5)
	await physics_frame
	_throw_at(s, Vector3(0.4, 0.5, -D[5] + 2.35))
	await _expect(s, Stage.State.CLEARED, "T6 화약통 기본탄")

	s = _new_stage(5)
	await physics_frame
	s.select_slot(1)
	_check(s.current_ammo().display_name == "중량 화염병", "T6 탄종 교체")
	_throw_at(s, Vector3(0.4, 0.5, -D[5] + 2.35))
	await _expect(s, Stage.State.CLEARED, "T6 화약통 중량탄")

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
