class_name Menus
extends CanvasLayer
## 타이틀, 스테이지 선택, 일시정지, 설정 화면. 게임이 멈춰 있어도 동작한다 (process_mode ALWAYS).
## 버튼 모양은 승리 화면과 같은 초록 판자.

signal start_requested
signal stage_chosen(index: int)
signal resume_requested
signal restart_requested
signal title_requested
signal opening_requested

enum Screen { NONE, TITLE, SELECT, PAUSE, SETTINGS }

var screen: int = Screen.NONE
var _root: Control
var _panel: Control
var _back_to: int = Screen.TITLE


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme_for_ui()
	add_child(_root)


static func theme_for_ui() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Apple SD Gothic Neo", "sans-serif"])
	font.font_weight = 700
	theme.default_font = font
	theme.default_font_size = 26
	var normal := _plank(Color(0.35, 0.5, 0.2))
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", _plank(Color(0.45, 0.62, 0.26)))
	theme.set_stylebox("pressed", "Button", _plank(Color(0.27, 0.4, 0.15)))
	theme.set_stylebox("focus", "Button", _plank(Color(0.45, 0.62, 0.26)))
	theme.set_stylebox("disabled", "Button", _plank(Color(0.25, 0.25, 0.25)))
	theme.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	theme.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6))
	theme.set_color("font_color", "Label", Color(1, 0.96, 0.88))
	theme.set_color("font_outline_color", "Label", Color(0.05, 0.03, 0.02))
	theme.set_constant("outline_size", "Label", 6)
	return theme


static func _plank(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.1, 0.08, 0.05)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func hide_all() -> void:
	screen = Screen.NONE
	if _panel:
		_panel.queue_free()
		_panel = null


func _new_panel(dim: float) -> VBoxContainer:
	if _panel:
		_panel.queue_free()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(holder)
	_panel = holder
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	return box


func _title_label(parent: Control, text: String, size: int, color := Color(1.0, 0.82, 0.15)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(340, 0)
	b.pressed.connect(func():
		Sfx.play_ui(self, "click")
		cb.call())
	parent.add_child(b)
	return b


# ---------- 타이틀 ----------

func show_title() -> void:
	screen = Screen.TITLE
	var box := _new_panel(0.25)
	var t := _title_label(box, Texts.t("game_title"), 110)
	t.rotation = -0.05
	_title_label(box, Texts.t("game_subtitle"), 26, Color(1, 0.95, 0.85))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	var first := SaveData.unlocked <= 1 and SaveData.best.is_empty()
	_button(box, Texts.t("menu_start") if first else Texts.t("menu_continue"), func(): start_requested.emit()).grab_focus()
	_button(box, Texts.t("menu_select"), func(): show_select(Screen.TITLE))
	_button(box, Texts.t("menu_opening"), func(): opening_requested.emit())
	_button(box, Texts.t("menu_settings"), func(): show_settings(Screen.TITLE))
	_button(box, Texts.t("menu_quit"), func(): get_tree().quit())


# ---------- 스테이지 선택 ----------

func show_select(back_to: int) -> void:
	screen = Screen.SELECT
	_back_to = back_to
	var box := _new_panel(0.6)
	_title_label(box, Texts.t("menu_select"), 54)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for i in Campaign.COUNT:
		var open := i < SaveData.unlocked
		var text := "%s\n%s" % [Campaign.label(i), Campaign.title(i) if open else Texts.t("locked")]
		if SaveData.is_cleared(i):
			text += "\n" + Texts.t("best_left") % int(SaveData.best[i])
		var b := _button(grid, text, func(): stage_chosen.emit(i), open)
		b.custom_minimum_size = Vector2(250, 118)
		b.add_theme_font_size_override("font_size", 20)
	_button(box, Texts.t("menu_back"), _go_back)


func _go_back() -> void:
	match _back_to:
		Screen.PAUSE:
			show_pause()
		_:
			show_title()


# ---------- 일시정지 ----------

func show_pause() -> void:
	screen = Screen.PAUSE
	var box := _new_panel(0.5)
	_title_label(box, Texts.t("paused"), 64)
	_button(box, Texts.t("menu_resume"), func(): resume_requested.emit()).grab_focus()
	_button(box, Texts.t("menu_restart"), func(): restart_requested.emit())
	_button(box, Texts.t("menu_select"), func(): show_select(Screen.PAUSE))
	_button(box, Texts.t("menu_settings"), func(): show_settings(Screen.PAUSE))
	_button(box, Texts.t("menu_title"), func(): title_requested.emit())


# ---------- 설정 ----------

func show_settings(back_to: int) -> void:
	screen = Screen.SETTINGS
	_back_to = back_to
	var box := _new_panel(0.6)
	_title_label(box, Texts.t("menu_settings"), 54)
	_slider(box, Texts.t("set_sens"), 0.3, 2.5, SaveData.mouse_sens, func(v):
		SaveData.mouse_sens = v)
	_slider(box, Texts.t("set_volume"), 0.0, 1.0, SaveData.volume, func(v):
		SaveData.volume = v
		SaveData.apply_settings())
	var fs := CheckButton.new()
	fs.text = Texts.t("set_fullscreen")
	fs.button_pressed = SaveData.fullscreen
	fs.toggled.connect(func(on):
		SaveData.fullscreen = on
		SaveData.apply_settings())
	box.add_child(fs)
	_button(box, Texts.t("menu_back"), func():
		SaveData.save_all()
		_go_back())


func _slider(parent: Control, text: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 30)
	s.value_changed.connect(cb)
	row.add_child(s)


func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.NONE:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		match screen:
			Screen.PAUSE:
				resume_requested.emit()
			Screen.SELECT, Screen.SETTINGS:
				SaveData.save_all()
				_go_back()
