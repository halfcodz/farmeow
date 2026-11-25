extends Node
## 그림·글꼴 도우미. 모든 그래픽은 원작 냥이농장 도트 + Kenney CC0 타일.

const TILE := 18
var font_body: FontFile
var font_bold: FontFile
var font_title: FontFile
var font_px: FontFile        # 월드 안 작은 글씨 (카메라 4배 → 선명)
var light_tex: Texture2D
var soft_tex: Texture2D
var _cache := {}


func _ready() -> void:
	font_body = _font("Galmuri11")
	font_bold = _font("Galmuri11-Bold")
	font_title = _font("Galmuri14")
	font_px = _font("Galmuri9")
	light_tex = _radial(256, [Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	soft_tex = _radial(64, [Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])


func _font(name: String) -> FontFile:
	var f: FontFile = load("res://assets/fonts/%s.ttf" % name)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


func _radial(size: int, cols: Array, offs: Array) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(cols)
	g.offsets = PackedFloat32Array(offs)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load("res://assets/" + path)
	return _cache[path]


func region(path: String, rect: Rect2) -> AtlasTexture:
	var key := "%s|%s" % [path, rect]
	if not _cache.has(key):
		var a := AtlasTexture.new()
		a.atlas = tex(path)
		a.region = rect
		_cache[key] = a
	return _cache[key]


## Kenney Pixel Platformer 18px 타일 (20열)
func pp(i: int) -> AtlasTexture:
	return region("tiles/pp/tiles.png", Rect2((i % 20) * 18, (i / 20) * 18, 18, 18))


func town(i: int) -> AtlasTexture:
	return region("tiles/kenney/town.png", Rect2((i % 12) * 16, (i / 12) * 16, 16, 16))


func farm(i: int) -> AtlasTexture:
	return region("tiles/kenney/farm.png", Rect2((i % 12) * 16, (i / 12) * 16, 16, 16))


func battle(i: int) -> AtlasTexture:
	return region("tiles/kenney/battle.png", Rect2((i % 18) * 16, (i / 18) * 16, 16, 16))


## 고양이: 0 idle 1 idle2 2 blink 3-6 walk 7 attack 8 down
func cat(fur: int, f: int) -> AtlasTexture:
	return region("sprites/cat_%d.png" % fur, Rect2(f * 16, 0, 16, 16))


## 좀비 동물: 0-3 walk 4 hit
func zombie(id: String, f: int, size: int = 16) -> AtlasTexture:
	return region("sprites/%s.png" % id, Rect2(f * size, 0, size, size))


func label(text: String, size: int = 32, color: Color = Color.WHITE, bold: bool = false, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
