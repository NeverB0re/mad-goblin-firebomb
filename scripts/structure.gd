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
	## 충격에 닳은 부재도 약해진다.
	func effective_strength() -> float:
		var h := minf(a.health, a.integrity)
		if b:
			h = minf(h, minf(b.health, b.integrity))
		return strength * maxf(h, 0.05)

	## 흰 석재끼리(또는 석재와 땅)의 연결은 무엇으로도 끊기지 않는다.
	## 강철이 낀 연결은 큰 폭발(explosive)에만 끊긴다.
	func unbreakable(explosive := false) -> bool:
		if a.mat == Block.Mat.STONE and (b == null or b.mat == Block.Mat.STONE):
			return true
		var steel := a.mat == Block.Mat.STEEL or (b != null and b.mat == Block.Mat.STEEL)
		return steel and not explosive


var blocks: Array[Block] = []
var joints: Array[Joint] = []
var stage: Node
## finalize 시점의 블록 수 (봉화대처럼 '절반 이상 남았는지'를 볼 때 쓴다)
var initial_count := 0
## 플레이어의 투척으로는 부서지지 않는다 (E11 성문: 동료의 폭발통으로만). 강제 충격만 받는다
var player_proof := false
## 다리 묶음: [{legs: Array[Block], max_lost: int, done: bool}]. 다리를 max_lost개보다 많이 잃으면
## 땅에서 떠 있는 블록 전체(남은 다리 포함)가 잃은 다리 쪽으로 한 몸처럼 기울어 넘어간다.
var leg_groups: Array = []

## 기울어 넘어가는 빠르기 (rad/s)
const TOPPLE_SPIN := 0.9


## 다리 묶음을 등록한다. 나무 다리 넷은 max_lost 1 (둘 잃으면 넘어감), 금 간 석재 기둥은 0 (하나만 잃어도 넘어감).
func add_leg_group(legs: Array, max_lost: int) -> void:
	var pos := []
	for b in legs:
		pos.append(b.position)
	leg_groups.append({"legs": legs, "pos": pos, "max_lost": max_lost, "done": false})


## 다리를 잃었는지 (다 타서 지워졌거나, 부서져 떨어졌거나).
static func _leg_lost(b) -> bool:
	return not is_instance_valid(b) or b.fallen or b.burnt


## 다리를 너무 많이 잃은 묶음이 있으면 잃은 다리 쪽으로 기울여 넘어뜨린다.
func _check_leg_groups() -> bool:
	var toppled := false
	for g in leg_groups:
		if g.done:
			continue
		var lost := []
		for k in g.legs.size():
			if _leg_lost(g.legs[k]):
				lost.append(k)
		if lost.size() <= g.max_lost:
			continue
		g.done = true
		toppled = true
		var all_c := Vector3.ZERO
		for p in g.pos:
			all_c += p
		all_c /= g.pos.size()
		var lost_c := Vector3.ZERO
		for k in lost:
			lost_c += g.pos[k]
		lost_c /= lost.size()
		var dir := Vector3(lost_c.x - all_c.x, 0, lost_c.z - all_c.z)
		if dir.length() < 0.05:
			dir = Vector3(1, 0, 0)
		dir = dir.normalized()
		# 잃은 다리 쪽 땅을 축으로 돈다: 높은 곳일수록 그쪽으로 빨리 기운다
		var pivot := Vector3(lost_c.x, 0.0, lost_c.z)
		var spin := Vector3.UP.cross(dir) * TOPPLE_SPIN
		for b in blocks:
			if (b.fallen and not b.freeze) or (b.start_low < 0.05 and not (b in g.legs)):
				continue
			for j in b.joints:
				j.broken = true
			b.topple(spin.cross(b.position - pivot), spin)
	return toppled


func add_block(mat: int, center: Vector3, size: Vector3) -> Block:
	# 부품을 키워 짓는 중이면 자리와 크기를 함께 키운다 (Stage.build_scale)
	if stage:
		center = stage.at(center)
		size *= stage.build_scale
	var b := Block.new().setup(mat, size, center)
	b.structure = self
	add_child(b)
	blocks.append(b)
	return b


## 맞닿은 블록을 찾아 연결과 이웃(불 번짐) 목록을 만든다.
func finalize() -> void:
	initial_count = blocks.size()
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
## 충격파는 거리에 따라 약해진다: 반경 안에서 연결 강도를 넘는 곳은 끊고, 끊기지 않은 닳는 재질(나무·금 간 석벽)은
## 반경의 WEAR_REACH배 거리까지 금이 커져 다음 충격에 쉽게 부서진다. 살짝 빗나가도 조금은 부서진다.
## (이번 충격의 끊김 판정이 끝난 뒤에 닳게 해서, 한 발로 끊기는 범위는 반경 그대로 예측 가능하다)
## explosive: 화약통·폭발통·미사일 같은 큰 폭발 (강철판도 날린다).
func apply_impact(pos: Vector3, radius: float, strength: float, forced := false, explosive := false) -> int:
	# 진지를 치운 뒤에 예약돼 있던 폭발이 터지는 경우
	if not is_inside_tree():
		return 0
	if player_proof and not forced:
		return 0
	var reach := radius * WEAR_REACH
	var wear := {}
	for b in blocks:
		if b.fallen:
			continue
		var bd := b.distance_to_point(pos)
		# 범위 안 블록은 끊기지 않아도 번쩍이며 흔들린다
		if bd < radius * 1.3:
			b.hit_react(strength * (1.0 - bd / (radius * 1.3)) / 40.0, pos)
		if bd < reach and b.mat in Block.WEARS:
			wear[b] = strength * (1.0 - bd / reach) / b.joint_strength() * WEAR_K
	var broken := 0
	var hit_blocks := {}
	for j in joints:
		if j.broken or j.unbreakable(explosive):
			continue
		var d := j.pos.distance_to(pos)
		if d >= radius:
			continue
		var dmg := strength * (1.0 - d / radius)
		if dmg >= j.effective_strength():
			j.broken = true
			broken += 1
			# 블록 자체 강도(닳은 만큼 약해짐) 이상의 충격을 받은 블록만 부서질 후보 (불에 약해진 이웃 때문에 끊긴 건 제외)
			if dmg >= j.a.joint_strength() * j.a.integrity:
				hit_blocks[j.a] = true
			if j.b and dmg >= j.b.joint_strength() * j.b.integrity:
				hit_blocks[j.b] = true
	if broken > 0:
		# 충격에 직접 끊긴 작은 석재 블록은 그 자리에서 산산조각 난다 (밀려나 끼어 버티지 않게)
		for b in hit_blocks:
			if b.mat in SHATTER_MATS and b.size.x * b.size.y * b.size.z <= SHATTER_VOLUME and not b.fallen:
				_shatter(b)
		resolve(pos, strength, radius)
	for b in wear:
		if is_instance_valid(b) and not b.fallen:
			var before: float = b.integrity
			b.wear(wear[b])
			if before - b.integrity > 0.15 and stage and stage.has_method("on_block_chipped"):
				stage.on_block_chipped(b)
	return broken


const SHATTER_MATS := [Block.Mat.CRACKED]
## 닳게 하는 충격이 닿는 거리 (충격 반경의 배수)와 닳는 정도
const WEAR_REACH := 1.6
const WEAR_K := 0.3
const SHATTER_VOLUME := 3.5


func _shatter(b: Block) -> void:
	if stage and stage.has_method("on_block_shattered"):
		stage.on_block_shattered(b)
	for j in b.joints:
		j.broken = true
	b.fallen = true
	blocks.erase(b)
	b.remove_from_group("blocks")
	b.queue_free()


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
	if _check_leg_groups():
		dropped += 1
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
	# 매달린 쇳덩이(종, 쇠 상자)는 밧줄이 끊기면 폭발에 밀리지 않고 곧장 아래로 떨어진다 (밑의 표적을 노리는 장치)
	if origin != Vector3.INF and radius > 0.0 and b.mat != Block.Mat.WEIGHT:
		# 충격으로 떨어지는 블록은 착탄점 반대쪽으로 과장되게 튕겨 나가며 위로 솟고 회전한다
		var d := b.global_position.distance_to(origin)
		if d < radius * 1.5:
			var away := b.global_position - origin
			var flat := Vector3(away.x, 0.0, away.z)
			# 위에 무언가를 받치던 블록은 위로 튀지 않게 한다 (위 블록에 끼어 멈추지 않도록)
			var lift := 0.0 if _carries_load(b) else 0.5
			var dir := (away.normalized() * 0.4 + flat.normalized() * 1.2 + Vector3.UP * lift).normalized()
			var falloff := 1.0 - d / (radius * 1.5)
			# 가벼운 판자는 크게 튕기고 무거운 석재나 추는 덜 밀린다
			impulse = dir * minf(strength * 0.35 * falloff, b.mass * 14.0)
	b.drop(impulse)


func _carries_load(b: Block) -> bool:
	for j in b.joints:
		if j.upper != null and j.upper != b:
			return true
	return false


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
