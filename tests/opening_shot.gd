extends SceneTree
## 오프닝 컷만화 확인 (창 모드): 컷을 하나씩 열며 화면을 저장하고, 끝까지 넘기면 finished가 오는지 확인한다.
## 실행: Godot --path . --script res://tests/opening_shot.gd

var _failures := 0


func _initialize() -> void:
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
	for i in range(1, Opening.PANEL_COUNT):
		opening.reveal_next()
		await _frames(30)
	await _frames(60)
	root.get_texture().get_image().save_png("res://tests/out/opening_page.png")
	opening.reveal_next()
	await _frames(40)
	print("  ", "PASS" if done[0] else "FAIL", " 6컷 뒤 클릭하면 오프닝 종료")
	if not done[0]:
		_failures += 1
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
