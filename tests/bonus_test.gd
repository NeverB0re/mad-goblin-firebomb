extends "res://tests/campaign_test.gd"
## 보조 목표 테스트: 바꾼 보조 목표(창문, 직격 n명, 아군 돕기, 쾅쾅알 하나로 둘, 하늘쾅 한 발로 둘, 폭발통)를
## 보조 목표 풀이(Campaign.plan(i, true))로 실제로 던져서, 클리어하면서 보조 목표도 채우는지 본다.
## 인자: 진지 번호(0부터)를 주면 그 진지만. 실행: Godot --headless --fixed-fps 60 --script res://tests/bonus_test.gd


const NEW_KINDS := ["window", "ally", "he_two", "sky_two", "keg"]


func _bonus_play(i: int) -> void:
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
	for step in Campaign.plan(i, true):
		if s.state != Stage.State.PLAYING:
			break
		if step[0] is String:
			if step[0] == "button":
				_to_button(s)
				s.press_button()
			continue
		var target: Vector3
		if step[1] is int:
			target = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0)
		elif step[1] is String:
			var foe: Actor = Campaign._foes(s).filter(func(a): return a.has_meta(step[1]))[0]
			target = foe.chest()
		else:
			target = step[1]
		await _throw_plan(s, step[0], target, step[2])
		if step[3] > 0.0:
			await _wait(s, step[3])
	var t := 0.0
	while s.state == Stage.State.PLAYING and t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
	var ok := s.state == Stage.State.CLEARED and Campaign.bonus_met(i, s)
	_check(ok, "%s %s 보조 목표 「%s」 → %s, 보조 목표 %s (투척 %d회)" % [Campaign.label(i), Campaign.title(i), Campaign.bonus_text(i),
		Stage.State.keys()[s.state], "달성" if Campaign.bonus_met(i, s) else "못 함", s.throws])
	if not ok:
		for line in log:
			print("    ", line)
		for c in s.commanders:
			print("    지휘관 %s dead=%s %s 투척%d 창문투척%d" % [c.global_position.snapped(Vector3.ONE * 0.1), c.dead, c.defeat_cause, c.throw_id, c.get_meta("window_tid", -2)])


func _run() -> void:
	print("== 보조 목표 테스트 ==")
	Engine.max_fps = 0
	preload("res://scripts/main.gd").register_input()
	var args := OS.get_cmdline_user_args()
	var only := int(args[0]) if args.size() > 0 else -1
	for i in Campaign.COUNT:
		var b: Array = Campaign.bonus_of(i)
		var wanted: bool = b[0] in NEW_KINDS or Campaign.BONUS_PLAN.has(i)
		if (only < 0 and wanted) or only == i:
			await _bonus_play(i)
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
