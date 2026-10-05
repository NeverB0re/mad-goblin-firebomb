class_name Stage
extends Node3D
## 한 테스트 스테이지의 상태: 지형, 플레이어(고블린), 인간 시설, 인물, 탄약, 승리/실패 판정.
## 승리 조건은 지휘관을 쓰러뜨리는 것 하나로 통일한다 (확장 기획서 6장). 지휘관이 여럿이면 모두 쓰러뜨려야 한다.
## 깃발은 위치 표식이다 (지휘관이 쓰러지면 그 깃발도 쓰러진다).
## 원칙은 "과장은 판정 뒤에": 궤적·폭발 반경·점화·지휘관 판정은 정직하고 고정, 연출만 부풀린다.

signal state_changed(state: int, message: String)
signal ammo_changed
signal toast(text: String)
signal projectile_thrown(projectile: Projectile)
## 착탄·폭발의 화면 흔들림 (세기 0~1, 추적 화면용)
signal shake_requested(amount: float)
## 승리 판정 확정 (승리 연출 시작). target: 쓰러진 인물 (봉화대를 태운 경우 null), focus: 연출이 비출 곳
signal target_down(target: Actor, cause: String, focus: Vector3)
## 지휘관 하나가 쓰러짐 (남은 표적 표시용)
signal targets_changed
## 최종 로켓이 발사대를 떠남 (추적 화면용)
signal rocket_launched(missile: Missile)
## 조명탄을 보고 글라이더 폭격 고블린이 날아오름 (추적 화면용)
signal bomber_launched(bomber: Bomber)

enum State { PLAYING, CLEARED, FAILED }
## 승리 조건: 지휘관 쓰러뜨리기, 또는 전령 멈추기 (전령을 쓰러뜨리거나 건너야 할 다리를 끊음)
enum Goal { COMMANDER, MESSENGER }

const TRACE_TIME := 30.0
const FAIL_QUIET_TIME := 2.5
const STARTLE_RANGE := 14.0
## 히트스톱 (현실 시간)
const HITSTOP := 0.07

var stage_id := ""
var title := ""
var night := false
## 비: 하늘이 어둡고 빗줄기가 보인다. 비 맞는 목재는 젖은 목재로 짓는다 (처마 밑만 마른다)
var rain := false
## 바람: 투척체가 받는 수평 가속 (m/s²). 깃발과 바람자루가 바람 쪽으로 날린다
var wind := Vector3.ZERO
## 대공 발리스타 (블록). 하나라도 서 있으면 미사일을 쏘아 떨어뜨린다
var ballistas: Array[Block] = []
## 월드 번호 (0부터, 실패 그림과 시작 컷이 쓴다)
var world := 0
var goal: int = Goal.COMMANDER
var state: int = State.PLAYING
var fail_cause := ""
var player: Player
var commander: Commander
## 이 진지의 지휘관 모두 (commander는 첫 번째)
var commanders: Array[Commander] = []
var structures: Array[Structure] = []
var messengers: Array[Messenger] = []
var allies: Array[Ally] = []
## 전령이 건너야 하는 다리: [{blocks: Array (상판), start, end: float (경로상 다리 앞·끝 거리)}]
## 전령이 건너기 전에 상판이 하나라도 끊기면, 전령은 다리 앞까지 달려와 오도 가도 못한다 → 전령 멈추기 성공
var bridges: Array = []
## 승리 연출 카메라 (스테이지마다 정해 둔 위치, 없으면 자동)
var cine_cam_pos := Vector3.INF
## [{type: AmmoType, count: int}]
var ammo_slots: Array = []
var current_slot := 0
var throws := 0
## 탄종별로 던진 수 (별 평가의 보조 목표용)
var thrown := {}
## 발리스타에 격추된 글라이더 수
var shot_down := 0
var elapsed := 0.0
var _projectiles: Array[Projectile] = []
var _quiet := 0.0
var _last_collapse_sound := -10.0
var _flags: Array[Node3D] = []
var _last_shot_warned := false
## 대기 중인 글라이더 폭격 고블린 모델들 (조명탄이 떨어지면 하나씩 날아간다)
var _bombers: Array[Node3D] = []
var bombers_total := 0
## 최종 진지의 발사 버튼과 거대 로켓
var _button: Node3D
var _button_cap: Node3D
var _button_used := false
var _final_rocket: Node3D


# ---------- 구성 ----------

func begin(p_id: String, p_title: String, p_night := false, p_goal := Goal.COMMANDER) -> void:
	goal = p_goal
	stage_id = p_id
	title = p_title
	night = p_night
	_make_ground()


func _make_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.add_to_group("ground")
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200, 2, 1200)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	mesh.mesh = plane
	mesh.material_override = Models.mat(Color(0.2, 0.22, 0.24) if night else Color(0.56, 0.6, 0.48), 1.0)
	ground.add_child(mesh)
	add_child(ground)


## 투척 구역 (center.y가 바위 턱 높이).
func set_zone(center: Vector3, half_extents: Vector2, yaw_deg := 0.0) -> void:
	player = Player.new()
	player.name = "Player"
	# 바위 턱 끝 가까이에서 시작해 아래가 잘 보이게 한다
	player.position = center + Vector3(0, 0, -half_extents.y + 0.6)
	add_child(player)
	player.rotation.y = deg_to_rad(yaw_deg)
	player.set_zone(center, half_extents)
	player.ammo_source = _ammo_for_throw
	player.throw_requested.connect(try_throw)
	player.slot_requested.connect(select_slot)
	player.slot_cycle_requested.connect(func(step): cycle_slot(step))
	player.windup_started.connect(func(): Sfx.play(self, "windup", player.global_position, -10.0))
	if center.y > 0.1:
		_make_perch(center, half_extents)

	_zone_outline(center, half_extents)


func _zone_outline(center: Vector3, half_extents: Vector2) -> void:
	var mat := Models.mat(Color(0.28, 0.18, 0.1))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var w := 0.08
	var hx := half_extents.x + 0.4
	var hz := half_extents.y + 0.4
	for spec in [[Vector3(0, 0, -hz), Vector3(hx * 2, 0.02, w)], [Vector3(0, 0, hz), Vector3(hx * 2, 0.02, w)],
			[Vector3(-hx, 0, 0), Vector3(w, 0.02, hz * 2)], [Vector3(hx, 0, 0), Vector3(w, 0.02, hz * 2)]]:
		Models.box(self, spec[1], center + spec[0] + Vector3(0, 0.08, 0), mat)


## 고블린이 올라선 높은 바위 턱. 앞쪽 끝이 투척 구역 바로 앞이라 아래를 내려다보며 던진다.
func _make_perch(center: Vector3, half_extents: Vector2) -> void:
	var rock := Color(0.55, 0.47, 0.43)
	var rock_dark := Color(0.47, 0.4, 0.37)
	var h := center.y
	var front := center.z - half_extents.y - 0.3
	var back := center.z + half_extents.y + 7.0
	var wide := half_extents.x + 4.0
	add_rock(Vector3(center.x, h * 0.5, (front + back) * 0.5), Vector3(wide * 2.0, h, back - front), rock)
	# 아래로 갈수록 넓어지는 절벽 (로우폴리 층)
	add_rock(Vector3(center.x, h * 0.3, (front + back) * 0.5 + 1.5), Vector3(wide * 2.0 + 4.0, h * 0.6, back - front + 6.0), rock_dark)
	add_rock(Vector3(center.x - 2.0, h * 0.12, (front + back) * 0.5 + 2.5), Vector3(wide * 2.0 + 9.0, h * 0.24, back - front + 10.0), rock)
	# 양옆과 뒤의 바위 턱 (앞은 비워 둔다)
	for sx in [-1.0, 1.0]:
		add_rock(Vector3(center.x + sx * (wide - 0.6), h + 0.6, center.z + 1.0), Vector3(1.2, 1.2, half_extents.y * 2.0 + 4.0), rock_dark)
	add_rock(Vector3(center.x, h + 0.9, back - 0.8), Vector3(wide * 2.0, 1.8, 1.6), rock_dark)
	# 언덕 위 풀밭 (투척 구역 둘레만, 충돌 없음)
	var turf := LowPoly.Builder.new()
	turf.base = Color(0.42, 0.6, 0.24)
	turf.chamfer_box(Transform3D(Basis(), Vector3(0, 0, 0)), Vector3(wide * 2.0 - 1.0, 0.12, back - front - 0.5), 0.05)
	var tm := MeshInstance3D.new()
	tm.name = "Turf"
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	tm.mesh = turf.commit(mat)
	tm.position = Vector3(center.x, h + 0.0, (front + back) * 0.5)
	add_child(tm)


func add_structure() -> Structure:
	var s := Structure.new()
	s.stage = self
	add_child(s)
	structures.append(s)
	s.collapsed.connect(_on_collapsed)
	return s


func add_ammo(type: AmmoType, count: int) -> void:
	ammo_slots.append({"type": type, "count": count})


## 지휘관과 곁에 꽂힌 빨간 깃발.
func add_commander(pos: Vector3, yaw_deg := 180.0, flag_offset := Vector3(1.2, 0, 0.3)) -> Commander:
	var c := Commander.new()
	c.position = pos
	c.rotation.y = deg_to_rad(yaw_deg)
	add_child(c)
	if commander == null:
		commander = c
	commanders.append(c)
	c.defeated.connect(_on_commander_defeated)
	var flag := Models.flag()
	flag.position = pos + flag_offset
	add_child(flag)
	_flags.append(flag)
	c.set_meta("flag", flag)
	return c


func add_guard(pos: Vector3, yaw_deg := 180.0, shield := false) -> Guard:
	var g := Guard.new().setup(shield)
	g.position = pos
	g.rotation.y = deg_to_rad(yaw_deg)
	add_child(g)
	return g


func _path(points: Array) -> PathFollow3D:
	var path := Path3D.new()
	var curve := Curve3D.new()
	for p in points:
		curve.add_point(p)
	path.curve = curve
	add_child(path)
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	path.add_child(follow)
	return follow


## 전령: 첫 투척과 함께 목적지(봉화대)로 정해진 경로를 달린다 (구불구불한 꺾은선).
## 길에는 일정한 간격으로 울타리 기둥을 세워 "몇 칸 앞에 던질지"의 단서로 쓴다.
func add_messenger(points: Array, speed: float, torch := false, cart := false) -> Messenger:
	var m := Messenger.new()
	m.speed = speed
	m.follow = _path(points)
	m.follow.add_child(m)
	if torch:
		m.carry_torch()
	if cart:
		m.ride_cart()
		_rails(points)
	messengers.append(m)
	m.arrived.connect(_on_messenger_arrived.bind(m))
	m.defeated.connect(_on_messenger_defeated)
	var carry := 0.0
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var d := carry
		while d <= a.distance_to(b):
			add_prop(a + dir * d + side * 1.6 + Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2), Color(0.35, 0.33, 0.3))
			d += 8.0
		carry = d - a.distance_to(b)
	return m

## 광차 궤도: 경로를 따라 깔린 레일 두 줄과 침목.
func _rails(points: Array) -> void:
	var iron := Models.mat(Color(0.3, 0.3, 0.33), 0.5, 0.6)
	var wood := Models.mat(Color(0.35, 0.24, 0.15))
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var seg := b - a
		var len := seg.length()
		if len < 0.01:
			continue
		var yaw := atan2(seg.x, seg.z)
		for sx in [-0.45, 0.45]:
			var side: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * sx
			Models.box(self, Vector3(0.08, 0.08, len), (a + b) * 0.5 + side + Vector3(0, 0.05, 0), iron, Vector3(0, yaw, 0))
		var n := int(len / 1.2)
		for k in n:
			Models.box(self, Vector3(1.3, 0.06, 0.2), a + seg * ((k + 0.5) / n) + Vector3(0, 0.02, 0), wood, Vector3(0, yaw, 0))


## 구경하는 마을 고블린 (1월드): 자기 집이 부서져도 박수 치며 좋아한다. 판정과 무관한 장식.
func add_villager(pos: Vector3, yaw_deg := 180.0) -> void:
	var v := Villager.new()
	v.position = pos
	v.rotation.y = deg_to_rad(yaw_deg)
	add_child(v)


## 빗줄기 (플레이어 주변을 따라다닌다).
func make_rain() -> void:
	rain = true
	var p := GPUParticles3D.new()
	p.amount = 600
	p.lifetime = 1.2
	p.visibility_aabb = AABB(Vector3(-60, -30, -80), Vector3(120, 60, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 1, 50)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 28.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = m
	p.draw_pass_1 = quad
	p.position = Vector3(0, 22, -30)
	if player:
		player.add_child(p)
	else:
		add_child(p)


## 지원형 동료 고블린. obstacles: [{distance: float, cleared: Callable}]
func add_ally(points: Array, speed: float, obstacles: Array) -> Ally:
	var a := Ally.new()
	a.speed = speed
	a.follow = _path(points)
	a.follow.add_child(a)
	a.obstacles = obstacles
	a.barrel_exploded.connect(_on_barrel_exploded.bind(a))
	allies.append(a)
	return a


## 장식/표지물 (충돌 있음, 블록 시스템과 무관).
func add_prop(center: Vector3, size: Vector3, color: Color, collide := true) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		node = body
	else:
		node = Node3D.new()
	Models.box(node, size, Vector3.ZERO, Models.mat(color, 1.0))
	node.position = center
	add_child(node)
	return node


## 배경 벽 한 칸 (블록 시스템과 무관, 무엇으로도 안 부서진다). 겉모양은 블록과 같은 로우폴리 재질 모양.
## 진지를 두르는 성벽·담·울타리가 혼자 덩그러니 서 있지 않게 둘레를 이어 준다. style: stone, steel, plank, straw.
func add_wall_prop(center: Vector3, size: Vector3, style: String, yaw := 0.0) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.block_mesh(style, size)
	var colors := {"stone": Block.INFO[Block.Mat.STONE].color, "steel": Block.INFO[Block.Mat.STEEL].color,
		"plank": Block.INFO[Block.Mat.WOOD_BEAM].color, "straw": Block.INFO[Block.Mat.STRAW].color}
	var m := Models.mat(colors.get(style, Color.WHITE), 0.95)
	mi.material_override = m
	body.add_child(mi)
	body.position = center
	body.rotation.y = yaw
	add_child(body)
	return body


## 마당을 두르는 배경 벽 (앞면 제외: 앞면은 진짜 블록 벽). center: 마당 가운데, half: 반폭(x)과 반깊이(z).
## sides: "l"(왼), "r"(오른), "b"(뒤) 중 둘러칠 쪽.
func add_enclosure(center: Vector3, half: Vector2, height: float, style: String, thick := 0.6, sides := "lrb") -> void:
	var y := center.y + height * 0.5
	if "b" in sides:
		add_wall_prop(Vector3(center.x, y, center.z - half.y + thick * 0.5), Vector3(half.x * 2.0, height, thick), style)
	for sx in [-1, 1]:
		if ("l" if sx < 0 else "r") in sides:
			add_wall_prop(Vector3(center.x + sx * (half.x - thick * 0.5), y, center.z), Vector3(thick, height, half.y * 2.0), style)


## 각진 바위 (충돌은 상자 그대로, 겉모양만 울퉁불퉁한 로우폴리 바위).
func add_rock(center: Vector3, size: Vector3, color: Color) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = LowPoly.cached("rock:%s:%s" % [str(size.snapped(Vector3.ONE * 0.01)), str(center.snapped(Vector3.ONE))], func(): return LowPoly.rock_mesh(size, center.x * 1.7 + center.z))
	mi.material_override = Models.mat(color, 1.0)
	body.add_child(mi)
	body.position = center
	add_child(body)
	return body


## 밤의 횃불 (실제 광원 없이 발광 재질).
func add_torch(pos: Vector3, height := 1.8) -> void:
	var t := Models.torch(height)
	t.position = pos
	add_child(t)


func finish_build() -> void:
	for s in structures:
		s.finalize()
	Scenery.build(self)
	if player and not ammo_slots.is_empty():
		_update_held()
	toast.emit.call_deferred(Texts.t("start"))


# ---------- 탄약 ----------

func current_ammo() -> AmmoType:
	return ammo_slots[current_slot].type if not ammo_slots.is_empty() else null


func _ammo_for_throw() -> AmmoType:
	if state != State.PLAYING or ammo_slots.is_empty():
		return null
	if ammo_slots[current_slot].count <= 0:
		toast.emit(Texts.t("empty_slot"))
		return null
	return current_ammo()


## 남은 주력 탄 수: 쾅쾅알과 불항아리. 보조탄(미끈기름, 연기알, 조명탄)은 치지 않는다: 보조탄만 남으면 더 할 수 있는 게 없어 진다.
## 단, 폭격대가 대기 중이면 조명탄은 폭격을 부르는 탄이다 (남은 폭격 수까지). 최종 로켓도 한 발로 친다.
func total_ammo() -> int:
	var n := 0
	for s in ammo_slots:
		match s.type.kind:
			AmmoType.Kind.PAINT, AmmoType.Kind.OIL:
				pass
			AmmoType.Kind.FLARE:
				n += mini(s.count, bombers_left())
			_:
				n += s.count
	if button_ready():
		n += 1
	return n


## 이 탄종이 몇 발 남았는지.
func ammo_count(kind: int) -> int:
	var n := 0
	for s in ammo_slots:
		if s.type.kind == kind:
			n += s.count
	return n


func bombers_left() -> int:
	return _bombers.size()


## 투척 구역 왼쪽 앞 바위 기둥 (폭격대 대기 자리, 최종 로켓 발사대).
func _side_rock(depth: float) -> Vector3:
	var zone := player.position
	var h := zone.y
	var base := Vector3(zone.x - 7.5, h, zone.z - 4.5)
	if h > 0.1:
		add_rock(Vector3(base.x, h * 0.5, base.z), Vector3(3.6, h, depth), Color(0.5, 0.43, 0.4))
	return base


## 글라이더 폭격대: 투척 구역 왼쪽 앞 바위 기둥 위에 글라이더를 멘 고블린 n명이 폭탄을 안고 대기한다 (플레이어 시야 왼쪽).
## 조명탄이 떨어지면 한 명씩 날아올라 그 불빛 위에서 폭탄을 안고 뛰어내린다.
func add_bombers(n: int) -> void:
	if player == null or n <= 0:
		return
	bombers_total = n
	var base := _side_rock(2.2 + n * 1.6)
	for k in n:
		var g := Models.glider_goblin()
		add_child(g)
		g.position = base + Vector3(0, 0, -(k - (n - 1) * 0.5) * 1.8)
		_bombers.append(g)


## 조명탄이 떨어진 자리로 대기 중인 폭격 고블린을 하나 보낸다.
func _launch_bomber(target: Vector3) -> void:
	var g: Node3D = _bombers.pop_back()
	var bomber := Bomber.new()
	add_child(bomber)
	bomber.setup(self, target, g.global_position, g)
	bomber_launched.emit(bomber)
	ammo_changed.emit()


## 최종 진지: 바위 기둥 위 거대 로켓과 투척 구역 왼쪽 가장자리의 크고 빨간 발사 버튼 (가까이 가서 E).
func add_launch_button() -> void:
	if player == null:
		return
	var base := _side_rock(4.0)
	var wood := Models.mat(Color(0.4, 0.27, 0.15))
	Models.box(self, Vector3(2.6, 0.3, 2.6), base + Vector3(0, 0.15, 0), wood)
	for sx in [-1.0, 1.0]:
		Models.box(self, Vector3(0.2, 5.5, 0.2), base + Vector3(sx * 1.0, 2.75, 0.4), wood, Vector3(-0.15, 0, 0))
	_final_rocket = Models.rocket()
	add_child(_final_rocket)
	_final_rocket.scale = Vector3.ONE * 1.5
	_final_rocket.position = base + Vector3(0, 4.6, -0.3)
	_final_rocket.rotation = Vector3(-0.2, 0, 0)
	# 발사 버튼: 노랑·검정 줄무늬 받침 기둥 위의 커다란 빨간 버섯 단추
	var zone := player.position
	_button = Node3D.new()
	add_child(_button)
	_button.position = Vector3(zone.x - 3.9, zone.y, zone.z - 0.5)
	var post := Models.mat(Color(0.95, 0.8, 0.1))
	var dark := Models.mat(Color(0.1, 0.1, 0.1))
	Models.box(_button, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0), post)
	for y in [0.2, 0.6]:
		Models.box(_button, Vector3(0.72, 0.15, 0.72), Vector3(0, y, 0), dark, Vector3(0, 0, 0.0))
	Models.cyl(_button, 0.45, 0.45, 0.12, Vector3(0, 1.06, 0), dark, Vector3.ZERO, 16)
	_button_cap = Models.cyl(_button, 0.38, 0.42, 0.22, Vector3(0, 1.22, 0), Models.mat(Color(0.95, 0.08, 0.05), 0.4, 0.0, 0.6), Vector3.ZERO, 16)
	# 버튼과 로켓을 잇는 전선
	var wire := Models.mat(Color(0.12, 0.12, 0.12))
	var from := _button.position + Vector3(0, 0.1, 0)
	var to := base + Vector3(1.2, 0.2, 0.0)
	var mid := (from + to) * 0.5
	var seg := to - from
	Models.box(self, Vector3(0.06, 0.06, seg.length()), Vector3(mid.x, maxf(from.y, to.y) + 0.05, mid.z), wire, Vector3(0, atan2(seg.x, seg.z), 0))


## 발사 버튼을 누를 수 있는지 (아직 안 썼고, 진행 중).
func button_ready() -> bool:
	return _button != null and not _button_used


## 플레이어가 발사 버튼 곁에 있는지.
func near_button() -> bool:
	if not button_ready() or player == null or state != State.PLAYING:
		return false
	var d := player.global_position - _button.global_position
	return Vector2(d.x, d.z).length() < 2.4


## 발사 버튼을 누른다. 발리스타가 하나라도 서 있으면 안전장치가 걸려 눌리지 않는다 (한 발뿐인 궁극기를 헛되이 날리지 않게).
func press_button() -> bool:
	if not near_button():
		return false
	var tw := _button_cap.create_tween()
	tw.tween_property(_button_cap, "position:y", 1.12, 0.06)
	tw.tween_property(_button_cap, "position:y", 1.22, 0.15)
	if aa_alive():
		Sfx.play(self, "fizzle", _button.global_position, 0.0)
		toast.emit(Texts.t("button_locked"))
		return false
	_button_used = true
	Sfx.play(self, "win", _button.global_position, 2.0)
	toast.emit(Texts.t("button_fire"))
	var center := Vector3.ZERO
	var n := 0
	for c in commanders:
		if not c.dead:
			center += c.global_position
			n += 1
	center = center / n if n > 0 else Vector3(0, 0, -60)
	var missile := Missile.new()
	add_child(missile)
	missile.mega = true
	missile.setup(self, Vector3(center.x, 0.3, center.z), _final_rocket.global_position, _final_rocket)
	_final_rocket = null
	rocket_launched.emit(missile)
	ammo_changed.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and near_button():
		press_button()
		get_viewport().set_input_as_handled()


## 최종 로켓 착탄: 성채에 남은 지휘관을 모두 한꺼번에 날린다. 착탄점의 초대형 폭발 뒤로 지휘관 자리마다 연쇄 폭발.
func mega_strike(pos: Vector3) -> void:
	if not is_inside_tree():
		return
	var reach := 20.0
	var targets: Array[Commander] = []
	for c in commanders:
		if not c.dead:
			targets.append(c)
			reach = maxf(reach, Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length() + 8.0)
	rocket_strike(pos, 16.0, 2000.0, 14.0)
	Fx.blast_rings(self, pos, reach, reach - 6.0)
	Fx.flash(self, pos + Vector3(0, 12, 0), 30.0, reach * 4.0, 1.5)
	var k := 0
	for c in targets:
		k += 1
		var at := c.global_position
		get_tree().create_timer(0.12 * k, false, true).timeout.connect(func():
			if not is_inside_tree():
				return
			explode(at, 9.0, 1200.0, false, false)
			var b := Fx.burst(90, 14.0, 1.5, Fx.FLAME_COLORS)
			add_child(b)
			b.global_position = at + Vector3(0, 1, 0)
			b.emitting = true
			Fx.free_after(b, 2.5))
	# 남은 지휘관은 모두 쓰러진다 (판정은 지금 확정, 날아가는 건 연출)
	for c in targets:
		c.defeat("blast")


## 로켓 착탄: 아주 큰 폭발 + 근처 인물은 엄폐와 상관없이 쓰러진다.
func rocket_strike(pos: Vector3, radius: float, strength: float, kill_radius: float) -> void:
	if not is_inside_tree():
		return
	# 동심원은 로켓의 실제 판정 반경(엄폐 무시 kill_radius)으로 따로 그린다
	explode(pos, radius, strength, false, false)
	Fx.blast_rings(self, pos, radius, kill_radius)
	Fx.flash(self, pos + Vector3(0, 4, 0), 16.0, radius * 4.0, 0.8)
	Fx.chunks(self, pos, [Color(0.3, 0.25, 0.2), Color(0.45, 0.35, 0.25), Color(0.15, 0.12, 0.1)], 16, 16.0)
	# 버섯구름: 큰 불덩이 + 사방으로 터지는 작은 폭발 + 솟는 연기
	var core := Fx.burst(140, 18.0, 1.8, Fx.FLAME_COLORS)
	core.lifetime = 1.4
	add_child(core)
	core.global_position = pos + Vector3(0, 1, 0)
	core.emitting = true
	Fx.free_after(core, 3.0)
	for k in 6:
		var a := k * TAU / 6.0
		var at := pos + Vector3(cos(a), 0.3, sin(a)) * radius * 0.45
		get_tree().create_timer(0.08 + 0.07 * k, false, true).timeout.connect(func():
			if not is_inside_tree():
				return
			var b := Fx.burst(40, 10.0, 1.1, Fx.FLAME_COLORS)
			add_child(b)
			b.global_position = at
			b.emitting = true
			Fx.free_after(b, 2.0)
			Fx.smoke_puff(self, at, 2.5))
	var column := Fx.smoke_column(60)
	(column.process_material as ParticleProcessMaterial).initial_velocity_max = 7.0
	(column.process_material as ParticleProcessMaterial).scale_max = 4.0
	add_child(column)
	column.global_position = pos
	get_tree().create_timer(3.0, false, true).timeout.connect(Callable(column, "set").bind("emitting", false))
	Fx.free_after(column, 12.0)
	for a in get_tree().get_nodes_in_group("actors"):
		if not a.dead and a.chest().distance_to(pos) < kill_radius:
			a.defeat("blast")
	Sfx.play_delayed(self, "boom", pos, 12.0, _listener())
	shake_requested.emit(1.0)
	if player:
		player.add_shake(1.0)
	hitstop(0.15)


func _update_held() -> void:
	var a := current_ammo()
	player.set_held_model(Fx.ammo_model(a.kind, a.model_scale * 0.8, false))


func select_slot(i: int) -> void:
	if i < 0 or i >= ammo_slots.size() or i == current_slot:
		return
	if player and player.is_throwing():
		return
	current_slot = i
	if player:
		# 손에 든 폭탄 모양이 바뀌는 것으로 알린다 (글씨는 띄우지 않는다)
		_update_held()
	ammo_changed.emit()


func cycle_slot(step: int) -> void:
	if ammo_slots.size() < 2:
		return
	select_slot(posmod(current_slot + step, ammo_slots.size()))


## 병이 손을 떠나는 순간 탄약이 줄어든다.
func try_throw(origin: Vector3, direction: Vector3) -> bool:
	if state != State.PLAYING or ammo_slots.is_empty():
		return false
	var slot: Dictionary = ammo_slots[current_slot]
	if slot.count <= 0:
		toast.emit(Texts.t("empty_slot"))
		return false
	slot.count -= 1
	throws += 1
	thrown[slot.type.kind] = int(thrown.get(slot.type.kind, 0)) + 1
	var p := Projectile.new()
	add_child(p)
	var excluded: Array[RID] = []
	if player:
		excluded.append(player.get_rid())
	p.wind = wind
	p.launch(origin, direction, slot.type, excluded)
	p.impacted.connect(_on_impact)
	_projectiles.append(p)
	projectile_thrown.emit(p)
	Sfx.play(self, "flight", origin, -12.0)
	if throws == 1:
		for m in messengers:
			m.start()
		for a in allies:
			a.start()
	if total_ammo() == 1 and slot.type.kind != AmmoType.Kind.PAINT and not _last_shot_warned:
		_last_shot_warned = true
		toast.emit(Texts.t("last_shot"))
	ammo_changed.emit()
	return true


# ---------- 착탄, 불, 폭발 ----------

func _on_impact(p: Projectile, pos: Vector3, normal: Vector3, collider: Object) -> void:
	_projectiles.erase(p)
	if collider == null:
		return
	var ammo := p.ammo
	if collider is Actor:
		collider.on_direct_hit(ammo)
	match ammo.kind:
		AmmoType.Kind.FIRE:
			Sfx.play_delayed(self, "break", pos, 0.0, _listener())
			_impact_juice(pos, 1.0, ammo.pool_radius)
			_shards(pos, Color(0.1, 0.1, 0.1))
			Fx.scorch(self, pos, 1.6)
			Fx.flash(self, pos, 3.0, 9.0, 0.35)
			for s in structures:
				s.apply_impact(pos, ammo.impact_radius, ammo.impact_strength)
			_blast_actors(pos, ammo.kill_radius)
			var on_steel: bool = collider is Block and collider.mat == Block.Mat.STEEL
			var pool := FirePool.new()
			add_child(pool)
			pool.global_position = pos + normal * 0.05
			if on_steel:
				# 강철에는 불이 붙지 않고 금방 꺼진다 (바로 보이게)
				pool.setup(ammo.pool_radius * 0.6, 0.6, 0.0)
				Sfx.play_delayed(self, "fizzle", pos, -2.0, _listener())
				Fx.smoke_puff(self, pos, 0.6)
			else:
				pool.setup(ammo.pool_radius, ammo.pool_duration, ammo.burn_multiplier)
		AmmoType.Kind.HE:
			Sfx.play_delayed(self, "boom", pos, 4.0, _listener())
			_impact_juice(pos, 3.0, 0.0)
			# 실제 판정 반경 그대로의 동심원 (바깥 = 부서지는 끝, 안 = 쓰러지는 끝)
			Fx.blast_rings(self, pos, ammo.impact_radius, ammo.kill_radius)
			_shards(pos, Color(0.25, 0.25, 0.27))
			Fx.smoke_puff(self, pos, 2.0)
			Fx.scorch(self, pos, 2.6)
			Fx.flash(self, pos, 6.0, 14.0, 0.3)
			Fx.chunks(self, pos, _chunk_colors(collider), 8, 7.0)
			var fireball := Fx.burst(40, 8.0, 0.7, Fx.FLAME_COLORS)
			add_child(fireball)
			fireball.global_position = pos
			fireball.emitting = true
			Fx.free_after(fireball, 2.0)
			for s in structures:
				s.apply_impact(pos, ammo.impact_radius, ammo.impact_strength)
			_blast_actors(pos, ammo.kill_radius)
			_detonate_kegs(pos, ammo.impact_radius)
		AmmoType.Kind.OIL:
			Sfx.play_delayed(self, "break", pos, -4.0, _listener())
			var slick := OilSlick.new()
			add_child(slick)
			slick.global_position = pos + normal * 0.02
			slick.setup(ammo.oil_radius, normal)
			slick.coat_blocks()
		AmmoType.Kind.PAINT:
			# 페인트탄: 터지지 않고 철퍽, 맞은 면에 밝은 물감 자국만 남는다
			Sfx.play_delayed(self, "splat", pos, -2.0, _listener())
			Fx.signal_smoke(self, pos + normal * 0.1)
			return
		AmmoType.Kind.FLARE:
			var flare := Flare.new()
			add_child(flare)
			flare.global_position = pos
			flare.setup(pos, ammo.flare_height, ammo.flare_duration)
			# 폭격대가 대기 중이면 그 불빛을 보고 날아간다
			if bombers_left() > 0 and state == State.PLAYING:
				_launch_bomber(pos)
			# 조명탄은 연기 기둥을 남기지 않는다 (꺼진 뒤 시야를 가리지 않게)
			return
	# 빗나가도 연기 기둥이 남아 다음 투척의 기준이 된다
	var smoke := Fx.smoke_column()
	add_child(smoke)
	smoke.global_position = pos + Vector3(0, 0.5, 0)
	get_tree().create_timer(TRACE_TIME - 7.0, false, true).timeout.connect(Callable(smoke, "set").bind("emitting", false))
	Fx.free_after(smoke, TRACE_TIME)


func _listener() -> Vector3:
	return player.global_position if player else Vector3.ZERO


func _shards(pos: Vector3, color: Color) -> void:
	var shards := Fx.burst(18, 4.0, 0.12, [color, Color(color, 0.0)], false)
	add_child(shards)
	shards.global_position = pos
	shards.emitting = true
	Fx.free_after(shards, 2.0)


func _blast_actors(pos: Vector3, radius: float) -> void:
	for a in get_tree().get_nodes_in_group("actors"):
		a.on_blast(pos, radius)
	# 배경 고블린(과 같이 싸우던 병사)은 휘말리면 날아간다
	for e in get_tree().get_nodes_in_group("goblin_extras"):
		e.on_blast(pos, maxf(radius, 2.5))


## 배경 고블린 (판정과 무관). point_at: 손짓해 가리킬 곳 (화약통).
func add_extra(pos: Vector3, yaw_deg: float, mode: int, point_at := Vector3.INF) -> GoblinExtra:
	var e := GoblinExtra.new()
	e.position = pos
	e.rotation.y = deg_to_rad(yaw_deg)
	add_child(e)
	e.setup(mode, point_at)
	return e


## 폭발이 화약통에 닿으면 0.15초 간격으로 연쇄 폭발한다 (쾅, 쾅, 쾅).
func _detonate_kegs(pos: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("flammable"):
		var block := b as Block
		if block.mat == Block.Mat.KEG and not block.burnt and block.distance_to_point(pos) <= radius:
			block.fuse(0.15)


## 화약통·폭발통 폭발: 석재 벽에도 통하는 큰 충격, 주변 점화, 기름 점화, 인물 판정.
## forced: 플레이어 투척으로는 안 부서지는 구조(성문)에도 통하는 폭발 (동료의 폭발통).
## 큰 폭발은 강철판도 날린다 (explosive). 흰 석재는 그대로.
func explode(pos: Vector3, radius: float, strength: float, forced := false, rings := true) -> void:
	if not is_inside_tree():
		return
	Fx.scorch(self, Vector3(pos.x, 0.05, pos.z), radius * 0.6, 40.0)
	Fx.flash(self, pos, 9.0, radius * 3.0, 0.45)
	if rings:
		Fx.blast_rings(self, pos, radius, radius * 0.8)
	Fx.chunks(self, pos, [Color(0.25, 0.2, 0.15), Color(0.4, 0.3, 0.2), Color(0.12, 0.1, 0.08)], 12, 10.0)
	Sfx.play_delayed(self, "boom", pos, 8.0, _listener())
	var fireball := Fx.burst(60, 9.0, 0.9, Fx.FLAME_COLORS)
	add_child(fireball)
	fireball.global_position = pos
	fireball.emitting = true
	Fx.free_after(fireball, 2.0)
	var smoke := Fx.smoke_column(40)
	add_child(smoke)
	smoke.global_position = pos
	Fx.free_after(smoke, 20.0)
	_impact_juice(pos, 4.0, 0.0)
	for s in structures:
		s.apply_impact(pos, radius, strength, forced, true)
	for b in get_tree().get_nodes_in_group("flammable"):
		if b.distance_to_point(pos) <= radius * 0.6:
			b.ignite()
	for o in get_tree().get_nodes_in_group("oil"):
		if o.global_position.distance_to(pos) <= radius:
			o.ignite_after(0.05)
	_blast_actors(pos, radius * 0.8)
	_detonate_kegs(pos, radius)


## 과장된 착탄 연출: 히트스톱, 충격파 링, 불덩이, 거리 비례 흔들림, 병사 반응 (판정과 무관).
## ring: 충격파 링 반경 (실제 효과 범위에 맞춘다. 0이면 링을 따로 그린다).
func _impact_juice(pos: Vector3, power: float, ring: float) -> void:
	var burst := Fx.burst(int(14 * power) + 10, 5.0 + 2.0 * power, 0.35 + 0.1 * power, Fx.FLAME_COLORS)
	add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	Fx.free_after(burst, 2.0)
	if ring > 0.0:
		Fx.shockwave(self, pos, ring)
	shake_requested.emit(clampf(0.45 * power, 0.0, 1.0))
	if player:
		var dist := player.global_position.distance_to(pos)
		player.add_shake(clampf(0.5 * power * 25.0 / maxf(dist, 25.0), 0.0, 1.0))
	for g in get_tree().get_nodes_in_group("soldiers"):
		var d: float = g.global_position.distance_to(pos)
		if d < STARTLE_RANGE:
			g.startle(power * (1.0 - d / STARTLE_RANGE) * 1.5)
	hitstop(HITSTOP * clampf(power, 0.6, 1.4))


## 대공 발리스타가 하나라도 남아 있는지.
func aa_alive() -> bool:
	for b in ballistas:
		if ballista_alive(b):
			return true
	return false


## 발리스타 하나가 아직 쏠 수 있는지: 탑이 서 있고 조종하는 궁병이 살아 있어야 한다.
func ballista_alive(b: Block) -> bool:
	if not is_instance_valid(b) or b.fallen or b.burnt:
		return false
	var op: Guard = b.get_meta("operator", null)
	return op == null or (is_instance_valid(op) and not op.dead)


## 대공 발리스타 탑의 발리스타를 등록한다.
func add_ballista(b: Block) -> void:
	ballistas.append(b)
	var wood := Models.mat(Color(0.32, 0.22, 0.14))
	var iron := Models.mat(Models.HUMAN_STEEL, 0.4, 0.6)
	# 받침 위 거대한 석궁 (반듯한 인간 규격품). 돌아가는 받침(Bow): -Z가 쏘는 쪽, 처음엔 하늘 쪽 고블린 언덕을 겨눈다
	var bow := Node3D.new()
	bow.name = "Bow"
	bow.position = Vector3(0, b.size.y * 0.5 + 0.35, 0)
	bow.rotation = Vector3(0.45, PI, 0)
	b.add_child(bow)
	Models.box(bow, Vector3(0.25, 0.25, 2.2), Vector3(0, 0, 0.2), wood)
	Models.box(bow, Vector3(2.4, 0.15, 0.15), Vector3(0, 0.05, -0.75), iron, Vector3(0, 0.25, 0))
	Models.box(bow, Vector3(0.06, 0.06, 2.0), Vector3(0, 0.17, -0.1), iron)
	Models.cyl(bow, 0.05, 0.12, 0.25, Vector3(0, 0.17, -1.15), iron, Vector3(PI * 0.5, 0, 0), 6)
	b.set_meta("bow", bow)
	# 조종하는 궁병: 석궁 뒤에 선다. 직격하거나 쓰러뜨리면 발리스타는 아무도 못 쏜다
	var op := Guard.new().setup(false, true)
	op.position = b.position + Vector3(0, -b.size.y * 0.5, -1.05)
	op.rotation.y = PI
	add_child(op)
	b.set_meta("operator", op)


## 바람 한 단계의 세기 (m/s²). 바람자루 마디 하나가 펴질 때마다 한 단계.
const WIND_STEP := 0.4
const WIND_LEVELS := 5


## 바람 단계 (0~5).
func wind_level() -> int:
	return clampi(roundi(wind.length() / WIND_STEP), 0, WIND_LEVELS)


## 바람 표시: 들판의 고블린 전투 깃발 (펴진 천 폭 수 = 바람 단계)과 모닥불 연기. 판정과 무관하다.
func add_wind_banner(pos: Vector3) -> WindBanner:
	var banner := WindBanner.new()
	banner.position = pos
	add_child(banner)
	banner.setup(wind, wind_level(), night)
	return banner


## 히트스톱: 짧게 시간을 거의 멈춘다. 물리 틱 수로 세는 판정은 영향받지 않는다.
## 승리 연출 중(time_scale이 다른 값)이면 건드리지 않는다.
func hitstop(seconds: float) -> void:
	if Engine.time_scale != 1.0 or not is_inside_tree():
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func():
		if Engine.time_scale == 0.05:
			Engine.time_scale = 1.0)


func on_block_burnt(b: Block) -> void:
	var embers := Fx.burst(14, 2.5, 0.15, Fx.FLAME_COLORS)
	add_child(embers)
	embers.global_position = b.global_position
	embers.emitting = true
	Fx.free_after(embers, 2.0)
	match b.mat:
		Block.Mat.KEG:
			# 화약통: 석재 벽에도 통하는 큰 충격. 큰 화약통(blast 메타)은 더 크게 터진다
			var blast: Array = b.get_meta("blast", [6.0, 450.0])
			explode.call_deferred(b.global_position, blast[0], blast[1])
		Block.Mat.FUEL:
			# 연료 배관이 다 타면 그 자리에서 불길이 확 솟는다
			var pool := FirePool.new()
			add_child(pool)
			pool.global_position = b.global_position
			pool.setup(2.2, 4.0, 1.5, true)


## 고폭탄·화약통에 산산조각 난 석재 블록: 같은 색 파편이 크게 튀고 먼지가 인다.
func on_block_shattered(b: Block) -> void:
	var col: Color = Block.INFO[b.mat].color
	var debris := Fx.burst(int(clampf(b.size.length() * 10.0, 10.0, 40.0)), 7.0, 0.3, [col, col, Color(col, 0.0)], false)
	debris.lifetime = 1.4
	add_child(debris)
	debris.global_position = b.global_position
	debris.emitting = true
	Fx.free_after(debris, 2.0)
	Fx.smoke_puff(self, b.global_position, b.size.length() * 0.5)


## 근처 충격에 금이 커진 블록: 같은 색 부스러기가 조금 튀고 먼지가 인다 (빗나가도 조금은 부서진 느낌).
func on_block_chipped(b: Block) -> void:
	var col: Color = Block.INFO[b.mat].color
	var chips := Fx.burst(8, 4.0, 0.12, [col, col.darkened(0.3), Color(col, 0.0)], false)
	add_child(chips)
	chips.global_position = b.global_position + Vector3.UP * b.size.y * 0.3
	chips.emitting = true
	Fx.free_after(chips, 1.5)
	Fx.smoke_puff(self, b.global_position, 0.4)


func on_heavy_landing(pos: Vector3, energy: float) -> void:
	if elapsed - _last_collapse_sound > 0.4:
		_last_collapse_sound = elapsed
		Sfx.play(self, "collapse", pos, clampf(energy / 200.0, -8.0, 4.0))


func _on_collapsed(pos: Vector3, count: int) -> void:
	for v in get_tree().get_nodes_in_group("villagers"):
		v.cheer()
	if elapsed - _last_collapse_sound > 0.3:
		_last_collapse_sound = elapsed
		Sfx.play(self, "collapse", pos, clampf(float(count) - 6.0, -8.0, 4.0))


func _on_barrel_exploded(pos: Vector3, ally: Ally) -> void:
	# 강철 문짝과 문 위 강철 초소를 통째로 날린다 (흰 석재 기둥은 남는다)
	explode(pos, 8.0, 1200.0, true)
	# 성문 바로 뒤에서 빗장을 붙든 지휘관은 성문째 날아간다 (엄폐와 상관없이)
	for c in commanders:
		if not c.dead and c.global_position.distance_to(pos) < 6.0:
			c.defeat("blast")
	# 그을린 동료가 웃으며 날아간다 (연출)
	ally.launch(Vector3(0.3, 0, 1.0), 3, 0.9)


# ---------- 판정 ----------

func _on_commander_defeated(c: Commander, cause: String) -> void:
	c.set_meta("down_at", elapsed)
	_drop_flag(c)
	if state != State.PLAYING or goal != Goal.COMMANDER:
		return
	for other in commanders:
		if not other.dead:
			targets_changed.emit()
			_kill_beat(c)
			return
	targets_changed.emit()
	_win(c, cause, c.chest())


## 지휘관 하나를 쓰러뜨렸을 때 (아직 남은 지휘관이 있을 때): 확실히 쓰러졌다는 걸 보여 준다.
## 지휘관이 만화처럼 날아가거나(불이면 불타며 허둥댐), 머리 위에서 별 폭죽이 터지고, 남은 수가 뜬다.
## 잠깐 느린 화면과 묵직한 소리로 손맛도 준다.
func _kill_beat(c: Commander) -> void:
	Sfx.play(self, "collapse", c.global_position, 4.0)
	Sfx.play(self, "win", c.global_position, -2.0)
	shake_requested.emit(0.6)
	if c.defeat_cause == "fire":
		c.burn_panic()
	else:
		var away := c.global_position - (player.global_position if player else Vector3.ZERO)
		c.launch(Vector3(away.x, 0, away.z), commanders.find(c) + 1, 0.9)
	var stars := Fx.burst(40, 7.0, 0.35, [Color(1, 0.95, 0.4), Color(1, 0.6, 0.15), Color(1, 1, 1, 0)])
	add_child(stars)
	stars.global_position = c.chest() + Vector3.UP * 1.0
	stars.emitting = true
	Fx.free_after(stars, 2.0)
	Fx.flash(self, c.chest(), 5.0, 8.0, 0.4)
	toast.emit(Texts.t("kill_one"))
	if Engine.time_scale != 1.0 and Engine.time_scale != 0.05:
		return
	Engine.time_scale = 0.3
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func():
		if Engine.time_scale == 0.3:
			Engine.time_scale = 1.0)


## 맞은 블록 재질 색의 파편 (땅이면 흙색).
func _chunk_colors(collider: Object) -> Array:
	if collider is Block:
		var col: Color = Block.INFO[collider.mat].color
		return [col, col.darkened(0.25), col.lightened(0.1)]
	return [Color(0.42, 0.36, 0.27), Color(0.3, 0.26, 0.2), Color(0.5, 0.45, 0.35)]


## 쓰러진 지휘관의 깃발이 넘어간다 (남은 표적을 글씨 없이 알려 준다).
func _drop_flag(c: Commander) -> void:
	if not c.has_meta("flag"):
		return
	var flag: Node3D = c.get_meta("flag")
	_flags.erase(flag)
	if not flag.is_inside_tree():
		return
	var tw := flag.create_tween()
	tw.tween_property(flag, "rotation:z", 1.45, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## 남은 지휘관 수.
func commanders_left() -> int:
	var n := 0
	for c in commanders:
		if not c.dead:
			n += 1
	return n


func _on_messenger_defeated(m: Actor, cause: String) -> void:
	if state != State.PLAYING or goal != Goal.MESSENGER:
		return
	for other in messengers:
		if not other.dead:
			return
	_win(m, cause, m.chest())


func _win(target: Actor, cause: String, focus: Vector3) -> void:
	_set_state(State.CLEARED, Texts.t("win"))
	target_down.emit(target, cause, focus)


## 다리를 놓는다 (상판 블록들과 경로상 다리 앞·끝 거리).
func add_bridge(deck: Array, start_distance: float, end_distance: float) -> void:
	bridges.append({"blocks": deck, "start": start_distance, "end": end_distance})


func _bridge_broken(br: Dictionary) -> bool:
	for b in br.blocks:
		if not is_instance_valid(b) or b.fallen or b.burnt:
			return true
	return false


func _on_messenger_arrived(_m: Messenger) -> void:
	_fail("fail_messenger")


func _fail(key: String) -> void:
	fail_cause = key
	_set_state(State.FAILED, Texts.t(key))


func is_active() -> bool:
	if not _projectiles.is_empty():
		return true
	if not get_tree().get_nodes_in_group("fire_pool").is_empty():
		return true
	if not get_tree().get_nodes_in_group("missile").is_empty():
		return true
	for s in structures:
		if s.any_burning() or s.any_moving():
			return true
	for m in messengers:
		if m.running:
			return true
	for a in allies:
		if a.walking:
			return true
	return false


func _set_state(s: int, message: String) -> void:
	if state != State.PLAYING:
		return
	state = s
	state_changed.emit(state, message)


func _physics_process(delta: float) -> void:
	elapsed += delta
	# 깃발 천(로컬 +X)이 바람이 불어 가는 쪽으로 날린다
	var wind_yaw := atan2(-wind.z, wind.x) if wind.length() > 0.01 else 0.0
	for f in _flags:
		var cloth: Node3D = f.get_node("Cloth")
		cloth.rotation.y = wind_yaw + sin(elapsed * (3.0 + wind.length())) * 0.25
		cloth.rotation.x = sin(elapsed * 5.0) * 0.06
	if state != State.PLAYING:
		return
	# 다리가 끊기면 전령은 다리 앞까지 와서 오도 가도 못한다 → 전령 멈추기 성공
	# (다리 위에 있을 때 끊겨도 마찬가지)
	if goal == Goal.MESSENGER:
		for br in bridges:
			if _bridge_broken(br):
				for m in messengers:
					var p: float = m.follow.progress
					if not m.dead and not m.has_arrived and p >= br.start and p < br.end:
						m.strand()
						_win(m, "bridge", m.chest())
						return
	# 부수는 탄(폭격 진지는 조명탄도)이 다 떨어지고, 날아가는 탄·불·무너짐·글라이더가 모두 멈춘 뒤에야 실패
	# (마지막 탄을 던지자마자 지지 않는다)
	if total_ammo() == 0:
		if is_active():
			_quiet = 0.0
		else:
			_quiet += delta
			if _quiet >= FAIL_QUIET_TIME:
				_fail("fail_ammo")
	else:
		_quiet = 0.0
