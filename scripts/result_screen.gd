class_name ResultScreen
extends CanvasLayer
## 승리 연출과 실패 그림. 판정이 끝난 뒤에만 시간을 늦추므로 영점과 무관하다.
##
## 승리: 쓰러진 방식에 따라 다르게 찍고, 마지막에 화면을 멈추고 흰 플래시 + 기울어진 "박살!" + 버튼.
##  - 날아감 (직격·폭발): 과장되게 날아가는 모습을 옆에서 따라가며 잠시 감상 → 공중에서 확대샷
##  - 불탐: 날아가지 않고 불붙어 당황하는 모습을 정면에서
##  - 깔림·추락: 줌을 당겨 무너진 건물과 깔린 지휘관을 함께
##  - 다리 (전령 스테이지): 끊긴 다리 앞에서 허둥대는 전령을 정면에서
## 아무 입력이나 누르면 바로 넘어간다 (R은 다시 하기).
## 실패: 고블린 그림 한 장(1.2초) + 원인 한 줄 → 다시 하기.

signal proceed(action: String)

## 날아가는 모습을 감상하는 시간 (현실 시간)과 그동안의 배속
const FLY_WATCH := 1.5
const FLY_SLOW := 0.45
const BURN_WATCH := 1.6
const CRUSH_WATCH := 2.0

var _root: Control
var _vignette: TextureRect
var _flash: ColorRect
var _ready_for_input := false
var _victory := false
var _cam: Camera3D
## 카메라 이동 (현실 시간 기준): from → to 위치로 옮기며 _look_node(인물) 또는 _look_point를 바라본다
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _cam_move := 0.5
var _cam_t := 1.0
var _look_node: Node3D
var _look_point := Vector3.ZERO
var _last_ms := 0
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
	_last_ms = Time.get_ticks_msec()


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


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## 카메라를 지금 자리에서 to로 seconds(현실 시간) 동안 옮긴다. 0이면 바로 자른다.
func _move_cam(to: Vector3, seconds: float) -> void:
	_cam_from = _cam.global_position
	_cam_to = to
	_cam_move = maxf(seconds, 0.001)
	_cam_t = 0.0 if seconds > 0.0 else 1.0
	if seconds <= 0.0:
		_cam.global_position = to
		_aim_cam()


func _aim_cam() -> void:
	var p := _look_node.global_position + Vector3.UP * 1.1 if is_instance_valid(_look_node) else _look_point
	if _cam.global_position.distance_to(p) > 0.05:
		_cam.look_at(p, Vector3.UP)


## 승리 연출. target: 쓰러진 인물 (봉화대를 태운 경우 null). start_cam: 추적 화면이 비추던 시점.
func play_victory(stage: Stage, target: Actor, cause: String, focus: Vector3, start_cam: Camera3D) -> void:
	_victory = true
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 1500.0
	stage.add_child(_cam)
	if start_cam and start_cam.is_inside_tree() and start_cam.global_position.distance_to(focus) < 45.0:
		_cam.global_transform = start_cam.global_transform
	else:
		_cam.global_position = stage.player.global_position + Vector3.UP * 2.0
	_cam.make_current()
	if stage.night:
		# 밤에는 연출 카메라에 조명을 달아 쓰러지는 모습이 보이게 한다 (연출 전용)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.88, 0.7)
		lamp.light_energy = 3.0
		lamp.omni_range = 30.0
		lamp.omni_attenuation = 0.6
		lamp.position = Vector3(0, 1.5, 0)
		_cam.add_child(lamp)
		var fill := OmniLight3D.new()
		fill.light_color = Color(1.0, 0.7, 0.45)
		fill.light_energy = 2.0
		fill.omni_range = 14.0
		fill.position = focus + Vector3.UP * 4.0
		stage.add_child(fill)
	_look_point = focus
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
	_set_lowpass(true)
	var away := focus - stage.player.global_position
	away.y = 0.0
	away = away.normalized()
	var side := away.cross(Vector3.UP).normalized()
	if cause == "bridge":
		await _shot_stranded(stage, target, focus, away, side)
	elif cause == "fire":
		await _shot_burn(stage, target)
	elif cause == "crush" or cause == "fall":
		await _shot_crush(stage, target, away, side)
	else:
		await _shot_fly(stage, target, away)
	await _smash(stage)


## 날아감: 크게 띄워 옆에서 따라가며 감상 → 공중에서 확대샷.
func _shot_fly(stage: Stage, target: Actor, away: Vector3) -> void:
	var chest := target.chest()
	_look_node = target
	_move_cam(_side_view(stage, chest, away), 0.45)
	Engine.time_scale = FLY_SLOW
	target.launch(away, stage.throws + stage.stage_id.hash(), 1.9)
	Sfx.play(stage, "scream", chest, 4.0)
	await _wait_real(FLY_WATCH)
	# 공중 확대샷: 빙글빙글 날아가는 몸 한가운데를 조금 떨어져서 잡고 멈춘다
	var body := target.visual.global_transform * Vector3(0, 0.9, 0) if target.visual else target.chest()
	var to_cam := _cam.global_position - body
	to_cam.y = 0.0
	to_cam = to_cam.normalized()
	_look_node = null
	_look_point = body
	_move_cam(body + to_cam * 4.6 + Vector3.UP * 0.9, 0.0)


## 불탐: 날아가지 않고 불붙어 당황하는 모습을 정면에서.
func _shot_burn(stage: Stage, target: Actor) -> void:
	Engine.time_scale = 0.8
	target.burn_panic()
	Sfx.play(stage, "scream", target.chest(), 2.0)
	var fwd := target.global_transform.basis * Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized()
	_look_node = target
	var front := target.global_position + fwd * 4.8 + Vector3.UP * 1.5
	_move_cam(front + fwd * 3.0 + Vector3.UP * 1.0, 0.0)
	_move_cam(front, 0.6)
	await _wait_real(BURN_WATCH)


## 깔림·추락: 무너진 건물과 깔린 지휘관을 함께 보이게 줌을 당긴다 (잔해가 가라앉는 동안).
func _shot_crush(stage: Stage, target: Actor, away: Vector3, side: Vector3) -> void:
	Engine.time_scale = 1.0
	var p := target.global_position
	# 옆쪽(트인 쪽)에서 낮게: 잔해 더미와 그 밖으로 삐져나온 다리가 함께 보인다
	var near := _find_view(stage, p + Vector3.UP * 0.4, [side - away * 0.5, -side - away * 0.5, -away, side, -side], 6.5, 2.8)
	# 잔해 밖으로 다리가 삐져나오게 카메라 쪽으로 눕힌다
	var to_cam := near - p
	to_cam.y = 0.0
	target.squash(to_cam.normalized())
	_look_node = null
	_look_point = (target.visual.global_position if target.visual else p) + Vector3.UP * 0.9
	_move_cam(p + (near - p) * 1.8 + Vector3.UP * 3.0, 0.0)
	_move_cam(near, CRUSH_WATCH * 0.8)
	Sfx.play(stage, "scream", target.chest(), -2.0)
	await _wait_real(CRUSH_WATCH)


## 다리: 끊긴 다리 앞에서 오도 가도 못하고 허둥대는 전령.
func _shot_stranded(stage: Stage, target: Actor, focus: Vector3, away: Vector3, side: Vector3) -> void:
	Engine.time_scale = 1.0
	_look_node = target
	var near := _find_view(stage, focus, [-away + side * 0.6, -away - side * 0.6, side, -side], 6.0, 2.0)
	_move_cam(focus + (near - focus) * 1.8 + Vector3.UP * 2.0, 0.0)
	_move_cam(near, 1.0)
	Sfx.play(stage, "scream", focus, 0.0)
	await _wait_real(1.8)


## 지형(바위, 절벽)에 가리지 않고 target을 볼 수 있는 자리. 블록(잔해)은 가려도 된다.
func _find_view(stage: Stage, target: Vector3, dirs: Array, dist: float, height: float) -> Vector3:
	var space := stage.get_world_3d().direct_space_state
	for dir in dirs:
		var flat: Vector3 = dir
		flat.y = 0.0
		var cand := target + flat.normalized() * dist + Vector3.UP * height
		var q := PhysicsRayQueryParameters3D.create(cand, target, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider is Block or hit.collider.is_in_group("ground"):
			return cand
	return target + (dirs[0] as Vector3).normalized() * dist + Vector3.UP * (height + 4.0)


## 마무리: 멈춤 + 흰 플래시 + 박살! + 남은 탄약과 버튼.
func _smash(stage: Stage) -> void:
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
	_place(smash, Vector4(0.5, 0.3, 0.5, 0.3), Vector4(-500, -130, 500, 130))
	smash.pivot_offset = Vector2(500, 130)
	smash.rotation = -0.18
	smash.scale = Vector2.ONE * 2.6
	_tween().tween_property(smash, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait_real(0.45)
	var left := _label("%s  %d" % [Texts.t("ammo_left"), stage.total_ammo()], 26, Color(1, 1, 1))
	_place(left, Vector4(0, 0.62, 1, 0.7))
	_buttons([Texts.t("next"), Texts.t("retry") + " (R)"])
	_ready_for_input = true


## 날아가는 모습을 옆에서 잡는 자리. 가려지지 않는 쪽을 고른다.
func _side_view(stage: Stage, target: Vector3, away: Vector3) -> Vector3:
	var side := away.cross(Vector3.UP).normalized()
	var space := stage.get_world_3d().direct_space_state
	for candidate in [target + side * 11.0 - away * 3.0 + Vector3.UP * 4.0, target - side * 11.0 - away * 3.0 + Vector3.UP * 4.0,
			target - away * 10.0 + Vector3.UP * 8.0, target + Vector3.UP * 14.0 - away * 4.0]:
		var q := PhysicsRayQueryParameters3D.create(candidate, target + Vector3.UP * 1.5, 1)
		if space.intersect_ray(q).is_empty():
			return candidate
	return target - away * 10.0 + Vector3.UP * 8.0


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
func play_failure(cause_text: String, picture: int, world := 0) -> void:
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
	FailurePictures.build(vp, picture, world)
	frame.pivot_offset = Vector2(320, 225)
	frame.scale = Vector2.ONE * 0.9
	_tween().tween_property(frame, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var line := _label(cause_text, 44, Color(1.0, 0.9, 0.75))
	line.anchor_left = 0.0
	line.anchor_right = 1.0
	line.anchor_top = 0.64
	line.anchor_bottom = 0.72
	await _wait_real(1.2)
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


func _process(_delta: float) -> void:
	# 연출 카메라는 시간 배율(슬로모션·멈춤)과 무관하게 현실 시간으로 움직인다
	var now := Time.get_ticks_msec()
	var real_dt := (now - _last_ms) / 1000.0
	_last_ms = now
	if _cam == null or not is_instance_valid(_cam) or not _cam.is_inside_tree():
		return
	if _cam_t < 1.0:
		_cam_t = minf(1.0, _cam_t + real_dt / _cam_move)
		var k := 1.0 - pow(1.0 - _cam_t, 3.0)
		_cam.global_position = _cam_from.lerp(_cam_to, k)
	if Engine.time_scale > 0.0:
		_aim_cam()


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
