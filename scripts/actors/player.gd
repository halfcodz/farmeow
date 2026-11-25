class_name Player
extends CharacterBody2D
## 보리. 코요테 타임 · 점프 버퍼 · 가변 점프 · 벽 미끄러짐/벽 점프 · 이중 점프 · 대시 · 3단 할퀴기 · 아래 찍기 반동.

const RUN := 118.0
const ACCEL := 1300.0
const AIR_ACCEL := 900.0
const FRICTION := 1600.0
const GRAVITY := 980.0
const FALL_MAX := 380.0
const JUMP_V := 355.0
const DJUMP_V := 310.0
const WALL_SLIDE := 70.0
const WALL_JUMP := Vector2(140.0, 360.0)
const DASH_V := 330.0
const DASH_T := 0.18
const COYOTE := 0.1
const BUFFER := 0.12

var world: Node
var fur := 0
var facing := 1
var coyote := 0.0
var buffer := 0.0
var air_jumps := 0
var wall_dir := 0
var wall_lock := 0.0
var dashing := 0.0
var dash_cd := 0.0
var air_dash := true
var attack_t := 0.0
var attack_cd := 0.0
var combo := 0
var combo_window := 0.0
var attack_dir := Vector2.RIGHT
var invuln := 0.0
var hurt_t := 0.0
var locked := false
var dead := false
var anim_t := 0.0
var step_t := 0.0
var squash := Vector2.ONE
var was_floor := true
var safe_pos := Vector2.ZERO
var _safe_t := 0.0
var _ghost_t := 0.0
var _last_vy := 0.0


func _ready() -> void:
	var sh := RectangleShape2D.new()
	sh.size = Vector2(9, 13)
	var cs := CollisionShape2D.new()
	cs.shape = sh
	cs.position = Vector2(0, -6.5)
	add_child(cs)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	safe_pos = global_position
	world.add_light(self, Color(1.0, 0.85, 0.7), 0.55, 0.35, Vector2(0, -8))


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-4, -12), Vector2(8, 11))


func _physics_process(delta: float) -> void:
	anim_t += delta
	invuln = maxf(0.0, invuln - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	attack_t = maxf(0.0, attack_t - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	combo_window = maxf(0.0, combo_window - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	wall_lock = maxf(0.0, wall_lock - delta)
	squash = squash.lerp(Vector2.ONE, minf(1.0, delta * 14.0))
	if dead: return
	var ctrl := not locked and not Game.in_dialog and hurt_t <= 0.0
	var ix := 0.0
	if ctrl: ix = Input.get_axis("left", "right")
	if absf(ix) < 0.3: ix = 0.0
	var on_floor := is_on_floor()

	# ── 대시 ──
	if dashing > 0.0:
		dashing -= delta
		velocity = Vector2(facing * DASH_V, 0)
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.025
			world.fx.ghost(_frame_tex(), global_position, facing < 0, Color(0.6, 0.9, 1.0, 0.7), 0.25)
		move_and_slide()
		if dashing <= 0.0:
			velocity.x = facing * RUN
		return

	# ── 좌우 ──
	if wall_lock <= 0.0:
		var target := ix * RUN
		var acc := (ACCEL if on_floor else AIR_ACCEL) if ix != 0.0 else (FRICTION if on_floor else AIR_ACCEL * 0.5)
		velocity.x = move_toward(velocity.x, target, acc * delta)
	if ix != 0.0 and attack_t <= 0.05 and wall_lock <= 0.0:
		facing = 1 if ix > 0 else -1

	# ── 벽 ──
	wall_dir = 0
	if not on_floor and is_on_wall():
		var n := get_wall_normal()
		wall_dir = -1 if n.x > 0 else 1
	var sliding := wall_dir != 0 and ix == wall_dir and velocity.y > 0

	# ── 중력 ──
	var g := GRAVITY
	if velocity.y < 0 and not Input.is_action_pressed("jump"): g *= 2.2   # 짧게 누르면 낮게
	if absf(velocity.y) < 40.0 and not on_floor: g *= 0.6                    # 정점에서 살짝 떠 있기
	velocity.y = minf(velocity.y + g * delta, WALL_SLIDE if sliding else FALL_MAX)
	if sliding and randf() < 0.4:
		world.fx.burst(global_position + Vector2(wall_dir * 5, -6), 1, Color(0.8, 0.85, 1.0, 0.6), 12, 0.3, 1.0, 40)
		if randf() < 0.05: Sound.play("wall", -14)

	# ── 점프 ──
	if on_floor:
		coyote = COYOTE
		air_jumps = 1 if Game.has_double else 0
		air_dash = true
	else:
		coyote -= delta
	if ctrl and Input.is_action_just_pressed("jump"): buffer = BUFFER
	else: buffer -= delta
	if buffer > 0.0:
		if coyote > 0.0:
			_jump(JUMP_V, "jump")
		elif wall_dir != 0 or _near_wall() != 0:
			var wd := wall_dir if wall_dir != 0 else _near_wall()
			if ix == wd:
				# 벽 쪽을 누른 채 점프 → 같은 벽을 타고 오르는 발차기
				velocity = Vector2(-wd * 70.0, -WALL_JUMP.y * 1.05)
				wall_lock = 0.08
			else:
				velocity = Vector2(-wd * WALL_JUMP.x * 1.1, -WALL_JUMP.y)
				facing = -wd
				wall_lock = 0.16
			buffer = 0.0
			air_dash = true
			squash = Vector2(0.75, 1.3)
			world.fx.burst(global_position + Vector2(wd * 5, -6), 8, Color(0.9, 0.95, 1.0), 50, 0.35, 1.2)
			Sound.play("jump", -2, 1.15)
		elif air_jumps > 0:
			air_jumps -= 1
			_jump(DJUMP_V, "djump")
			world.fx_add.ring(global_position + Vector2(0, -2), 14, Color(0.4, 0.7, 1.0, 0.9), 0.35, 2.0)
			world.fx_add.burst(global_position, 12, Color(0.45, 0.75, 1.0), 60, 0.45, 2.0, 0)

	# ── 대시 ──
	if ctrl and Game.has_dash and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (on_floor or air_dash):
		dashing = DASH_T
		dash_cd = 0.45
		if not on_floor: air_dash = false
		if ix != 0.0: facing = 1 if ix > 0 else -1
		squash = Vector2(1.4, 0.7)
		Sound.play("dash")
		world.fx_add.spray(global_position + Vector2(0, -6), Vector2(-facing, 0), 14, Color(0.6, 0.9, 1.0), 90, 0.4, 0.35, 2.0)
		Game.kick(1.5)

	# ── 할퀴기 ──
	if ctrl and Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
		_attack(on_floor)

	_last_vy = velocity.y
	move_and_slide()
	on_floor = is_on_floor()

	# 착지
	if on_floor and not was_floor:
		var hard := clampf(_last_vy / FALL_MAX, 0.0, 1.0)
		squash = Vector2(1.0 + 0.35 * hard, 1.0 - 0.3 * hard)
		if hard > 0.4:
			world.fx.burst(global_position, int(4 + hard * 8), Color(0.75, 0.7, 0.6, 0.8), 45, 0.35, 1.3, 120, 0.2)
			Sound.play("land", -6 + hard * 4)
	was_floor = on_floor

	# 발소리 · 먼지
	if on_floor and absf(velocity.x) > 30.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.26
			Sound.play("step", -16)
			world.fx.burst(global_position + Vector2(-facing * 3, 0), 2, Color(0.7, 0.65, 0.55, 0.6), 18, 0.3, 1.0, 60, 0.3)

	# 안전 위치 기록 (가시에 떨어지면 돌아올 곳)
	if on_floor and not world.near_hazard(global_position):
		_safe_t += delta
		if _safe_t > 0.25: safe_pos = global_position
	else:
		_safe_t = 0.0


func _near_wall() -> int:
	# 벽에서 2px 떨어져 있어도 벽 점프를 받아 준다 (관대한 판정)
	if is_on_floor(): return 0
	if test_move(global_transform, Vector2(3, 0)): return 1
	if test_move(global_transform, Vector2(-3, 0)): return -1
	return 0


func _jump(v: float, snd: String) -> void:
	velocity.y = -v
	coyote = 0.0
	buffer = 0.0
	squash = Vector2(0.7, 1.35)
	world.fx.burst(global_position, 6, Color(0.8, 0.75, 0.65, 0.8), 40, 0.3, 1.2, 80, 0.1)
	Sound.play(snd, -2)


func _attack(on_floor: bool) -> void:
	combo = (combo + 1) % 3 if combo_window > 0.0 else 0
	combo_window = 0.42
	attack_t = 0.2
	attack_cd = 0.17 if combo < 2 else 0.32
	var dir := Vector2(facing, 0)
	if Input.is_action_pressed("up"): dir = Vector2.UP
	elif Input.is_action_pressed("down") and not on_floor: dir = Vector2.DOWN
	attack_dir = dir
	var heavy := combo == 2
	var center := global_position + Vector2(0, -7) + dir * (13 if dir.y == 0 else 12)
	var size := Vector2(24, 18) if dir.y == 0 else Vector2(20, 24)
	if heavy: size *= 1.25
	var box := Rect2(center - size / 2.0, size)
	world.fx_add.slash(global_position + Vector2(0, -7) + dir * 4, dir, 15 if not heavy else 19, Color(0.75, 0.92, 1.0, 0.9), heavy)
	Sound.play("swish", -3, 1.0 + combo * 0.12)
	if on_floor and dir.y == 0: velocity.x += facing * (40 if heavy else 20)
	var hits: int = world.player_attack(box, 2 if heavy else 1, dir, heavy)
	if hits > 0:
		if dir == Vector2.DOWN:
			velocity.y = -270.0      # 아래 찍기 반동
			air_jumps = 1 if Game.has_double else 0
			air_dash = true
		elif dir.y == 0 and not on_floor:
			velocity.y = minf(velocity.y, -40.0)  # 공중 콤보가 조금 버티게
		velocity.x -= facing * 30


func hurt(dmg: int, from_x: float) -> void:
	if invuln > 0.0 or dead or dashing > 0.0: return
	Game.hp = maxi(0, Game.hp - dmg)
	invuln = 1.2
	hurt_t = 0.22
	var d := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(d * 160.0, -190.0)
	Sound.play("hurt")
	Sound.play("meow_sad", -8, 1.3)
	Game.hitstop(0.11)
	Game.kick(7.0)
	world.fx.burst(global_position + Vector2(0, -7), 14, Color(1.0, 0.45, 0.5), 80, 0.5, 1.6)
	world.flash(Color(1, 0.2, 0.25), 0.35)
	Game.state_changed.emit()
	if Game.hp <= 0:
		die()


func hazard() -> void:
	if dead or invuln > 0.4: return
	Game.hp = maxi(0, Game.hp - 1)
	Sound.play("hurt")
	Game.kick(5.0)
	world.flash(Color(1, 0.2, 0.25), 0.3)
	Game.state_changed.emit()
	if Game.hp <= 0:
		die()
		return
	invuln = 1.0
	velocity = Vector2.ZERO
	global_position = safe_pos
	world.fx_add.burst(global_position + Vector2(0, -8), 16, Color(0.5, 0.85, 1.0), 50, 0.6, 2.0, 0)


func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	Game.hitstop(0.25)
	world.on_player_dead()


func revive(at: Vector2) -> void:
	dead = false
	global_position = at
	safe_pos = at
	velocity = Vector2.ZERO
	invuln = 1.0
	Game.hp = Game.max_hp
	Game.state_changed.emit()


func _frame_tex() -> Texture2D:
	var f := 0
	if dead: f = 8
	elif attack_t > 0.0: f = 7
	elif not is_on_floor(): f = 4 if velocity.y < 0 else 6
	elif absf(velocity.x) > 20.0: f = 3 + int(anim_t * 12.0) % 4
	else: f = (2 if fmod(anim_t, 3.2) > 3.05 else int(anim_t * 2.0) % 2)
	return Art.cat(fur, f)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if invuln > 0.0 and int(invuln * 20.0) % 2 == 0 and not dead: return
	# 그림자
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 5.0 * (1.0 if is_on_floor() else 0.6), Color(0, 0, 0, 0.3))
	var lean := 0.0
	if absf(velocity.x) > 60 and is_on_floor(): lean = 0.06 * facing
	if dashing > 0.0: lean = 0.15 * facing
	draw_set_transform(Vector2(0, 0), lean, Vector2(squash.x * facing, squash.y))
	draw_texture(_frame_tex(), Vector2(-8, -16), Color(1.6, 1.6, 1.6) if hurt_t > 0.15 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
