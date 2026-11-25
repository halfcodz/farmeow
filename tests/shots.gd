extends Node
## 렌더링 확인용 자동 플레이 (xvfb-run). 주요 장면을 /tmp/mm_shots 에 저장.

var main: Node
var out := "/tmp/mm_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _w(60)
	_shot("00_title")
	title.queue_free()
	Game.new_run()
	Game.flags["prologue"] = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _w(90)
	_shot("01_start")
	main.world.player.invuln = 9999.0
	await _hold("right", 50)
	await _w(30)
	_shot("02_lumi_dialog")
	await _advance(8)
	await _hold("right", 40)
	_tp(48, 29)
	await _w(20)
	await _advance(4)
	_tp(51, 29)
	for k in 3:
		Input.action_press("attack"); await _w(2); Input.action_release("attack"); await _w(6)
	_shot("03_combat")
	await _w(40)
	_shot("04_after_kill")
	_tp(73, 29)
	await _w(20)
	main.world.talk(_npc("beryl"))
	await _w(40)
	_shot("05_beryl")
	await _advance(10)
	_tp(78, 25)
	await _w(70)
	_shot("06_memory")
	for k in 8:
		await _advance(1)
		await _w(60)
	await _advance(5)
	_tp(85, 29)
	await _w(30)
	await _advance(3)
	Input.action_press("left"); await _w(10)
	Input.action_press("jump"); await _w(8)
	_shot("07_canyon")
	_tp(46, 29)
	await _w(30)
	_shot("07b_hint")
	Input.action_release("jump"); Input.action_release("left")
	Game.has_double = true
	_tp(100, 12)
	await _w(40)
	_shot("08_canopy")
	Game.has_dash = true
	_tp(148, 29)
	await _w(30)
	main.world.player.facing = -1
	Input.action_press("dash"); await _w(4)
	_shot("09_dash")
	Input.action_release("dash")
	_tp(161, 29)
	await _w(30)
	_shot("10_boss_intro")
	await _advance(6)
	await _w(160)
	_shot("11_boss_fight")
	for k in 6:
		Input.action_press("attack"); await _w(2); Input.action_release("attack"); await _w(8)
	_shot("12_boss_hit")
	get_tree().quit()


func _npc(key: String) -> Prop:
	for c in main.world.get_children():
		if c is Prop and c.kind == "npc" and c.data.get("talk", "") == key: return c
	return null


func _tp(cx: int, cy: int) -> void:
	main.world.player.global_position = Vector2(cx * 18 + 9, (cy + 1) * 18)
	main.world.player.velocity = Vector2.ZERO


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _w(frames)
	Input.action_release(action)


func _advance(n: int) -> void:
	for i in n:
		var e := InputEventAction.new()
		e.action = "jump"
		e.pressed = true
		Input.parse_input_event(e)
		await _w(3)
		var r := InputEventAction.new()
		r.action = "jump"
		r.pressed = false
		Input.parse_input_event(r)
		await _w(12)


func _w(n: int) -> void:
	for i in n: await get_tree().process_frame


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)
