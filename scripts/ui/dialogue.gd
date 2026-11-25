extends Control
## 대화창: 초상화 · 이름 · 타자기 효과 · 넘기기 (Space / X / E / 클릭)

signal finished

var lines: Array = []
var i := 0
var _cb := Callable()
var _box: PanelContainer
var _name: Label
var _text: RichTextLabel
var _portrait: Control
var _more: Label
var _speaker := ""
var _typing := false
var _t := 0.0
var _blip := 0
var _open := false


func _ready() -> void:
	size = Vector2(1920, 1080)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.03, 0.05, 0.1, 0.9), Color(0.55, 0.8, 1.0, 0.6), 18, 3))
	_box.position = Vector2(200, 770)
	_box.size = Vector2(1520, 270)
	_box.custom_minimum_size = _box.size
	add_child(_box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 32)
	_box.add_child(h)
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(210, 210)
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	h.add_child(v)
	_name = Art.label("", 40, UiKit.GOLD, true, 6)
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(1200, 130)
	_text.add_theme_font_override("normal_font", Art.font_body)
	_text.add_theme_font_size_override("normal_font_size", 40)
	_text.add_theme_color_override("default_color", UiKit.TEXT)
	_text.add_theme_constant_override("line_separation", 12)
	_text.add_theme_constant_override("outline_size", 6)
	_text.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07))
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_more = Art.label("▼", 32, UiKit.BLUE, true, 4)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_more)


class Portrait extends Control:
	var who := ""
	var t := 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.07, 0.1, 0.18, 0.9))
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.55, 0.8, 1.0, 0.35), false, 3.0)
		var sp: Dictionary = Story.SPEAKERS.get(who, {})
		var c := sz / 2.0
		if sp.get("lumi", false):
			var s := 1.0 + 0.08 * sin(t * 4.0)
			draw_texture_rect(Art.soft_tex, Rect2(c - Vector2(90, 90) * s, Vector2(180, 180) * s), false, Color(0.3, 0.7, 1.0, 0.7))
			draw_texture_rect(Art.soft_tex, Rect2(c - Vector2(36, 36) * s, Vector2(72, 72) * s), false, Color(0.75, 0.95, 1.0, 1.0))
			draw_circle(c, 10, Color.WHITE)
		elif sp.get("boss", false):
			draw_texture_rect(Art.zombie("bossBear", 0, 32), Rect2(c - Vector2(96, 96), Vector2(192, 192)), false, Color(0.85, 0.8, 1.0))
		elif sp.has("fur"):
			var col := Color(0.8, 0.88, 1.2, 0.75) if sp.get("ghost", false) else Color.WHITE
			var f := 2 if fmod(t, 3.5) > 3.3 else 0
			draw_texture_rect(Art.cat(sp.fur, f), Rect2(c - Vector2(88, 96), Vector2(176, 176)), false, col)
			if sp.get("elder", false):
				draw_circle(c + Vector2(70, -10), 10, Color(1, 0.85, 0.4))


func start(p_lines: Array, cb: Callable = Callable()) -> void:
	lines = p_lines
	_cb = cb
	i = 0
	_open = true
	visible = true
	Game.in_dialog = true
	get_tree().paused = true
	_box.modulate.a = 0.0
	_box.position.y = 800
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_box, "position:y", 770.0, 0.2).set_trans(Tween.TRANS_BACK)
	_show()


func _show() -> void:
	var l: Array = lines[i]
	_speaker = l[0]
	_portrait.who = _speaker
	var sp: Dictionary = Story.SPEAKERS.get(_speaker, {})
	_name.text = _speaker
	_name.add_theme_color_override("font_color", sp.get("color", UiKit.GOLD))
	_text.text = l[1]
	_text.visible_characters = 0
	_typing = true
	_t = 0.0
	if _speaker == "보리": Sound.play("mew", -8)


func _process(delta: float) -> void:
	if not _open: return
	_more.modulate.a = 0.0 if _typing else 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	if _typing:
		_t += delta
		var n := int(_t * 42.0)
		if n != _text.visible_characters:
			_text.visible_characters = n
			_blip += 1
			if _blip % 3 == 0: Sound.play("text", -14, 1.2 if _speaker == "루미" else (0.7 if _speaker == "망각의 곰" else 1.0), 0.05)
		if n >= _text.get_total_character_count():
			_typing = false


func _unhandled_input(e: InputEvent) -> void:
	if not _open: return
	var adv := e.is_action_pressed("jump") or e.is_action_pressed("attack") or e.is_action_pressed("interact")
	if adv:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
			_text.visible_characters = -1
			return
		i += 1
		Sound.play("click", -10)
		if i >= lines.size():
			_close()
		else:
			_show()


func _close() -> void:
	_open = false
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		visible = false
		get_tree().paused = false
		await get_tree().create_timer(0.12).timeout
		Game.in_dialog = false
		finished.emit()
		if _cb.is_valid(): _cb.call())
