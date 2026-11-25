class_name UiKit
extends RefCounted
## 공통 UI 스타일 — 어두운 반투명 판, 하늘빛 테두리, 큼직한 글씨.

const INK := Color(0.03, 0.04, 0.09, 0.82)
const EDGE := Color(0.55, 0.8, 1.0, 0.55)
const TEXT := Color(0.94, 0.96, 1.0)
const SUB := Color(0.7, 0.78, 0.92)
const GOLD := Color(1.0, 0.86, 0.55)
const BLUE := Color(0.55, 0.82, 1.0)


static func panel_style(bg: Color = INK, edge: Color = EDGE, r: int = 14, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.set_content_margin_all(24)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 12
	return s


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = Art.font_body
	th.default_font_size = 36
	var normal := panel_style(Color(0.06, 0.08, 0.15, 0.75), Color(0.5, 0.7, 0.95, 0.25), 12, 2)
	normal.set_content_margin_all(14)
	normal.content_margin_left = 34
	normal.content_margin_right = 34
	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.2, 0.34, 0.9)
	hover.border_color = Color(0.65, 0.88, 1.0, 0.95)
	hover.set_border_width_all(3)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.2, 0.32, 0.5, 0.95)
	for k in ["Button", "CheckButton"]:
		th.set_stylebox("normal", k, normal)
		th.set_stylebox("hover", k, hover)
		th.set_stylebox("focus", k, hover)
		th.set_stylebox("pressed", k, pressed)
		th.set_stylebox("hover_pressed", k, pressed)
		th.set_stylebox("disabled", k, normal)
		th.set_color("font_color", k, TEXT)
		th.set_color("font_hover_color", k, Color(1, 1, 1))
		th.set_color("font_focus_color", k, Color(1, 1, 1))
		th.set_color("font_pressed_color", k, GOLD)
		th.set_color("font_disabled_color", k, Color(0.5, 0.55, 0.65))
		th.set_font_size("font_size", k, 36)
		th.set_constant("outline_size", k, 6)
		th.set_color("font_outline_color", k, Color(0.02, 0.03, 0.07))
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "PanelContainer", panel_style())
	th.set_stylebox("slider", "HSlider", panel_style(Color(0.1, 0.14, 0.24), Color(0, 0, 0, 0), 6, 0))
	var grab := panel_style(BLUE, Color(1, 1, 1, 0.6), 6, 2)
	grab.set_content_margin_all(6)
	th.set_stylebox("grabber_area", "HSlider", grab)
	th.set_stylebox("grabber_area_highlight", "HSlider", grab)
	return th


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(520, 76)
	b.pressed.connect(func():
		Sound.play("click")
		cb.call())
	b.focus_entered.connect(func(): Sound.play("hover", -10))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b
