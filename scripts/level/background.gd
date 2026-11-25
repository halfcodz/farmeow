extends Node2D
## 먼 배경 (화면 좌표 1920x1080). 밤하늘 그라데이션 · 달빛 · 멀리 겹친 숲 실루엣 · 빛줄기 · 떠다니는 포자.
## 카메라 위치에 따라 층마다 다른 속도로 움직여 깊이감을 만든다.

var world: Node
var t := 0.0
var _far: Array = []
var _mid: Array = []
var _spores: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 60:
		_far.append({"x": r.randf() * 4000.0, "h": r.randf_range(260, 520), "w": r.randf_range(50, 110)})
	for i in 40:
		_mid.append({"x": r.randf() * 4000.0, "h": r.randf_range(380, 760), "w": r.randf_range(60, 130)})
	for i in 90:
		_spores.append({"x": r.randf() * 1920.0, "y": r.randf() * 1080.0, "s": r.randf_range(2, 6), "ph": r.randf() * TAU, "z": r.randf_range(0.2, 1.0)})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _cam() -> Vector2:
	if world and world.cam: return world.cam.global_position
	return Vector2(t * 20.0, 400)


func _draw() -> void:
	var c := _cam()
	# 하늘
	var top := Color(0.02, 0.03, 0.09)
	var mid := Color(0.05, 0.1, 0.2)
	var bot := Color(0.09, 0.2, 0.3)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 600), Vector2(0, 600)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, 600), Vector2(1920, 600), Vector2(1920, 1080), Vector2(0, 1080)]), PackedColorArray([mid, mid, bot, bot]))
	# 달빛
	var moon := Vector2(1500 - c.x * 0.02, 190 - c.y * 0.02)
	draw_texture_rect(Art.light_tex, Rect2(moon - Vector2(420, 420), Vector2(840, 840)), false, Color(0.5, 0.65, 0.9, 0.22))
	draw_circle(moon, 46, Color(0.85, 0.9, 1.0, 0.85))
	draw_circle(moon + Vector2(14, -8), 40, Color(0.7, 0.78, 0.95, 0.3))
	# 별
	for i in 50:
		var sx := fmod(i * 397.0 - c.x * 0.01, 1920.0)
		var sy := fmod(i * 211.0, 520.0)
		draw_rect(Rect2(sx, sy, 3, 3), Color(0.8, 0.85, 1.0, 0.3 + 0.3 * sin(t * 2.0 + i)))
	# 먼 숲 (Kenney 배경 타일 실루엣을 길게 반복)
	var far_y := 760.0 - c.y * 0.12
	var bg_tex: Texture2D = Art.region("tiles/pp/backgrounds.png", Rect2(24, 24, 72, 24))
	var tw := 72.0 * 10.0
	var off := fmod(-c.x * 0.15, tw)
	for k in range(-1, 5):
		draw_texture_rect(bg_tex, Rect2(off + k * tw, far_y - 240, tw, 240), false, Color(0.12, 0.2, 0.34, 0.9))
	draw_rect(Rect2(0, far_y, 1920, 1080 - far_y + 10), Color(0.1, 0.17, 0.28))
	# 빛줄기 (가산)
	for k in 5:
		var bx := fmod(300.0 + k * 470.0 - c.x * 0.25, 2400.0) - 200.0
		var a := 0.05 + 0.03 * sin(t * 0.7 + k)
		draw_polygon(PackedVector2Array([Vector2(bx, -20), Vector2(bx + 110, -20), Vector2(bx + 420, 1100), Vector2(bx + 180, 1100)]),
			PackedColorArray([Color(0.6, 0.8, 1.0, a), Color(0.6, 0.8, 1.0, a), Color(0.6, 0.8, 1.0, 0.0), Color(0.6, 0.8, 1.0, 0.0)]))
	# 중간 숲: 가는 나무줄기 + 둥근 수관
	for tr in _far:
		var x := fmod(tr.x - c.x * 0.3, 4000.0) - 500.0
		if x < -200 or x > 2100: continue
		var base := 900.0 - c.y * 0.25
		var col := Color(0.07, 0.13, 0.22)
		draw_rect(Rect2(x - tr.w * 0.12, base - tr.h, tr.w * 0.24, tr.h + 300), col)
		draw_circle(Vector2(x, base - tr.h), tr.w * 0.75, col)
		draw_circle(Vector2(x - tr.w * 0.5, base - tr.h + 30), tr.w * 0.55, col)
		draw_circle(Vector2(x + tr.w * 0.5, base - tr.h + 25), tr.w * 0.6, col)
	for tr in _mid:
		var x := fmod(tr.x - c.x * 0.5, 4000.0) - 500.0
		if x < -200 or x > 2100: continue
		var base := 1080.0 - c.y * 0.4
		var col := Color(0.045, 0.08, 0.14)
		draw_rect(Rect2(x - tr.w * 0.15, base - tr.h, tr.w * 0.3, tr.h + 600), col)
		draw_circle(Vector2(x, base - tr.h), tr.w * 0.9, col)
		draw_circle(Vector2(x - tr.w * 0.6, base - tr.h + 40), tr.w * 0.65, col)
		draw_circle(Vector2(x + tr.w * 0.6, base - tr.h + 30), tr.w * 0.7, col)
	# 안개
	for k in 3:
		var fy := 700.0 + k * 120.0 - c.y * 0.3
		draw_texture_rect(Art.light_tex, Rect2(fmod(-c.x * (0.2 + k * 0.1) + t * 12.0, 1920.0) - 1200, fy - 200, 2400, 400), false, Color(0.4, 0.6, 0.8, 0.06))
		draw_texture_rect(Art.light_tex, Rect2(fmod(-c.x * (0.2 + k * 0.1) + t * 12.0, 1920.0) + 1200, fy - 200, 2400, 400), false, Color(0.4, 0.6, 0.8, 0.06))
	# 포자
	for s in _spores:
		var x := fmod(s.x - c.x * s.z * 0.4 + sin(t * 0.5 + s.ph) * 30.0 + 4000.0, 1920.0)
		var y := fmod(s.y - t * 12.0 * s.z - c.y * s.z * 0.2 + 4000.0, 1080.0)
		var a := 0.25 + 0.25 * sin(t * 2.0 + s.ph)
		draw_texture_rect(Art.soft_tex, Rect2(x - s.s * 2, y - s.s * 2, s.s * 4, s.s * 4), false, Color(0.55, 0.85, 1.0, a))
