class_name Projectile
extends Node3D
## 물리 엔진에 맡기지 않고 고정 틱에서 직접 적분하는 투척체.
## 같은 위치·방향·탄종이면 항상 같은 곳에 떨어진다 (무작위 흔들림 없음).

signal impacted(projectile: Projectile, position: Vector3, normal: Vector3, collider: Object)

const GRAVITY := 9.8
## 1 = 지형/블록, 2 = 적
const HIT_MASK := 1 | 2
const MAX_TIME := 25.0
## 비행 시계 배율. 궤적(착탄점)은 그대로 두고 날아가는 시간만 늘려 무게감을 준다.
## 투척 속도 × k, 중력 × k² 로 바꾼 것과 같아서 사거리 표는 변하지 않는다.
const FLIGHT_TIME_SCALE := 0.64

var ammo: AmmoType
## 바람: 날아가는 동안 받는 일정한 수평 가속 (m/s²). 스테이지마다 고정이라 영점은 여전히 내 판단이다
var wind := Vector3.ZERO
var velocity := Vector3.ZERO
var exclude: Array[RID] = []
var flight_time := 0.0
var done := false
var _model: Node3D
## 연기알: 지나간 자리에 연기 덩이를 떨어뜨린다
var _smoke_trail := false
var _last_puff := Vector3.INF


func launch(origin: Vector3, direction: Vector3, ammo_type: AmmoType, excluded: Array[RID] = []) -> void:
	ammo = ammo_type
	exclude = excluded
	wind *= ammo.wind_factor
	global_position = origin
	velocity = direction.normalized() * ammo.throw_speed
	_model = Fx.ammo_model(ammo.kind, ammo.model_scale)
	add_child(_model)
	if ammo.kind == AmmoType.Kind.PAINT:
		# 연기알: 날아가는 동안 가는 분홍 연기 줄을 남긴다 (step에서 떨어뜨린다)
		_smoke_trail = true
		return
	if ammo.kind == AmmoType.Kind.OIL:
		return
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
	var new_velocity := velocity + (Vector3.DOWN * GRAVITY + wind) * dt
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
	if _smoke_trail and get_parent():
		# 0.3m마다 한 덩이 (빠르게 날아도 끊기지 않는 가는 줄)
		if _last_puff == Vector3.INF:
			_last_puff = from
		while _last_puff.distance_to(to) >= 0.3:
			_last_puff = _last_puff.move_toward(to, 0.3)
			Fx.trail_puff(get_parent(), _last_puff)
	if _model:
		# 무거운 화염 항아리는 느리게 굴러 묵직해 보인다
		_model.rotate_x(-dt * (3.5 if ammo.kind == AmmoType.Kind.FIRE else 9.0))
	if flight_time > MAX_TIME or to.y < -100.0:
		done = true
		impacted.emit(self, to, Vector3.UP, null)
		queue_free()


func _physics_process(_delta: float) -> void:
	step(FLIGHT_TIME_SCALE / Engine.physics_ticks_per_second)
