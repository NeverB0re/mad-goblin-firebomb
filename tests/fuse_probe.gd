extends "res://tests/campaign_test.gd"
## 디버그용: 1-9 도화선의 각 조각(끝 → 화약통 순)에 불을 붙여 화약통이 터지는지 본다. 인자: -- <진지>


func _run() -> void:
	var idx := int(OS.get_cmdline_user_args()[0])
	for pick in [0, 3, 5, 10]:
		var s := _campaign(idx)
		await physics_frame
		var ropes := []
		for st in s.structures:
			for b in st.blocks:
				if b.mat == Block.Mat.ROPE:
					ropes.append(b)
		ropes.sort_custom(func(a, b): return a.position.z > b.position.z)
		print("로프 ", ropes.size(), "개 pick ", pick)
		if pick == 5:
			for r in ropes:
				r.drop(Vector3(0.3, 1.0, 0.2) * r.mass * 3.0)
			await _wait(s, 0.6)
		ropes[pick].ignite()
		var kegs := 0
		for st in s.structures:
			for b in st.blocks:
				if b.mat == Block.Mat.KEG:
					kegs += 1
		await _wait(s, 15.0)
		var left := 0
		var rope_left := 0
		for st in s.structures:
			for b in st.blocks:
				if b.mat == Block.Mat.KEG:
					left += 1
				if b.mat == Block.Mat.ROPE:
					rope_left += 1
		print("  통 ", kegs, " → ", left, ", 로프 남음 ", rope_left)
	quit()
