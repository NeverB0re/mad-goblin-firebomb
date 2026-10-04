class_name Missile
extends Node3D
## 후방 고블린 진지에서 쏘아 올린 탄도미사일 (가죽끈으로 묶은 거대 로켓). 플레어건이 지정한 지점에 떨어진다.
## 대공 발리스타가 하나라도 남아 있으면 날아오는 도중 발리스타 화살에 맞아 공중에서 터진다 (피해 없음).
## 시간은 물리 틱으로 세서 언제나 같다.

const DELAY_TICKS := 60
const FLIGHT_TICKS := 90
const RADIUS := 9.0
const STRENGTH := 900.0
## 엄폐와 상관없이 쓰러뜨리는 거리
const KILL_RADIUS := 6.0

var _stage: Stage
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _tick := 0
var _intercept := false
var _done := false
var _model: Node3D


func setup(stage: Stage, target: Vector3) -> void:
	_stage = stage
	_target = target
	_from = target + Vector3(-25, 70, 30)
	_intercept = stage.aa_alive()
	_model = Node3D.new()
	add_child(_model)
	var iron := Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	var wood := Models.mat(Color(0.42, 0.28, 0.16))
	Models.cyl(_model, 0.5, 0.6, 4.0, Vector3.ZERO, iron, Vector3(0, 0, 0.06), 8)
	Models.cyl(_model, 0.0, 0.55, 1.1, Vector3(0, 2.5, 0), iron, Vector3.ZERO, 8)
	for a in [0.0, 2.1, 4.2]:
		Models.box(_model, Vector3(0.12, 1.1, 0.8), Vector3(cos(a) * 0.6, -1.6, sin(a) * 0.6), wood, Vector3(0, -a, 0))
	Models.box(_model, Vector3(1.3, 0.1, 1.3), Vector3(0, 0.6, 0), Models.mat(Color(0.5, 0.35, 0.2)), Vector3(0.1, 0, 0.12))
	var trail := Fx.fire(Vector3(0.3, 0.3, 0.3), 50, 0.9)
	trail.local_coords = false
	trail.position = Vector3(0, -2.2, 0)
	_model.add_child(trail)
	_model.visible = false
	global_position = _from
	add_to_group("missile")


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_tick += 1
	if _tick < DELAY_TICKS:
		return
	if _tick == DELAY_TICKS:
		_model.visible = true
		Sfx.play(_stage, "flight", _target, 6.0)
	var k := float(_tick - DELAY_TICKS) / FLIGHT_TICKS
	var p := _from.lerp(_target, k)
	global_position = p
	_model.look_at(_target, Vector3.UP)
	_model.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	if _intercept and k >= 0.5:
		_done = true
		# 발리스타 화살에 맞아 공중에서 터진다 (땅에는 피해 없음)
		Sfx.play(_stage, "boom", p, 2.0)
		var burst := Fx.burst(50, 9.0, 0.8, Fx.FLAME_COLORS)
		_stage.add_child(burst)
		burst.global_position = p
		burst.emitting = true
		Fx.free_after(burst, 2.0)
		Fx.smoke_puff(_stage, p, 3.0)
		queue_free()
		return
	if k >= 1.0:
		_done = true
		_stage.explode(_target, RADIUS, STRENGTH)
		# 탄도미사일은 엄폐를 무시한다: 가까운 인물은 벽·지붕 너머라도 날아간다
		for a in get_tree().get_nodes_in_group("actors"):
			if not a.dead and a.chest().distance_to(_target) < KILL_RADIUS:
				a.defeat("blast")
		_stage.hitstop(0.12)
		queue_free()
