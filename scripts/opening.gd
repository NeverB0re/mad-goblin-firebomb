class_name Opening
extends CanvasLayer
## 오프닝 컷만화. 대사 없이 그림만으로 이야기를 전한다. 6컷을 만화 페이지처럼 한 칸씩 연다.
## 각 칸은 게임과 같은 단색 로우폴리 모델로 만든 작은 3D 장면이다.
##  1. 폭발물에 미친 발명가 고블린들의 작업장
##  2. 고블린들이 모시는 기계장치의 신
##  3. 남작의 병사들이 신상을 사슬로 끌고 간다
##  4. 남작이 우리에 갇힌 신상을 가리키고, 고블린들은 창 앞에서 남작의 무기를 만든다
##  5. 신상이 분해되어 부품이 영지 곳곳의 요새로 흩어진다 (지도)
##  6. 절벽 위의 미친 고블린이 화염병에 불을 붙인다

signal finished

const PANEL_COUNT := 6
const VIEW_SIZE := Vector2i(640, 500)
const MARGIN := 0.03
const GUTTER := 0.018
const PAPER := Color(0.94, 0.91, 0.83)

var _panels: Array[Control] = []
var _viewports: Array[SubViewport] = []
var _revealed := 0
var _animators: Array[Callable] = []
var _t := 0.0
var _done := false
var _root: Control
var _gold: StandardMaterial3D
var _dark: StandardMaterial3D


func _ready() -> void:
	layer = 10
	_gold = Models.gold_material()
	_dark = Models.mat(Color(0.2, 0.17, 0.12), 0.5, 0.4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var bottom := 0.95
	var w := (1.0 - MARGIN * 2.0 - GUTTER * 2.0) / 3.0
	var h := (bottom - MARGIN - GUTTER) / 2.0
	for i in PANEL_COUNT:
		var col := i % 3
		var row := i / 3
		var panel := Control.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.anchor_left = MARGIN + col * (w + GUTTER)
		panel.anchor_right = panel.anchor_left + w
		panel.anchor_top = MARGIN + row * (h + GUTTER)
		panel.anchor_bottom = panel.anchor_top + h
		_root.add_child(panel)
		var border := ColorRect.new()
		border.color = Color(0.06, 0.06, 0.06)
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(border)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.offset_left = 5
		container.offset_top = 5
		container.offset_right = -5
		container.offset_bottom = -5
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(container)
		var vp := SubViewport.new()
		vp.size = VIEW_SIZE
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		container.add_child(vp)
		call("_panel_%d" % (i + 1), vp)
		panel.visible = false
		_panels.append(panel)
		_viewports.append(vp)

	var hint := Label.new()
	hint.text = "클릭 / 스페이스 ▶     Esc 건너뛰기"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "sans-serif"])
	hint.add_theme_font_override("font", font)
	hint.anchor_left = 0.5
	hint.anchor_right = 1.0 - MARGIN
	hint.anchor_top = bottom
	hint.anchor_bottom = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	get_tree().create_timer(0.35).timeout.connect(reveal_next)


## 다음 칸을 연다. 모두 열린 뒤에는 오프닝을 끝낸다.
func reveal_next() -> void:
	if _done:
		return
	if _revealed >= PANEL_COUNT:
		finish()
		return
	var panel := _panels[_revealed]
	_viewports[_revealed].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * 0.88
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	_revealed += 1


func finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


func _input(event: InputEvent) -> void:
	if _done:
		return
	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			finish()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT]:
			advance = true
	if advance:
		reveal_next()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	for a in _animators:
		a.call(_t)


# ---------- 장면 도우미 ----------

func _scene(vp: SubViewport, sky: Color, ground: Color, cam_pos: Vector3, look: Vector3, fov := 50.0, sun_rot := Vector3(-50, 30, 0)) -> Node3D:
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = sky.lerp(Color.WHITE, 0.5)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	root.add_child(sun)
	Models.box(root, Vector3(80, 1, 80), Vector3(0, -0.5, 0), Models.mat(ground, 1.0))
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.position = cam_pos
	cam.look_at_from_position(cam_pos, look, Vector3.UP)
	cam.current = true
	return root


func _place(node: Node3D, parent: Node3D, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(node)
	return node


func _arm(n: Node3D, side: String, z_angle: float, x_angle := 0.0) -> void:
	var arm: Node3D = n.get_node_or_null(side)
	if arm:
		arm.rotation = Vector3(x_angle, 0, z_angle)


# ---------- 1. 작업장: 폭발물에 미친 발명가 고블린들 ----------

func _panel_1(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.55, 0.62, 0.7), Color(0.45, 0.4, 0.35), Vector3(0, 3.2, 6.0), Vector3(0, 1.0, 0))
	var wood := Models.mat(Color(0.5, 0.33, 0.18))
	Models.box(r, Vector3(8, 4, 0.4), Vector3(0, 2, -3.0), Models.mat(Color(0.38, 0.33, 0.3)))
	Models.box(r, Vector3(2.4, 0.15, 1.2), Vector3(0, 0.95, 0), wood)
	for lx in [-1.0, 1.0]:
		Models.box(r, Vector3(0.12, 0.9, 1.0), Vector3(lx, 0.45, 0), wood)
	# 탁자 위 화염병과 톱니
	for bx in [-0.7, -0.35, 0.6]:
		_place(Fx.molotov_model(1.6, false), r, Vector3(bx, 1.2, 0.2))
	Models.gear(r, 0.35, 0.08, Vector3(0.1, 1.08, -0.3), _dark, _gold)
	# 선반 위 화염병 더미
	Models.box(r, Vector3(3, 0.1, 0.5), Vector3(0, 2.3, -2.6), wood)
	for i in 6:
		_place(Fx.molotov_model(1.4, false), r, Vector3(-1.2 + i * 0.48, 2.5, -2.6))
	# 탁자 가운데에서 터지는 폭발 (반복)
	var boom := Fx.fire(Vector3(0.25, 0.1, 0.25), 40, 0.5)
	boom.position = Vector3(0.1, 1.2, 0)
	r.add_child(boom)
	var smoke := Fx.smoke_column(16)
	smoke.position = Vector3(0.1, 1.6, 0)
	r.add_child(smoke)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.6, 0.2)
	flash.omni_range = 5.0
	flash.position = Vector3(0.1, 1.6, 0.3)
	r.add_child(flash)
	# 신난 고블린 셋: 팔을 번쩍 들고 펄쩍펄쩍 뛴다
	var gobs: Array[Node3D] = []
	for spec in [[Vector3(-1.7, 0, 0.6), 60.0], [Vector3(1.7, 0, 0.6), -60.0], [Vector3(0.3, 0, -1.3), 175.0]]:
		var g := _place(Models.goblin(), r, spec[0], spec[1])
		_arm(g, "ArmL", -2.6)
		_arm(g, "ArmR", 2.6)
		gobs.append(g)
	_animators.append(func(t: float):
		flash.light_energy = 2.0 + 3.0 * absf(sin(t * 6.0))
		for i in gobs.size():
			gobs[i].position.y = absf(sin(t * 7.0 + i * 1.3)) * 0.35)


# ---------- 2. 고블린들이 모시는 기계장치의 신 ----------

func _panel_2(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.32, 0.28, 0.4), Color(0.4, 0.36, 0.33), Vector3(3.2, 2.4, 5.2), Vector3(0, 1.6, 0), 48.0)
	Models.box(r, Vector3(1.8, 0.5, 1.4), Vector3(0, 0.25, 0), Models.mat(Color(0.5, 0.48, 0.46)))
	var statue := _place(Models.statue(_gold, _dark), r, Vector3(0, 0.5, 0))
	statue.scale = Vector3.ONE * 1.25
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.3)
	glow.omni_range = 6.0
	glow.position = Vector3(0, 2.0, 1.5)
	r.add_child(glow)
	var heart: Node3D = statue.get_node("Part%d" % Models.Part.HEART).find_child("Spin", true, false)
	# 엎드려 절하는 고블린들 (신상을 바라본다)
	var gobs: Array[Node3D] = []
	for p in [Vector3(-1.4, 0, 1.8), Vector3(0, 0, 2.2), Vector3(1.4, 0, 1.8), Vector3(-2.2, 0, 0.6)]:
		var g := Models.goblin()
		r.add_child(g)
		g.position = p
		g.look_at(Vector3(0, 0, 0), Vector3.UP)
		_arm(g, "ArmL", -2.4, -0.6)
		_arm(g, "ArmR", 2.4, -0.6)
		gobs.append(g)
	_animators.append(func(t: float):
		if heart:
			heart.rotate_y(0.02)
		glow.light_energy = 2.5 + sin(t * 2.0) * 0.8
		for i in gobs.size():
			# 몸을 숙였다 폈다 하며 절한다
			gobs[i].rotation.x = -0.15 - 0.45 * absf(sin(t * 2.2 + i * 0.6)))


# ---------- 3. 남작의 병사들이 신상을 끌고 간다 ----------

func _panel_3(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.85, 0.5, 0.38), Color(0.5, 0.42, 0.36), Vector3(0, 2.6, 7.0), Vector3(0.3, 1.2, 0), 52.0, Vector3(-30, -40, 0))
	# 불타는 작업장
	var hut := Models.box(r, Vector3(2.4, 1.8, 1.6), Vector3(-3.6, 0.9, -2.2), Models.mat(Color(0.35, 0.3, 0.28)))
	var hut_fire := Fx.fire(Vector3(1.0, 0.2, 0.6), 40, 0.6)
	hut_fire.position = hut.position + Vector3(0, 1.0, 0)
	r.add_child(hut_fire)
	var smoke := Fx.smoke_column(20)
	smoke.position = hut.position + Vector3(0, 1.5, 0)
	r.add_child(smoke)
	# 수레에 실려 사슬로 끌려가는 신상
	var cart := Node3D.new()
	r.add_child(cart)
	var wood := Models.mat(Color(0.45, 0.3, 0.17))
	Models.box(cart, Vector3(2.0, 0.2, 1.2), Vector3(0, 0.55, 0), wood)
	var wheels: Array[Node3D] = []
	for wx in [-0.7, 0.7]:
		for wz in [-0.65, 0.65]:
			wheels.append(Models.cyl(cart, 0.32, 0.32, 0.1, Vector3(wx, 0.32, wz), Models.mat(Color(0.25, 0.2, 0.15)), Vector3(PI * 0.5, 0, 0), 8))
	var statue := _place(Models.statue(_gold, _dark), cart, Vector3(0, 0.65, 0))
	statue.rotation.z = -0.25
	var chain := Models.mat(Color(0.3, 0.3, 0.32), 0.4, 0.6)
	# 앞에서 끄는 병사 둘
	var soldiers: Array[Node3D] = []
	for sz in [-0.5, 0.5]:
		var s := Models.human(Models.ENEMY_RED, Models.Hat.HELMET)
		cart.add_child(s)
		s.position = Vector3(2.6, 0, sz)
		s.rotation = Vector3(0, -PI * 0.5, 0)
		_arm(s, "ArmL", 0.0, -1.2)
		_arm(s, "ArmR", 0.0, -1.2)
		soldiers.append(s)
		Models.box(cart, Vector3(1.6, 0.05, 0.05), Vector3(1.6, 1.0, sz * 0.8), chain, Vector3(0, 0, -0.15))
	# 뒤에 남아 절망하는 고블린들 (머리를 감싸 쥔다)
	for p in [Vector3(-2.2, 0, 1.2), Vector3(-1.5, 0, 2.0)]:
		var g := _place(Models.goblin(), r, p, -60.0)
		_arm(g, "ArmL", -2.9, 0.4)
		_arm(g, "ArmR", 2.9, 0.4)
	_animators.append(func(t: float):
		# 오른쪽으로 끌려가다 처음 자리로 돌아오기를 반복
		var k := fmod(t * 0.35, 1.0)
		cart.position.x = -0.6 + k * 1.8
		for w in wheels:
			w.rotation.y = -t * 2.0
		for i in soldiers.size():
			soldiers[i].rotation.z = 0.25 + sin(t * 8.0 + i) * 0.05)


# ---------- 4. 남작의 협박: 신상은 우리 속에, 고블린은 창 앞에서 무기를 만든다 ----------

func _panel_4(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.28, 0.24, 0.3), Color(0.42, 0.4, 0.4), Vector3(0.5, 3.0, 7.2), Vector3(0.3, 1.4, 0), 50.0)
	# 우리에 갇힌 신상
	var statue := _place(Models.statue(_gold, _dark), r, Vector3(2.6, 0, -1.6))
	var bars := Models.mat(Color(0.18, 0.18, 0.2), 0.4, 0.7)
	for i in 7:
		var a := TAU * i / 7.0
		Models.cyl(r, 0.04, 0.04, 2.8, Vector3(2.6 + cos(a) * 0.95, 1.4, -1.6 + sin(a) * 0.95), bars)
	Models.cyl(r, 1.05, 1.05, 0.12, Vector3(2.6, 2.85, -1.6), bars, Vector3.ZERO, 7)
	var spot := SpotLight3D.new()
	spot.position = Vector3(2.6, 5, -1.6)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color(1, 0.85, 0.5)
	spot.light_energy = 4.0
	spot.spot_angle = 25.0
	r.add_child(spot)
	# 남작: 왕관과 보라 망토, 고블린들을 가리킨다
	var baron := _place(Models.human(Color(0.75, 0.1, 0.1), Models.Hat.CROWN, 1.35, Color(0.4, 0.15, 0.55)), r, Vector3(1.0, 0, 0.4), 70.0)
	_arm(baron, "ArmR", 0.0, -1.5)
	# 모루에서 망치질하는 고블린들과 쌓여 가는 화염병
	var anvil := Models.mat(Color(0.15, 0.15, 0.17), 0.4, 0.6)
	var hammers: Array[Node3D] = []
	for p in [Vector3(-2.2, 0, 0.8), Vector3(-1.2, 0, 1.6)]:
		Models.box(r, Vector3(0.6, 0.5, 0.4), p + Vector3(0.3, 0.25, -0.5), anvil)
		var g := _place(Models.goblin(), r, p, 160.0)
		g.rotation.x = 0.25
		hammers.append(g.get_node("ArmR"))
		_arm(g, "ArmL", 0.0, -0.8)
	for i in 5:
		_place(Fx.molotov_model(1.5, false), r, Vector3(-2.6 + i * 0.3, 0.12, 2.2))
	# 창을 든 감시병
	var guard := _place(Models.human(Models.ENEMY_RED, Models.Hat.HELMET), r, Vector3(-3.0, 0, -0.8), -30.0)
	Models.spear(guard, Vector3(0.45, 0, -0.1), Vector3(0, 0, 0.1))
	_animators.append(func(t: float):
		for i in hammers.size():
			hammers[i].rotation.x = -1.6 + absf(sin(t * 6.0 + i * 1.7)) * 1.4
		statue.rotation.y = sin(t * 0.8) * 0.15)


# ---------- 5. 분해된 신상의 부품이 영지 곳곳의 요새로 흩어진다 ----------

func _panel_5(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.85, 0.79, 0.62), Color(0.86, 0.79, 0.6), Vector3(0, 11.0, 6.5), Vector3(0, 0, -0.3), 48.0, Vector3(-70, 20, 0))
	var ink := Models.mat(Color(0.3, 0.22, 0.15), 1.0)
	# 가운데: 남작의 성과 빈 받침대
	_place(Models.tower(2.4, Color(0.55, 0.45, 0.45)), r, Vector3(0, 0, 0)).scale = Vector3.ONE * 1.2
	var parts: Array[Node3D] = []
	var targets: Array[Vector3] = []
	for i in Models.PART_COUNT:
		var a := TAU * i / Models.PART_COUNT + 0.3
		var dest := Vector3(cos(a) * 5.2, 0, sin(a) * 3.4)
		_place(Models.tower(1.6), r, dest)
		# 점선 경로
		for k in range(1, 7):
			var p := dest * (k / 7.0)
			Models.box(r, Vector3(0.18, 0.02, 0.18), Vector3(p.x, 0.01, p.z), ink)
		var part := _place(Models.idol_part(i, _gold, _dark), r, Vector3.ZERO)
		part.scale = Vector3.ONE * 0.9
		parts.append(part)
		targets.append(dest + Vector3(0, 2.6, 0))
	_animators.append(func(t: float):
		# 성 위에서 부품들이 포물선을 그리며 각 요새로 날아가 앉는다 (반복)
		var k := clampf(fmod(t * 0.4, 1.25), 0.0, 1.0)
		for i in parts.size():
			var start := Vector3(0, 3.6, 0)
			var p := start.lerp(targets[i], k)
			p.y += sin(k * PI) * 2.0
			parts[i].position = p
			parts[i].rotation.y = t * 2.0 + i)


# ---------- 6. 절벽 위의 미친 고블린이 화염병에 불을 붙인다 ----------

func _panel_6(vp: SubViewport) -> void:
	var r := _scene(vp, Color(0.95, 0.55, 0.3), Color(0.55, 0.45, 0.4), Vector3(-2.2, 13.4, 3.6), Vector3(1.0, 10.0, -12.0), 55.0, Vector3(-15, 160, 0))
	var rock := Models.mat(Color(0.3, 0.27, 0.26))
	Models.box(r, Vector3(6, 12, 6), Vector3(0, 6, 0), rock)
	Models.box(r, Vector3(8, 6, 8), Vector3(0.5, 3, 1.5), Models.mat(Color(0.25, 0.22, 0.22)))
	# 멀리 아래에 보이는 남작의 요새들
	for p in [Vector3(-6, 0, -26), Vector3(4, 0, -32), Vector3(14, 0, -24), Vector3(-14, 0, -36)]:
		_place(Models.tower(4.0), r, p).scale = Vector3.ONE * 1.6
	# 등을 보이고 아래의 요새들을 내려다본다
	var g := _place(Models.goblin(), r, Vector3(0.4, 12, -1.2), 15.0)
	_arm(g, "ArmR", 2.7)
	var bomb := Fx.molotov_model(1.6, true)
	var arm_r: Node3D = g.get_node("ArmR")
	bomb.position = Vector3(0, -0.62, 0)
	arm_r.add_child(bomb)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.6, 0.2)
	glow.omni_range = 3.0
	bomb.add_child(glow)
	_animators.append(func(t: float):
		glow.light_energy = 1.5 + absf(sin(t * 9.0)) * 1.5
		g.position.y = 12.0 + absf(sin(t * 3.0)) * 0.05)
