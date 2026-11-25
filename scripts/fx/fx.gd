class_name FX
extends Node2D
## 파티클 · 베기 궤적 · 충격파 · 잔상. additive=true 인스턴스는 빛나는 효과용 (가산 혼합).

var additive := false
var parts: Array = []
var rings: Array = []
var slashes: Array = []
var ghosts: Array = []


func _ready() -> void:
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if additive else CanvasItem.TEXTURE_FILTER_NEAREST


func burst(pos: Vector2, n: int, col: Color, speed: float = 60.0, life: float = 0.5, size: float = 1.5, grav: float = 120.0, up: float = 0.4) -> void:
	if parts.size() > 900: return
	for i in n:
		var a := randf() * TAU
		parts.append({"p": pos, "v": Vector2.from_angle(a) * randf_range(speed * 0.3, speed) + Vector2(0, -speed * up),
			"t": 0.0, "l": life * randf_range(0.6, 1.3), "c": col, "s": size * randf_range(0.6, 1.3), "g": grav})


func spray(pos: Vector2, dir: Vector2, n: int, col: Color, speed: float = 80.0, spread: float = 0.6, life: float = 0.4, size: float = 1.5) -> void:
	for i in n:
		var a := dir.angle() + randf_range(-spread, spread)
		parts.append({"p": pos, "v": Vector2.from_angle(a) * randf_range(speed * 0.4, speed), "t": 0.0, "l": life * randf_range(0.6, 1.2), "c": col, "s": size, "g": 80.0})


func mote(pos: Vector2, col: Color, vel: Vector2 = Vector2(0, -8), life: float = 1.2, size: float = 2.0) -> void:
	parts.append({"p": pos, "v": vel, "t": 0.0, "l": life, "c": col, "s": size, "g": 0.0, "soft": true})


func ring(pos: Vector2, r: float, col: Color, life: float = 0.35, width: float = 2.0) -> void:
	rings.append({"p": pos, "r": r, "c": col, "t": 0.0, "l": life, "w": width})


func slash(pos: Vector2, dir: Vector2, size: float, col: Color, heavy: bool = false) -> void:
	slashes.append({"p": pos, "d": dir, "s": size, "c": col, "t": 0.0, "l": 0.16 if not heavy else 0.22, "h": heavy})


func ghost(tex: Texture2D, pos: Vector2, flip: bool, col: Color, life: float = 0.3) -> void:
	ghosts.append({"tex": tex, "p": pos, "f": flip, "c": col, "t": 0.0, "l": life})


func _process(delta: float) -> void:
	for p in parts:
		p.t += delta
		p.v.y += p.g * delta
		p.v *= 0.985
		p.p += p.v * delta
	parts = parts.filter(func(p): return p.t < p.l)
	for arr in [rings, slashes, ghosts]:
		for e in arr: e.t += delta
	rings = rings.filter(func(e): return e.t < e.l)
	slashes = slashes.filter(func(e): return e.t < e.l)
	ghosts = ghosts.filter(func(e): return e.t < e.l)
	queue_redraw()


func _draw() -> void:
	for g in ghosts:
		var k: float = g.t / g.l
		var c: Color = g.c
		c.a *= 1.0 - k
		draw_set_transform(g.p, 0.0, Vector2(-1 if g.f else 1, 1))
		draw_texture(g.tex, Vector2(-8, -16), c)
		draw_set_transform(Vector2.ZERO)
	for p in parts:
		var k: float = p.t / p.l
		var c: Color = p.c
		c.a *= 1.0 - k
		if p.get("soft", false) or additive:
			var s: float = p.s * (1.0 + (0.5 if additive else 0.0))
			draw_texture_rect(Art.soft_tex, Rect2(p.p - Vector2(s, s) * 2, Vector2(s, s) * 4), false, c)
		else:
			var s: float = p.s
			draw_rect(Rect2(p.p - Vector2(s, s) * 0.5, Vector2(s, s)), c)
	for r in rings:
		var k: float = r.t / r.l
		var c: Color = r.c
		c.a *= 1.0 - k
		draw_arc(r.p, r.r * (0.3 + 0.7 * sqrt(k)), 0, TAU, 32, c, r.w * (1.0 - k * 0.5))
	for s in slashes:
		var k: float = s.t / s.l
		var c: Color = s.c
		c.a *= 1.0 - k * k
		var ang: float = (s.d as Vector2).angle()
		var sweep := 2.4
		var a0 := ang - sweep / 2.0 + k * 0.6
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 12
		for i in n + 1:
			var a := a0 + sweep * float(i) / n * minf(1.0, k * 3.0 + 0.3)
			var w := sin(PI * float(i) / n)
			pts.append(s.p + Vector2.from_angle(a) * s.s)
			inner.append(s.p + Vector2.from_angle(a) * s.s * (1.0 - 0.35 * w * (1.6 if s.h else 1.0)))
		inner.reverse()
		var poly := pts + inner
		if poly.size() >= 3:
			draw_colored_polygon(poly, c)
		draw_polyline(pts, Color(1, 1, 1, c.a), 1.0)
