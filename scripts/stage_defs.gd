class_name StageDefs
extends RefCounted
## 테스트 스테이지 T1~T6. 플레이어는 원점 근처 투척 구역에서 -Z 방향을 본다.

const BASIC := preload("res://ammo/basic.tres")
const HEAVY := preload("res://ammo/heavy.tres")
const M := Block.Mat

const COUNT := 6
const NAMES := ["T1", "T2", "T3", "T4", "T5", "T6"]


static func build(index: int, s: Stage) -> void:
	match index:
		0: _t1(s)
		1: _t2(s)
		2: _t3(s)
		3: _t4(s)
		4: _t5(s)
		5: _t6(s)
	s.finish_build()


static func _zone(s: Stage) -> void:
	s.set_zone(Vector3(0, 0, 0), Vector2(3.0, 3.0))


## T1. 얇은 목재 창고 60m, 기본 5발. 충격만으로 무너진다.
static func _t1(s: Stage) -> void:
	s.begin("T1", "T1 · 얇은 목재 창고", "창고를 무너뜨려 빨간 코어를 땅에 떨어뜨려라", Stage.Goal.CORE)
	_zone(s)
	s.add_ammo(BASIC, 5)
	build_shed(s.add_structure(), Vector3(0, 0, -60))


static func build_shed(st: Structure, c: Vector3) -> void:
	var hx := 2.0
	var hz := 1.5
	var post_h := 2.6
	# 모서리 기둥
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_THIN, c + Vector3(sx * (hx - 0.125), post_h * 0.5, sz * (hz - 0.125)), Vector3(0.25, post_h, 0.25))
	# 앞뒤 도리
	for sz in [-1, 1]:
		st.add_block(M.WOOD_THIN, c + Vector3(0, post_h + 0.125, sz * (hz - 0.125)), Vector3(hx * 2.0, 0.25, 0.25))
	# 지붕 판자 (앞뒤 도리에 걸침)
	var plank_w := 0.5
	var n := int(hx * 2.0 / plank_w)
	for i in n:
		var x := -hx + plank_w * (i + 0.5)
		st.add_block(M.WOOD_THIN, c + Vector3(x, post_h + 0.25 + 0.05, 0), Vector3(plank_w, 0.1, hz * 2.0))
	# 코어
	st.add_block(M.CORE, c + Vector3(0, post_h + 0.35 + 0.4, 0), Vector3(0.8, 0.8, 0.8))
	# 벽 판자 (하중 없음)
	var wall_h := 2.4
	for sz in [-1, 1]:
		var x := -hx + 0.25
		while x < hx - 0.25 - 0.01:
			var w := minf(0.5, hx - 0.25 - x)
			st.add_block(M.WOOD_THIN, c + Vector3(x + w * 0.5, wall_h * 0.5, sz * (hz - 0.125)), Vector3(w, wall_h, 0.06))
			x += w
	for sx in [-1, 1]:
		var z := -hz + 0.25
		while z < hz - 0.25 - 0.01:
			var w := minf(0.5, hz - 0.25 - z)
			st.add_block(M.WOOD_THIN, c + Vector3(sx * (hx - 0.125), wall_h * 0.5, z + w * 0.5), Vector3(0.06, wall_h, w))
			z += w


## T2. 목재 기둥이 받치는 석재 망루 80m, 기본 5발.
static func _t2(s: Stage) -> void:
	s.begin("T2", "T2 · 석재 망루", "망루를 받치는 기둥을 태워 코어를 떨어뜨려라", Stage.Goal.CORE)
	_zone(s)
	s.add_ammo(BASIC, 5)
	build_tower(s.add_structure(), Vector3(0, 0, -80))


static func build_tower(st: Structure, c: Vector3) -> void:
	var leg_h := 5.0
	var off := 1.25
	# 하중을 받는 짙은 갈색 목재 기둥 4개
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			st.add_block(M.WOOD_BEAM, c + Vector3(sx * off, leg_h * 0.5, sz * off), Vector3(0.5, leg_h, 0.5))
	# 앞쪽 가로대 (두 기둥을 잇는 가연물)
	st.add_block(M.WOOD_BEAM, c + Vector3(0, 1.4, off), Vector3(2.0, 0.3, 0.3))
	# 석재 바닥판
	st.add_block(M.STONE, c + Vector3(0, leg_h + 0.3, 0), Vector3(3.5, 0.6, 3.5))
	# 석재 방 두 층 (2x2)
	var y := leg_h + 0.6
	for layer in 2:
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				st.add_block(M.STONE, c + Vector3(sx * 0.875, y + 0.5, sz * 0.875), Vector3(1.75, 1.0, 1.75))
		y += 1.0
	st.add_block(M.CORE, c + Vector3(0, y + 0.4, 0), Vector3(0.8, 0.8, 0.8))


## T3. 밧줄에 매달린 추가 있는 석재 벽 90m, 기본 4발.
static func _t3(s: Stage) -> void:
	s.begin("T3", "T3 · 석재 벽과 매달린 추", "석재 벽 위의 코어를 떨어뜨려라", Stage.Goal.CORE)
	_zone(s)
	s.add_ammo(BASIC, 4)
	var st := s.add_structure()
	var c := Vector3(0, 0, -90)
	# 석재 벽 6m x 6m (2m 벽돌 3열)
	for layer in 6:
		for col in [-2.0, 0.0, 2.0]:
			st.add_block(M.STONE, c + Vector3(col, layer + 0.5, 0), Vector3(2.0, 1.0, 1.0))
	st.add_block(M.CORE, c + Vector3(0, 6.4, 0), Vector3(0.8, 0.8, 0.8))
	# 석재 기둥과 팔. 추는 코어 뒤쪽 모서리에 걸치게 매달아, 떨어지면 코어를 짓누르지 않고 벽 앞쪽으로 쳐낸다
	var hang_z := -0.9
	var post_h := 15.0
	st.add_block(M.STONE, c + Vector3(-4.5, post_h * 0.5, hang_z), Vector3(1.0, post_h, 1.0))
	st.add_block(M.STONE, c + Vector3(-2.25, post_h + 0.4, hang_z), Vector3(5.5, 0.8, 1.0))
	# 밧줄 (두 마디) + 추
	var rope_top := post_h
	var rope_len := 3.0
	for i in 2:
		var r := st.add_block(M.ROPE, c + Vector3(0, rope_top - rope_len * 0.25 - i * rope_len * 0.5, hang_z), Vector3(0.18, rope_len * 0.5, 0.18))
		r.hanging = true
	var wsize := 1.6
	var weight := st.add_block(M.WEIGHT, c + Vector3(0, rope_top - rope_len - wsize * 0.5, hang_z), Vector3(wsize, wsize, wsize))
	weight.hanging = true


## T4. 옆을 지나 멀어지는 적 1명 50~110m, 기본 6발.
static func _t4(s: Stage) -> void:
	s.begin("T4", "T4 · 도망치는 적", "달아나는 적에게 불을 붙여라 (첫 투척과 함께 달린다)", Stage.Goal.ENEMY)
	_zone(s)
	s.add_ammo(BASIC, 6)
	var from := Vector3(-28, 0, -42)
	var to := Vector3(42, 0, -100)
	s.add_enemy(from, to, 4.5)
	# 길을 따라 일정한 간격의 울타리 기둥
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var length := from.distance_to(to)
	var d := 0.0
	while d <= length + 0.01:
		var p := from + dir * d + side * 1.6
		s.add_prop(p + Vector3(0, 0.6, 0), Vector3(0.2, 1.2, 0.2), Color(0.35, 0.33, 0.3))
		d += 8.0
	# 경로 끝의 숲
	var forest_mat := Color(0.18, 0.32, 0.2)
	for i in 9:
		var fx := to + dir * (3.0 + (i / 3) * 3.0) + side * ((i % 3) - 1) * 3.0
		s.add_prop(fx + Vector3(0, 3.0, 0), Vector3(1.6, 6.0 + (i % 2), 1.6), forest_mat)


## T5. T2와 같은 망루, 중량 화염병만 5발.
static func _t5(s: Stage) -> void:
	s.begin("T5", "T5 · 석재 망루 (중량 화염병)", "무게가 달라진 화염병으로 망루를 무너뜨려라", Stage.Goal.CORE)
	_zone(s)
	s.add_ammo(HEAVY, 5)
	build_tower(s.add_structure(), Vector3(0, 0, -80))


## T6. 화약통이 있는 석재 건물 100m, 기본 3발 + 중량 3발.
static func _t6(s: Stage) -> void:
	s.begin("T6", "T6 · 화약통과 석재 탑", "1/2 키나 휠로 탄종을 바꿀 수 있다", Stage.Goal.CORE)
	_zone(s)
	s.add_ammo(BASIC, 3)
	s.add_ammo(HEAVY, 3)
	var st := s.add_structure()
	var c := Vector3(0, 0, -100)
	for layer in 6:
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				st.add_block(M.STONE, c + Vector3(sx * 0.75, layer + 0.5, sz * 0.75), Vector3(1.5, 1.0, 1.5))
	st.add_block(M.CORE, c + Vector3(0, 6.4, 0), Vector3(0.8, 0.8, 0.8))
	# 탑 앞에 기대 둔 화약통
	st.add_block(M.KEG, c + Vector3(0.4, 0.5, 1.5 + 0.4), Vector3(0.8, 1.0, 0.8))
