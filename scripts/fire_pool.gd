class_name FirePool
extends Node3D
## 화염병이 깨진 자리에 몇 초간 남는 불웅덩이. 범위 안의 가연물에 점화 시간을 누적하고,
## 지나가는 적에게 불을 붙인다. 불은 고정 틱 기준으로 계산하고 무작위 값을 쓰지 않는다.

var radius := 2.5
var duration := 5.0
var burn_multiplier := 1.0
var active := true
var _t := 0.0
var _fire: GPUParticles3D
var _light: OmniLight3D


func setup(p_radius: float, p_duration: float, p_burn_multiplier: float) -> FirePool:
	radius = p_radius
	duration = p_duration
	burn_multiplier = p_burn_multiplier
	add_to_group("fire_pool")
	_fire = Fx.fire(Vector3(radius * 0.6, 0.05, radius * 0.6), int(radius * radius * 7.0), 0.55)
	add_child(_fire)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 2.5
	_light.omni_range = radius * 3.0
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)
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
		if block.distance_to_point(p) <= radius:
			block.add_heat(delta * burn_multiplier, burn_multiplier)
	for e in get_tree().get_nodes_in_group("enemy"):
		var enemy := e as Enemy
		if enemy.dead:
			continue
		var ep := enemy.global_position
		var flat := Vector2(ep.x - p.x, ep.z - p.z).length()
		if flat <= radius + 0.35 and ep.y > p.y - 2.0 and ep.y < p.y + 1.5:
			enemy.ignite()
	if _t >= duration:
		active = false
		remove_from_group("fire_pool")
		_fire.emitting = false
		var tw := create_tween()
		tw.tween_property(_light, "light_energy", 0.0, 0.8)
		Fx.free_after(self, 1.5)
