class_name Stage
extends Node3D
## 한 테스트 스테이지의 상태: 지형, 플레이어(고블린), 인간 시설, 인물, 탄약, 승리/실패 판정.
## 승리 조건은 지휘관을 쓰러뜨리는 것 하나로 통일한다 (확장 기획서 6장). 깃발은 위치 표식이다.
## 원칙은 "과장은 판정 뒤에": 궤적·폭발 반경·점화·지휘관 판정은 정직하고 고정, 연출만 부풀린다.

signal state_changed(state: int, message: String)
signal ammo_changed
signal toast(text: String)
signal projectile_thrown(projectile: Projectile)
## 착탄·폭발의 화면 흔들림 (세기 0~1, 추적 화면용)
signal shake_requested(amount: float)
## 승리 판정 확정 (승리 연출 시작). target: 쓰러진 인물 (봉화대를 태운 경우 null), focus: 연출이 비출 곳
signal target_down(target: Actor, cause: String, focus: Vector3)

enum State { PLAYING, CLEARED, FAILED }
## 승리 조건: 지휘관 쓰러뜨리기, 또는 전령 멈추기 (전령을 쓰러뜨리거나 봉화대를 먼저 태움)
enum Goal { COMMANDER, MESSENGER }

const TRACE_TIME := 30.0
const FAIL_QUIET_TIME := 4.0
const STARTLE_RANGE := 14.0
## 히트스톱 (현실 시간)
const HITSTOP := 0.07

var stage_id := ""
var title := ""
var night := false
var goal: int = Goal.COMMANDER
var state: int = State.PLAYING
var fail_cause := ""
var player: Player
var commander: Commander
var structures: Array[Structure] = []
var messengers: Array[Messenger] = []
var allies: Array[Ally] = []
## 전령의 목적지 (봉화대). 다 타거나 무너지면 전령이 도착해도 지원을 부르지 못한다
var beacon: Structure
## 봉화대 위치 (다 타 없어졌을 때 연출이 비출 곳)
var beacon_center := Vector3.ZERO
## 승리 연출 카메라 (스테이지마다 정해 둔 위치, 없으면 자동)
var cine_cam_pos := Vector3.INF
## [{type: AmmoType, count: int}]
var ammo_slots: Array = []
var current_slot := 0
var throws := 0
var elapsed := 0.0
var _projectiles: Array[Projectile] = []
var _quiet := 0.0
var _last_collapse_sound := -10.0
var _flags: Array[Node3D] = []
var _last_shot_warned := false


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
	var mat := Models.mat(Color(0.15, 0.15, 0.15))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var w := 0.08
	var hx := half_extents.x + 0.4
	var hz := half_extents.y + 0.4
	for spec in [[Vector3(0, 0, -hz), Vector3(hx * 2, 0.02, w)], [Vector3(0, 0, hz), Vector3(hx * 2, 0.02, w)],
			[Vector3(-hx, 0, 0), Vector3(w, 0.02, hz * 2)], [Vector3(hx, 0, 0), Vector3(w, 0.02, hz * 2)]]:
		Models.box(self, spec[1], center + spec[0] + Vector3(0, 0.01, 0), mat)


## 고블린이 올라선 높은 바위 턱. 앞쪽 끝이 투척 구역 바로 앞이라 아래를 내려다보며 던진다.
func _make_perch(center: Vector3, half_extents: Vector2) -> void:
	var rock := Color(0.33, 0.31, 0.3)
	var rock_dark := Color(0.25, 0.24, 0.23)
	var h := center.y
	var front := center.z - half_extents.y - 0.3
	var back := center.z + half_extents.y + 7.0
	var wide := half_extents.x + 4.0
	add_prop(Vector3(center.x, h * 0.5, (front + back) * 0.5), Vector3(wide * 2.0, h, back - front), rock)
	# 아래로 갈수록 넓어지는 절벽 (로우폴리 층)
	add_prop(Vector3(center.x, h * 0.3, (front + back) * 0.5 + 1.5), Vector3(wide * 2.0 + 4.0, h * 0.6, back - front + 6.0), rock_dark)
	add_prop(Vector3(center.x - 2.0, h * 0.12, (front + back) * 0.5 + 2.5), Vector3(wide * 2.0 + 9.0, h * 0.24, back - front + 10.0), rock)
	# 양옆과 뒤의 바위 턱 (앞은 비워 둔다)
	for sx in [-1.0, 1.0]:
		add_prop(Vector3(center.x + sx * (wide - 0.6), h + 0.6, center.z + 1.0), Vector3(1.2, 1.2, half_extents.y * 2.0 + 4.0), rock_dark)
	add_prop(Vector3(center.x, h + 0.9, back - 0.8), Vector3(wide * 2.0, 1.8, 1.6), rock_dark)


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
	commander = Commander.new()
	commander.position = pos
	commander.rotation.y = deg_to_rad(yaw_deg)
	add_child(commander)
	commander.defeated.connect(_on_commander_defeated)
	var flag := Models.flag()
	flag.position = pos + flag_offset
	add_child(flag)
	_flags.append(flag)
	return commander


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
func add_messenger(points: Array, speed: float, torch := false) -> Messenger:
	var m := Messenger.new()
	m.speed = speed
	m.follow = _path(points)
	m.follow.add_child(m)
	if torch:
		m.carry_torch()
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


## 밤의 횃불 (실제 광원 없이 발광 재질).
func add_torch(pos: Vector3, height := 1.8) -> void:
	var t := Models.torch(height)
	t.position = pos
	add_child(t)


func finish_build() -> void:
	for s in structures:
		s.finalize()
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


func total_ammo() -> int:
	var n := 0
	for s in ammo_slots:
		n += s.count
	return n


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
	var p := Projectile.new()
	add_child(p)
	var excluded: Array[RID] = []
	if player:
		excluded.append(player.get_rid())
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
	if total_ammo() == 1 and not _last_shot_warned:
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
			_impact_juice(pos, 1.0)
			_shards(pos, Color(0.1, 0.1, 0.1))
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
			_impact_juice(pos, 3.0)
			_shards(pos, Color(0.25, 0.25, 0.27))
			Fx.smoke_puff(self, pos, 2.0)
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
			slick.setup(ammo.oil_radius)
			slick.coat_blocks()
		AmmoType.Kind.FLARE:
			var flare := Flare.new()
			add_child(flare)
			flare.global_position = pos
			flare.setup(pos, ammo.flare_height, ammo.flare_duration)
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


## 폭발이 화약통에 닿으면 0.15초 간격으로 연쇄 폭발한다 (쾅, 쾅, 쾅).
func _detonate_kegs(pos: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("flammable"):
		var block := b as Block
		if block.mat == Block.Mat.KEG and not block.burnt and block.distance_to_point(pos) <= radius:
			block.fuse(0.15)


## 화약통·폭발통 폭발: 석재 벽에도 통하는 큰 충격, 주변 점화, 기름 점화, 인물 판정.
## forced: 플레이어 투척으로는 안 부서지는 구조(성문)에도 통하는 폭발 (동료의 폭발통).
func explode(pos: Vector3, radius: float, strength: float, forced := false) -> void:
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
	_impact_juice(pos, 4.0)
	for s in structures:
		s.apply_impact(pos, radius, strength, forced)
	for b in get_tree().get_nodes_in_group("flammable"):
		if b.distance_to_point(pos) <= radius * 0.6:
			b.ignite()
	for o in get_tree().get_nodes_in_group("oil"):
		if o.global_position.distance_to(pos) <= radius:
			o.ignite_after(0.05)
	_blast_actors(pos, radius * 0.8)
	_detonate_kegs(pos, radius)


## 과장된 착탄 연출: 히트스톱, 충격파 링, 불덩이, 거리 비례 흔들림, 병사 반응 (판정과 무관).
func _impact_juice(pos: Vector3, power: float) -> void:
	var burst := Fx.burst(int(14 * power) + 10, 5.0 + 2.0 * power, 0.35 + 0.1 * power, Fx.FLAME_COLORS)
	add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	Fx.free_after(burst, 2.0)
	Fx.shockwave(self, pos, 2.0 + power * 1.5)
	shake_requested.emit(clampf(0.45 * power, 0.0, 1.0))
	if player:
		var dist := player.global_position.distance_to(pos)
		player.add_shake(clampf(0.5 * power * 25.0 / maxf(dist, 25.0), 0.0, 1.0))
	for g in get_tree().get_nodes_in_group("soldiers"):
		var d: float = g.global_position.distance_to(pos)
		if d < STARTLE_RANGE:
			g.startle(power * (1.0 - d / STARTLE_RANGE) * 1.5)
	hitstop(HITSTOP * clampf(power, 0.6, 1.4))


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
			# 화약통: 석재 벽에도 통하는 큰 충격
			explode.call_deferred(b.global_position, 6.0, 450.0)
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
	if elapsed - _last_collapse_sound > 0.3:
		_last_collapse_sound = elapsed
		Sfx.play(self, "collapse", pos, clampf(float(count) - 6.0, -8.0, 4.0))


func _on_barrel_exploded(pos: Vector3, ally: Ally) -> void:
	# 반듯한 석재 성문(연결 강도 400)을 무너뜨릴 만큼 크다. 강철 문짝은 그대로 남는다
	explode(pos, 8.0, 1200.0, true)
	# 그을린 동료가 웃으며 날아간다 (연출)
	ally.launch(Vector3(0.3, 0, 1.0), 3, 0.9)


# ---------- 판정 ----------

func _on_commander_defeated(c: Commander, cause: String) -> void:
	if state != State.PLAYING or goal != Goal.COMMANDER:
		return
	_win(c, cause, c.chest())


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


## 봉화대가 남아 있는지 (가연 블록의 절반 이상이 타거나 무너지면 못 쓴다).
func beacon_alive() -> bool:
	if beacon == null:
		return true
	var ok := 0
	for b in beacon.blocks:
		if not b.fallen and not b.burnt and not b.burning:
			ok += 1
	return ok * 2 > beacon.initial_count


func _on_messenger_arrived(_m: Messenger) -> void:
	if beacon_alive():
		_fail("fail_messenger")


func _fail(key: String) -> void:
	fail_cause = key
	_set_state(State.FAILED, Texts.t(key))


func is_active() -> bool:
	if not _projectiles.is_empty():
		return true
	if not get_tree().get_nodes_in_group("fire_pool").is_empty():
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
	for f in _flags:
		var cloth: Node3D = f.get_node("Cloth")
		cloth.rotation.y = sin(elapsed * 3.0) * 0.25
		cloth.rotation.x = sin(elapsed * 5.0) * 0.06
	if state != State.PLAYING:
		return
	# 봉화대를 먼저 태우면 전령이 지원을 부를 수 없다 → 전령 멈추기 성공
	if goal == Goal.MESSENGER and beacon and not beacon_alive():
		_win(null, "beacon", beacon_center)
		return
	if total_ammo() == 0:
		if is_active():
			_quiet = 0.0
		else:
			_quiet += delta
			if _quiet >= FAIL_QUIET_TIME:
				_fail("fail_ammo")
