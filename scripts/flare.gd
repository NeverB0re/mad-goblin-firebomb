class_name Flare
extends Node3D
## 조명탄: 착탄 지점에서 위로 솟아 몇 초간 주변을 밝힌다. 파괴력은 없다.
## 솟는 높이와 밝기 지속 시간은 고정이다. 불빛은 짧고(몇 초) 좁다: 비춘 동안에 던져야 하고, 한 발로 진지 전체를 밝힐 수 없다.
## 밤의 인간들은 불빛이 궁금해 구경하러 나온다 (Commander.lure_path). 모바일 예산에 맞춰 광원은 하나만, 그림자는 그리지 않는다
## (새 조명탄이 뜨면 이전 조명탄의 빛은 꺼진다).

const RISE_TIME := 0.9

var height := 15.0
var duration := 6.0
var _t := 0.0
var _base := Vector3.ZERO
var _light: OmniLight3D
var _core: MeshInstance3D
var _sparks: GPUParticles3D


## 착탄 지점(at)에서 솟아오른다. 트리에 붙이고 위치를 정한 뒤에 부른다.
func setup(at: Vector3, p_height: float, p_duration: float) -> Flare:
	height = p_height
	duration = p_duration
	_base = at
	global_position = at
	for f in get_tree().get_nodes_in_group("flare"):
		if f != self:
			f.extinguish()
	add_to_group("flare")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.9, 0.7)
	_light.light_energy = 0.0
	_light.omni_range = 20.0
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = false
	add_child(_light)
	_core = Models.ball(self, 0.25, Vector3.ZERO, Models.mat(Color(1.0, 0.95, 0.8), 0.5, 0.0, 6.0), 6)
	_sparks = Fx.fire(Vector3(0.1, 0.1, 0.1), 30, 0.25)
	_sparks.local_coords = false
	add_child(_sparks)
	return self


## 비추고 있는 중인지 (솟아오른 뒤부터 꺼지기 전까지).
func is_lit() -> bool:
	return _t >= RISE_TIME * 0.6 and _t < RISE_TIME + duration


## 착탄 지점.
func base() -> Vector3:
	return _base


func extinguish() -> void:
	_t = maxf(_t, RISE_TIME + duration)


func _process(delta: float) -> void:
	_t += delta
	if _t < RISE_TIME:
		var k := _t / RISE_TIME
		global_position = _base + Vector3.UP * height * (1.0 - pow(1.0 - k, 2.0))
		_light.light_energy = 1.0 * k
	elif _t < RISE_TIME + duration:
		# 천천히 내려오며 밝게 비춘다
		var k := (_t - RISE_TIME) / duration
		global_position = _base + Vector3.UP * (height - k * 2.0)
		# 끝나기 직전까지 밝게 유지하다가 마지막에 빠르게 어두워진다
		_light.light_energy = 4.0 * (1.0 - pow(k, 6.0))
	else:
		_light.light_energy = 0.0
		_core.visible = false
		_sparks.emitting = false
		remove_from_group("flare")
		set_process(false)
		Fx.free_after(self, 1.0)
