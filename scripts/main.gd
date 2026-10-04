extends Node3D
## 진입점. 입력 등록, 환경(낮/밤), HUD, 타이틀·메뉴, 오프닝, 스테이지 전환, 승리 연출과 실패 그림, 진행 저장.
## 흐름: 타이틀 (뒤에 첫 진지가 멈춘 채 보임) → (처음이면 오프닝) → 본편 스테이지 → 승리 → 다음 진지 … → 엔딩 → 타이틀.
## Esc = 잠깐 메뉴. R = 바로 다시 시작.

## 테스트에서 오프닝 컷만화를 건너뛸 때 false로 둔다
static var show_opening := true
## 테스트: 타이틀 없이 바로 시험 스테이지(StageDefs E1~E11)로 시작한다
static var test_mode := false

var stage_index := 0
var stage: Stage
var hud: Hud
var result: ResultScreen
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fail_count := 0
var menus: Menus


func _ready() -> void:
	register_input()
	_setup_environment()
	hud = Hud.new()
	add_child(hud)
	menus = Menus.new()
	add_child(menus)
	menus.start_requested.connect(_on_start)
	menus.stage_chosen.connect(_on_stage_chosen)
	menus.resume_requested.connect(_resume)
	menus.restart_requested.connect(func():
		_resume()
		load_stage(stage_index))
	menus.title_requested.connect(show_title)
	menus.opening_requested.connect(func(): _play_opening(false))
	if test_mode:
		load_stage(0)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	SaveData.load_all()
	SaveData.apply_settings()
	show_title()


func _count() -> int:
	return StageDefs.COUNT if test_mode else Campaign.COUNT


# ---------- 타이틀·메뉴 ----------

## 타이틀: 마지막으로 열린 진지를 배경으로 멈춰 두고 카메라만 천천히 돈다.
func show_title() -> void:
	get_tree().paused = false
	load_stage(mini(SaveData.unlocked, Campaign.COUNT) - 1)
	hud.set_gameplay_visible(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var orbit := OrbitCam.new()
	orbit.center = stage.commander.global_position if stage.commander else Vector3(0, 0, -50)
	stage.add_child(orbit)
	orbit.make_current()
	menus.show_title()


func _on_start() -> void:
	if not SaveData.opening_seen:
		await _play_opening(true)
	_on_stage_chosen(_first_unfinished())


func _first_unfinished() -> int:
	for i in Campaign.COUNT:
		if i < SaveData.unlocked and not SaveData.is_cleared(i):
			return i
	return mini(SaveData.unlocked, Campaign.COUNT) - 1


func _play_opening(first: bool) -> void:
	menus.hide_all()
	get_tree().paused = false
	var opening := Opening.new()
	add_child(opening)
	await opening.finished
	SaveData.opening_seen = true
	SaveData.save_all()
	if not first:
		show_title()


func _on_stage_chosen(index: int) -> void:
	menus.hide_all()
	get_tree().paused = false
	load_stage(index)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause() -> void:
	if result or get_tree().paused:
		return
	if stage and stage.player and stage.player.is_throwing():
		stage.player.cancel_throw()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_pause()


func _resume() -> void:
	menus.hide_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func register_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"restart": [KEY_R], "next_stage": [KEY_ENTER, KEY_KP_ENTER],
		"ammo_1": [KEY_1], "ammo_2": [KEY_2], "ammo_3": [KEY_3], "ammo_4": [KEY_4],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _setup_environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 먼 곳은 옅은 대기색으로 살짝 흐리게 (게임플레이용 안개가 아니라 깊이감용)
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 70.0
	_env.fog_depth_end = 400.0
	_env.fog_density = 0.35
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 35, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 160.0
	add_child(_sun)
	_apply_time_of_day(false)


## 밤은 안개 대신 시야를 제한한다. 적의 횃불과 조명탄이 단서다.
func _apply_time_of_day(night: bool) -> void:
	if night:
		_sky_mat.sky_top_color = Color(0.02, 0.03, 0.07)
		_sky_mat.sky_horizon_color = Color(0.06, 0.07, 0.12)
		_sky_mat.ground_horizon_color = Color(0.04, 0.04, 0.06)
		_sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
		_env.ambient_light_energy = 0.12
		_env.fog_light_color = Color(0.03, 0.04, 0.07)
		_sun.light_color = Color(0.55, 0.65, 0.9)
		_sun.light_energy = 0.06
	else:
		_sky_mat.sky_top_color = Color(0.52, 0.66, 0.86)
		_sky_mat.sky_horizon_color = Color(0.86, 0.88, 0.9)
		_sky_mat.ground_horizon_color = Color(0.86, 0.88, 0.9)
		_sky_mat.ground_bottom_color = Color(0.6, 0.6, 0.55)
		_env.ambient_light_energy = 0.9
		_env.fog_light_color = Color(0.82, 0.86, 0.92)
		_sun.light_color = Color(1.0, 0.97, 0.9)
		_sun.light_energy = 1.1


func load_stage(index: int) -> void:
	Engine.time_scale = 1.0
	if result:
		result.close()
		result = null
	stage_index = posmod(index, _count())
	if stage:
		remove_child(stage)
		stage.queue_free()
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	if test_mode:
		StageDefs.build(stage_index, stage)
	else:
		Campaign.build(stage_index, stage)
	_apply_time_of_day(stage.night)
	stage.player.camera.make_current()
	stage.state_changed.connect(_on_stage_state)
	stage.target_down.connect(_on_target_down)
	hud.bind(stage)


func _on_target_down(target: Actor, cause: String, focus: Vector3) -> void:
	result = ResultScreen.new()
	add_child(result)
	result.proceed.connect(_on_result_proceed)
	var start_cam: Camera3D = hud.follow_cam.camera() if hud.follow_cam.visible else null
	hud.set_gameplay_visible(false)
	if not test_mode:
		SaveData.record_clear(stage_index, stage.total_ammo())
	result.play_victory(stage, target, cause, focus, start_cam)


func _on_stage_state(state: int, message: String) -> void:
	if state == Stage.State.FAILED:
		result = ResultScreen.new()
		add_child(result)
		result.proceed.connect(_on_result_proceed)
		hud.set_gameplay_visible(false)
		result.play_failure(message, _fail_count)
		_fail_count += 1


func _on_result_proceed(action: String) -> void:
	result = null
	if action == "next" and stage_index == _count() - 1:
		# 마지막 진지를 박살 내면 엔딩 컷만화 (그을린 부족장과 기뻐하는 고블린들) → 타이틀
		Engine.time_scale = 1.0
		var ending := Opening.new(Opening.Mode.ENDING)
		add_child(ending)
		await ending.finished
		if test_mode:
			load_stage(0)
		else:
			show_title()
			return
	else:
		load_stage(stage_index + (1 if action == "next" else 0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if stage == null or menus.screen != Menus.Screen.NONE:
		return
	if event.is_action_pressed("restart"):
		load_stage(stage_index)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if test_mode:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				_pause()
		elif OS.is_debug_build():
			# 개발용 바로가기: F1~F11 스테이지, PageUp/PageDown 이전·다음
			if event.physical_keycode >= KEY_F1 and event.physical_keycode <= KEY_F12:
				load_stage(event.physical_keycode - KEY_F1)
			elif event.physical_keycode == KEY_PAGEDOWN:
				load_stage(stage_index + 1)
			elif event.physical_keycode == KEY_PAGEUP:
				load_stage(stage_index - 1)
