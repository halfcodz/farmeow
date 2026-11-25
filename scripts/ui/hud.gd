extends Control
## 미니멀 HUD. 글 대신 아이콘·숫자·빛으로 알려 주고, 기능은 필요해지는 순간 하나씩 나타난다.
## 위: 재화 · 날짜 / 아래: 퀵바(씨앗·방어작물) / 오른쪽: 밤·상점·고양이·냥슬롯·연구·도감

signal quit_to_title

const RESEARCH_ICON := {"growSpeed": ["farm", 81], "yieldUp": ["farm", 71], "seedLuck": ["farm", 9], "sellPrice": ["town", 93],
	"storage": ["farm", 74], "offlineCap": ["farm", 84], "turretDmg": ["town", 118], "turretRange": ["town", 119],
	"turretHp": ["town", 128], "catAtk": ["town", 129], "catHp": ["battle", 195], "catCap": ["farm", 108]}

var sim: Sim
var world: Node2D
var cam: Camera2D
var tool := {}

var _chips := {}
var _shown := {}
var _day_lbl: Label
var _phase_bar: ProgressBar
var _phase_icon: TextureRect
var _speed_btn: Button
var _pause_btn: Button
var _combo_lbl: Label
var _night_info: HBoxContainer
var _zcount: Label
var _house_bar: ProgressBar
var _hotbar: HBoxContainer
var _slots := {}
var _side: VBoxContainer
var _side_btns := {}
var _bubble: PanelContainer
var _bubble_sig := ""
var _banner: VBoxContainer
var _window: Control
var _window_kind := ""
var _guide_hand: TextureRect
var _flash: ColorRect
var _modal_open := false
var _refresh_t := 0.0
var _last_coins := 0.0


func setup(p_sim: Sim, p_world: Node2D, p_cam: Camera2D) -> void:
	sim = p_sim
	world = p_world
	cam = p_cam
	theme = UiTheme.make()
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_hotbar()
	_build_overlay()
	sim.event.connect(_on_event)
	world.tile_clicked.connect(_on_tile_clicked)
	_last_coins = float(sim.s.coins)
	_refresh(true)


# ═════════════════════════════════════════════════════════
# 구성
# ═════════════════════════════════════════════════════════

func _pill(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.1, 0.07, 0.15, 0.72), Color(0, 0, 0, 0), 0, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _build_top() -> void:
	var left := HBoxContainer.new()
	left.position = Vector2(8, 6)
	left.add_theme_constant_override("separation", 6)
	add_child(left)
	for k in [["coins", Data.town_tile(93)], ["seeds", Data.farm_tile(9)], ["fodder", Data.food("canned_food_1")], ["candy", Data.food("candy_corn")]]:
		var p := _pill(left)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		p.add_child(h)
		h.add_child(UiTheme.icon(k[1], 16))
		var l := UiTheme.label("0", 12, UiTheme.CREAM, true)
		h.add_child(l)
		_chips[k[0]] = [p, l]
	var mid := _pill(self)
	mid.position = Vector2(400, 6)
	mid.custom_minimum_size = Vector2(160, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	mid.add_child(v)
	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_icon = UiTheme.icon(null, 16)
	h2.add_child(_phase_icon)
	_day_lbl = UiTheme.label("", 12, UiTheme.CREAM, true)
	h2.add_child(_day_lbl)
	v.add_child(h2)
	_phase_bar = ProgressBar.new()
	_phase_bar.custom_minimum_size = Vector2(150, 4)
	_phase_bar.show_percentage = false
	v.add_child(_phase_bar)
	_night_info = HBoxContainer.new()
	_night_info.alignment = BoxContainer.ALIGNMENT_CENTER
	_night_info.add_child(UiTheme.icon(Data.t("sprites/icons/zom_rat.png"), 16))
	_zcount = UiTheme.label("0", 10, Color("#ffb3a8"), true)
	_night_info.add_child(_zcount)
	_night_info.add_child(UiTheme.icon(Data.t("sprites/terrain/house_kenney.png"), 16))
	_house_bar = ProgressBar.new()
	_house_bar.custom_minimum_size = Vector2(70, 6)
	_house_bar.show_percentage = false
	_house_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_night_info.add_child(_house_bar)
	v.add_child(_night_info)
	_combo_lbl = UiTheme.label("", 18, UiTheme.GOLD, true)
	_combo_lbl.add_theme_constant_override("outline_size", 6)
	_combo_lbl.add_theme_color_override("font_outline_color", Color("#2b2038"))
	_combo_lbl.position = Vector2(380, 50)
	_combo_lbl.custom_minimum_size = Vector2(200, 0)
	_combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_lbl.pivot_offset = Vector2(100, 12)
	_combo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_lbl)
	var right := HBoxContainer.new()
	right.position = Vector2(820, 6)
	right.add_theme_constant_override("separation", 4)
	add_child(right)
	_speed_btn = _icon_btn(right, "▶", func(): Game.cycle_speed(), 40)
	_pause_btn = _icon_btn(right, "II", func(): _toggle_pause(), 36)
	_icon_btn(right, "≡", func(): _open_menu(), 36)


func _icon_btn(parent: Control, text: String, cb: Callable, w: int = 36, tex: Texture2D = null) -> Button:
	var b := UiTheme.button(text, cb, tex, w)
	b.custom_minimum_size.y = 28
	parent.add_child(b)
	return b


## 아래쪽 도크 하나에 모든 조작을 모은다:
## [씨앗/방어 전환] [퀵바 9칸] | [상점 고양이 냥슬롯 연구 도감] | [밤 맞이]
var _group := "crop"
var _group_btn: Button
var _dock: PanelContainer


func _build_hotbar() -> void:
	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", UiTheme.box(11, 10, 5))
	add_child(_dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_dock.add_child(row)
	_dock.resized.connect(func(): _dock.position = Vector2(roundf((960 - _dock.size.x) / 2.0), 540 - _dock.size.y - 4))
	_group_btn = UiTheme.button("", func(): _switch_group(), Data.farm_tile(9), 34)
	_group_btn.custom_minimum_size = Vector2(34, 44)
	_group_btn.tooltip_text = "씨앗 ↔ 방어작물 (Tab)"
	row.add_child(_group_btn)
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 3)
	row.add_child(_hotbar)
	for c in Data.crops: _make_slot("crop", c.id, Data.t("sprites/icons/crop_%s.png" % c.id), float(c.seedCost), c.name)
	for d in Data.defenses: _make_slot("turret", d.id, Data.t("sprites/icons/def_%s.png" % d.id), float(d.cost), d.name)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 40)
	sep.color = Color(0.25, 0.15, 0.1, 0.6)
	sep.name = "sep"
	row.add_child(sep)
	_side = VBoxContainer.new()   # (호환용, 쓰지 않음)
	var menu := HBoxContainer.new()
	menu.add_theme_constant_override("separation", 3)
	row.add_child(menu)
	var defs := [
		["shop", Data.farm_tile(74), "상점 (B)", func(): _open_window("shop")],
		["cats", Data.t("sprites/icons/cat_farmer_0.png"), "고양이 (C)", func(): _open_window("cats")],
		["slot", Data.t("sprites/icons/crop_rainbow.png"), "냥슬롯", func(): _open_window("slot")],
		["research", Data.town_tile(104), "연구 (R)", func(): _open_window("research")],
		["dex", Data.farm_tile(9), "도감", func(): _open_window("dex")],
		["night", Data.food("blueberries"), "밤 맞이 (N)", func(): _call_night()],
	]
	for d in defs:
		var b := UiTheme.button("", d[3], d[1], 44)
		b.custom_minimum_size = Vector2(44, 44)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 26)
		b.tooltip_text = d[2]
		b.visible = false
		if d[0] == "night":
			var sp2 := ColorRect.new()
			sp2.custom_minimum_size = Vector2(2, 40)
			sp2.color = Color(0.25, 0.15, 0.1, 0.6)
			sp2.name = "sep2"
			menu.add_child(sp2)
			b.add_theme_stylebox_override("normal", UiTheme.box(3, 8, 3))
			b.add_theme_stylebox_override("hover", UiTheme.box(3, 8, 3, Color(1.15, 1.1, 1.1)))
		menu.add_child(b)
		_side_btns[d[0]] = b


func _switch_group() -> void:
	if not sim.revealed("defense"): return
	_group = "turret" if _group == "crop" else "crop"
	_group_btn.icon = Data.farm_tile(9) if _group == "crop" else Data.t("sprites/icons/def_peashoot.png")
	Sound.play("toggle")
	_refresh(false)


## 지금 그룹에서 보여 줄 슬롯: 해금된 것 중 가장 높은 단계 9개
func _visible_slots() -> Array:
	var list := []
	for id in _slots:
		var sl: Dictionary = _slots[id]
		if sl.kind != _group: continue
		var ok := sim.crop_unlocked(id) if sl.kind == "crop" else (sim.def_unlocked(id) and sim.revealed("defense"))
		if ok: list.append(id)
	if list.size() > 9: list = list.slice(list.size() - 9)
	return list


func _make_slot(kind: String, id: String, tex: Texture2D, cost: float, name: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s  ·  %s" % [name, Data.fmt(cost)]
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 24)
	b.text = Data.fmt(cost)
	b.add_theme_font_override("font", Data.font_tiny)
	b.add_theme_font_size_override("font_size", 8)
	b.pressed.connect(func():
		Sound.play("click")
		_select_tool(kind, id))
	b.mouse_entered.connect(func(): Sound.play("hover", 0.1, -12.0))
	b.visible = false
	_hotbar.add_child(b)
	_slots[id] = {"b": b, "kind": kind}


func _build_overlay() -> void:
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.1, 0.07, 0.15, 0.85), Color(1, 1, 1, 0.2), 1, 3))
	_bubble.visible = false
	add_child(_bubble)
	_banner = VBoxContainer.new()
	_banner.position = Vector2(0, 150)
	_banner.custom_minimum_size = Vector2(960, 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_guide_hand = UiTheme.icon(Data.battle_tile(196), 32)
	_guide_hand.visible = false
	add_child(_guide_hand)
	_flash = ColorRect.new()
	_flash.size = Vector2(960, 540)
	_flash.color = Color(1, 1, 0.8, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


# ═════════════════════════════════════════════════════════
# 갱신
# ═════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if sim == null: return
	var s := sim.s
	_chips.coins[1].text = Data.fmt(s.coins)
	_chips.seeds[1].text = str(int(s.seeds))
	_chips.fodder[1].text = str(int(s.fodder))
	_chips.candy[1].text = str(int(s.candy))
	_chips.candy[0].visible = int(s.candy) > 0
	_chips.fodder[0].visible = sim.revealed("cats")
	_chips.seeds[0].visible = int(s.seeds) > 3 or sim.revealed("defense")
	if float(s.coins) > _last_coins + 0.5:
		_pop(_chips.coins[0], 1.15)
	_last_coins = float(s.coins)
	var icon := {"day": Data.farm_tile(83), "dusk": Data.town_tile(15), "night": Data.food("blueberries"), "dawn": Data.farm_tile(122)}
	_phase_icon.texture = icon.get(s.phase)
	_day_lbl.text = " %d일" % int(s.day)
	_phase_bar.value = 100.0 * clampf(float(s.t) / maxf(1.0, sim.phase_len()), 0.0, 1.0)
	_phase_bar.add_theme_stylebox_override("fill", UiTheme.flat(Color({"day": "#ffd447", "dusk": "#ff9a3d", "night": "#7a6cff", "dawn": "#ffb3c1"}.get(s.phase, "#ffffff"))))
	_night_info.visible = s.phase == "night"
	if s.phase == "night":
		var alive := 0
		for z in sim.zombies:
			if z.alive: alive += 1
		_zcount.text = "%d " % (alive + sim.plan.get("spawns", []).size() - sim.spawn_i)
		var hk := 100.0 * sim.house_hp / maxf(1.0, sim.house_max)
		_house_bar.value = hk
		_house_bar.add_theme_stylebox_override("fill", UiTheme.flat(Color("#e8556d") if hk < 35 else Color("#8fd05a")))
	_speed_btn.text = "▶".repeat(int(s.speed))
	_speed_btn.visible = sim.revealed("speed")
	_pause_btn.text = "▶" if Game.paused else "II"
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh(false)
	_update_bubble()
	_update_guide()


func _refresh(_force: bool) -> void:
	var s := sim.s
	var vis := _visible_slots()
	for id in _slots:
		var sl: Dictionary = _slots[id]
		var b: Button = sl.b
		var ok := vis.has(id)
		if ok and not b.visible:
			b.visible = true
			var key: String = "slot_" + id
			if _shown.has("hotbar") and not _shown.has(key):
				_pop(b, 1.4)
				Sound.play("reveal")
			_shown[key] = true
		elif not ok:
			b.visible = false
			if sl.kind == _group: pass
			elif not _shown.has("slot_" + id) and (sim.crop_unlocked(id) if sl.kind == "crop" else (sim.def_unlocked(id) and sim.revealed("defense"))):
				_shown["slot_" + id] = true
		var cost := float(Data.crop_by_id[id].seedCost) if sl.kind == "crop" else float(Data.def_by_id[id].cost)
		b.modulate = Color(1.0, 0.92, 0.55) if tool.get("id", "") == id else (Color(1, 1, 1) if float(s.coins) >= cost else Color(0.7, 0.7, 0.75))
	_group_btn.visible = sim.revealed("defense")
	_shown["hotbar"] = true
	var any_menu := false
	for k in ["shop", "cats", "slot", "research", "dex"]:
		if sim.revealed(k): any_menu = true
	_dock.get_child(0).get_node("sep").visible = any_menu
	for k in _side_btns:
		var b: Button = _side_btns[k]
		var ok := sim.revealed(k)
		if k == "night":
			b.disabled = s.phase != "day"
		if ok and not b.visible:
			b.visible = true
			if not _shown.has("side_" + k) and k != "night":
				_pop(b, 1.5)
		if ok: _shown["side_" + k] = true
		if not ok: b.visible = false
	var full := sim.storage_used() >= sim.storage_cap()
	_side_btns.shop.modulate = Color(1, 0.6, 0.6) if full else Color.WHITE
	if _window_kind != "" and is_instance_valid(_window):
		_refresh_window()


func _pop(c: Control, sc: float) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(sc, sc), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _screen(world_px: Vector2) -> Vector2:
	return world.get_global_transform_with_canvas() * world_px


func _update_guide() -> void:
	var g: Dictionary = sim.guide() if not _modal_open and _window_kind == "" else {}
	var bob := absf(sin(Time.get_ticks_msec() / 200.0)) * 6
	if g.has("tool") and tool.is_empty():
		var id := "carrot" if g.tool == "crop" else "peashoot"
		world.guide = {}
		if _slots.has(id) and _slots[id].kind != _group and sim.revealed("defense"):
			var b2: Button = _group_btn
			_guide_hand.visible = true
			_guide_hand.position = b2.global_position + Vector2(4, -34 - bob)
			return
		if _slots.has(id) and _slots[id].b.visible:
			var b: Button = _slots[id].b
			_guide_hand.visible = true
			_guide_hand.position = b.global_position + Vector2(4, -34 - bob)
			return
	if g.has("ui"):
		world.guide = {}
		var b: Button = _side_btns.get(g.ui)
		if b and b.visible:
			_guide_hand.visible = true
			_guide_hand.position = b.global_position + Vector2(6, -34 - bob)
			return
	_guide_hand.visible = false
	world.guide = g if g.has("tile") else {}


func _update_bubble() -> void:
	var i: int = world.selected
	if i < 0 or not tool.is_empty():
		_bubble.visible = false
		_bubble_sig = ""
		return
	var t: Dictionary = sim.s.tiles[i]
	if t.kind == "":
		_bubble.visible = false
		return
	var sig := "%d|%s|%s|%d|%s" % [i, t.kind, t.id, int(t.stars), sim.s.phase]
	if sig != _bubble_sig:
		_bubble_sig = sig
		for n in _bubble.get_children(): n.queue_free()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		_bubble.add_child(h)
		if t.kind == "turret":
			var d: Dictionary = Data.def_by_id[t.id]
			h.add_child(UiTheme.icon(Data.t("sprites/icons/def_%s.png" % t.id), 24))
			h.add_child(UiTheme.label("★".repeat(int(t.stars)) + "☆".repeat(3 - int(t.stars)), 10, UiTheme.GOLD))
			if int(t.stars) < 3:
				var b := UiTheme.button("%d" % Data.upgrade_seed_cost(int(t.stars)), func(): sim.upgrade_turret(i), Data.farm_tile(9))
				b.tooltip_text = "★ 승급 · 씨앗 %d · 코인 %s" % [Data.upgrade_seed_cost(int(t.stars)), Data.fmt(float(d.cost) * (int(t.stars) + 1))]
				h.add_child(b)
			if sim.can_build_now():
				h.add_child(UiTheme.button("✕", func():
					sim.clear_tile(i)
					world.selected = -1))
		else:
			h.add_child(UiTheme.icon(Data.t("sprites/icons/crop_%s.png" % t.id), 20))
			h.add_child(UiTheme.button("✕", func():
				sim.clear_tile(i)
				world.selected = -1))
	_bubble.visible = true
	_bubble.reset_size()
	var sp := _screen(world._tc(i) + Vector2(0, -12))
	_bubble.position = (sp - Vector2(_bubble.size.x / 2.0, _bubble.size.y)).clamp(Vector2(4, 40), Vector2(956, 490) - _bubble.size)


# ═════════════════════════════════════════════════════════
# 조작
# ═════════════════════════════════════════════════════════

func _select_tool(kind: String, id: String) -> void:
	if kind != _group and sim.revealed("defense"):
		_group = kind
		_group_btn.icon = Data.farm_tile(9) if _group == "crop" else Data.t("sprites/icons/def_peashoot.png")
	tool = {} if tool.get("id", "") == id else {"kind": kind, "id": id}
	world.tool = tool
	world.selected = -1
	_refresh(false)


func _on_tile_clicked(i: int, button: int, _shift: bool) -> void:
	if _modal_open: return
	if button == MOUSE_BUTTON_RIGHT:
		tool = {}
		world.tool = tool
		world.selected = -1
		return
	var t: Dictionary = sim.s.tiles[i]
	if not t.open:
		if Data.zone_of(Sim.tx(i), Sim.ty(i)) != "house":
			sim.unlock_tile(i)
		return
	if t.kind == "crop" and sim.crop_ripe(t):
		sim.harvest(i)
		return
	if t.kind == "" and not tool.is_empty():
		if tool.kind == "crop": sim.plant(i, tool.id)
		else: sim.build(i, tool.id)
		return
	world.selected = i if world.selected != i else -1


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	if _modal_open: return
	if _window_kind != "" and e.keycode == KEY_ESCAPE:
		_close_window()
		get_viewport().set_input_as_handled()
		return
	match e.keycode:
		KEY_SPACE: _toggle_pause()
		KEY_TAB: _switch_group()
		KEY_H: sim.harvest_all()
		KEY_N: _call_night()
		KEY_Z:
			if sim.revealed("speed"): Game.cycle_speed()
		KEY_B:
			if sim.revealed("shop"): _open_window("shop")
		KEY_C:
			if sim.revealed("cats"): _open_window("cats")
		KEY_R:
			if sim.revealed("research"): _open_window("research")
		KEY_F: sim.feed_all()
		KEY_ESCAPE:
			if not tool.is_empty() or world.selected >= 0:
				tool = {}
				world.tool = tool
				world.selected = -1
			else:
				_open_menu()
		_:
			if e.keycode >= KEY_1 and e.keycode <= KEY_9:
				var vis := _visible_slots()
				var idx: int = e.keycode - KEY_1
				if idx < vis.size(): _select_tool(_slots[vis[idx]].kind, vis[idx])
			else:
				return
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	Game.paused = not Game.paused
	Sound.play("pause" if Game.paused else "unpause")


func _call_night() -> void:
	if sim.s.phase == "day": sim.skip_to_dusk()


# ═════════════════════════════════════════════════════════
# 이벤트 → 배너·드래프트
# ═════════════════════════════════════════════════════════

func _on_event(kind: String, d: Dictionary) -> void:
	world.on_event(kind, d)
	match kind:
		"toast":
			if d.get("color", "") == "warn": _mini_banner(d.text, Color("#ffb3a8"))
		"phase":
			match d.phase:
				"dusk":
					Sound.music("boss" if d.plan.boss != null else "night")
					_title_card("%d일째 밤" % int(sim.s.day), Color("#ff9a7a"))
				"night":
					var final := sim.is_gate_night(int(sim.s.day)) and int(sim.s.day) >= 60
					Sound.music("final" if final else ("boss" if d.plan.boss != null else ("night2" if int(sim.s.day) % 2 == 0 else "night")))
				"day":
					Sound.music("day" if int(sim.s.day) % 3 != 0 else "day2")
					Sound.play("rooster", 0.1, -6.0)
		"night_result":
			if d.failed:
				_title_card("습격 실패…", Color("#ff6b6b"))
				_flash_screen(Color(1, 0.2, 0.2), 0.35)
			elif d.has("draft") and not d.draft.is_empty():
				_queue_modal({"type": "draft", "res": d})
		"newcomer":
			var z: Dictionary = Data.zombie_by_id[d.id]
			_title_card(z.name, Color("#c8f5a0"), Data.t("sprites/icons/zom_%s.png" % d.id))
		"boss_spawn":
			var z: Dictionary = Data.zombie_by_id[d.id]
			_title_card(z.name, Color("#ff7a7a"), Data.t("sprites/icons/zom_%s.png" % d.id))
			_flash_screen(Color(1, 0.1, 0.1), 0.25)
		"golden":
			_mini_banner("황금 좀비!", UiTheme.GOLD)
		"golden_kill":
			_flash_screen(Color(1, 0.9, 0.3), 0.4)
			Game.hitstop = 0.12
		"jackpot":
			if int(d.level) == 2:
				_flash_screen(Color(1, 0.8, 1.0), 0.45)
				Game.hitstop = 0.15
		"kill":
			if d.boss:
				Game.hitstop = 0.25
				_flash_screen(Color.WHITE, 0.3)
		"combo":
			var n := int(d.n)
			if n == 0:
				var tw := _combo_lbl.create_tween()
				tw.tween_property(_combo_lbl, "modulate:a", 0.0, 0.4)
			else:
				_combo_lbl.text = "%d 콤보!" % n
				_combo_lbl.modulate = Color(1, 1, 1, 1)
				_combo_lbl.add_theme_color_override("font_color", Color.from_hsv(fmod(n / 60.0, 1.0), 0.6, 1.0))
				_pop(_combo_lbl, 1.0 + minf(n, 100) / 80.0)
				Sound.play("combo")
		"goal":
			Sound.play("quest")
		"reveal":
			Sound.play("reveal")
		"chapter_clear":
			var ch: Dictionary = d.chapter
			_title_card(ch.title, UiTheme.GOLD, Data.farm_tile(83), "+%s  ·  씨앗 +%d" % [Data.fmt(d.coins), int(d.seeds)])
			_flash_screen(Color(1, 1, 0.7), 0.4)
			Sound.play("legend")
		"dialog":
			var ch2 := sim.chapter()
			if not ch2.is_empty(): _title_card(ch2.title, UiTheme.CREAM)
		"ending":
			_queue_modal({"type": "ending"})
		"cat_down":
			_mini_banner("%s ♥%d" % [d.name, int(d.lives)], Color("#ffb3a8"))


func _flash_screen(c: Color, a: float) -> void:
	_flash.color = Color(c.r, c.g, c.b, a)
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)


## 큰 글씨 타이틀 카드 (읽을 필요 없는 한 단어)
func _title_card(text: String, col: Color, icon: Texture2D = null, sub: String = "") -> void:
	for n in _banner.get_children(): n.queue_free()
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon: h.add_child(UiTheme.icon(icon, 40))
	var l := UiTheme.label(text, 28, col, true)
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color("#1a1024"))
	h.add_child(l)
	_banner.add_child(h)
	if sub != "":
		var s2 := UiTheme.label(sub, 14, UiTheme.CREAM, true)
		s2.add_theme_constant_override("outline_size", 6)
		s2.add_theme_color_override("font_outline_color", Color("#1a1024"))
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_banner.add_child(s2)
	_banner.modulate = Color(1, 1, 1, 0)
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	Sound.play("whoosh", 0.1, -6.0)


func _mini_banner(text: String, col: Color) -> void:
	var l := UiTheme.label(text, 12, col, true)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color("#1a1024"))
	l.position = Vector2(0, 440)
	l.custom_minimum_size.x = 960
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 420.0, 1.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tw.tween_callback(l.queue_free)


# ═════════════════════════════════════════════════════════
# 창 (상점 · 고양이 · 연구 · 냥슬롯 · 도감)
# ═════════════════════════════════════════════════════════

var _win_body: VBoxContainer
var _win_head: HBoxContainer
var _win_tab := "buy"
var _win_sig := ""


func _open_window(kind: String) -> void:
	if _window_kind == kind:
		_close_window()
		return
	_close_window()
	_window_kind = kind
	var dim := ColorRect.new()
	dim.size = Vector2(960, 540)
	dim.color = Color(0.05, 0.03, 0.1, 0.35)
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed: _close_window())
	add_child(dim)
	move_child(dim, _banner.get_index())
	_window = dim
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(10, 10, 10))
	p.position = Vector2(170, 56)
	p.custom_minimum_size = Vector2(620, 420)
	p.size = p.custom_minimum_size
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_win_head = HBoxContainer.new()
	_win_head.add_theme_constant_override("separation", 6)
	v.add_child(_win_head)
	var titles := {"shop": "상점", "cats": "고양이", "research": "연구", "slot": "냥슬롯", "dex": "도감"}
	_win_head.add_child(UiTheme.label(titles[kind], 14, UiTheme.INK, true))
	if kind == "shop":
		for tb in [["buy", "사기"], ["sell", "팔기"]]:
			var b := UiTheme.button(tb[1], func():
				_win_tab = tb[0]
				_win_sig = ""
				_refresh_window(), null, 80)
			b.name = "tab_" + tb[0]
			_win_head.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_head.add_child(sp)
	_win_head.add_child(UiTheme.button("✕", func(): _close_window(), null, 34))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(600, 370)
	v.add_child(scroll)
	_win_body = VBoxContainer.new()
	_win_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_win_body)
	if kind == "shop": _win_tab = "sell" if sim.storage_used() > 0 else "buy"
	_win_sig = ""
	_refresh_window()
	Sound.play("open")
	if kind == "slot": Game.modal_pause += 1


func _close_window() -> void:
	if _window_kind == "": return
	if _window_kind == "slot": Game.modal_pause = maxi(0, Game.modal_pause - 1)
	_window_kind = ""
	if is_instance_valid(_window): _window.queue_free()
	Sound.play("close")


func _refresh_window() -> void:
	match _window_kind:
		"shop": _win_shop()
		"cats": _win_cats()
		"research": _win_research()
		"dex": _win_dex()
		"slot": _win_slot()


func _clear_body() -> void:
	for n in _win_body.get_children(): n.queue_free()


func _section(text: String) -> GridContainer:
	if text != "": _win_body.add_child(UiTheme.label(text, 12, UiTheme.INK_SOFT, true))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_win_body.add_child(g)
	return g


## 상품 카드: 큰 아이콘 · 이름 · 가격 하나
func _card(parent: Control, tex: Texture2D, name: String, price: String, cb: Callable, ok: bool = true, tip: String = "", badge: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 86)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not ok
	b.tooltip_text = tip
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UiTheme.icon(tex, 36)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not ok: ic.modulate = Color(1, 1, 1, 0.45)
	v.add_child(ic)
	var nl := UiTheme.label(name, 10, UiTheme.INK)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if price != "":
		h.add_child(UiTheme.icon(Data.town_tile(93), 10))
		h.add_child(UiTheme.label(price, 10, UiTheme.INK if ok else UiTheme.WARN, true))
	v.add_child(h)
	if badge != "":
		var bl := UiTheme.label(badge, 10, UiTheme.CREAM, true)
		bl.add_theme_constant_override("outline_size", 4)
		bl.add_theme_color_override("font_outline_color", Color("#2b2038"))
		bl.position = Vector2(6, 4)
		b.add_child(bl)
	b.pressed.connect(func():
		cb.call()
		_pop(b, 1.08)
		_win_sig = ""
		_refresh_window())
	b.mouse_entered.connect(func(): Sound.play("hover", 0.1, -12.0))
	parent.add_child(b)
	return b


func _win_shop() -> void:
	var s := sim.s
	var sig := "%s|%d|%s|%d|%d" % [_win_tab, int(s.coins), str(s.storage), sim.alive_cats().size(), int(s.seeds)]
	if sig == _win_sig: return
	_win_sig = sig
	_clear_body()
	for tb in ["buy", "sell"]:
		var b: Button = _win_head.get_node_or_null("tab_" + tb)
		if b: b.modulate = Color(1, 0.92, 0.55) if _win_tab == tb else Color(1, 1, 1, 0.6)
	if _win_tab == "sell":
		var total := 0.0
		for id in s.storage:
			total += floorf(float(Data.crop_by_id[id].unitPrice) * int(s.storage[id]) * sim.sell_mul())
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		var all := UiTheme.button("전부 팔기   +%s" % Data.fmt(total), func():
			var g := sim.sell_all(false)
			if g > 0: _flash_screen(Color(1, 0.9, 0.4), 0.15)
			_win_sig = ""
			_refresh_window(), Data.town_tile(93), 220)
		all.custom_minimum_size.y = 40
		all.disabled = total <= 0
		top.add_child(all)
		var auto := CheckButton.new()
		auto.text = "자동 판매"
		auto.button_pressed = bool(s.toggles.auto_sell) or sim.has_job("merchant")
		auto.disabled = sim.has_job("merchant")
		auto.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled"]:
			auto.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		auto.toggled.connect(func(on): s.toggles.auto_sell = on)
		top.add_child(auto)
		top.add_child(UiTheme.label("창고 %d/%d" % [sim.storage_used(), sim.storage_cap()], 10, UiTheme.WARN if sim.storage_used() >= sim.storage_cap() else UiTheme.INK_SOFT))
		_win_body.add_child(top)
		var g := _section("")
		if s.storage.is_empty():
			_win_body.add_child(UiTheme.label("—", 14, UiTheme.INK_SOFT))
		for id in s.storage:
			var c: Dictionary = Data.crop_by_id[id]
			var n := int(s.storage[id])
			var gain := floorf(float(c.unitPrice) * n * sim.sell_mul())
			_card(g, Data.t("sprites/icons/cropbig_%s.png" % id), c.name, "+" + Data.fmt(gain), func():
				if sim.sell(id) > 0: Sound.play("coins"), true, "", "×%d" % n)
		return
	var g1 := _section("씨앗")
	for c in Data.crops:
		if not sim.crop_unlocked(c.id): continue
		_card(g1, Data.t("sprites/icons/cropbig_%s.png" % c.id), c.name, Data.fmt(c.seedCost), func():
			_select_tool("crop", c.id)
			_close_window(), float(s.coins) >= float(c.seedCost), "%d초 · %d개 · 개당 %s" % [int(round(sim.crop_grow_time(c.id))), int(c.yield), Data.fmt(c.unitPrice)])
	if sim.revealed("defense"):
		var g2 := _section("방어작물")
		for d in Data.defenses:
			if not sim.def_unlocked(d.id): continue
			_card(g2, Data.t("sprites/icons/def_%s.png" % d.id), d.name, Data.fmt(d.cost), func():
				_select_tool("turret", d.id)
				_close_window(), float(s.coins) >= float(d.cost), d.desc)
	if sim.revealed("cats"):
		var g3 := _section("고양이")
		var owned := sim.alive_cats().size()
		var room := owned < sim.cat_cap()
		for j in Data.jobs:
			if not sim.job_unlocked(j.id): continue
			var cost := Data.hire_cost(j, owned)
			_card(g3, Data.t("sprites/icons/cat_%s_0.png" % j.id), j.name, Data.fmt(cost), func():
				if sim.hire(j.id): Sound.play("meow"), room and float(s.coins) >= cost, j.perk)
		_card(g3, Data.farm_tile(74), "입양 상자", "", func(): _gacha(), room and int(s.seeds) >= Data.ADOPT_SEED_COST, "등급 랜덤!", "씨앗%d" % Data.ADOPT_SEED_COST)
		_card(g3, Data.food("canned_food_1"), "사료 ×5", Data.fmt(sim.fodder_price() * 5), func(): sim.buy_fodder(5), float(s.coins) >= sim.fodder_price() * 5)


## 입양 상자 — 등급이 드러나는 순간의 두근거림
func _gacha() -> void:
	var c := sim.adopt()
	if c.is_empty(): return
	_close_window()
	_queue_modal({"type": "gacha", "cat": c})


func _win_cats() -> void:
	var s := sim.s
	var sig := ""
	for c in s.cats: sig += "%d%d%s%d%d%s|" % [int(c.uid), int(c.level), c.assign, int(c.lives), int(float(c.full) / 10), str(c.down)]
	sig += str(int(s.fodder))
	if sig == _win_sig: return
	_win_sig = sig
	_clear_body()
	var fb := UiTheme.button("밥 주기 (F)   사료 %d" % int(s.fodder), func():
		sim.feed_all()
		_win_sig = "", Data.food("canned_food_1"), 190)
	fb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_win_body.add_child(fb)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_win_body.add_child(g)
	var letters := {"N": 123, "E": 124, "S": 146, "W": 147}
	for c in s.cats:
		if not c.alive: continue
		var j: Dictionary = Data.job_by_id[c.job]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.box(49, 8, 5))
		p.custom_minimum_size = Vector2(192, 0)
		g.add_child(p)
		var h := HBoxContainer.new()
		p.add_child(h)
		h.add_child(UiTheme.icon(Data.t("sprites/icons/cat_%s_%d.png" % [c.job, int(c.fur)]), 40))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var rar: Dictionary = Data.rarities[int(c.rarity)]
		v.add_child(UiTheme.label("%s  Lv%d" % [c.name, int(c.level)], 10, Color(rar.color).darkened(0.4) if int(c.rarity) > 0 else UiTheme.INK, true))
		v.add_child(UiTheme.label("♥".repeat(int(c.lives)), 9, UiTheme.WARN))
		var fb2 := ProgressBar.new()
		fb2.custom_minimum_size = Vector2(120, 5)
		fb2.show_percentage = false
		fb2.value = float(c.full)
		fb2.add_theme_stylebox_override("fill", UiTheme.flat(Color("#e8556d") if float(c.full) < 30 else Color("#ffb347")))
		v.add_child(fb2)
		if sim.is_combat(c):
			var dirs := HBoxContainer.new()
			dirs.add_theme_constant_override("separation", 1)
			for dk in ["free", "N", "E", "S", "W"]:
				var db := Button.new()
				db.icon = Data.ui_tile(78) if dk == "free" else Data.ui_tile(letters[dk])
				db.flat = true
				db.focus_mode = Control.FOCUS_NONE
				db.custom_minimum_size = Vector2(22, 20)
				db.modulate = Color.WHITE if c.assign == dk else Color(1, 1, 1, 0.35)
				db.tooltip_text = "자유" if dk == "free" else Data.DIR_NAME[dk]
				var uid := int(c.uid)
				db.pressed.connect(func():
					sim.assign(uid, dk)
					_win_sig = "")
				dirs.add_child(db)
			v.add_child(dirs)
		p.tooltip_text = "%s · %s" % [j.name, j.perk]


func _win_research() -> void:
	var s := sim.s
	var sig := "%d|%s|%d" % [int(s.coins), str(s.research), int(s.candy)]
	if sig == _win_sig: return
	_win_sig = sig
	_clear_body()
	var g := _section("")
	for r in Data.research:
		var lv := sim.rlv(r.id)
		var ic: Array = RESEARCH_ICON[r.id]
		var tex: Texture2D = Data.farm_tile(ic[1]) if ic[0] == "farm" else (Data.town_tile(ic[1]) if ic[0] == "town" else Data.battle_tile(ic[1]))
		var maxed := lv >= int(r.maxLevel)
		var cost := Data.research_cost(r, lv)
		_card(g, tex, r.name, "MAX" if maxed else Data.fmt(cost), func(): sim.research_up(r.id), not maxed and float(s.coins) >= cost, r.desc, "Lv%d" % lv)
	if int(s.candy) > 0 or sim.can_prestige():
		var g2 := _section("별사탕 %d" % int(s.candy))
		var names := {"yield": ["수확", Data.farm_tile(71)], "sell": ["판매", Data.town_tile(93)], "catatk": ["발톱", Data.town_tile(129)], "offline": ["방치", Data.farm_tile(84)]}
		for k in names:
			var cc := sim.candy_cost(k)
			_card(g2, names[k][1], "%s %d" % [names[k][0], int(s.candy_up[k])], "", func(): sim.candy_up(k), int(s.candy) >= cc, "+10%", "★%d" % cc)
		if sim.can_prestige():
			_card(g2, Data.food("candy_corn"), "환생", "", func(): _confirm_prestige(), true, "냥생 %d회차" % (int(s.prestige) + 2), "+%d" % sim.prestige_candy())


func _win_dex() -> void:
	var s := sim.s
	var sig := str(s.stats.kills) + str(s.stats.harvest.keys()) + str(s.memorial.size()) + str(s.get("perks", {}))
	if sig == _win_sig: return
	_win_sig = sig
	_clear_body()
	var g := _section("좀비")
	g.columns = 9
	for z in Data.zombies:
		var k := int(s.stats.kills.get(z.id, 0))
		var ic := UiTheme.icon(Data.t("sprites/icons/zom_%s.png" % z.id) if k > 0 else Data.ui_tile(54), 48)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		ic.tooltip_text = ("%s  ×%d\n%s" % [z.name, k, z.counter]) if k > 0 else "?"
		g.add_child(ic)
	var g3 := _section("원래 모습")
	g3.columns = 14
	for z in Data.zombies:
		var shown: bool = s.campaign_clear or int(s.stats.kills.get(z.id, 0)) >= 30
		var ic := UiTheme.icon(Data.portrait(z.id) if shown else Data.ui_tile(54), 32)
		ic.modulate = Color.WHITE if shown else Color(1, 1, 1, 0.35)
		g3.add_child(ic)
	var g2 := _section("작물")
	g2.columns = 14
	for c in Data.crops:
		var n := int(s.stats.harvest.get(c.id, 0))
		var ic := UiTheme.icon(Data.t("sprites/icons/cropbig_%s.png" % c.id) if n > 0 else Data.ui_tile(54), 32)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		ic.tooltip_text = ("%s ×%s" % [c.name, Data.fmt(n)]) if n > 0 else "?"
		g2.add_child(ic)
	if not s.get("perks", {}).is_empty():
		var gp := _section("축복")
		gp.columns = 12
		for id in s.perks:
			var p := Perks.by_id(id)
			var ic := UiTheme.icon(Perks.icon(p), 32)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			ic.tooltip_text = "%s ×%d\n%s" % [p.name, int(s.perks[id]), p.desc]
			gp.add_child(ic)
	if not s.memorial.is_empty():
		var gm := _section("무지개다리")
		gm.columns = 12
		for m in s.memorial:
			var ic := UiTheme.icon(Data.t("sprites/icons/cat_%s_%d.png" % [m.job, int(m.get("fur", 0))]), 32)
			ic.modulate = Color(0.8, 0.8, 1.0, 0.7)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			ic.tooltip_text = "%s · %d일" % [m.name, int(m.day)]
			gm.add_child(ic)
	var st: Dictionary = s.stats
	_win_body.add_child(UiTheme.label("최고 %d일 · 최대 콤보 %d · 생존한 밤 %d" % [int(st.best_day), int(s.get("combo_best", 0)), int(st.won)], 10, UiTheme.INK_SOFT))


# ── 냥슬롯 ────────────────────────────────────────────────

var _reels: Array = []
var _spinning := false
var _slot_result: Label


func _slot_tex(id: String) -> Texture2D:
	match id:
		"cat": return Data.t("sprites/icons/cat_farmer_0.png")
		"zombie": return Data.t("sprites/icons/zom_rat.png")
	return Data.t("sprites/icons/cropbig_%s.png" % id)


func _win_slot() -> void:
	if _win_sig == "slot": return
	_win_sig = "slot"
	_clear_body()
	var machine := PanelContainer.new()
	machine.add_theme_stylebox_override("panel", UiTheme.flat(Color("#2b2038"), Color("#ffd447"), 3, 12))
	machine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_win_body.add_child(machine)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	machine.add_child(h)
	_reels.clear()
	for k in 3:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.flat(Color("#fff4dc"), Color("#3b2a20"), 2, 6))
		var ic := UiTheme.icon(_slot_tex(["carrot", "rainbow", "cat"][k]), 72)
		p.add_child(ic)
		h.add_child(p)
		_reels.append(ic)
	_slot_result = UiTheme.label("", 18, UiTheme.INK, true)
	_slot_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_result.add_theme_font_size_override("font_size", 20)
	_win_body.add_child(_slot_result)
	var bets := HBoxContainer.new()
	bets.alignment = BoxContainer.ALIGNMENT_CENTER
	bets.add_theme_constant_override("separation", 8)
	for b in [[0.1, "10%"], [0.25, "25%"], [0.5, "50%"], [1.0, "올인!"]]:
		var btn := UiTheme.button(b[1], func(): _spin(float(b[0])), Data.town_tile(93), 100)
		btn.custom_minimum_size.y = 44
		bets.add_child(btn)
	_win_body.add_child(bets)
	var pay := HBoxContainer.new()
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	for sy in Sim.SLOT_SYMBOLS:
		if float(sy.x3) <= 0: continue
		pay.add_child(UiTheme.icon(_slot_tex(sy.id), 20))
		pay.add_child(UiTheme.label("×%d  " % int(sy.x3), 10, UiTheme.INK_SOFT, true))
	_win_body.add_child(pay)


func _spin(frac: float) -> void:
	if _spinning or not sim.can_build_now(): return
	var bet := floorf(float(sim.s.coins) * frac)
	if bet < 1: return
	var r := sim.slot_spin(bet)
	if r.is_empty(): return
	_spinning = true
	_slot_result.text = ""
	Sound.play("coin")
	var syms := ["carrot", "corn", "tomato", "strawberry", "pumpkin", "cat", "rainbow", "zombie"]
	for k in 3:
		var stop_at := 0.6 + k * 0.45 + (0.7 if k == 2 and r.reels[0] == r.reels[1] else 0.0)  # 두 개가 맞으면 마지막 릴을 질질 끈다
		var t := 0.0
		while t < stop_at:
			for j in range(k, 3):
				_reels[j].texture = _slot_tex(syms[randi() % syms.size()])
			Sound.play("slot_tick", 0.1, -8.0)
			await get_tree().create_timer(0.06, true).timeout
			t += 0.06
			if not is_instance_valid(_slot_result):
				_spinning = false
				return
		_reels[k].texture = _slot_tex(r.reels[k])
		_pop(_reels[k], 1.25)
		Sound.play("slot_stop")
	_spinning = false
	match r.kind:
		"jackpot":
			_slot_result.text = "잭팟!!! ×%d  +%s" % [int(r.mult), Data.fmt(r.win)]
			_slot_result.add_theme_color_override("font_color", Color("#ff4fa8"))
			Sound.play("jackpot")
			_flash_screen(Color(1, 0.85, 1), 0.6)
			if r.bonus != "": _mini_banner("%s 합류!" % r.bonus, UiTheme.GOLD)
		"big":
			_slot_result.text = "대박! ×%d  +%s" % [int(r.mult), Data.fmt(r.win)]
			_slot_result.add_theme_color_override("font_color", UiTheme.GOOD)
			Sound.play("bigwin")
			_flash_screen(Color(1, 1, 0.6), 0.3)
		"small":
			_slot_result.text = "+%s" % Data.fmt(r.win)
			_slot_result.add_theme_color_override("font_color", UiTheme.GOOD)
			Sound.play("coins")
		"refund":
			_slot_result.text = "본전"
			_slot_result.add_theme_color_override("font_color", UiTheme.INK)
		_:
			_slot_result.text = "꽝…  -%s" % Data.fmt(r.bet)
			_slot_result.add_theme_color_override("font_color", UiTheme.WARN)
			Sound.play("lose")
	_pop(_slot_result, 1.3)


# ═════════════════════════════════════════════════════════
# 모달 (축복 드래프트 · 입양 · 엔딩 · 메뉴) — 열려 있는 동안 게임 정지
# ═════════════════════════════════════════════════════════

var _modal_queue: Array = []
var _modal_node: Control
var _cur_modal: Dictionary = {}


func _queue_dialog(_lines: Array, title: String) -> void:
	_title_card(title, UiTheme.CREAM)


func _popup(title: String, body: String, icon: Texture2D = null, buttons: Array = []) -> void:
	_queue_modal({"type": "popup", "title": title, "body": body, "icon": icon, "buttons": buttons})


func _queue_modal(m: Dictionary) -> void:
	_modal_queue.append(m)
	if not _modal_open: _next_modal()


func _next_modal() -> void:
	if is_instance_valid(_modal_node): _modal_node.queue_free()
	_modal_node = null
	if _modal_queue.is_empty():
		if _modal_open:
			_modal_open = false
			Game.modal_pause = maxi(0, Game.modal_pause - 1)
		return
	if not _modal_open:
		_modal_open = true
		Game.modal_pause += 1
	_cur_modal = _modal_queue.pop_front()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.6)
	dim.size = Vector2(960, 540)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_modal_node = dim
	match _cur_modal.type:
		"draft": _open_draft(dim)
		"gacha": _open_gacha(dim)
		"popup": _open_popup(dim)
		"ending": _open_ending(dim)


func _open_draft(dim: Control) -> void:
	var res: Dictionary = _cur_modal.res
	var v := VBoxContainer.new()
	v.position = Vector2(0, 60)
	v.custom_minimum_size = Vector2(960, 0)
	v.add_theme_constant_override("separation", 10)
	dim.add_child(v)
	var t := UiTheme.label("%d일째 밤 생존!" % int(res.night), 28, UiTheme.GOLD, true)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", Color("#1a1024"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := "처치 %d    +%s    씨앗 +%d" % [int(res.kills), Data.fmt(float(res.coins)), int(res.seeds)]
	if res.has("interest"): sub += "    이자 +%s" % Data.fmt(float(res.interest))
	for n in res.dead: sub += "\n%s…" % n
	var sl := UiTheme.label(sub, 12, UiTheme.CREAM, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	_fill_draft(row)
	var rr := UiTheme.button("다시 뽑기  씨앗 %d" % sim.reroll_cost(), func(): pass, Data.farm_tile(9), 180)
	rr.pressed.connect(func():
		if sim.reroll_draft():
			for n in row.get_children(): n.queue_free()
			_fill_draft(row)
		else:
			Sound.play("error")
		rr.text = "다시 뽑기  씨앗 %d" % sim.reroll_cost())
	rr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rr.custom_minimum_size.y = 34
	v.add_child(rr)


func _fill_draft(row: HBoxContainer) -> void:
	for k in sim.draft.size():
		var p := Perks.by_id(sim.draft[k])
		var rar: Dictionary = Perks.RARITY[int(p.r)]
		var card := Button.new()
		card.custom_minimum_size = Vector2(170, 230)
		card.focus_mode = Control.FOCUS_NONE
		var sb := UiTheme.box(10, 10, 10)
		card.add_theme_stylebox_override("normal", sb)
		card.add_theme_stylebox_override("hover", UiTheme.box(10, 10, 10, Color(1.1, 1.1, 1.0)))
		card.add_theme_stylebox_override("pressed", sb)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var glow := ColorRect.new()
		glow.color = rar.color
		glow.custom_minimum_size = Vector2(150, 6)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(glow)
		var rl := UiTheme.label(rar.name, 10, Color(rar.color).darkened(0.3), true)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rl)
		var ic := UiTheme.icon(Perks.icon(p), 64)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nl := UiTheme.label(p.name, 14, UiTheme.INK, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
		var dl := UiTheme.label(p.desc, 12, UiTheme.INK_SOFT)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 150
		v.add_child(dl)
		if sim.pk(p.id) > 0:
			var st := UiTheme.label("보유 %d" % sim.pk(p.id), 10, UiTheme.GOOD, true)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(st)
		var id: String = p.id
		var r := int(p.r)
		card.pressed.connect(func():
			sim.take_perk(id)
			Sound.play("legend" if r == 3 else ("rare" if r >= 1 else "confirm"))
			_flash_screen(rar.color, 0.3)
			_next_modal())
		card.mouse_entered.connect(func():
			Sound.play("hover", 0.1, -8.0)
			_pop(card, 1.04))
		row.add_child(card)
		# 한 장씩 뒤집히며 등장
		card.modulate = Color(1, 1, 1, 0)
		card.pivot_offset = Vector2(85, 115)
		card.scale = Vector2(0.1, 1.0)
		var tw := card.create_tween()
		tw.tween_interval(0.15 + k * 0.22)
		tw.tween_callback(func(): Sound.play("card"))
		tw.tween_property(card, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		if r >= 2:
			tw.tween_callback(func():
				Sound.play("legend" if r == 3 else "rare")
				_flash_screen(rar.color, 0.25))


func _open_gacha(dim: Control) -> void:
	var c: Dictionary = _cur_modal.cat
	var rar: Dictionary = Data.rarities[int(c.rarity)]
	var box := UiTheme.icon(Data.farm_tile(74), 96)
	box.position = Vector2(432, 180)
	box.pivot_offset = Vector2(48, 48)
	dim.add_child(box)
	var tw := box.create_tween()
	for k in 6 + int(c.rarity) * 3:
		tw.tween_property(box, "rotation", 0.25 * (1 if k % 2 == 0 else -1), 0.07)
		tw.tween_callback(func(): Sound.play("slot_tick", 0.2, -4.0))
	tw.tween_property(box, "scale", Vector2(1.6, 1.6), 0.12)
	tw.tween_callback(func():
		box.visible = false
		_flash_screen(Color(rar.color), 0.5)
		Sound.play(["pop", "rare", "rare", "legend"][int(c.rarity)])
		Sound.play("meow")
		var cat := UiTheme.icon(Data.t("sprites/icons/cat_%s_%d.png" % [c.job, int(c.fur)]), 128)
		cat.position = Vector2(416, 150)
		dim.add_child(cat)
		_pop(cat, 1.3)
		var l := UiTheme.label("%s  %s" % [rar.name, Data.job_by_id[c.job].name], 28, Color(rar.color), true)
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color("#1a1024"))
		l.position = Vector2(0, 300)
		l.custom_minimum_size.x = 960
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dim.add_child(l)
		var ok := UiTheme.button("좋아!", func(): _next_modal(), null, 120)
		ok.position = Vector2(420, 360)
		dim.add_child(ok))


func _open_popup(dim: Control) -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := HBoxContainer.new()
	if _cur_modal.icon: h.add_child(UiTheme.icon(_cur_modal.icon, 40))
	h.add_child(UiTheme.label(_cur_modal.title, 14, UiTheme.INK, true))
	v.add_child(h)
	if _cur_modal.body != "":
		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		body.fit_content = true
		body.custom_minimum_size = Vector2(280, 10)
		body.text = _cur_modal.body
		v.add_child(body)
	var btns: Array = _cur_modal.buttons
	if btns.is_empty(): btns = [["확인", func(): pass]]
	for b in btns:
		var cb: Callable = b[1]
		var btn := UiTheme.button(b[0], func():
			_next_modal()
			cb.call(), null, 200)
		btn.custom_minimum_size.y = 32
		v.add_child(btn)
	await get_tree().process_frame
	if is_instance_valid(p): p.position = (Vector2(960, 540) - p.size) / 2.0
	Sound.play("open")


func _open_ending(dim: Control) -> void:
	dim.color = Color(0.03, 0.02, 0.06, 0.94)
	Sound.music("ending")
	var v := VBoxContainer.new()
	v.position = Vector2(180, 560)
	v.custom_minimum_size = Vector2(600, 0)
	dim.add_child(v)
	var lines := [["FARMEOW", 28], ["", 12],
		["함께한 고양이 %d · 무지개다리 %d" % [sim.alive_cats().size(), sim.s.memorial.size()], 12],
		["생존한 밤 %d · 최대 콤보 %d" % [int(sim.s.stats.won), int(sim.s.get("combo_best", 0))], 12], ["", 12],
		["기획·개발  halfcodz", 12], ["원작  냥이농장", 12], ["", 12],
		["Kenney · Juhani Junkala · OpenGameArt 작가들 · Galmuri(quiple)", 10], ["", 12], ["고마워요!", 18]]
	for l in lines:
		var lb := UiTheme.label(l[0], l[1], UiTheme.CREAM if l[1] < 18 else UiTheme.GOLD, l[1] >= 18)
		if l[1] >= 28: lb.add_theme_font_size_override("font_size", 40)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.custom_minimum_size.x = 600
		v.add_child(lb)
	var tw := v.create_tween()
	tw.tween_property(v, "position:y", -300.0, 22.0)
	tw.tween_callback(func():
		if _cur_modal.get("type", "") == "ending": _next_modal())
	var skip := UiTheme.button("✕", func(): _next_modal(), null, 40)
	skip.position = Vector2(900, 20)
	dim.add_child(skip)


func _confirm_prestige() -> void:
	_close_window()
	_popup("환생", "별사탕 +%d · 1장부터 다시" % sim.prestige_candy(), Data.food("candy_corn"), [["환생!", func(): sim.do_prestige()], ["취소", func(): pass]])


func _open_menu() -> void:
	_popup("메뉴", "", Data.farm_tile(108), [["계속", func(): pass], ["설정", func(): _open_settings()], ["저장하고 타이틀로", func():
		Game.save_game()
		quit_to_title.emit()]])


func _open_settings() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.6)
	dim.size = Vector2(960, 540)
	add_child(dim)
	Game.modal_pause += 1
	var p := PanelContainer.new()
	p.position = Vector2(300, 120)
	p.custom_minimum_size = Vector2(360, 280)
	dim.add_child(p)
	p.add_child(SettingsPanel.build(func():
		Game.modal_pause = maxi(0, Game.modal_pause - 1)
		dim.queue_free()))
