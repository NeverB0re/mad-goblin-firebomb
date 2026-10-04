class_name Opening
extends CanvasLayer
## 컷만화 (대사 없이 그림만으로 이야기를 전한다). 2D로 직접 그린 칸을 만화 페이지처럼 한 칸씩 연다.
##
## 오프닝 (확장 기획서 3장 이야기):
##  1. 폭발에 미친 발명가 고블린들의 작업장
##  2. 인간 병사들이 부족장을 우리에 가둬 끌고 간다
##  3. 인간 지휘관이 갇힌 부족장을 내세워 으름장을 놓는다
##  4. 고블린들은 대답 대신 폭탄에 불을 붙이며 웃는다 (협박이 통하지 않는다)
##  5. 지도: 고블린 폭탄이 인간 진지를 하나씩 박살 낸다
##  6. 언덕 위의 미친 고블린이 화염병에 불을 붙인다
## 엔딩: 후방의 탄도미사일 발사 → 본진이 박살 나며 지휘관이 날아감 → 그을린 부족장과 고블린들이 기뻐한다.
## 월드 시작 (두 칸): 그 월드의 인간 지휘관이 부족장을 내세워 으름장 → 고블린들이 새 무기에 불을 붙이며 웃는다.
## 4월드만 세 칸: 으름장 → 그을린 동료가 글라이더를 메고 폭탄을 안은 채 자랑한다 → 동료가 조명탄을 건넨다 (조명탄 불빛 위에서 폭탄을 안고 뛰어내린다).

signal finished

enum Mode { OPENING, ENDING, WORLD }

const MARGIN := 0.03
const GUTTER := 0.018
const PAPER := Color(0.94, 0.91, 0.83)
const A := preload("res://scripts/comic_art.gd")

var mode: int = Mode.OPENING
## 월드 시작 컷의 월드 번호 (0~4)
var world := 0
var _panels: Array[Control] = []
var _revealed := 0
var _done := false
var _root: Control


func _init(p_mode := Mode.OPENING, p_world := 0) -> void:
	mode = p_mode
	world = p_world


func panel_count() -> int:
	match mode:
		Mode.OPENING:
			return 6
		Mode.ENDING:
			return 3
	# 4월드는 한 칸 더: 동료가 글라이더 폭격을 보여 주고 조명탄을 건넨다
	return 3 if world == 3 else 2


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var cols := 3 if n > 3 else n
	var rows := int(ceil(n / float(cols)))
	var bottom := 0.95
	var w := (1.0 - MARGIN * 2.0 - GUTTER * (cols - 1)) / cols
	var h := (bottom - MARGIN - GUTTER * (rows - 1)) / rows
	if rows == 1:
		h = minf(h, 0.72)
	for i in n:
		var col := i % cols
		var row := i / cols
		var panel := Control.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.anchor_left = MARGIN + col * (w + GUTTER)
		panel.anchor_right = panel.anchor_left + w
		panel.anchor_top = MARGIN + row * (h + GUTTER) + (0.1 if rows == 1 else 0.0)
		panel.anchor_bottom = panel.anchor_top + h
		_root.add_child(panel)
		var border := ColorRect.new()
		border.color = Color(0.06, 0.06, 0.06)
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(border)
		var art := ComicPanel.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 5
		art.offset_top = 5
		art.offset_right = -5
		art.offset_bottom = -5
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.clip_contents = true
		match mode:
			Mode.OPENING:
				art.painter = Callable(self, "_panel_%d" % (i + 1))
			Mode.ENDING:
				art.painter = Callable(self, "_ending_%d" % (i + 1))
			_:
				art.painter = Callable(self, "_world_%d" % (i + 1))
		panel.add_child(art)
		panel.visible = false
		_panels.append(panel)

	var hint := Label.new()
	hint.text = Texts.t("opening_hint")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	hint.add_theme_font_override("font", UiStyle.BOLD)
	hint.anchor_left = 0.5
	hint.anchor_right = 1.0 - MARGIN
	hint.anchor_top = bottom
	hint.anchor_bottom = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	get_tree().create_timer(0.35, true, false, true).timeout.connect(reveal_next)


## 다음 칸을 연다. 모두 열린 뒤에는 컷만화를 끝낸다.
func reveal_next() -> void:
	if _done:
		return
	if _revealed >= panel_count():
		finish()
		return
	var panel := _panels[_revealed]
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


# ---------- 오프닝 ----------

## 1. 작업장: 폭탄을 만지는 고블린들, 뒤에서 하나가 터져 날아가도 신났다.
func _panel_1(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.42, 0.3, 0.22), Color(0.55, 0.4, 0.28), Color(0.35, 0.26, 0.2), 0.7)
	for i in 4:
		A.rect(c, Vector2(s.x * (0.08 + i * 0.24), s.y * 0.12), Vector2(s.x * 0.12, s.y * 0.08), Color(0.6, 0.5, 0.35), 2.0, 6.0)
	A.rect(c, Vector2(s.x * 0.15, s.y * 0.66), Vector2(s.x * 0.7, s.y * 0.06), A.WOOD)
	for i in 3:
		A.bomb(c, Vector2(s.x * (0.3 + i * 0.12), s.y * 0.63), 1.2, i == 1, t, i)
	A.goblin(c, Vector2(s.x * 0.22, s.y * 0.95), 1.6, {"bomb": true, "grin": true}, t)
	A.goblin(c, Vector2(s.x * 0.62, s.y * 0.95), 1.5, {"flip": true, "crazy": true}, t)
	A.boom(c, Vector2(s.x * 0.85, s.y * 0.35), 50.0, t)
	A.goblin(c, Vector2(s.x * 0.85, s.y * 0.32 - absf(sin(t * 2.0)) * 20.0), 0.9, {"arms_up": true, "grin": true, "soot": true}, t)


## 2. 인간 병사들이 부족장을 우리에 가둬 끌고 간다. 마을 고블린이 숨어서 본다.
func _panel_2(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.55, 0.62, 0.72), Color(0.82, 0.8, 0.7), Color(0.5, 0.56, 0.38), 0.68)
	A.hut(c, Vector2(s.x * 0.12, s.y * 0.68), 70, 50)
	A.hut(c, Vector2(s.x * 0.3, s.y * 0.68), 60, 44)
	var x := s.x * 0.4 + fmod(t * 12.0, 30.0)
	A.rect(c, Vector2(x, s.y * 0.72), Vector2(150, 18), A.WOOD)
	for wx in [20.0, 130.0]:
		A.ellipse(c, Vector2(x + wx, s.y * 0.8), Vector2(14, 14), A.WOOD.darkened(0.3))
	A.chief(c, Vector2(x + 75, s.y * 0.72), 1.0, {"sad": true}, t)
	A.cage(c, Vector2(x + 20, s.y * 0.72 - 110), Vector2(110, 110))
	A.human(c, Vector2(x + 190, s.y * 0.9), 1.1, false, {}, t)
	A.human(c, Vector2(x + 240, s.y * 0.92), 1.1, false, {}, t)
	A.goblin(c, Vector2(s.x * 0.08, s.y * 0.97), 1.0, {"crazy": true}, t)


## 3. 인간 지휘관이 우리 속 부족장을 내세워 으름장을 놓는다.
func _panel_3(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.35, 0.3, 0.42), Color(0.6, 0.52, 0.55), Color(0.42, 0.4, 0.4), 0.7)
	A.tower(c, Vector2(s.x * 0.8, s.y * 0.7), 90, 150)
	A.flag(c, Vector2(s.x * 0.62, s.y * 0.92), 140, t)
	A.human(c, Vector2(s.x * 0.5, s.y * 0.95), 2.0, true, {"point": true, "flip": true}, t)
	A.chief(c, Vector2(s.x * 0.22, s.y * 0.93), 1.1, {"sad": true}, t)
	A.cage(c, Vector2(s.x * 0.12, s.y * 0.93 - 130), Vector2(130, 130))


## 4. 고블린들은 대답 대신 폭탄에 불을 붙이며 웃는다.
func _panel_4(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.98, 0.62, 0.3), Color(1.0, 0.85, 0.5), Color(0.55, 0.42, 0.3), 0.8)
	for i in 3:
		A.goblin(c, Vector2(s.x * (0.22 + i * 0.28), s.y * (1.02 + (i % 2) * 0.04)), 2.3 - (i % 2) * 0.3, {"bomb": true, "grin": true, "bomb_kind": i, "bounce": true}, t)


## 5. 지도: 고블린 폭탄이 인간 진지를 하나씩 박살 낸다.
func _panel_5(c: CanvasItem, s: Vector2, t: float) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.9, 0.84, 0.66))
	var pts := [Vector2(0.1, 0.85), Vector2(0.3, 0.65), Vector2(0.5, 0.72), Vector2(0.65, 0.45), Vector2(0.8, 0.3), Vector2(0.9, 0.12)]
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1] * s
		var b: Vector2 = pts[i] * s
		for k in 6:
			A.line(c, a.lerp(b, k / 6.0), a.lerp(b, (k + 0.5) / 6.0), 3.0, Color(0.45, 0.3, 0.2))
	A.goblin(c, pts[0] * s + Vector2(0, 30), 0.8, {"grin": true}, t)
	var lit := int(fmod(t * 1.2, pts.size() + 1.0))
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i] * s
		A.tower(c, p + Vector2(0, 20), 34, 30, i % 2 == 0)
		A.flag(c, p + Vector2(16, -10), 26, t)
		if i <= lit:
			A.boom(c, p, 28.0, t + i)


## 6. 언덕 위의 미친 고블린이 화염병에 불을 붙인다. 아래로 인간 진지가 보인다.
func _panel_6(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.95, 0.45, 0.25), Color(1.0, 0.8, 0.45), Color(0.45, 0.4, 0.3), 0.75)
	A.tower(c, Vector2(s.x * 0.78, s.y * 0.75), 40, 50)
	A.flag(c, Vector2(s.x * 0.86, s.y * 0.75), 50, t)
	A.shape(c, PackedVector2Array([Vector2(0, s.y), Vector2(0, s.y * 0.7), Vector2(s.x * 0.35, s.y * 0.66), Vector2(s.x * 0.5, s.y)]), Color(0.3, 0.28, 0.27))
	A.goblin(c, Vector2(s.x * 0.22, s.y * 0.68), 2.4, {"bomb": true, "grin": true, "crazy": true}, t)


# ---------- 엔딩 ----------

## 1. 후방 고블린 진지에서 탄도미사일을 쏘아 올린다.
func _ending_1(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.3, 0.32, 0.5), Color(0.9, 0.6, 0.45), Color(0.4, 0.36, 0.3), 0.78)
	for sx in [-1.0, 1.0]:
		A.line(c, Vector2(s.x * 0.4 + sx * 40, s.y * 0.78), Vector2(s.x * 0.4 + sx * 10, s.y * 0.3), 8.0, A.WOOD)
	var k := fmod(t * 0.4, 1.0)
	A.rocket(c, Vector2(s.x * (0.4 + k * 0.5), s.y * (0.4 - k * 0.5)), 0.9, -0.9, t)
	A.goblin(c, Vector2(s.x * 0.15, s.y * 0.98), 1.3, {"arms_up": true, "grin": true, "bounce": true}, t)
	A.goblin(c, Vector2(s.x * 0.75, s.y * 0.98), 1.3, {"arms_up": true, "grin": true, "bounce": true, "flip": true}, t)


## 2. 본진이 박살 나고 지휘관이 팽이처럼 날아간다.
func _ending_2(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.35, 0.3, 0.42), Color(0.7, 0.55, 0.5), Color(0.42, 0.4, 0.4), 0.8)
	A.tower(c, Vector2(s.x * 0.5, s.y * 0.8), 160, 120)
	A.boom(c, Vector2(s.x * 0.5, s.y * 0.45), s.y * 0.35, t)
	c.draw_set_transform(Vector2(s.x * 0.75, s.y * 0.2), t * 6.0, Vector2.ONE)
	A.human(c, Vector2(0, 40), 1.1, true, {"scared": true, "arms_up": true}, t)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	A.speed_lines(c, Vector2(s.x * 0.68, s.y * 0.3), Vector2(0.7, -0.7), 4, 50)


## 3. 그을린 부족장이 고블린들과 함께 기뻐한다.
func _ending_3(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.98, 0.72, 0.4), Color(1.0, 0.9, 0.6), Color(0.5, 0.45, 0.36), 0.8)
	A.chief(c, Vector2(s.x * 0.5, s.y * 0.95), 2.0, {"arms_up": true, "grin": true, "soot": true, "bounce": true}, t)
	var xs := [0.12, 0.3, 0.7, 0.88]
	for i in 4:
		var x: float = xs[i]
		A.goblin(c, Vector2(s.x * x, s.y * 1.0), 1.3, {"arms_up": true, "grin": true, "bounce": true, "soot": i % 2 == 0, "flip": x > 0.5}, t + i)
	for i in 5:
		A.boom(c, Vector2(s.x * (0.1 + i * 0.2), s.y * 0.15), 14.0, t * 2.0 + i, 7)


# ---------- 월드 시작 (월드마다 배경과 새 무기가 다르다) ----------

## 1. 이 월드의 인간 지휘관이 우리 속 부족장을 내세워 으름장.
func _world_1(c: CanvasItem, s: Vector2, t: float) -> void:
	match world:
		0:
			A.backdrop(c, s, Color(0.55, 0.65, 0.8), Color(0.85, 0.85, 0.75), Color(0.5, 0.56, 0.38), 0.7)
			for i in 3:
				A.hut(c, Vector2(s.x * (0.62 + i * 0.13), s.y * 0.7), 60, 44)
				A.flag(c, Vector2(s.x * (0.62 + i * 0.13), s.y * 0.7 - 70), 40, t)
		1:
			# 비 내리는 광산 도시: 굴뚝 연기와 빗줄기
			A.backdrop(c, s, Color(0.35, 0.37, 0.4), Color(0.55, 0.55, 0.55), Color(0.32, 0.3, 0.28), 0.7)
			for i in 3:
				var bx := s.x * (0.65 + i * 0.12)
				A.rect(c, Vector2(bx, s.y * 0.7 - 120 - i * 20), Vector2(26, 120 + i * 20), Color(0.4, 0.35, 0.33))
				A.smoke(c, Vector2(bx + 13, s.y * 0.7 - 140 - i * 20 - fmod(t * 15.0, 20.0)), 16.0, 0.35)
			_rain(c, s, t)
		2:
			# 밤의 철벽 관문
			A.backdrop(c, s, Color(0.05, 0.06, 0.15), Color(0.15, 0.17, 0.3), Color(0.14, 0.15, 0.19), 0.7)
			A.tower(c, Vector2(s.x * 0.68, s.y * 0.7), 80, 170, true)
			A.tower(c, Vector2(s.x * 0.9, s.y * 0.7), 80, 170, true)
		3:
			# 대공 요새: 높은 하늘 아래 발리스타
			A.backdrop(c, s, Color(0.5, 0.62, 0.8), Color(0.82, 0.85, 0.85), Color(0.45, 0.45, 0.42), 0.7)
			A.ballista(c, Vector2(s.x * 0.7, s.y * 0.7), 1.1)
			A.ballista(c, Vector2(s.x * 0.9, s.y * 0.7), 1.1)
		_:
			A.backdrop(c, s, Color(0.4, 0.3, 0.45), Color(0.75, 0.55, 0.5), Color(0.4, 0.38, 0.38), 0.7)
			A.tower(c, Vector2(s.x * 0.7, s.y * 0.7), 110, 220)
			A.tower(c, Vector2(s.x * 0.92, s.y * 0.7), 70, 160)
			A.ballista(c, Vector2(s.x * 0.55, s.y * 0.7), 0.9)
	A.flag(c, Vector2(s.x * 0.52, s.y * 0.93), 120, t)
	A.human(c, Vector2(s.x * 0.42, s.y * 0.96), 1.9, true, {"point": true, "flip": true}, t)
	A.chief(c, Vector2(s.x * 0.15, s.y * 0.93), 1.0, {"sad": true}, t)
	A.cage(c, Vector2(s.x * 0.06, s.y * 0.93 - 120), Vector2(120, 120))


## 빗줄기 (비 내리는 광산 도시).
func _rain(c: CanvasItem, s: Vector2, t: float) -> void:
	for k in 40:
		var x := fmod(k * 97.0 + t * 40.0, s.x)
		var y := fmod(k * 53.0 + t * 600.0, s.y)
		A.line(c, Vector2(x, y), Vector2(x - 6, y + 26), 2.0, Color(0.8, 0.85, 0.95, 0.5))


## 2. 고블린들이 이 월드의 새 무기에 불을 붙이며 웃는다.
## 1월드 화염탄, 2월드 기름병(비), 3월드 조명탄(밤), 4월드 글라이더 폭격(동료가 폭탄을 안고 글라이더를 멘다), 5월드 고폭탄.
func _world_2(c: CanvasItem, s: Vector2, t: float) -> void:
	if world == 3:
		_rocket_intro(c, s, t)
		return
	match world:
		1:
			A.backdrop(c, s, Color(0.35, 0.37, 0.4), Color(0.58, 0.58, 0.58), Color(0.36, 0.32, 0.28), 0.8)
		2:
			A.backdrop(c, s, Color(0.1, 0.1, 0.2), Color(0.3, 0.25, 0.35), Color(0.3, 0.26, 0.24), 0.8)
		_:
			A.backdrop(c, s, Color(0.98, 0.62, 0.3), Color(1.0, 0.85, 0.5), Color(0.55, 0.42, 0.3), 0.8)
	var kinds := [0, 2, 3, 3, 1]
	for i in 3:
		var pose := {"grin": true, "bounce": true, "bomb": true, "bomb_kind": kinds[world % kinds.size()]}
		A.goblin(c, Vector2(s.x * (0.18 + i * 0.32), s.y * 1.02), 2.0, pose, t + i)
	if world == 1:
		_rain(c, s, t)
	if world == 2:
		# 조명탄: 하늘에 솟은 밝은 불꽃
		A.boom(c, Vector2(s.x * 0.5, s.y * 0.2), 30.0, t, 9)


## 4월드 2칸: 그을린 동료 고블린이 엉성한 삼각 글라이더를 메고 자기 몸통만 한 폭탄을 끌어안고 자랑한다. 미친 고블린은 눈이 휘둥그레.
func _rocket_intro(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.5, 0.62, 0.8), Color(0.85, 0.85, 0.8), Color(0.45, 0.42, 0.36), 0.8)
	_glider(c, Vector2(s.x * 0.36, s.y * 0.98), 1.6, t, true)
	A.goblin(c, Vector2(s.x * 0.82, s.y * 1.0), 1.7, {"grin": true, "crazy": true, "flip": true}, t + 1.0)
	A.speed_lines(c, Vector2(s.x * 0.7, s.y * 0.55), Vector2(-1, -0.3), 3, 30)


## 글라이더를 멘 고블린 (발 위치 p). bomb: 폭탄을 끌어안았는지.
func _glider(c: CanvasItem, p: Vector2, sc: float, t: float, bomb: bool) -> void:
	var top := p + Vector2(0, -150) * sc
	A.shape(c, PackedVector2Array([top + Vector2(-110, 28) * sc, top + Vector2(0, -22) * sc, top + Vector2(110, 28) * sc, top + Vector2(0, 12) * sc]), Color(0.86, 0.3, 0.18))
	A.rect(c, top + Vector2(30, 0) * sc, Vector2(26, 14) * sc, Color(0.9, 0.82, 0.62), 2.0)
	A.line(c, top + Vector2(0, 10) * sc, p + Vector2(0, -60) * sc, 3.0 * sc, A.WOOD)
	A.line(c, p + Vector2(-30, -62) * sc, p + Vector2(30, -62) * sc, 4.0 * sc, A.WOOD)
	A.goblin(c, p, sc, {"arms_up": true, "grin": true, "soot": true, "bounce": true}, t)
	if bomb:
		A.bomb(c, p + Vector2(4, -28) * sc, 2.4 * sc, true, t, 1)


## 4월드 3칸: 동료가 조명탄을 건넨다. 조명탄 불빛 위에서 글라이더 고블린이 폭탄을 안고 뛰어내리는 모습이 말풍선 그림으로 떠 있다.
func _world_3(c: CanvasItem, s: Vector2, t: float) -> void:
	A.backdrop(c, s, Color(0.98, 0.62, 0.3), Color(1.0, 0.85, 0.5), Color(0.55, 0.42, 0.3), 0.8)
	# 생각 그림: 조명탄 불빛 → 글라이더 고블린이 그 위에서 폭탄을 안고 뛰어내림 → 쾅
	var bubble := Vector2(s.x * 0.5, s.y * 0.3)
	A.ellipse(c, bubble, Vector2(s.x * 0.36, s.y * 0.22), Color(1, 1, 1, 0.92))
	for k in 3:
		A.ellipse(c, Vector2(s.x * (0.62 + k * 0.06), s.y * (0.55 + k * 0.07)), Vector2(10 - k * 3, 8 - k * 2), Color(1, 1, 1, 0.92), 2.0)
	var flare := bubble + Vector2(s.x * 0.2, -s.y * 0.04)
	c.draw_circle(flare, 16.0 * (1.0 + 0.2 * sin(t * 18.0)), Color(1.0, 0.82, 0.15))
	c.draw_circle(flare, 8.0, Color(1.0, 1.0, 0.85))
	A.boom(c, flare + Vector2(0, s.y * 0.1), 18.0, t, 9)
	var k2 := fmod(t * 0.5, 1.0)
	_glider(c, bubble + Vector2(-s.x * 0.22 + k2 * s.x * 0.28, s.y * 0.12), 0.35, t, true)
	# 동료가 조명탄을 건네고, 미친 고블린이 받는다
	A.goblin(c, Vector2(s.x * 0.3, s.y * 1.0), 1.8, {"bomb": true, "bomb_kind": 3, "grin": true, "soot": true}, t)
	A.goblin(c, Vector2(s.x * 0.72, s.y * 1.0), 1.8, {"arms_up": true, "grin": true, "crazy": true, "flip": true, "bounce": true}, t + 0.5)
