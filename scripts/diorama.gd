class_name Diorama
extends RefCounted
## 만화 칸·실패 그림용 작은 3D 장면 도우미 (독립 World3D의 SubViewport 안에 만든다).


static func scene(vp: SubViewport, sky: Color, ground: Color, cam_pos: Vector3, look: Vector3, fov := 50.0, sun_rot := Vector3(-50, 30, 0)) -> Node3D:
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
	cam.look_at_from_position(cam_pos, look, Vector3.UP)
	cam.current = true
	return root


static func place(node: Node3D, parent: Node3D, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(node)
	return node


static func arm(n: Node3D, side: String, z_angle: float, x_angle := 0.0) -> void:
	var a: Node3D = n.get_node_or_null(side)
	if a:
		a.rotation = Vector3(x_angle, 0, z_angle)
