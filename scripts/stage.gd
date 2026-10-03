class_name Stage
extends Node3D
## 한 테스트 스테이지의 상태: 지형, 플레이어, 건물, 적, 탄약, 클리어/실패 판정.

signal state_changed(state: int, message: String)
signal ammo_changed
signal toast(text: String)
signal projectile_thrown(projectile: Projectile)
## 착탄·폭발의 화면 흔들림 (세기 0~1, 추적 화면용)
signal shake_requested(amount: float)

enum State { PLAYING, CLEARED, FAILED }
enum Goal { CORE, ENEMY }

const TRACE_TIME := 30.0
const FAIL_QUIET_TIME := 4.0
## 코어 바닥이 이 높이 아래로 내려와 멈추면 땅에 닿은 것으로 본다 (잔해 위에 걸친 경우)
const CORE_GROUND_HEIGHT := 0.9

var stage_id := ""
var title := ""
var objective := ""
var goal: int = Goal.CORE
var state: int = State.PLAYING
var player: Player
var structures: Array[Structure] = []
var enemies: Array[Enemy] = []
## [{type: AmmoType, count: int}]
var ammo_slots: Array = []
var current_slot := 0
var throws := 0
var elapsed := 0.0
var _projectiles: Array[Projectile] = []
var _quiet := 0.0
var _last_collapse_sound := -10.0


# ---------- 구성 ----------

func begin(p_id: String, p_title: String, p_objective: String, p_goal: int) -> void:
	stage_id = p_id
	title = p_title
	objective = p_objective
	goal = p_goal
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
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.6, 0.59)
	m.roughness = 1.0
	mesh.material_override = m
	ground.add_child(mesh)
	add_child(ground)


func set_zone(center: Vector3, half_extents: Vector2, yaw_deg := 0.0) -> void:
	player = Player.new()
	player.name = "Player"
	# 바위 턱 끝 가까이에서 시작해 아래가 잘 보이게 한다
	player.position = center + Vector3(0, 0, -half_extents.y + 0.6)
	add_child(player)
	player.rotation.y = deg_to_rad(yaw_deg)
	player.set_zone(center, half_extents)
	player.throw_requested.connect(try_throw)
	player.slot_requested.connect(select_slot)
	player.slot_cycle_requested.connect(func(step): cycle_slot(step))
	if center.y > 0.1:
		_make_perch(center, half_extents)
	# 투척 구역 테두리
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var w := 0.08
	var hx := half_extents.x + 0.4
	var hz := half_extents.y + 0.4
	for spec in [[Vector3(0, 0, -hz), Vector3(hx * 2, 0.02, w)], [Vector3(0, 0, hz), Vector3(hx * 2, 0.02, w)],
			[Vector3(-hx, 0, 0), Vector3(w, 0.02, hz * 2)], [Vector3(hx, 0, 0), Vector3(w, 0.02, hz * 2)]]:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		line.mesh = bm
		line.material_override = mat
		line.position = center + spec[0] + Vector3(0, 0.01, 0)
		add_child(line)


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


func add_enemy(from: Vector3, to: Vector3, speed: float) -> Enemy:
	var path := Path3D.new()
	var curve := Curve3D.new()
	curve.add_point(from)
	curve.add_point(to)
	path.curve = curve
	add_child(path)
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_Y
	path.add_child(follow)
	var e := Enemy.new()
	e.speed = speed
	e.follow = follow
	follow.add_child(e)
	enemies.append(e)
	e.escaped.connect(func(): _set_state(State.FAILED, "적을 놓쳤다"))
	return e


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
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mesh.material_override = m
	node.add_child(mesh)
	node.position = center
	add_child(node)
	return node


func finish_build() -> void:
	for s in structures:
		s.finalize()
	if player and not ammo_slots.is_empty():
		player.set_held_model(ammo_slots[0].type.model_scale)


# ---------- 탄약 ----------

func current_ammo() -> AmmoType:
	return ammo_slots[current_slot].type if not ammo_slots.is_empty() else null


func total_ammo() -> int:
	var n := 0
	for s in ammo_slots:
		n += s.count
	return n


func select_slot(i: int) -> void:
	if i < 0 or i >= ammo_slots.size() or i == current_slot:
		return
	var prev: AmmoType = current_ammo()
	current_slot = i
	if player:
		player.set_held_model(current_ammo().model_scale)
	if prev and prev.weight != current_ammo().weight:
		# 수치는 보여 주지 않는다
		toast.emit("무게가 달라졌다")
	ammo_changed.emit()


func cycle_slot(step: int) -> void:
	if ammo_slots.size() < 2:
		return
	select_slot(posmod(current_slot + step, ammo_slots.size()))


func try_throw(origin: Vector3, direction: Vector3) -> bool:
	if state != State.PLAYING or ammo_slots.is_empty():
		return false
	var slot: Dictionary = ammo_slots[current_slot]
	if slot.count <= 0:
		toast.emit("이 화염병은 다 썼다")
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
	Sfx.play(self, "throw", origin, -4.0)
	if throws == 1:
		for e in enemies:
			e.start()
	ammo_changed.emit()
	return true


# ---------- 착탄, 불, 폭발 ----------

func _on_impact(p: Projectile, pos: Vector3, normal: Vector3, collider: Object) -> void:
	_projectiles.erase(p)
	if collider == null:
		return
	var ammo := p.ammo
	Sfx.play(self, "break", pos, 0.0)
	_impact_juice(pos, ammo.impact_strength / 30.0)
	var shards := Fx.burst(18, 4.0, 0.12, [Color(0.1, 0.1, 0.1, 1), Color(0.2, 0.2, 0.2, 0)], false)
	add_child(shards)
	shards.global_position = pos
	shards.emitting = true
	Fx.free_after(shards, 2.0)
	if collider is Enemy:
		collider.ignite()
	for s in structures:
		s.apply_impact(pos, ammo.impact_radius, ammo.impact_strength)
	var pool := FirePool.new()
	add_child(pool)
	pool.global_position = pos + normal * 0.05
	pool.setup(ammo.pool_radius, ammo.pool_duration, ammo.burn_multiplier)
	# 빗나가도 연기 기둥이 남아 다음 투척의 기준이 된다
	var smoke := Fx.smoke_column()
	add_child(smoke)
	smoke.global_position = pos + Vector3(0, 0.5, 0)
	get_tree().create_timer(TRACE_TIME - 7.0, false, true).timeout.connect(Callable(smoke, "set").bind("emitting", false))
	Fx.free_after(smoke, TRACE_TIME)


func explode(pos: Vector3, radius: float, strength: float) -> void:
	Sfx.play(self, "break", pos, 6.0)
	Sfx.play(self, "collapse", pos, 8.0)
	var fireball := Fx.burst(60, 9.0, 0.9, Fx.FLAME_COLORS)
	add_child(fireball)
	fireball.global_position = pos
	fireball.emitting = true
	Fx.free_after(fireball, 2.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.25)
	light.light_energy = 8.0
	light.omni_range = radius * 3.0
	add_child(light)
	light.global_position = pos + Vector3(0, 1, 0)
	create_tween().tween_property(light, "light_energy", 0.0, 0.6)
	Fx.free_after(light, 0.8)
	var smoke := Fx.smoke_column(40)
	add_child(smoke)
	smoke.global_position = pos
	Fx.free_after(smoke, 20.0)
	_impact_juice(pos, 3.0)
	for s in structures:
		s.apply_impact(pos, radius, strength)
	for b in get_tree().get_nodes_in_group("flammable"):
		if b.distance_to_point(pos) <= radius * 0.6:
			b.ignite()
	for e in enemies:
		if e.global_position.distance_to(pos) <= radius * 0.7:
			e.ignite()


## 과장된 착탄 연출: 불덩이 튀김, 순간 섬광, 화면 흔들림 (게임 판정과 무관).
func _impact_juice(pos: Vector3, power: float) -> void:
	var burst := Fx.burst(int(20 * power) + 10, 5.0 + 2.0 * power, 0.35 + 0.1 * power, Fx.FLAME_COLORS)
	add_child(burst)
	burst.global_position = pos
	burst.emitting = true
	Fx.free_after(burst, 2.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.35)
	flash.light_energy = 6.0 * power
	flash.omni_range = 6.0 + 3.0 * power
	add_child(flash)
	flash.global_position = pos + Vector3(0, 0.8, 0)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.35)
	Fx.free_after(flash, 0.5)
	shake_requested.emit(clampf(0.45 * power, 0.0, 1.0))
	if player:
		var dist := player.global_position.distance_to(pos)
		player.add_shake(clampf(0.5 * power * 25.0 / maxf(dist, 25.0), 0.0, 1.0))


func on_block_burnt(b: Block) -> void:
	var embers := Fx.burst(14, 2.5, 0.15, Fx.FLAME_COLORS)
	add_child(embers)
	embers.global_position = b.global_position
	embers.emitting = true
	Fx.free_after(embers, 2.0)
	if b.mat == Block.Mat.KEG:
		# 화약통: 석재 벽에도 통하는 큰 충격
		explode.call_deferred(b.global_position, 6.0, 450.0)


func on_heavy_landing(pos: Vector3, energy: float) -> void:
	if elapsed - _last_collapse_sound > 0.4:
		_last_collapse_sound = elapsed
		Sfx.play(self, "collapse", pos, clampf(energy / 200.0, -8.0, 4.0))


func _on_collapsed(pos: Vector3, count: int) -> void:
	if elapsed - _last_collapse_sound > 0.3:
		_last_collapse_sound = elapsed
		Sfx.play(self, "collapse", pos, clampf(float(count) - 6.0, -8.0, 4.0))


# ---------- 판정 ----------

func is_active() -> bool:
	if not _projectiles.is_empty():
		return true
	if not get_tree().get_nodes_in_group("fire_pool").is_empty():
		return true
	for s in structures:
		if s.any_burning() or s.any_moving():
			return true
	for e in enemies:
		if e.running:
			return true
	return false


func _set_state(s: int, message: String) -> void:
	if state != State.PLAYING:
		return
	state = s
	state_changed.emit(state, message)


func core_down() -> bool:
	var cores := get_tree().get_nodes_in_group("core")
	if cores.is_empty():
		return false
	for c in cores:
		var core := c as Block
		if not core.fallen:
			return false
		if core.touched_ground:
			continue
		if core.linear_velocity.length() > 0.5:
			return false
		var low := core.lowest_point()
		# 잔해 위에 걸쳐 멈춘 경우: 땅 가까이 내려왔거나 처음 높이의 절반 이상 떨어졌으면 인정
		if low < CORE_GROUND_HEIGHT or core.start_low - low >= maxf(2.0, core.start_low * 0.5):
			continue
		return false
	return true


func _physics_process(delta: float) -> void:
	elapsed += delta
	if state != State.PLAYING:
		return
	match goal:
		Goal.CORE:
			if core_down():
				_set_state(State.CLEARED, "코어가 땅에 닿았다")
				return
		Goal.ENEMY:
			var all_dead := not enemies.is_empty()
			for e in enemies:
				all_dead = all_dead and e.dead
			if all_dead:
				_set_state(State.CLEARED, "적을 쓰러뜨렸다")
				return
	if total_ammo() == 0:
		if is_active():
			_quiet = 0.0
		else:
			_quiet += delta
			if _quiet >= FAIL_QUIET_TIME:
				_set_state(State.FAILED, "화염병이 떨어졌다")
