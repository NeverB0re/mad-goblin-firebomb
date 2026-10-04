class_name FirePool
extends Node3D
## 화염탄이 깨진 자리(또는 점화된 기름)에 몇 초간 남는 불웅덩이. 범위 안의 가연물에 점화 시간을 누적하고,
## 범위 안 인물(지휘관, 전령, 방패병, 동료 고블린)에게 불이 닿았음을 알린다.
## 불은 고정 틱 기준으로 계산하고 무작위 값을 쓰지 않는다.
## 모바일 예산(동적 광원은 방향광 + 조명탄 하나)에 맞춰 실제 광원 대신 가산 혼합 불꽃만 쓴다.

var radius := 2.5
var duration := 5.0
var burn_multiplier := 1.0
var active := true
var _t := 0.0
var _fire: GPUParticles3D


func setup(p_radius: float, p_duration: float, p_burn_multiplier: float, big := false) -> FirePool:
	radius = p_radius
	duration = p_duration
	burn_multiplier = p_burn_multiplier
	add_to_group("fire_pool")
	var amount := clampi(int(radius * radius * (10.0 if big else 6.0)), 6, 120)
	_fire = Fx.fire(Vector3(radius * 0.6, 0.05, radius * 0.6), amount, 0.75 if big else 0.55)
	if big:
		_fire.lifetime = 1.1
	add_child(_fire)
	return self


func _physics_process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var p := global_position
	for b in get_tree().get_nodes_in_group("flammable"):
		var block := b as Block
		if block.burnt or block.burning:
			continue
		if block.distance_to_point(p) <= radius and FirePool.reaches(self, p, block):
			block.add_heat(delta * burn_multiplier, burn_multiplier)
	for a in get_tree().get_nodes_in_group("actors"):
		var ap: Vector3 = a.global_position
		var flat := Vector2(ap.x - p.x, ap.z - p.z).length()
		if flat <= radius + 0.35 and ap.y > p.y - 2.0 and ap.y < p.y + 1.5 and FirePool.clear_line(self, p, a.chest()):
			a.on_fire_touch()
	if _t >= duration:
		active = false
		remove_from_group("fire_pool")
		_fire.emitting = false
		Fx.free_after(self, 1.5)


## 불이 블록까지 닿는지: 사이를 다른 블록(벽 등)이 가리면 닿지 않는다. 지면은 가리지 않는다.
static func reaches(from_node: Node3D, p: Vector3, block: Block) -> bool:
	var start := p + Vector3.UP * 0.3
	var local := block.global_transform.affine_inverse() * start
	var h := block.size * 0.5
	var closest := block.global_transform * Vector3(clampf(local.x, -h.x, h.x), clampf(local.y, -h.y, h.y), clampf(local.z, -h.z, h.z))
	if start.distance_to(closest) < 0.05:
		return true
	var q := PhysicsRayQueryParameters3D.create(start, closest + (closest - start).normalized() * 0.05, 1)
	var hit := from_node.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Object = hit.collider
	return col == block or not (col is Block)

## 두 점 사이를 블록이 가리지 않는지 (지면·지형은 무시). 불이 벽 너머 인물에게 닿지 않게 한다.
static func clear_line(from_node: Node3D, a: Vector3, b: Vector3) -> bool:
	var start := a + Vector3.UP * 0.3
	var q := PhysicsRayQueryParameters3D.create(start, b, 1)
	var hit := from_node.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or not (hit.collider is Block)