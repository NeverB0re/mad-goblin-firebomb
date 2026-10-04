extends SceneTree
## 디버그용: 스테이지 하나에 정해 둔 투척을 순서대로 하고 블록과 지휘관 상태를 출력한다.
## 인자: -- <stage_index> <kind> <x> <y> <z> [<kind> <x> <y> <z> ...]  (좌표는 지휘관 기준 상대 위치)

const StageTest := preload("res://tests/stage_test.gd")


func _initialize() -> void:
	_run()


func _dump(s: Stage, label: String) -> void:
	print("-- ", label, " t=%.1f state=%d" % [s.elapsed, s.state])
	for st in s.structures:
		for b in st.blocks:
			print("   %s pos=%s fallen=%s burning=%s hp=%.2f below=%d/%d frz=%s slp=%s v=%s" % [Block.Mat.keys()[b.mat], b.global_position.snapped(Vector3.ONE * 0.1), b.fallen, b.burning, b.health, st._count_below(b), b.required_below, b.freeze, b.sleeping, b.linear_velocity.snapped(Vector3.ONE * 0.01)])
	if s.commander:
		print("   commander dead=%s cause=%s pos=%s" % [s.commander.dead, s.commander.defeat_cause, s.commander.global_position.snapped(Vector3.ONE * 0.1)])


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	var args := OS.get_cmdline_user_args()
	var idx := int(args[0])
	var s := Stage.new()
	root.add_child(s)
	StageDefs.build(idx, s)
	await physics_frame
	var base: Vector3 = StageDefs.COMMANDER[idx]
	var test = StageTest.new()
	var i := 1
	while i + 3 < args.size() + 1 and i + 3 <= args.size() - 0:
		var kind := int(args[i])
		var target := base + Vector3(float(args[i + 1]), float(args[i + 2]), float(args[i + 3]))
		for slot in s.ammo_slots.size():
			if s.ammo_slots[slot].type.kind == kind:
				s.select_slot(slot)
		var v := s.current_ammo().throw_speed
		for k in 4:
			var dir := StageTest.aim(s.player.throw_origin(), target, v)
			s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))
		var n := s.get_child_count()
		s.try_throw(s.player.throw_origin(), s.player.throw_direction())
		var proj: Projectile = s.get_child(n)
		proj.impacted.connect(func(_p, pos, _n, col): print("impact %s on %s" % [pos.snapped(Vector3.ONE * 0.01), col]))
		for f in 60 * 4:
			await physics_frame
			if f in [1, 2, 3, 5, 10]:
				_dump(s, "frame %d" % f)
		Engine.time_scale = 1.0
		_dump(s, "after throw %d" % (i / 4 + 1))
		i += 4
	for f in 60 * 8:
		await physics_frame
	Engine.time_scale = 1.0
	_dump(s, "end")
	quit()
