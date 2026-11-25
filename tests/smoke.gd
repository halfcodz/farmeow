extends Node
## UI/저장/도박 흐름 스모크 테스트 (헤드리스)

func _ready() -> void:
	Game.start_new("easy")
	var sim: Sim = Game.sim
	sim.s.coins = 1e7
	sim.s.seeds = 200
	sim.s.day = 12
	for i in 81:
		if sim.unlock_cost(i) > 0: sim.unlock_tile(i)
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var hud = main.hud
	for j in ["sword", "archer", "farmer", "chef"]: sim.hire(j)
	sim.plant(20, "carrot")
	sim.build(0, "peashoot")
	sim.upgrade_turret(0)
	sim.research_up("growSpeed")
	for k in ["shop", "cats", "research", "dex", "slot"]:
		hud._open_window(k)
		await _frames(3)
		if k == "shop":
			hud._win_tab = "sell"; hud._win_sig = ""; hud._refresh_window()
			await _frames(2)
		hud._close_window()
	print("windows ok")
	hud._open_window("slot")
	await _frames(2)
	var r := sim.slot_spin(1000)
	print("slot: ", r.reels, " x", r.mult)
	var wins := 0.0
	var bets := 0.0
	for k in 20000:
		var rr := sim.slot_spin(10)
		bets += 10; wins += rr.win
		sim.s.coins = 1e7
	print("slot RTP %.1f%%" % (100.0 * wins / bets))
	hud._close_window()
	hud._gacha()
	await _frames(60)
	hud._next_modal()
	sim.draft = sim.roll_draft(0)
	hud._queue_modal({"type": "draft", "res": {"night": 3, "kills": 10, "coins": 50.0, "seeds": 1, "dead": []}})
	await _frames(40)
	print("draft: ", sim.draft)
	sim.take_perk(sim.draft[0])
	hud._next_modal()
	print("perks: ", sim.s.perks)
	Game.save_game()
	var day := int(sim.s.day)
	Game.continue_game()
	assert(int(Game.sim.s.day) == day)
	print("save/load ok")
	sim = Game.sim
	sim.s.chapter = 7
	sim._reset_goals()
	sim.s.boss_cleared["60"] = true
	main.queue_free()
	var main2 = load("res://scenes/main.tscn").instantiate()
	add_child(main2)
	await _frames(3)
	sim._check_goals()
	await _frames(30)
	print("campaign_clear=", sim.s.campaign_clear, " modal=", main2.hud._cur_modal.get("type"))
	sim.do_prestige()
	print("prestige=", sim.s.prestige, " perks=", sim.s.get("perks"))
	print("SMOKE OK")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame
