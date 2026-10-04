class_name OilSlick
extends Node3D
## 기름탄이 남긴 기름 웅덩이. 폭발 없이 넓게 퍼지고, 범위 안 블록에 기름을 묻힌다.
## 불(불웅덩이, 타는 블록, 폭발, 이웃한 타는 기름)이 닿으면 크게 타오른다.
## 기름만으로는 아무것도 부서지지 않는다.

const LIFETIME := 45.0
## 점화되면 생기는 큰 불의 지속 시간과 연소 배수
const BURN_DURATION := 8.0
const BURN_MULTIPLIER := 1.8
## 이웃 기름으로 불이 옮겨붙는 지연
const CHAIN_DELAY := 0.25

var radius := 3.5
var ignited := false
var _age := 0.0
var _chain_timer := -1.0
var _disc: MeshInstance3D


func setup(p_radius: float) -> OilSlick:
	radius = p_radius
	add_to_group("oil")
	_disc = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 14
	cm.rings = 1
	_disc.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.04, 0.03, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.3
	_disc.material_override = m
	_disc.position = Vector3(0, 0.03, 0)
	add_child(_disc)
	var splat := Fx.burst(14, 3.0, 0.18, [Color(0.08, 0.06, 0.04, 1), Color(0.08, 0.06, 0.04, 0)], false)
	add_child(splat)
	splat.emitting = true
	Fx.free_after(splat, 1.5)
	return self


## 범위 안 블록에 기름을 묻힌다 (불이 빨리 붙고 빨리 약해진다. 젖은 목재도 탈 수 있게 된다).
func coat_blocks() -> void:
	for b in get_tree().get_nodes_in_group("blocks"):
		var block := b as Block
		if not block.burnt and block.distance_to_point(global_position) <= radius:
			block.coat_oil()


func ignite_now() -> void:
	if ignited:
		return
	ignited = true
	remove_from_group("oil")
	var stage := get_parent()
	var pool := FirePool.new()
	stage.add_child(pool)
	pool.global_position = global_position
	pool.setup(radius, BURN_DURATION, BURN_MULTIPLIER, true)
	# 이웃 기름으로 번진다
	for o in get_tree().get_nodes_in_group("oil"):
		var other := o as OilSlick
		if other.global_position.distance_to(global_position) <= radius + other.radius + 0.5:
			other.ignite_after(CHAIN_DELAY)
	Fx.free_after(self, 0.1)


func ignite_after(seconds: float) -> void:
	if not ignited and _chain_timer < 0.0:
		_chain_timer = seconds


func _near_fire() -> bool:
	var p := global_position
	for f in get_tree().get_nodes_in_group("fire_pool"):
		var pool := f as FirePool
		if pool.global_position.distance_to(p) <= pool.radius + radius:
			return true
	for b in get_tree().get_nodes_in_group("flammable"):
		var block := b as Block
		if block.burning and block.distance_to_point(p) <= radius:
			return true
	return false


func _physics_process(delta: float) -> void:
	if ignited:
		return
	_age += delta
	if _chain_timer >= 0.0:
		_chain_timer -= delta
		if _chain_timer < 0.0:
			ignite_now()
			return
	if _near_fire():
		ignite_now()
		return
	if _age > LIFETIME:
		ignited = true
		remove_from_group("oil")
		Fx.free_after(self, 0.1)
