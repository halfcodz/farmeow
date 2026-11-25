class_name Boss
extends CharacterBody2D
## 망각의 곰. 패턴: 걸어와 내려치기 · 돌진(벽에 박으면 기절) · 도약 내려찍기(충격파) · 포효(낙석, 2페이즈)

signal defeated

var world: Node
var hp := 70
var max_hp := 70
var dir := -1
var state := "intro"
var t := 0.0
var flash := 0.0
var anim := 0.0
var dead := false
var phase := 1
var _next := "walk"
var _jump_target := 0.0
var _arena := Rect2()


func _ready() -> void:
	var sh := RectangleShape2D.new()
	sh.size = Vector2(34, 40)
	var cs := CollisionShape2D.new()
	cs.shape = sh
	cs.position = Vector2(0, -20)
	add_child(cs)
	collision_layer = 4
	collision_mask = 1
	world.add_light(self, Color(1.0, 0.45, 0.6), 0.8, 0.9, Vector2(0, -30))


func set_arena(r: Rect2) -> void:
	_arena = r


func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-17, -44), Vector2(34, 44))


func start() -> void:
	state = "walk"
	t = 0.0


func _physics_process(delta: float) -> void:
	if dead: return
	anim += delta
	t += delta
	flash = maxf(0.0, flash - delta)
	velocity.y = minf(velocity.y + 1000.0 * delta, 600.0)
	var p: Player = world.player
	var dx: float = p.global_position.x - global_position.x
	if phase == 1 and hp <= max_hp / 2:
		phase = 2
		state = "roar"; t = 0.0
		Sound.play("roar", 2)
		Game.kick(8.0)
	var spd := 1.0 if phase == 1 else 1.3
	match state:
		"intro":
			velocity.x = 0
		"walk":
			dir = 1 if dx > 0 else -1
			velocity.x = dir * 42.0 * spd
			if absf(dx) < 34:
				state = "swipe_wind"; t = 0.0
				velocity.x = 0
			elif t > 1.6 / spd:
				_pick()
		"swipe_wind":
			velocity.x = 0
			if t > 0.38 / spd:
				state = "swipe"; t = 0.0
				Sound.play("swish", 2, 0.6)
				var box := Rect2(global_position + Vector2(dir * 8 - 22, -40), Vector2(44, 40))
				world.fx_add.slash(global_position + Vector2(dir * 14, -22), Vector2(dir, 0.2), 30, Color(1, 0.5, 0.6, 0.9), true)
				if box.intersects(p.hurt_rect()): p.hurt(1, global_position.x)
		"swipe":
			if t > 0.45: _pick()
		"charge_wind":
			velocity.x = -dir * 12.0
			if fmod(t, 0.1) < delta: world.fx.burst(global_position, 2, Color(0.7, 0.6, 0.5), 40, 0.3, 1.5, 60, 0.3)
			if t > 0.7 / spd:
				state = "charge"; t = 0.0
				Sound.play("roar", -4, 1.3)
		"charge":
			velocity.x = dir * 230.0 * spd
			if randf() < 0.6: world.fx.burst(global_position + Vector2(-dir * 12, 0), 2, Color(0.75, 0.65, 0.55, 0.8), 50, 0.4, 1.8, 80, 0.3)
			if is_on_wall() or t > 2.0:
				state = "stunned"; t = 0.0
				velocity.x = -dir * 60.0
				Sound.play("slam", 2)
				Game.kick(10.0)
				world.fx.burst(global_position + Vector2(dir * 18, -20), 30, Color(0.8, 0.7, 0.6), 90, 0.6, 2.0)
				world.rockfall(3 if phase == 1 else 5, _arena)
		"stunned":
			velocity.x = move_toward(velocity.x, 0, 300 * delta)
			if t > 1.6: _pick()
		"leap_wind":
			velocity.x = 0
			if t > 0.45 / spd:
				state = "leap"; t = 0.0
				_jump_target = clampf(p.global_position.x, _arena.position.x + 30, _arena.end.x - 30)
				velocity = Vector2((_jump_target - global_position.x) / 0.8, -420.0)
				Sound.play("jump", 2, 0.5)
		"leap":
			if is_on_floor() and t > 0.15:
				state = "land"; t = 0.0
				velocity.x = 0
				Sound.play("slam", 4)
				Game.kick(9.0)
				world.shockwave(global_position, 1)
				world.shockwave(global_position, -1)
				world.fx.burst(global_position, 26, Color(0.8, 0.7, 0.6), 100, 0.6, 2.0, 120, 0.3)
		"land":
			if t > 0.7 / spd: _pick()
		"roar":
			velocity.x = 0
			if fmod(t, 0.25) < delta:
				world.fx_add.ring(global_position + Vector2(0, -30), 50, Color(0.8, 0.4, 1.0, 0.6), 0.5, 3.0)
			if t > 1.3:
				world.rockfall(7, _arena)
				_pick()
	move_and_slide()
	# 몸에 닿으면 아프다
	if state != "stunned" and body_rect().intersects(p.hurt_rect()):
		p.hurt(1, global_position.x)


func _pick() -> void:
	t = 0.0
	var p: Player = world.player
	dir = 1 if p.global_position.x > global_position.x else -1
	var opts := ["walk", "charge_wind", "leap_wind"]
	if phase == 2: opts += ["charge_wind", "leap_wind"]
	var nxt: String = opts[randi() % opts.size()]
	if nxt == _next and randf() < 0.6: nxt = opts[(opts.find(nxt) + 1) % opts.size()]
	_next = nxt
	state = nxt
	if state != "walk": Sound.play("growl", 0, 0.7)


func take_hit(dmg: int, from: Vector2, heavy: bool) -> void:
	if dead or state == "intro": return
	if state == "stunned": dmg *= 2
	hp -= dmg
	flash = 0.1
	Sound.play("boss_hit", -6)
	if hp <= 0:
		dead = true
		hp = 0
		velocity = Vector2.ZERO
		defeated.emit()


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := int(anim * 6.0) % 4
	var mod := Color(0.8, 0.78, 0.95)
	var sq := Vector2.ONE
	match state:
		"swipe_wind", "charge_wind", "leap_wind":
			mod = Color(1.5, 0.8, 0.85) if int(t * 16) % 2 == 0 else mod
			sq = Vector2(1.08, 0.92)
		"stunned":
			f = 4
			mod = Color(0.95, 0.95, 1.3)
		"leap":
			sq = Vector2(0.88, 1.15)
		"land":
			sq = Vector2(1.2, 0.82) if t < 0.15 else Vector2.ONE
	if flash > 0.0:
		f = 4
		mod = Color(3, 3, 3)
	if dead: mod = Color(0.6, 0.6, 0.8, 0.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.0 * sq.x * (-1 if dir > 0 else 1), 2.0 * sq.y))
	draw_texture(Art.zombie("bossBear", f, 32), Vector2(-16, -30), mod)
	draw_set_transform(Vector2.ZERO)
	if state == "stunned":
		for k in 3:
			var a := anim * 4.0 + k * TAU / 3.0
			draw_circle(Vector2(cos(a) * 14, -52 + sin(a) * 4), 1.5, Color(1, 0.95, 0.5))
