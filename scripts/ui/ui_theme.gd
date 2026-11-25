class_name UiTheme
extends RefCounted
## Kenney "UI Pack - Pixel Adventure"(CC0)를 9-slice로 써서 테마를 만든다.

const SHEET := "res://assets/free/kenney_ui_pixel_adventure/small_thick_2x.png"
const INK := Color("#3b2a20")
const INK_SOFT := Color("#6b5240")
const CREAM := Color("#fff4dc")
const GOLD := Color("#ffd447")
const GOOD := Color("#4f9a3a")
const WARN := Color("#c8413b")
const NIGHT := Color("#2b2038")


static func cell(i: int) -> Rect2:
	return Rect2((i % 23) * 32, (i / 23) * 32, 32, 32)


static func box(i: int, margin: int = 10, content: int = 6, mod: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(SHEET)
	sb.region_rect = cell(i)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content + 2
	sb.content_margin_right = content + 2
	sb.content_margin_top = content
	sb.content_margin_bottom = content
	sb.modulate_color = mod
	return sb


static func flat(bg: Color, border: Color = Color.TRANSPARENT, bw: int = 0, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	return sb


static func make() -> Theme:
	var th := Theme.new()
	th.default_font = Data.font_main
	th.default_font_size = 12
	# 패널
	th.set_stylebox("panel", "Panel", box(10))
	th.set_stylebox("panel", "PanelContainer", box(10))
	# 버튼
	var normal := box(49, 8, 3)
	var hover := box(49, 8, 3, Color(1.08, 1.05, 0.9))
	var pressed := box(56, 8, 3)
	var disabled := box(26, 8, 3, Color(1, 1, 1, 0.75))
	for t in ["Button", "OptionButton", "CheckButton"]:
		th.set_stylebox("normal", t, normal)
		th.set_stylebox("hover", t, hover)
		th.set_stylebox("pressed", t, pressed)
		th.set_stylebox("disabled", t, disabled)
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_color("font_color", t, INK)
		th.set_color("font_hover_color", t, INK)
		th.set_color("font_pressed_color", t, INK)
		th.set_color("font_focus_color", t, INK)
		th.set_color("font_disabled_color", t, Color("#e8e8f0"))
	th.set_constant("h_separation", "Button", 4)
	# 라벨
	th.set_color("font_color", "Label", INK)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_font("normal_font", "RichTextLabel", Data.font_main)
	th.set_font("bold_font", "RichTextLabel", Data.font_bold)
	th.set_font_size("normal_font_size", "RichTextLabel", 12)
	th.set_font_size("bold_font_size", "RichTextLabel", 12)
	# 탭
	th.set_stylebox("tab_selected", "TabContainer", box(10, 10, 5))
	th.set_stylebox("tab_unselected", "TabContainer", box(11, 10, 5))
	th.set_stylebox("tab_hovered", "TabContainer", box(11, 10, 5, Color(1.1, 1.1, 1.1)))
	th.set_stylebox("panel", "TabContainer", box(10, 10, 6))
	th.set_color("font_selected_color", "TabContainer", INK)
	th.set_color("font_unselected_color", "TabContainer", CREAM)
	th.set_color("font_hovered_color", "TabContainer", CREAM)
	th.set_font("font", "TabContainer", Data.font_bold)
	th.set_font_size("font_size", "TabContainer", 12)
	# 진행바
	th.set_stylebox("background", "ProgressBar", flat(Color("#5a4033"), INK, 1, 0))
	th.set_stylebox("fill", "ProgressBar", flat(Color("#8fd05a"), Color.TRANSPARENT, 0, 0))
	th.set_constant("outline_size", "ProgressBar", 0)
	th.set_color("font_color", "ProgressBar", Color.WHITE)
	th.set_font_size("font_size", "ProgressBar", 10)
	# 슬라이더
	th.set_stylebox("slider", "HSlider", flat(Color("#5a4033"), INK, 1, 2))
	th.set_stylebox("grabber_area", "HSlider", flat(Color("#e0a520"), INK, 1, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", flat(GOLD, INK, 1, 2))
	# 스크롤바
	th.set_stylebox("scroll", "VScrollBar", flat(Color(0.35, 0.25, 0.2, 0.35), Color.TRANSPARENT, 0, 2))
	th.set_stylebox("grabber", "VScrollBar", flat(Color("#a3743f")))
	th.set_stylebox("grabber_highlight", "VScrollBar", flat(Color("#c9973a")))
	th.set_stylebox("grabber_pressed", "VScrollBar", flat(Color("#e0a520")))
	# 툴팁
	th.set_stylebox("panel", "TooltipPanel", box(12, 10, 6))
	th.set_color("font_color", "TooltipLabel", CREAM)
	th.set_font("font", "TooltipLabel", Data.font_main)
	th.set_font_size("font_size", "TooltipLabel", 12)
	return th


static func label(text: String, size: int = 12, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if bold: l.add_theme_font_override("font", Data.font_bold)
	if size <= 10: l.add_theme_font_override("font", Data.font_small)
	if size >= 18: l.add_theme_font_override("font", Data.font_big)
	l.add_theme_color_override("font_color", color)
	return l


static func icon(tex: Texture2D, size: int = 16) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, cb: Callable, tex: Texture2D = null, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if tex:
		b.icon = tex
		b.expand_icon = false
	b.custom_minimum_size = Vector2(min_w, 26)
	b.pressed.connect(func():
		Sound.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Sound.play("hover", 0.1, -10.0))
	b.focus_mode = Control.FOCUS_NONE
	return b
