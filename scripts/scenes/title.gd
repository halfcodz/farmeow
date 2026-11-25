extends Control
## 타이틀 화면: 이어하기 / 새 게임(난이도) / 설정 / 크레딧 / 종료

var _menu: VBoxContainer
var _time := 0.0
var _cats: Array = []
var _layer: Control


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sound.music("title")
	_build_background()
	var logo_box := VBoxContainer.new()
	logo_box.position = Vector2(0, 70)
	logo_box.custom_minimum_size = Vector2(960, 0)
	add_child(logo_box)
	var t1 := UiTheme.label("FARMEOW", 28, UiTheme.GOLD, true)
	t1.add_theme_font_size_override("font_size", 56)
	t1.add_theme_constant_override("outline_size", 8)
	t1.add_theme_color_override("font_outline_color", Color("#2b2038"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_box.add_child(t1)
	var t2 := UiTheme.label("냥이농장 — 낮엔 농사, 밤엔 좀비 디펜스", 14, UiTheme.CREAM)
	t2.add_theme_constant_override("outline_size", 4)
	t2.add_theme_color_override("font_outline_color", Color("#2b2038"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_box.add_child(t2)
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_show_main()
	var ver := UiTheme.label("v1.0.0 · Godot 4", 9, Color(1, 1, 1, 0.5))
	ver.position = Vector2(8, 524)
	add_child(ver)


func _build_background() -> void:
	var bg := Node2D.new()
	bg.set_script(preload("res://scripts/scenes/title_bg.gd"))
	add_child(bg)


func _clear() -> void:
	for n in _layer.get_children(): n.queue_free()


func _box(w: int = 260) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 0)
	p.add_theme_stylebox_override("panel", UiTheme.box(11, 10, 10))
	_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	p.resized.connect(func(): p.position = Vector2((960 - p.size.x) / 2.0, 230))
	return v


func _btn(v: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := UiTheme.button(text, cb)
	b.custom_minimum_size = Vector2(0, 30)
	v.add_child(b)
	return b


func _show_main() -> void:
	_clear()
	var v := _box()
	var sm := Game.save_summary()
	if not sm.is_empty():
		var ch := ""
		for c in Data.chapters:
			if int(c.id) == int(sm.chapter): ch = c.title
		if ch == "": ch = "에필로그"
		_btn(v, "이어하기 — %d일째 · %s" % [int(sm.day), ch], func():
			if Game.continue_game():
				get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_btn(v, "새 게임", func(): _show_difficulty())
	_btn(v, "설정", func(): _show_settings())
	_btn(v, "만든 사람 · 에셋", func(): _show_credits())
	_btn(v, "종료", func():
		Settings.save_settings()
		get_tree().quit())


func _show_difficulty() -> void:
	_clear()
	var v := _box(340)
	v.add_child(UiTheme.label("난이도를 골라 주세요", 14, UiTheme.INK, true))
	for k in ["easy", "normal", "hard"]:
		var d: Dictionary = Data.DIFFICULTY[k]
		var b := _btn(v, "%s — %s" % [d.name, d.desc], func(): _start(k))
		b.add_theme_font_override("font", Data.font_small)
		b.add_theme_font_size_override("font_size", 10)
	if Game.has_save():
		v.add_child(UiTheme.label("※ 새 게임을 시작하면 기존 저장이 덮어써져요", 10, UiTheme.WARN))
	_btn(v, "뒤로", func(): _show_main())


func _start(diff: String) -> void:
	Game.start_new(diff)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_settings() -> void:
	_clear()
	var p := PanelContainer.new()
	p.position = Vector2(300, 190)
	p.custom_minimum_size = Vector2(360, 0)
	_layer.add_child(p)
	p.add_child(SettingsPanel.build(func(): _show_main()))


func _show_credits() -> void:
	_clear()
	var v := _box(560)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = Vector2(540, 250)
	rt.add_theme_font_override("normal_font", Data.font_small)
	rt.add_theme_font_size_override("normal_font_size", 10)
	var f := FileAccess.open("res://CREDITS.md", FileAccess.READ)
	rt.text = f.get_as_text().replace("# ", "").replace("## ", "") if f else ""
	v.add_child(rt)
	_btn(v, "뒤로", func(): _show_main())
