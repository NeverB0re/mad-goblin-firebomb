class_name Player
extends CharacterBody3D
## 1인칭 플레이어. 투척 구역 안에서만 이동하고, 시선의 위아래 각도가 곧 투척 각도다.

signal throw_requested(origin: Vector3, direction: Vector3)
signal slot_requested(index: int)
signal slot_cycle_requested(step: int)

const SPEED := 4.5
const MOUSE_SENS := 0.0022
const BASE_FOV := 70.0
const EYE_HEIGHT := 1.6
const THROW_COOLDOWN := 0.6

var zone_min := Vector2(-3, -3)
var zone_max := Vector2(3, 3)
var head: Node3D
var camera: Camera3D
var zoom_fov: float
var pitch := 0.0
var cooldown := 0.0
var _held: Node3D
var _held_scale := 1.0


func _init() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	head = Node3D.new()
	head.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.far = 1500.0
	camera.near = 0.05
	head.add_child(camera)
	# 2배 줌: 화면 절반 각도의 탄젠트를 절반으로
	zoom_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(BASE_FOV) * 0.5) * 0.5))
	set_held_model(1.0)


func set_held_model(model_scale: float) -> void:
	if _held:
		_held.queue_free()
	_held_scale = model_scale
	# 화면 가까이에서는 불꽃 파티클이 하얗게 번지므로 손에 든 모델은 불꽃 없이 작게 표시한다
	_held = Fx.molotov_model(model_scale * 0.45, false)
	_held.position = Vector3(0.3, -0.26, -0.62)
	_held.rotation = Vector3(0.2, 0, -0.25)
	camera.add_child(_held)


func set_zone(center: Vector3, half_extents: Vector2) -> void:
	zone_min = Vector2(center.x, center.z) - half_extents
	zone_max = Vector2(center.x, center.z) + half_extents


## 화면 중앙(조준점)에서 나가는 투척 방향과 출발점.
func throw_direction() -> Vector3:
	return -camera.global_transform.basis.z


func throw_origin() -> Vector3:
	return camera.global_position + throw_direction() * 0.6


func look_at_angles(yaw: float, pitch_rad: float) -> void:
	rotation.y = yaw
	pitch = clampf(pitch_rad, -1.5, 1.5)
	head.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * (camera.fov / BASE_FOV)
		rotate_y(-event.relative.x * sens)
		pitch = clampf(pitch - event.relative.y * sens, -1.5, 1.5)
		head.rotation.x = pitch
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_throw()
			MOUSE_BUTTON_WHEEL_UP:
				slot_cycle_requested.emit(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				slot_cycle_requested.emit(1)
	elif event.is_action_pressed("ammo_1"):
		slot_requested.emit(0)
	elif event.is_action_pressed("ammo_2"):
		slot_requested.emit(1)


func _throw() -> void:
	if cooldown > 0.0:
		return
	cooldown = THROW_COOLDOWN
	throw_requested.emit(throw_origin(), throw_direction())


func _physics_process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
	if _held:
		_held.visible = cooldown <= THROW_COOLDOWN * 0.4

	var zooming := Input.is_action_pressed("zoom") if InputMap.has_action("zoom") else false
	var target_fov := zoom_fov if zooming else BASE_FOV
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 14.0))

	var input := Vector2.ZERO
	if InputMap.has_action("move_forward"):
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	dir = dir.normalized() * SPEED
	velocity.x = dir.x
	velocity.z = dir.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, zone_min.x, zone_max.x)
	global_position.z = clampf(global_position.z, zone_min.y, zone_max.y)
