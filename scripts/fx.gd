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
	# 노드가 먼저 지워지면 연결도 함께 사라진다
	node.get_tree().create_timer(seconds, false, true).timeout.connect(node.queue_free)


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


## 탄종별 고블린식 모델 (겉은 엉성하게 삐뚤빼뚤, 실제 위력은 겉모습과 무관).
## 화염탄 = 검고 둥근 병 + 천 심지, 고폭탄 = 쇠테 두른 폭탄 항아리 + 짧은 도화선,
## 기름탄 = 마개를 끈으로 묶은 기름 단지, 조명탄 = 가늘고 긴 종이 통 + 끝의 불꽃.
static func ammo_model(kind: int, model_scale := 1.0, with_flame := true) -> Node3D:
	if kind == AmmoType.Kind.FIRE:
		return molotov_model(model_scale, with_flame)
	var root := Node3D.new()
	var spark_at := Vector3.ZERO
	match kind:
		AmmoType.Kind.HE:
			var iron := Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.6)
			var band := Models.mat(Color(0.45, 0.42, 0.38), 0.5, 0.7)
			var pot := Models.ball(root, 0.13, Vector3.ZERO, iron, 10)
			pot.scale = Vector3(1.0, 0.85, 1.05)
			Models.cyl(root, 0.135, 0.135, 0.035, Vector3(0, 0.02, 0), band, Vector3(0.12, 0, -0.08), 10)
			Models.cyl(root, 0.11, 0.11, 0.03, Vector3(0, -0.07, 0), band, Vector3(-0.1, 0, 0.1), 10)
			Models.cyl(root, 0.045, 0.05, 0.06, Vector3(0.01, 0.12, 0), iron)
			Models.cyl(root, 0.008, 0.008, 0.07, Vector3(0.02, 0.18, 0.01), Models.mat(Color(0.75, 0.7, 0.55)), Vector3(0, 0, -0.4))
			spark_at = Vector3(0.035, 0.22, 0.01)
		AmmoType.Kind.OIL:
			var clay := Models.mat(Color(0.48, 0.3, 0.17), 0.9)
			var oil := Models.mat(Color(0.06, 0.05, 0.03), 0.2)
			Models.cyl(root, 0.08, 0.12, 0.2, Vector3(0, -0.02, 0), clay, Vector3(0, 0, 0.08), 9)
			Models.cyl(root, 0.05, 0.08, 0.06, Vector3(0.008, 0.11, 0), clay, Vector3(0, 0, 0.08))
			Models.cyl(root, 0.045, 0.04, 0.05, Vector3(0.012, 0.16, 0), Models.mat(Color(0.6, 0.48, 0.3)))
			Models.box(root, Vector3(0.11, 0.012, 0.02), Vector3(0.012, 0.15, 0.03), Models.mat(Color(0.85, 0.8, 0.65)), Vector3(0, 0.6, 0.2))
			Models.box(root, Vector3(0.03, 0.08, 0.005), Vector3(0.06, 0.02, 0.105), oil, Vector3(0, 0, 0.15))
			spark_at = Vector3(-1, -1, -1)
		AmmoType.Kind.FLAREGUN:
			# 붉은 띠를 감은 굵은 신호탄 통 (가죽끈으로 묶은 고블린 플레어)
			var tube := Models.mat(Color(0.2, 0.18, 0.16), 0.6, 0.3)
			var red := Models.mat(Color(0.9, 0.08, 0.06), 0.8)
			Models.cyl(root, 0.05, 0.055, 0.36, Vector3.ZERO, tube, Vector3(0, 0, 0.1))
			Models.cyl(root, 0.058, 0.058, 0.05, Vector3(0, 0.08, 0), red, Vector3(0, 0, 0.1))
			spark_at = Vector3(-0.02, 0.2, 0)
		AmmoType.Kind.STONE:
			# 울퉁불퉁한 주먹만 한 돌 (불 없음)
			var rock := Models.mat(Color(0.5, 0.48, 0.45), 1.0)
			var lump := Models.ball(root, 0.12, Vector3.ZERO, rock, 6)
			lump.scale = Vector3(1.1, 0.8, 0.95)
			Models.ball(root, 0.07, Vector3(0.06, 0.05, 0.02), rock, 5)
			spark_at = Vector3(-1, -1, -1)
		AmmoType.Kind.FLARE:
			var paper := Models.mat(Color(0.93, 0.86, 0.6), 0.95)
			var stripe := Models.mat(Color(0.25, 0.2, 0.15), 0.9)
			Models.cyl(root, 0.035, 0.04, 0.42, Vector3.ZERO, paper, Vector3(0, 0, 0.06))
			for y in [-0.12, 0.05]:
				Models.cyl(root, 0.042, 0.042, 0.02, Vector3(0.002 * y, y, 0), stripe, Vector3(0, 0, 0.06))
			spark_at = Vector3(-0.013, 0.22, 0)
	if with_flame and spark_at.y > -1.0:
		var flame := fire(Vector3(0.01, 0.01, 0.01), 10, 0.06)
		var pm: ParticleProcessMaterial = flame.process_material
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.6
		pm.spread = 60.0
		flame.lifetime = 0.25
		flame.position = spark_at
		flame.name = "Flame"
		root.add_child(flame)
	root.scale = Vector3.ONE * model_scale
	return root

## 큼직한 충격파 링 (착탄 연출). 바닥과 평행하게 퍼지며 사라진다.
static func shockwave(parent: Node, pos: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.95, 0.8, 0.8)
	ring.material_override = m
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.2, 0)
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, radius * 0.4, radius), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	free_after(ring, 0.5)


## 연기 구름 (착탄 연출, 짧게).
static func smoke_puff(parent: Node, pos: Vector3, size: float) -> void:
	var p := burst(int(10 + size * 6), 2.0 + size, 0.8 + size * 0.4, SMOKE_COLORS, false)
	p.lifetime = 2.0
	var pm: ParticleProcessMaterial = p.process_material
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	free_after(p, 2.5)

static var _scorch_tex: GradientTexture2D

## 그을음 자국: 착탄 자리 땅과 벽에 남는 검은 얼룩 (잠시 뒤 옅어진다). 판정과 무관.
static func scorch(parent: Node, pos: Vector3, radius: float, life := 25.0) -> void:
	if _scorch_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.04, 0.03, 0.02, 0.85))
		g.set_color(1, Color(0.06, 0.05, 0.04, 0.0))
		g.add_point(0.55, Color(0.08, 0.06, 0.05, 0.6))
		_scorch_tex = GradientTexture2D.new()
		_scorch_tex.gradient = g
		_scorch_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_tex.fill_to = Vector2(1.0, 0.5)
		_scorch_tex.width = 64
		_scorch_tex.height = 64
	var d := Decal.new()
	d.texture_albedo = _scorch_tex
	d.size = Vector3(radius * 2.0, 2.0, radius * 2.0)
	d.cull_mask = 1
	parent.add_child(d)
	d.global_position = pos
	d.rotation.y = fmod(pos.x * 7.0 + pos.z * 3.0, TAU)
	var tw := d.create_tween()
	tw.tween_interval(life - 5.0)
	tw.tween_property(d, "modulate:a", 0.0, 5.0)
	free_after(d, life)


## 폭발 섬광: 아주 짧게 주변을 밝히는 불빛 (밤에 특히 잘 보인다).
static func flash(parent: Node, pos: Vector3, energy: float, reach: float, seconds := 0.3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.35)
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	free_after(l, seconds + 0.05)


## 튀는 파편 덩어리: 굴러다니다 사라지는 작은 돌·나무 조각 (충돌층 16, 땅과 서 있는 블록에만 부딪힌다.
## 인물·투척체·무너진 잔해와는 부딪히지 않아 판정에 영향 없음). 방향은 고정 무늬라 무작위 값을 쓰지 않는다.
static func chunks(parent: Node, pos: Vector3, colors: Array, count: int, speed: float) -> void:
	for k in count:
		var body := RigidBody3D.new()
		body.collision_layer = 16
		body.collision_mask = 1
		body.mass = 0.3
		var s := 0.12 + 0.08 * float(k % 3)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(s, s * 0.8, s * 1.2)
		shape.shape = box
		body.add_child(shape)
		Models.box(body, box.size, Vector3.ZERO, Models.mat(colors[k % colors.size()], 0.9))
		parent.add_child(body)
		var a := TAU * k / count + 0.37 * k
		var up := 0.6 + 0.4 * float((k * 7) % 5) / 4.0
		body.global_position = pos + Vector3(cos(a), 0.3, sin(a)) * 0.3
		body.linear_velocity = Vector3(cos(a), up * 1.4, sin(a)).normalized() * speed * (0.7 + 0.3 * float(k % 4) / 3.0)
		body.angular_velocity = Vector3(sin(a * 3.0), cos(a * 2.0), sin(a)) * 8.0
		free_after(body, 3.0 + 0.1 * (k % 5))
