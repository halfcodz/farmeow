extends Node
## 첫 1분 화면 확인

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/farmeow_shots")
	Game.start_new("normal")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _w(90)
	_shot("10_start")
	main.hud._select_tool("crop", "carrot")
	await _w(10)
	_shot("11_tool")
	Game.sim.plant(Sim._i(4, 2), "carrot")
	Game.sim.plant(Sim._i(2, 4), "carrot")
	Game.sim.s.tiles[Sim._i(4, 2)].prog = 100.0
	main.hud._select_tool("crop", "carrot")
	await _w(20)
	_shot("12_ripe")
	Game.sim.harvest(Sim._i(4, 2))
	await _w(8)
	_shot("13_harvest")
	get_tree().quit()


func _w(n: int) -> void:
	for i in n: await get_tree().process_frame


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/farmeow_shots/%s.png" % n)
