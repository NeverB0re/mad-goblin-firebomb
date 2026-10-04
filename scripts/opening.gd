class_name Opening
extends CanvasLayer
## 컷만화 (대사 없이 그림만으로 이야기를 전한다). 칸을 만화 페이지처럼 한 칸씩 연다.
## 각 칸은 게임과 같은 단색 로우폴리 모델로 만든 작은 3D 장면이다.
##
## 오프닝 (확장 기획서 3장 이야기):
##  1. 폭발에 미친 발명가 고블린들의 작업장
##  2. 인간 병사들이 부족장을 우리에 가둬 끌고 간다
##  3. 인간 지휘관이 갇힌 부족장을 내세워 으름장을 놓는다
##  4. 고블린들은 대답 대신 폭탄에 불을 붙이며 웃는다 (협박이 통하지 않는다)
##  5. 지도: 고블린 폭탄이 인간 진지를 하나씩 박살 낸다
##  6. 절벽 위의 미친 고블린이 화염병에 불을 붙인다
## 엔딩: 본진이 박살 나고, 그을린 부족장이 고블린들과 함께 기뻐한다.

signal finished

enum Mode { OPENING, ENDING }

const VIEW_SIZE := Vector2i(640, 500)
const MARGIN := 0.03
const GUTTER := 0.018
const PAPER := Color(0.94, 0.91, 0.83)

var mode: int = Mode.OPENING
var _panels: Array[Control] = []
var _viewports: Array[SubViewport] = []
var _revealed := 0
var _animators: Array[Callable] = []
var _t := 0.0
var _done := false
var _root: Control


func _init(p_mode := Mode.OPENING) -> void:
	mode = p_mode


func panel_count() -> int:
	return 6 if mode == Mode.OPENING else 2


func _ready() -> void:
	layer = 10
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

	var n := panel_count()
	var cols := 3 if n > 2 else 2
	var rows := int(ceil(n / float(cols)))
	var bottom := 0.95
	var w := (1.0 - MARGIN * 2.0 - GUTTER * (cols - 1)) / cols
	var h := (bottom - MARGIN - GUTTER * (rows - 1)) / rows
	if rows == 1:
		h = minf(h, 0.7)
	for i in n:
		var col := i % cols
		var row := i / cols
		var panel := Control.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.anchor_left = MARGIN + col * (w + GUTTER)
		panel.anchor_right = panel.anchor_left + w
		panel.anchor_top = MARGIN + row * (h + GUTTER) + (0.12 if rows == 1 else 0.0)
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
		if mode == Mode.OPENING:
			call("_panel_%d" % (i + 1), vp)
		else:
			call("_ending_%d" % (i + 1), vp)
		panel.visible = false
		_panels.append(panel)
		_viewports.append(vp)

	var hint := Label.new()
	hint.text = Texts.t("opening_hint")
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


## 다음 칸을 연다. 모두 열린 뒤에는 컷만화를 끝낸다.
func reveal_next() -> void:
	if _done:
		return
	if _revealed >= panel_count():
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


func _cage(parent: Node3D, pos: Vector3) -> Node3D:
	var cage := Node3D.new()
	cage.position = pos
	parent.add_child(cage)
	var bars := Models.mat(Models.HUMAN_STEEL.darkened(0.3), 0.4, 0.7)
	for i in 8:
		var a := TAU * i / 8.0
		Models.cyl(cage, 0.035, 0.035, 2.0, Vector3(cos(a) * 0.65, 1.0, sin(a) * 0.65), bars)
	Models.cyl(cage, 0.72, 0.72, 0.1, Vector3(0, 2.0, 0), bars, Vector3.ZERO, 8)
	Models.cyl(cage, 0.72, 0.72, 0.1, Vector3(0, 0.02, 0), bars, Vector3.ZERO, 8)
	var chief := Models.chief()
	chief.scale = Vector3.ONE * 0.85
	cage.add_child(chief)
	Diorama.arm(chief, "ArmL", -2.6, 0.2)
	Diorama.arm(chief, "ArmR", 2.6, 0.2)
	return cage


# ---------- 1. 작업장: 폭발에 미친 발명가 고블린들 ----------

func _panel_1(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.55, 0.62, 0.7), Color(0.45, 0.4, 0.35), Vector3(0, 3.2, 6.0), Vector3(0, 1.0, 0))
	var wood := Models.mat(Color(0.5, 0.33, 0.18))
	Models.box(r, Vector3(8, 4, 0.4), Vector3(0, 2, -3.0), Models.mat(Color(0.38, 0.33, 0.3)))
	Models.box(r, Vector3(2.4, 0.15, 1.2), Vector3(0, 0.95, 0), wood)
	for lx in [-1.0, 1.0]:
		Models.box(r, Vector3(0.12, 0.9, 1.0), Vector3(lx, 0.45, 0), wood)
	for spec in [[-0.7, 0], [-0.35, 1], [0.6, 2]]:
		Diorama.place(Fx.ammo_model(spec[1], 1.6, false), r, Vector3(spec[0], 1.2, 0.2))
	Models.box(r, Vector3(3, 0.1, 0.5), Vector3(0, 2.3, -2.6), wood)
	for i in 6:
		Diorama.place(Fx.ammo_model(i % 3, 1.4, false), r, Vector3(-1.2 + i * 0.48, 2.5, -2.6))
	var boom := Fx.fire(Vector3(0.25, 0.1, 0.25), 40, 0.5)
	boom.position = Vector3(0.1, 1.2, 0)
	r.add_child(boom)
	var smoke := Fx.smoke_column(16)
	smoke.position = Vector3(0.1, 1.6, 0)
	r.add_child(smoke)
	var gobs: Array[Node3D] = []
	for spec in [[Vector3(-1.7, 0, 0.6), 60.0], [Vector3(1.7, 0, 0.6), -60.0], [Vector3(0.3, 0, -1.3), 175.0]]:
		var g := Diorama.place(Models.goblin(), r, spec[0], spec[1])
		Diorama.arm(g, "ArmL", -2.6)
		Diorama.arm(g, "ArmR", 2.6)
		gobs.append(g)
	_animators.append(func(t: float):
		for i in gobs.size():
			gobs[i].position.y = absf(sin(t * 7.0 + i * 1.3)) * 0.35)


# ---------- 2. 인간 병사들이 부족장을 우리에 가둬 끌고 간다 ----------

func _panel_2(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.85, 0.5, 0.38), Color(0.5, 0.42, 0.36), Vector3(0, 2.6, 7.0), Vector3(0.3, 1.2, 0), 52.0, Vector3(-30, -40, 0))
	var hut := Models.box(r, Vector3(2.4, 1.8, 1.6), Vector3(-3.6, 0.9, -2.2), Models.mat(Color(0.42, 0.28, 0.16)), Vector3(0, 0.1, 0.06))
	var hut_fire := Fx.fire(Vector3(1.0, 0.2, 0.6), 40, 0.6)
	hut_fire.position = hut.position + Vector3(0, 1.0, 0)
	r.add_child(hut_fire)
	var smoke := Fx.smoke_column(20)
	smoke.position = hut.position + Vector3(0, 1.5, 0)
	r.add_child(smoke)
	var cart := Node3D.new()
	r.add_child(cart)
	var steel := Models.mat(Models.HUMAN_STEEL, 0.5, 0.4)
	Models.box(cart, Vector3(2.0, 0.2, 1.4), Vector3(0, 0.55, 0), steel)
	var wheels: Array[Node3D] = []
	for wx in [-0.7, 0.7]:
		for wz in [-0.75, 0.75]:
			wheels.append(Models.cyl(cart, 0.32, 0.32, 0.1, Vector3(wx, 0.32, wz), Models.mat(Color(0.25, 0.25, 0.28)), Vector3(PI * 0.5, 0, 0), 8))
	_cage(cart, Vector3(0, 0.65, 0))
	var soldiers: Array[Node3D] = []
	for sz in [-0.5, 0.5]:
		var s := Models.human(Models.HUMAN_STEEL, Models.Hat.HELMET)
		cart.add_child(s)
		s.position = Vector3(2.6, 0, sz)
		s.rotation = Vector3(0, -PI * 0.5, 0)
		Diorama.arm(s, "ArmL", 0.0, -1.2)
		Diorama.arm(s, "ArmR", 0.0, -1.2)
		soldiers.append(s)
		Models.box(cart, Vector3(1.6, 0.05, 0.05), Vector3(1.6, 1.0, sz * 0.8), steel, Vector3(0, 0, -0.15))
	# 남은 고블린들은 주먹을 휘두르며 분해한다
	var fists: Array[Node3D] = []
	for p in [Vector3(-2.2, 0, 1.2), Vector3(-1.5, 0, 2.0)]:
		var g := Diorama.place(Models.goblin(), r, p, -70.0)
		fists.append(g.get_node("ArmR"))
		Diorama.arm(g, "ArmL", -2.2)
	_animators.append(func(t: float):
		var k := fmod(t * 0.35, 1.0)
		cart.position.x = -0.6 + k * 1.8
		for w in wheels:
			w.rotation.y = -t * 2.0
		for i in soldiers.size():
			soldiers[i].rotation.z = 0.25 + sin(t * 8.0 + i) * 0.05
		for i in fists.size():
			fists[i].rotation.z = 2.4 + sin(t * 12.0 + i) * 0.5)


# ---------- 3. 지휘관이 갇힌 부족장을 내세워 으름장을 놓는다 ----------

func _panel_3(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.3, 0.27, 0.35), Color(0.45, 0.43, 0.42), Vector3(0.6, 2.6, 7.0), Vector3(0.6, 1.3, 0), 50.0)
	var flag := Diorama.place(Models.flag(4.0), r, Vector3(3.8, 0, -1.4))
	var commander := Diorama.place(Models.commander(), r, Vector3(2.2, 0, 0), -70.0)
	Diorama.arm(commander, "ArmR", 0.0, -1.5)
	var cage := _cage(r, Vector3(3.2, 0, 1.2))
	for sx in [-1.0, 1.0]:
		var s := Diorama.place(Models.human(Models.HUMAN_STEEL, Models.Hat.HELMET), r, Vector3(2.4 + sx * 1.0, 0, -1.6), -60.0)
		Models.spear(s, Vector3(0.45, 0, -0.1))
	# 고블린들은 폭탄을 든 채 지휘관을 쳐다본다
	for i in 3:
		var g := Diorama.place(Models.goblin(), r, Vector3(-2.6 + i * 0.7, 0, 0.6 + (i % 2) * 0.6), 100.0)
		var bomb := Fx.ammo_model(i % 2, 1.6, false)
		bomb.position = Vector3(0, -0.6, 0)
		g.get_node("ArmR").add_child(bomb)
		Diorama.arm(g, "ArmR", 0.3, -0.6)
	_animators.append(func(t: float):
		commander.position.y = absf(sin(t * 2.6)) * 0.05
		commander.rotation.z = sin(t * 1.3) * 0.05
		var cloth: Node3D = flag.get_node("Cloth")
		cloth.rotation.y = sin(t * 3.0) * 0.25
		cage.rotation.y = sin(t * 0.7) * 0.1)


# ---------- 4. 대답 대신 폭탄에 불을 붙이며 웃는다 ----------

func _panel_4(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.95, 0.6, 0.3), Color(0.5, 0.4, 0.32), Vector3(0, 1.9, 4.2), Vector3(0, 1.3, 0), 52.0, Vector3(-25, 20, 0))
	var heads: Array[Node3D] = []
	var bodies: Array[Node3D] = []
	for i in 4:
		var x := -1.9 + i * 1.25
		var g := Diorama.place(Models.goblin(), r, Vector3(x, 0, -0.2 - (i % 2) * 0.7), 180.0 + (x * -12.0))
		# 카메라 쪽을 보고 웃는다
		g.rotation.y = deg_to_rad(180.0 + x * 10.0)
		Diorama.arm(g, "ArmR", 2.5)
		Diorama.arm(g, "ArmL", -1.2, -0.8)
		var bomb := Fx.ammo_model(i % 3, 1.8, true)
		bomb.position = Vector3(0, -0.65, 0)
		g.get_node("ArmR").add_child(bomb)
		heads.append(g.get_node("Head"))
		bodies.append(g)
		# 크게 벌린 입 (웃음)
		Models.box(g.get_node("Head"), Vector3(0.22, 0.09, 0.05), Vector3(0, -0.1, -0.25), Models.mat(Color(0.15, 0.05, 0.05)))
	_animators.append(func(t: float):
		for i in heads.size():
			heads[i].rotation.x = -0.3 + absf(sin(t * 9.0 + i)) * 0.35
			bodies[i].position.y = absf(sin(t * 4.5 + i * 0.8)) * 0.1)


# ---------- 5. 지도: 고블린 폭탄이 인간 진지를 하나씩 박살 낸다 ----------

func _panel_5(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.85, 0.79, 0.62), Color(0.86, 0.79, 0.6), Vector3(0, 11.0, 7.5), Vector3(0, 0, -1.0), 48.0, Vector3(-70, 20, 0))
	var ink := Models.mat(Color(0.3, 0.22, 0.15), 1.0)
	# 아래쪽: 고블린 절벽, 위쪽으로 인간 진지들이 이어지고 맨 끝이 본진
	Models.box(r, Vector3(3, 1.2, 2), Vector3(0, 0.6, 4.5), Models.mat(Color(0.33, 0.31, 0.3)))
	var gob := Diorama.place(Models.goblin(), r, Vector3(0, 1.2, 4.2), 0.0)
	gob.scale = Vector3.ONE * 1.4
	var forts: Array[Node3D] = []
	var spots := [Vector3(-3.5, 0, 1.5), Vector3(2.5, 0, 0.0), Vector3(-1.5, 0, -2.5), Vector3(3.5, 0, -4.0), Vector3(0, 0, -6.5)]
	for i in spots.size():
		var t := Models.tower(2.0 if i < 4 else 3.4, Models.HUMAN_STEEL.lightened(0.2))
		Diorama.place(t, r, spots[i])
		forts.append(t)
		var prev: Vector3 = Vector3(0, 0, 4.2) if i == 0 else spots[i - 1]
		for k in range(1, 6):
			var p := prev.lerp(spots[i], k / 6.0)
			Models.box(r, Vector3(0.18, 0.02, 0.18), Vector3(p.x, 0.01, p.z), ink)
	var bomb := Diorama.place(Fx.ammo_model(AmmoType.Kind.FIRE, 3.0, true), r, Vector3.ZERO)
	var booms: Array[GPUParticles3D] = []
	for i in spots.size():
		var b := Fx.fire(Vector3(0.5, 0.3, 0.5), 30, 0.6)
		b.position = spots[i] + Vector3(0, 1.5, 0)
		b.emitting = false
		r.add_child(b)
		booms.append(b)
	_animators.append(func(t: float):
		# 폭탄이 진지를 차례로 맞히고, 맞은 진지는 기울어지고 불탄다 (반복)
		var cycle := fmod(t * 0.7, spots.size() + 1.5)
		var i := mini(int(cycle), spots.size() - 1)
		var k := clampf(cycle - i, 0.0, 1.0)
		var from: Vector3 = Vector3(0, 2.2, 4.2) if i == 0 else spots[i - 1] + Vector3(0, 2, 0)
		var to: Vector3 = spots[i] + Vector3(0, 2.0, 0)
		var p := from.lerp(to, k)
		p.y += sin(k * PI) * 3.0
		bomb.position = p
		bomb.visible = cycle < spots.size()
		for j in forts.size():
			var hit := j < i or (j == i and k >= 1.0) or cycle >= spots.size()
			forts[j].rotation.z = 0.35 if hit else 0.0
			booms[j].emitting = hit)


# ---------- 6. 절벽 위의 미친 고블린이 화염병에 불을 붙인다 ----------

func _panel_6(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.95, 0.55, 0.3), Color(0.55, 0.45, 0.4), Vector3(-2.2, 13.4, 3.6), Vector3(1.0, 10.0, -12.0), 55.0, Vector3(-15, 160, 0))
	var rock := Models.mat(Color(0.3, 0.27, 0.26))
	Models.box(r, Vector3(6, 12, 6), Vector3(0, 6, 0), rock)
	Models.box(r, Vector3(8, 6, 8), Vector3(0.5, 3, 1.5), Models.mat(Color(0.25, 0.22, 0.22)))
	for p in [Vector3(-6, 0, -26), Vector3(4, 0, -32), Vector3(14, 0, -24), Vector3(-14, 0, -36)]:
		Diorama.place(Models.tower(4.0, Models.HUMAN_STEEL.lightened(0.2)), r, p).scale = Vector3.ONE * 1.6
	# 등을 보이고 아래의 진지들을 내려다본다
	var g := Diorama.place(Models.goblin(), r, Vector3(0.4, 12, -1.2), 15.0)
	Diorama.arm(g, "ArmR", 2.7)
	var bomb := Fx.molotov_model(1.6, true)
	bomb.position = Vector3(0, -0.62, 0)
	g.get_node("ArmR").add_child(bomb)
	_animators.append(func(t: float):
		g.position.y = 12.0 + absf(sin(t * 3.0)) * 0.05)


# ---------- 엔딩 ----------

## 1. 인간 본진 위로 거대한 고블린 로켓이 떨어져 박살 난다.
func _ending_1(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.4, 0.3, 0.35), Color(0.45, 0.42, 0.4), Vector3(6, 10, 34), Vector3(0, 9, -2), 50.0)
	var keep := Models.tower(5.0, Models.HUMAN_STEEL.lightened(0.2))
	keep.scale = Vector3.ONE * 2.2
	Diorama.place(keep, r, Vector3(0, 0, -2))
	var rocket := Node3D.new()
	r.add_child(rocket)
	var wood := Models.mat(Color(0.42, 0.28, 0.16))
	Models.cyl(rocket, 0.35, 0.45, 3.0, Vector3.ZERO, Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5), Vector3(0, 0, 0.08), 8)
	Models.cyl(rocket, 0.0, 0.4, 0.8, Vector3(0, 1.9, 0), Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5), Vector3.ZERO, 8)
	for a in [0.0, 2.1, 4.2]:
		Models.box(rocket, Vector3(0.1, 0.8, 0.6), Vector3(cos(a) * 0.45, -1.2, sin(a) * 0.45), wood, Vector3(0, -a, 0))
	Models.box(rocket, Vector3(0.95, 0.08, 0.95), Vector3(0, 0.4, 0), Models.mat(Color(0.5, 0.35, 0.2)), Vector3(0.1, 0, 0.1))
	var trail := Fx.fire(Vector3(0.2, 0.2, 0.2), 40, 0.6)
	trail.local_coords = false
	trail.position = Vector3(0, -1.6, 0)
	rocket.add_child(trail)
	var boom := Fx.fire(Vector3(3, 2, 3), 80, 1.2)
	boom.position = Vector3(0, 9, -2)
	boom.emitting = false
	r.add_child(boom)
	_animators.append(func(t: float):
		var k := fmod(t * 0.45, 1.6)
		rocket.visible = k < 1.0
		rocket.position = Vector3(-8, 26, -2).lerp(Vector3(0, 11, -2), minf(k, 1.0))
		rocket.rotation.z = -0.5
		boom.emitting = k >= 1.0
		keep.rotation.z = 0.25 if k >= 1.0 else 0.0)


## 2. 그을린 부족장이 고블린들과 함께 기뻐한다.
func _ending_2(vp: SubViewport) -> void:
	var r := Diorama.scene(vp, Color(0.98, 0.75, 0.4), Color(0.5, 0.45, 0.36), Vector3(0, 2.4, 5.5), Vector3(0, 1.2, 0), 50.0)
	var chief := Diorama.place(Models.chief(), r, Vector3(0, 0, 0), 180.0)
	chief.scale = Vector3.ONE * 1.15
	# 그을림 (검은 얼룩, 삐죽 선 깃털)
	var soot := Models.mat(Color(0.08, 0.07, 0.06))
	Models.box(chief.get_node("Head"), Vector3(0.36, 0.14, 0.05), Vector3(0, -0.05, -0.25), soot)
	Models.box(chief, Vector3(0.5, 0.3, 0.05), Vector3(0.05, 0.9, -0.34), soot)
	var jumpers: Array[Node3D] = [chief]
	for p in [Vector3(-1.6, 0, 0.6), Vector3(1.6, 0, 0.6), Vector3(-0.9, 0, -1.2), Vector3(1.0, 0, -1.3)]:
		jumpers.append(Diorama.place(Models.goblin(), r, p, 180.0 + p.x * 15.0))
	for g in jumpers:
		Diorama.arm(g, "ArmL", -2.7)
		Diorama.arm(g, "ArmR", 2.7)
	var sparks := Fx.fire(Vector3(3, 0.2, 2), 50, 0.3)
	sparks.position = Vector3(0, 3.5, -1)
	r.add_child(sparks)
	_animators.append(func(t: float):
		for i in jumpers.size():
			jumpers[i].position.y = absf(sin(t * 6.0 + i * 1.1)) * 0.5)
