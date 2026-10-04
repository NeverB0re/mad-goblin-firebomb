extends "res://tests/campaign_test.gd"
## 디버그용: 진지 하나에 한 발 던지고 블록 상태를 찍는다. 인자: -- <진지> <탄종> <x> <y> <z> (절대 좌표)


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	var a := OS.get_cmdline_user_args()
	var s := _campaign(int(a[0]))
	await physics_frame
	s.projectile_thrown.connect(func(p): p.impacted.connect(func(_p, pos, _n, col): print("impact ", pos, " ", col)))
	await _throw_plan(s, int(a[1]), Vector3(float(a[2]), float(a[3]), float(a[4])), false)
	for k in 6:
		await _wait(s, 0.5)
		Engine.time_scale = 1.0
		var line := "t=%.1f " % s.elapsed
		for st in s.structures:
			for b in st.blocks:
				line += "%s%s%s%s " % [Block.Mat.keys()[b.mat].left(2), b.global_position.snapped(Vector3.ONE * 0.1), "*" if b.burning else "", "F" if b.fallen else ""]
		print(line)
	quit()
