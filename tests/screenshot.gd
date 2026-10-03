extends SceneTree
## 렌더링 확인용: 각 스테이지를 띄우고 한 발 던진 뒤 화면을 저장한다 (창 모드로 실행).
## 실행: Godot --path . --script res://tests/screenshot.gd

const StageTest := preload("res://tests/stage_test.gd")
const SHOTS := [
	[0, Vector3(0, 2.7, -48.5), 3.2],
	[1, Vector3(0, 1.4, -63.6), 8.0],
	[2, Vector3(0, 12.6, -70.8), 5.2],
	[3, Vector3(-8, 0.9, -45), 2.5],
	[4, Vector3(0, 1.4, -63.6), 10.0],
	[5, Vector3(0.4, 0.5, -72.65), 7.5],
]


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var main := current_scene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	for shot in SHOTS:
		main.load_stage(shot[0])
		await _frames(10)
		var s: Stage = main.stage
		var v := s.current_ammo().throw_speed
		for i in 4:
			var dir := StageTest.aim(s.player.throw_origin(), shot[1], v)
			s.player.look_at_angles(atan2(-dir.x, -dir.z), asin(dir.y))
		s.player.winding = true
		await _frames(20)
		root.get_texture().get_image().save_png("res://tests/out/stage%d_a.png" % shot[0])
		s.player.winding = false
		s.try_throw(s.player.throw_origin(), s.player.throw_direction())
		# 목표 쪽으로 시선을 낮춰 결과를 본다
		var to_target: Vector3 = shot[1] - s.player.head.global_position
		s.player.look_at_angles(s.player.rotation.y, atan2(to_target.y, Vector2(to_target.x, to_target.z).length()))
		var t := 0.0
		while t < shot[2]:
			await process_frame
			t += main.get_process_delta_time()
		root.get_texture().get_image().save_png("res://tests/out/stage%d_b.png" % shot[0])
	quit()
