class_name Block
extends RigidBody3D
## 건물 블록. 평소에는 freeze 상태로 서 있다가, 연결이 끊기거나 받침을 잃으면 떨어진다.
## 재질은 눈으로 보고 바로 알 수 있게 나눈다: 짚·나무 = 탄다, 금 간 석재 = 고폭탄으로 부서진다,
## 강철 = 고폭탄으로는 안 되고 폭발통·화약통·미사일 같은 큰 폭발에만 날아간다, 금 하나 없는 흰 석재 = 무엇으로도 안 부서진다.
## (흰 석재도 받치던 것이 없어지면 떨어진다.)
## 가연물은 불이 붙으면 서서히 약해지다가(검게 변함) 다 타면 끊어져 사라진다.

enum Mat { WOOD_THIN, WOOD_BEAM, STONE, ROPE, STRAW, KEG, CORE, WEIGHT, STEEL, WOOD_WET, FUEL, CRACKED }

const CHAR_COLOR := Color(0.07, 0.06, 0.05)
## 떨어지는 블록이 다른 블록에 부딪힐 때의 충격 계수 (질량 × 속도 × K)
const IMPACT_K := 2.2

## joint: 연결 강도, ignite: 점화에 필요한 누적 열(초), burn: 다 타는 시간(초, -1 = 굵기로 계산)
## ratio: 처음 받침 수 중 몇 비율이 남아야 버티는지 (0 = 받침 규칙 없음)
const INFO := {
	Mat.WOOD_THIN: {"color": Color(0.6, 0.4, 0.22), "density": 0.6, "joint": 10.0, "flammable": true, "ignite": 0.4, "burn": 3.5, "ratio": 1.0},
	Mat.WOOD_BEAM: {"color": Color(0.42, 0.26, 0.14), "density": 0.7, "joint": 70.0, "flammable": true, "ignite": 0.8, "burn": -1.0, "ratio": 1.0},
	# 반듯한 흰 석재: 석재끼리, 석재와 땅 사이 연결은 무엇으로도 끊기지 않는다 (Structure.Joint.unbreakable)
	Mat.STONE: {"color": Color(0.7, 0.68, 0.63), "density": 2.4, "joint": 400.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
	Mat.ROPE: {"color": Color(0.84, 0.7, 0.42), "density": 0.5, "joint": 15.0, "flammable": true, "ignite": 0.3, "burn": 2.0, "ratio": 0.0},
	Mat.STRAW: {"color": Color(0.93, 0.76, 0.4), "density": 0.2, "joint": 5.0, "flammable": true, "ignite": 0.15, "burn": 2.0, "ratio": 1.0},
	Mat.KEG: {"color": Color(0.8, 0.3, 0.13), "density": 0.9, "joint": 30.0, "flammable": true, "ignite": 0.3, "burn": 0.8, "ratio": 1.0},
	Mat.CORE: {"color": Color(0.97, 0.74, 0.16), "density": 2.4, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 1.0},
	Mat.WEIGHT: {"color": Color(0.16, 0.16, 0.18), "density": 7.8, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.0},
	# 인간의 강철판: 청회색, 반듯한 리벳. 고폭탄으로는 안 부서지고 큰 폭발(폭발통·화약통·미사일)에만 날아간다
	Mat.STEEL: {"color": Color(0.42, 0.5, 0.58), "density": 3.0, "joint": 150.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
	# 젖은 목재: 그대로는 타지 않는다. 기름을 묻히면 탄다
	Mat.WOOD_WET: {"color": Color(0.26, 0.2, 0.17), "density": 0.8, "joint": 60.0, "flammable": true, "ignite": 0.6, "burn": 5.0, "ratio": 1.0},
	# 내부 연료 배관: 검정에 흰 띠. 빨리 타고, 다 타면 그 자리에서 불길이 확 솟는다
	Mat.FUEL: {"color": Color(0.08, 0.08, 0.08), "density": 1.0, "joint": 40.0, "flammable": true, "ignite": 0.25, "burn": 1.6, "ratio": 0.0},
	# 금 간 석벽: 석재와 비슷한 색, 쪼개지고 비뚤고 이 빠진 돌 (낡아 부서져 가는 모양이 취약하다는 표시). 고폭탄으로 부서지고, 근처에 맞아도 조금씩 금이 커진다
	Mat.CRACKED: {"color": Color(0.66, 0.63, 0.57), "density": 2.2, "joint": 110.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
}
## 재질별 로우폴리 겉모양 (LowPoly.block_mesh)
const STYLE := {
	Mat.WOOD_THIN: "plank", Mat.WOOD_BEAM: "plank", Mat.WOOD_WET: "plank", Mat.STONE: "stone", Mat.CRACKED: "cracked",
	Mat.STRAW: "straw", Mat.KEG: "keg", Mat.STEEL: "steel",
}
## 근처 충격에 조금씩 약해지는(금이 커지는) 재질. 반듯한 석재와 강철은 닳지 않는다
const WEARS := [Mat.WOOD_THIN, Mat.WOOD_BEAM, Mat.ROPE, Mat.STRAW, Mat.WOOD_WET, Mat.CRACKED]

var mat: int = Mat.STONE
var size := Vector3.ONE
var structure: Node  # Structure
var joints: Array = []
var neighbors: Array[Block] = []
## 도화선 연결: 맞닿지 않아도(날아가 떨어져 있어도) 불을 넘겨 주는 이웃 (도화선 조각, 끝의 화약통)
var fuse_links: Array[Block] = []
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
## 비에 젖은 화약통 (기름을 묻혀야 불이 붙는다)
var wet_keg := false

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _fire: GPUParticles3D
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _pending_impulse := Vector3.ZERO
## 쓰러질 때 줄 회전 (INF = 충격 방향으로 알아서 굴림). 기울어 넘어가는 건물은 블록들이 한 몸처럼 돈다
var _pending_spin := Vector3.INF
var _topple_vel := Vector3.INF
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
	# 로우폴리 겉모양 (충돌 상자는 그대로): 나무는 판자·각목, 석재는 벽돌, 짚은 층층이, 통은 술통
	# 금 간 석재는 블록마다 부서진 모양이 다르다
	var look_seed := absi(roundi(p_pos.x * 7.0 + p_pos.y * 13.0 + p_pos.z * 3.0)) % 97 if mat == Mat.CRACKED else 0
	_mesh.mesh = LowPoly.block_mesh(STYLE.get(mat, "plain"), size, look_seed)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.albedo_color = _base_color
	_material.roughness = 0.95
	_mesh.material_override = _material
	add_child(_mesh)

	if mat == Mat.KEG:
		_add_keg_marks()
	elif mat == Mat.FUEL:
		# 흰 띠를 두른 검은 배관
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

	add_to_group("blocks")
	if INFO[mat].flammable:
		add_to_group("flammable")
	return self


func is_flammable() -> bool:
	if mat == Mat.WOOD_WET or wet_keg:
		return oiled
	return INFO[mat].flammable


## 겉 색을 바꾼다 (판정과 무관: 눈에 띄는 검정·노랑 도화선 등).
func set_color(c: Color) -> void:
	_base_color = c
	_material.albedo_color = c


## 비에 젖는다 (나무와 짚). 그대로는 타지 않고 기름을 묻혀야 탄다.
## 화약통과 도화선은 덮개 없이 비를 맞는 것(rain_wets 메타)만 젖는다: 불로는 안 붙고 기름을 부어야 탄다 (폭발에는 그대로 터진다).
func make_wet() -> void:
	if (mat == Mat.KEG or mat == Mat.ROPE) and has_meta("rain_wets"):
		wet_keg = true
		_base_color = _base_color.lightened(0.15)
		_material.albedo_color = _base_color
		return
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


## 겉모양만 깨끗한 흰 석재로 바꾼다 (재질의 성질은 그대로: 강철 기둥이 석재 망대에 섞여 보이게).
func look_like_stone() -> void:
	for child in _mesh.get_children():
		child.free()
	_mesh.mesh = LowPoly.block_mesh("stone", size)
	_base_color = INFO[Mat.STONE].color
	_material.albedo_color = _base_color


## 폭발통: 붉은 통에 보랏빛 쇠테 둘, 네 면에 노란 폭발 표지 (한눈에 터지는 통임을 알린다).
func _add_keg_marks() -> void:
	Models.keg_marks(_mesh, minf(size.x, size.z) * 0.5, size.y)


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


## 석재 문짝의 모양: 쇠 띠 둘과 징, 손잡이, 가운데 쪽 틈. inner: 문짝의 가운데 쪽이 +x(1)인지 -x(-1)인지.
func add_door_details(inner: float) -> void:
	var iron := Models.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6)
	var knob := Models.mat(Color(0.7, 0.55, 0.25), 0.4, 0.6)
	for side in [-1.0, 1.0]:
		var z: float = side * (size.z * 0.5 + 0.02)
		for y in [-0.3, 0.3]:
			Models.box(_mesh, Vector3(size.x * 0.94, 0.14, 0.04), Vector3(0, size.y * y, z), iron)
			for k in 4:
				Models.box(_mesh, Vector3(0.07, 0.07, 0.03), Vector3((k - 1.5) * size.x * 0.22, size.y * y, z + side * 0.025), iron)
		Models.ball(_mesh, 0.07, Vector3(inner * size.x * 0.36, 0, z + side * 0.04), knob, 6)
		Models.box(_mesh, Vector3(0.04, size.y * 0.96, 0.03), Vector3(inner * size.x * 0.5, 0, z), Models.mat(Color(0.12, 0.1, 0.09), 1.0))


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
## tid: 이 화약통을 터뜨린 플레이어 투척 번호 (그 폭발에 쓰러진 인물도 그 투척의 것으로 친다)
func fuse(seconds: float, tid := -1) -> void:
	if burnt:
		return
	if tid >= 0 and not has_meta("blast_tid"):
		set_meta("blast_tid", tid)
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


## 정해진 속도와 회전으로 떨어뜨린다 (건물이 한쪽으로 기울어 넘어갈 때).
## 막 떨어지기 시작한(아직 풀리기 전인) 블록에도 덮어쓴다.
func topple(velocity: Vector3, spin: Vector3) -> void:
	if fallen and not freeze:
		return
	_pending_spin = spin
	_topple_vel = velocity
	drop()


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
	_pending_impulse = impulse if _topple_vel == Vector3.INF else _topple_vel * mass + Vector3(0, 0.0001, 0)
	_impulse_delay = 2


## 막 풀려난 몸체가 잠들어 있을 수 있으므로 깨우고 속도를 직접 더한다.
func _apply_pending_impulse() -> void:
	var impulse := _pending_impulse
	_pending_impulse = Vector3.ZERO
	if impulse == Vector3.ZERO:
		return
	sleeping = false
	linear_velocity += impulse / mass
	if _pending_spin != Vector3.INF:
		angular_velocity = _pending_spin
		return
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
	for n in fuse_links:
		if is_instance_valid(n) and not n.burnt and not n.burning and (n.is_flammable() or n.wet_keg):
			if n.wet_keg and not n.is_flammable():
				# 도화선은 통 속까지 이어져 있어 젖은 화약통도 도화선 불로는 터진다
				n.fuse(0.3)
			else:
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