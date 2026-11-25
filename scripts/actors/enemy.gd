class_name Enemy
extends CharacterBody2D
## 잊힘에 물든 동물들 (원작 냥이농장 좀비 도트).
## rat 순찰 · hare 깡충 추격 · boar 돌진 · crow 급강하 · frog 침 뱉기

var world: Node
var kind := "rat"
var hp := 3
var max_hp := 3
var dir := -1
var state := "idle"
var t := 0.0
var flash := 0.0
var home := Vector2.ZERO
var anim := 0.0
var flying := false
var sprite := "rat"
var dead := false
var aggro := false
var stun := 0.0
var _cd := 0.0

const STATS := {
	"rat": {"hp": 3, "sprite": "rat", "orbs": 3},
	"hare": {"hp": 2, "sprite": "hare", "orbs": 3},
	"boar": {"hp": 7, "sprite": "boar", "orbs": 7},
	"crow": {"hp": 2, "sprite": "crow", "orbs": 4},
	"frog": {"hp": 3, "sprite": "boomer", "orbs": 5},
}


func setup(p_kind: String) -> void:
	kind = p_kind
	var st: Dictionary = STATS[kind]
	hp = st.hp
	max_hp = hp
	sprite = st.sprite
	flying = kind == "crow"


func _ready() -> void:
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 11)
	var cs := CollisionShape2D.new()
	cs.shape = sh
	cs.position = Vector2(0, -5.5)
	add_child(cs)
	collision_layer = 4
	collision_mask = 0 if flying else 1
	home = global_position
	dir = -1 if randf() < 0.5 else 1
	t = randf() * 2.0


func body_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -12), Vector2(12, 12))


func _player() -> Player:
	return world.player


func _physics_process(delta: float) -> void:
	if dead: return
	anim += delta
	t += delta
	flash = maxf(0.0, flash - delta)
	stun = maxf(0.0, stun - delta)
	_cd = maxf(0.0, _cd - delta)
	var p := _player()
	var to_p: Vector2 = p.global_position - global_position
	var near := to_p.length() < 130.0 and not p.dead
	if near and not aggro:
		aggro = true
		world.on_enemy_seen(self)
	if not flying:
		velocity.y = minf(velocity.y + 900.0 * delta, 380.0)
	if stun > 0.0:
		velocity.x = move_toward(velocity.x, 0, 600 * delta)
		if flying: velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
		move_and_slide()
		return
	match kind:
		"rat":
			velocity.x = move_toward(velocity.x, dir * 32.0, 400 * delta)
			_turn_at_edges()
		"hare":
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, 500 * delta)
				if t > 0.9:
					t = 0.0
					if near: dir = 1 if to_p.x > 0 else -1
					else: dir = -dir if randf() < 0.4 else dir
					velocity = Vector2(dir * (85.0 if near else 40.0), -230.0 if near else -150.0)
		"boar":
			match state:
				"idle":
					velocity.x = move_toward(velocity.x, dir * 20.0, 300 * delta)
					_turn_at_edges()
					if near and absf(to_p.y) < 22 and absf(to_p.x) < 120 and signf(to_p.x) == dir:
						state = "windup"; t = 0.0
						Sound.play("growl", -4)
				"windup":
					velocity.x = 0
					if t > 0.5:
						state = "charge"; t = 0.0
						Sound.play("dash", -4, 0.7)
				"charge":
					velocity.x = dir * 175.0
					if randf() < 0.5: world.fx.burst(global_position, 1, Color(0.7, 0.6, 0.5, 0.7), 30, 0.3, 1.2, 60, 0.2)
					if is_on_wall() or t > 1.3 or not _ground_ahead():
						if is_on_wall():
							Game.kick(3.0)
							Sound.play("thump")
							stun = 1.0
						state = "idle"; t = 0.0
						velocity.x = -dir * 40
						dir = -dir
		"crow":
			match state:
				"idle":
					var target := home + Vector2(sin(t * 0.9) * 30.0, sin(t * 2.1) * 8.0)
					velocity = (target - global_position) * 3.0
					if near and _cd <= 0.0 and to_p.y > -10:
						state = "dive"; t = 0.0
						velocity = to_p.normalized() * 150.0
						Sound.play("flap", -2)
				"dive":
					if t > 0.7:
						state = "back"; t = 0.0
				"back":
					velocity = (home - global_position).normalized() * 70.0
					if global_position.distance_to(home) < 6 or t > 2.0:
						state = "idle"; _cd = 1.2
			dir = 1 if velocity.x > 0 else -1
		"frog":
			velocity.x = move_toward(velocity.x, 0, 400 * delta)
			if near: dir = 1 if to_p.x > 0 else -1
			if near and _cd <= 0.0 and is_on_floor():
				_cd = 2.2
				state = "spit"; t = 0.0
			if state == "spit" and t > 0.35:
				state = "idle"
				var v := Vector2(clampf(to_p.x * 1.1, -150, 150), -170.0)
				world.spawn_shot(global_position + Vector2(dir * 6, -8), v, "spit")
				Sound.play("spit", -6)
	move_and_slide()


func _ground_ahead() -> bool:
	return world.solid_at(global_position + Vector2(dir * 8, 4))


func _turn_at_edges() -> void:
	if is_on_wall() or (is_on_floor() and not _ground_ahead()):
		dir = -dir
		velocity.x = dir * 10


func take_hit(dmg: int, from: Vector2, heavy: bool) -> void:
	if dead: return
	hp -= dmg
	flash = 0.12
	aggro = true
	var kd: float = signf(global_position.x - from.x)
	if kd == 0: kd = 1
	var force := 140.0 if heavy else 90.0
	if kind == "boar" and state == "charge":
		force *= 0.3
	velocity = Vector2(kd * force, -60.0 if not flying else -30.0)
	if kind != "boar": stun = 0.25
	if hp <= 0:
		die()


func die() -> void:
	dead = true
	collision_layer = 0
	world.on_enemy_killed(self, STATS[kind].orbs)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 0.2), 0.12)
	tw.tween_callback(queue_free)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := int(anim * (10.0 if kind != "frog" else 3.0)) % 4
	if kind == "boar" and state == "windup": f = int(anim * 20) % 2
	if flash > 0.0 or stun > 0.3: f = 4
	var mod := Color(0.75, 0.8, 0.95)
	if flash > 0.0: mod = Color(3, 3, 3)
	elif kind == "boar" and state == "windup": mod = Color(1.6, 0.7, 0.7)
	elif stun > 0.0: mod = Color(0.9, 0.9, 1.3)
	if not flying:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.28))
	var lift := 0.0
	if flying: lift = 3.0 + sin(anim * 8.0) * 1.5
	var shake := Vector2(randf_range(-1, 1), 0) if kind == "boar" and state == "windup" else Vector2.ZERO
	var sq := Vector2(1.0 + flash * 2.0, 1.0 - flash * 1.5)
	draw_set_transform(Vector2(0, -lift) + shake, 0.0, Vector2(sq.x * (-1 if dir > 0 else 1), sq.y))
	draw_texture(Art.zombie(sprite, f), Vector2(-8, -15), mod)
	draw_set_transform(Vector2.ZERO)
	# 잊힘의 기운: 보랏빛 눈
	if flash <= 0.0:
		draw_rect(Rect2(Vector2(dir * 3 - 1, -10 - lift), Vector2(1, 1)), Color(0.85, 0.5, 1.0))
