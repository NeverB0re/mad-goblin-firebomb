extends Node3D
## 진입점. 입력 등록, 환경, HUD, 스테이지 전환과 R 재시작.

var stage_index := 0
var stage: Stage
var hud: Hud


func _ready() -> void:
	register_input()
	_setup_environment()
	hud = Hud.new()
	add_child(hud)
	load_stage(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func register_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"restart": [KEY_R], "next_stage": [KEY_ENTER, KEY_KP_ENTER],
		"ammo_1": [KEY_1], "ammo_2": [KEY_2],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("zoom"):
		InputMap.add_action("zoom")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("zoom", mb)


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.62, 0.72, 0.86)
	sky_mat.sky_horizon_color = Color(0.95, 0.95, 0.95)
	sky_mat.ground_horizon_color = Color(0.95, 0.95, 0.95)
	sky_mat.ground_bottom_color = Color(0.85, 0.85, 0.85)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)


func load_stage(index: int) -> void:
	stage_index = posmod(index, StageDefs.COUNT)
	if stage:
		remove_child(stage)
		stage.queue_free()
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	StageDefs.build(stage_index, stage)
	stage.player.camera.make_current()
	hud.bind(stage)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		load_stage(stage_index)
	elif event.is_action_pressed("next_stage") and stage and stage.state == Stage.State.CLEARED:
		load_stage(stage_index + 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_F1 and event.physical_keycode <= KEY_F6:
			load_stage(event.physical_keycode - KEY_F1)
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
