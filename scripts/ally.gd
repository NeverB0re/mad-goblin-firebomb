class_name Ally
extends Actor
## 지원형 스테이지의 동료 고블린. 폭발통을 지고 성문까지 정해진 경로를 일정한 속도로 걷는다.
## 길을 막은 장애물이 남아 있으면 그 앞에서 멈춰 기다리고, 길이 열리면 다시 걷는다.
## 성문 앞에 닿으면 플레이어가 화염탄으로 폭발통을 직접 터뜨린다. 동료는 함께 터지지만 웃으며 날아간다.
## auto_fuse(본편): 걷기 시작할 때 폭발통 심지에 불을 붙인다. 심지가 타 들어가는 모습(불똥, 줄어드는 심지)이 보이고,
## 성문 앞에 닿으면 FUSE_AT_GATE초 뒤 스스로 터진다 (플레이어가 터뜨리지 않아도 된다).
## 동료는 판정 대상이 아니다 (투척에 맞아도 그을릴 뿐 실패 조건이 아니다).

signal barrel_exploded(pos: Vector3)

const STOP_GAP := 2.0

var speed := 1.6
var follow: PathFollow3D
var walking := false
var at_gate := false
var exploded := false
## [{distance: float, cleared: Callable}] 경로 위 장애물 (거리 순)
var obstacles: Array = []
var _barrel: Node3D
var auto_fuse := false
## 성문 앞에 닿은 뒤 스스로 터지기까지 (초)
const FUSE_AT_GATE := 2.5
var _gate_t := 0.0
var _fuse: Node3D
var _spark: GPUParticles3D


func _init() -> void:
	super()
	invulnerable = true
	uses_gravity = false
	set_visual(Models.goblin())
	_barrel = Node3D.new()
	_barrel.position = Vector3(0, 1.0, 0.45)
	visual.add_child(_barrel)
	var black := Models.mat(Color(0.07, 0.07, 0.07), 0.6)
	var white := Models.mat(Color(0.95, 0.95, 0.95), 0.8)
	Models.cyl(_barrel, 0.32, 0.32, 0.8, Vector3.ZERO, black, Vector3(0.1, 0, 0.05), 10)
	for y in [-0.2, 0.2]:
		Models.cyl(_barrel, 0.335, 0.335, 0.07, Vector3(0, y, 0), white, Vector3(0.1, 0, 0.05), 10)
	# 심지: 길게 뻗은 검정·노랑 꼰 줄 (타 들어가며 짧아진다)
	_fuse = Node3D.new()
	_fuse.position = Vector3(0.1, 0.42, 0)
	_fuse.rotation.z = -0.5
	_barrel.add_child(_fuse)
	for k in 6:
		Models.cyl(_fuse, 0.022, 0.022, 0.1, Vector3(0, 0.05 + k * 0.1, 0), Models.mat(Color(0.1, 0.09, 0.08) if k % 2 == 0 else Color(1.0, 0.8, 0.12)))
	_fuse.name = "Fuse"


func start() -> void:
	walking = true
	if auto_fuse and _spark == null:
		# 심지에 불: 끝에서 불똥이 튄다
		_spark = Fx.fire(Vector3(0.03, 0.03, 0.03), 14, 0.12)
		_spark.position = Vector3(0, 0.62, 0)
		_fuse.add_child(_spark)


func blocked() -> bool:
	if follow == null:
		return false
	for o in obstacles:
		if not o.cleared.call() and follow.progress >= o.distance - STOP_GAP:
			return true
	return false


## 성문 앞에서만 폭발통이 불에 반응한다. 그 전에는 그을릴 뿐이다.
func on_fire_touch() -> void:
	if at_gate and not exploded:
		_detonate()
	else:
		singe()


func on_direct_hit(ammo: AmmoType) -> void:
	if at_gate and not exploded and ammo.kind == AmmoType.Kind.FIRE:
		_detonate()
	else:
		singe()


func on_blast(pos: Vector3, radius: float) -> void:
	if chest().distance_to(pos) <= radius:
		singe()


func _detonate() -> void:
	exploded = true
	walking = false
	_barrel.visible = false
	barrel_exploded.emit(_barrel.global_position)


func _physics_process(delta: float) -> void:
	super(delta)
	if exploded or follow == null:
		return
	if walking and not at_gate:
		if blocked():
			# 막혀서 발을 동동 구르며 기다린다
			visual.position.y = absf(sin(_anim_t * 8.0)) * 0.05
			return
		follow.progress += speed * delta
		visual.position.y = absf(sin(_anim_t * 7.0)) * 0.08
		if _spark:
			# 걸을수록 심지가 타 들어가 짧아진다 (성문 앞에서 끝까지 거의 다 탄다)
			_fuse.scale.y = lerpf(1.0, 0.25, follow.progress_ratio)
		var arm_l: Node3D = visual.get_node("ArmL")
		arm_l.rotation.x = sin(_anim_t * 7.0) * 0.6
		if follow.progress_ratio >= 0.999:
			at_gate = true
			walking = false
	elif at_gate:
		if auto_fuse:
			_gate_t += delta
			_fuse.scale.y = lerpf(0.25, 0.05, clampf(_gate_t / FUSE_AT_GATE, 0.0, 1.0))
			if _gate_t >= FUSE_AT_GATE:
				_detonate()
				return
		# 성문 앞에서 신나서 들썩이며 기다린다
		visual.position.y = absf(sin(_anim_t * 5.0)) * 0.12
		var arm_r: Node3D = visual.get_node("ArmR")
		arm_r.rotation.z = 2.5 + sin(_anim_t * 10.0) * 0.4
