extends SceneTree
## 인물-건물 겹침 검사 (헤드리스): 50개 진지에서 지휘관·병사 몸(모델 전체)이 블록 속에 파묻히거나 머리가 천장을 뚫고 나오지 않는지.
## 인물 모델의 경계 상자와 블록 상자가 세 축 모두 GAP(m)보다 깊이 겹치면 실패. 인자로 월드 번호(1~5)를 주면 그 월드만.

const GAP := 0.04

var _failures := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	print("  ", "PASS " if cond else "FAIL ", msg)
	if not cond:
		_failures += 1


## 노드 아래 모든 메시의 전역 경계 상자
static func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _run() -> void:
	print("== 인물-건물 겹침 테스트 ==")
	var only := -1
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = int(args[0])
	for i in Campaign.COUNT:
		if only > 0 and Campaign.world_of(i) != only - 1:
			continue
		var s := Stage.new()
		root.add_child(s)
		Campaign.build(i, s)
		await physics_frame
		await physics_frame
		var bad := []
		var actors: Array = []
		actors.append_array(s.commanders)
		for n in s.find_children("*", "", true, false):
			if n is Actor and not n in actors:
				actors.append(n)
		for a in actors:
			var body := _bounds(a)
			if body.size == Vector3.ZERO:
				continue
			for b in s.get_tree().get_nodes_in_group("blocks"):
				var blk := b as Block
				if not is_instance_valid(blk) or not s.is_ancestor_of(blk):
					continue
				var bb := blk.global_transform * AABB(-blk.size * 0.5, blk.size)
				var inter := body.intersection(bb)
				if inter.size.x > GAP and inter.size.y > GAP and inter.size.z > GAP:
					bad.append("%s(%s) ↔ %s %s 겹침 %s" % [a.get_class() if a.get_script() == null else a.get_script().get_global_name(), str(a.global_position.snapped(Vector3.ONE * 0.1)), Block.Mat.keys()[blk.mat], str(blk.size), str(inter.size.snapped(Vector3.ONE * 0.01))])
		_check(bad.is_empty(), "%s 인물이 건물에 끼지 않는다%s" % [Campaign.label(i), "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))])
		s.queue_free()
		await process_frame
	print("결과: ", "OK" if _failures == 0 else "%d개 실패" % _failures)
	quit(0 if _failures == 0 else 1)
