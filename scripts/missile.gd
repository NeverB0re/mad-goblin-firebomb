class_name Missile
extends Node3D
## 고블린 로켓. 투척 구역 옆 발사대에서 대기하다가, 조명탄이 떨어진 자리(불빛)를 보고 날아간다.
## 대공 발리스타가 하나라도 남아 있으면 날아가는 도중 발리스타 화살에 맞아 공중에서 터진다 (피해 없음).
## 떨어지면 아주 크게 터져 근처 지휘관을 엄폐와 상관없이 모두 쓰러뜨린다: 발리스타만 치우면 거의 한 방에 끝난다.
## 시간은 물리 틱으로 세서 언제나 같다.

signal exploded(pos: Vector3)

## 점화 뒤 발사대에서 불을 뿜는 시간
const DELAY_TICKS := 45
const FLIGHT_TICKS := 120
## 포물선 꼭대기 높이 (발사대와 표적을 잇는 선 위로)
const ARC := 35.0
const RADIUS := 14.0
const STRENGTH := 1400.0
## 엄폐와 상관없이 쓰러뜨리는 거리 (조명탄이 조금 빗나가도 진지가 끝나게)
const KILL_RADIUS := 12.0

var done := false
var _stage: Stage
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _tick := 0
var _intercept := false
var _model: Node3D
var _trail: GPUParticles3D


## model: 발사대에 서 있던 로켓 (그대로 들고 날아간다). 없으면 새로 만든다.
func setup(stage: Stage, target: Vector3, from: Vector3, model: Node3D = null) -> void:
	_stage = stage
	_target = target
	_from = from
	_intercept = stage.aa_alive()
	if model:
		model.get_parent().remove_child(model)
		_model = model
	else:
		_model = Models.rocket()
	_model.transform = Transform3D.IDENTITY
	add_child(_model)
	_trail = Fx.fire(Vector3(0.3, 0.3, 0.3), 60, 1.0)
	_trail.local_coords = false
	_trail.position = Vector3(0, -2.6, 0)
	_model.add_child(_trail)
	global_position = _from
	add_to_group("missile")
	# 점화: 발사대에서 연기와 불을 뿜는다
	Sfx.play(_stage, "windup", _from, 4.0)
	var smoke := Fx.smoke_column(40)
	_stage.add_child(smoke)
	smoke.global_position = _from + Vector3(0, -2.5, 0)
	_stage.get_tree().create_timer(2.5, false, true).timeout.connect(Callable(smoke, "set").bind("emitting", false))
	Fx.free_after(smoke, 10.0)


func target_pos() -> Vector3:
	return _target


func _pos(k: float) -> Vector3:
	return _from.lerp(_target, k) + Vector3.UP * ARC * sin(PI * k)


func _physics_process(_delta: float) -> void:
	if done:
		return
	_tick += 1
	if _tick < DELAY_TICKS:
		# 발사대 위에서 부르르 떤다
		_model.position = Vector3(sin(_tick * 1.7), 0, cos(_tick * 2.3)) * 0.04
		return
	if _tick == DELAY_TICKS:
		_model.position = Vector3.ZERO
		Sfx.play(_stage, "flight", _from, 8.0)
		Sfx.play(_stage, "boom", _from, -4.0)
	var k := float(_tick - DELAY_TICKS) / FLIGHT_TICKS
	var p := _pos(k)
	global_position = p
	var ahead := _pos(minf(k + 0.02, 1.0)) - p
	if ahead.length() > 0.05:
		look_at(p + ahead, Vector3.UP if absf(ahead.normalized().y) < 0.99 else Vector3.FORWARD)
		rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	if _intercept and k >= 0.5:
		done = true
		# 발리스타 화살에 맞아 공중에서 터진다 (땅에는 피해 없음)
		Sfx.play(_stage, "boom", p, 2.0)
		var burst := Fx.burst(50, 9.0, 0.8, Fx.FLAME_COLORS)
		_stage.add_child(burst)
		burst.global_position = p
		burst.emitting = true
		Fx.free_after(burst, 2.0)
		Fx.smoke_puff(_stage, p, 3.0)
		_stage.toast.emit(Texts.t("rocket_shot_down"))
		exploded.emit(p)
		queue_free()
		return
	if k >= 1.0:
		done = true
		_stage.rocket_strike(_target, RADIUS, STRENGTH, KILL_RADIUS)
		exploded.emit(_target)
		queue_free()
