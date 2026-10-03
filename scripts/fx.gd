class_name Fx
extends RefCounted
## 단색 로우폴리 스타일의 파티클과 모델 생성 도우미.

const FLAME_COLORS := [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.1, 0.95), Color(0.85, 0.15, 0.05, 0.7), Color(0.1, 0.05, 0.03, 0.0)]
const SMOKE_COLORS := [Color(0.25, 0.25, 0.25, 0.0), Color(0.3, 0.3, 0.3, 0.55), Color(0.55, 0.55, 0.55, 0.35), Color(0.7, 0.7, 0.7, 0.0)]


static func _gradient(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _quad(size: float, additive: bool) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	return q


static func _particles(amount: int, lifetime: float, quad_size: float, additive: bool, colors: Array) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.color_ramp = _gradient(colors)
	p.process_material = pm
	p.draw_pass_1 = _quad(quad_size, additive)
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 60, 60))
	return p


## 상자 범위에서 위로 피어오르는 불꽃.
static func fire(extents: Vector3, amount: int, quad_size := 0.45) -> GPUParticles3D:
	var p := _particles(amount, 0.8, quad_size, true, FLAME_COLORS)
	var pm: ParticleProcessMaterial = p.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	return p


## 오래 남는 연기 기둥. 다음 투척의 기준점 역할.
static func smoke_column(amount := 28) -> GPUParticles3D:
	var p := _particles(amount, 7.0, 1.4, false, SMOKE_COLORS)
	p.local_coords = false
	var pm: ParticleProcessMaterial = p.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(0.15, 0.2, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.8
	return p


## 한 번 터지는 파편/불씨.
static func burst(amount: int, speed: float, quad_size: float, colors: Array, additive := true) -> GPUParticles3D:
	var p := _particles(amount, 0.9, quad_size, additive, colors)
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var pm: ParticleProcessMaterial = p.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	return p


## 일정 시간 뒤 노드를 지운다.
static func free_after(node: Node, seconds: float) -> void:
	if not node.is_inside_tree():
		return
	node.get_tree().create_timer(seconds, false, true).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())


## 검고 둥근 몸통 + 짧은 목 + 천 심지 + 심지 불꽃.
static func molotov_model(model_scale := 1.0, with_flame := true) -> Node3D:
	var root := Node3D.new()
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.05, 0.06)
	black.roughness = 0.35
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.86, 0.82, 0.72)

	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.21
	sphere.radial_segments = 10
	sphere.rings = 6
	body.mesh = sphere
	body.material_override = black
	root.add_child(body)

	var neck := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.045
	cyl.height = 0.1
	cyl.radial_segments = 8
	neck.mesh = cyl
	neck.material_override = black
	neck.position = Vector3(0, 0.13, 0)
	root.add_child(neck)

	var wick := MeshInstance3D.new()
	var wcyl := CylinderMesh.new()
	wcyl.top_radius = 0.045
	wcyl.bottom_radius = 0.05
	wcyl.height = 0.05
	wcyl.radial_segments = 8
	wick.mesh = wcyl
	wick.material_override = cloth
	wick.position = Vector3(0, 0.15, 0)
	root.add_child(wick)

	if with_flame:
		var flame := fire(Vector3(0.015, 0.01, 0.015), 10, 0.07)
		var pm: ParticleProcessMaterial = flame.process_material
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.3
		flame.lifetime = 0.35
		flame.position = Vector3(0, 0.19, 0)
		flame.name = "Flame"
		root.add_child(flame)

	root.scale = Vector3.ONE * model_scale
	return root
