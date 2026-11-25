extends Node
## 이동 검증: 협곡 벽 점프로 꼭대기까지 오를 수 있는가 / 이중 점프로 우듬지 틈을 건널 수 있는가 / 대시로 가시밭을 넘는가

var main: Node


func _ready() -> void:
	Game.new_run()
	Game.flags = {"prologue": true, "lumi_join": true, "canyon": true, "first_enemy": true, "first_shrine": true}
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _w(20)
	var p: Player = main.world.player
	p.invuln = 9999
	# 1) 벽 점프 등반: 왼벽을 향해 누른 채 점프 연타
	_tp(84, 29)
	await _w(10)
	var best := p.global_position.y
	Input.action_press("left")
	for k in 60:
		Input.action_press("jump"); await _w(20); Input.action_release("jump"); await _w(16)
		best = minf(best, p.global_position.y)
		if p.global_position.x > 88 * 18: break
	Input.action_release("left")
	print("벽 점프 최고 높이: 칸 y=%.1f (출구 y≈12)" % (best / 18.0))
	# 오른쪽으로 빠져나가기
	Input.action_press("right")
	for k in 10:
		Input.action_press("jump"); await _w(20); Input.action_release("jump"); await _w(16)
	Input.action_release("right")
	print("협곡 탈출 후 위치: 칸 (%.1f, %.1f)" % [p.global_position.x / 18.0, p.global_position.y / 18.0])
	# 2) 이중 점프로 101→108 틈
	Game.has_double = true
	_tp(100, 12)
	await _w(10)
	Input.action_press("right")
	await _w(6)
	Input.action_press("jump"); await _w(60); Input.action_release("jump"); await _w(4)
	Input.action_press("jump"); await _w(50); Input.action_release("jump")
	await _w(60)
	Input.action_release("right")
	print("이중 점프 후: 칸 (%.1f, %.1f)  [섬1 x108~111, y13 위면 성공]" % [p.global_position.x / 18.0, p.global_position.y / 18.0])
	# 3) 대시로 가시밭(144~149) 넘기
	Game.has_dash = true
	_tp(142, 29)
	p.facing = 1
	await _w(10)
	var hp0 := Game.hp
	p.invuln = 0
	Input.action_press("right")
	await _w(58)
	Input.action_press("jump"); await _w(34)
	Input.action_press("dash"); await _w(3); Input.action_release("dash")
	await _w(20); Input.action_release("jump")
	await _w(60)
	Input.action_release("right")
	print("대시 후: 칸 x=%.1f  피해 %d (가시밭 끝 149, 0이면 성공)" % [p.global_position.x / 18.0, hp0 - Game.hp])
	get_tree().quit()


func _tp(cx: int, cy: int) -> void:
	main.world.player.global_position = Vector2(cx * 18 + 9, (cy + 1) * 18)
	main.world.player.velocity = Vector2.ZERO


func _w(n: int) -> void:
	for i in n: await get_tree().physics_frame
