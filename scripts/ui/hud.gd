extends Control
## 게임 화면 HUD: 목숨(하트) · 빛 조각 · 기억 조각 · 능력 · 보스 체력 · 구역 이름 · 알림

var _hp_pop := 0.0
var _orb_pop := 0.0
var _last_hp := -1
var _last_orbs := -1
var _boss_name := ""
var _boss_k := 0.0
var _boss_show := 0.0
var _toast_t := 0.0
var _toast := ""
var t := 0.0
var _title: Label
var _subtitle: Label
var _title_box: VBoxContainer
var _orb_label: Label


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_label = Art.label("0", 40, Color(0.85, 0.97, 1.0), true, 8)
	_orb_label.position = Vector2(118, 116)
	add_child(_orb_label)
	_title_box = VBoxContainer.new()
	_title_box.position = Vector2(0, 300)
	_title_box.size = Vector2(1920, 200)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.modulate.a = 0.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)
	_title = Art.label("", 72, Color(0.92, 0.96, 1.0), false, 12)
	_title.add_theme_font_override("font", Art.font_title)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title)
	_subtitle = Art.label("", 36, Color(0.65, 0.8, 1.0), false, 8)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_subtitle)


func area_title(name: String, sub: String = "") -> void:
	_title.text = name
	_subtitle.text = sub if sub != "" else "잊힘의 숲"
	_title_box.pivot_offset = Vector2(960, 100)
	var tw := create_tween()
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(_title_box, "modulate:a", 0.0, 1.0)


func toast(text: String) -> void:
	_toast = text
	_toast_t = 2.0


func set_boss(name: String, hp: float, max_hp: float) -> void:
	_boss_name = name
	if name != "": _boss_k = lerpf(_boss_k, hp / max_hp, 0.3)


func _process(delta: float) -> void:
	t += delta
	_hp_pop = maxf(0.0, _hp_pop - delta * 3.0)
	_orb_pop = maxf(0.0, _orb_pop - delta * 4.0)
	_toast_t = maxf(0.0, _toast_t - delta)
	_boss_show = move_toward(_boss_show, 1.0 if _boss_name != "" else 0.0, delta * 2.0)
	if Game.hp != _last_hp:
		if _last_hp >= 0: _hp_pop = 1.0
		_last_hp = Game.hp
	if Game.orbs != _last_orbs:
		if _last_orbs >= 0: _orb_pop = 1.0
		_last_orbs = Game.orbs
	_orb_label.text = str(Game.orbs)
	_orb_label.scale = Vector2.ONE * (1.0 + _orb_pop * 0.25)
	queue_redraw()


func _draw() -> void:
	# 목숨: Kenney 하트 (18px → 4배)
	for i in Game.max_hp:
		var full := i < Game.hp
		var p := Vector2(40 + i * 80, 32)
		var s := 4.0
		if full and i == Game.hp - 1 and _hp_pop > 0.0: s += _hp_pop * 1.2
		if not full and i == Game.hp and _hp_pop > 0.0: s += _hp_pop * 0.8
		var sz := Vector2(18, 18) * s
		var c := p + Vector2(36, 36) - sz / 2.0
		draw_texture_rect(Art.pp(44 if full else 46), Rect2(c + Vector2(4, 6), sz), false, Color(0, 0, 0, 0.5))
		draw_texture_rect(Art.pp(44 if full else 46), Rect2(c, sz), false)
	# 빛 조각
	var op := Vector2(74, 140)
	draw_texture_rect(Art.soft_tex, Rect2(op - Vector2(34, 34), Vector2(68, 68)), false, Color(0.45, 0.85, 1.0, 0.6 + 0.2 * sin(t * 3.0)))
	draw_circle(op, 9, Color(0.85, 0.97, 1.0))
	# 기억 조각 (오른쪽 위)
	for i in 3:
		var have := Game.memories.has(i + 1)
		var p := Vector2(1920 - 80 - (2 - i) * 84, 36)
		if have:
			draw_texture_rect(Art.soft_tex, Rect2(p - Vector2(20, 20), Vector2(112, 112)), false, Color(0.4, 0.65, 1.0, 0.45))
		draw_texture_rect(Art.pp(67), Rect2(p, Vector2(72, 72)), false, Color(1.1, 1.2, 1.5) if have else Color(0.25, 0.28, 0.38, 0.7))
	# 능력
	var ax := 1920 - 80.0
	if Game.has_dash:
		_ability_icon(Vector2(ax + 36, 160), "dash")
		ax -= 84
	if Game.has_double:
		_ability_icon(Vector2(ax + 36, 160), "double")
	# 보스 체력
	if _boss_show > 0.01:
		var a := _boss_show
		var w := 1000.0
		var x := 960 - w / 2.0
		var y := 990.0 + (1.0 - a) * 60
		draw_rect(Rect2(x - 6, y - 6, w + 12, 34), Color(0.02, 0.02, 0.05, 0.8 * a))
		draw_rect(Rect2(x, y, w, 22), Color(0.2, 0.08, 0.12, a))
		draw_rect(Rect2(x, y, w * _boss_k, 22), Color(0.85, 0.25, 0.35, a))
		draw_rect(Rect2(x, y, w * _boss_k, 6), Color(1.0, 0.55, 0.6, a))
		var f := Art.font_bold
		draw_string_outline(f, Vector2(x, y - 16), _boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 8, Color(0, 0, 0, a))
		draw_string(f, Vector2(x, y - 16), _boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.8, 0.82, a))
	# 알림
	if _toast_t > 0.0:
		var a := minf(1.0, _toast_t * 2.0)
		var f := Art.font_body
		var tw := f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		var p := Vector2(1920 - tw - 80, 1010)
		draw_texture_rect(Art.soft_tex, Rect2(p - Vector2(60, 54), Vector2(tw + 120, 80)), false, Color(1.0, 0.85, 0.5, 0.25 * a))
		draw_string_outline(f, p, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 8, Color(0, 0, 0, a))
		draw_string(f, p, _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1.0, 0.92, 0.75, a))


func _ability_icon(c: Vector2, id: String) -> void:
	draw_circle(c, 34, Color(0.05, 0.08, 0.16, 0.8))
	draw_arc(c, 34, 0, TAU, 40, Color(0.55, 0.82, 1.0, 0.8), 3.0)
	if id == "double":
		var pts := PackedVector2Array([Vector2(0, -22), Vector2(10, -8), Vector2(8, 12), Vector2(0, 20), Vector2(-8, 12), Vector2(-10, -8)])
		for i in pts.size(): pts[i] = pts[i].rotated(0.4) + c
		draw_colored_polygon(pts, Color(0.35, 0.6, 1.0))
		draw_line(c + Vector2(0, -22).rotated(0.4), c + Vector2(0, 24).rotated(0.4), Color(0.85, 0.95, 1.0), 3.0)
	else:
		for k in 3:
			draw_arc(c + Vector2(-10 + k * 10, 4), 18, -2.2, -0.9, 10, Color(0.75, 0.95, 1.0), 4.0)
