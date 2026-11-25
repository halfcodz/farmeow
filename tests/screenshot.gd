extends Node
## 렌더링 확인용: 타이틀/낮/황혼/밤 화면을 PNG로 저장 (xvfb-run으로 실행)

var out := "/tmp/farmeow_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var days := 6
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: days = int(args[0])
	await _wait(10)
	var title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _wait(40)
	_shot("01_title")
	title.queue_free()
	Game.start_new("normal")
	var bot = load("res://tests/balance_bot.gd").new()
	var sim: Sim = Game.sim
	var think := 0.0
	while int(sim.s.day) < days or sim.s.phase != "day" or float(sim.s.t) < 40.0:
		sim.tick(Sim.TICK)
		think -= Sim.TICK
		if think <= 0:
			think = 1.0
			bot._play(sim)
	sim.s.seen_intro = [1, 2, 3, 4, 5, 6, 7]
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.running = true
	await _wait(30)
	main.world.hover = 20
	await _wait(10)
	_shot("02_day")
	main._target_zoom = 1.0
	await _wait(40)
	_shot("02b_far")
	main._target_zoom = 2.0
	main.hud._open_window("shop")
	await _wait(10)
	_shot("02c_shop")
	main.hud._win_tab = "sell"
	main.hud._win_sig = ""
	await _wait(10)
	_shot("02d_sell")
	main.hud._close_window()
	main.hud._open_window("slot")
	await _wait(5)
	main.hud._spin(0.1)
	await _wait(200)
	_shot("02e_slot")
	main.hud._close_window()
	sim.s.t = 89.0
	await _wait(60)
	_shot("03_dusk")
	await _wait_until(func(): return sim.s.phase == "night" and float(sim.s.t) > float(OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "22"), 3000)
	_shot("04_night")
	await _wait_until(func(): return sim.s.phase == "dawn", 6000)
	await _wait(80)
	_shot("05_dawn")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame


func _wait_until(cond: Callable, max_frames: int) -> void:
	Engine.time_scale = 4.0
	Game.set_speed(2)
	for i in max_frames:
		if cond.call(): break
		await get_tree().process_frame
	Engine.time_scale = 1.0


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
