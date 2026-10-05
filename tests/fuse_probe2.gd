extends "res://tests/campaign_test.gd"
## 디버그용: 1-9에서 불항아리를 도화선 여러 곳에 던져 화약통이 터지는지 본다.


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	for cfg in [[6.7, -0.5, 0.1], [6.7, 0.5, 0.1], [6.7, 1.0, 0.1], [6.4, 0.0, 0.5], [6.4, 0.0, 1.5], [6.8, 0.0, 0.5]]:
		var zz: float = cfg[0]
		var s := _campaign(8)
		await physics_frame
		var c := Vector3(0, 0, -54)
		var target := Campaign.part_at(c, Vector3(Campaign.fort_fuse_x(c) + cfg[1], cfg[2], zz))
		s.projectile_thrown.connect(func(pr): pr.impacted.connect(func(_p, pos, _n, col): print("  impact ", pos, " ", col)))
		await _throw_plan(s, AmmoType.Kind.FIRE, target, false)
		for k in 7:
			await _wait(s, 2.0)
			var line := "  t=%.0f " % s.elapsed
			for st in s.structures:
				for b in st.blocks:
					if b.mat == Block.Mat.ROPE or b.mat == Block.Mat.KEG:
						line += "%s%.1f%s%s " % [Block.Mat.keys()[b.mat].left(1), b.position.z, "*" if b.burning else "", "F" if b.fallen else ""]
			print(line)
		var kegs := 0
		var ropes := 0
		for st in s.structures:
			for b in st.blocks:
				if b.mat == Block.Mat.KEG:
					kegs += 1
				if b.mat == Block.Mat.ROPE:
					ropes += 1
		print("cfg=", cfg, " 남은 통 ", kegs, " 남은 도화선 ", ropes, " 상태 ", s.state)
	quit()
