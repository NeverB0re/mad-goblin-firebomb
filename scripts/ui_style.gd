class_name UiStyle
## 모든 화면이 함께 쓰는 글꼴·색·판 모양.
## 따뜻한 짙은 갈색 반투명 판 + 금빛 강조 + 그림자 글씨 (굵은 검은 외곽선 대신).
## 글꼴: 본문 Pretendard, 제목 Black Han Sans (둘 다 SIL OFL, fonts/ 안에 라이선스).

const BODY := preload("res://fonts/Pretendard-Medium.otf")
const BOLD := preload("res://fonts/Pretendard-Bold.otf")
const DISPLAY := preload("res://fonts/BlackHanSans-Regular.ttf")

## 판 바탕 (짙은 갈색)
const INK := Color(0.09, 0.065, 0.04)
const TEXT := Color(0.98, 0.95, 0.88)
const MUTED := Color(0.98, 0.95, 0.88, 0.62)
const GOLD := Color(1.0, 0.78, 0.26)
## 판 테두리 (아주 옅은 빛)
const EDGE := Color(1.0, 0.9, 0.7, 0.14)


## 반투명 판
static func panel(alpha := 0.66, radius := 14, margin := 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


static func _button_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := panel(bg.a, 12, 0.0)
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	return sb


## 메뉴·결과 화면 공통 테마
static func theme(font_size := 22) -> Theme:
	var t := Theme.new()
	t.default_font = BOLD
	t.default_font_size = font_size
	t.set_stylebox("normal", "Button", _button_box(Color(INK, 0.7), EDGE, 1))
	t.set_stylebox("hover", "Button", _button_box(Color(0.22, 0.16, 0.08, 0.88), GOLD, 2))
	t.set_stylebox("pressed", "Button", _button_box(Color(0.42, 0.3, 0.1, 0.92), GOLD, 2))
	var focus := _button_box(Color(0, 0, 0, 0), Color(GOLD, 0.7), 2)
	focus.draw_center = false
	focus.shadow_size = 0
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", _button_box(Color(INK, 0.38), Color(EDGE, 0.06), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD.lightened(0.25))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.32))
	_shadow(t, "Label")
	_shadow(t, "CheckButton")
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	return t


static func _shadow(t: Theme, type: String) -> void:
	t.set_color("font_shadow_color", type, Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_x", type, 0)
	t.set_constant("shadow_offset_y", type, 2)
	t.set_color("font_outline_color", type, Color(INK, 0.55))
	t.set_constant("outline_size", type, 3)


## 첫 버튼 (주 동작): 금빛 판에 짙은 글씨
static func primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _button_box(GOLD, GOLD.lightened(0.3), 1))
	b.add_theme_stylebox_override("hover", _button_box(GOLD.lightened(0.15), Color(1, 1, 1, 0.9), 2))
	b.add_theme_stylebox_override("pressed", _button_box(GOLD.darkened(0.2), GOLD, 2))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, INK)


## 글 한 줄 (그림자 글씨). display = 제목 글꼴
static func label(text: String, size: int, color := TEXT, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", DISPLAY)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 20))
		l.add_theme_color_override("font_outline_color", Color(INK, 0.9))
		l.add_theme_constant_override("outline_size", maxi(4, size / 14))
	else:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_color_override("font_outline_color", Color(INK, 0.55))
		l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 마우스를 올리면 살짝 커진다
static func hover_grow(b: Control, k := 1.04) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func():
		if not b.is_inside_tree() or (b is BaseButton and b.disabled):
			return
		b.create_tween().set_ignore_time_scale(true).tween_property(b, "scale", Vector2.ONE * k, 0.1))
	b.mouse_exited.connect(func():
		if b.is_inside_tree():
			b.create_tween().set_ignore_time_scale(true).tween_property(b, "scale", Vector2.ONE, 0.12))


## 등장: 살짝 작은 데서 커지며 나타난다 (멈춤·슬로모션과 무관). 컨테이너 안에서도 자리가 흔들리지 않게 크기·투명도만 바꾼다.
static func pop_in(c: Control, delay := 0.0) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * 0.94
	var tw := c.create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_callback(func(): c.pivot_offset = c.size * 0.5).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.22).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
