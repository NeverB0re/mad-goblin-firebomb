class_name Structure
extends Node3D
## 블록과 연결 데이터(블록 쌍 + 강도). 블록 위치는 월드 좌표로 둔다 (Structure 자체는 원점).
## 연결이 끊기면 (1) 받침을 잃은 블록, (2) 지면과 이어지지 않은 블록 묶음만 freeze를 풀어 떨어뜨린다.

signal collapsed(position: Vector3, count: int)

const EPS := 0.03


class Joint:
	var a: Block
	var b: Block  # null = 지면
	var strength := 0.0
	var pos := Vector3.ZERO
	## 수직 받침이면 위에 얹힌 블록, 아니면 null
	var upper: Block
	var broken := false

	func other(x: Block) -> Block:
		return b if x == a else a

	## 불에 타는 부재는 점점 약해진다.
	func effective_strength() -> float:
		var h := a.health
		if b:
			h = minf(h, b.health)
		return strength * maxf(h, 0.05)


var blocks: Array[Block] = []
var joints: Array[Joint] = []
var stage: Node


func add_block(mat: int, center: Vector3, size: Vector3) -> Block:
	var b := Block.new().setup(mat, size, center)
	b.structure = self
	add_child(b)
	blocks.append(b)
	return b


## 맞닿은 블록을 찾아 연결과 이웃(불 번짐) 목록을 만든다.
func finalize() -> void:
	for i in blocks.size():
		var a := blocks[i]
		var amin := a.position - a.size * 0.5
		var amax := a.position + a.size * 0.5
		if absf(amin.y) <= EPS:
			_add_joint(a, null, Vector3(a.position.x, 0.0, a.position.z), a)
		for j in range(i + 1, blocks.size()):
			var b := blocks[j]
			var bmin := b.position - b.size * 0.5
			var bmax := b.position + b.size * 0.5
			var ov := Vector3(
				minf(amax.x, bmax.x) - maxf(amin.x, bmin.x),
				minf(amax.y, bmax.y) - maxf(amin.y, bmin.y),
				minf(amax.z, bmax.z) - maxf(amin.z, bmin.z))
			for axis in 3:
				var o1 := (axis + 1) % 3
				var o2 := (axis + 2) % 3
				if absf(ov[axis]) <= EPS and ov[o1] > 0.01 and ov[o2] > 0.01:
					var pos := Vector3.ZERO
					pos[axis] = (maxf(amin[axis], bmin[axis]) + minf(amax[axis], bmax[axis])) * 0.5
					pos[o1] = (maxf(amin[o1], bmin[o1]) + minf(amax[o1], bmax[o1])) * 0.5
					pos[o2] = (maxf(amin[o2], bmin[o2]) + minf(amax[o2], bmax[o2])) * 0.5
					var upper: Block = null
					if axis == 1:
						upper = a if a.position.y > b.position.y else b
					_add_joint(a, b, pos, upper)
					a.neighbors.append(b)
					b.neighbors.append(a)
					break
	for b in blocks:
		var initial := _count_below(b)
		b.required_below = 0 if b.hanging else int(ceil(initial * b.base_ratio() - 0.001))


func _add_joint(a: Block, b: Block, pos: Vector3, upper: Block) -> Joint:
	var j := Joint.new()
	j.a = a
	j.b = b
	j.pos = pos
	j.upper = upper
	j.strength = a.joint_strength() if b == null else minf(a.joint_strength(), b.joint_strength())
	joints.append(j)
	a.joints.append(j)
	if b:
		b.joints.append(j)
	return j


func set_joint_strength(a: Block, b: Block, strength: float) -> void:
	for j in a.joints:
		if j.other(a) == b:
			j.strength = strength


## 끊기지 않은 아래쪽 받침 수. 매달린 물체는 받침으로 치지 않는다.
func _count_below(b: Block) -> int:
	var n := 0
	for j in b.joints:
		if j.broken or j.upper != b:
			continue
		var lower: Block = j.other(b)
		if lower == null or not lower.hanging:
			n += 1
	return n


## 거리 감쇠 충격. 끊긴 연결 수를 돌려준다.
func apply_impact(pos: Vector3, radius: float, strength: float) -> int:
	var broken := 0
	for j in joints:
		if j.broken:
			continue
		var d := j.pos.distance_to(pos)
		if d >= radius:
			continue
		var dmg := strength * (1.0 - d / radius)
		if dmg >= j.effective_strength():
			j.broken = true
			broken += 1
	if broken > 0:
		resolve(pos, strength, radius)
	return broken


## 받침과 지면 연결을 다시 계산해서 버틸 수 없는 블록을 떨어뜨린다.
func resolve(origin := Vector3.INF, strength := 0.0, radius := 0.0) -> void:
	var dropped := 0
	var changed := true
	while changed:
		changed = false
		for b in blocks:
			if b.fallen or b.required_below == 0:
				continue
			if _count_below(b) < b.required_below:
				_drop(b, origin, strength, radius)
				dropped += 1
				changed = true
		# 지면과 이어진 블록 찾기
		var connected := {}
		var queue: Array[Block] = []
		for b in blocks:
			if b.fallen:
				continue
			for j in b.joints:
				if not j.broken and j.b == null:
					connected[b] = true
					queue.append(b)
					break
		while not queue.is_empty():
			var cur: Block = queue.pop_back()
			for j in cur.joints:
				if j.broken:
					continue
				var o: Block = j.other(cur)
				if o and not o.fallen and not connected.has(o):
					connected[o] = true
					queue.append(o)
		for b in blocks:
			if not b.fallen and not connected.has(b):
				_drop(b, origin, strength, radius)
				dropped += 1
				changed = true
	if dropped > 0:
		var center := origin if origin != Vector3.INF else global_position
		collapsed.emit(center, dropped)
	wake_fallen()


## 받침이 사라졌을 때 그 위에서 잠든 잔해가 공중에 떠 있지 않도록 깨운다.
func wake_fallen() -> void:
	for b in blocks:
		if b.fallen and is_instance_valid(b) and b.sleeping:
			b.sleeping = false


func _drop(b: Block, origin: Vector3, strength: float, radius: float) -> void:
	for j in b.joints:
		j.broken = true
	var impulse := Vector3.ZERO
	if origin != Vector3.INF and radius > 0.0:
		# 충격으로 떨어지는 블록은 착탄점 반대쪽으로 밀려난다 (속도 변화량 기준)
		var d := b.global_position.distance_to(origin)
		if d < radius * 1.5:
			# 가벼운 판자는 튕겨 나가고 무거운 석재나 추는 거의 밀리지 않는다
			var dir := (b.global_position - origin).normalized()
			var falloff := 1.0 - d / (radius * 1.5)
			impulse = dir * minf(strength * 0.15 * falloff, b.mass * 8.0)
	b.drop(impulse)


## 다 탄 블록은 끊어져 사라진다.
func on_block_burnt(b: Block) -> void:
	if stage and stage.has_method("on_block_burnt"):
		stage.on_block_burnt(b)
	for j in b.joints:
		j.broken = true
	b.fallen = true
	blocks.erase(b)
	b.remove_from_group("flammable")
	b.remove_from_group("blocks")
	b.queue_free()
	resolve()


func notify_heavy_landing(pos: Vector3, energy: float) -> void:
	if stage and stage.has_method("on_heavy_landing"):
		stage.on_heavy_landing(pos, energy)


func any_burning() -> bool:
	for b in blocks:
		if b.burning:
			return true
	return false


func any_moving() -> bool:
	for b in blocks:
		if b.fallen and is_instance_valid(b) and b.linear_velocity.length() > 0.4:
			return true
	return false
