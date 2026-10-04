class_name Block
extends RigidBody3D
## 건물 블록. 평소에는 freeze 상태로 서 있다가, 연결이 끊기거나 받침을 잃으면 떨어진다.
## 재질은 눈으로 보고 바로 알 수 있게 나눈다: 짚·나무 = 탄다, 금 간 석벽 = 고폭탄으로 부서진다,
## 반듯한 석재 = 고폭탄으로도 거의 안 부서진다 (화약통 정도만 통함), 강철 = 절대 부서지지 않는다.
## 가연물은 불이 붙으면 서서히 약해지다가(검게 변함) 다 타면 끊어져 사라진다.

enum Mat { WOOD_THIN, WOOD_BEAM, STONE, ROPE, STRAW, KEG, CORE, WEIGHT, STEEL, WOOD_WET, FUEL, CRACKED }

const CHAR_COLOR := Color(0.07, 0.06, 0.05)
## 떨어지는 블록이 다른 블록에 부딪힐 때의 충격 계수 (질량 × 속도 × K)
const IMPACT_K := 2.2

## joint: 연결 강도, ignite: 점화에 필요한 누적 열(초), burn: 다 타는 시간(초, -1 = 굵기로 계산)
## ratio: 처음 받침 수 중 몇 비율이 남아야 버티는지 (0 = 받침 규칙 없음)
const INFO := {
	Mat.WOOD_THIN: {"color": Color(0.5, 0.33, 0.19), "density": 0.6, "joint": 10.0, "flammable": true, "ignite": 0.4, "burn": 3.5, "ratio": 1.0},
	Mat.WOOD_BEAM: {"color": Color(0.32, 0.19, 0.1), "density": 0.7, "joint": 70.0, "flammable": true, "ignite": 0.8, "burn": -1.0, "ratio": 1.0},
	# 반듯한 석재: 고폭탄(최대 320)으로는 끊기지 않는다. 화약통·폭발통(450~500)만 통한다
	Mat.STONE: {"color": Color(0.74, 0.74, 0.76), "density": 2.4, "joint": 400.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
	Mat.ROPE: {"color": Color(0.84, 0.7, 0.42), "density": 0.5, "joint": 15.0, "flammable": true, "ignite": 0.3, "burn": 2.0, "ratio": 0.0},
	Mat.STRAW: {"color": Color(0.86, 0.7, 0.38), "density": 0.2, "joint": 5.0, "flammable": true, "ignite": 0.15, "burn": 2.0, "ratio": 1.0},
	Mat.KEG: {"color": Color(0.06, 0.06, 0.06), "density": 0.9, "joint": 30.0, "flammable": true, "ignite": 0.3, "burn": 0.8, "ratio": 1.0},
	Mat.CORE: {"color": Color(0.97, 0.74, 0.16), "density": 2.4, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 1.0},
	Mat.WEIGHT: {"color": Color(0.16, 0.16, 0.18), "density": 7.8, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.0},
	# 인간의 강철벽: 청회색, 반듯한 리벳. 무엇으로도 부서지지 않는다 (가림막)
	Mat.STEEL: {"color": Color(0.42, 0.5, 0.58), "density": 3.0, "joint": 99999.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
	# 젖은 목재: 그대로는 타지 않는다. 기름을 묻히면 탄다
	Mat.WOOD_WET: {"color": Color(0.26, 0.2, 0.17), "density": 0.8, "joint": 60.0, "flammable": true, "ignite": 0.6, "burn": 5.0, "ratio": 1.0},
	# 내부 연료 배관: 검정에 흰 띠. 빨리 타고, 다 타면 그 자리에서 불길이 확 솟는다
	Mat.FUEL: {"color": Color(0.08, 0.08, 0.08), "density": 1.0, "joint": 40.0, "flammable": true, "ignite": 0.25, "burn": 1.6, "ratio": 0.0},
	# 금 간 석벽: 누렇게 바랜 석재에 검은 균열. 고폭탄으로 부서지고, 근처에 맞아도 조금씩 금이 커진다
	Mat.CRACKED: {"color": Color(0.66, 0.62, 0.55), "density": 2.2, "joint": 110.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
}
## 근처 충격에 조금씩 약해지는(금이 커지는) 재질. 반듯한 석재와 강철은 닳지 않는다
const WEARS := [Mat.WOOD_THIN, Mat.WOOD_BEAM, Mat.ROPE, Mat.STRAW, Mat.WOOD_WET, Mat.CRACKED]

var mat: int = Mat.STONE
var size := Vector3.ONE
var structure: Node  # Structure
var joints: Array = []
var neighbors: Array[Block] = []
## 매달린 물체(밧줄, 추)는 받침 규칙을 쓰지 않고 연결만으로 버틴다.
var hanging := false
var support_ratio := -1.0
var required_below := 0
var health := 1.0
## 충격에 닳은 정도 (1 = 멀쩡함). 연결 강도에 곱해진다
var integrity := 1.0
var heat := 0.0
var burning := false
var burnt := false
var fallen := false
var touched_ground := false
## 처음 놓인 위치의 가장 낮은 높이
var start_low := 0.0
var burn_time := 8.0
var burn_rate := 1.0
## 기름이 묻었는지 (불이 빨리 붙고 빨리 약해진다)
var oiled := false

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _fire: GPUParticles3D
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _pending_impulse := Vector3.ZERO
var _box: BoxShape3D
var _impulse_delay := 0
var _burn_clock := 0.0
var _react := 0.0
var _react_dir := Vector3.ZERO


func setup(p_mat: int, p_size: Vector3, p_pos: Vector3) -> Block:
	mat = p_mat
	size = p_size
	position = p_pos
	start_low = p_pos.y - p_size.y * 0.5
	var info: Dictionary = INFO[mat]
	_base_color = info.color
	mass = maxf(0.05, size.x * size.y * size.z * info.density)
	burn_time = info.burn
	if burn_time < 0.0:
		# 목재는 굵기에 따라 약 3~8초 뒤 끊어진다 (기획서 초기값 8~20초에서 플레이 피드백으로 단축)
		var thick := minf(size.x, minf(size.y, size.z))
		burn_time = 3.0 + 5.0 * clampf((thick - 0.2) / 0.6, 0.0, 1.0)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 1
	collision_mask = 1
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.9
	pmat.bounce = 0.0
	physics_material_override = pmat
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_box = box
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_material.roughness = 0.95
	_mesh.material_override = _material
	add_child(_mesh)

	if mat == Mat.KEG or mat == Mat.FUEL:
		# 흰 띠를 두른 검은 통 / 배관
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color(0.95, 0.95, 0.95)
		for y in [-0.22, 0.22]:
			var band := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(size.x * 1.04, size.y * 0.1, size.z * 1.04)
			band.mesh = bb
			band.material_override = band_mat
			band.position = Vector3(0, size.y * y, 0)
			_mesh.add_child(band)

	if mat == Mat.STEEL:
		_add_rivets()
	elif mat == Mat.CRACKED:
		_add_cracks()

	add_to_group("blocks")
	if INFO[mat].flammable:
		add_to_group("flammable")
	return self


func is_flammable() -> bool:
	if mat == Mat.WOOD_WET:
		return oiled
	return INFO[mat].flammable


## 비에 젖은 목재로 바꾼다 (기름을 묻혀야 탄다).
## 비에 젖는다 (나무와 짚). 그대로는 타지 않고 기름을 묻혀야 탄다.
func make_wet() -> void:
	if not (mat in [Mat.WOOD_THIN, Mat.WOOD_BEAM, Mat.STRAW]):
		return
	mat = Mat.WOOD_WET
	_base_color = INFO[mat].color
	_material.albedo_color = _base_color
	burn_time = INFO[mat].burn


## 기름을 묻힌다. 젖은 목재도 탈 수 있게 되고, 불이 빨리 붙어 빨리 약해진다.
func coat_oil() -> void:
	if oiled or not INFO[mat].flammable:
		return
	oiled = true
	_base_color = _base_color.darkened(0.35)
	_material.albedo_color = _base_color
	_material.roughness = 0.15
	_material.metallic = 0.2


## 반듯하게 박힌 리벳 (큰 면 두 개에 격자로).
func _add_rivets() -> void:
	var rivet_mat := Models.mat(Color(0.28, 0.33, 0.38), 0.4, 0.7)
	var axis := 2 if size.z <= size.x else 0
	var u := 0 if axis == 2 else 2
	var nu := clampi(int(size[u] / 0.6), 1, 4)
	var nv := clampi(int(size.y / 0.6), 1, 3)
	for side in [-1.0, 1.0]:
		for i in nu:
			for j in nv:
				var p := Vector3.ZERO
				p[u] = (i + 0.5) / nu * size[u] - size[u] * 0.5
				p.y = (j + 0.5) / nv * size.y - size.y * 0.5
				p[axis] = side * (size[axis] * 0.5 + 0.015)
				Models.box(_mesh, Vector3(0.07, 0.07, 0.07), p, rivet_mat)


## 큰 면 두 개에 번개 모양 검은 균열 (위치로 정해지는 모양이라 매번 같다).
## 멀리서도 보이게 굵고 길게: 위 가장자리에서 아래로 갈라져 내려가고 중간에 가지가 하나 난다.
func _add_cracks() -> void:
	var crack_mat := Models.mat(Color(0.08, 0.06, 0.05), 1.0)
	crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var axis := 2 if size.z <= size.x else 0
	var u := 0 if axis == 2 else 2
	var k := absi(int(position.x * 7.0 + position.y * 13.0 + position.z * 3.0))
	var w := minf(size[u], 1.5)
	for side in [-1.0, 1.0]:
		var cur := Vector2((float(k % 5) / 4.0 - 0.5) * w * 0.4, size.y * 0.5)
		var steps := 3
		for i in steps:
			var dx := (0.16 + 0.06 * float((k + i) % 3)) * w * (1.0 if (k + i) % 2 == 0 else -1.0)
			var nxt := Vector2(clampf(cur.x + dx, -size[u] * 0.42, size[u] * 0.42), cur.y - size.y * 0.85 / steps)
			_crack_segment(cur, nxt, 0.11 - i * 0.025, axis, u, side, crack_mat)
			if i == 0:
				# 가지
				var br := nxt + Vector2(-signf(dx) * w * 0.3, -size.y * 0.12)
				br.x = clampf(br.x, -size[u] * 0.45, size[u] * 0.45)
				_crack_segment(nxt, br, 0.06, axis, u, side, crack_mat)
			cur = nxt
		k += 3


func _crack_segment(a: Vector2, b: Vector2, thick: float, axis: int, u: int, side: float, crack_mat: Material) -> void:
	var seg := b - a
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, seg.length() + thick * 0.5, 0.02) if axis == 2 else Vector3(0.02, seg.length() + thick * 0.5, thick)
	m.mesh = bm
	m.material_override = crack_mat
	var mid := (a + b) * 0.5
	var p := Vector3.ZERO
	p[u] = mid.x
	p.y = mid.y
	p[axis] = side * (size[axis] * 0.5 + 0.012)
	m.position = p
	var ang := atan2(seg.x, -seg.y)
	if axis == 2:
		m.rotation.z = ang
	else:
		m.rotation.x = -ang
	_mesh.add_child(m)


## 근처 충격으로 닳는다 (금이 커진다). 닳을수록 연결이 약해지고 색이 어두워진다.
func wear(amount: float) -> void:
	if not (mat in WEARS) or fallen or amount <= 0.0:
		return
	integrity = maxf(0.05, integrity - amount)
	_base_color = Color(INFO[mat].color).darkened((1.0 - integrity) * 0.35)
	if oiled:
		_base_color = _base_color.darkened(0.35)
	_material.albedo_color = _base_color.lerp(CHAR_COLOR, clampf(1.0 - health, 0.0, 1.0))


func joint_strength() -> float:
	return INFO[mat].joint


func base_ratio() -> float:
	return support_ratio if support_ratio >= 0.0 else INFO[mat].ratio


## 가장 낮은 꼭짓점의 높이 (회전 반영).
func lowest_point() -> float:
	var low := INF
	var t := global_transform
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				low = minf(low, (t * Vector3(size.x * sx, size.y * sy, size.z * sz)).y)
	return low


## 점에서 이 블록 표면까지의 거리.
func distance_to_point(p: Vector3) -> float:
	var local := global_transform.affine_inverse() * p
	var h := size * 0.5
	var clamped := Vector3(clampf(local.x, -h.x, h.x), clampf(local.y, -h.y, h.y), clampf(local.z, -h.z, h.z))
	return local.distance_to(clamped)


func add_heat(amount: float, rate := 1.0) -> void:
	if burnt or burning or not is_flammable():
		return
	heat += amount
	var need: float = INFO[mat].ignite * (0.3 if oiled else 1.0)
	if heat >= need:
		ignite(rate * (1.6 if oiled else 1.0))


func ignite(rate := 1.0) -> void:
	if burnt or burning or not is_flammable():
		return
	burning = true
	burn_rate = maxf(burn_rate, rate)
	var extents := size * 0.45
	extents.y = minf(extents.y, 2.0)
	var amount := clampi(int(size.x * size.z * 10.0 + size.y * 6.0), 6, 40)
	_fire = Fx.fire(extents, amount, clampf(minf(size.x, size.z) * 0.9, 0.25, 0.6))
	add_child(_fire)


## 화약통 연쇄: 폭발이 닿으면 짧은 지연 뒤 터진다.
func fuse(seconds: float) -> void:
	if burnt:
		return
	if not burning:
		burning = true
		var f := Fx.fire(size * 0.4, 12, 0.4)
		add_child(f)
	burn_rate = 1.0
	health = 1.0
	burn_time = maxf(seconds, 0.02)


func drop(impulse := Vector3.ZERO) -> void:
	if fallen:
		return
	fallen = true
	_unfreeze.call_deferred(impulse)


func _unfreeze(impulse: Vector3) -> void:
	# 충돌 상자를 살짝 줄여 위아래 블록 사이에 끼어 버티지 않게 한다
	if _box:
		_box.size = size * 0.97
	# 떨어진 잔해는 층 8로 옮긴다: 지형·서 있는 블록·다른 잔해와는 부딪히지만 인물은 밀지 않는다
	# (깔림 판정은 인물이 따로 본다)
	collision_layer = 8
	collision_mask = 1 | 8
	freeze = false
	can_sleep = true
	sleeping = false
	# 충격은 정지 상태가 실제로 풀린 뒤(2틱 후)에 준다. 더 일찍 주면 상태 전환 때 속도가 0으로 초기화된다
	_pending_impulse = impulse
	_impulse_delay = 2


## 막 풀려난 몸체가 잠들어 있을 수 있으므로 깨우고 속도를 직접 더한다.
func _apply_pending_impulse() -> void:
	var impulse := _pending_impulse
	_pending_impulse = Vector3.ZERO
	if impulse == Vector3.ZERO:
		return
	sleeping = false
	linear_velocity += impulse / mass
	# 날아가는 방향에 수직한 축으로 굴러가듯 회전 (결정적, 무작위 없음).
	# 위에 무언가를 받치던 블록은 돌리지 않는다 (쓰러지며 위 블록에 걸려 끼지 않도록)
	for j in joints:
		if j.upper != null and j.upper != self:
			return
	var axis := impulse.cross(Vector3.UP)
	if axis.length() < 0.001:
		axis = Vector3.RIGHT * impulse.length()
	angular_velocity += axis.normalized() * clampf(impulse.length() / mass * 0.8, 0.0, 12.0)


func _physics_process(delta: float) -> void:
	if fallen:
		if _pending_impulse != Vector3.ZERO and not freeze:
			_impulse_delay -= 1
			if _impulse_delay <= 0:
				_apply_pending_impulse()
		_last_velocity = linear_velocity
		_impact_cooldown -= delta
	if not burning:
		return
	_burn_clock += delta
	health -= delta * burn_rate / burn_time
	# 불은 맞닿은 가연물로만 번진다
	for n in neighbors:
		if is_instance_valid(n) and not n.burnt and not n.burning and n.is_flammable():
			var reach := (size.length() + n.size.length()) * 0.5 + 0.1
			if global_position.distance_to(n.global_position) <= reach:
				n.add_heat(delta, burn_rate)
	_material.albedo_color = _base_color.lerp(CHAR_COLOR, clampf(1.0 - health, 0.0, 1.0))
	if health < 0.2 and mat != Mat.KEG:
		# 끊어지기 직전에 흔들린다
		_mesh.position = Vector3(sin(_burn_clock * 57.0), 0, cos(_burn_clock * 43.0)) * 0.025
	if health <= 0.0:
		burning = false
		burnt = true
		if structure:
			structure.on_block_burnt(self)


func _on_body_entered(other: Node) -> void:
	if other.is_in_group("ground"):
		touched_ground = true
	if not fallen or _impact_cooldown > 0.0:
		return
	var speed := _last_velocity.length()
	if speed < 2.0:
		return
	var energy := mass * speed * IMPACT_K
	if other is Block and not other.fallen and other.structure:
		# 함께 떨어지는 잔해(끊어진 밧줄 등)와 닿은 것은 무시하고, 서 있는 블록을 칠 때만 쿨다운을 건다
		_impact_cooldown = 0.3
		var dir: Vector3 = (other.global_position - global_position).normalized()
		var contact := global_position + dir * minf(size.y, size.length()) * 0.5
		var radius := clampf(size.length() * 1.2, 1.0, 3.0)
		other.structure.call_deferred("apply_impact", contact, radius, energy)
	if structure and energy > 120.0:
		structure.notify_heavy_landing(global_position, energy)


## 충격을 받은 블록의 과장된 반응: 하얗게 번쩍이며 충격 방향으로 흔들린다 (연출 전용, 물리 무관).
func hit_react(amount: float, from: Vector3) -> void:
	_react = maxf(_react, clampf(amount, 0.2, 1.0))
	var dir := global_position - from
	_react_dir = dir.normalized() if dir.length() > 0.01 else Vector3.UP


func _process(delta: float) -> void:
	if _react <= 0.0:
		return
	_react = maxf(0.0, _react - delta * 3.0)
	var wobble := sin(_react * 40.0) * _react
	_mesh.position = _react_dir * wobble * 0.12
	_mesh.scale = Vector3.ONE * (1.0 + _react * 0.08)
	var base := _base_color.lerp(CHAR_COLOR, clampf(1.0 - health, 0.0, 1.0))
	_material.albedo_color = base.lerp(Color(1.0, 0.95, 0.8), _react * 0.8)
	if _react <= 0.0:
		_mesh.position = Vector3.ZERO
		_mesh.scale = Vector3.ONE
		_material.albedo_color = base