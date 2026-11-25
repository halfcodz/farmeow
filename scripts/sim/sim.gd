class_name Sim
extends RefCounted
## 냥이농장 시뮬레이션 코어. 상태(s)는 JSON으로 저장 가능한 Dictionary,
## 밤 전투용 개체(좀비/투사체)는 저장하지 않는 임시 데이터다.
## (밤 도중 종료하면 그 밤을 처음부터 다시 한다.)

signal event(kind: String, data: Dictionary)

const TICK := 1.0 / 20.0
const G := 11            # 밭 한 변 (넓힌 농장)
const C := 5             # 중앙 칸
const N := G * G
const CF := C + 0.5      # 중앙 좌표
const SAVE_VERSION := 2

var s: Dictionary = {}

# ── 임시 상태 ─────────────────────────────────────────────
var zombies: Array = []
var shots: Array = []
var fx: Array = []          # 화면 효과 (월드 뷰가 소비)
var cat_rt := {}            # uid → {pos, task, ...}
var plan: Dictionary = {}
var spawn_i := 0
var house_hp := 0.0
var house_max := 1.0
var night_kills := 0
var night_coins := 0.0
var night_lost_lives := 0
var night_failed := false
var night_over := false
var _zid := 0
var _rng := RandomNumberGenerator.new()
var _sell_t := 0.0
var _chef_t := 0.0
var _auto_t := 0.0
var _free_t := 0.0
var day_income := 0.0
var combo := 0
var combo_t := 0.0
var golden_at := -1.0
var draft: Array = []
var _reveal_t := 0.0
var offline := false
var last_result: Dictionary = {}


# ═════════════════════════════════════════════════════════
# 새 게임 / 불러오기
# ═════════════════════════════════════════════════════════

func new_game(difficulty: String = "normal", keep: Dictionary = {}) -> void:
	_rng.randomize()
	var tiles := []
	for i in N:
		tiles.append({"open": false, "kind": "", "id": "", "prog": 0.0, "stars": 0, "hp": 0.0, "wilted": false, "plan": ""})
	s = {
		"version": SAVE_VERSION, "difficulty": difficulty,
		"day": 1, "phase": "day", "t": 0.0, "speed": 1,
		"coins": 60.0, "seeds": 3, "fodder": 6, "candy": 0, "prestige": 0,
		"candy_up": {"yield": 0, "sell": 0, "catatk": 0, "offline": 0},
		"tiles": tiles, "storage": {}, "cats": [], "next_uid": 1,
		"research": {}, "toggles": {"auto_sell": false, "auto_plant": true, "auto_reclaim": false, "auto_feed": true},
		"stats": {"harvest": {}, "kills": {}, "built": {}, "earned": 0.0, "won": 0, "lost": 0, "cats_lost": 0, "best_day": 1, "stars": 0},
		"memorial": [], "chapter": 1, "goals": [], "boss_cleared": {}, "seen_intro": [], "campaign_clear": false,
		"income_rate": 0.0, "last_saved": Time.get_unix_time_from_system(), "playtime": 0.0,
		"perks": {}, "ui": {}, "combo_best": 0, "rerolls": 0, "slot": {"spins": 0, "best": 0.0},
	}
	if not keep.is_empty():
		for k in keep: s[k] = keep[k]
	for i in [_i(C, C - 2), _i(C, C + 2), _i(C - 2, C), _i(C + 2, C), _i(C, 0), _i(C, G - 1), _i(0, C), _i(G - 1, C)]:
		s.tiles[i].open = true
	_add_cat("farmer", 0, 1, "나비")
	_reset_goals()
	_sync_cats()


func load_state(d: Dictionary) -> void:
	s = d
	# 9x9 시절 저장 → 11x11 가운데로 옮긴다
	if s.tiles.size() == 81:
		var nt := []
		for i in N:
			nt.append({"open": false, "kind": "", "id": "", "prog": 0.0, "stars": 0, "hp": 0.0, "wilted": false, "plan": ""})
		for i in 81:
			nt[_i(i % 9 + 1, i / 9 + 1)] = s.tiles[i]
		s.tiles = nt
	_rng.randomize()
	if s.phase == "night" or s.phase == "dusk":
		s.phase = "dusk"   # 밤은 처음부터 다시
		s.t = 0.0
	for c in s.cats:
		c.down = false
	_sync_cats()


static func _i(x: int, y: int) -> int:
	return y * G + x


static func tx(i: int) -> int:
	return i % G


static func ty(i: int) -> int:
	return i / G


func emit(kind: String, data: Dictionary = {}) -> void:
	event.emit(kind, data)


func toast(text: String, color: String = "") -> void:
	emit("toast", {"text": text, "color": color})


func diff() -> Dictionary:
	return Data.DIFFICULTY[s.difficulty]


func chapter() -> Dictionary:
	for c in Data.chapters:
		if int(c.id) == int(s.chapter):
			return c
	return {}


# ═════════════════════════════════════════════════════════
# 보정치 (연구 / 별사탕 / 대장냥)
# ═════════════════════════════════════════════════════════

func rlv(id: String) -> int:
	return int(s.research.get(id, 0))


func rstep(id: String) -> float:
	return rlv(id) * float(Data.research_by_id[id].step)


func research_total() -> int:
	var n := 0
	for k in s.research: n += int(s.research[k])
	return n


func has_job(job: String) -> bool:
	for c in s.cats:
		if c.alive and c.job == job: return true
	return false


func count_job(job: String) -> int:
	var n := 0
	for c in s.cats:
		if c.alive and c.job == job: n += 1
	return n


func captain_mul() -> float:
	return 1.12 if has_job("captain") else 1.0


func pk(id: String) -> int:
	return int(s.get("perks", {}).get(id, 0))


func grow_mul() -> float:
	return (1.0 + 0.12 * pk("grow")) / maxf(0.2, 1.0 - rstep("growSpeed"))


func yield_mul() -> float:
	return 1.0 + rstep("yieldUp") + 0.1 * int(s.candy_up.yield) + 0.1 * pk("yield")


func sell_mul() -> float:
	return (1.0 + rstep("sellPrice") + 0.1 * int(s.candy_up.sell) + 0.1 * pk("price")) * (1.0 + 0.2 * mini(count_job("merchant"), 3))


func storage_cap() -> int:
	return 60 + int(rstep("storage"))


func storage_used() -> int:
	var n := 0
	for k in s.storage: n += int(s.storage[k])
	return n


func cat_cap() -> int:
	return mini(Data.CAT_CAP_MAX, Data.CAT_CAP_BASE + rlv("catCap"))


func offline_cap_hours() -> float:
	return 8.0 + rstep("offlineCap") + 2.0 * int(s.candy_up.offline)


func alive_cats() -> Array:
	return s.cats.filter(func(c): return c.alive)


# ═════════════════════════════════════════════════════════
# 타일
# ═════════════════════════════════════════════════════════

func tile(i: int) -> Dictionary:
	return s.tiles[i]


func zone_open_day(zone: String) -> int:
	return int(Data.ZONE_UNLOCK[zone].day) if Data.ZONE_UNLOCK.has(zone) else 999


func unlocked_in_zone(zone: String) -> int:
	var n := 0
	for i in N:
		if s.tiles[i].open and Data.zone_of(tx(i), ty(i)) == zone: n += 1
	return n


func open_tiles() -> int:
	var n := 0
	for t in s.tiles:
		if t.open: n += 1
	return n


func unlock_cost(i: int) -> int:
	var z := Data.zone_of(tx(i), ty(i))
	if z == "house" or s.tiles[i].open: return -1
	var cfg: Dictionary = Data.ZONE_UNLOCK[z]
	if s.day < int(cfg.day): return -1
	return int(ceil(float(cfg.base) * pow(float(cfg.mult), unlocked_in_zone(z))))


func unlock_tile(i: int) -> bool:
	var c := unlock_cost(i)
	if c < 0:
		var z := Data.zone_of(tx(i), ty(i))
		if z != "house" and Data.ZONE_UNLOCK.has(z):
			toast("%s 구역은 %d일째부터 개간할 수 있어요" % [_zone_name(z), zone_open_day(z)], "warn")
		return false
	if s.coins < c:
		toast("코인이 부족해요 (%s 필요)" % Data.fmt(c), "warn")
		emit("sfx", {"name": "error"})
		return false
	s.coins -= c
	s.tiles[i].open = true
	emit("sfx", {"name": "unlock"})
	emit("fx", {"k": "dust", "i": i})
	_check_goals()
	return true


func _zone_name(z: String) -> String:
	return {"A": "안쪽 밭", "B": "가운데 밭", "C": "바깥 밭", "D": "들판 끝"}.get(z, z)


func can_build_now() -> bool:
	return s.phase == "day" or s.phase == "dusk" or s.phase == "dawn"


func crop_unlocked(id: String) -> bool:
	return int(Data.crop_by_id[id].unlockDay) <= int(s.day) or s.prestige > 0 and int(Data.crop_by_id[id].unlockDay) <= int(s.stats.best_day)


func def_unlocked(id: String) -> bool:
	return int(Data.def_by_id[id].unlockDay) <= int(s.day) or s.prestige > 0 and int(Data.def_by_id[id].unlockDay) <= int(s.stats.best_day)


func plant(i: int, crop_id: String, quiet: bool = false) -> bool:
	var t := tile(i)
	if not t.open or t.kind != "": return false
	if not can_build_now():
		if not quiet: toast("밤에는 심을 수 없어요", "warn")
		return false
	if not crop_unlocked(crop_id): return false
	var cost := float(Data.crop_by_id[crop_id].seedCost)
	if s.coins < cost:
		if not quiet:
			toast("코인이 부족해요", "warn")
			emit("sfx", {"name": "error"})
		return false
	s.coins -= cost
	t.kind = "crop"; t.id = crop_id; t.prog = 0.0; t.plan = crop_id
	if not quiet: emit("sfx", {"name": "plant"})
	emit("fx", {"k": "dust", "i": i})
	return true


func build(i: int, def_id: String) -> bool:
	var t := tile(i)
	if not t.open or t.kind != "": return false
	if not can_build_now():
		toast("밤에는 심을 수 없어요", "warn")
		return false
	var d: Dictionary = Data.def_by_id[def_id]
	if not def_unlocked(def_id): return false
	if s.coins < float(d.cost):
		toast("코인이 부족해요", "warn")
		emit("sfx", {"name": "error"})
		return false
	s.coins -= float(d.cost)
	t.kind = "turret"; t.id = def_id; t.prog = 0.0; t.stars = 0; t.wilted = false
	t.hp = turret_max_hp(t); t.plan = ""
	s.stats.built[def_id] = int(s.stats.built.get(def_id, 0)) + 1
	emit("sfx", {"name": "plant"})
	emit("fx", {"k": "dust", "i": i})
	_check_goals()
	return true


func clear_tile(i: int) -> void:
	var t := tile(i)
	if t.kind == "turret":
		var refund := float(Data.def_by_id[t.id].cost) * 0.3
		s.coins += refund
		toast("갈아엎었어요 (+%s 환급)" % Data.fmt(refund))
	t.kind = ""; t.id = ""; t.prog = 0.0; t.stars = 0; t.plan = ""; t.wilted = false
	emit("sfx", {"name": "plant"})


func upgrade_turret(i: int) -> bool:
	var t := tile(i)
	if t.kind != "turret" or int(t.stars) >= 3: return false
	var seeds := Data.upgrade_seed_cost(int(t.stars))
	var coins := float(Data.def_by_id[t.id].cost) * (int(t.stars) + 1)
	if s.seeds < seeds or s.coins < coins:
		toast("씨앗 %d개 · 코인 %s 필요" % [seeds, Data.fmt(coins)], "warn")
		emit("sfx", {"name": "error"})
		return false
	s.seeds -= seeds
	s.coins -= coins
	t.stars = int(t.stars) + 1
	t.hp = turret_max_hp(t)
	s.stats.stars = int(s.stats.stars) + 1
	emit("sfx", {"name": "levelup"})
	emit("fx", {"k": "star", "i": i})
	_check_goals()
	return true


func crop_grow_time(id: String) -> float:
	return float(Data.crop_by_id[id].growTime) / grow_mul()


func crop_ripe(t: Dictionary) -> bool:
	return t.kind == "crop" and float(t.prog) >= crop_grow_time(t.id)


func turret_ready(t: Dictionary) -> bool:
	return t.kind == "turret" and float(t.prog) >= float(Data.def_by_id[t.id].growTime)


func turret_max_hp(t: Dictionary) -> float:
	return float(Data.def_by_id[t.id].hp) * Data.star_mul(int(t.stars)) * (1.0 + rstep("turretHp"))


func harvest(i: int, by_cat: bool = false) -> bool:
	var t := tile(i)
	if not crop_ripe(t): return false
	if storage_used() >= storage_cap():
		if not by_cat:
			toast("창고가 가득 찼어요! 판매하세요 (S)", "warn")
			emit("sfx", {"name": "error"})
		return false
	var d: Dictionary = Data.crop_by_id[t.id]
	var qty := maxi(1, int(round(float(d.yield) * yield_mul())))
	if by_cat and _rng.randf() < 0.05: qty *= 2
	# 대박 / 초대박 — 수확의 도파민
	var roll := _rng.randf()
	var luck := 0.04 * pk("jackpot")
	var jp := 0
	if roll < 0.012 + luck * 0.25:
		jp = 2; qty *= 10
	elif roll < 0.07 + luck:
		jp = 1; qty *= 3
	if jp > 0:
		emit("jackpot", {"i": i, "level": jp, "id": t.id, "n": qty})
	s.storage[t.id] = int(s.storage.get(t.id, 0)) + qty
	s.stats.harvest[t.id] = int(s.stats.harvest.get(t.id, 0)) + qty
	if _rng.randf() < 0.02 + rstep("seedLuck") + 0.03 * pk("seedluck"):
		s.seeds += 1
		emit("fx", {"k": "text", "i": i, "text": "+씨앗", "color": "seed"})
	emit("fx", {"k": "harvest", "i": i, "id": t.id, "n": qty})
	emit("sfx", {"name": "harvest"})
	var replant: String = t.plan
	if pk("regrow") > 0 and _rng.randf() < 0.15 * pk("regrow"):
		t.prog = 0.0
		t.prog = crop_grow_time(t.id) * 0.999
		emit("fx", {"k": "star", "i": i})
		_check_goals()
		return true
	t.kind = ""; t.id = ""; t.prog = 0.0
	if s.toggles.auto_plant and replant != "":
		if not plant(i, replant, true):
			t.plan = replant
	if s.toggles.auto_sell or has_job("merchant"):
		_sell_t = 0.6
	_check_goals()
	return true


func harvest_all() -> int:
	var n := 0
	for i in N:
		if harvest(i, true): n += 1
	if n == 0: toast("다 자란 작물이 없어요")
	return n


func sell(id: String, n: int = -1) -> float:
	var have := int(s.storage.get(id, 0))
	var k := have if n < 0 else mini(n, have)
	if k <= 0: return 0.0
	var gain := floorf(float(Data.crop_by_id[id].unitPrice) * k * sell_mul())
	s.storage[id] = have - k
	if int(s.storage[id]) <= 0: s.storage.erase(id)
	_earn(gain)
	return gain


func sell_all(reserve_for_chef: bool = false) -> float:
	var total := 0.0
	var reserve := 10 if reserve_for_chef and has_job("chef") and storage_used() < storage_cap() * 0.9 else 0
	for id in s.storage.keys():
		var have := int(s.storage[id])
		if have > reserve:
			total += sell(id, have - reserve)
	if total > 0:
		emit("sfx", {"name": "coins"})
		emit("fx", {"k": "coins", "v": total})
	return total


func _earn(v: float) -> void:
	v *= 1.0 + 0.5 * pk("midas")
	s.coins += v
	s.stats.earned = float(s.stats.earned) + v
	day_income += v


# ═════════════════════════════════════════════════════════
# 고양이
# ═════════════════════════════════════════════════════════

func job_unlocked(job: String) -> bool:
	var j: Dictionary = Data.job_by_id[job]
	if int(j.unlockDay) < 0: return s.prestige > 0
	return int(j.unlockDay) <= int(s.day)


func _add_cat(job: String, rarity: int, level: int, name: String = "") -> Dictionary:
	if name == "":
		var used := {}
		for c in s.cats: used[c.name] = true
		var pool := Data.cat_names.filter(func(n): return not used.has(n))
		name = pool[_rng.randi() % pool.size()] if pool.size() > 0 else "냥이%d" % s.next_uid
	var c := {"uid": int(s.next_uid), "name": name, "job": job, "rarity": rarity, "level": level, "xp": 0,
		"lives": Data.CAT_MAX_LIVES, "hp": 0.0, "full": 100.0, "assign": "free", "alive": true, "down": false,
		"fur": (int(s.next_uid) * 7 + rarity * 3) % 6, "nurse_cd": 0, "kills": 0, "joined": int(s.day)}
	s.next_uid = int(s.next_uid) + 1
	c.hp = cat_max_hp(c)
	s.cats.append(c)
	_sync_cats()
	return c


func start_level() -> int:
	return clampi(int(floor(s.day * 0.45)), 1, 26)


func hire(job: String) -> bool:
	if not job_unlocked(job): return false
	if alive_cats().size() >= cat_cap():
		toast("냥이집이 꽉 찼어요 (연구: 냥이집 증축)", "warn")
		emit("sfx", {"name": "error"})
		return false
	var cost := Data.hire_cost(Data.job_by_id[job], alive_cats().size())
	if s.coins < cost:
		toast("코인이 부족해요 (%s)" % Data.fmt(cost), "warn")
		emit("sfx", {"name": "error"})
		return false
	s.coins -= cost
	var c := _add_cat(job, 0, start_level())
	toast("%s %s 합류!" % [Data.job_by_id[job].name, c.name], "good")
	emit("sfx", {"name": "hire"})
	_check_goals()
	return true


func adopt() -> Dictionary:
	if alive_cats().size() >= cat_cap():
		toast("냥이집이 꽉 찼어요", "warn")
		return {}
	if s.seeds < Data.ADOPT_SEED_COST:
		toast("씨앗 %d개가 필요해요" % Data.ADOPT_SEED_COST, "warn")
		emit("sfx", {"name": "error"})
		return {}
	s.seeds -= Data.ADOPT_SEED_COST
	var pool := Data.jobs.filter(func(j): return job_unlocked(j.id))
	var job: String = pool[_rng.randi() % pool.size()].id
	var roll := _rng.randf() * 100.0
	var rar := 0
	var acc := 0.0
	for r in Data.rarities:
		acc += float(r.weight)
		if roll < acc:
			rar = int(r.id)
			break
	var c := _add_cat(job, rar, start_level())
	toast("입양! %s %s (%s)" % [Data.rarities[rar].name, Data.job_by_id[job].name, c.name], "good")
	emit("sfx", {"name": "hire"})
	_check_goals()
	return c


func cat_mul(c: Dictionary) -> float:
	return float(Data.rarities[int(c.rarity)].mul) * Data.level_mul(int(c.level)) * captain_mul()


func cat_max_hp(c: Dictionary) -> float:
	return float(Data.job_by_id[c.job].hp) * cat_mul(c) * (1.0 + rstep("catHp") + 0.15 * pk("cathp")) * (1.0 + 0.4 * pk("catgod"))


func cat_atk(c: Dictionary) -> float:
	var a := float(Data.job_by_id[c.job].atk) * cat_mul(c) * (1.0 + rstep("catAtk") + 0.1 * int(s.candy_up.catatk) + 0.15 * pk("catatk")) * (1.0 + 0.4 * pk("catgod"))
	if float(c.full) < 30.0: a *= 0.5
	return a


func cat_by_uid(uid: int) -> Dictionary:
	for c in s.cats:
		if int(c.uid) == uid: return c
	return {}


func assign(uid: int, dir: String) -> void:
	var c := cat_by_uid(uid)
	if c.is_empty(): return
	c.assign = dir
	emit("sfx", {"name": "toggle"})


func feed_all() -> int:
	var fed := 0
	var cats := alive_cats()
	cats.sort_custom(func(a, b): return float(a.full) < float(b.full))
	for c in cats:
		if int(s.fodder) <= 0: break
		if float(c.full) <= 70.0:
			c.full = minf(100.0, float(c.full) + 40.0)
			s.fodder = int(s.fodder) - 1
			fed += 1
	if fed > 0: emit("sfx", {"name": "eat"})
	return fed


func fodder_price() -> int:
	return int(ceil(12.0 * pow(1.09, s.day)))


func buy_fodder(n: int = 5) -> bool:
	var cost := fodder_price() * n
	if s.coins < cost:
		toast("코인이 부족해요", "warn")
		emit("sfx", {"name": "error"})
		return false
	s.coins -= cost
	s.fodder = int(s.fodder) + n
	emit("sfx", {"name": "coin"})
	return true


func is_combat(c: Dictionary) -> bool:
	return Data.job_by_id[c.job].line != "farm"


func _sync_cats() -> void:
	for c in s.cats:
		if not c.alive:
			cat_rt.erase(c.uid)
			continue
		if not cat_rt.has(c.uid):
			cat_rt[c.uid] = {"pos": Vector2(CF + _rng.randf_range(-0.8, 0.8), CF + _rng.randf_range(-0.8, 0.8)),
				"task": "idle", "target": -1, "t": 0.0, "cd": 0.0, "stack": 0, "anim": "idle", "flip": false,
				"post": Vector2(CF, CF), "wander": 0.0, "act": 0.0}


# ═════════════════════════════════════════════════════════
# 연구 / 별사탕
# ═════════════════════════════════════════════════════════

func research_up(id: String) -> bool:
	var r: Dictionary = Data.research_by_id[id]
	var lv := rlv(id)
	if lv >= int(r.maxLevel): return false
	var cost := Data.research_cost(r, lv)
	if s.coins < cost:
		toast("코인이 부족해요 (%s)" % Data.fmt(cost), "warn")
		emit("sfx", {"name": "error"})
		return false
	s.coins -= cost
	s.research[id] = lv + 1
	for c in s.cats:
		if c.alive: c.hp = minf(float(c.hp), cat_max_hp(c))
	emit("sfx", {"name": "levelup"})
	_check_goals()
	return true


func candy_cost(key: String) -> int:
	return int(pow(2, int(s.candy_up[key]))) * 2


func candy_up(key: String) -> bool:
	var cost := candy_cost(key)
	if int(s.candy) < cost: return false
	s.candy = int(s.candy) - cost
	s.candy_up[key] = int(s.candy_up[key]) + 1
	emit("sfx", {"name": "levelup"})
	return true


func prestige_candy() -> int:
	return int(floor(sqrt(float(s.stats.earned) / 1e6))) + int(s.day) * 2


func can_prestige() -> bool:
	return bool(s.campaign_clear)


func do_prestige() -> void:
	var keep := {
		"candy": int(s.candy) + prestige_candy(), "prestige": int(s.prestige) + 1,
		"candy_up": s.candy_up, "stats": s.stats, "memorial": s.memorial,
		"campaign_clear": true, "difficulty": s.difficulty, "playtime": s.playtime,
	}
	keep.stats.best_day = maxi(int(keep.stats.best_day), int(s.day))
	var legend := {}
	for c in s.cats:
		if c.alive and int(c.rarity) == 3:
			legend = c.duplicate()
			break
	new_game(s.difficulty, keep)
	s.coins += 200.0 * (int(s.prestige))
	s.seeds += 4 * int(s.prestige)
	if not legend.is_empty():
		legend.level = 1; legend.lives = Data.CAT_MAX_LIVES
		legend.uid = int(s.next_uid); s.next_uid = int(s.next_uid) + 1
		s.cats.append(legend)
		_sync_cats()
	toast("냥생 %d회차 시작! 별사탕 %d개" % [int(s.prestige) + 1, int(s.candy)], "good")


# ═════════════════════════════════════════════════════════
# 장(챕터) · 목표 — 레벨 디자인의 뼈대
# ═════════════════════════════════════════════════════════

func _reset_goals() -> void:
	var ch := chapter()
	s.goals = []
	if ch.is_empty(): return
	for g in ch.goals:
		s.goals.append(false)


func goal_progress(g: Dictionary) -> Array:
	var n := int(g.get("n", 1))
	match g.type:
		"harvest": return [int(s.stats.harvest.get(g.id, 0)), n]
		"hire": return [count_job(g.id), n]
		"build": return [int(s.stats.built.get(g.id, 0)), n]
		"kill": return [int(s.stats.kills.get(g.id, 0)), n]
		"unlock_zone": return [unlocked_in_zone(g.id), n]
		"tiles": return [open_tiles(), n]
		"coins": return [int(s.coins), n]
		"research": return [research_total(), n]
		"star": return [int(s.stats.stars), n]
		"cats": return [alive_cats().size(), n]
		"boss": return [1 if s.boss_cleared.has(str(n)) else 0, 1]
	return [0, 1]


func _check_goals() -> void:
	var ch := chapter()
	if ch.is_empty(): return
	for gi in ch.goals.size():
		if gi >= s.goals.size(): s.goals.append(false)
		if s.goals[gi]: continue
		var p := goal_progress(ch.goals[gi])
		if p[0] >= p[1]:
			s.goals[gi] = true
			s.seeds += 1
			emit("goal", {"text": ch.goals[gi].text})
			emit("sfx", {"name": "quest"})
	# 필수 목표(장의 마지막 보스 밤)를 달성하면 장 클리어
	var cleared := true
	for gi in ch.goals.size():
		if ch.goals[gi].get("required", false) and not s.goals[gi]:
			cleared = false
	if cleared:
		_clear_chapter(ch)


func _clear_chapter(ch: Dictionary) -> void:
	var all_done: bool = not s.goals.has(false)
	var rw: Dictionary = ch.reward
	var coins := float(rw.coins) * (1.5 if all_done else 1.0)
	s.coins += coins
	s.seeds += int(rw.seeds)
	emit("chapter_clear", {"chapter": ch, "all": all_done, "coins": coins, "seeds": int(rw.seeds)})
	if int(ch.id) >= Data.chapters.size():
		s.campaign_clear = true
		s.chapter = Data.chapters.size() + 1
		s.goals = []
		emit("ending", {})
	else:
		s.chapter = int(s.chapter) + 1
		_reset_goals()


func is_gate_night(n: int) -> bool:
	var ch := chapter()
	return not ch.is_empty() and int(ch.gate) == n


## 지금 상황에서 가장 필요한 한 줄 안내 (튜토리얼 비트)
func hint() -> String:
	var crops_planted := 0
	var turrets := 0
	for t in s.tiles:
		if t.kind == "crop": crops_planted += 1
		elif t.kind == "turret": turrets += 1
	if s.day == 1:
		if crops_planted == 0 and int(s.stats.harvest.get("carrot", 0)) == 0:
			return "오른쪽 [씨앗] 탭에서 당근을 고르고, 안쪽 빈 밭을 클릭해 심어 보세요"
		if int(s.stats.harvest.get("carrot", 0)) == 0:
			return "작물이 다 자라 반짝이면 클릭해서 수확! 농부냥도 알아서 거들어요"
		if turrets == 0:
			return "[방어] 탭에서 콩콩나무를 골라 바깥 테두리 길목(흙길)에 심어 두세요"
		if s.phase == "day":
			return "창고의 작물은 S키나 [판매] 버튼으로 팔아요. 준비되면 [밤 맞이]"
	if s.phase == "dusk":
		return "황혼! 왼쪽 위협도를 보고 [고양이] 탭에서 방면을 정해 주세요"
	if s.phase == "night":
		return "전투는 자동이에요. 위급하면 고양이 배치를 바꿔 보세요"
	if s.day == 2 and count_job("sword") == 0:
		return "[고양이] 탭에서 검사냥을 고용하면 밤에 함께 싸워요"
	if alive_cats().any(func(c): return float(c.full) < 30.0):
		return "배고픈 고양이가 있어요! [고양이] 탭에서 밥을 주세요 (F)"
	if storage_used() >= storage_cap():
		return "창고가 가득 찼어요. S키로 전부 판매하세요"
	if is_gate_night(int(s.day)):
		return "오늘 밤은 이 장의 마지막 보스전! 이길 때까지 같은 밤이 반복돼요"
	return ""


# ═════════════════════════════════════════════════════════
# 메인 루프
# ═════════════════════════════════════════════════════════

func tick(dt: float) -> void:
	_reveal_t -= dt
	if _reveal_t <= 0.0:
		_reveal_t = 0.5
		check_reveals()
	s.t = float(s.t) + dt
	s.playtime = float(s.playtime) + dt
	match s.phase:
		"day":
			_tick_growth(dt)
			_tick_day_cats(dt)
			_tick_economy(dt)
			if float(s.t) >= Data.PHASE_LEN.day:
				_enter_dusk()
		"dusk":
			_tick_growth(dt)
			_tick_day_cats(dt)
			if float(s.t) >= Data.PHASE_LEN.dusk:
				_enter_night()
		"night":
			_tick_growth(dt)
			_tick_night(dt)
		"dawn":
			_tick_day_cats(dt)
			if float(s.t) >= Data.PHASE_LEN.dawn:
				_enter_day()
	_tick_fx(dt)


func skip_to_dusk() -> void:
	if s.phase == "day":
		s.t = Data.PHASE_LEN.day


func phase_len() -> float:
	match s.phase:
		"night": return float(plan.get("duration", 60.0))
		_: return float(Data.PHASE_LEN.get(s.phase, 1.0))


func _enter_dusk() -> void:
	s.phase = "dusk"
	s.t = 0.0
	plan = Data.night_plan(int(s.day))
	s.income_rate = day_income / Data.PHASE_LEN.day
	emit("phase", {"phase": "dusk", "plan": plan})
	emit("sfx", {"name": "dusk"})
	if plan.newcomer != null and int(plan.night) == int(Data.zombie_by_id[plan.newcomer].firstNight):
		emit("newcomer", {"id": plan.newcomer})


func _enter_night() -> void:
	s.phase = "night"
	s.t = 0.0
	if plan.is_empty() or int(plan.get("night", 0)) != int(s.day):
		plan = Data.night_plan(int(s.day))
	zombies.clear()
	shots.clear()
	spawn_i = 0
	night_kills = 0
	night_coins = 0.0
	night_lost_lives = 0
	night_failed = false
	night_over = false
	house_max = float(plan.baseHp) * float(diff().house) * (2.0 if int(s.day) <= 5 else 1.0) * (1.0 + 0.2 * pk("house"))
	combo = 0
	combo_t = 0.0
	golden_at = -1.0
	if int(s.day) >= 3 and (_rng.randf() < 0.22 or pk("goldrain") > 0):
		golden_at = float(plan.duration) * _rng.randf_range(0.2, 0.6)
	house_hp = house_max
	for i in N:
		var t: Dictionary = s.tiles[i]
		if t.kind == "turret":
			t.hp = turret_max_hp(t)
			t.wilted = false
			t["cd"] = 0.0
	_place_night_cats()
	emit("phase", {"phase": "night", "plan": plan})
	if plan.boss != null:
		emit("sfx", {"name": "boss"})


func _enter_dawn(failed: bool) -> void:
	s.phase = "dawn"
	s.t = 0.0
	var n := int(s.day)
	var gate := is_gate_night(n)
	var res := {"night": n, "failed": failed, "kills": night_kills, "coins": night_coins, "lost": night_lost_lives,
		"boss": plan.get("boss"), "seeds": 0, "retry": false, "dead": []}
	if failed:
		s.stats.lost = int(s.stats.lost) + 1
		var loss := float(s.coins) * 0.3
		s.coins -= loss
		res.coin_loss = loss
		var crops := []
		for i in N:
			if s.tiles[i].kind == "crop": crops.append(i)
		crops.shuffle()
		for k in crops.size() / 2:
			var t: Dictionary = s.tiles[crops[k]]
			t.kind = ""; t.id = ""; t.prog = 0.0
		res.retry = gate
		emit("sfx", {"name": "fail"})
	else:
		s.stats.won = int(s.stats.won) + 1
		var seeds := 1 + (2 if plan.get("boss") != null else 0) + n / 10
		s.seeds += seeds
		res.seeds = seeds
		if plan.get("boss") != null or gate:
			s.boss_cleared[str(n)] = true
		emit("sfx", {"name": "dawn"})
		if pk("interest") > 0:
			var it := float(s.coins) * 0.03 * pk("interest")
			_earn(it)
			res["interest"] = it
		draft = roll_draft(1 if plan.get("boss") != null else 0)
		res["draft"] = draft
	# 고양이: 경험치, 회복, 간호냥 목숨 복구
	for c in s.cats:
		if not c.alive: continue
		c.down = false
		c.xp = int(c.xp) + 8 + n * 2 + (6 if is_combat(c) else 0)
		while int(c.level) < 30 and int(c.xp) >= Data.xp_to_next(int(c.level)):
			c.xp = int(c.xp) - Data.xp_to_next(int(c.level))
			c.level = int(c.level) + 1
		c.hp = cat_max_hp(c)
	for c in s.cats:
		if c.alive and c.job == "nurse":
			if int(c.nurse_cd) <= 0:
				var hurt: Array = s.cats.filter(func(x): return x.alive and int(x.lives) < Data.CAT_MAX_LIVES)
				if hurt.size() > 0:
					hurt.sort_custom(func(a, b): return int(a.lives) < int(b.lives))
					hurt[0].lives = int(hurt[0].lives) + 1
					c.nurse_cd = 3
					res["nursed"] = hurt[0].name
			else:
				c.nurse_cd = int(c.nurse_cd) - 1
	res.dead = _flush_dead()
	for i in N:
		var t: Dictionary = s.tiles[i]
		if t.kind == "turret":
			t.wilted = false
			t.hp = turret_max_hp(t)
	zombies.clear()
	shots.clear()
	if s.toggles.auto_feed: feed_all()
	if not res.retry:
		s.day = int(s.day) + 1
	s.stats.best_day = maxi(int(s.stats.best_day), int(s.day))
	last_result = res
	_check_goals()
	emit("night_result", res)
	emit("phase", {"phase": "dawn"})
	emit("save", {})


func _enter_day() -> void:
	s.phase = "day"
	s.t = 0.0
	day_income = 0.0
	for c in s.cats:
		if c.alive and cat_rt.has(c.uid):
			cat_rt[c.uid].task = "idle"
	emit("phase", {"phase": "day"})
	var ch := chapter()
	if not ch.is_empty() and not s.seen_intro.has(int(ch.id)):
		s.seen_intro.append(int(ch.id))
		emit("dialog", {"lines": ch.intro, "title": ch.title})


func _flush_dead() -> Array:
	var dead := []
	for c in s.cats:
		if c.alive and int(c.lives) <= 0:
			if diff().permadeath and not offline:
				c.alive = false
				s.memorial.append({"name": c.name, "job": c.job, "day": int(s.day), "level": int(c.level), "fur": int(c.fur)})
				s.stats.cats_lost = int(s.stats.cats_lost) + 1
				dead.append(c.name)
				cat_rt.erase(c.uid)
			else:
				c.lives = 1
	s.cats = s.cats.filter(func(c): return c.alive)
	return dead


# ── 낮 ───────────────────────────────────────────────────

func _tick_growth(dt: float) -> void:
	var gm := grow_mul()
	var sprinklers := []
	for c in s.cats:
		if c.alive and c.job == "sprinkler" and cat_rt.has(c.uid):
			sprinklers.append(cat_rt[c.uid].pos)
	for i in N:
		var t: Dictionary = s.tiles[i]
		if t.kind == "crop":
			var m := 1.0
			if s.phase == "night": m = 0.5
			if not sprinklers.is_empty():
				var p := Vector2(tx(i) + 0.5, ty(i) + 0.5)
				for sp in sprinklers:
					if p.distance_to(sp) <= 2.5:
						m *= 1.35
						break
			t.prog = minf(float(t.prog) + dt * m, crop_grow_time(t.id) * 1.0001) if gm > 0 else t.prog
		elif t.kind == "turret":
			var gt := float(Data.def_by_id[t.id].growTime)
			if float(t.prog) < gt:
				t.prog = minf(gt, float(t.prog) + dt)


func _tick_economy(dt: float) -> void:
	for c in s.cats:
		if c.alive:
			var drain := Data.FULLNESS_DRAIN * (0.8 if has_job("chef") else 1.0)
			c.full = maxf(0.0, float(c.full) - drain * dt)
	_sell_t -= dt
	if _sell_t <= 0.0:
		_sell_t = 1.0
		if (s.toggles.auto_sell or has_job("merchant")) and storage_used() > 0:
			var g := sell_all(true)
			if g > 0: emit("fx", {"k": "coins", "v": g})
	_chef_t -= dt
	if _chef_t <= 0.0:
		_chef_t = 8.0 / maxf(1, count_job("chef"))
		if has_job("chef") and int(s.fodder) < alive_cats().size() * 3:
			var cheapest := ""
			var price := INF
			for id in s.storage:
				var p := float(Data.crop_by_id[id].unitPrice)
				if int(s.storage[id]) > 0 and p < price:
					price = p; cheapest = id
			if cheapest != "":
				s.storage[cheapest] = int(s.storage[cheapest]) - 1
				if int(s.storage[cheapest]) <= 0: s.storage.erase(cheapest)
				s.fodder = int(s.fodder) + 2
	_auto_t -= dt
	if _auto_t <= 0.0:
		_auto_t = 1.5
		if s.toggles.auto_plant:
			for i in N:
				var t: Dictionary = s.tiles[i]
				if t.open and t.kind == "" and t.plan != "" and s.coins >= float(Data.crop_by_id[t.plan].seedCost) * 2:
					plant(i, t.plan, true)
		if s.toggles.auto_reclaim:
			var best := -1
			var best_cost := INF
			for i in N:
				var c := unlock_cost(i)
				if c > 0 and float(c) < best_cost:
					best_cost = c; best = i
			if best >= 0 and s.coins >= best_cost * 8:
				unlock_tile(best)


func _tick_day_cats(dt: float) -> void:
	var reserved := {}
	for c in s.cats:
		if c.alive and cat_rt.has(c.uid) and cat_rt[c.uid].task == "harvest":
			reserved[cat_rt[c.uid].target] = true
	for c in s.cats:
		if not c.alive or not cat_rt.has(c.uid): continue
		var rt: Dictionary = cat_rt[c.uid]
		var j: Dictionary = Data.job_by_id[c.job]
		var speed := float(j.moveSpeed) * 0.6
		if float(c.full) < 30.0: speed *= 0.6
		rt.act = maxf(0.0, float(rt.act) - dt)
		if rt.task == "harvest":
			var t: Dictionary = s.tiles[rt.target]
			if not crop_ripe(t):
				rt.task = "idle"
				continue
			var goal := Vector2(tx(rt.target) + 0.5, ty(rt.target) + 0.75)
			if _walk(rt, goal, speed, dt):
				rt.t = float(rt.t) + dt * maxf(0.3, float(j.work))
				rt.anim = "act"
				if float(rt.t) >= 1.0:
					if harvest(rt.target, true):
						c.xp = int(c.xp) + 1
					rt.task = "idle"
			continue
		if rt.task == "walk":
			if _walk(rt, rt.goal, speed * 0.6, dt):
				rt.task = "idle"
			continue
		# idle: 농부는 익은 작물을 찾는다
		rt.anim = "idle"
		rt.wander = float(rt.wander) - dt
		if float(j.work) >= 0.5 and c.job in ["farmer", "merchant", "chef"]:
			var best := -1
			var bd := INF
			for i in N:
				if reserved.has(i): continue
				if crop_ripe(s.tiles[i]):
					var d := (rt.pos as Vector2).distance_to(Vector2(tx(i) + 0.5, ty(i) + 0.5))
					if d < bd:
						bd = d; best = i
			if best >= 0 and storage_used() < storage_cap() and (c.job == "farmer" or bd < 2.5):
				rt.task = "harvest"; rt.target = best; rt.t = 0.0
				reserved[best] = true
				continue
		if float(rt.wander) <= 0.0:
			rt.wander = _rng.randf_range(2.0, 5.0)
			var goal := Vector2(CF, CF)
			if c.job == "sprinkler":
				var crops := []
				for i in N:
					if s.tiles[i].kind == "crop": crops.append(i)
				if crops.size() > 0:
					var ci: int = crops[_rng.randi() % crops.size()]
					goal = Vector2(tx(ci) + 0.5, ty(ci) + 0.8)
			else:
				goal = Vector2(_rng.randf_range(CF - 2.4, CF + 2.4), _rng.randf_range(CF - 2.4, CF + 2.4))
			rt.task = "walk"; rt.goal = goal


func _walk(rt: Dictionary, goal: Vector2, speed: float, dt: float) -> bool:
	var p: Vector2 = rt.pos
	var d := goal - p
	if d.length() < 0.06:
		rt.pos = goal
		return true
	rt.anim = "walk"
	rt.flip = d.x < 0
	rt.pos = p + d.normalized() * minf(d.length(), speed * dt)
	return false


# ═════════════════════════════════════════════════════════
# 밤 전투
# ═════════════════════════════════════════════════════════

const DIR_VEC := {"N": Vector2(0, 1), "S": Vector2(0, -1), "W": Vector2(1, 0), "E": Vector2(-1, 0)}
const GATE_POS := {"N": Vector2(CF, CF - 3.0), "S": Vector2(CF, CF + 3.0), "W": Vector2(CF - 3.0, CF), "E": Vector2(CF + 3.0, CF)}


func _spawn_pos(dir: String, lane: int) -> Vector2:
	match dir:
		"N": return Vector2(lane + 0.5, -1.5)
		"S": return Vector2(lane + 0.5, G + 1.5)
		"W": return Vector2(-1.5, lane + 0.5)
		_: return Vector2(G + 1.5, lane + 0.5)


func _place_night_cats() -> void:
	var threat: Dictionary = plan.get("threat", {"N": 0.25, "E": 0.25, "S": 0.25, "W": 0.25})
	var top := "N"
	for d in Data.DIRS:
		if float(threat[d]) > float(threat[top]): top = d
	var per := {"N": 0, "E": 0, "S": 0, "W": 0}
	for c in s.cats:
		if not c.alive or not cat_rt.has(c.uid): continue
		var rt: Dictionary = cat_rt[c.uid]
		rt.cd = 0.0; rt.stack = 0; rt.task = "night"; rt.target = -1
		c.hp = cat_max_hp(c)
		if not is_combat(c):
			rt.post = Vector2(CF + _rng.randf_range(-0.6, 0.6), CF + _rng.randf_range(-0.4, 0.4))
			continue
		var d: String = c.assign if c.assign != "free" else top
		rt.dir = d
		var k: int = per[d]
		per[d] = k + 1
		var off := (k % 3 - 1) * 0.75
		var back := (k / 3) * 0.7
		var base: Vector2 = GATE_POS[d]
		var dv: Vector2 = DIR_VEC[d]
		var side := Vector2(dv.y, dv.x).abs()
		rt.post = base + side * off + dv * back
		if c.job in ["archer", "mage", "nurse"]:
			rt.post += dv * 0.9


func _tick_night(dt: float) -> void:
	if night_over: return
	var t := float(s.t)
	# 스폰
	var dm := float(diff().hp) * early_grace(int(s.day))
	while spawn_i < plan.spawns.size() and float(plan.spawns[spawn_i][0]) <= t:
		var sp: Array = plan.spawns[spawn_i]
		spawn_i += 1
		_spawn(sp[3], sp[1], int(sp[2]) - 4 + C, float(sp[4]) * dm)
	if golden_at >= 0.0 and t >= golden_at:
		golden_at = -1.0
		var gd: String = Data.DIRS[_rng.randi() % 4]
		var gz := _spawn("hare", gd, C, float(plan.dmgRef) * 60.0 * dm + 30.0)
		gz["golden"] = true
		gz.speed = float(gz.speed) * 0.8
		emit("golden", {"dir": gd})
	combo_t -= dt
	if combo_t <= 0.0 and combo > 0:
		combo = 0
		emit("combo", {"n": 0})
	_tick_free_cats(dt)
	_tick_zombies(dt)
	_tick_turrets(dt)
	_tick_shots(dt)
	_tick_night_cats(dt)
	if night_failed:
		night_over = true
		_enter_dawn(true)
		return
	var alive := 0
	for z in zombies:
		if z.alive: alive += 1
	if spawn_i >= plan.spawns.size() and alive == 0:
		night_over = true
		_enter_dawn(false)
	elif t > float(plan.duration) + 50.0:
		# 너무 길어지면 남은 좀비는 새벽빛에 흩어진다
		for z in zombies: z.alive = false
		night_over = true
		_enter_dawn(false)


func _spawn(type: String, dir: String, lane: int, hp: float) -> Dictionary:
	var d: Dictionary = Data.zombie_by_id[type]
	_zid += 1
	var z := {"id": _zid, "type": type, "hp": hp, "max": hp, "pos": _spawn_pos(dir, lane), "dir": dir,
		"v": DIR_VEC[dir], "speed": float(d.speed), "alive": true, "atk_cd": 0.0, "slow_t": 0.0, "slow": 0.0,
		"stacks": 0, "frozen": 0.0, "burn_t": 0.0, "burn": 0.0, "poison_t": 0.0, "hit": 0.0, "anim": _rng.randf() * 4.0,
		"boss": d.get("boss", false), "flying": d.get("flying", false), "burrow": d.get("burrow", false),
		"phase": d.get("phase", false), "special": 3.0, "target": null, "size": int(d.size)}
	zombies.append(z)
	emit("spawn", {"pos": z.pos, "type": type})
	if z.boss:
		emit("boss_spawn", {"id": type, "dir": dir})
		emit("shake", {"amount": 4.0})
	return z


## 튜토리얼 구간 완화: 첫 밤들은 "배우는 밤"이다
func early_grace(n: int) -> float:
	if n <= 2: return 0.5
	if n <= 4: return 0.72
	if n <= 6: return 0.88
	return 1.0


func burrowed(z: Dictionary) -> bool:
	if not z.burrow: return false
	var p: Vector2 = z.pos
	return maxf(absf(p.x - CF), absf(p.y - CF)) > 3.5


func _tick_free_cats(dt: float) -> void:
	_free_t -= dt
	if _free_t > 0.0: return
	_free_t = 3.0
	var load := {"N": 0.0, "E": 0.0, "S": 0.0, "W": 0.0}
	for z in zombies:
		if z.alive: load[z.dir] += float(z.hp)
	var top := "N"
	for d in Data.DIRS:
		if load[d] > load[top]: top = d
	if load[top] <= 0.0: return
	var i := 0
	for c in s.cats:
		if not c.alive or c.down or c.assign != "free" or not is_combat(c) or not cat_rt.has(c.uid): continue
		var rt: Dictionary = cat_rt[c.uid]
		if rt.get("dir", "") != top:
			rt.dir = top
			var dv: Vector2 = DIR_VEC[top]
			var side := Vector2(dv.y, dv.x).abs()
			rt.post = GATE_POS[top] + side * ((i % 3) - 1) * 0.75 + dv * (i / 3) * 0.7
		i += 1


func _tick_zombies(dt: float) -> void:
	var dmg_ref := float(plan.dmgRef) * float(diff().dmg)
	for z in zombies:
		if not z.alive: continue
		var d: Dictionary = Data.zombie_by_id[z.type]
		z.anim = float(z.anim) + dt * 6.0
		z.hit = maxf(0.0, float(z.hit) - dt)
		# 상태이상
		if float(z.burn_t) > 0.0:
			z.burn_t = float(z.burn_t) - dt
			_hurt(z, float(z.burn) * dt, true, "dot")
			if not z.alive: continue
		if float(z.poison_t) > 0.0:
			z.poison_t = float(z.poison_t) - dt
		if float(z.frozen) > 0.0:
			z.frozen = float(z.frozen) - dt
			continue
		var slow := 0.0
		if float(z.slow_t) > 0.0:
			z.slow_t = float(z.slow_t) - dt
			slow = float(z.slow)
		# 마늘벽 둔화 오라
		if not z.flying:
			for i in _walls_near(z.pos, 1.3):
				slow = maxf(slow, float(Data.def_by_id[s.tiles[i].id].get("slow", 0.0)))
		var speed := float(z.speed) * (1.0 - slow)
		# 주술사: 주변 회복 + 버프
		if d.has("healAura"):
			for o in zombies:
				if o.alive and o != z and (o.pos as Vector2).distance_to(z.pos) < 2.0:
					o.hp = minf(float(o.max), float(o.hp) + float(o.max) * float(d.healAura) * dt)
		# 보스 기믹
		if z.boss:
			_boss_special(z, d, dt, dmg_ref)
			if not z.alive: continue
		z.atk_cd = maxf(0.0, float(z.atk_cd) - dt)
		# 목표 결정: 도발 > 좀비냥(고양이 사냥) > 막는 포탑/고양이 > 본진
		var blocker := _find_blocker(z, d)
		if blocker.is_empty():
			var mv: Vector2 = z.v
			if d.get("huntCats", false):
				var cat := _nearest_cat(z.pos, 99.0)
				if not cat.is_empty():
					mv = ((cat_rt[cat.uid].pos as Vector2) - (z.pos as Vector2)).normalized()
			var p: Vector2 = z.pos
			if maxf(absf(p.x - CF), absf(p.y - CF)) <= 1.95 + (0.3 if int(z.size) == 2 else 0.0):
				# 본진 도착
				if float(z.atk_cd) <= 0.0:
					z.atk_cd = 1.0 / float(d.atkSpeed)
					house_hp -= dmg_ref * float(d.dmgMul) * 0.5
					emit("fx", {"k": "househit"})
					emit("sfx", {"name": "house"})
					if house_hp <= 0.0:
						night_failed = true
			else:
				z.pos = p + mv * speed * dt
		else:
			if float(z.atk_cd) <= 0.0:
				z.atk_cd = 1.0 / float(d.atkSpeed)
				var dmg := dmg_ref * float(d.dmgMul)
				if blocker.k == "tile":
					_damage_turret(blocker.i, dmg, z)
				else:
					_damage_cat(blocker.c, dmg, z)


func _walls_near(p: Vector2, r: float) -> Array:
	var out := []
	var cx := int(p.x)
	var cy := int(p.y)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			if x < 0 or y < 0 or x > G - 1 or y > G - 1: continue
			var t: Dictionary = s.tiles[_i(x, y)]
			if t.kind == "turret" and not t.wilted and turret_ready(t) and Data.def_by_id[t.id].kind == "wall":
				if p.distance_to(Vector2(x + 0.5, y + 0.5)) <= r: out.append(_i(x, y))
	return out


func _find_blocker(z: Dictionary, d: Dictionary) -> Dictionary:
	if z.flying: return {}
	# 도발: 방패냥
	for c in s.cats:
		if c.alive and not c.down and c.job == "guard" and cat_rt.has(c.uid):
			if (cat_rt[c.uid].pos as Vector2).distance_to(z.pos) < 0.75:
				return {"k": "cat", "c": c}
	# 경로 위 고양이
	var p: Vector2 = z.pos
	for c in s.cats:
		if not c.alive or c.down or not cat_rt.has(c.uid) or not is_combat(c): continue
		var cp: Vector2 = cat_rt[c.uid].pos
		if cp.distance_to(p) < 0.6:
			return {"k": "cat", "c": c}
	if burrowed(z): return {}
	var ahead: Vector2 = p + (z.v as Vector2) * (0.55 if int(z.size) == 1 else 0.85)
	var x := int(floor(ahead.x))
	var y := int(floor(ahead.y))
	if x < 0 or y < 0 or x > G - 1 or y > G - 1: return {}
	var i := _i(x, y)
	var t: Dictionary = s.tiles[i]
	if t.kind == "turret" and not t.wilted and turret_ready(t):
		if z.phase and Data.def_by_id[t.id].kind == "wall": return {}
		return {"k": "tile", "i": i}
	return {}


func _nearest_cat(p: Vector2, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for c in s.cats:
		if c.alive and not c.down and cat_rt.has(c.uid) and is_combat(c):
			var dd := (cat_rt[c.uid].pos as Vector2).distance_to(p)
			if dd < bd:
				bd = dd; best = c
	return best


func _boss_special(z: Dictionary, d: Dictionary, dt: float, dmg_ref: float) -> void:
	z.special = float(z.special) - dt
	if float(z.special) > 0.0: return
	match z.type:
		"bossBear":
			z.special = 6.0
			emit("fx", {"k": "slam", "pos": z.pos})
			emit("shake", {"amount": 5.0})
			emit("sfx", {"name": "bigboom"})
			for i in N:
				var t: Dictionary = s.tiles[i]
				if t.kind == "turret" and not t.wilted and (z.pos as Vector2).distance_to(Vector2(tx(i) + 0.5, ty(i) + 0.5)) < 1.6:
					_damage_turret(i, turret_max_hp(t) * 0.5, z)
		"bossPumpkin":
			z.special = 5.0
			for k in 2:
				var m := _spawn("rat", z.dir, C - 1 + _rng.randi() % 3, float(z.max) * 0.02)
				m.pos = (z.pos as Vector2) + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
			emit("sfx", {"name": "zgrowl"})
		"bossChicken":
			z.special = 3.0
			var best := -1
			var bd := 4.5
			for i in N:
				var t: Dictionary = s.tiles[i]
				if t.kind == "turret" and not t.wilted:
					var dd := (z.pos as Vector2).distance_to(Vector2(tx(i) + 0.5, ty(i) + 0.5))
					if dd < bd:
						bd = dd; best = i
			if best >= 0:
				shots.append({"pos": z.pos, "to": Vector2(tx(best) + 0.5, ty(best) + 0.5), "egg": true, "i": best,
					"dmg": dmg_ref * 2.5, "t": 0.0, "dur": 0.7, "kind": "egg", "alive": true, "color": Color("#fff6d8")})
		"bossCat":
			z.special = 4.0
			emit("sfx", {"name": "zgrowl"})
		"bossDark":
			z.special = 8.0
			emit("fx", {"k": "dark", "pos": z.pos})
		_:
			z.special = 99.0


func _damage_turret(i: int, dmg: float, src: Dictionary) -> void:
	var t: Dictionary = s.tiles[i]
	if t.kind != "turret" or t.wilted: return
	t.hp = float(t.hp) - dmg
	emit("fx", {"k": "thit", "i": i})
	var d: Dictionary = Data.def_by_id[t.id]
	if d.has("thorns") and not src.is_empty() and src.has("hp"):
		_hurt(src, dmg * float(d.thorns), false, "")
	if float(t.hp) <= 0.0:
		t.wilted = true
		t.hp = 0.0
		emit("sfx", {"name": "wilt"})
		emit("fx", {"k": "wilt", "i": i})


func _damage_cat(c: Dictionary, dmg: float, src: Dictionary) -> void:
	var j: Dictionary = Data.job_by_id[c.job]
	dmg *= 1.0 - float(j.get("dr", 0.0))
	c.hp = float(c.hp) - dmg
	emit("fx", {"k": "cathit", "uid": c.uid})
	if float(c.hp) <= 0.0 and not c.down:
		c.down = true
		c.hp = 0.0
		if _rng.randf() >= 0.3 * pk("ninelives"):
			c.lives = int(c.lives) - 1
		night_lost_lives += 1
		emit("sfx", {"name": "catdown"})
		emit("cat_down", {"name": c.name, "lives": int(c.lives)})


## 좀비 피해. armor_ignore = 독/마법/화상
func _hurt(z: Dictionary, dmg: float, armor_ignore: bool, src: String, from: Vector2 = Vector2.INF) -> void:
	if not z.alive: return
	var d: Dictionary = Data.zombie_by_id[z.type]
	if not armor_ignore and d.has("armorFront"):
		# 방패는 정면만 막는다 — 길목 옆에서 쏘면 그대로 들어간다
		var front := true
		if from != Vector2.INF:
			var to_src: Vector2 = (from - (z.pos as Vector2)).normalized()
			front = to_src.dot(z.v) > 0.45
		if front:
			dmg *= 1.0 - float(d.armorFront)
	var crit := false
	if src != "dot" and _rng.randf() < 0.05 + 0.06 * pk("crit"):
		crit = true
		dmg *= 2.0 + 0.5 * pk("critdmg")
	if pk("frost") > 0 and src != "dot" and not z.boss:
		z.slow = maxf(float(z.slow), 0.15 * pk("frost")); z.slow_t = maxf(float(z.slow_t), 1.0)
	z.hp = float(z.hp) - dmg
	z.hit = 0.12
	if src != "dot": emit("hit", {"pos": z.pos, "crit": crit, "src": src})
	if Settings.damage_numbers and (crit or dmg >= float(z.max) * 0.08) and fx.size() < 140:
		fx.append({"k": "num", "pos": (z.pos as Vector2) + Vector2(_rng.randf_range(-0.2, 0.2), -0.6), "text": Data.fmt(dmg) + ("!" if crit else ""), "t": 0.0, "life": 0.9 if crit else 0.7, "crit": crit})
	if crit and pk("chain") > 0:
		var n := 0
		for o in zombies:
			if n >= 1 + pk("chain"): break
			if o != z and o.alive and (o.pos as Vector2).distance_to(z.pos) < 2.0:
				fx.append({"k": "zap", "pts": [z.pos, o.pos], "t": 0.0, "life": 0.15})
				o.hp = float(o.hp) - dmg * 0.5
				o.hit = 0.12
				if float(o.hp) <= 0.0: _kill(o)
				n += 1
	if float(z.hp) <= 0.0:
		_kill(z)


func _kill(z: Dictionary) -> void:
	if not z.alive: return
	z.alive = false
	var d: Dictionary = Data.zombie_by_id[z.type]
	combo += 1
	combo_t = 2.5
	s.combo_best = maxi(int(s.get("combo_best", 0)), combo)
	if combo in [5, 10, 20, 30, 50, 75, 100, 150, 200, 300]:
		emit("combo", {"n": combo})
	var reward := maxf(1.0, round(float(z.max) * 0.02)) * (1.0 + 0.25 * pk("killcoin")) * (1.0 + minf(combo, 100) * 0.02 * (1.0 + 0.5 * pk("combo")))
	if z.get("golden", false):
		reward = 40.0 * pow(float(s.day), 1.6) + float(s.income_rate) * 40.0
		s.seeds += 3
		emit("golden_kill", {"pos": z.pos, "coins": reward})
		emit("shake", {"amount": 5.0})
	if pk("boom") > 0 and _rng.randf() < 0.2:
		emit("fx", {"k": "boom", "pos": z.pos, "r": 1.3})
		emit("sfx", {"name": "boom"})
		for o in zombies:
			if o.alive and (o.pos as Vector2).distance_to(z.pos) < 1.3:
				o.hp = float(o.hp) - float(z.max) * 0.6 * pk("boom")
				if float(o.hp) <= 0.0: _kill(o)
	_earn(reward)
	night_coins += reward
	night_kills += 1
	s.stats.kills[z.type] = int(s.stats.kills.get(z.type, 0)) + 1
	fx.append({"k": "die", "pos": z.pos, "type": z.type, "t": 0.0, "life": 0.45, "size": int(z.size), "golden": z.get("golden", false)})
	emit("kill", {"pos": z.pos, "type": z.type, "coins": reward, "boss": z.boss})
	emit("sfx", {"name": "zdie"})
	if d.get("explode", 0) and float(d.explode) > 0.0:
		emit("fx", {"k": "boom", "pos": z.pos, "r": float(d.explode)})
		emit("sfx", {"name": "boom"})
		var dmg := float(plan.dmgRef) * 8.0 * float(diff().dmg)
		for i in N:
			var t: Dictionary = s.tiles[i]
			if t.kind == "turret" and (z.pos as Vector2).distance_to(Vector2(tx(i) + 0.5, ty(i) + 0.5)) <= float(d.explode):
				_damage_turret(i, dmg, {})
	if z.boss:
		emit("shake", {"amount": 6.0})
		emit("sfx", {"name": "bigboom"})
	_check_goals_light()


var _goal_t := 0.0
func _check_goals_light() -> void:
	# 처치 목표는 자주 바뀌므로 0.5초에 한 번만 검사
	var now := Time.get_ticks_msec() / 1000.0
	if now - _goal_t > 0.5:
		_goal_t = now
		_check_goals()


func _turret_range(t: Dictionary) -> float:
	var d: Dictionary = Data.def_by_id[t.id]
	return float(d.range) + rstep("turretRange") + 0.4 * pk("range") + (0.5 if has_job("engineer") else 0.0)


func _suppressed(p: Vector2) -> bool:
	for z in zombies:
		if z.alive and z.type == "bossDark" and (z.pos as Vector2).distance_to(p) <= 2.5:
			return true
	return false


func _targetable(z: Dictionary, anti_air: bool) -> bool:
	if not z.alive or burrowed(z): return false
	if z.flying and not anti_air: return false
	var p: Vector2 = z.pos
	return p.x > -1.0 and p.y > -1.0 and p.x < 10.0 and p.y < 10.0


func _tick_turrets(dt: float) -> void:
	var dmg_mul := (1.0 + rstep("turretDmg") + 0.12 * pk("tdmg"))
	var rate_mul := 1.0 + 0.1 * pk("trate") + 0.35 * pk("overclock")
	# 해바라기 오라
	var aura := {}
	for i in N:
		var t: Dictionary = s.tiles[i]
		if t.kind == "turret" and not t.wilted and turret_ready(t) and Data.def_by_id[t.id].kind == "support":
			var d: Dictionary = Data.def_by_id[t.id]
			var r := float(d.auraRange)
			for j in N:
				if Vector2(tx(i), ty(i)).distance_to(Vector2(tx(j), ty(j))) <= r:
					aura[j] = maxf(float(aura.get(j, 0.0)), float(d.fireRateAura) * Data.star_mul(int(t.stars)))
			var coin := float(d.get("coinPerSec", 0)) * dt * (1 + int(t.stars)) * maxf(1.0, s.day * 0.5)
			_earn(coin)
			night_coins += coin
	for i in N:
		var t: Dictionary = s.tiles[i]
		if t.kind != "turret" or t.wilted or not turret_ready(t): continue
		var d: Dictionary = Data.def_by_id[t.id]
		if float(d.dps) <= 0.0 or float(d.fireRate) <= 0.0: continue
		var center := Vector2(tx(i) + 0.5, ty(i) + 0.5)
		if _suppressed(center): continue
		t.cd = float(t.get("cd", 0.0)) + dt * float(d.fireRate) * (1.0 + float(aura.get(i, 0.0))) * rate_mul
		if float(t.cd) < 1.0: continue
		var rng := _turret_range(t)
		var per_shot := float(d.dps) / float(d.fireRate) * Data.star_mul(int(t.stars)) * dmg_mul
		match d.kind:
			"wall":
				# 가시장미: 붙어 있는 좀비를 찌른다
				var hit := false
				for z in zombies:
					if _targetable(z, false) and (z.pos as Vector2).distance_to(center) <= rng + 0.3:
						_hurt(z, per_shot, false, t.id)
						hit = true
				t.cd = 0.0 if hit else 1.0
			"field":
				var hit := false
				for z in zombies:
					if _targetable(z, d.antiAir) and (z.pos as Vector2).distance_to(center) <= rng:
						_hurt(z, per_shot, true, t.id)
						z.poison_t = 0.6
						hit = true
				if hit:
					t.cd = 0.0
					emit("fx", {"k": "poison", "i": i, "r": rng})
				else:
					t.cd = 1.0
			_:
				var target := _pick_target(center, rng, bool(d.antiAir))
				if target.is_empty():
					t.cd = 1.0
					continue
				t.cd = 0.0
				t["fire"] = 0.15
				_fire(i, t, d, center, target, per_shot, rng)


func _pick_target(center: Vector2, rng: float, anti_air: bool) -> Dictionary:
	# 본진에 가장 가까운 좀비 우선 (= 가장 위험한 적)
	var best := {}
	var bd := INF
	for z in zombies:
		if not _targetable(z, anti_air): continue
		if (z.pos as Vector2).distance_to(center) > rng: continue
		var hd := (z.pos as Vector2).distance_to(Vector2(CF, CF))
		if z.type == "shaman": hd -= 2.0
		if hd < bd:
			bd = hd; best = z
	return best


func _fire(i: int, t: Dictionary, d: Dictionary, center: Vector2, target: Dictionary, dmg: float, rng: float) -> void:
	var col := Color(d.color)
	match d.kind:
		"shooter":
			if d.has("pierce"):
				# 관통: 같은 방향의 적 여러 마리를 꿰뚫는 가시
				var dirv := ((target.pos as Vector2) - center).normalized()
				var n := 0
				var hits := zombies.filter(func(z): return _targetable(z, d.antiAir) and (z.pos as Vector2).distance_to(center) <= rng and _dist_to_ray(z.pos, center, dirv) < 0.45)
				hits.sort_custom(func(a, b): return (a.pos as Vector2).distance_to(center) < (b.pos as Vector2).distance_to(center))
				for z in hits:
					if n >= int(d.pierce): break
					_hurt(z, dmg, false, t.id, center)
					n += 1
				fx.append({"k": "line", "a": center, "b": center + dirv * rng, "color": col, "t": 0.0, "life": 0.12, "w": 1.0})
				emit("sfx", {"name": "shoot"})
			else:
				shots.append({"pos": center + Vector2(0, -0.3), "src": center, "z": target, "speed": 7.0, "dmg": dmg, "kind": "bullet",
					"splash": float(d.get("splash", 0.0)), "burn": float(d.get("burn", 0.0)) * float(d.dps),
					"slow": float(d.get("slow", 0.0)), "freeze": int(d.get("freezeStacks", 0)), "alive": true,
					"color": col, "anti_air": d.antiAir})
				emit("sfx", {"name": "shoot"})
		"chain":
			var hit := [target]
			_hurt(target, dmg, false, t.id, center)
			var last: Dictionary = target
			var pts := [center, target.pos]
			for k in int(d.get("chain", 3)) - 1:
				var nxt := {}
				var nd := 2.2
				for z in zombies:
					if _targetable(z, true) and not hit.has(z):
						var dd := (z.pos as Vector2).distance_to(last.pos)
						if dd < nd:
							nd = dd; nxt = z
				if nxt.is_empty(): break
				hit.append(nxt)
				_hurt(nxt, dmg * 0.8, false, t.id)
				pts.append(nxt.pos)
				last = nxt
			fx.append({"k": "zap", "pts": pts, "t": 0.0, "life": 0.18})
			emit("sfx", {"name": "zap"})
		"laser":
			var dirv := ((target.pos as Vector2) - center).normalized()
			for z in zombies:
				if _targetable(z, true) and (z.pos as Vector2).distance_to(center) <= rng and _dist_to_ray(z.pos, center, dirv) < 0.5:
					_hurt(z, dmg, false, t.id, center)
			fx.append({"k": "line", "a": center, "b": center + dirv * rng, "color": Color("#fff2a0"), "t": 0.0, "life": 0.2, "w": 3.0})
			emit("sfx", {"name": "laser"})
		"lob":
			shots.append({"pos": center, "from": center, "to": target.pos, "t": 0.0, "dur": 0.9, "dmg": dmg, "kind": "lob",
				"splash": float(d.get("splash", 1.5)), "alive": true, "color": col})
			emit("sfx", {"name": "lob"})


func _dist_to_ray(p: Vector2, o: Vector2, dirv: Vector2) -> float:
	var v := p - o
	var along := v.dot(dirv)
	if along < 0: return INF
	return (v - dirv * along).length()


func _tick_shots(dt: float) -> void:
	for sh in shots:
		if not sh.alive: continue
		match sh.kind:
			"bullet":
				var z: Dictionary = sh.z
				if not z.alive:
					sh.alive = false
					continue
				var to: Vector2 = z.pos
				var d: Vector2 = to - (sh.pos as Vector2)
				if d.length() < 0.25:
					sh.alive = false
					_bullet_hit(sh, z)
				else:
					sh.pos = (sh.pos as Vector2) + d.normalized() * float(sh.speed) * dt
			"lob", "egg":
				sh.t = float(sh.t) + dt
				var k: float = clampf(float(sh.t) / float(sh.dur), 0.0, 1.0)
				var from: Vector2 = sh.get("from", sh.pos)
				if not sh.has("from"): sh["from"] = sh.pos
				sh.pos = (sh.from as Vector2).lerp(sh.to, k)
				sh["h"] = sin(k * PI) * 1.5
				if k >= 1.0:
					sh.alive = false
					if sh.kind == "egg":
						_damage_turret(int(sh.i), float(sh.dmg), {})
						emit("fx", {"k": "boom", "pos": sh.to, "r": 0.5})
					else:
						emit("fx", {"k": "boom", "pos": sh.to, "r": float(sh.splash)})
						emit("sfx", {"name": "boom"})
						for z in zombies:
							if _targetable(z, true) and (z.pos as Vector2).distance_to(sh.to) <= float(sh.splash):
								_hurt(z, float(sh.dmg), false, "lob")
			"arrow", "magic":
				var z: Dictionary = sh.z
				if not z.alive:
					sh.alive = false
					continue
				var d: Vector2 = (z.pos as Vector2) - (sh.pos as Vector2)
				if d.length() < 0.3:
					sh.alive = false
					if sh.kind == "magic":
						emit("fx", {"k": "boom", "pos": z.pos, "r": float(sh.splash), "color": "magic"})
						for o in zombies:
							if _targetable(o, true) and (o.pos as Vector2).distance_to(z.pos) <= float(sh.splash):
								_hurt(o, float(sh.dmg), true, "mage")
					else:
						_hurt(z, float(sh.dmg), false, "archer", sh.get("src", Vector2.INF))
				else:
					sh.pos = (sh.pos as Vector2) + d.normalized() * 8.0 * dt
	shots = shots.filter(func(x): return x.alive)


func _bullet_hit(sh: Dictionary, z: Dictionary) -> void:
	if float(sh.splash) > 0.0:
		emit("fx", {"k": "boom", "pos": z.pos, "r": float(sh.splash)})
		for o in zombies:
			if _targetable(o, sh.anti_air) and (o.pos as Vector2).distance_to(z.pos) <= float(sh.splash):
				_hurt(o, float(sh.dmg), false, "", sh.get("src", Vector2.INF))
				if float(sh.burn) > 0.0:
					o.burn = float(sh.burn); o.burn_t = 2.0
	else:
		_hurt(z, float(sh.dmg), false, "", sh.get("src", Vector2.INF))
	if float(sh.slow) > 0.0 and z.alive:
		z.slow = float(sh.slow); z.slow_t = 1.5
		z.stacks = int(z.stacks) + 1
		if int(sh.freeze) > 0 and int(z.stacks) >= int(sh.freeze) and not z.boss:
			z.stacks = 0
			z.frozen = 1.5
			emit("fx", {"k": "freeze", "pos": z.pos})


func _tick_night_cats(dt: float) -> void:
	for c in s.cats:
		if not c.alive or not cat_rt.has(c.uid): continue
		var rt: Dictionary = cat_rt[c.uid]
		var j: Dictionary = Data.job_by_id[c.job]
		if c.down:
			rt.anim = "down"
			continue
		rt.cd = maxf(0.0, float(rt.cd) - dt)
		if not is_combat(c):
			# 농사 고양이도 냥이집 문 앞까지 온 좀비는 할퀸다
			_walk(rt, rt.post, 2.0, dt)
			rt.anim = "idle"
			if float(rt.cd) <= 0.0:
				for z in zombies:
					if _targetable(z, false) and (z.pos as Vector2).distance_to(rt.pos) < 1.9:
						rt.cd = 1.0 / float(j.atkSpeed)
						rt.anim = "act"
						_hurt(z, cat_atk(c), false, c.job, rt.pos)
						fx.append({"k": "slash", "pos": z.pos, "t": 0.0, "life": 0.2})
						break
			continue
		var rng := float(j.range)
		var p: Vector2 = rt.pos
		var leash := 2.2
		match c.job:
			"nurse":
				# 가장 다친 아군 치료
				var worst := {}
				var wr := 0.98
				for o in s.cats:
					if o.alive and not o.down and cat_rt.has(o.uid) and (cat_rt[o.uid].pos as Vector2).distance_to(p) <= rng:
						var r := float(o.hp) / maxf(1.0, cat_max_hp(o))
						if r < wr:
							wr = r; worst = o
				_walk(rt, rt.post, float(j.moveSpeed), dt)
				if not worst.is_empty() and float(rt.cd) <= 0.0:
					rt.cd = 1.0 / float(j.atkSpeed)
					worst.hp = minf(cat_max_hp(worst), float(worst.hp) + cat_atk(c) * 6.0)
					rt.act = 0.3
					fx.append({"k": "heal", "pos": cat_rt[worst.uid].pos, "t": 0.0, "life": 0.5})
					emit("sfx", {"name": "heal"})
				continue
			"engineer":
				_walk(rt, rt.post, float(j.moveSpeed), dt)
				if float(rt.cd) <= 0.0:
					rt.cd = 7.0
					for i in N:
						var t: Dictionary = s.tiles[i]
						if t.kind == "turret" and t.wilted and p.distance_to(Vector2(tx(i) + 0.5, ty(i) + 0.5)) <= 3.5:
							t.wilted = false
							t.hp = turret_max_hp(t) * 0.6
							rt.act = 0.4
							emit("fx", {"k": "star", "i": i})
							break
		var target := {}
		var td := INF
		var aa := bool(j.get("antiAir", false))
		for z in zombies:
			if not _targetable(z, aa): continue
			var dd := (z.pos as Vector2).distance_to(p)
			var limit := rng + (leash if rng < 1.5 else 0.0)
			if dd <= limit and dd < td:
				td = dd; target = z
		if target.is_empty():
			_walk(rt, rt.post, float(j.moveSpeed), dt)
			if (rt.pos as Vector2).distance_to(rt.post) < 0.1: rt.anim = "idle"
			continue
		var tp: Vector2 = target.pos
		if td > rng:
			# 근접형: 붙으러 간다 (자기 자리에서 너무 멀리는 안 간다)
			if (rt.post as Vector2).distance_to(tp) < leash + 0.8:
				_walk(rt, tp - (tp - p).normalized() * (rng * 0.8), float(j.moveSpeed), dt)
			continue
		rt.flip = tp.x < p.x
		if float(rt.cd) > 0.0:
			if float(rt.act) <= 0.0: rt.anim = "idle"
			rt.act = maxf(0.0, float(rt.act) - dt)
			continue
		var spd := float(j.atkSpeed) * (1.0 + 0.1 * int(rt.stack))
		rt.cd = 1.0 / spd
		rt.act = 0.25
		rt.anim = "act"
		var atk := cat_atk(c)
		match c.job:
			"archer":
				shots.append({"pos": p, "src": p, "z": target, "dmg": atk, "kind": "arrow", "alive": true, "color": Color("#e8e0c8")})
				emit("sfx", {"name": "shoot"})
			"mage":
				shots.append({"pos": p, "z": target, "dmg": atk, "kind": "magic", "alive": true, "splash": float(j.get("aoe", 1.4)), "color": Color("#b48cff")})
				emit("sfx", {"name": "magic"})
			_:
				var was_alive: bool = target.alive
				_hurt(target, atk * (3.0 if c.job == "sword" and int(c.kills) % 3 == 2 else 1.0), c.job == "captain", c.job, p)
				fx.append({"k": "slash", "pos": tp, "t": 0.0, "life": 0.2})
				emit("sfx", {"name": "slash"})
				var zd: Dictionary = Data.zombie_by_id[target.type]
				if zd.has("thorns"):
					c.hp = float(c.hp) - atk * float(zd.thorns)
					if float(c.hp) <= 0.0: _damage_cat(c, 1.0, {})
				if was_alive and not target.alive:
					c.kills = int(c.kills) + 1
					if c.job == "sword": rt.stack = mini(5, int(rt.stack) + 1)


func _tick_fx(dt: float) -> void:
	for f in fx:
		f.t = float(f.t) + dt
	fx = fx.filter(func(f): return float(f.t) < float(f.life))


# ═════════════════════════════════════════════════════════
# 방치(오프라인) 진행 — 장의 관문(보스 밤)은 직접 치러야 한다
# ═════════════════════════════════════════════════════════

func estimate_power() -> float:
	var p := 0.0
	var dm := 1.0 + rstep("turretDmg")
	for t in s.tiles:
		if t.kind == "turret":
			p += float(Data.def_by_id[t.id].dps) * Data.star_mul(int(t.stars)) * dm
	for c in s.cats:
		if c.alive and is_combat(c):
			p += cat_atk(c) * float(Data.job_by_id[c.job].atkSpeed)
	return p


func apply_offline(seconds: float) -> Dictionary:
	var cap := offline_cap_hours() * 3600.0
	seconds = minf(seconds, cap)
	var res := {"seconds": seconds, "coins": 0.0, "days": 0, "won": 0, "lost": 0, "harvest": 0}
	if seconds < 60.0: return res
	offline = true
	var rate := maxf(float(s.income_rate), 0.0) * 0.75
	var cycle := Data.PHASE_LEN.day + Data.PHASE_LEN.dusk + Data.PHASE_LEN.dawn + Data.night_len(int(s.day))
	var left := seconds
	while left >= cycle and res.days < 400:
		var n := int(s.day)
		if is_gate_night(n) or Data.night_plan(n).boss != null:
			break   # 보스 밤과 장의 관문은 직접!
		left -= cycle
		var gain := rate * Data.PHASE_LEN.day
		_earn(gain)
		res.coins += gain
		var need := float(Data.night_plan(n).totalHp) * float(diff().hp) / Data.night_len(n)
		if estimate_power() >= need * 0.85:
			res.won += 1
			s.seeds += 1 + n / 10
			s.stats.won = int(s.stats.won) + 1
		else:
			res.lost += 1
			var loss := float(s.coins) * 0.15
			s.coins -= loss
			res.coins -= loss
		s.day = n + 1
		res.days += 1
	# 남은 시간은 작물 성장으로
	for t in s.tiles:
		if t.kind == "crop":
			t.prog = float(t.prog) + left
		elif t.kind == "turret":
			t.prog = float(t.prog) + left
	s.phase = "day"
	s.t = 0.0
	offline = false
	s.stats.best_day = maxi(int(s.stats.best_day), int(s.day))
	_check_goals()
	return res


# ═════════════════════════════════════════════════════════
# 로그라이크: 축복 카드
# ═════════════════════════════════════════════════════════

func roll_draft(min_r: int = 0) -> Array:
	var out := []
	var tries := 0
	while out.size() < 3 and tries < 200:
		tries += 1
		var luck := pk("lucky")
		var w := [60.0 - luck * 12, 28.0 + luck * 4, 10.0 + luck * 5, 2.0 + luck * 3]
		var total := 0.0
		for k in range(min_r, 4): total += w[k]
		var roll := _rng.randf() * total
		var r := min_r
		for k in range(min_r, 4):
			roll -= w[k]
			if roll <= 0.0:
				r = k
				break
		var pool: Array = Perks.LIST.filter(func(p): return int(p.r) == r and pk(p.id) < int(p.max) and not out.has(p.id))
		if pool.is_empty(): continue
		out.append(pool[_rng.randi() % pool.size()].id)
	return out


func reroll_cost() -> int:
	return 1 + int(s.get("rerolls", 0))


func reroll_draft() -> bool:
	var c := reroll_cost()
	if int(s.seeds) < c: return false
	s.seeds = int(s.seeds) - c
	s.rerolls = int(s.get("rerolls", 0)) + 1
	draft = roll_draft(0)
	return true


func take_perk(id: String) -> void:
	if not s.has("perks"): s.perks = {}
	s.perks[id] = pk(id) + 1
	draft = []
	s.rerolls = 0
	for c in s.cats:
		if c.alive: c.hp = cat_max_hp(c)


# ═════════════════════════════════════════════════════════
# 냥슬롯 — 운명을 건 한 판
# ═════════════════════════════════════════════════════════

const SLOT_SYMBOLS := [
	{"id": "carrot", "w": 26, "x3": 3.0},
	{"id": "corn", "w": 20, "x3": 5.0},
	{"id": "tomato", "w": 15, "x3": 8.0},
	{"id": "strawberry", "w": 11, "x3": 12.0},
	{"id": "pumpkin", "w": 8, "x3": 25.0},
	{"id": "cat", "w": 5, "x3": 60.0},
	{"id": "rainbow", "w": 3, "x3": 150.0},
	{"id": "zombie", "w": 12, "x3": 0.0},
]


func slot_symbol() -> String:
	var total := 0
	for sy in SLOT_SYMBOLS: total += int(sy.w)
	var r := _rng.randi() % total
	for sy in SLOT_SYMBOLS:
		r -= int(sy.w)
		if r < 0: return sy.id
	return "carrot"


func slot_spin(bet: float) -> Dictionary:
	bet = floorf(minf(bet, float(s.coins)))
	if bet < 1.0 or not can_build_now(): return {}
	s.coins -= bet
	var reels := [slot_symbol(), slot_symbol(), slot_symbol()]
	var mult := 0.0
	var kind := "lose"
	if reels[0] == reels[1] and reels[1] == reels[2]:
		for sy in SLOT_SYMBOLS:
			if sy.id == reels[0]: mult = float(sy.x3)
		kind = "jackpot" if reels[0] in ["rainbow", "cat"] else ("big" if mult > 0 else "zombie")
		if reels[0] == "zombie":
			mult = 0.0
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		var pair: String = reels[1] if (reels[0] == reels[1] or reels[1] == reels[2]) else reels[0]
		if pair != "zombie":
			mult = 2.0   # 기대값 약 96% — 대부분 조금 잃고, 가끔 크게 딴다
			kind = "small"
	elif reels.has("rainbow"):
		mult = 1.0
		kind = "refund"
	var win := bet * mult
	if win > 0.0:
		s.coins += win
		s.stats.earned = float(s.stats.earned) + maxf(0.0, win - bet)
	s.slot.spins = int(s.slot.get("spins", 0)) + 1
	s.slot.best = maxf(float(s.slot.get("best", 0.0)), mult)
	var bonus := ""
	if kind == "jackpot" and reels[0] == "cat" and alive_cats().size() < cat_cap():
		var pool := Data.jobs.filter(func(j): return job_unlocked(j.id))
		var c := _add_cat(pool[_rng.randi() % pool.size()].id, 2 + (_rng.randi() % 2), start_level())
		bonus = c.name
	return {"reels": reels, "mult": mult, "win": win, "bet": bet, "kind": kind, "bonus": bonus}


# ═════════════════════════════════════════════════════════
# 스스로 익히는 레벨 디자인: UI를 하나씩 드러내고, 손가락으로 다음 행동을 가리킨다
# ═════════════════════════════════════════════════════════

func revealed(key: String) -> bool:
	return bool(s.get("ui", {}).get(key, false))


func check_reveals() -> void:
	if not s.has("ui"): s.ui = {}
	var harvested := 0
	for k in s.stats.harvest: harvested += int(s.stats.harvest[k])
	var kills := 0
	for k in s.stats.kills: kills += int(s.stats.kills[k])
	var conds := {
		"shop": harvested > 0 or storage_used() > 0,
		"defense": harvested >= 6 or int(s.day) >= 2 or s.phase == "dusk",
		"cats": int(s.day) >= 2 or harvested >= 9,
		"slot": int(s.day) >= 2,
		"research": int(s.day) >= 3,
		"dex": kills > 0,
		"speed": int(s.day) >= 2,
		"night": int(s.day) >= 2 or harvested >= 9,
	}
	for k in conds:
		if conds[k] and not revealed(k):
			s.ui[k] = true
			emit("reveal", {"key": k})


func _count_kind(kind: String) -> int:
	var n := 0
	for t in s.tiles:
		if t.kind == kind: n += 1
	return n


## 지금 해야 할 일 하나 — {"tile": i} 또는 {"ui": 이름}
func guide() -> Dictionary:
	var harvested := 0
	for k in s.stats.harvest: harvested += int(s.stats.harvest[k])
	if s.phase == "night": return {}
	# 1) 익은 작물
	if harvested < 6:
		for i in N:
			if crop_ripe(s.tiles[i]): return {"tile": i}
	# 2) 첫 씨앗
	if harvested < 3 and _count_kind("crop") == 0:
		for i in N:
			var t: Dictionary = s.tiles[i]
			if t.open and t.kind == "" and Data.zone_of(tx(i), ty(i)) == "A": return {"tile": i, "tool": "crop"}
	# 3) 첫 판매
	if float(s.coins) < 20 and storage_used() > 0 and revealed("shop"): return {"ui": "shop"}
	# 4) 첫 방어작물 — 길목 위
	if revealed("defense") and _count_kind("turret") < 2 and float(s.coins) >= 18:
		for i in [_i(C, 0), _i(C, G - 1), _i(0, C), _i(G - 1, C)]:
			if s.tiles[i].open and s.tiles[i].kind == "": return {"tile": i, "tool": "turret"}
	# 5) 첫 전투 고양이
	if revealed("cats") and count_job("sword") == 0 and job_unlocked("sword") and float(s.coins) >= Data.hire_cost(Data.job_by_id.sword, alive_cats().size()):
		return {"ui": "cats"}
	# 6) 땅 넓히기
	if open_tiles() < 14 and s.phase == "day":
		var best := -1
		var bc := INF
		for i in N:
			var c := unlock_cost(i)
			if c > 0 and float(c) <= float(s.coins) and c < bc:
				bc = c; best = i
		if best >= 0: return {"tile": best}
	return {}
