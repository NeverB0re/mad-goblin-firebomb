extends SceneTree
## 디버그용: 한 스테이지에 한 발 던지고 상태를 시간순으로 출력한다.
## 인자: -- <stage_index> <x> <y> <z> [slot]

const StageTest := preload("res://tests/stage_test.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	var args := OS.get_cmdline_user_args()
	var idx := int(args[0])
	var target := Vector3(float(args[1]), float(args[2]), float(args[3]))
	var slot := int(args[4]) if args.size() > 4 else 0
	var s := Stage.new()
	root.add_child(s)
	StageDefs.build(idx, s)
	await physics_frame
	s.select_slot(slot)
	var v := s.current_ammo().throw_speed
	for i in 4:
		var dir := StageTest.aim(s.player.throw_origin(), target, v)
		s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))
	for st in s.structures:
		for b in st.blocks:
			if b.mat in [Block.Mat.CORE, Block.Mat.ROPE, Block.Mat.WEIGHT, Block.Mat.KEG]:
				print("  block ", Block.Mat.keys()[b.mat], " pos ", b.position, " req ", b.required_below, " joints ", b.joints.size())
	var p_count := s.get_child_count()
	s.try_throw(s.player.throw_origin(), s.player.throw_direction())
	var proj: Projectile = s.get_child(p_count)
	proj.impacted.connect(func(_p, pos, _n, col): print("t=%.2f impact %s on %s" % [s.elapsed, pos, col]))
	var last := ""
	for f in 60 * 30:
		await physics_frame
		var burning := 0
		var fallen := 0
		var total := 0
		for st in s.structures:
			for b in st.blocks:
				total += 1
				if b.burning: burning += 1
				if b.fallen: fallen += 1
		var core_info := ""
		for c in get_nodes_in_group("core"):
			core_info = "core fallen=%s low=%.2f ground=%s frz=%s slp=%s v=%.2f" % [c.fallen, c.lowest_point(), c.touched_ground, c.freeze, c.sleeping, c.linear_velocity.y]
		var line := "burning=%d fallen=%d/%d %s state=%d" % [burning, fallen, total, core_info, s.state]
		if line != last:
			print("t=%.2f %s" % [s.elapsed, line])
			last = line
		if s.state != Stage.State.PLAYING:
			break
	quit()
