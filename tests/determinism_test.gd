extends SceneTree
## 결정성 테스트: 같은 위치와 각도에서 20번 던져 착탄점이 같은지 확인한다.
## 실행: Godot --headless --fixed-fps 60 --script res://tests/determinism_test.gd

const THROWS := 20

var _failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS ", msg)
	else:
		_failures += 1
		print("  FAIL ", msg)


func _make_box(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)


func _throw(world: Node3D, origin: Vector3, dir: Vector3, ammo: AmmoType) -> Vector3:
	var p := Projectile.new()
	world.add_child(p)
	p.launch(origin, dir, ammo)
	var result := [null]
	p.impacted.connect(func(_p, pos, _n, _c): result[0] = pos)
	while result[0] == null:
		await physics_frame
	return result[0]


func _run() -> void:
	print("== 결정성 테스트 ==")
	var world := Node3D.new()
	root.add_child(world)
	_make_box(world, Vector3(0, -0.5, 0), Vector3(800, 1, 800))
	_make_box(world, Vector3(0, 3, -70), Vector3(10, 6, 1))
	await physics_frame
	await physics_frame

	var basic: AmmoType = load("res://ammo/fire.tres")
	var heavy: AmmoType = load("res://ammo/he.tres")
	var origin := Vector3(0.3, 1.6, -0.6)

	for ammo in [basic, heavy]:
		var dir := Vector3(0.05, 0.2, -1.0).normalized()
		var first: Vector3 = await _throw(world, origin, dir, ammo)
		var same := true
		for i in THROWS - 1:
			var p: Vector3 = await _throw(world, origin, dir, ammo)
			if p != first:
				same = false
				print("    차이: ", p, " vs ", first)
		_check(same, "%s %d회 투척 착탄점 동일 %s" % [ammo.display_name, THROWS, first])

	# 평지 45도 사거리가 기획서 수치(공기 저항 없음)와 맞는지 확인
	for pair in [[basic, basic.throw_speed * basic.throw_speed / 9.8], [heavy, heavy.throw_speed * heavy.throw_speed / 9.8]]:
		var ammo: AmmoType = pair[0]
		var dir := Vector3(0, 1, -1).normalized()
		var hit: Vector3 = await _throw(world, Vector3(20, 0.001, 0), dir, ammo)
		var dist := Vector2(hit.x - 20, hit.z).length()
		_check(absf(dist - pair[1]) < 1.0, "%s 45도 사거리 %.1fm (기대 %.1fm)" % [ammo.display_name, dist, pair[1]])

	# 탄종이 다르면 같은 겨냥으로 다른 곳에 떨어진다
	var d2 := Vector3(0, 0.8, -1).normalized()
	var a: Vector3 = await _throw(world, Vector3(-20, 1.6, 0), d2, basic)
	var b: Vector3 = await _throw(world, Vector3(-20, 1.6, 0), d2, heavy)
	_check(a.distance_to(b) > 10.0, "화염탄/고폭탄 같은 겨냥 착탄 차이 %.1fm" % a.distance_to(b))

	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
