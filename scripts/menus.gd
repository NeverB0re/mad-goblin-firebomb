class_name Menus
extends CanvasLayer
## 타이틀, 스테이지 선택, 일시정지, 설정 화면. 게임이 멈춰 있어도 동작한다 (process_mode ALWAYS).
## 모양은 UiStyle (짙은 갈색 반투명 판, 금빛 강조).

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
	return UiStyle.theme(22)


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
	bg.color = Color(UiStyle.INK, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	# 가장자리를 더 어둡게 (가운데 메뉴에 눈이 가게)
	var vig := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)])
	g.offsets = PackedFloat32Array([0.35, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.1, 1.1)
	vig.texture = gt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vig)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	# 다음 프레임에 칸들이 차례로 나타난다
	(func():
		if not is_instance_valid(box):
			return
		var k := 0
		for c in box.get_children():
			if c is Control:
				UiStyle.pop_in(c, 0.04 * k)
				k += 1).call_deferred()
	return box


func _title_label(parent: Control, text: String, size: int, color := UiStyle.GOLD) -> Label:
	var l := UiStyle.label(text, size, color, size >= 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(360, 0)
	UiStyle.hover_grow(b)
	b.pressed.connect(func():
		Sfx.play_ui(self, "click")
		cb.call())
	parent.add_child(b)
	return b


# ---------- 타이틀 ----------

func show_title() -> void:
	screen = Screen.TITLE
	var box := _new_panel(0.25)
	_title_label(box, Texts.t("game_title"), 120)
	_title_label(box, Texts.t("game_subtitle"), 22, UiStyle.TEXT)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)
	var first := SaveData.unlocked <= 1 and SaveData.best.is_empty()
	var go := _button(box, Texts.t("menu_start") if first else Texts.t("menu_continue"), func(): start_requested.emit())
	UiStyle.primary(go)
	go.grab_focus()
	_button(box, Texts.t("menu_select"), func(): show_select(Screen.TITLE))
	_button(box, Texts.t("menu_opening"), func(): opening_requested.emit())
	_button(box, Texts.t("menu_settings"), func(): show_settings(Screen.TITLE))
	_button(box, Texts.t("menu_quit"), func(): get_tree().quit())


# ---------- 스테이지 선택 ----------

var _select_world := -1


## 지금 진지가 있는 월드 (잠깐 메뉴에서 진지 고르기를 열면 이 월드부터 보여 준다)
var current_world := -1


func show_select(back_to: int, world := -1) -> void:
	screen = Screen.SELECT
	_back_to = back_to
	if world < 0:
		world = clampi((SaveData.unlocked - 1) / 10, 0, Campaign.WORLDS.size() - 1)
	_select_world = world
	var box := _new_panel(0.6)
	_title_label(box, Texts.t("menu_select"), 54)
	# 월드 고르기 (열린 월드만)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	for w in Campaign.WORLDS.size():
		var b := _button(tabs, "%d  %s" % [w + 1, Campaign.WORLDS[w]], func(): show_select(back_to, w), w * 10 < SaveData.open_count())
		b.custom_minimum_size = Vector2(0, 0)
		b.add_theme_font_size_override("font_size", 17)
		if w == world:
			UiStyle.primary(b)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for i in range(world * 10, world * 10 + 10):
		var open := i < SaveData.open_count()
		var b := _button(grid, "", func(): stage_chosen.emit(i), open)
		b.custom_minimum_size = Vector2(230, 112)
		# 카드: 번호(금빛 제목 글꼴) / 이름 / 별
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var num := UiStyle.label(Campaign.label(i), 24, UiStyle.GOLD if open else UiStyle.MUTED, true)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(num)
		var name_l := UiStyle.label(Campaign.title(i) if open else Texts.t("locked"), 16, UiStyle.TEXT if open else UiStyle.MUTED)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_l)
		if SaveData.is_cleared(i):
			var n := int(SaveData.stars.get(i, 1))
			var st := UiStyle.label("★".repeat(n) + "☆".repeat(3 - n), 18, UiStyle.GOLD)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(st)
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
	var go := _button(box, Texts.t("menu_resume"), func(): resume_requested.emit())
	UiStyle.primary(go)
	go.grab_focus()
	_button(box, Texts.t("menu_restart"), func(): restart_requested.emit())
	_button(box, Texts.t("menu_select"), func(): show_select(Screen.PAUSE, current_world))
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
