class_name Projectile
extends Node3D
## 물리 엔진에 맡기지 않고 고정 틱에서 직접 적분하는 투척체.
## 같은 위치·방향·탄종이면 항상 같은 곳에 떨어진다 (무작위 흔들림 없음).

signal impacted(projectile: Projectile, position: Vector3, normal: Vector3, collider: Object)

const GRAVITY := 9.8
## 1 = 지형/블록, 2 = 적
const HIT_MASK := 1 | 2
const MAX_TIME := 20.0

var ammo: AmmoType
var velocity := Vector3.ZERO
var exclude: Array[RID] = []
var flight_time := 0.0
var done := false
var _model: Node3D


func launch(origin: Vector3, direction: Vector3, ammo_type: AmmoType, excluded: Array[RID] = []) -> void:
	ammo = ammo_type
	exclude = excluded
	global_position = origin
	velocity = direction.normalized() * ammo.throw_speed
	_model = Fx.molotov_model(ammo.model_scale)
	add_child(_model)
	var trail := Fx.fire(Vector3(0.02, 0.02, 0.02), 24, 0.12)
	trail.local_coords = false
	trail.lifetime = 0.3
	var pm: ParticleProcessMaterial = trail.process_material
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	trail.position = Vector3(0, 0.19, 0) * ammo.model_scale
	_model.add_child(trail)


## 한 틱 진행. 고정 틱 간격을 쓰므로 프레임 속도와 무관하게 같은 궤적이 나온다.
func step(dt: float) -> void:
	if done:
		return
	var from := global_position
	var new_velocity := velocity + Vector3.DOWN * GRAVITY * dt
	# 등가속도 운동의 정확한 변위: (v0 + v1) / 2 * dt
	var to := from + (velocity + new_velocity) * 0.5 * dt
	velocity = new_velocity
	flight_time += dt

	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, exclude)
	query.hit_back_faces = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		done = true
		global_position = hit.position
		impacted.emit(self, hit.position, hit.normal, hit.collider)
		queue_free()
		return

	global_position = to
	if _model:
		_model.rotate_x(-dt * 9.0)
	if flight_time > MAX_TIME or to.y < -100.0:
		done = true
		impacted.emit(self, to, Vector3.UP, null)
		queue_free()


func _physics_process(_delta: float) -> void:
	step(1.0 / Engine.physics_ticks_per_second)
