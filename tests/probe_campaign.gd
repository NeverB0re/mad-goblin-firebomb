extends "res://tests/campaign_test.gd"
## 디버그용: 본편 진지 하나의 풀이를 던지고 블록 상태를 시간마다 찍는다. 인자: -- <진지 번호(0부터)> [초]


func _run() -> void:
	preload("res://scripts/main.gd").register_input()
	var args := OS.get_cmdline_user_args()
	var i := int(args[0])
	var secs := float(args[1]) if args.size() > 1 else 12.0
	var s := _campaign(i)
	await physics_frame
	for step in Campaign.plan(i):
		if step[0] is String:
			continue
		var target: Vector3 = s.commanders[step[1]].global_position + Vector3(0, 1.2, 0) if step[1] is int else step[1]
		await _throw_plan(s, step[0], target, step[2])
		if step[3] > 0.0:
			await _wait(s, step[3])
	var t := 0.0
	while t < secs:
		for f in 60:
			await physics_frame
		t += 1.0
		Engine.time_scale = 1.0
		var line := "t=%.0f " % s.elapsed
		for st in s.structures:
			for b in st.blocks:
				if b.burning or b.fallen or b.health < 1.0 or b.mat in [Block.Mat.ROPE, Block.Mat.WEIGHT]:
					line += "%s%s%s%s hp%.1f | " % [Block.Mat.keys()[b.mat], b.global_position.snapped(Vector3.ONE * 0.1), " 탐" if b.burning else "", " 떨어짐" if b.fallen else "", b.health]
		for c in s.commanders:
			line += " 지휘관 dead=%s %s" % [c.dead, c.defeat_cause]
		print(line)
	quit()
