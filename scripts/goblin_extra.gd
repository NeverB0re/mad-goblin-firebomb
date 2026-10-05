class_name GoblinExtra
extends Node3D
## 판정과 무관한 배경 고블린 (충돌 없음).
## - WAVE: 화약통·폭발통 곁에서 "여기야, 여기!" 하고 두 팔을 휘저으며 통을 가리킨다 (자기가 휘말릴 건 신경 안 쓴다).
## - FIGHT: 인간 병사(장식)와 몽둥이로 치고받는다 (1월드).
## - THROW: 인간 건물에 돌멩이를 던지는 시늉을 한다 (1월드).
## 근처에서 폭발이 나면 (같이 싸우던 병사도) 과장되게 날아간다. 웃음소리는 나중에 붙인다.

enum Mode { WAVE, FIGHT, THROW }

var mode: int = Mode.WAVE
## 가리킬 곳 (WAVE)
var point_at := Vector3.INF
var _body: Node3D
var _foe: Node3D
var _club: Node3D
var _t := 0.0
var _flying := false
var _vel := Vector3.ZERO
var _spin := Vector3.ZERO
var _foe_vel := Vector3.ZERO
var _landed := false


func setup(p_mode: int, p_point_at := Vector3.INF) -> GoblinExtra:
	mode = p_mode
	point_at = p_point_at
	add_to_group("goblin_extras")
	_body = Models.goblin()
	add_child(_body)
	if mode == Mode.FIGHT:
		var arm: Node3D = _body.get_node("ArmR")
		_club = Models.box(arm, Vector3(0.12, 0.7, 0.12), Vector3(0, -0.7, 0), Models.mat(Color(0.4, 0.27, 0.15)))
		_foe = Models.human(Models.HUMAN_STEEL, Models.Hat.HELMET)
		_foe.position = Vector3(0, 0, -1.3)
		_foe.rotation.y = PI
		add_child(_foe)
	_t = position.x * 1.3 + position.z * 0.7
	return self


## 근처 폭발: 반경 안이면 과장되게 날아간다 (판정과 무관한 연출).
func on_blast(pos: Vector3, radius: float) -> void:
	if _flying or global_position.distance_to(pos) > radius * 1.3 + 1.0:
		return
	_flying = true
	var away := global_position - pos
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0.3, 0, 1)
	away = away.normalized()
	_vel = away * 7.0 + Vector3.UP * 11.0
	_spin = Vector3(9.0, 14.0, 5.0)
	if _foe:
		# 같이 싸우던 병사는 반대쪽으로
		var foe_pos := _foe.global_position
		remove_child(_foe)
		get_parent().add_child(_foe)
		_foe.global_position = foe_pos
		_foe_vel = (away * -0.3 + Vector3(away.z, 0, -away.x)).normalized() * 6.0 + Vector3.UP * 9.0


func _process(delta: float) -> void:
	_t += delta
	if _flying:
		_fly(delta)
		return
	var arm_l: Node3D = _body.get_node("ArmL")
	var arm_r: Node3D = _body.get_node("ArmR")
	match mode:
		Mode.WAVE:
			# 플레이어를 바라보며 펄쩍펄쩍 뛰고 두 팔을 번갈아 휘젓다가, 가끔 한 팔로 통을 콕 가리킨다
			_body.position.y = absf(sin(_t * 7.0)) * 0.35
			var stage := get_parent()
			if stage is Stage and stage.player:
				var to_player := to_local(stage.player.global_position)
				_body.rotation.y = atan2(-to_player.x, -to_player.z)
			if fmod(_t, 3.0) < 1.2 and point_at != Vector3.INF:
				var dir := _body.to_local(point_at) - arm_r.position
				arm_r.basis = Basis(Quaternion(Vector3.DOWN, dir.normalized()))
				arm_l.rotation = Vector3(0, 0, -2.5 + sin(_t * 18.0) * 0.4)
			else:
				arm_l.rotation = Vector3(0, 0, -2.4 + sin(_t * 12.0) * 0.6)
				arm_r.rotation = Vector3(0, 0, 2.4 + sin(_t * 12.0 + 1.5) * 0.6)
		Mode.FIGHT:
			# 몽둥이를 휘두르고, 병사는 창을 찌르며 들썩
			var swing := sin(_t * 6.0)
			arm_r.rotation = Vector3(-1.2 - swing * 1.0, 0, 0.3)
			arm_l.rotation = Vector3(0, 0, -0.8)
			_body.position = Vector3(0, absf(sin(_t * 6.0)) * 0.15, -maxf(swing, 0.0) * 0.25)
			if _foe:
				_foe.position = Vector3(0, absf(sin(_t * 6.0 + 1.5)) * 0.1, -1.3 + maxf(swing, 0.0) * 0.2)
				_foe.rotation = Vector3(-maxf(swing, 0.0) * 0.3, PI, 0)
		Mode.THROW:
			# 팔을 크게 돌려 돌멩이를 던지는 시늉
			arm_r.rotation = Vector3(-fmod(_t * 5.0, TAU), 0, 0.2)
			arm_l.rotation = Vector3(0, 0, -0.6)
			_body.position.y = absf(sin(_t * 5.0)) * 0.1


func _fly(delta: float) -> void:
	if not _landed:
		_vel.y -= 9.8 * delta
		position += _vel * delta
		_body.rotation += _spin * delta
		if position.y <= 0.0 and _vel.y < 0.0:
			position.y = 0.0
			_landed = true
			_body.rotation = Vector3(-PI * 0.5, _body.rotation.y, 0)
	if _foe and _foe_vel != Vector3.ZERO:
		_foe_vel.y -= 9.8 * delta
		_foe.position += _foe_vel * delta
		_foe.rotation += Vector3(7.0, 3.0, 9.0) * delta
		if _foe.position.y <= 0.0 and _foe_vel.y < 0.0:
			_foe.position.y = 0.0
			_foe_vel = Vector3.ZERO
			_foe.rotation = Vector3(PI * 0.5, _foe.rotation.y, 0)
