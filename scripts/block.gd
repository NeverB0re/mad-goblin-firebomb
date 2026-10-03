class_name Block
extends RigidBody3D
## 건물 블록. 평소에는 freeze 상태로 서 있다가, 연결이 끊기거나 받침을 잃으면 떨어진다.
## 가연물은 불이 붙으면 서서히 약해지다가(검게 변함) 다 타면 끊어져 사라진다.

enum Mat { WOOD_THIN, WOOD_BEAM, STONE, ROPE, STRAW, KEG, CORE, WEIGHT }

const CHAR_COLOR := Color(0.07, 0.06, 0.05)
## 떨어지는 블록이 다른 블록에 부딪힐 때의 충격 계수 (질량 × 속도 × K)
const IMPACT_K := 2.2

## joint: 연결 강도, ignite: 점화에 필요한 누적 열(초), burn: 다 타는 시간(초, -1 = 굵기로 계산)
## ratio: 처음 받침 수 중 몇 비율이 남아야 버티는지 (0 = 받침 규칙 없음)
const INFO := {
	Mat.WOOD_THIN: {"color": Color(0.82, 0.64, 0.42), "density": 0.6, "joint": 10.0, "flammable": true, "ignite": 0.8, "burn": 8.0, "ratio": 1.0},
	Mat.WOOD_BEAM: {"color": Color(0.30, 0.18, 0.09), "density": 0.7, "joint": 70.0, "flammable": true, "ignite": 2.0, "burn": -1.0, "ratio": 1.0},
	Mat.STONE: {"color": Color(0.64, 0.65, 0.68), "density": 2.4, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.6},
	Mat.ROPE: {"color": Color(0.86, 0.78, 0.55), "density": 0.5, "joint": 15.0, "flammable": true, "ignite": 0.5, "burn": 4.0, "ratio": 0.0},
	Mat.STRAW: {"color": Color(0.94, 0.83, 0.36), "density": 0.2, "joint": 5.0, "flammable": true, "ignite": 0.2, "burn": 4.0, "ratio": 1.0},
	Mat.KEG: {"color": Color(0.06, 0.06, 0.06), "density": 0.9, "joint": 30.0, "flammable": true, "ignite": 0.3, "burn": 0.8, "ratio": 1.0},
	Mat.CORE: {"color": Color(0.92, 0.07, 0.07), "density": 2.4, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 1.0},
	Mat.WEIGHT: {"color": Color(0.16, 0.16, 0.18), "density": 7.8, "joint": 200.0, "flammable": false, "ignite": 0.0, "burn": 0.0, "ratio": 0.0},
}

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
var heat := 0.0
var burning := false
var burnt := false
var fallen := false
var touched_ground := false
## 처음 놓인 위치의 가장 낮은 높이
var start_low := 0.0
var burn_time := 8.0
var burn_rate := 1.0

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color
var _fire: GPUParticles3D
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _burn_clock := 0.0


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
		# 목재는 굵기에 따라 약 8~20초 뒤 끊어진다
		var thick := minf(size.x, minf(size.y, size.z))
		burn_time = 8.0 + 12.0 * clampf((thick - 0.2) / 0.6, 0.0, 1.0)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
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

	if mat == Mat.KEG:
		# 흰 띠를 두른 검은 통
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

	add_to_group("blocks")
	if is_flammable():
		add_to_group("flammable")
	if mat == Mat.CORE:
		add_to_group("core")
	return self


func is_flammable() -> bool:
	return INFO[mat].flammable


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
	if heat >= INFO[mat].ignite:
		ignite(rate)


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


func drop(impulse := Vector3.ZERO) -> void:
	if fallen:
		return
	fallen = true
	_unfreeze.call_deferred(impulse)


func _unfreeze(impulse: Vector3) -> void:
	freeze = false
	can_sleep = true
	sleeping = false
	if impulse != Vector3.ZERO:
		apply_central_impulse(impulse)


func _physics_process(delta: float) -> void:
	if fallen:
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
	_impact_cooldown = 0.3
	var energy := mass * speed * IMPACT_K
	if other is Block and not other.fallen and other.structure:
		var dir: Vector3 = (other.global_position - global_position).normalized()
		var contact := global_position + dir * minf(size.y, size.length()) * 0.5
		var radius := clampf(size.length() * 1.2, 1.0, 3.0)
		other.structure.call_deferred("apply_impact", contact, radius, energy)
	if structure and energy > 120.0:
		structure.notify_heavy_landing(global_position, energy)
