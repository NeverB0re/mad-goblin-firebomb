class_name ComicArt
extends RefCounted
## 컷만화용 2D 그림 도구 (게임 3D 모델을 쓰지 않고 펜 선 + 평면 색으로 직접 그린다).
## 모든 그림은 굵은 먹선 외곽에 납작한 색. 고블린은 삐뚤빼뚤, 인간은 반듯하고 대칭.

const INK := Color(0.08, 0.06, 0.05)
const LINE := 3.0
const SKIN := Color(0.45, 0.66, 0.26)
const SKIN_DARK := Color(0.33, 0.5, 0.18)
const STEEL := Color(0.55, 0.64, 0.74)
const STEEL_DARK := Color(0.36, 0.43, 0.52)
const RED := Color(0.88, 0.1, 0.07)
const WOOD := Color(0.5, 0.33, 0.19)
const STONE := Color(0.78, 0.77, 0.74)
const FIRE_Y := Color(1.0, 0.86, 0.2)
const FIRE_O := Color(1.0, 0.5, 0.1)
const PAPER := Color(0.97, 0.94, 0.86)
const CLOTH := Color(0.62, 0.52, 0.38)


static func shape(c: CanvasItem, pts: PackedVector2Array, fill: Color, width := LINE) -> void:
	c.draw_colored_polygon(pts, fill)
	if width > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		c.draw_polyline(closed, INK, width, true)


static func ellipse_pts(center: Vector2, r: Vector2, n := 24, wobble := 0.0, phase := 0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + (sin(a * 3.0 + phase) * wobble if wobble > 0.0 else 0.0)
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts


static func ellipse(c: CanvasItem, center: Vector2, r: Vector2, fill: Color, width := LINE, wobble := 0.0) -> void:
	shape(c, ellipse_pts(center, r, 24, wobble), fill, width)


static func rect(c: CanvasItem, pos: Vector2, size: Vector2, fill: Color, width := LINE, skew := 0.0) -> void:
	shape(c, PackedVector2Array([pos + Vector2(skew, 0), pos + Vector2(size.x + skew, 0), pos + size, pos + Vector2(0, size.y)]), fill, width)


static func line(c: CanvasItem, a: Vector2, b: Vector2, width := LINE, color := INK) -> void:
	c.draw_line(a, b, color, width, true)


## 배경: 하늘 그라데이션(위→아래)과 땅.
static func backdrop(c: CanvasItem, size: Vector2, sky_top: Color, sky_bottom: Color, ground: Color, horizon := 0.72) -> void:
	var steps := 12
	for i in steps:
		var y0 := size.y * horizon * i / steps
		var y1 := size.y * horizon * (i + 1) / steps
		c.draw_rect(Rect2(0, y0, size.x, y1 - y0 + 1), sky_top.lerp(sky_bottom, float(i) / steps))
	c.draw_rect(Rect2(0, size.y * horizon, size.x, size.y * (1.0 - horizon)), ground)
	line(c, Vector2(0, size.y * horizon), Vector2(size.x, size.y * horizon), 2.0)


## 폭발 별 (뾰족뾰족한 노랑·주황 + 먹선).
static func boom(c: CanvasItem, center: Vector2, r: float, t := 0.0, spikes := 11) -> void:
	for layer in 2:
		var rr := r * (1.0 if layer == 0 else 0.55)
		var pts := PackedVector2Array()
		for i in spikes * 2:
			var a := TAU * i / (spikes * 2) + t * 0.6 + layer * 0.3
			var k := 1.0 if i % 2 == 0 else 0.55 + 0.08 * sin(t * 9.0 + i)
			pts.append(center + Vector2(cos(a), sin(a)) * rr * k)
		shape(c, pts, FIRE_O if layer == 0 else FIRE_Y, LINE if layer == 0 else 0.0)


static func smoke(c: CanvasItem, center: Vector2, r: float, shade := 0.6) -> void:
	for i in 4:
		var off := Vector2(cos(i * 1.7) * r * 0.6, -i * r * 0.35)
		ellipse(c, center + off, Vector2(r, r * 0.8) * (1.0 - i * 0.15), Color(shade, shade, shade * 1.02), 2.0, 0.08)


## 속도선.
static func speed_lines(c: CanvasItem, from: Vector2, dir: Vector2, n := 5, length := 60.0) -> void:
	var side := Vector2(-dir.y, dir.x)
	for i in n:
		var o := side * (i - n * 0.5) * 10.0
		line(c, from + o, from + o - dir * (length * (0.6 + 0.4 * ((i * 7) % 3) / 2.0)), 2.0)


## 고블린 폭탄 (검은 병 + 천 심지 불꽃).
static func bomb(c: CanvasItem, p: Vector2, s: float, lit := true, t := 0.0, kind := 0) -> void:
	match kind:
		1:
			ellipse(c, p, Vector2(13, 11) * s, Color(0.15, 0.15, 0.16))
			line(c, p + Vector2(-13, -2) * s, p + Vector2(13, -2) * s, 3.0 * s, Color(0.55, 0.5, 0.45))
		2:
			shape(c, PackedVector2Array([p + Vector2(-9, -10) * s, p + Vector2(9, -10) * s, p + Vector2(12, 10) * s, p + Vector2(-12, 10) * s]), Color(0.55, 0.34, 0.18))
		3:
			# 조명탄: 가늘고 긴 종이 통, 끝에서 하얗게 타오른다
			rect(c, p + Vector2(-5, -18) * s, Vector2(10, 34) * s, Color(0.93, 0.86, 0.6), 2.0)
			for y in [-8.0, 6.0]:
				line(c, p + Vector2(-5, y) * s, p + Vector2(5, y) * s, 3.0 * s, Color(0.25, 0.2, 0.15))
			if lit:
				c.draw_circle(p + Vector2(0, -22) * s, 11.0 * s * (1.0 + 0.15 * sin(t * 25.0)), Color(1.0, 1.0, 0.85, 0.8))
		_:
			ellipse(c, p, Vector2(11, 12) * s, Color(0.12, 0.12, 0.13))
			rect(c, p + Vector2(-4, -19) * s, Vector2(8, 8) * s, Color(0.12, 0.12, 0.13), 2.0)
	line(c, p + Vector2(0, -14) * s, p + Vector2(4, -26) * s, 2.0, CLOTH.darkened(0.2))
	if lit:
		boom(c, p + Vector2(5, -28) * s, 7.0 * s * (1.0 + 0.2 * sin(t * 20.0)), t, 7)


## 고블린. pose: grin(웃음), arms_up(만세), bomb(폭탄 듦), flip(왼쪽 봄), soot(그을림), sad(풀죽음), crazy(눈 짝짝이)
static func goblin(c: CanvasItem, p: Vector2, s: float, pose := {}, t := 0.0) -> void:
	var f := -1.0 if pose.get("flip", false) else 1.0
	var bob := sin(t * 6.0 + p.x) * 3.0 * s if pose.get("bounce", false) else 0.0
	p.y -= bob
	var skin: Color = SKIN.darkened(0.35) if pose.get("soot", false) else SKIN
	# 몸 (허름한 천 조끼)
	shape(c, PackedVector2Array([p + Vector2(-16, -30) * s, p + Vector2(16 * f, -32) * s, p + Vector2(20, 0) * s, p + Vector2(-19, 0) * s]), CLOTH)
	# 다리
	rect(c, p + Vector2(-13, 0) * s, Vector2(9, 14) * s, SKIN_DARK, 2.0)
	rect(c, p + Vector2(4, 0) * s, Vector2(9, 14) * s, SKIN_DARK, 2.0)
	# 팔
	var up: bool = pose.get("arms_up", false)
	var arm_r := p + (Vector2(20, -48) if up else Vector2(26, -14)) * s
	var arm_l := p + (Vector2(-20, -48) if up else Vector2(-26, -12)) * s
	if pose.get("sad", false):
		arm_r = p + Vector2(14, -2) * s
		arm_l = p + Vector2(-14, -2) * s
	line(c, p + Vector2(14, -26) * s, arm_r, 7.0 * s, INK)
	line(c, p + Vector2(14, -26) * s, arm_r, 4.5 * s, skin)
	line(c, p + Vector2(-14, -26) * s, arm_l, 7.0 * s, INK)
	line(c, p + Vector2(-14, -26) * s, arm_l, 4.5 * s, skin)
	if pose.get("bomb", false):
		bomb(c, arm_r + Vector2(4, -6) * s, s * 0.9, true, t, pose.get("bomb_kind", 0))
	# 머리 (큰 머리, 길고 뾰족한 귀)
	var h := p + Vector2(2 * f, -48) * s
	if pose.get("sad", false):
		h.y += 6 * s
	shape(c, PackedVector2Array([h + Vector2(-14, -4) * s, h + Vector2(-44, -16) * s, h + Vector2(-16, 6) * s]), skin)
	shape(c, PackedVector2Array([h + Vector2(14, -4) * s, h + Vector2(44, -18) * s, h + Vector2(16, 6) * s]), skin)
	ellipse(c, h, Vector2(19, 18) * s, skin, LINE, 0.04)
	# 고글 끈과 이마 위 고글 (발명가)
	line(c, h + Vector2(-18, -8) * s, h + Vector2(18, -10) * s, 3.0 * s, Color(0.35, 0.22, 0.12))
	for gx in [-7.0, 7.0]:
		ellipse(c, h + Vector2(gx, -11) * s, Vector2(6, 5) * s, Color(0.75, 0.85, 0.9), 2.0)
	# 눈 (미친 듯 짝짝이)
	var crazy: bool = pose.get("crazy", true)
	ellipse(c, h + Vector2(-7 * f, 0) * s, Vector2(5, 5) * s, Color.WHITE, 2.0)
	ellipse(c, h + Vector2(7 * f, -1) * s, Vector2(7, 7) * s if crazy else Vector2(5, 5) * s, Color.WHITE, 2.0)
	c.draw_circle(h + Vector2(-6 * f, 1) * s, 1.8 * s, INK)
	c.draw_circle(h + Vector2(8 * f, 0) * s, 2.2 * s, INK)
	# 입
	if pose.get("grin", false):
		shape(c, PackedVector2Array([h + Vector2(-11, 7) * s, h + Vector2(12, 6) * s, h + Vector2(6, 14) * s, h + Vector2(-6, 14) * s]), Color(0.35, 0.05, 0.05), 2.0)
		for k in 4:
			rect(c, h + Vector2(-9 + k * 5, 7) * s, Vector2(4, 3) * s, Color.WHITE, 1.0)
	elif pose.get("sad", false):
		c.draw_arc(h + Vector2(0, 14) * s, 6 * s, PI * 1.15, PI * 1.85, 8, INK, 2.0)
	else:
		line(c, h + Vector2(-6, 9) * s, h + Vector2(7, 8) * s, 2.0)
	if pose.get("soot", false):
		for k in 3:
			c.draw_circle(h + Vector2(-10 + k * 9, 3 + (k % 2) * 6) * s, 3.0 * s, Color(0.1, 0.09, 0.08, 0.8))


## 부족장 (늙은 고블린, 깃털 머리장식, 하얀 수염).
static func chief(c: CanvasItem, p: Vector2, s: float, pose := {}, t := 0.0) -> void:
	goblin(c, p, s, pose, t)
	var h := p + Vector2(0, -48) * s
	if pose.get("bounce", false):
		h.y -= sin(t * 6.0 + p.x) * 3.0 * s
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.35
		shape(c, PackedVector2Array([h + Vector2(0, -14) * s, h + Vector2(cos(a) * 30 - 3, -14 + sin(a) * 30) * s, h + Vector2(cos(a) * 30 + 3, -14 + sin(a) * 30) * s]), [RED.lightened(0.2), FIRE_Y, Color(0.3, 0.6, 0.9)][k % 3], 2.0)
	shape(c, PackedVector2Array([h + Vector2(-10, 8) * s, h + Vector2(10, 8) * s, h + Vector2(0, 30) * s]), Color(0.95, 0.95, 0.92), 2.0)


## 인간 병사 (청회색 갑옷, 반듯한 투구, 창). commander: 더 크고 콧수염, 남색 망토.
static func human(c: CanvasItem, p: Vector2, s: float, commander := false, pose := {}, t := 0.0) -> void:
	var f := -1.0 if pose.get("flip", false) else 1.0
	var k := 1.2 if commander else 1.0
	s *= k
	if commander:
		shape(c, PackedVector2Array([p + Vector2(-14, -50) * s, p + Vector2(14, -50) * s, p + Vector2(22, 0) * s, p + Vector2(-22, 0) * s]), Color(0.16, 0.2, 0.36))
	rect(c, p + Vector2(-14, -52) * s, Vector2(28, 40) * s, STEEL)
	line(c, p + Vector2(0, -52) * s, p + Vector2(0, -14) * s, 2.0)
	rect(c, p + Vector2(-12, -12) * s, Vector2(10, 12) * s, STEEL_DARK, 2.0)
	rect(c, p + Vector2(2, -12) * s, Vector2(10, 12) * s, STEEL_DARK, 2.0)
	var head := p + Vector2(0, -64) * s
	ellipse(c, head, Vector2(11, 12) * s, Color(0.95, 0.82, 0.7))
	# 투구
	shape(c, PackedVector2Array([head + Vector2(-13, -2) * s, head + Vector2(-11, -14) * s, head + Vector2(11, -14) * s, head + Vector2(13, -2) * s]), STEEL_DARK)
	if commander:
		shape(c, PackedVector2Array([head + Vector2(-3, -14) * s, head + Vector2(3, -14) * s, head + Vector2(0, -26) * s]), Models.GOLD, 2.0)
		shape(c, PackedVector2Array([head + Vector2(-9, 5) * s, head + Vector2(0, 3) * s, head + Vector2(9, 5) * s, head + Vector2(0, 8) * s]), Color(0.3, 0.2, 0.12), 1.5)
	c.draw_circle(head + Vector2(-4 * f, 0) * s, 1.6 * s, INK)
	c.draw_circle(head + Vector2(4 * f, 0) * s, 1.6 * s, INK)
	if pose.get("scared", false):
		ellipse(c, head + Vector2(0, 7) * s, Vector2(3, 4) * s, INK, 0.0)
	# 팔: 가리키기(으름장) / 창
	if pose.get("point", false):
		var hand := p + Vector2(34 * f, -60) * s + Vector2(0, sin(t * 5.0) * 3.0)
		line(c, p + Vector2(12 * f, -46) * s, hand, 7.0 * s)
		line(c, p + Vector2(12 * f, -46) * s, hand, 4.0 * s, STEEL)
	elif pose.get("arms_up", false):
		for sx in [-1.0, 1.0]:
			line(c, p + Vector2(12 * sx, -46) * s, p + Vector2(22 * sx, -76) * s, 6.0 * s)
	else:
		line(c, p + Vector2(16, -70) * s, p + Vector2(16, 4) * s, 3.0 * s, WOOD.darkened(0.3))
		shape(c, PackedVector2Array([p + Vector2(12, -70) * s, p + Vector2(20, -70) * s, p + Vector2(16, -82) * s]), STEEL, 2.0)


## 우리 (쇠창살).
static func cage(c: CanvasItem, pos: Vector2, size: Vector2) -> void:
	rect(c, pos, size, Color(0, 0, 0, 0), 0.0)
	for i in 6:
		var x := pos.x + size.x * i / 5.0
		line(c, Vector2(x, pos.y), Vector2(x, pos.y + size.y), 4.0, STEEL_DARK)
	rect(c, pos + Vector2(-4, -6), Vector2(size.x + 8, 8), STEEL_DARK)
	rect(c, pos + Vector2(-4, size.y - 2), Vector2(size.x + 8, 8), STEEL_DARK)


static func flag(c: CanvasItem, base: Vector2, h: float, t := 0.0, wave := 1.0) -> void:
	line(c, base, base + Vector2(0, -h), 3.0)
	var w := sin(t * 4.0) * 4.0 * wave
	shape(c, PackedVector2Array([base + Vector2(0, -h), base + Vector2(h * 0.45, -h + 4 + w), base + Vector2(h * 0.4, -h + h * 0.28 + w), base + Vector2(0, -h + h * 0.3)]), RED, 2.0)


## 인간 성탑 (반듯한 석재/강철, 총안).
static func tower(c: CanvasItem, base: Vector2, w: float, h: float, steel := false) -> void:
	var col := STEEL if steel else STONE
	rect(c, base + Vector2(-w * 0.5, -h), Vector2(w, h), col)
	var n := int(w / 14.0)
	for i in n:
		if i % 2 == 0:
			rect(c, base + Vector2(-w * 0.5 + i * w / n, -h - 10), Vector2(w / n, 10), col, 2.0)
	for row in int(h / 18.0):
		line(c, base + Vector2(-w * 0.5, -h + row * 18 + 18), base + Vector2(w * 0.5, -h + row * 18 + 18), 1.0, INK.lightened(0.4))
	if steel:
		for row in int(h / 18.0):
			for i in 3:
				c.draw_circle(base + Vector2(-w * 0.3 + i * w * 0.3, -h + row * 18 + 9), 1.5, INK)
	rect(c, base + Vector2(-w * 0.12, -h * 0.6), Vector2(w * 0.24, h * 0.18), INK.lightened(0.15), 2.0)


## 고블린 오두막 (삐뚤빼뚤한 판자, 기운 지붕).
static func hut(c: CanvasItem, base: Vector2, w: float, h: float, burning := false, t := 0.0) -> void:
	shape(c, PackedVector2Array([base + Vector2(-w * 0.5, 0), base + Vector2(-w * 0.45, -h), base + Vector2(w * 0.52, -h * 1.05), base + Vector2(w * 0.5, 0)]), WOOD)
	for i in 4:
		var x := -w * 0.5 + w * (i + 1) / 5.0
		line(c, base + Vector2(x, 0), base + Vector2(x + 3, -h), 1.5)
	shape(c, PackedVector2Array([base + Vector2(-w * 0.65, -h), base + Vector2(w * 0.1, -h * 1.7), base + Vector2(w * 0.7, -h * 1.02)]), Color(0.85, 0.7, 0.38))
	if burning:
		boom(c, base + Vector2(0, -h * 1.3), w * 0.35, t, 8)


## 탄도미사일 (가죽끈으로 묶은 거대 로켓). angle: 진행 방향 라디안.
static func rocket(c: CanvasItem, p: Vector2, s: float, angle: float, t := 0.0, lit := true) -> void:
	c.draw_set_transform(p, angle, Vector2.ONE * s)
	if lit:
		boom(c, Vector2(-70, 0), 22, t, 8)
	shape(c, PackedVector2Array([Vector2(-60, -14), Vector2(40, -14), Vector2(70, 0), Vector2(40, 14), Vector2(-60, 14)]), Color(0.18, 0.18, 0.19))
	for x in [-40.0, 0.0]:
		rect(c, Vector2(x, -16), Vector2(8, 32), Color(0.45, 0.3, 0.16), 2.0)
	shape(c, PackedVector2Array([Vector2(-60, -14), Vector2(-78, -30), Vector2(-48, -14)]), WOOD, 2.0)
	shape(c, PackedVector2Array([Vector2(-60, 14), Vector2(-78, 30), Vector2(-48, 14)]), WOOD, 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 발리스타 탑 (인간의 대공 무기).
static func ballista(c: CanvasItem, base: Vector2, s: float) -> void:
	for sx in [-1.0, 1.0]:
		line(c, base + Vector2(sx * 20, 0) * s, base + Vector2(sx * 12, -90) * s, 6.0 * s, WOOD.darkened(0.2))
	rect(c, base + Vector2(-26, -96) * s, Vector2(52, 8) * s, WOOD)
	line(c, base + Vector2(0, -104) * s, base + Vector2(28, -128) * s, 6.0 * s, WOOD)
	c.draw_arc(base + Vector2(10, -112) * s, 26 * s, PI * 0.9, PI * 1.9, 10, STEEL_DARK, 4.0 * s)
