extends Control
## 일시정지 (Esc / Start)

var main: Node
var _box: VBoxContainer
var _open := false


func _ready() -> void:
	size = Vector2(1920, 1080)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	visible = false


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _open: close()
		elif not Game.in_dialog: open()


func open() -> void:
	_open = true
	visible = true
	get_tree().paused = true
	Sound.play("open")
	_build_main()


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Sound.play("close")
	Settings.save()


func _clear() -> void:
	for n in get_children(): n.queue_free()


func _frame(title: String) -> VBoxContainer:
	_clear()
	var dim := ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0.01, 0.02, 0.05, 0.7)
	add_child(dim)
	var v := VBoxContainer.new()
	v.position = Vector2(660, 250)
	v.size = Vector2(600, 600)
	v.add_theme_constant_override("separation", 20)
	add_child(v)
	var t := Art.label(title, 64, UiKit.BLUE, false, 10)
	t.add_theme_font_override("font", Art.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _build_main() -> void:
	var v := _frame("일시정지")
	var b1 := UiKit.button("계속하기", func(): close())
	v.add_child(b1)
	v.add_child(UiKit.button("설정", func(): _build_settings()))
	v.add_child(UiKit.button("저장하고 타이틀로", func():
		_open = false
		main.to_title()))
	b1.grab_focus()


func _build_settings() -> void:
	var v := _frame("설정")
	_slider(v, "전체 음량", Settings.master, func(x): Settings.master = x; Settings.apply())
	_slider(v, "음악", Settings.music, func(x): Settings.music = x; Settings.apply())
	_slider(v, "효과음", Settings.sfx, func(x):
		Settings.sfx = x
		Settings.apply()
		Sound.play("orb", -6))
	var fs := UiKit.button("전체 화면: " + ("켬" if Settings.fullscreen else "끔"), func(): pass)
	fs.pressed.connect(func():
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()
		fs.text = "전체 화면: " + ("켬" if Settings.fullscreen else "끔"))
	v.add_child(fs)
	var sk := UiKit.button("화면 흔들림: " + ("켬" if Settings.shake else "끔"), func(): pass)
	sk.pressed.connect(func():
		Settings.shake = not Settings.shake
		sk.text = "화면 흔들림: " + ("켬" if Settings.shake else "끔"))
	v.add_child(sk)
	var back := UiKit.button("뒤로", func(): _build_main())
	v.add_child(back)
	back.grab_focus()


func _slider(v: Control, text: String, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Art.label(text, 34, UiKit.TEXT, false, 4)
	l.custom_minimum_size.x = 200
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(320, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(cb)
	h.add_child(s)
	v.add_child(h)
