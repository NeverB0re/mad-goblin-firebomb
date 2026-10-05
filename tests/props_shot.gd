extends "res://tests/screenshot.gd"
## 전초기지 소품 확인용 (창 모드, 화면 밖): 소품 근처를 찍고, 소품에 폭탄을 던져 날아가는 모습을 찍는다.


func _run() -> void:
	preload("res://scripts/main.gd").show_opening = false
	preload("res://scripts/main.gd").test_mode = false
	SaveData.path = "user://test_save.cfg"
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	main.menus.hide_all()
	paused = false
	for i in [2, 14, 33]:
		main.load_stage(i)
		await _frames(10)
		var s: Stage = main.stage
		s.wind = Vector3.ZERO
		var props: Array = []
		for st in s.structures:
			if not st.blocks.is_empty() and st.get_index() > 0 and not st.blocks.any(func(b): return b.mat in [Block.Mat.STONE, Block.Mat.STEEL, Block.Mat.CRACKED, Block.Mat.KEG, Block.Mat.ROPE]):
				props.append(st)
		print(Campaign.label(i), " 소품 구조물 후보 ", props.size())
		if props.is_empty():
			continue
		var target: Vector3 = props[props.size() - 1].blocks[0].global_position
		main.hud.set_gameplay_visible(false)
		var cam := Camera3D.new()
		s.add_child(cam)
		cam.look_at_from_position(target + Vector3(5.0, 3.5, 6.0), target + Vector3(0, 0.6, 0))
		cam.current = true
		await _real_wait(main, 0.3)
		_save("props_%d" % i)
		_throw(s, AmmoType.Kind.HE if s.ammo_count(AmmoType.Kind.HE) > 0 else AmmoType.Kind.FIRE, target + Vector3(0, 0.5, 0))
		var t := 0.0
		while t < 6.0:
			await process_frame
			t += 1.0 / 60.0
			if s.get_children().all(func(n): return not (n is Projectile)):
				break
		await _real_wait(main, 0.25)
		_save("props_hit_%d" % i)
	quit()
