extends Node3D
## 진입점. 입력 등록, 환경(낮/밤), HUD, 오프닝, 스테이지 전환, 승리 연출과 실패 그림, R 재시작.

## 테스트에서 오프닝 컷만화를 건너뛸 때 false로 둔다
static var show_opening := true

var stage_index := 0
var stage: Stage
var hud: Hud
var result: ResultScreen
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fail_count := 0


func _ready() -> void:
	register_input()
	_setup_environment()
	hud = Hud.new()
	add_child(hud)
	if show_opening:
		var opening := Opening.new()
		add_child(opening)
		await opening.finished
	load_stage(0)
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
	stage_index = posmod(index, StageDefs.COUNT)
	if stage:
		remove_child(stage)
		stage.queue_free()
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	StageDefs.build(stage_index, stage)
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
	if action == "next" and stage_index == StageDefs.COUNT - 1:
		# 마지막 진지를 박살 내면 엔딩 컷만화 (그을린 부족장과 기뻐하는 고블린들)
		Engine.time_scale = 1.0
		var ending := Opening.new(Opening.Mode.ENDING)
		add_child(ending)
		await ending.finished
		load_stage(0)
	else:
		load_stage(stage_index + (1 if action == "next" else 0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if stage == null:
		return
	if event.is_action_pressed("restart"):
		load_stage(stage_index)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_F1 and event.physical_keycode <= KEY_F11:
			load_stage(event.physical_keycode - KEY_F1)
		elif event.physical_keycode == KEY_PAGEDOWN:
			load_stage(stage_index + 1)
		elif event.physical_keycode == KEY_PAGEUP:
			load_stage(stage_index - 1)
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
