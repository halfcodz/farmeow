extends Node2D
## 넓은 농장 월드 (61x37칸). 가운데 9x9 밭 + 사방 길 + 숲·연못·헛간.
## 정적인 땅은 한 장의 텍스처로 구워 두고, 밭·캐릭터·효과만 매 프레임 그린다.

signal tile_clicked(i: int, button: int, shift: bool)
signal tile_hovered(i: int)

const T := 16
const WX := 61
const WY := 37
const OFF := Vector2(25, 13)     # 밭 (0,0) 칸의 월드 칸 좌표 (11x11 밭이 월드 한가운데)
const G := Sim.G
const CF := Sim.CF

## 원작 도트 대신 Kenney Tiny Farm 성장 단계를 쓰는 작물 (환경 에셋과 톤 맞춤)
const KENNEY_CROP := {"carrot": [4, 5, 5, 6], "cabbage": [52, 53, 53, 54], "corn": [28, 29, 29, 30], "tomato": [40, 41, 41, 42]}

var sim: Sim
var hover := -1
var selected := -1
var tool := {}
var guide := {}
var time := 0.0
var shake := 0.0
var ground: ImageTexture
var _animals: Array = []
var _grass_var: Array = []
var _flies: Array = []
var _parts: Array = []
var _house_flash := 0.0
var _step_t := 0.0
var _meow_t := 8.0
var _bubbles := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 11
	for i in Sim.N: _grass_var.append(_rng.randi() % 100)
	_bake_ground()
	var kinds := [[120, "sheep"], [121, "cow"], [122, "chicken"], [122, "chicken"], [0, "chick"], [0, "chick"], [121, "cow"], [120, "sheep"]]
	for k in kinds:
		_animals.append({"tile": k[0], "kind": k[1], "pos": _pasture_spot(), "goal": Vector2.ZERO, "t": _rng.randf() * 3.0, "flip": false})
	_rng.randomize()
	for k in 60:
		_flies.append({"p": Vector2(_rng.randf() * WX * T, _rng.randf() * WY * T), "ph": _rng.randf() * TAU})


func field_center_px() -> Vector2:
	return (OFF + Vector2(CF, CF)) * T


func world_size_px() -> Vector2:
	return Vector2(WX, WY) * T


func fpos(p: Vector2) -> Vector2:
	return (p + OFF) * T


func _tile_px(i: int) -> Vector2:
	return (OFF + Vector2(Sim.tx(i), Sim.ty(i))) * T


func _tc(i: int) -> Vector2:
	return _tile_px(i) + Vector2(8, 8)


func _pasture_spot() -> Vector2:
	var zones := [Rect2(OFF.x + G + 1, OFF.y + 1, 4, 2), Rect2(OFF.x - 6, OFF.y + G, 5, 3), Rect2(OFF.x - 6, OFF.y - 3, 4, 2), Rect2(OFF.x + G + 1, OFF.y + G, 4, 3)]
	var z: Rect2 = zones[_rng.randi() % zones.size()]
	return (z.position + Vector2(_rng.randf() * z.size.x, _rng.randf() * z.size.y)) * T


# ═════════════════════════════════════════════════════════
# 땅 굽기
# ═════════════════════════════════════════════════════════

func _img(sheet_path: String) -> Image:
	var im: Image = Data.t(sheet_path).get_image()
	if im.is_compressed(): im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _bake_ground() -> void:
	var town := _img("free/kenney_tiny_town/tilemap_packed.png")
	var farm := _img("free/kenney_tiny_farm/tilemap_packed.png")
	var battle := _img("free/kenney_tiny_battle/tilemap_packed.png")
	var img := Image.create(WX * T, WY * T, false, Image.FORMAT_RGBA8)
	var put := func(src: Image, idx: int, cols: int, x: int, y: int, blend: bool) -> void:
		var r := Rect2i((idx % cols) * T, (idx / cols) * T, T, T)
		if blend: img.blend_rect(src, r, Vector2i(x * T, y * T))
		else: img.blit_rect(src, r, Vector2i(x * T, y * T))
	var occupied := {}
	var fx0 := int(OFF.x)
	var fy0 := int(OFF.y)
	for y in WY:
		for x in WX:
			var v := _rng.randi() % 100
			put.call(town, 0 if v < 78 else (1 if v < 94 else 2), 12, x, y, false)
	for y in WY:
		for x in WX:
			var lx := x - fx0
			var ly := y - fy0
			if lx >= 0 and ly >= 0 and lx < G and ly < G: continue
			if absi(lx - Sim.C) <= 1 and (ly < 0 or ly >= G):
				put.call(town, [24, 25, 26][lx - Sim.C + 1], 12, x, y, false)
				occupied[Vector2i(x, y)] = true
			elif absi(ly - Sim.C) <= 1 and (lx < 0 or lx >= G):
				put.call(town, [13, 25, 37][ly - Sim.C + 1], 12, x, y, false)
				occupied[Vector2i(x, y)] = true
	for y in range(fy0 - 4, fy0 + G + 4):
		for x in range(fx0 - 7, fx0 + G + 7):
			occupied[Vector2i(x, y)] = true
	var barn := [[90, 91, 92], [102, 103, 104], [114, 115, 116]]
	for yy in 3:
		for xx in 3:
			put.call(farm, barn[yy][xx], 12, fx0 + G + 2 + xx, fy0 - 3 + yy, true)
	for d in [[96, G + 5, -1], [97, G + 6, -1], [85, G + 1, -1], [74, G + 6, 0], [72, -3, -2], [73, -2, -2], [83, -4, G + 1], [83, -3, G + 2], [98, G + 2, G + 1], [99, G + 3, G + 1], [84, -5, -1], [86, G + 1, G + 2], [89, -6, 0], [77, G + 4, G + 2]]:
		put.call(farm, d[0], 12, fx0 + d[1], fy0 + d[2], true)
	for k in 4:
		for tries in 40:
			var px := _rng.randi_range(2, WX - 4)
			var py := _rng.randi_range(2, WY - 4)
			var ok := true
			for yy in range(-1, 3):
				for xx in range(-1, 3):
					if occupied.has(Vector2i(px + xx, py + yy)): ok = false
			if not ok: continue
			for yy in 2:
				for xx in 2:
					put.call(battle, [[3, 4], [21, 22]][yy][xx], 18, px + xx, py + yy, false)
					occupied[Vector2i(px + xx, py + yy)] = true
			break
	var trees := [3, 4, 15, 16, 27, 28, 5, 4, 16]
	for y in WY:
		for x in WX:
			if occupied.has(Vector2i(x, y)): continue
			var dx := (x - (fx0 + CF)) / 1.6
			var dy := float(y - (fy0 + CF))
			var dist := sqrt(dx * dx + dy * dy)
			var p := clampf((dist - 9.0) / 10.0, 0.0, 0.85)
			var r := _rng.randf()
			if r < p * 0.75:
				put.call(town, trees[_rng.randi() % trees.size()], 12, x, y, true)
			elif r < p * 0.75 + 0.03:
				put.call(town, 29, 12, x, y, true)
			elif r < p * 0.75 + 0.06:
				put.call(farm, [39, 77, 89, 83][_rng.randi() % 4], 12, x, y, true)
	ground = ImageTexture.create_from_image(img)


# ═════════════════════════════════════════════════════════
# 입력
# ═════════════════════════════════════════════════════════

func tile_at(local: Vector2) -> int:
	var c := local / T - OFF
	var x := int(floor(c.x))
	var y := int(floor(c.y))
	if x < 0 or y < 0 or x >= G or y >= G: return -1
	return y * G + x


func cat_at(local: Vector2) -> Dictionary:
	for c in sim.s.cats:
		if c.alive and sim.cat_rt.has(c.uid):
			if (fpos(sim.cat_rt[c.uid].pos) - Vector2(0, 6)).distance_to(local) < 7: return c
	return {}


func _unhandled_input(e: InputEvent) -> void:
	if sim == null: return
	if e is InputEventMouseMotion:
		var i := tile_at(get_local_mouse_position())
		if i != hover:
			hover = i
			tile_hovered.emit(i)
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
		var lp := get_local_mouse_position()
		var i := tile_at(lp)
		if e.button_index == MOUSE_BUTTON_LEFT and tool.is_empty():
			var c := cat_at(lp)
			var ripe := i >= 0 and sim.crop_ripe(sim.s.tiles[i])
			if not c.is_empty() and not ripe:
				_bubbles[c.uid] = 1.2
				Sound.play("meow", 0.15)
				get_viewport().set_input_as_handled()
				return
		if i >= 0:
			tile_clicked.emit(i, e.button_index, e.shift_pressed)
			get_viewport().set_input_as_handled()


# ═════════════════════════════════════════════════════════
# 이벤트 → 효과·소리
# ═════════════════════════════════════════════════════════

func _burst(pos: Vector2, n: int, col: Color, speed: float = 30.0, life: float = 0.5, size: float = 1.0) -> void:
	if _parts.size() > 600: return
	for k in n:
		var a := _rng.randf() * TAU
		_parts.append({"pos": pos, "v": Vector2.from_angle(a) * _rng.randf_range(speed * 0.4, speed) + Vector2(0, -speed * 0.3), "t": 0.0, "life": life * _rng.randf_range(0.7, 1.2), "c": col, "sz": size, "g": 60.0})


func _text(pos: Vector2, text: String, col: Color, size: int = 8, life: float = 0.9, icon: Texture2D = null) -> void:
	_parts.append({"pos": pos, "text": text, "t": 0.0, "life": life, "c": col, "fs": size, "icon": icon, "v": Vector2(0, -16)})


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"fx":
			match d.k:
				"harvest":
					_text(_tc(d.i) + Vector2(0, -6), "+%d" % d.n, Color("#fff4dc"), 8, 0.9, Data.crop_icon(d.id))
					_burst(_tc(d.i), 6, Color("#ffe98a"), 40, 0.5)
					Sound.play("pop", 0.15, -4.0)
				"dust":
					_burst(_tc(d.i) + Vector2(0, 4), 7, Color("#c9a27a"), 24, 0.4)
				"star":
					_burst(_tc(d.i), 10, Color("#ffd447"), 45, 0.6)
				"text":
					_text(_tc(d.i) + Vector2(0, -8), d.text, Color("#9ef07a"))
				"househit":
					_house_flash = 0.15
					_burst(fpos(Vector2(CF, CF)), 3, Color("#c9a27a"), 30, 0.4)
				"wilt":
					_burst(_tc(d.i), 8, Color("#6b5a3a"), 30, 0.5)
				"thit":
					_burst(_tc(d.i) + Vector2(0, -4), 2, Color("#8fd05a"), 20, 0.3)
					Sound.play("thit", 0.2, -10.0)
				"boom", "slam", "dark", "poison", "freeze":
					var col := Color("#ffb347")
					match d.k:
						"slam": col = Color("#c9a27a")
						"dark": col = Color("#7b4bcc")
						"poison": col = Color("#8fd05a")
						"freeze": col = Color("#bfe9ff")
					if d.get("color", "") == "magic": col = Color("#b48cff")
					var pos: Vector2 = d.pos if d.has("pos") else Vector2(Sim.tx(d.i) + 0.5, Sim.ty(d.i) + 0.5)
					_parts.append({"ring": true, "pos": fpos(pos), "r": float(d.get("r", 1.0)) * T, "t": 0.0, "life": 0.35, "c": col})
					if d.k == "boom": _burst(fpos(pos), 10, col, 50, 0.4, 1.5)
					if d.k == "freeze": Sound.play("freeze", 0.1, -6.0)
				"coins":
					_text(fpos(Vector2(CF, CF - 1.3)), "+" + Data.fmt(d.v), Color("#ffd447"), 8, 1.1, Data.town_tile(93))
		"hit":
			var p := fpos(d.pos) + Vector2(0, -6)
			if d.crit:
				_burst(p, 10, Color("#fff27a"), 60, 0.35, 1.5)
				Sound.play("crit", 0.1, -3.0)
			else:
				_burst(p, 3, Color(1, 1, 1, 0.9), 35, 0.25)
				if String(d.src) in ["sword", "guard", "captain", "farmer", "merchant", "chef", "sprinkler", "engineer"]:
					Sound.play("slash", 0.15, -6.0)
				else:
					Sound.play("hit", 0.2, -12.0)
		"kill":
			var zd: Dictionary = Data.zombie_by_id[d.type]
			_burst(fpos(d.pos) + Vector2(0, -6), 60 if d.boss else 14, Color(zd.color), 90 if d.boss else 55, 0.6, 1.5)
			if float(d.coins) >= 1.0 and _rng.randf() < 0.6:
				_text(fpos(d.pos) + Vector2(0, -12), "+" + Data.fmt(d.coins), Color("#ffd447"), 8, 0.7)
			Sound.play("coin", 0.2, -14.0)
		"golden_kill":
			_burst(fpos(d.pos), 80, Color("#ffd447"), 110, 1.2, 2.0)
			_text(fpos(d.pos) + Vector2(0, -20), "+" + Data.fmt(d.coins), Color("#ffd447"), 14, 1.6, Data.town_tile(93))
			Sound.play("jackpot")
		"golden":
			Sound.play("rare")
		"jackpot":
			var lv := int(d.level)
			_burst(_tc(d.i), 30 if lv == 1 else 90, Color("#ffd447"), 70 if lv == 1 else 130, 1.0, 1.5)
			_text(_tc(d.i) + Vector2(0, -14), "대박!" if lv == 1 else "초대박!!", Color("#ffcf4a") if lv == 1 else Color("#ff7ac6"), 14 if lv == 1 else 20, 1.5)
			Sound.play("bigwin" if lv == 1 else "jackpot")
			if lv == 2: shake = maxf(shake, 4.0)
		"boss_spawn":
			Sound.play("boss")
		"spawn":
			_burst(fpos(d.pos), 8, Color("#6b4a2b"), 30, 0.5, 1.5)
			Sound.play("zgrowl", 0.2, -14.0)
		"cat_down":
			Sound.play("meow_sad")
		"shake":
			if Settings.screen_shake:
				shake = maxf(shake, float(d.amount))


# ═════════════════════════════════════════════════════════
# 프레임
# ═════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	time += delta
	shake = maxf(0.0, shake - delta * 12.0)
	_house_flash = maxf(0.0, _house_flash - delta)
	for p in _parts:
		p.t += delta
		if p.has("v"):
			p.pos += p.v * delta
			if p.has("g"): p.v.y += p.g * delta
			else: p.v *= 0.92
	_parts = _parts.filter(func(p): return p.t < p.life)
	for k in _bubbles.keys():
		_bubbles[k] -= delta
		if _bubbles[k] <= 0: _bubbles.erase(k)
	if sim != null:
		var daylike: bool = sim.s.phase == "day" or sim.s.phase == "dawn"
		for a in _animals:
			a.t -= delta
			if a.t <= 0.0:
				a.t = _rng.randf_range(2.0, 6.0)
				a.goal = a.pos + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-16, 16))
			var dd: Vector2 = a.goal - a.pos
			if a.goal != Vector2.ZERO and dd.length() > 1.0 and daylike:
				a.pos += dd.normalized() * 8.0 * delta
				a.flip = dd.x < 0
		_step_t -= delta
		var walking := false
		for c in sim.s.cats:
			if c.alive and sim.cat_rt.has(c.uid) and sim.cat_rt[c.uid].anim == "walk": walking = true
		if walking and _step_t <= 0.0 and not Game.paused and Game.modal_pause == 0:
			_step_t = 0.32 / float(sim.s.speed)
			Sound.play("step", 0.25, -16.0)
		_meow_t -= delta
		if _meow_t <= 0.0 and daylike and not Game.paused and Game.modal_pause == 0:
			_meow_t = _rng.randf_range(10.0, 22.0)
			var al := sim.alive_cats()
			if al.size() > 0:
				var c: Dictionary = al[_rng.randi() % al.size()]
				_bubbles[c.uid] = 1.4
				Sound.play("meow", 0.2, -8.0)
	position = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake if shake > 0.1 else Vector2.ZERO
	queue_redraw()


# ═════════════════════════════════════════════════════════
# 그리기
# ═════════════════════════════════════════════════════════

func _draw() -> void:
	if sim == null: return
	draw_texture(ground, Vector2.ZERO)
	_draw_field()
	_draw_house()
	_draw_gates()
	_draw_entities()
	_draw_shots()
	_draw_fx()
	_draw_overlay()


func _shadow(p: Vector2, w: float = 5.0) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)


func crop_tex(id: String, stage: int) -> Texture2D:
	if KENNEY_CROP.has(id):
		return Data.farm_tile(KENNEY_CROP[id][clampi(stage, 0, 3)])
	return Data.crop_stage(id, stage)


## 밭: 배경과 같은 Kenney 풀 · 흙길 · 고랑으로 자동 연결 (울타리 없음)
func _crop_at(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= G or y >= G: return false
	return sim.s.tiles[y * G + x].kind == "crop"


func _path_tile(x: int, y: int) -> int:
	var dx := x - Sim.C
	var dy := y - Sim.C
	if absi(dx) <= 1 and absi(dy) <= 1: return 25
	if absi(dx) <= 1: return [24, 25, 26][dx + 1]
	return [13, 25, 37][dy + 1]


func _draw_field() -> void:
	var plots := "sprites/terrain/plots.png"
	var wet_pos := []
	for c in sim.s.cats:
		if c.alive and c.job == "sprinkler" and sim.cat_rt.has(c.uid): wet_pos.append(sim.cat_rt[c.uid].pos)
	for i in Sim.N:
		var x := Sim.tx(i)
		var y := Sim.ty(i)
		var p := _tile_px(i)
		var t: Dictionary = sim.s.tiles[i]
		var zone := Data.zone_of(x, y)
		if zone == "house": continue
		# 바탕: 배경 풀 위에 길목은 흙길
		if Data.on_lane(x, y):
			draw_texture(Data.town_tile(_path_tile(x, y)), p)
		if not t.open:
			draw_rect(Rect2(p, Vector2(T, T)), Color(0.1, 0.18, 0.08, 0.22))
			if _grass_var[i] % 5 == 0 and not Data.on_lane(x, y):
				draw_texture(Data.town_tile(17), p, Color(1, 1, 1, 0.7))
			var uc := sim.unlock_cost(i)
			if uc > 0 and hover == i:
				draw_texture(Data.battle_tile(193), p)
			elif uc > 0 and sim.s.phase == "day" and float(sim.s.coins) >= uc:
				draw_rect(Rect2(p + Vector2(7, 7), Vector2(2, 2)), Color(1, 0.9, 0.4, 0.5 + 0.3 * sin(time * 3.0)))
			continue
		if t.kind == "crop":
			var wet := false
			for sp in wet_pos:
				if (sp as Vector2).distance_to(Vector2(x + 0.5, y + 0.5)) <= 2.5: wet = true
			var up := _crop_at(x, y - 1)
			var dn := _crop_at(x, y + 1)
			var k := 3 if not up and not dn else (0 if not up else (2 if not dn else 1))
			draw_texture(Data.frame(plots, k, 16, 16, 1 if wet else 0), p)
			var g := clampf(float(t.prog) / sim.crop_grow_time(t.id), 0.0, 1.0)
			var stage := 3 if g >= 1.0 else int(g * 3.0)
			var bob := Vector2(0, -1) if g >= 1.0 and fmod(time * 2.0 + i, 2.0) < 1.0 else Vector2.ZERO
			draw_texture(crop_tex(t.id, stage), p + bob)
			if g >= 1.0:
				draw_texture(Data.t("sprites/terrain/sparkle.png"), p + Vector2(0, -2), Color(1, 1, 1, 0.5 + 0.5 * sin(time * 5.0 + i)))
			else:
				# 최소 표시: 무엇을 심었는지 작은 아이콘 + 얇은 성장 막대
				draw_texture_rect(Data.crop_icon(t.id), Rect2(p + Vector2(11, 0), Vector2(5, 5)), false)
				draw_rect(Rect2(p + Vector2(2, 15), Vector2(12, 1)), Color(0, 0, 0, 0.3))
				draw_rect(Rect2(p + Vector2(2, 15), Vector2(12 * g, 1)), Color("#9ef07a"))
		elif t.kind == "" and not Data.on_lane(x, y):
			# 열린 빈 땅: 아주 옅은 테두리로만 표시
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(T - 2, T - 2)), Color(1, 1, 0.85, 0.12), false, 1.0)


func _draw_house() -> void:
	var p := fpos(Vector2(Sim.C - 1, Sim.C - 1))
	draw_texture(Data.t("sprites/terrain/house_kenney.png"), p, Color(1, 0.6, 0.6) if _house_flash > 0 else Color.WHITE)
	if sim.s.phase == "night":
		var k := clampf(sim.house_hp / maxf(1.0, sim.house_max), 0.0, 1.0)
		draw_rect(Rect2(p + Vector2(4, -5), Vector2(40, 3)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(p + Vector2(5, -4), Vector2(38 * k, 1)), Color("#ff6b6b") if k < 0.35 else Color("#8fd05a"))


## 사방 좀비 구멍: 황혼·밤에 위협도만큼 붉게 빛난다 (글 대신 빛으로 알려 준다)
func _draw_gates() -> void:
	var threat: Dictionary = sim.plan.get("threat", {}) if sim.s.phase in ["dusk", "night"] else {}
	var gp := {"N": Vector2(CF, -1.6), "S": Vector2(CF, G + 1.6), "W": Vector2(-1.6, CF), "E": Vector2(G + 1.6, CF)}
	for d in Data.DIRS:
		var p := fpos(gp[d])
		var v := float(threat.get(d, 0.0))
		draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 9, Color(0.18, 0.12, 0.1, 0.55))
		if v > 0.01:
			var pulse := 0.5 + 0.5 * sin(time * (4.0 + v * 8.0))
			draw_circle(Vector2.ZERO, 6 + v * 16, Color(0.95, 0.15, 0.2, (0.15 + v * 0.6) * (0.5 + pulse * 0.5)))
		draw_set_transform(Vector2.ZERO)


func _draw_entities() -> void:
	var list := []
	for i in Sim.N:
		if sim.s.tiles[i].kind == "turret":
			list.append({"y": Sim.ty(i) + 0.9, "k": "turret", "i": i})
	for c in sim.s.cats:
		if c.alive and sim.cat_rt.has(c.uid):
			list.append({"y": (sim.cat_rt[c.uid].pos as Vector2).y, "k": "cat", "c": c})
	for z in sim.zombies:
		if z.alive:
			list.append({"y": (z.pos as Vector2).y + (5.0 if z.flying else 0.0), "k": "zombie", "z": z})
	if sim.s.phase != "night":
		for a in _animals:
			list.append({"y": a.pos.y / T - OFF.y, "k": "animal", "a": a})
	list.sort_custom(func(a, b): return a.y < b.y)
	for e in list:
		match e.k:
			"turret": _draw_turret(e.i)
			"cat": _draw_cat(e.c)
			"zombie": _draw_zombie(e.z)
			"animal": _draw_animal(e.a)


func _draw_turret(i: int) -> void:
	var t: Dictionary = sim.s.tiles[i]
	var p := _tile_px(i)
	var path := "sprites/turrets/%s.png" % t.id
	var f := 0
	var sq := Vector2.ONE
	if t.wilted: f = 4
	elif not sim.turret_ready(t): f = 3
	elif float(t.get("fire", 0.0)) > 0.0:
		f = 2
		sq = Vector2(1.12, 0.9)
		t.fire = float(t.fire) - get_process_delta_time()
	else: f = int(time * 2.0 + i) % 2
	_shadow(p + Vector2(8, 14), 5.5)
	draw_set_transform(p + Vector2(8, 16), 0.0, sq)
	draw_texture(Data.frame(path, f), Vector2(-8, -16))
	draw_set_transform(Vector2.ZERO)
	for k in int(t.stars):
		draw_rect(Rect2(p + Vector2(1 + k * 4, 0), Vector2(3, 3)), Color("#2b2038"))
		draw_rect(Rect2(p + Vector2(2 + k * 4, 1), Vector2(1, 1)), Color("#ffd447"))
	if sim.s.phase == "night" and not t.wilted:
		var mx := sim.turret_max_hp(t)
		if float(t.hp) < mx:
			draw_rect(Rect2(p + Vector2(2, 15), Vector2(12, 1)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(p + Vector2(2, 15), Vector2(12 * float(t.hp) / mx, 1)), Color("#8fd05a"))


func _draw_cat(c: Dictionary) -> void:
	var rt: Dictionary = sim.cat_rt[c.uid]
	var base := fpos(rt.pos)
	var p := base - Vector2(8, 13)
	var f := 0
	var hop := 0.0
	match rt.anim:
		"walk":
			f = 2 + int(time * 8.0 + int(c.uid)) % 4
			hop = absf(sin(time * 12.0 + int(c.uid)))
		"act": f = 6 + int(time * 8.0) % 2
		"down": f = 8
		_: f = int(time * 2.0 + int(c.uid)) % 2
	if c.down: f = 8
	_shadow(base + Vector2(0, 2), 4.5)
	var tex := Data.cat_frame(c.job, int(c.fur), f)
	var mod := Color(0.85, 0.85, 1.0) if float(c.full) < 30.0 else Color.WHITE
	p.y -= hop
	if rt.flip:
		draw_set_transform(p + Vector2(16, 0), 0.0, Vector2(-1, 1))
		draw_texture(tex, Vector2.ZERO, mod)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(tex, p, mod)
	if int(c.rarity) > 0:
		draw_rect(Rect2(p + Vector2(7, -2), Vector2(2, 2)), Color(Data.rarities[int(c.rarity)].color))
	if _bubbles.has(c.uid):
		var bp := p + Vector2(10, -8 - (1.4 - _bubbles[c.uid]) * 4)
		draw_texture_rect(Data.battle_tile(195), Rect2(bp, Vector2(8, 8)), false, Color(1, 1, 1, minf(1.0, _bubbles[c.uid] * 2)))
	if sim.s.phase == "night" and not c.down:
		var k := float(c.hp) / maxf(1.0, sim.cat_max_hp(c))
		if k < 0.999:
			draw_rect(Rect2(p + Vector2(3, -3), Vector2(10, 1)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(p + Vector2(3, -3), Vector2(10 * k, 1)), Color("#7ad4ff"))


func _draw_zombie(z: Dictionary) -> void:
	var big := int(z.size) == 2
	var sz := 32 if big else 16
	var pos := fpos(z.pos)
	if sim.burrowed(z):
		draw_circle(pos, 4, Color("#6b4a2b"))
		draw_circle(pos + Vector2(-2, -1), 2, Color("#8f6440"))
		return
	_shadow(pos + Vector2(0, 1), 9.0 if big else 4.5)
	var lift := 0.0
	if z.flying: lift = 5 + sin(time * 6.0 + int(z.id)) * 1.5
	var f := int(float(z.anim)) % 4
	var mod := Color.WHITE
	if float(z.frozen) > 0.0: mod = Color(0.6, 0.85, 1.0)
	elif float(z.slow_t) > 0.0: mod = Color(0.8, 0.9, 1.0)
	elif float(z.burn_t) > 0.0: mod = Color(1.0, 0.75, 0.6)
	elif float(z.poison_t) > 0.0: mod = Color(0.8, 1.0, 0.7)
	if z.get("golden", false): mod = Color(1.5, 1.25, 0.4)
	if float(z.hit) > 0.0:
		f = 4
		mod = Color(2.2, 2.2, 2.2)
	if z.phase: mod.a = 0.6 + 0.2 * sin(time * 4.0)
	var squash := Vector2(1.0 + float(z.hit) * 1.2, 1.0 - float(z.hit) * 1.0)
	var flip := -1.0 if (z.v as Vector2).x > 0 else 1.0
	draw_set_transform(pos - Vector2(0, lift), 0.0, Vector2(squash.x * flip, squash.y))
	draw_texture(Data.zombie_frame(z.type, f), Vector2(-sz / 2.0, -sz + 3), mod)
	draw_set_transform(Vector2.ZERO)
	var k := float(z.hp) / maxf(1.0, float(z.max))
	if k < 0.999 or big:
		var w := 26.0 if big else 10.0
		draw_rect(Rect2(pos + Vector2(-w / 2, -sz + 1 - lift), Vector2(w, 2 if big else 1)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(pos + Vector2(-w / 2, -sz + 1 - lift), Vector2(w * k, 2 if big else 1)), Color("#ff5d73") if big else Color("#ffb347"))
	if z.type == "bossDark":
		draw_arc(pos, 2.5 * T, 0, TAU, 48, Color(0.4, 0.2, 0.7, 0.25 + 0.1 * sin(time * 3.0)), 1.0)


func _draw_animal(a: Dictionary) -> void:
	var tex: Texture2D
	if a.kind == "chick":
		tex = Data.frame("free/chick/chick_24x24.png", int(time * 4.0) % 2, 24, 24)
	else:
		tex = Data.farm_tile(a.tile)
	var p: Vector2 = a.pos - Vector2(8, 12)
	_shadow(a.pos + Vector2(0, 3), 5)
	if a.flip:
		draw_set_transform(p + Vector2(16, 0), 0.0, Vector2(-1, 1))
		draw_texture(tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture(tex, p)


func _draw_shots() -> void:
	for sh in sim.shots:
		var p := fpos(sh.pos)
		match sh.kind:
			"bullet":
				draw_circle(p, 2.0, Color("#2b2038"))
				draw_circle(p, 1.3, sh.color)
			"arrow":
				var z: Dictionary = sh.z
				var dir := ((z.pos as Vector2) - (sh.pos as Vector2)).normalized()
				draw_line(p - dir * 5, p, Color("#e8e0c8"), 1.0)
			"magic":
				draw_circle(p, 2.4, Color(0.7, 0.55, 1.0, 0.8))
				draw_circle(p, 1.0, Color.WHITE)
			"lob", "egg":
				var h := float(sh.get("h", 0.0)) * T
				draw_circle(p, 2.0, Color(0, 0, 0, 0.25))
				draw_circle(p - Vector2(0, h), 2.6, Color("#2b2038"))
				draw_circle(p - Vector2(0, h), 1.9, sh.color)


func _draw_fx() -> void:
	for f in sim.fx:
		var k: float = float(f.t) / float(f.life)
		match f.k:
			"num":
				var crit: bool = f.get("crit", false)
				var p := fpos(f.pos) - Vector2(0, k * (14 if crit else 8))
				var fs := 12 if crit else 8
				var font: Font = Data.font_main if crit else Data.font_tiny
				var col := Color(1, 0.9, 0.2, 1 - k * k) if crit else Color(1, 0.95, 0.75, 1 - k)
				var sc := 1.0 + (0.6 * (1.0 - minf(1.0, k * 5.0)) if crit else 0.0)
				draw_set_transform(p, 0.0, Vector2(sc, sc))
				draw_string_outline(font, Vector2(-20, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 40, fs, 3, Color(0.15, 0.05, 0.1, 1 - k))
				draw_string(font, Vector2(-20, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 40, fs, col)
				draw_set_transform(Vector2.ZERO)
			"die":
				var big := int(f.size) == 2
				var sz := 32 if big else 16
				draw_set_transform(fpos(f.pos), 0.0, Vector2(1.0 + k * 0.4, 1.0 - k * 0.6))
				var c := Color(2, 1.7, 0.5, 1 - k) if f.get("golden", false) else Color(1.6, 1.6, 1.6, 1.0 - k)
				draw_texture(Data.zombie_frame(f.type, 4), Vector2(-sz / 2.0, -sz + 3), c)
				draw_set_transform(Vector2.ZERO)
			"slash":
				var p := fpos(f.pos) + Vector2(0, -6)
				draw_arc(p, 6, -1.4 + k * 2.4, 0.2 + k * 2.4, 8, Color(1, 1, 1, 1 - k), 1.5)
			"zap":
				var pts := PackedVector2Array()
				for q in f.pts:
					pts.append(fpos(q) + Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.5, 1.5) - 6))
				draw_polyline(pts, Color(0.8, 0.9, 1.0, 1 - k), 2.0)
				draw_polyline(pts, Color(1, 1, 0.6, 1 - k), 0.8)
			"line":
				var c: Color = f.color
				c.a = 1 - k
				draw_line(fpos(f.a), fpos(f.b), c, float(f.w))
			"heal":
				var p := fpos(f.pos) - Vector2(0, 14 + k * 6)
				draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 6)), Color(0.5, 1, 0.6, 1 - k))
				draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 2)), Color(0.5, 1, 0.6, 1 - k))


func _draw_overlay() -> void:
	if sim.s.phase == "night" or sim.s.phase == "dusk":
		for fl in _flies:
			var q: Vector2 = fl.p + Vector2(sin(time * 0.7 + fl.ph) * 10, cos(time * 0.9 + fl.ph) * 8)
			draw_circle(q, 0.8, Color(1.0, 0.95, 0.5, 0.4 + 0.4 * sin(time * 3.0 + fl.ph)))
	for p in _parts:
		var k: float = p.t / p.life
		if p.has("ring"):
			var c: Color = p.c
			c.a = (1 - k) * 0.8
			draw_circle(p.pos, p.r * (0.4 + 0.6 * k), Color(c.r, c.g, c.b, c.a * 0.3))
			draw_arc(p.pos, p.r * (0.4 + 0.6 * k), 0, TAU, 24, c, 1.0)
		elif p.has("text"):
			var col: Color = p.c
			col.a = 1 - k * k
			var fs: int = p.fs
			var font: Font = Data.font_tiny if fs <= 8 else (Data.font_main if fs <= 12 else Data.font_big)
			var sc := 1.0 + 0.5 * maxf(0.0, 1.0 - k * 6.0)
			draw_set_transform(p.pos, 0.0, Vector2(sc, sc))
			if p.icon:
				draw_texture_rect(p.icon, Rect2(Vector2(-26, -fs + 1), Vector2(8, 8)), false, Color(1, 1, 1, col.a))
			draw_string_outline(font, Vector2(-40, 0), p.text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 3, Color(0.12, 0.06, 0.12, col.a))
			draw_string(font, Vector2(-40, 0), p.text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
			draw_set_transform(Vector2.ZERO)
		else:
			var c: Color = p.c
			c.a *= 1 - k
			var sz: float = p.sz
			draw_rect(Rect2(p.pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
	if hover >= 0:
		var p := _tile_px(hover)
		draw_rect(Rect2(p, Vector2(T, T)), Color(1, 1, 1, 0.35 + 0.15 * sin(time * 6.0)), false, 1.0)
		var t: Dictionary = sim.s.tiles[hover]
		if not tool.is_empty():
			if t.open and t.kind == "":
				var ghost: Texture2D = crop_tex(tool.id, 3) if tool.kind == "crop" else Data.turret_frame(tool.id, 0)
				draw_texture(ghost, p, Color(1, 1, 1, 0.55))
			if tool.kind == "turret":
				var r := float(Data.def_by_id[tool.id].range) + sim.rstep("turretRange") + 0.4 * sim.pk("range")
				if r > 0 and r < 20:
					draw_arc(p + Vector2(8, 8), r * T, 0, TAU, 48, Color(1, 1, 0.6, 0.5), 1.0)
		elif not t.open:
			var uc := sim.unlock_cost(hover)
			if uc > 0:
				_draw_tag(p + Vector2(8, -2), Data.fmt(uc), float(sim.s.coins) >= uc)
	if selected >= 0:
		var p := _tile_px(selected)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(T + 2, T + 2)), Color("#ffd447"), false, 1.0)
		var t: Dictionary = sim.s.tiles[selected]
		if t.kind == "turret":
			var r := sim._turret_range(t)
			if r > 0 and r < 20:
				draw_arc(p + Vector2(8, 8), r * T, 0, TAU, 48, Color(1, 0.85, 0.3, 0.6), 1.0)
	if guide.has("tile"):
		var gc := _tc(int(guide.tile))
		draw_arc(gc, 9 + sin(time * 5.0), 0, TAU, 24, Color(1, 1, 1, 0.6), 1.0)
		draw_texture(Data.battle_tile(196), gc + Vector2(-6, -24 - absf(sin(time * 5.0)) * 5))


func _draw_tag(p: Vector2, text: String, ok: bool) -> void:
	var w := Data.font_tiny.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 12
	draw_rect(Rect2(p - Vector2(w / 2, 9), Vector2(w, 10)), Color(0.12, 0.08, 0.16, 0.85))
	draw_texture_rect(Data.town_tile(93), Rect2(p - Vector2(w / 2 - 1, 8), Vector2(8, 8)), false)
	draw_string(Data.font_tiny, p + Vector2(-w / 2 + 10, -1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffd447") if ok else Color("#ff8a8a"))
