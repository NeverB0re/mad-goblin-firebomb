class_name Fx
extends RefCounted
## 단색 로우폴리 스타일의 파티클과 모델 생성 도우미.

const FLAME_COLORS := [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.1, 0.95), Color(0.85, 0.15, 0.05, 0.7), Color(0.1, 0.05, 0.03, 0.0)]
const SMOKE_COLORS := [Color(0.25, 0.25, 0.25, 0.0), Color(0.3, 0.3, 0.3, 0.55), Color(0.55, 0.55, 0.55, 0.35), Color(0.7, 0.7, 0.7, 0.0)]
## 연기알 신호 연기 색 (어느 배경에서도 튀는 분홍)
const PAINT_COLOR := Color(1.0, 0.18, 0.72)


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


## 탄종별 고블린식 모델 (겉은 엉성하게 삐뚤빼뚤, 실제 위력은 겉모습과 무관).
## 고폭탄(기본 폭탄) = 검고 둥근 쇠공 + 쇠 꼭지 + 꼬인 심지, 화염 항아리 = 기름 먹인 천으로 막고 밧줄로 동인 큰 질항아리,
## 기름 단지 = 마개를 끈으로 묶은 기름 단지, 조명탄 = 가늘고 긴 종이 통 + 끝의 불꽃.
static func ammo_model(kind: int, model_scale := 1.0, with_flame := true) -> Node3D:
	var root := Node3D.new()
	var spark_at := Vector3.ZERO
	match kind:
		AmmoType.Kind.HE:
			# 전형적인 폭탄: 까만 쇠공, 위에 쇠 꼭지, 꼬불꼬불한 심지 끝에 불똥
			var iron := Models.mat(Color(0.09, 0.09, 0.1), 0.45, 0.5)
			var cap := Models.mat(Color(0.5, 0.46, 0.4), 0.5, 0.7)
			Models.ball(root, 0.11, Vector3.ZERO, iron, 12)
			Models.cyl(root, 0.035, 0.042, 0.05, Vector3(0, 0.115, 0), cap, Vector3.ZERO, 8)
			Models.cyl(root, 0.045, 0.045, 0.012, Vector3(0, 0.095, 0), cap, Vector3.ZERO, 8)
			var cord := Models.mat(Color(0.78, 0.7, 0.5))
			Models.cyl(root, 0.009, 0.009, 0.05, Vector3(0.008, 0.16, 0), cord, Vector3(0, 0, -0.35))
			Models.cyl(root, 0.009, 0.009, 0.04, Vector3(0.022, 0.2, 0), cord, Vector3(0, 0, 0.4))
			# 쇠공에 비친 하이라이트 (둥근 느낌)
			Models.ball(root, 0.025, Vector3(-0.05, 0.05, 0.075), Models.mat(Color(0.45, 0.45, 0.5), 0.3, 0.6), 5)
			spark_at = Vector3(0.012, 0.225, 0)
		AmmoType.Kind.FIRE:
			# 큼직한 질항아리: 불룩한 몸통, 좁은 목, 기름 먹인 천 마개에서 불길이 솟는다. 밧줄로 칭칭 동였다
			var clay := Models.mat(Color(0.62, 0.32, 0.16), 0.9)
			var clay_dark := Models.mat(Color(0.42, 0.2, 0.1), 0.9)
			var rope := Models.mat(Color(0.8, 0.68, 0.42), 1.0)
			var rag := Models.mat(Color(0.3, 0.24, 0.18), 1.0)
			var body := Models.ball(root, 0.13, Vector3(0, -0.01, 0), clay, 10)
			body.scale = Vector3(1.0, 0.95, 1.0)
			Models.cyl(root, 0.09, 0.12, 0.05, Vector3(0, -0.12, 0), clay_dark, Vector3.ZERO, 10)
			Models.cyl(root, 0.06, 0.08, 0.07, Vector3(0, 0.13, 0), clay, Vector3.ZERO, 10)
			Models.cyl(root, 0.075, 0.075, 0.02, Vector3(0, 0.17, 0), clay_dark, Vector3.ZERO, 10)
			# 밧줄: 허리에 두 바퀴, 목에서 내려오는 고리 둘
			Models.cyl(root, 0.133, 0.133, 0.018, Vector3(0, 0.0, 0), rope, Vector3(0.05, 0, 0), 12)
			Models.cyl(root, 0.125, 0.125, 0.018, Vector3(0, -0.05, 0), rope, Vector3(-0.06, 0, 0.03), 12)
			for sx in [-1, 1]:
				Models.box(root, Vector3(0.015, 0.14, 0.02), Vector3(sx * 0.1, 0.07, 0), rope, Vector3(0, 0, sx * 0.55))
			# 천 마개 (불룩하게 비어져 나온 기름 천)
			Models.ball(root, 0.06, Vector3(0.005, 0.2, 0), rag, 6)
			Models.box(root, Vector3(0.04, 0.07, 0.012), Vector3(0.05, 0.17, 0.04), rag, Vector3(0.2, 0.3, -0.5))
			spark_at = Vector3(0, 0.25, 0)
		AmmoType.Kind.OIL:
			# 미끈기름: 목이 긴 유리병 속에 검게 출렁이는 기름, 넘쳐 병을 타고 흘러내린 기름 줄기, 기름 먹은 천 마개
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.85, 0.7, 0.35, 0.35)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.metallic = 0.2
			var oil := Models.mat(Color(0.05, 0.04, 0.02), 0.08, 0.35)
			var rag := Models.mat(Color(0.35, 0.28, 0.18), 1.0)
			Models.ball(root, 0.1, Vector3(0, -0.04, 0), oil, 10)
			var shell := Models.ball(root, 0.12, Vector3(0, -0.03, 0), glass, 10)
			shell.scale = Vector3(1.0, 1.05, 1.0)
			Models.cyl(root, 0.035, 0.045, 0.12, Vector3(0, 0.12, 0), glass, Vector3.ZERO, 8)
			Models.cyl(root, 0.025, 0.03, 0.1, Vector3(0, 0.1, 0), oil, Vector3.ZERO, 6)
			Models.cyl(root, 0.045, 0.04, 0.05, Vector3(0, 0.2, 0), rag, Vector3.ZERO, 6)
			# 흘러내린 기름 줄기 셋과 바닥에 맺힌 방울
			for k in 3:
				var ang := k * 2.1 + 0.4
				Models.box(root, Vector3(0.025, 0.14, 0.012), Vector3(cos(ang) * 0.115, 0.02, sin(ang) * 0.115), oil, Vector3(0, -ang, 0.1))
			Models.ball(root, 0.025, Vector3(0.02, -0.15, 0.06), oil, 5)
			spark_at = Vector3(-1, -1, -1)
		AmmoType.Kind.PAINT:
			# 연기알: 분홍 유리 구슬. 속이 은은히 빛나고 가는 분홍 연기가 새어 나온다
			var marble := Models.mat(PAINT_COLOR, 0.15, 0.1, 0.8)
			var core := Models.mat(PAINT_COLOR.lightened(0.5), 0.3, 0.0, 1.5)
			Models.ball(root, 0.09, Vector3.ZERO, marble, 10)
			Models.ball(root, 0.05, Vector3.ZERO, core, 6)
			Models.ball(root, 0.02, Vector3(-0.04, 0.045, 0.05), Models.mat(Color(1, 1, 1), 0.1, 0.0, 1.0), 4)
			if with_flame:
				var wisp := _particles(10, 0.8, 0.08, false, [Color(PAINT_COLOR, 0.0), Color(PAINT_COLOR, 0.6), Color(PAINT_COLOR.lightened(0.4), 0.0)])
				var wpm: ParticleProcessMaterial = wisp.process_material
				wpm.direction = Vector3.UP
				wpm.spread = 25.0
				wpm.initial_velocity_min = 0.15
				wpm.initial_velocity_max = 0.35
				wpm.gravity = Vector3(0, 0.3, 0)
				wisp.position = Vector3(0, 0.08, 0)
				root.add_child(wisp)
			spark_at = Vector3(-1, -1, -1)
		AmmoType.Kind.FLARE:
			var paper := Models.mat(Color(0.93, 0.86, 0.6), 0.95)
			var stripe := Models.mat(Color(0.25, 0.2, 0.15), 0.9)
			Models.cyl(root, 0.035, 0.04, 0.42, Vector3.ZERO, paper, Vector3(0, 0, 0.06))
			for y in [-0.12, 0.05]:
				Models.cyl(root, 0.042, 0.042, 0.02, Vector3(0.002 * y, y, 0), stripe, Vector3(0, 0, 0.06))
			spark_at = Vector3(-0.013, 0.22, 0)
	if with_flame and spark_at.y > -1.0:
		# 화염 항아리는 천 마개에서 큰 불길, 나머지는 심지 끝의 작은 불똥
		var big := kind == AmmoType.Kind.FIRE
		var flame := fire(Vector3(0.03, 0.02, 0.03) if big else Vector3(0.01, 0.01, 0.01), 16 if big else 10, 0.1 if big else 0.06)
		var pm: ParticleProcessMaterial = flame.process_material
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.6
		pm.spread = 25.0 if big else 60.0
		flame.lifetime = 0.35 if big else 0.25
		flame.position = spark_at
		flame.name = "Flame"
		root.add_child(flame)
	root.scale = Vector3.ONE * model_scale
	return root

## 큼직한 충격파 링 (착탄 연출). 바닥과 평행하게 퍼지며 사라진다.
## radius는 링 바깥 가장자리. hold: 다 퍼진 뒤 그 크기로 잠깐 머문다 (범위를 눈으로 가늠하게).
static func shockwave(parent: Node, pos: Vector3, radius: float, color := Color(1.0, 0.95, 0.8, 0.8), hold := 0.0) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	# 링 두께는 반경과 상관없이 비슷하게 (큰 링이 뭉툭해지지 않게)
	tm.inner_radius = 1.0 - clampf(0.45 / maxf(radius, 0.5), 0.04, 0.18)
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 범위 표시 링은 벽에 가려도 보인다
	m.no_depth_test = hold > 0.0
	m.albedo_color = color
	ring.material_override = m
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.2, 0)
	ring.scale = Vector3.ONE * 0.3
	var grow := 0.3 if hold > 0.0 else 0.35
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, minf(radius * 0.4, 1.2), radius), grow).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if hold > 0.0:
		tw.tween_interval(hold)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	else:
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, grow)
	free_after(ring, grow + hold + 0.45)


## 폭발 범위 동심원: 바깥 흰 링 = 구조물이 부서지는 끝, 안쪽 주황 링 = 인물이 쓰러지는 끝.
## 실제 판정 반경과 똑같은 크기로 잠깐 머물렀다 사라진다 (연출이 아니라 정보).
static func blast_rings(parent: Node, pos: Vector3, break_radius: float, kill_radius: float) -> void:
	shockwave(parent, pos, break_radius, Color(1.0, 0.97, 0.85, 0.85), 0.35)
	if kill_radius > 0.0:
		shockwave(parent, pos, kill_radius, Color(1.0, 0.45, 0.1, 0.9), 0.35)


static var _puff_mesh: QuadMesh

## 연기알이 날아가며 남기는 가는 분홍 연기 한 덩이. 날아가는 동안 짧은 간격으로 떨어뜨리면
## 지나간 길을 따라 가는 연기 줄이 되어 몇 초 동안 공중에 남았다가 흩어진다 (다음 투척의 길잡이).
static func trail_puff(parent: Node, pos: Vector3, life := 6.0) -> void:
	if _puff_mesh == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(PAINT_COLOR.lightened(0.15), 0.6)
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2(0.16, 0.16)
		_puff_mesh.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = _puff_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, life)
	tw.tween_property(mi, "global_position", pos + Vector3(0, 0.6, 0), life)
	tw.tween_property(mi, "transparency", 1.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## 연기알이 떨어진 자리: 분홍 연기가 퍽 터지고 가는 분홍 연기 기둥이 한동안 솟는다 (밤에도 보인다).
static func signal_smoke(parent: Node, pos: Vector3) -> void:
	var puff := burst(24, 2.5, 0.6, [Color(PAINT_COLOR, 0.8), Color(PAINT_COLOR.lightened(0.4), 0.0)], false)
	puff.lifetime = 1.6
	parent.add_child(puff)
	puff.global_position = pos
	puff.emitting = true
	free_after(puff, 2.0)
	var col := _particles(30, 6.0, 0.5, false, [Color(PAINT_COLOR, 0.0), Color(PAINT_COLOR, 0.6), Color(PAINT_COLOR.lightened(0.5), 0.0)])
	col.add_to_group("signal_smoke")
	col.local_coords = false
	var pm: ParticleProcessMaterial = col.process_material
	pm.direction = Vector3.UP
	pm.spread = 5.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.1, 0)
	parent.add_child(col)
	col.global_position = pos + Vector3(0, 0.2, 0)
	parent.get_tree().create_timer(12.0, false, true).timeout.connect(Callable(col, "set").bind("emitting", false))
	free_after(col, 18.0)


static var _oil_tex: GradientTexture2D

## 기름 자국: 맞은 면을 따라 번들거리는 검은 기름이 묻고, 벽·지붕이면 아래로 흘러 바닥에도 고인다 (공중에 뜬 원판 대신).
static func oil_mark(parent: Node, pos: Vector3, normal: Vector3, radius: float) -> Array:
	if _oil_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.03, 0.025, 0.015, 0.95))
		g.set_color(1, Color(0.03, 0.025, 0.015, 0.0))
		g.add_point(0.62, Color(0.05, 0.04, 0.03, 0.85))
		g.add_point(0.72, Color(0.05, 0.04, 0.03, 0.0))
		_oil_tex = GradientTexture2D.new()
		_oil_tex.gradient = g
		_oil_tex.fill = GradientTexture2D.FILL_RADIAL
		_oil_tex.fill_from = Vector2(0.5, 0.5)
		_oil_tex.fill_to = Vector2(1.0, 0.5)
		_oil_tex.width = 64
		_oil_tex.height = 64
	var out := []
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	# 맞은 면에 큰 자국 (가장자리를 감싸도록 깊게 비춘다) + 튄 방울 둘
	for spot in [[Vector3.ZERO, 1.0, 2.0], [side * 0.9, 0.35, 1.0], [-side.cross(up) * 0.8, 0.3, 1.0]]:
		var d := Decal.new()
		d.texture_albedo = _oil_tex
		var r: float = radius * spot[1]
		d.size = Vector3(r * 2.0, spot[2], r * 2.0)
		d.cull_mask = 1
		parent.add_child(d)
		d.global_transform = Transform3D(basis, pos + spot[0] * radius * 0.6)
		out.append(d)
	# 벽이나 지붕 옆면에 맞으면 흘러내려 그 아래에도 고인다
	if up.y < 0.8:
		var d := Decal.new()
		d.texture_albedo = _oil_tex
		var h := pos.y + 1.0
		d.size = Vector3(radius * 1.4, h, radius * 1.4)
		d.cull_mask = 1
		parent.add_child(d)
		d.global_position = Vector3(pos.x, pos.y - h * 0.5 + 0.5, pos.z) + up * radius * 0.4
		out.append(d)
	# 흘러내리는 기름 방울
	var drip := burst(12, 1.2, 0.08, [Color(0.04, 0.03, 0.02, 1.0), Color(0.04, 0.03, 0.02, 0.0)], false)
	drip.one_shot = false
	drip.explosiveness = 0.0
	drip.lifetime = 0.8
	parent.add_child(drip)
	drip.global_position = pos
	drip.emitting = true
	parent.get_tree().create_timer(2.0, false, true).timeout.connect(Callable(drip, "set").bind("emitting", false))
	free_after(drip, 3.0)
	return out


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
