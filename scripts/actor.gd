class_name Actor
extends CharacterBody3D
## 전장의 인물 공통 (지휘관, 전령, 병사, 동료 고블린). 대사 없이 몸짓으로만 상황을 보여 준다.
## 판정은 직격, 폭발 반경, 불, 무너지는 구조(깔림·추락) 중 하나로 그 순간 확정되고,
## 그 뒤에 날아가는 모습은 연출이다.

signal defeated(actor: Actor, cause: String)

const CRUSH_SPEED := 2.5
const FALL_HEIGHT := 2.0

var dead := false
## 쓰러진 원인 (direct, blast, fire, crush, fall)
var defeat_cause := ""
## 판정 대상이 아님 (동료 고블린: 그을리기만 한다)
var invulnerable := false
var visual: Node3D
var uses_gravity := true
var _rest_y := INF
var _anim_t := 0.0
var _flying := false
var _fly_vel := Vector3.ZERO
var _fly_spin := Vector3.ZERO
var _fly_time := 0.0
var _burn_panic := false


func _init() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("actors")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)


func set_visual(v: Node3D) -> void:
	if visual:
		visual.queue_free()
	visual = v
	add_child(visual)


func chest() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)


# ---------- 판정 ----------

func on_fire_touch() -> void:
	if invulnerable:
		singe()
		return
	defeat("fire")


func on_direct_hit(ammo: AmmoType) -> void:
	if ammo.kind == AmmoType.Kind.FIRE or ammo.kind == AmmoType.Kind.HE:
		if invulnerable:
			singe()
		else:
			defeat("direct")


## 폭발 반경 판정. 착탄점과 가슴 사이를 블록이 가리면 엄폐되어 살아남는다.
func on_blast(pos: Vector3, radius: float) -> void:
	if dead or radius <= 0.0:
		return
	if chest().distance_to(pos) > radius:
		return
	# 착탄면 바깥쪽에서 시작해야 벽 안에서 시작한 광선이 벽을 그냥 통과하지 않는다
	var q := PhysicsRayQueryParameters3D.create(pos - (chest() - pos).normalized() * 0.05, chest(), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return
	if invulnerable:
		singe()
	else:
		defeat("blast")


func defeat(cause: String) -> void:
	if dead or invulnerable:
		return
	dead = true
	defeat_cause = cause
	collision_layer = 0
	_on_defeated(cause)
	defeated.emit(self, cause)


## 하위 클래스가 쓰러질 때의 몸짓을 정한다.
func _on_defeated(_cause: String) -> void:
	pass


## 그을림 (동료 고블린). 몸이 잠깐 검게 번쩍인다.
func singe() -> void:
	if visual == null:
		return
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.1, 0.85, 1.1), 0.08)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.2)


## 만화처럼 날아가기 (판정 뒤의 연출). style 0~4: 팽이, 옆돌기, 뒤공중제비, 로켓, 데굴데굴.
func launch(dir: Vector3, style: int, power := 1.0) -> void:
	_flying = true
	uses_gravity = false
	collision_layer = 0
	collision_mask = 0
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	match style % 5:
		0:
			_fly_vel = flat * 5.0 + Vector3.UP * 11.0
			_fly_spin = Vector3(0, 22.0, 0)
		1:
			_fly_vel = flat * 7.0 + Vector3.UP * 9.0
			_fly_spin = Vector3(0, 0, 14.0)
		2:
			_fly_vel = flat * 6.0 + Vector3.UP * 10.0
			_fly_spin = Vector3(-12.0, 0, 0)
		3:
			_fly_vel = flat * 1.5 + Vector3.UP * 16.0
			_fly_spin = Vector3(0, 30.0, 2.0)
		4:
			_fly_vel = flat * 8.0 + Vector3.UP * 7.0
			_fly_spin = Vector3(9.0, 6.0, 11.0)
	_fly_vel *= power


## 불타며 허둥댄다 (승리 연출: 날아가지 않고 불탄 경우). 쓰러진 뒤에도 몸짓을 계속한다.
func burn_panic() -> void:
	_burn_panic = true
	var fire := Fx.fire(Vector3(0.3, 0.7, 0.3), 36, 0.45)
	fire.position = Vector3(0, 1.0, 0)
	add_child(fire)
	var smoke := Fx.smoke_column(12)
	smoke.position = Vector3(0, 2.0, 0)
	add_child(smoke)
	# 그을림
	if visual:
		for m in visual.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var dark := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				dark.albedo_color = dark.albedo_color.darkened(0.55)
				mi.material_override = dark


## 무너진 건물에 깔려 납작해진다 (승리 연출: 깔림·추락).
## toward: 다리가 삐져나올 방향 (보통 카메라 쪽). 잔해 가장자리를 찾아 다리가 그 밖으로 나오게 한다.
func squash(toward := Vector3.FORWARD) -> void:
	if visual == null:
		return
	var dir := Vector3(toward.x, 0, toward.z).normalized()
	# 위를 덮은 블록이 끝나는 곳까지의 거리
	var space := get_world_3d().direct_space_state
	var edge := 0.0
	while edge < 4.0:
		var p := global_position + dir * edge
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5.0, p + Vector3.UP * 0.5, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not (hit.collider is Block):
			break
		edge += 0.25
	# 머리는 잔해 밑, 납작해진 몸과 다리는 잔해 밖으로 삐져나온다
	var local := global_transform.basis.inverse() * dir
	var yaw := atan2(local.x, local.z)
	visual.rotation = Vector3(-PI * 0.5, yaw, 0.25)
	visual.scale = Vector3(1.3, 1.3, 0.4)
	# 발끝이 가장자리 밖으로 나오게 (누운 몸은 머리 쪽으로 약 2.3m 뻗는다)
	visual.position = local * (edge + 0.5 if edge > 0.0 else 0.0) + Vector3(0, 0.15, 0)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if _flying:
		return
	if dead:
		return
	if uses_gravity:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		if is_on_floor():
			if _rest_y == INF:
				_rest_y = global_position.y
			elif _rest_y - global_position.y >= FALL_HEIGHT:
				defeat("fall")
				return
	_check_surroundings()


## 무너지는 블록에 깔리거나, 타는 블록에 닿았는지 본다.
func _check_surroundings() -> void:
	var c := chest()
	for b in get_tree().get_nodes_in_group("blocks"):
		var block := b as Block
		if block.burnt:
			continue
		var d := block.distance_to_point(c)
		if d > 1.2:
			continue
		# 깔림: 위에서 떨어지는 블록만 친다 (옆으로 튕겨 나가는 과장된 파편은 판정에 쓰지 않는다)
		if block.fallen and block.linear_velocity.y < -CRUSH_SPEED and block.global_position.y > c.y - 0.2 and d < 0.6 and block.mass > 0.3:
			if invulnerable:
				singe()
			else:
				defeat("crush")
			return
		if block.burning and d < 0.9:
			on_fire_touch()
			if dead:
				return


func _process(delta: float) -> void:
	if _burn_panic and visual:
		# 팔을 마구 휘두르며 제자리에서 펄쩍펄쩍
		var t := _anim_t + _fly_time
		_fly_time += delta
		visual.position = Vector3(sin(t * 17.0) * 0.12, absf(sin(t * 11.0)) * 0.35, 0)
		visual.rotation = Vector3(-0.15, sin(t * 7.0) * 0.6, sin(t * 13.0) * 0.12)
		for arm_name in ["ArmL", "ArmR"]:
			var arm: Node3D = visual.get_node_or_null(arm_name)
			if arm:
				arm.rotation = Vector3(sin(t * 21.0) * 0.8, 0, (2.4 + sin(t * 25.0 + (0.0 if arm_name == "ArmL" else 1.7)) * 0.7) * (-1.0 if arm_name == "ArmL" else 1.0))
		return
	if not _flying or visual == null:
		return
	# 연출: 느린 화면(Engine.time_scale)에 맞춰 함께 느려진다
	_fly_time += delta
	_fly_vel.y -= 9.8 * delta
	global_position += _fly_vel * delta
	visual.rotation += _fly_spin * delta
	for arm_name in ["ArmL", "ArmR"]:
		var arm: Node3D = visual.get_node_or_null(arm_name)
		if arm:
			arm.rotation.z = sin(_fly_time * 25.0 + (0.0 if arm_name == "ArmL" else PI)) * 1.6
	if global_position.y < 0.0 and _fly_vel.y < 0.0:
		global_position.y = 0.0
		_fly_vel = Vector3.ZERO
		_fly_spin *= 0.0
