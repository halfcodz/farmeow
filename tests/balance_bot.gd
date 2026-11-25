extends Node
## 밸런스 검증 봇 (헤드리스): 그리디 플레이어로 N일을 돌려 밤 생존율을 본다.
##   godot --headless --path . res://tests/balance_bot.tscn -- --days 30 --diff normal --policy active

var days := 30
var policy := "active"
var diff := "normal"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--days": days = int(args[i + 1])
			"--policy": policy = args[i + 1]
			"--diff": diff = args[i + 1]
	var sim := Sim.new()
	sim.new_game(diff)
	var results := []
	sim.event.connect(func(k, d):
		if k == "night_result":
			results.append(d)
			var hp := sim.house_hp / maxf(1.0, sim.house_max)
			print("밤 %2d %s  집 %3d%%  처치 %3d  코인 %8s  포탑 %2d  고양이 %d  연구 %d  화력 %s" % [d.night, "실패" if d.failed else "생존", int(hp * 100), d.kills, Data.fmt(sim.s.coins), _count(sim, "turret"), sim.alive_cats().size(), sim.research_total(), Data.fmt(sim.estimate_power())])
		elif k == "chapter_clear":
			print("  ▶ %s 클리어" % d.chapter.title))
	var t := 0.0
	var think := 0.0
	var guard := 0
	while int(sim.s.day) <= days and guard < 20000000:
		guard += 1
		sim.tick(Sim.TICK)
		t += Sim.TICK
		think -= Sim.TICK
		if think <= 0.0:
			think = 1.0 if policy == "active" else 30.0
			_play(sim)
	var won := results.filter(func(r): return not r.failed).size()
	print("결과: %d/%d 생존 (%.1f%%), 장 %d, 무지개다리 %d" % [won, results.size(), 100.0 * won / maxf(1, results.size()), int(sim.s.chapter), sim.s.memorial.size()])
	get_tree().quit()


func _count(sim: Sim, kind: String) -> int:
	var n := 0
	for t in sim.s.tiles:
		if t.kind == kind: n += 1
	return n


func _play(sim: Sim) -> void:
	var s := sim.s
	if s.phase != "day": return
	for i in 81: sim.harvest(i, true)
	sim.sell_all(true)
	if float(s.t) < 2.0:
		sim.feed_all()
		if int(s.fodder) < sim.alive_cats().size() and s.coins > sim.fodder_price() * 20: sim.buy_fodder(5)
	# 최고 효율 작물
	var best := "carrot"
	for c in Data.crops:
		if sim.crop_unlocked(c.id) and float(c.seedCost) * 6 <= float(s.coins) + 40: best = c.id
	var best_def := "peashoot"
	for d in Data.defenses:
		if sim.def_unlocked(d.id) and float(d.dps) > 0 and float(d.cost) <= float(s.coins) * 0.25: best_def = d.id
	var budget: float = s.coins
	# 방어: 길목 위·옆 칸
	var want_turrets := mini(44, 3 + int(s.day * 1.6))
	var have := _count(sim, "turret")
	for i in 81:
		if have >= want_turrets: break
		var x := Sim.tx(i); var y := Sim.ty(i)
		var z := Data.zone_of(x, y)
		if (z == "C" or z == "B") and sim.s.tiles[i].open and sim.s.tiles[i].kind == "":
			if sim.build(i, best_def): have += 1
	# 낡은 포탑 교체
	for i in 81:
		var t: Dictionary = s.tiles[i]
		if t.kind == "turret" and int(Data.def_by_id[t.id].tier) + 2 < int(Data.def_by_id[best_def].tier) and float(s.coins) > float(Data.def_by_id[best_def].cost) * 3:
			sim.clear_tile(i)
			sim.build(i, best_def)
	for i in 81:
		if s.tiles[i].open and s.tiles[i].kind == "" and Data.zone_of(Sim.tx(i), Sim.ty(i)) == "A":
			sim.plant(i, best, true)
	# 개간
	var cheapest := -1
	var cc := INF
	for i in 81:
		var c := sim.unlock_cost(i)
		if c > 0 and c < cc:
			var z := Data.zone_of(Sim.tx(i), Sim.ty(i))
			if Data.on_lane(Sim.tx(i), Sim.ty(i)) or z == "A" or true:
				cc = c; cheapest = i
	if cheapest >= 0 and float(s.coins) > cc * 2.5: sim.unlock_tile(cheapest)
	# 고용
	var combat := ["sword", "archer", "guard", "mage"]
	var cats := sim.alive_cats().size()
	if cats < sim.cat_cap():
		var order := ["farmer", "sword", "sword", "sprinkler", "merchant", "archer", "farmer", "guard", "chef", "nurse", "archer", "engineer", "mage", "mage", "sword", "archer"]
		var counts := {}
		for c in sim.alive_cats(): counts[c.job] = int(counts.get(c.job, 0)) + 1
		var seen := {}
		for j in order:
			seen[j] = int(seen.get(j, 0)) + 1
			if int(counts.get(j, 0)) < int(seen[j]) and sim.job_unlocked(j):
				if float(s.coins) > Data.hire_cost(Data.job_by_id[j], cats) * 1.5:
					sim.hire(j)
				break
	# 연구
	for r in Data.research:
		if float(s.coins) > Data.research_cost(r, sim.rlv(r.id)) * 4: sim.research_up(r.id)
	# 승급
	if int(s.seeds) >= 8:
		for i in 81:
			if s.tiles[i].kind == "turret" and int(s.tiles[i].stars) < 2 and sim.upgrade_turret(i): break
