class_name ResultScreen
extends CanvasLayer
## 승리 연출과 실패 그림 (확장 기획서 7장). 판정이 끝난 뒤에만 시간을 늦추므로 영점과 무관하다.
##
## 승리 (약 3초): 추적 카메라 시점이 전체 화면으로 → 0.25배속, 소리 먹먹, 가장자리 어둡게 →
## 지휘관이 비명을 지르며 팽이처럼 날아감 → 0.9초 뒤 멈춤 + 흰 플래시 + 기울어진 "박살!" →
## 남은 탄약과 버튼. 아무 입력이나 누르면 바로 넘어간다 (R은 다시 하기).
## 실패: 고블린 그림 한 장(1.2초) + 원인 한 줄 → 다시 하기. 아무 입력이나 누르면 넘어간다.

signal proceed(action: String)

const SLOW := 0.25
const FLIGHT_REAL := 0.9

var _root: Control
var _vignette: TextureRect
var _flash: ColorRect
var _ready_for_input := false
var _cam: Camera3D
var _cam_from: Transform3D
var _cam_to: Transform3D
var _cam_t := 0.0
var _victory := false
static var _lowpass_idx := -1


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "sans-serif"])
	font.font_weight = 800
	theme.default_font = font
	_root.theme = theme
	add_child(_root)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


static func _set_lowpass(on: bool) -> void:
	if _lowpass_idx < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 700.0
		AudioServer.add_bus_effect(0, lp)
		_lowpass_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lowpass_idx, on)


## 승리 연출. start_cam: 추적 화면이 비추던 시점 (없으면 null).
func play_victory(stage: Stage, commander: Commander, start_cam: Camera3D) -> void:
	_victory = true
	# 1. 연출 카메라: 추적 카메라 시점에서 지휘관을 크게 잡는 자리로 옮겨 간다
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 1500.0
	stage.add_child(_cam)
	var target := commander.chest()
	var away := commander.global_position - stage.player.global_position
	away.y = 0
	away = away.normalized()
	var frame_pos := stage.cine_cam_pos
	if frame_pos == Vector3.INF:
		frame_pos = _side_view(stage, target, away)
	_cam_to = Transform3D(Basis(), frame_pos).looking_at(target + Vector3.UP * 3.0, Vector3.UP)
	if start_cam and start_cam.is_inside_tree() and start_cam.global_position.distance_to(target) < 45.0:
		_cam_from = start_cam.global_transform
	else:
		_cam_from = _cam_to
	_cam.global_transform = _cam_from
	_cam.make_current()
	# 2. 느려지고, 먹먹해지고, 가장자리가 어두워진다
	Engine.time_scale = SLOW
	_set_lowpass(true)
	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)])
	g.offsets = PackedFloat32Array([0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	_vignette.texture = gt
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)
	_tween().tween_property(_vignette, "modulate:a", 1.0, 0.3)
	# 3. 지휘관이 비명을 길게 지르며 날아간다 (비행 방식은 다섯 가지를 돌려 쓴다)
	# 0.25배속에서 0.9초(게임 시간 약 0.23초) 안에 확실히 날아가 보이도록 과장된 속도로 띄운다
	commander.launch(away, stage.throws + stage.stage_id.hash(), 2.6)
	Sfx.play(stage, "scream", target, 4.0)
	# 4. 0.9초 뒤 멈춤 + 흰 플래시 + 박살!
	await get_tree().create_timer(FLIGHT_REAL, true, false, true).timeout
	Engine.time_scale = 0.0
	_set_lowpass(false)
	Sfx.play(stage, "win", _cam.global_position, 0.0)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.95)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	var smash := _label(Texts.t("win"), 150, Color(1.0, 0.82, 0.15))
	_place(smash, Vector4(0.5, 0.42, 0.5, 0.42), Vector4(-500, -130, 500, 130))
	smash.pivot_offset = Vector2(500, 130)
	smash.rotation = -0.18
	smash.scale = Vector2.ONE * 2.6
	_tween().tween_property(smash, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 5. 남은 탄약과 버튼
	await get_tree().create_timer(0.45, true, false, true).timeout
	var left := _label("%s  %d" % [Texts.t("ammo_left"), stage.total_ammo()], 26, Color(1, 1, 1))
	_place(left, Vector4(0, 0.62, 1, 0.7))
	_buttons([Texts.t("next"), Texts.t("retry") + " (R)"])
	_ready_for_input = true


## 지휘관이 날아가는 모습을 옆에서 잡는 자리. 가려지지 않는 쪽을 고른다.
func _side_view(stage: Stage, target: Vector3, away: Vector3) -> Vector3:
	var side := away.cross(Vector3.UP).normalized()
	var space := stage.get_world_3d().direct_space_state
	for candidate in [target + side * 9.0 - away * 2.0 + Vector3.UP * 3.0, target - side * 9.0 - away * 2.0 + Vector3.UP * 3.0,
			target - away * 8.0 + Vector3.UP * 7.0, target + Vector3.UP * 12.0 - away * 3.0]:
		var q := PhysicsRayQueryParameters3D.create(candidate, target + Vector3.UP * 1.5, 1)
		if space.intersect_ray(q).is_empty():
			return candidate
	return target - away * 8.0 + Vector3.UP * 7.0


## 앵커(왼, 위, 오른, 아래)와 오프셋으로 배치한다.
static func _place(c: Control, anchors: Vector4, offsets := Vector4.ZERO) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


## 실패: 고블린 그림 한 장과 원인 한 줄.
func play_failure(cause_text: String, picture: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var frame := ColorRect.new()
	frame.color = Color(0.06, 0.06, 0.06)
	frame.anchor_left = 0.3
	frame.anchor_right = 0.7
	frame.anchor_top = 0.12
	frame.anchor_bottom = 0.62
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 6
	container.offset_top = 6
	container.offset_right = -6
	container.offset_bottom = -6
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 450)
	vp.own_world_3d = true
	container.add_child(vp)
	FailurePictures.build(vp, picture)
	frame.pivot_offset = Vector2(320, 225)
	frame.scale = Vector2.ONE * 0.9
	_tween().tween_property(frame, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var line := _label(cause_text, 44, Color(1.0, 0.9, 0.75))
	line.anchor_left = 0.0
	line.anchor_right = 1.0
	line.anchor_top = 0.64
	line.anchor_bottom = 0.72
	await get_tree().create_timer(1.2, true, false, true).timeout
	_buttons([Texts.t("retry")])
	_ready_for_input = true


func _buttons(texts: Array) -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.76
	box.anchor_bottom = 0.84
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	for t in texts:
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.35, 0.5, 0.2)
		sb.border_color = Color(0.1, 0.08, 0.05)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", sb)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = t
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
		panel.add_child(l)
		box.add_child(panel)
	var hint := _label(Texts.t("any_key"), 16, Color(1, 1, 1, 0.7))
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.85
	hint.anchor_bottom = 0.9


func _tween() -> Tween:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	return tw


func _process(delta: float) -> void:
	if _cam and _cam_t < 1.0:
		# 시간 배율과 무관하게 0.5초 동안 연출 카메라 자리로
		_cam_t = minf(1.0, _cam_t + delta / maxf(Engine.time_scale, 0.001) / 0.5) if Engine.time_scale > 0.0 else 1.0
		var k := 1.0 - pow(1.0 - _cam_t, 3.0)
		_cam.global_transform = _cam_from.interpolate_with(_cam_to, k)


func _input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_ready_for_input = false
	var action := "next" if _victory else "retry"
	if event is InputEventKey and event.physical_keycode == KEY_R:
		action = "retry"
	close()
	proceed.emit(action)


func close() -> void:
	Engine.time_scale = 1.0
	_set_lowpass(false)
	queue_free()
