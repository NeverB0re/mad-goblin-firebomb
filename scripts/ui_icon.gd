class_name UiIcon
extends Control
## 글자 대신 쓰는 작은 그림 (탄종, 폭격대, 최종 로켓, 남은 탄).
## 모두 코드로 그린다: 48×48 칸 기준 좌표를 크기에 맞춰 늘린다.

## he, fire, oil, flare, paint, bomber, rocket
var kind := "he"


static func make(p_kind: String, px := 48.0) -> UiIcon:
	var i := UiIcon.new()
	i.kind = p_kind
	i.custom_minimum_size = Vector2(px, px)
	i.size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## 탄종 → 그림 이름
static func of_ammo(kind_id: int) -> String:
	match kind_id:
		AmmoType.Kind.FIRE:
			return "fire"
		AmmoType.Kind.OIL:
			return "oil"
		AmmoType.Kind.FLARE:
			return "flare"
		AmmoType.Kind.PAINT:
			return "paint"
	return "he"


func _draw() -> void:
	var k := size.x / 48.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var ink := Color(0.05, 0.04, 0.03)
	match kind:
		"he":
			# 까만 쇠공 + 쇠 꼭지 + 꼬인 심지 + 불똥
			draw_circle(Vector2(22, 29), 15.5, ink)
			draw_circle(Vector2(22, 29), 14, Color(0.13, 0.13, 0.15))
			draw_circle(Vector2(16, 23), 4, Color(0.42, 0.42, 0.48))
			draw_rect(Rect2(18, 11, 9, 6), Color(0.55, 0.5, 0.42))
			draw_polyline(PackedVector2Array([Vector2(22, 11), Vector2(25, 6), Vector2(30, 7), Vector2(33, 3)]), Color(0.85, 0.75, 0.5), 2.5)
			_spark(Vector2(35, 3), 6.0)
		"fire":
			# 불룩한 질항아리 + 밧줄 + 천 마개에서 솟는 불길
			var jar := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				jar.append(Vector2(24 + cos(a) * 15, 31 + sin(a) * 13))
			draw_colored_polygon(jar, Color(0.66, 0.34, 0.16))
			draw_polyline(jar + PackedVector2Array([jar[0]]), ink, 2.0)
			draw_rect(Rect2(18, 14, 12, 7), Color(0.66, 0.34, 0.16))
			draw_line(Vector2(9, 31), Vector2(39, 31), Color(0.88, 0.76, 0.48), 3.0)
			draw_line(Vector2(13, 38), Vector2(35, 38), Color(0.88, 0.76, 0.48), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(16, 15), Vector2(20, 4), Vector2(24, 10), Vector2(27, 1), Vector2(32, 15)]), Color(1.0, 0.45, 0.08))
			draw_colored_polygon(PackedVector2Array([Vector2(20, 15), Vector2(23, 8), Vector2(26, 12), Vector2(28, 15)]), Color(1.0, 0.85, 0.3))
		"oil":
			# 반질반질한 검은 기름방울 (무지갯빛 번들거림과 흰 반짝임) + 아래 고인 웅덩이
			draw_colored_polygon(PackedVector2Array([Vector2(8, 42), Vector2(40, 42), Vector2(44, 46), Vector2(4, 46)]), Color(0.06, 0.05, 0.04))
			var body := PackedVector2Array([Vector2(24, 3), Vector2(13, 22)])
			for i in 13:
				var a := PI * i / 12.0
				body.append(Vector2(24 - cos(a) * 12, 28 + sin(a) * 12))
			body.append(Vector2(35, 22))
			draw_colored_polygon(body, Color(0.07, 0.06, 0.05))
			draw_polyline(body + PackedVector2Array([body[0]]), Color(0.0, 0.0, 0.0), 2.0)
			draw_line(Vector2(15, 30), Vector2(20, 38), Color(0.45, 0.3, 0.7, 0.8), 3.0)
			draw_line(Vector2(18, 32), Vector2(22, 38), Color(0.25, 0.6, 0.55, 0.8), 2.0)
			draw_circle(Vector2(19, 22), 3.2, Color(1, 1, 1, 0.9))
			draw_circle(Vector2(30, 34), 1.6, Color(1, 1, 1, 0.6))
		"flare":
			# 비스듬한 종이 통(빨간 띠) + 끝에서 터지는 밝은 별 (검은 테두리로 밝은 배경에서도 보이게)
			draw_set_transform(Vector2(24 * k, 28 * k), -0.6, Vector2(k, k))
			draw_rect(Rect2(-5.5, -3.5, 11, 25), ink)
			draw_rect(Rect2(-4, -2, 8, 22), Color(0.93, 0.86, 0.6))
			draw_rect(Rect2(-4, 6, 8, 3), Color(0.75, 0.2, 0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
			_spark(Vector2(19, 13), 14.0, ink)
			_spark(Vector2(19, 13), 12.0, Color(1.0, 0.85, 0.2))
		"paint":
			# 연기알: 분홍 유리 구슬에서 가는 연기가 꼬불꼬불 솟는다
			var c := Fx.PAINT_COLOR
			draw_polyline(PackedVector2Array([Vector2(26, 26), Vector2(30, 18), Vector2(26, 11), Vector2(31, 4)]), Color(c, 0.55), 4.0)
			draw_polyline(PackedVector2Array([Vector2(22, 24), Vector2(18, 15), Vector2(22, 8)]), Color(c, 0.4), 3.0)
			draw_circle(Vector2(24, 33), 12, Color(0.05, 0.04, 0.03))
			draw_circle(Vector2(24, 33), 10.5, c)
			draw_circle(Vector2(24, 33), 6, c.lightened(0.3))
			draw_circle(Vector2(20, 29), 3, Color(1, 1, 1, 0.85))
		"bomber":
			# 삼각 글라이더 날개 아래 매달린 고블린과 폭탄
			draw_colored_polygon(PackedVector2Array([Vector2(4, 22), Vector2(24, 8), Vector2(44, 22), Vector2(24, 17)]), Color(0.86, 0.8, 0.66))
			draw_polyline(PackedVector2Array([Vector2(4, 22), Vector2(24, 8), Vector2(44, 22), Vector2(24, 17), Vector2(4, 22)]), ink, 2.0)
			draw_line(Vector2(24, 17), Vector2(24, 26), ink, 2.0)
			draw_circle(Vector2(24, 29), 5, Color(0.4, 0.62, 0.25))
			draw_circle(Vector2(24, 39), 7, Color(0.13, 0.13, 0.15))
		"rocket":
			# 빨간 거대 로켓
			draw_colored_polygon(PackedVector2Array([Vector2(24, 2), Vector2(32, 14), Vector2(32, 36), Vector2(16, 36), Vector2(16, 14)]), Color(0.85, 0.15, 0.1))
			draw_colored_polygon(PackedVector2Array([Vector2(16, 26), Vector2(8, 40), Vector2(16, 36)]), Color(0.6, 0.6, 0.65))
			draw_colored_polygon(PackedVector2Array([Vector2(32, 26), Vector2(40, 40), Vector2(32, 36)]), Color(0.6, 0.6, 0.65))
			draw_circle(Vector2(24, 18), 3.5, Color(0.95, 0.9, 0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(18, 37), Vector2(24, 47), Vector2(30, 37)]), Color(1.0, 0.6, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 별 모양 불똥
func _spark(at: Vector2, r: float, col := Color(1.0, 0.8, 0.25)) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.4))
	draw_colored_polygon(pts, col)
	draw_circle(at, r * 0.25, Color(1, 1, 0.9))
