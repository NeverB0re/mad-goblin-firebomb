extends SceneTree
## 입력 테스트 (창 모드): 실제 메인 씬에 마우스 이동·클릭 이벤트를 넣어 시점 회전과 투척이 되는지 확인한다.
## 실행: Godot --path . --script res://tests/input_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	print("  ", "PASS " if cond else "FAIL ", msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("== 입력 테스트 ==")
	preload("res://scripts/main.gd").show_opening = false
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	var stage: Stage = main.stage
	var player := stage.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(2)
	var center := root.get_visible_rect().size * 0.5

	var yaw0 := player.rotation.y
	var pitch0 := player.pitch
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.relative = Vector2(120, -80)
	root.push_input(motion)
	await _frames(2)
	_check(not is_equal_approx(player.rotation.y, yaw0), "마우스 좌우 이동 → 시점 회전 (%.3f → %.3f)" % [yaw0, player.rotation.y])
	_check(player.pitch > pitch0, "마우스 위로 이동 → 시선 올라감 (%.3f → %.3f)" % [pitch0, player.pitch])

	var ammo0 := stage.total_ammo()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = center
	root.push_input(click)
	await _frames(10)
	_check(player.winding and stage.total_ammo() == ammo0, "좌클릭 누름 → 준비 자세, 아직 안 던짐")
	var release := click.duplicate()
	release.pressed = false
	root.push_input(release)
	await _frames(2)
	_check(not player.winding and stage.total_ammo() == ammo0 - 1, "좌클릭 뗌 → 투척 (탄약 %d → %d)" % [ammo0, stage.total_ammo()])
	# 20m 이상 날아가면 추적 화면이 켜진다
	var shown := false
	for i in 90:
		await process_frame
		shown = shown or main.hud.follow_cam.visible
	_check(shown, "투척 후 추적 화면 표시")

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
