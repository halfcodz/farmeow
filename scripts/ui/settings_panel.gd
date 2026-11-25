class_name SettingsPanel
extends RefCounted
## 설정 화면 (타이틀·게임 공용)


static func build(on_close: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UiTheme.label("설정", 14, UiTheme.INK, true))
	_slider(v, "전체 음량", Settings.master, func(x): Settings.master = x; Settings.apply())
	_slider(v, "음악", Settings.music, func(x): Settings.music = x; Settings.apply())
	_slider(v, "효과음", Settings.sfx, func(x):
		Settings.sfx = x
		Settings.apply()
		Sound.play("coin"))
	_check(v, "전체 화면", Settings.fullscreen, func(on): Settings.fullscreen = on; Settings.apply())
	var row := HBoxContainer.new()
	row.add_child(UiTheme.label("창 크기", 12))
	for k in [1, 2, 3]:
		row.add_child(UiTheme.button("x%d" % k, func():
			Settings.window_scale = k
			Settings.fullscreen = false
			Settings.apply(), null, 44))
	v.add_child(row)
	_check(v, "화면 흔들림", Settings.screen_shake, func(on): Settings.screen_shake = on)
	_check(v, "피해 숫자 표시", Settings.damage_numbers, func(on): Settings.damage_numbers = on)
	var close := UiTheme.button("닫기", func():
		Settings.save_settings()
		on_close.call(), null, 90)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	return v


static func _slider(parent: Control, text: String, value: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.label(text, 12)
	l.custom_minimum_size.x = 90
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(200, 16)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	h.add_child(s)
	parent.add_child(h)


static func _check(parent: Control, text: String, on: bool, cb: Callable) -> void:
	var b := CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.toggled.connect(cb)
	parent.add_child(b)
