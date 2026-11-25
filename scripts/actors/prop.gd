class_name Prop
extends Node2D
## 월드 소품: 빛 조각 · 기억 조각 · 능력 · 사당 · NPC · 조작 안내 · 큰 나무

var world: Node
var kind := ""
var data := {}
var t := 0.0
var active := true
var taken := false
var near := false
var _vel := Vector2.ZERO
var _light: PointLight2D


func _ready() -> void:
	t = randf() * 3.0
	match kind:
		"memory": _light = world.add_light(self, Color(0.35, 0.6, 1.0), 1.4, 0.5)
		"ability": _light = world.add_light(self, Color(0.4, 0.75, 1.0), 1.3, 0.45)
		"shrine": _light = world.add_light(self, Color(1.0, 0.8, 0.5), 1.0, 0.6, Vector2(0, -16))
		"orb": _light = world.add_light(self, Color(0.5, 0.9, 1.0), 0.6, 0.12)
		"npc":
			if data.get("ghost", false): _light = world.add_light(self, Color(0.7, 0.8, 1.0), 0.9, 0.35, Vector2(0, -8))
	if _light: _light.enabled = active


func set_active(on: bool) -> void:
	active = on
	visible = on
	if _light: _light.enabled = on


func _process(delta: float) -> void:
	t += delta
	if not active or taken: return
	var p: Player = world.player
	var d: Vector2 = p.global_position + Vector2(0, -8) - global_position
	near = d.length() < 26.0
	match kind:
		"orb":
			if d.length() < 46.0 and not p.dead:
				_vel = _vel.move_toward(d.normalized() * 260.0, 900.0 * delta)
				global_position += _vel * delta
			elif _vel.length() > 0:
				_vel = _vel.move_toward(Vector2.ZERO, 300 * delta)
				global_position += _vel * delta
			if d.length() < 8.0: _take()
		"memory", "ability":
			if d.length() < 14.0: _take()
			if randf() < 0.3:
				world.fx_add.mote(global_position + Vector2(randf_range(-6, 6), randf_range(-4, 4)), Color(0.4, 0.7, 1.0, 0.8), Vector2(0, -12), 1.0, 1.6)
		"shrine":
			if absf(d.x) < 14 and absf(d.y) < 20 and not p.dead:
				world.touch_shrine(self)
			if randf() < 0.15:
				world.fx_add.mote(global_position + Vector2(randf_range(-5, 5), -18), Color(1.0, 0.8, 0.5, 0.7), Vector2(0, -10), 1.4, 1.5)
		"npc":
			if near and Input.is_action_just_pressed("interact") and not Game.in_dialog:
				world.talk(self)
			if data.get("ghost", false) and randf() < 0.1:
				world.fx_add.mote(global_position + Vector2(randf_range(-6, 6), randf_range(-14, 0)), Color(0.7, 0.8, 1.0, 0.6), Vector2(0, -6), 1.5, 1.4)
	queue_redraw()


func _take() -> void:
	taken = true
	match kind:
		"orb": world.collect_orb(self)
		"memory": world.collect_memory(self)
		"ability": world.gain_ability(self)
	queue_free()


func _draw() -> void:
	if not active: return
	match kind:
		"orb":
			var b := sin(t * 4.0) * 1.5
			draw_texture_rect(Art.soft_tex, Rect2(Vector2(-7, -7 + b), Vector2(14, 14)), false, Color(0.4, 0.85, 1.0, 0.55))
			draw_circle(Vector2(0, b), 1.8, Color(0.85, 0.97, 1.0))
		"memory":
			var b := sin(t * 2.0) * 2.0
			var s := 1.0 + 0.08 * sin(t * 5.0)
			draw_texture_rect(Art.soft_tex, Rect2(Vector2(-16, -16 + b) * s, Vector2(32, 32) * s), false, Color(0.3, 0.55, 1.0, 0.6))
			draw_set_transform(Vector2(0, b), sin(t) * 0.2, Vector2(s, s))
			draw_texture(Art.pp(67), Vector2(-9, -9), Color(1.2, 1.3, 1.6))
			draw_set_transform(Vector2.ZERO)
			for k in 3:
				var a := t * 1.5 + k * TAU / 3.0
				draw_circle(Vector2(cos(a) * 12, sin(a) * 5 + b), 1.0, Color(0.7, 0.85, 1.0, 0.9))
		"ability":
			var b := sin(t * 2.5) * 2.0
			draw_texture_rect(Art.soft_tex, Rect2(Vector2(-14, -14 + b), Vector2(28, 28)), false, Color(0.35, 0.65, 1.0, 0.6))
			if data.id == "double":
				# 파랑 깃털
				var pts := PackedVector2Array([Vector2(0, -9), Vector2(4, -3), Vector2(3, 5), Vector2(0, 8), Vector2(-3, 5), Vector2(-4, -3)])
				for i in pts.size(): pts[i] = pts[i].rotated(0.4 + sin(t) * 0.15) + Vector2(0, b)
				draw_colored_polygon(pts, Color(0.35, 0.6, 1.0))
				draw_line(Vector2(0, -9).rotated(0.4) + Vector2(0, b), Vector2(0, 10).rotated(0.4) + Vector2(0, b), Color(0.85, 0.95, 1.0), 1.0)
			else:
				# 바람 발톱
				for k in 3:
					var x := -4 + k * 4
					draw_arc(Vector2(x, b), 7, -2.2, -0.9, 8, Color(0.75, 0.95, 1.0), 1.5)
		"shrine":
			draw_rect(Rect2(-6, -14, 12, 14), Color(0.32, 0.36, 0.5))
			draw_rect(Rect2(-7, -16, 14, 3), Color(0.42, 0.46, 0.62))
			draw_rect(Rect2(-6, -14, 12, 1), Color(0.5, 0.55, 0.7))
			var glow := 0.6 + 0.4 * sin(t * 2.0)
			var lit: bool = data.get("lit", false)
			var c := Color(1.0, 0.82, 0.5, glow) if lit else Color(0.6, 0.65, 0.8, 0.5)
			draw_circle(Vector2(0, -8), 2.5, c)
			draw_texture_rect(Art.soft_tex, Rect2(Vector2(-12, -20), Vector2(24, 24)), false, Color(c.r, c.g, c.b, 0.35 * glow))
		"npc":
			var fur: int = data.get("fur", 1)
			var col := Color(0.75, 0.85, 1.2, 0.55 + 0.1 * sin(t * 2.0)) if data.get("ghost", false) else Color(0.85, 0.85, 0.95)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if data.get("flip", false) else 1, 1))
			draw_texture(Art.cat(fur, int(t * 2.0) % 2 if fmod(t, 4.0) < 3.8 else 2), Vector2(-8, -16), col)
			draw_set_transform(Vector2.ZERO)
			if data.get("elder", false):
				# 늙은 고양이의 지팡이와 작은 별 모자
				draw_line(Vector2(7, -9), Vector2(9, 0), Color(0.55, 0.4, 0.3), 1.0)
				draw_circle(Vector2(7, -10), 1.2, Color(1, 0.85, 0.4))
			if near and not Game.in_dialog:
				world.draw_key(self, Vector2(0, -26), "E", "대화")
		"hint":
			var p: Player = world.player
			var a := clampf(1.0 - (absf(p.global_position.x - global_position.x) - 30.0) / 50.0, 0.0, 1.0)
			if a > 0.01: world.draw_hint(self, data, a)
		"tree":
			pass
