extends Node
## 보스전 흐름: 시작 → 쓰러뜨리기 → 기억 3 → 데모 끝

var main: Node


func _ready() -> void:
	Game.new_run()
	Game.flags = {"prologue": true, "lumi_join": true, "canyon": true, "first_enemy": true, "first_shrine": true}
	Game.has_double = true
	Game.has_dash = true
	Game.memories = [1, 2]
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _w(30)
	var p: Player = main.world.player
	p.invuln = 99999
	_tp(161, 29)
	await _w(60)
	await _advance(8)
	print("보스 상태: ", main.world.boss_state, " hp ", main.world.boss.hp)
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while is_instance_valid(main.world.boss) and not main.world.boss.dead and frames < 120 * 120:
		p.invuln = 99999
		var b: Node2D = main.world.boss
		var dx: float = b.global_position.x - p.global_position.x
		Input.action_release("left"); Input.action_release("right")
		if absf(dx) > 26: Input.action_press("right" if dx > 0 else "left")
		else: p.facing = 1 if dx > 0 else -1
		Input.action_press("attack"); await _w(2); Input.action_release("attack"); await _w(10)
		frames += 12
	Input.action_release("left"); Input.action_release("right")
	print("보스 처치: ", main.world.boss.dead if is_instance_valid(main.world.boss) else true, "  걸린 시간(게임) %.1f초" % (frames / 120.0))
	await _w(240)
	await _advance(6)
	await _w(200)
	var m = main.world.memory_props.get(3)
	print("기억3 활성: ", is_instance_valid(m) and m.active)
	if is_instance_valid(m):
		p.global_position = m.global_position + Vector2(0, 10)
	await _w(200)
	for k in 8:
		await _advance(1)
		await _w(140)
	await _advance(6)
	await _w(60)
	print("기억: ", Game.memories, " boss_down ", Game.boss_down)
	_tp(186, 29)
	await _w(120)
	print("데모 끝 플래그: ", Game.flags.has("end"))
	get_tree().quit()


func _tp(cx: int, cy: int) -> void:
	main.world.player.global_position = Vector2(cx * 18 + 9, (cy + 1) * 18)
	main.world.player.velocity = Vector2.ZERO


func _advance(n: int) -> void:
	for i in n:
		var e := InputEventAction.new()
		e.action = "jump"; e.pressed = true
		Input.parse_input_event(e)
		await _w(4)
		var r := InputEventAction.new()
		r.action = "jump"; r.pressed = false
		Input.parse_input_event(r)
		await _w(16)


func _w(n: int) -> void:
	for i in n: await get_tree().physics_frame
