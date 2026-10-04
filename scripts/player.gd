class_name Player
extends CharacterBody3D
## 3인칭(어깨 너머) 플레이어. 투척 구역 안에서만 이동하고, 시선의 위아래 각도가 곧 투척 각도다.
## 투척 출발점(오른손)은 카메라 중심선 위에 있어서 화면 중앙의 점과 투척 방향이 정확히 일치한다.
## 좌클릭을 누르고 있으면 카메라가 같은 중심선을 따라 앞으로 미끄러져 1인칭으로 줌인한다.

signal throw_requested(origin: Vector3, direction: Vector3)
signal slot_requested(index: int)
signal slot_cycle_requested(step: int)

const SPEED := 4.5
const MOUSE_SENS := 0.0022
const BASE_FOV := 70.0
const EYE_HEIGHT := 1.6
## 시점 회전 중심 기준 카메라 위치 (오른쪽 어깨 너머, 뒤, 위)
const CAMERA_OFFSET := Vector3(0.55, 0.3, 3.2)
## 오른손 위치 = 카메라 중심선 위의 앞쪽 점
const HAND_FORWARD := 0.45
## 준비 자세(1인칭)에서의 카메라 깊이. 중심선 위에서 z만 바뀌므로 조준은 그대로다
const FIRST_PERSON_Z := 0.1
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
var _body: Node3D
var _arm: MeshInstance3D
## 좌클릭을 누르고 있는 동안 준비 자세, 떼면 던진다 (힘은 항상 같다)
var winding := false
var _wind := 0.0
var _follow := 0.0
var _shake := 0.0
var _shake_t := 0.0

const HELD_REST := Vector3(0.45, -0.32, -0.35)
## 1인칭 화면 오른쪽 아래에 들어 올린 화염병이 살짝 보이는 위치
const HELD_WIND := Vector3(1.2, 0.02, -0.62)
const HELD_FOLLOW := Vector3(0.3, -0.05, -0.75)


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
	camera.position = CAMERA_OFFSET
	head.add_child(camera)
	_build_body()
	# 2배 줌: 화면 절반 각도의 탄젠트를 절반으로
	zoom_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(BASE_FOV) * 0.5) * 0.5))
	set_held_model(1.0)


func set_held_model(model_scale: float) -> void:
	if _held:
		_held.queue_free()
	_held_scale = model_scale
	# 카메라 가까이에서는 불꽃 파티클이 하얗게 번지므로 손에 든 모델은 불꽃 없이 표시한다.
	# 들고 있는 자세는 조준점을 가리지 않도록 오른쪽 아래. 던질 때는 카메라 중심선 위의 손 위치에서 출발한다
	_held = Fx.molotov_model(model_scale, false)
	_held.position = HELD_REST
	head.add_child(_held)


## 미친 발명가 고블린 몸체. 던지는 오른팔은 시점을 따라 움직이므로 따로 만든다.
func _build_body() -> void:
	_body = Models.goblin(false)
	add_child(_body)
	var mat := Models.mat(Models.GOBLIN_SKIN, 0.8)
	# 오른팔: 어깨에서 손(투척 출발점)까지, 시점의 위아래 각도를 따라 움직인다
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.12, 0.12, 0.45)
	arm.mesh = arm_mesh
	arm.material_override = mat
	arm.name = "Arm"
	_arm = arm
	arm.position = Vector3(0.36, -0.28, -0.12)
	head.add_child(arm)


func set_zone(center: Vector3, half_extents: Vector2) -> void:
	zone_min = Vector2(center.x, center.z) - half_extents
	zone_max = Vector2(center.x, center.z) + half_extents


## 화면 중앙(조준점)에서 나가는 투척 방향과 출발점.
## 카메라가 줌인 중이어도 값이 바뀌지 않도록 시점 회전 중심(head) 기준으로 계산한다.
func throw_direction() -> Vector3:
	return -head.global_transform.basis.z


func throw_origin() -> Vector3:
	# 카메라 중심선 위, 플레이어 오른손 위치
	return head.global_transform * Vector3(CAMERA_OFFSET.x, CAMERA_OFFSET.y, -HAND_FORWARD)


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
				if cooldown <= 0.0:
					winding = true
			MOUSE_BUTTON_WHEEL_UP:
				slot_cycle_requested.emit(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				slot_cycle_requested.emit(1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if winding:
			winding = false
			_throw()
	elif event.is_action_pressed("ammo_1"):
		slot_requested.emit(0)
	elif event.is_action_pressed("ammo_2"):
		slot_requested.emit(1)


func _throw() -> void:
	if cooldown > 0.0:
		return
	cooldown = THROW_COOLDOWN
	_follow = 1.0
	throw_requested.emit(throw_origin(), throw_direction())


## 화면 흔들림 (연출 전용. h/v_offset은 카메라 변환을 바꾸지 않아 투척 방향에 영향 없음)
func add_shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func _process(delta: float) -> void:
	_wind = move_toward(_wind, 1.0 if winding else 0.0, delta * 7.0)
	_follow = maxf(0.0, _follow - delta * 4.0)
	if _held:
		var pose := HELD_REST.lerp(HELD_WIND, ease(_wind, -2.0))
		pose = pose.lerp(HELD_FOLLOW, sin(_follow * PI) * (1.0 - _wind))
		_held.position = pose
		_held.rotation = Vector3(-_wind * 0.9, 0, 0)
	if _arm:
		var hand := _held.position if _held else HELD_REST
		var shoulder := Vector3(0.28, -0.22, 0.1)
		_arm.position = (shoulder + hand) * 0.5
		_arm.scale = Vector3(1, 1, maxf(0.3, shoulder.distance_to(hand) / 0.45))
		if shoulder.distance_to(hand) > 0.01:
			_arm.look_at(head.to_global(hand), head.global_transform.basis.y)
	# 준비 자세: 같은 중심선을 따라 1인칭까지 줌인, 몸은 숨긴다
	var fp := ease(_wind, -2.0)
	camera.position = Vector3(CAMERA_OFFSET.x, CAMERA_OFFSET.y, lerpf(CAMERA_OFFSET.z, FIRST_PERSON_Z, fp))
	if _body:
		_body.visible = fp < 0.6
	if _arm:
		_arm.visible = fp < 0.6
	_shake = maxf(0.0, _shake - delta * 1.8)
	_shake_t += delta
	var s := _shake * _shake * 0.35
	camera.h_offset = sin(_shake_t * 47.0) * s
	camera.v_offset = cos(_shake_t * 39.0) * s


func _physics_process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
	if _held:
		_held.visible = cooldown <= THROW_COOLDOWN * 0.4

	var zooming := Input.is_action_pressed("zoom") if InputMap.has_action("zoom") else false
	var target_fov := zoom_fov if zooming else BASE_FOV
	# 준비 자세에서는 살짝 조여서 집중되는 느낌
	target_fov *= 1.0 - 0.08 * _wind
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
