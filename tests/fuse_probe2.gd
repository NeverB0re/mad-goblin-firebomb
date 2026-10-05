extends "res://tests/campaign_test.gd"
## 디버그용: 1-9에서 불항아리를 도화선 여러 곳에 던져 화약통이 터지는지 본다.


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	for zz in [3.0, 4.5, 6.0, 7.5, 9.0]:
		var s := _campaign(8)
		await physics_frame
		var c := Vector3(0, 0, -54)
		var target := Campaign.part_at(c, Vector3(Campaign.fort_fuse_x(c), 0.1, zz))
		await _throw_plan(s, AmmoType.Kind.FIRE, target, false)
		await _wait(s, 14.0)
		var kegs := 0
		var ropes := 0
		for st in s.structures:
			for b in st.blocks:
				if b.mat == Block.Mat.KEG:
					kegs += 1
				if b.mat == Block.Mat.ROPE:
					ropes += 1
		print("z=", zz, " 남은 통 ", kegs, " 남은 도화선 ", ropes, " 상태 ", s.state)
	quit()
