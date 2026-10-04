extends SceneTree
## 오프닝 컷만화 확인 (창 모드): 컷을 하나씩 열며 화면을 저장하고, 끝까지 넘기면 finished가 오는지 확인한다.
## 실행: Godot --path . --script res://tests/opening_shot.gd

var _failures := 0


func _initialize() -> void:
	# 사용자가 하던 작업을 가리거나 포커스를 빼앗지 않게 창을 화면 밖에 두고 포커스를 받지 않는다
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("== 오프닝 테스트 ==")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	var opening := Opening.new()
	root.add_child(opening)
	var done := [false]
	opening.finished.connect(func(): done[0] = true)
	await _frames(40)
	for i in range(1, opening.panel_count()):
		opening.reveal_next()
		await _frames(30)
	await _frames(60)
	root.get_texture().get_image().save_png("res://tests/out/opening_page.png")
	opening.reveal_next()
	await _frames(40)
	print("  ", "PASS" if done[0] else "FAIL", " 6컷 뒤 클릭하면 오프닝 종료")
	if not done[0]:
		_failures += 1
	# 엔딩 컷만화
	var ending := Opening.new(Opening.Mode.ENDING)
	root.add_child(ending)
	await _frames(40)
	ending.reveal_next()
	await _frames(30)
	ending.reveal_next()
	await _frames(70)
	root.get_texture().get_image().save_png("res://tests/out/ending_page.png")
	print("  ", "PASS" if ending.panel_count() == 3 else "FAIL", " 엔딩 3컷")
	ending.finish()
	await _frames(30)
	# 월드 시작 컷 (5월드)
	for w in 5:
		var card := Opening.new(Opening.Mode.WORLD, w)
		root.add_child(card)
		await _frames(30)
		card.reveal_next()
		await _frames(40)
		root.get_texture().get_image().save_png("res://tests/out/world_%d.png" % (w + 1))
		card.finish()
		await _frames(25)
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
