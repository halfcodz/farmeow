extends Node2D
## 잊힘의 숲 (데모 맵). LevelData의 글자 지도로 타일 · 충돌 · 적 · 소품 · 연출 지점을 만든다.

signal boss_bar(name: String, hp: float, max_hp: float)

const T := 18
const PLAYER_SCENE := preload("res://scripts/actors/player.gd")

var main: Node
var map: Array = LevelData.MAP
var W := 0
var H := 0
var player: Player
var lumi: Lumi
var boss: Boss
var fx: FX
var fx_add: FX
var cam: Camera2D
var overlay: Node2D
var enemies: Array = []
var shots: Array = []
var waves: Array = []
var rocks: Array = []
var hazards: Array = []
var hazard_cells := {}
var spots := {}           # 글자 → [위치들]
var shrines: Array = []
var memory_props := {}
var end_prop: Vector2
var boss_area := Rect2()
var boss_state := "wait"  # wait → fight → done
var gate: StaticBody2D
var area_shown := {}
var _shake := 0.0
var _cam_target := Vector2.ZERO
var _lights := 0
var _orb_pitch := 1.0
var _orb_t := 0.0


func _ready() -> void:
	H = map.size()
	W = map[0].length()
	var tint := CanvasModulate.new()
	tint.color = Color(0.36, 0.42, 0.62)
	add_child(tint)
	_build_deco_back()
	_build_tiles()
	_build_collision()
	fx = FX.new()
	fx.z_index = 4
	add_child(fx)
	fx_add = FX.new()
	fx_add.additive = true
	fx_add.z_index = 6
	add_child(fx_add)
	_spawn_entities()
	overlay = Overlay.new()
	overlay.w = self
	overlay.z_index = 7
	add_child(overlay)
	cam = Camera2D.new()
	cam.zoom = Vector2(4, 4)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = W * T
	cam.limit_bottom = H * T - T
	add_child(cam)
	cam.make_current()
	cam.global_position = player.global_position
	_cam_target = cam.global_position
	Game.shake.connect(func(a): _shake = maxf(_shake, a))


class Overlay extends Node2D:
	var w: Node
	func _process(_d: float) -> void: queue_redraw()
	func _draw() -> void: w._draw_overlay(self)


# ═════════════════════════════════════════════════════════
# 지도 → 타일 · 충돌
# ═════════════════════════════════════════════════════════

func ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H: return "#"
	return map[y][x]


func is_solid_cell(x: int, y: int) -> bool:
	return ch(x, y) == "#"


func solid_at(p: Vector2) -> bool:
	var c := ch(int(floor(p.x / T)), int(floor(p.y / T)))
	return c == "#" or c == "="


func near_hazard(p: Vector2) -> bool:
	var cx := int(p.x / T)
	var cy := int(p.y / T)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 2, cx + 3):
			if hazard_cells.has(Vector2i(x, y)): return true
	return false


## ground.png: 0 잔디 1 잔디왼 2 잔디오른 3 잔디외톨이 4,5,11 흙 6 왼 7 오른 8 아래 9 아래왼 10 아래오른
func _tile_for(x: int, y: int) -> int:
	var open_up := not is_solid_cell(x, y - 1)
	var open_l := not is_solid_cell(x - 1, y)
	var open_r := not is_solid_cell(x + 1, y)
	var open_d := not is_solid_cell(x, y + 1)
	if open_up:
		if open_l and open_r: return 3
		if open_l: return 1
		if open_r: return 2
		return 0
	if open_d:
		if open_l: return 9
		if open_r: return 10
		return 8
	if open_l: return 6
	if open_r: return 7
	return [4, 5, 4, 11][(x * 7 + y * 13) % 4]


## 공기와의 거리 (깊은 흙일수록 어둡게)
func _depth(x: int, y: int) -> int:
	for d in range(1, 4):
		for k in [Vector2i(0, -d), Vector2i(-d, 0), Vector2i(d, 0), Vector2i(0, d)]:
			if not is_solid_cell(x + k.x, y + k.y): return d
	return 4


func _build_tiles() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex("tiles/pp/tiles.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var gsrc := TileSetAtlasSource.new()
	gsrc.texture = Art.tex("tiles/ground.png")
	gsrc.texture_region_size = Vector2i(T, T)
	ts.add_source(gsrc, 1)
	for k in 12: gsrc.create_tile(Vector2i(k, 0))
	var made := {}
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.z_index = 1
	add_child(layer)
	var deep := TileMapLayer.new()
	deep.tile_set = ts
	deep.z_index = 1
	deep.modulate = Color(0.55, 0.55, 0.72)
	add_child(deep)
	var deeper := TileMapLayer.new()
	deeper.tile_set = ts
	deeper.z_index = 1
	deeper.modulate = Color(0.32, 0.32, 0.48)
	add_child(deeper)
	var hz := TileMapLayer.new()
	hz.tile_set = ts
	hz.z_index = 2
	hz.modulate = Color(1.0, 0.55, 1.0)
	add_child(hz)
	for y in H:
		for x in W:
			var c := ch(x, y)
			var idx := -1
			var target := layer
			if c == "#":
				var dp := _depth(x, y)
				var gl: TileMapLayer = layer if dp <= 1 else (deep if dp <= 2 else deeper)
				gl.set_cell(Vector2i(x, y), 1, Vector2i(_tile_for(x, y), 0))
				continue
			elif c == "=":
				var l := ch(x - 1, y) == "="
				var r := ch(x + 1, y) == "="
				idx = 49 if (l and r) or (not l and not r) else (48 if not l else 50)
			elif c == "^":
				idx = 68
				target = hz
				hazard_cells[Vector2i(x, y)] = true
				hazards.append(Rect2(x * T + 2, y * T + 9, T - 4, T - 9))
			if idx < 0: continue
			var co := Vector2i(idx % 20, idx / 20)
			if not made.has(idx):
				src.create_tile(co)
				made[idx] = true
			target.set_cell(Vector2i(x, y), 0, co)
	# 풀 · 버섯 · 꽃 장식 (잔디 윗면에만)
	var deco := Node2D.new()
	deco.z_index = 3
	add_child(deco)
	for y in range(1, H):
		for x in W:
			if ch(x, y) == "#" and ch(x, y - 1) == "." and randf() < 0.32:
				var r := randf()
				var s := Sprite2D.new()
				s.texture = Art.pp([124, 125, 124, 125, 128, 126][int(r * 6)])
				s.position = Vector2(x * T + 9 + randf_range(-3, 3), y * T - 9 + 1)
				s.flip_h = randf() < 0.5
				deco.add_child(s)
				if s.texture == Art.pp(128) and _lights < 40:
					s.modulate = Color(1.3, 1.1, 1.5)
					add_light(s, Color(0.75, 0.5, 1.0), 0.7, 0.25)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if ch(x, y) == "#":
				var x0 := x
				while x < W and ch(x, y) == "#": x += 1
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = Vector2((x - x0) * T, T)
				cs.shape = sh
				cs.position = Vector2((x0 + x) * T / 2.0, y * T + T / 2.0)
				body.add_child(cs)
			else:
				x += 1
	var plat := StaticBody2D.new()
	plat.collision_layer = 1
	add_child(plat)
	for y in H:
		var x := 0
		while x < W:
			if ch(x, y) == "=":
				var x0 := x
				while x < W and ch(x, y) == "=": x += 1
				var cs := CollisionShape2D.new()
				var sh := RectangleShape2D.new()
				sh.size = Vector2((x - x0) * T, 5)
				cs.shape = sh
				cs.one_way_collision = true
				cs.position = Vector2((x0 + x) * T / 2.0, y * T + 2.5)
				plat.add_child(cs)
			else:
				x += 1


## 타일 뒤쪽: 큰 나무 실루엣과 넝쿨 (월드와 함께 움직이는 가까운 배경)
func _build_deco_back() -> void:
	var back := BackTrees.new()
	back.w = self
	back.z_index = -1
	add_child(back)


class BackTrees extends Node2D:
	var w: Node
	var trees: Array = []
	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 77
		for i in 70:
			var x := r.randf_range(0, w.W * 18)
			trees.append({"x": x, "h": r.randf_range(90, 220), "w": r.randf_range(8, 16), "c": r.randf_range(0.0, 1.0)})
		for y in w.H:
			for x in w.W:
				if w.ch(x, y) == "T":
					trees.append({"x": x * 18 + 9, "h": 160.0, "w": 22.0, "c": 0.5, "base": (y + 1) * 18, "big": true})
	func _draw() -> void:
		for t in trees:
			var base: float = t.get("base", 0.0)
			if base == 0.0:
				base = _ground(t.x)
			var col: Color = Color(0.09, 0.13, 0.2).lerp(Color(0.12, 0.18, 0.26), t.c)
			var x: float = t.x
			draw_rect(Rect2(x - t.w / 2, base - t.h, t.w, t.h), col)
			var crown: float = t.h * 0.35 + 18
			for k in 5:
				var a: float = k * 1.3 + t.c * 6.0
				draw_circle(Vector2(x + cos(a) * crown * 0.5, base - t.h + sin(a) * crown * 0.25), crown * 0.45, col.lightened(0.04))
			if t.get("big", false):
				for k in 6:
					draw_line(Vector2(x + (k - 3) * 4, base), Vector2(x + (k - 3) * 9, base + 6), col, 2.0)
	func _ground(x: float) -> float:
		var cx := int(x / 18)
		for y in w.H:
			if w.ch(cx, y) == "#": return y * 18.0
		return w.H * 18.0


func add_light(parent: Node, col: Color, energy: float, scale_: float, offset: Vector2 = Vector2.ZERO) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = col
	l.energy = energy
	l.texture_scale = scale_
	l.position = offset
	l.blend_mode = Light2D.BLEND_MODE_ADD
	parent.add_child(l)
	_lights += 1
	return l


# ═════════════════════════════════════════════════════════
# 등장인물 · 소품
# ═════════════════════════════════════════════════════════

func _cell_pos(x: int, y: int) -> Vector2:
	return Vector2(x * T + T / 2.0, (y + 1) * T)


func _prop(kind: String, pos: Vector2, data: Dictionary = {}) -> Prop:
	var p := Prop.new()
	p.world = self
	p.kind = kind
	p.data = data
	p.position = pos
	p.z_index = 3
	add_child(p)
	return p


const HINTS := {
	"k": {"keys": ["A", "D"], "text": "이동"},
	"j": {"keys": ["Space"], "text": "점프 · 길게 누르면 높이"},
	"x": {"keys": ["X"], "text": "할퀴기 · 연타하면 3연격"},
	"w": {"keys": ["벽", "Space"], "text": "벽에 붙어 점프"},
	"d": {"keys": ["C"], "text": "바람 발톱 (대시)"},
}


func _spawn_entities() -> void:
	var start := Vector2.ZERO
	for y in H:
		for x in W:
			var c := ch(x, y)
			var pos := _cell_pos(x, y)
			if not spots.has(c): spots[c] = []
			spots[c].append(pos)
			match c:
				"P": start = pos
				"o":
					for k in 3:
						_prop("orb", pos + Vector2((k - 1) * 6, -10 - (k % 2) * 4))
				"S":
					var s := _prop("shrine", pos, {"lit": false})
					shrines.append(s)
				"N": _prop("npc", pos, {"fur": 1, "elder": true, "talk": "beryl", "flip": true})
				"G": _prop("npc", pos, {"fur": 3, "ghost": true, "talk": "mother"})
				"1", "2", "3":
					var m := _prop("memory", pos + Vector2(0, -12), {"id": int(c)})
					memory_props[int(c)] = m
					if Game.memories.has(int(c)): m.queue_free()
					elif c == "3": m.set_active(false)
				"D":
					if not Game.has_double: _prop("ability", pos + Vector2(0, -12), {"id": "double"})
				"A":
					if not Game.has_dash: _prop("ability", pos + Vector2(0, -12), {"id": "dash"})
				"k", "j", "x", "w", "d":
					_prop("hint", pos + Vector2(0, -6), HINTS[c])
				"r", "h", "b", "c", "f":
					var e := Enemy.new()
					e.world = self
					e.setup({"r": "rat", "h": "hare", "b": "boar", "c": "crow", "f": "frog"}[c])
					e.position = pos
					e.z_index = 3
					add_child(e)
					enemies.append(e)
				"E": end_prop = pos
	# 보스 둥지
	var bpos: Vector2 = spots["K"][0]
	var trig: Vector2 = spots["B"][0]
	boss_area = Rect2(Vector2(154 * T, 14 * T), Vector2((189 - 154) * T, (30 - 14) * T))
	if not Game.boss_down:
		boss = Boss.new()
		boss.world = self
		boss.position = bpos
		boss.z_index = 3
		boss.set_arena(boss_area)
		boss.visible = false
		boss.process_mode = Node.PROCESS_MODE_DISABLED
		boss.defeated.connect(_on_boss_defeated)
		add_child(boss)
	else:
		boss_state = "done"
		if memory_props.has(3) and is_instance_valid(memory_props[3]): memory_props[3].set_active(true)
	# 보리
	player = PLAYER_SCENE.new()
	player.world = self
	player.z_index = 4
	add_child(player)
	player.global_position = Game.checkpoint if Game.checkpoint != Vector2.ZERO else start
	for s in shrines:
		if s.global_position.distance_to(Game.checkpoint) < 4: s.data.lit = true
	lumi = Lumi.new()
	lumi.world = self
	lumi.player = player
	add_child(lumi)
	if Game.flags.has("lumi_join"):
		lumi.joined = true
		lumi.global_position = player.global_position + Vector2(-14, -24)
	else:
		lumi.global_position = spots["L"][0] + Vector2(30, -30)


# ═════════════════════════════════════════════════════════
# 매 프레임
# ═════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if player.dead: return
	var pr := player.hurt_rect()
	# 가시
	for h in hazards:
		if (h as Rect2).intersects(pr):
			player.hazard()
			break
	# 적과 닿으면
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.body_rect().intersects(pr):
			player.hurt(1, e.global_position.x)
	# 침 · 충격파 · 낙석
	for s in shots:
		s.v.y += 420.0 * delta
		s.p += s.v * delta
		s.t += delta
		if Rect2(s.p - Vector2(3, 3), Vector2(6, 6)).intersects(pr):
			player.hurt(1, s.p.x)
			s.dead = true
		elif solid_at(s.p) or s.t > 4.0:
			s.dead = true
			fx.burst(s.p, 8, Color(0.6, 0.9, 0.4), 40, 0.4, 1.3)
	shots = shots.filter(func(s): return not s.dead)
	for w in waves:
		w.t += delta
		w.x += w.dir * 170.0 * delta
		if randf() < 0.7: fx.burst(Vector2(w.x, w.y), 2, Color(0.85, 0.75, 0.6), 40, 0.35, 1.6, 120, 0.6)
		if absf(player.global_position.x - w.x) < 8 and player.global_position.y > w.y - 12:
			player.hurt(1, w.x - w.dir * 10)
		if w.t > 1.3 or solid_at(Vector2(w.x + w.dir * 6, w.y - 6)): w.dead = true
	waves = waves.filter(func(w): return not w.get("dead", false))
	for r in rocks:
		r.t += delta
		if r.t > r.warn:
			r.vy += 900.0 * delta
			r.y += r.vy * delta
			if Rect2(r.x - 5, r.y - 5, 10, 10).intersects(pr):
				player.hurt(1, r.x)
				r.dead = true
			if solid_at(Vector2(r.x, r.y + 5)):
				r.dead = true
				fx.burst(Vector2(r.x, r.y), 12, Color(0.6, 0.6, 0.7), 60, 0.5, 1.8)
				Sound.play("thump", -8)
	rocks = rocks.filter(func(r): return not r.get("dead", false))
	_check_triggers()


func _process(delta: float) -> void:
	# 카메라: 앞쪽을 살짝 더 보여 주고, 보스전에서는 둥지 가운데 고정
	var target := player.global_position + Vector2(player.facing * 26.0, -34.0)
	target.y += clampf(player.velocity.y * 0.08, -10, 30)
	if boss_state == "fight":
		target = Vector2(boss_area.get_center().x, boss_area.end.y - 70)
	_cam_target = _cam_target.lerp(target, minf(1.0, delta * (5.0 if boss_state != "fight" else 2.0)))
	cam.global_position = _cam_target
	_shake = maxf(0.0, _shake - delta * 18.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.5 if _shake > 0.1 else Vector2.ZERO
	_orb_t -= delta
	if _orb_t <= 0.0: _orb_pitch = 1.0
	if boss and boss_state == "fight":
		boss_bar.emit("망각의 곰", boss.hp, boss.max_hp)


func _check_triggers() -> void:
	var px := player.global_position.x / T
	for a in Story.AREAS:
		if px >= a[0] and not area_shown.has(a[1]):
			var best := true
			for b in Story.AREAS:
				if px >= b[0] and b[0] > a[0]: best = false
			if best:
				area_shown[a[1]] = true
				main.area_title(a[1])
	if not Game.flags.has("lumi_join") and player.global_position.x > spots["L"][0].x - 10:
		Game.flags["lumi_join"] = true
		lumi.joined = true
		Sound.play("wisp")
		say("lumi_join")
	if not Game.flags.has("canyon") and px > 82 and player.global_position.y > 20 * T:
		Game.flags["canyon"] = true
		say("canyon")
	if boss_state == "wait" and boss and player.global_position.x > spots["B"][0].x:
		_start_boss()
	if boss_state == "done" and Game.memories.has(3) and player.global_position.distance_to(end_prop) < 20 and not Game.flags.has("end"):
		Game.flags["end"] = true
		main.demo_end()


# ═════════════════════════════════════════════════════════
# 전투
# ═════════════════════════════════════════════════════════

func player_attack(box: Rect2, dmg: int, dir: Vector2, heavy: bool) -> int:
	var hits := 0
	var targets: Array = enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	if boss and boss_state == "fight" and not boss.dead: targets.append(boss)
	for e in targets:
		var r: Rect2 = e.body_rect()
		if r.intersects(box):
			hits += 1
			var c := r.intersection(box).get_center()
			e.take_hit(dmg, player.global_position, heavy)
			fx_add.burst(c, 10 if heavy else 6, Color(1.0, 0.95, 0.7), 110, 0.25, 1.6, 0)
			fx.spray(c, dir, 8, Color(0.85, 0.6, 1.0), 120, 0.5, 0.35, 1.4)
			fx_add.ring(c, 10 if heavy else 7, Color(1, 1, 1, 0.9), 0.15, 1.5)
	for s in shots:
		if Rect2(s.p - Vector2(4, 4), Vector2(8, 8)).intersects(box):
			s.dead = true
			hits += 1
			fx_add.burst(s.p, 10, Color(0.7, 1.0, 0.6), 80, 0.3, 1.5, 0)
	if hits > 0:
		Sound.play("hit", -2 if heavy else -5, 0.9 if heavy else 1.0)
		if heavy: Sound.play("thump", -4)
		Game.hitstop(0.07 if heavy else 0.04)
		Game.kick(3.0 if heavy else 1.5)
		lumi.flash()
	return hits


func on_enemy_seen(_e: Enemy) -> void:
	if not Game.flags.has("first_enemy") and Game.flags.has("lumi_join"):
		Game.flags["first_enemy"] = true
		say("first_enemy")


func on_enemy_killed(e: Enemy, orbs: int) -> void:
	var pos := e.global_position + Vector2(0, -6)
	Sound.play("kill")
	Sound.play("pop", -6)
	Game.hitstop(0.09)
	Game.kick(4.0)
	fx.burst(pos, 18, Color(0.55, 0.45, 0.7), 90, 0.6, 1.8)
	fx_add.burst(pos, 14, Color(0.75, 0.5, 1.0), 50, 1.0, 2.2, -40)
	fx_add.ring(pos, 16, Color(0.8, 0.6, 1.0, 0.9), 0.3, 2.0)
	for k in orbs:
		var o := _prop("orb", pos)
		o._vel = Vector2(randf_range(-80, 80), randf_range(-140, -60))
	enemies.erase(e)


func spawn_shot(p: Vector2, v: Vector2, kind: String) -> void:
	shots.append({"p": p, "v": v, "kind": kind, "t": 0.0, "dead": false})


func shockwave(pos: Vector2, dir: int) -> void:
	waves.append({"x": pos.x, "y": pos.y, "dir": dir, "t": 0.0})


func rockfall(n: int, area: Rect2) -> void:
	for k in n:
		var x := randf_range(area.position.x + 20, area.end.x - 20)
		if k == 0: x = clampf(player.global_position.x, area.position.x + 20, area.end.x - 20)
		rocks.append({"x": x, "y": area.position.y + 4, "vy": 0.0, "t": 0.0, "warn": 0.7 + k * 0.18})


func flash(c: Color, a: float) -> void:
	main.flash(c, a)


# ═════════════════════════════════════════════════════════
# 수집 · 사당 · 대화
# ═════════════════════════════════════════════════════════

func collect_orb(o: Prop) -> void:
	Game.orbs += 1
	Game.orbs_total += 1
	Sound.play("orb", -8, _orb_pitch, 0.0)
	_orb_pitch = minf(_orb_pitch + 0.04, 1.8)
	_orb_t = 0.6
	fx_add.burst(o.global_position, 4, Color(0.6, 0.95, 1.0), 30, 0.3, 1.5, 0)
	if Game.orbs_total % 30 == 0 and Game.hp < Game.max_hp:
		Game.hp += 1
		Sound.play("heal")
		fx_add.burst(player.global_position + Vector2(0, -8), 16, Color(1.0, 0.5, 0.6), 50, 0.7, 2.0, -30)
	Game.state_changed.emit()


func touch_shrine(s: Prop) -> void:
	var fresh: bool = not s.data.lit or Game.hp < Game.max_hp or Game.checkpoint.distance_to(s.global_position) > 4
	if not fresh: return
	for o in shrines: o.data.lit = false
	s.data.lit = true
	Game.checkpoint = s.global_position
	Game.hp = Game.max_hp
	Game.save_game()
	Sound.play("shrine", -2)
	fx_add.ring(s.global_position + Vector2(0, -8), 30, Color(1.0, 0.85, 0.5, 0.9), 0.6, 2.0)
	fx_add.burst(s.global_position + Vector2(0, -8), 24, Color(1.0, 0.85, 0.5), 60, 0.9, 2.0, -20)
	Game.state_changed.emit()
	main.toast("저장했어요")
	if not Game.flags.has("first_shrine"):
		Game.flags["first_shrine"] = true
		say("first_shrine")


func talk(npc: Prop) -> void:
	var key: String = npc.data.talk
	if key == "beryl" and Game.flags.has("beryl"): key = "beryl_again"
	Game.flags[npc.data.talk] = true
	Sound.play("meow", -4, 0.8 if npc.data.get("elder", false) else 1.1)
	say(key)


func collect_memory(m: Prop) -> void:
	var id: int = m.data.id
	if Game.memories.has(id): return
	Game.memories.append(id)
	Sound.play("memory")
	Game.hitstop(0.2)
	fx_add.burst(m.global_position, 40, Color(0.45, 0.7, 1.0), 120, 1.2, 2.5, -10)
	fx_add.ring(m.global_position, 40, Color(0.6, 0.8, 1.0), 0.8, 3.0)
	main.memory_scene(id, func():
		say("after_mem%d" % id)
		Game.save_game())


func gain_ability(a: Prop) -> void:
	var id: String = a.data.id
	if id == "double": Game.has_double = true
	else: Game.has_dash = true
	Sound.play("ability")
	Game.hitstop(0.25)
	Game.kick(4.0)
	fx_add.burst(a.global_position, 50, Color(0.45, 0.75, 1.0), 140, 1.0, 2.5, 0)
	fx_add.ring(a.global_position, 50, Color(0.7, 0.9, 1.0), 0.7, 3.0)
	main.flash(Color(0.6, 0.85, 1.0), 0.5)
	main.ability_card(id)
	Game.state_changed.emit()
	await get_tree().create_timer(1.6).timeout
	say("feather" if id == "double" else "claw")


func say(key: String, cb: Callable = Callable()) -> void:
	main.dialog(Story.DIALOG[key], cb)


# ═════════════════════════════════════════════════════════
# 보스
# ═════════════════════════════════════════════════════════

func _start_boss() -> void:
	boss_state = "fight"
	gate = StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(18, 16 * T)
	cs.shape = sh
	cs.position = Vector2(boss_area.position.x - 9, boss_area.get_center().y)
	gate.add_child(cs)
	add_child(gate)
	Sound.play("gate")
	Game.kick(5.0)
	Sound.music("")
	boss.visible = true
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.hp = boss.max_hp
	boss.phase = 1
	boss.state = "intro"
	boss.global_position = spots["K"][0]
	Sound.play("roar", 2)
	say("boss_intro", func():
		main.area_title("망각의 곰", "잊힘을 지키는 자")
		Sound.music("boss", 0.5)
		boss.start())


func _on_boss_defeated() -> void:
	boss_state = "done"
	Game.boss_down = true
	Game.hitstop(0.5)
	Game.kick(12.0)
	Sound.play("roar", 0, 0.7)
	main.flash(Color.WHITE, 0.7)
	boss_bar.emit("", 0, 1)
	var pos := boss.global_position + Vector2(0, -24)
	for k in 6:
		await get_tree().create_timer(0.15).timeout
		fx.burst(pos + Vector2(randf_range(-16, 16), randf_range(-16, 16)), 20, Color(0.5, 0.4, 0.7), 120, 0.8, 2.0)
		fx_add.burst(pos, 20, Color(0.8, 0.6, 1.0), 80, 1.4, 2.5, -40)
		Sound.play("boom", -4)
	for k in 30:
		var o := _prop("orb", pos)
		o._vel = Vector2(randf_range(-140, 140), randf_range(-200, -60))
	say("boss_down", func():
		var tw := boss.create_tween()
		tw.tween_property(boss, "modulate:a", 0.0, 1.0)
		tw.tween_callback(boss.queue_free)
		if is_instance_valid(gate): gate.queue_free()
		Sound.music("dreams")
		if memory_props.has(3) and is_instance_valid(memory_props[3]): memory_props[3].set_active(true))


func reset_boss() -> void:
	if boss_state != "fight": return
	boss_state = "wait"
	if is_instance_valid(gate): gate.queue_free()
	boss.visible = false
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss_bar.emit("", 0, 1)
	waves.clear()
	rocks.clear()


func on_player_dead() -> void:
	Game.deaths += 1
	Sound.play("meow_sad")
	fx_add.burst(player.global_position + Vector2(0, -8), 40, Color(0.6, 0.8, 1.0), 80, 1.4, 2.4, -30)
	main.on_death()


func respawn() -> void:
	reset_boss()
	var at: Vector2 = Game.checkpoint if Game.checkpoint != Vector2.ZERO else spots["P"][0]
	player.revive(at)
	_cam_target = at
	lumi.global_position = at + Vector2(-14, -24)


# ═════════════════════════════════════════════════════════
# 오버레이 그리기 (투사체 · 충격파 · 낙석 경고 · 안내 키캡)
# ═════════════════════════════════════════════════════════

func _draw_overlay(o: CanvasItem) -> void:
	for s in shots:
		o.draw_texture_rect(Art.soft_tex, Rect2(s.p - Vector2(6, 6), Vector2(12, 12)), false, Color(0.5, 1.0, 0.4, 0.5))
		o.draw_circle(s.p, 2.5, Color(0.6, 0.95, 0.35))
	for w in waves:
		var k: float = w.t / 1.3
		o.draw_rect(Rect2(w.x - 3, w.y - 10 + k * 4, 6, 10 - k * 4), Color(0.95, 0.8, 0.55, 1.0 - k))
	for r in rocks:
		if r.t < r.warn:
			var gy := _ground_below(r.x, boss_area.position.y)
			var a: float = 0.3 + 0.4 * sin(r.t * 20.0)
			o.draw_set_transform(Vector2(r.x, gy), 0.0, Vector2(1, 0.3))
			o.draw_circle(Vector2.ZERO, 7, Color(0.9, 0.2, 0.3, a))
			o.draw_set_transform(Vector2.ZERO)
		else:
			o.draw_circle(Vector2(r.x, r.y), 5, Color(0.45, 0.45, 0.55))
			o.draw_circle(Vector2(r.x - 1, r.y - 1), 3, Color(0.6, 0.6, 0.7))


func _ground_below(x: float, from_y: float) -> float:
	var cx := int(x / T)
	for y in range(int(from_y / T), H):
		if ch(cx, y) == "#" or ch(cx, y) == "=": return y * T
	return H * T


## 키캡 (월드 글씨: Galmuri9를 10px로 → 카메라 4배 = 화면 40px, 선명)
## 밤 색조(CanvasModulate)에 곱해져 어두워지므로 미리 밝게 보정한 색을 쓴다
const FS := 10


func draw_key(ci: CanvasItem, at: Vector2, key: String, text: String = "", a: float = 1.0) -> float:
	var f := Art.font_px
	var kw := maxf(12.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x + 6)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x if text != "" else 0.0
	var total: float = kw + (tw + 4.0 if text != "" else 0.0)
	var x0: float = round(at.x - total / 2.0)
	var y0: float = round(at.y)
	ci.draw_rect(Rect2(x0, y0 - 11, kw, 13), Color(2.6, 2.25, 1.6, 0.95 * a))
	ci.draw_rect(Rect2(x0, y0 + 2, kw, 1), Color(1.5, 1.4, 1.2, a))
	ci.draw_string(f, Vector2(x0 + 3, y0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(0.1, 0.12, 0.2, a))
	if text != "":
		ci.draw_string_outline(f, Vector2(x0 + kw + 4, y0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 2, Color(0.02, 0.03, 0.07, 0.85 * a))
		ci.draw_string(f, Vector2(x0 + kw + 4, y0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(2.7, 2.35, 1.6, a))
	return total


func draw_hint(ci: CanvasItem, data: Dictionary, a: float) -> void:
	var keys: Array = data["keys"]
	var f := Art.font_px
	var widths := []
	for k in keys: widths.append(maxf(12.0, f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x + 6))
	var tw: float = f.get_string_size(data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var total := 0.0
	for w in widths: total += w + 2
	var x: float = round(-total / 2.0)
	for i in keys.size():
		ci.draw_rect(Rect2(x, -27, widths[i], 13), Color(2.6, 2.25, 1.6, 0.95 * a))
		ci.draw_rect(Rect2(x, -14, widths[i], 1), Color(1.5, 1.4, 1.2, a))
		ci.draw_string(f, Vector2(x + 3, -16), keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(0.1, 0.12, 0.2, a))
		x += widths[i] + 2
	var tx: float = round(-tw / 2.0)
	ci.draw_string_outline(f, Vector2(tx, -1), data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 2, Color(0.02, 0.03, 0.07, 0.9 * a))
	ci.draw_string(f, Vector2(tx, -1), data.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, Color(2.7, 2.35, 1.6, a))
