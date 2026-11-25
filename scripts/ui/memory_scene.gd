extends Control
## 기억 회상 연출: 어두운 화면에 푸른 빛, 문장이 하나씩 떠오른다.

signal done

var _lines: Array = []
var _i := 0
var _labels: Array = []
var _box: VBoxContainer
var _title: Label
var _hint: Label
var _ready_next := false
var t := 0.0
var _active := false


func _ready() -> void:
	size = Vector2(1920, 1080)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_title = Art.label("", 56, Color(0.7, 0.85, 1.0), false, 10)
	_title.add_theme_font_override("font", Art.font_title)
	_title.position = Vector2(0, 170)
	_title.size = Vector2(1920, 80)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_box = VBoxContainer.new()
	_box.position = Vector2(160, 330)
	_box.size = Vector2(1600, 600)
	_box.add_theme_constant_override("separation", 34)
	add_child(_box)
	_hint = Art.label("Space ▶", 30, Color(0.6, 0.75, 1.0, 0.8), false, 4)
	_hint.position = Vector2(1640, 980)
	add_child(_hint)


func play(id: int) -> void:
	var m: Dictionary = Story.MEMORIES[id]
	_lines = m.lines
	_title.text = m.title
	for l in _labels: l.queue_free()
	_labels.clear()
	_i = 0
	visible = true
	_active = true
	modulate.a = 0.0
	get_tree().paused = true
	Game.in_dialog = true
	Sound.music("memory", 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.0)
	tw.tween_callback(_next)


func _next() -> void:
	if _i >= _lines.size():
		_finish()
		return
	var l := Art.label(_lines[_i], 44, UiKit.TEXT, false, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 1600
	l.modulate.a = 0.0
	if _i == _lines.size() - 1: l.add_theme_color_override("font_color", UiKit.GOLD)
	_box.add_child(l)
	_labels.append(l)
	_ready_next = false
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.9)
	tw.tween_callback(func(): _ready_next = true)
	Sound.play("wisp", -14, 0.8 + _i * 0.08)
	_i += 1


func _finish() -> void:
	_active = false
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		visible = false
		get_tree().paused = false
		Game.in_dialog = false
		done.emit())


func _process(delta: float) -> void:
	t += delta
	_hint.visible = _ready_next and _active
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if not _active: return
	if e.is_action_pressed("jump") or e.is_action_pressed("attack") or e.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _ready_next: _next()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.01, 0.02, 0.05, 0.92))
	draw_texture_rect(Art.light_tex, Rect2(260, -260, 1400, 1400), false, Color(0.25, 0.45, 0.9, 0.22 + 0.04 * sin(t)))
	for k in 40:
		var x := fmod(k * 173.0 + t * (10 + k % 5 * 6), 1920.0)
		var y := fmod(1080.0 - fmod(k * 97.0 + t * (20 + k % 7 * 5), 1200.0), 1080.0)
		draw_texture_rect(Art.soft_tex, Rect2(x - 6, y - 6, 12, 12), false, Color(0.5, 0.75, 1.0, 0.35))
