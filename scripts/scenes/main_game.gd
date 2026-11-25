extends Node2D
## 게임 화면: 넓은 농장(월드) + 카메라(휠 줌·드래그) + 낮밤 색조 + 미니멀 HUD

const ZOOMS := [1.0, 2.0, 3.0]

var world: Node2D
var hud: Control
var cam: Camera2D
var tint: CanvasModulate
var _zoom_i := 1
var _drag := false
var _target_zoom := 2.0


func _ready() -> void:
	var sim: Sim = Game.sim
	world = preload("res://scripts/world/world_view.gd").new()
	world.sim = sim
	add_child(world)
	cam = Camera2D.new()
	cam.position = world.field_center_px()
	cam.zoom = Vector2(2, 2)
	add_child(cam)
	cam.make_current()
	tint = CanvasModulate.new()
	add_child(tint)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	hud = preload("res://scripts/ui/hud.gd").new()
	layer.add_child(hud)
	hud.setup(sim, world, cam)
	hud.quit_to_title.connect(_to_title)
	Sound.music("night" if sim.s.phase in ["dusk", "night"] else "day")
	var ch := sim.chapter()
	if not ch.is_empty() and not sim.s.seen_intro.has(int(ch.id)):
		sim.s.seen_intro.append(int(ch.id))
		hud._title_card(ch.title, UiTheme.CREAM)
	var off: Dictionary = Game.offline_result
	if not off.is_empty() and float(off.get("seconds", 0)) >= 60.0:
		hud._title_card("어서 와요!", UiTheme.GOLD, Data.town_tile(93), "+%s" % Data.fmt(float(off.coins)))
		Game.offline_result = {}


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_i = mini(_zoom_i + 1, ZOOMS.size() - 1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_i = maxi(_zoom_i - 1, 0)
		elif e.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = e.pressed
		_target_zoom = ZOOMS[_zoom_i]
	elif e is InputEventMouseMotion and _drag:
		cam.position -= e.relative / cam.zoom.x
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_EQUAL, KEY_KP_ADD:
				_zoom_i = mini(_zoom_i + 1, ZOOMS.size() - 1)
				_target_zoom = ZOOMS[_zoom_i]
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_i = maxi(_zoom_i - 1, 0)
				_target_zoom = ZOOMS[_zoom_i]
			KEY_HOME:
				cam.position = world.field_center_px()


func _process(delta: float) -> void:
	if Game.sim == null: return
	# 카메라: WASD/방향키 이동, 줌은 정수 배율로 부드럽게
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1
	cam.position += mv * 260.0 * delta / cam.zoom.x
	var z := lerpf(cam.zoom.x, _target_zoom, clampf(delta * 10.0, 0.0, 1.0))
	if absf(z - _target_zoom) < 0.01: z = _target_zoom
	cam.zoom = Vector2(z, z)
	var half := Vector2(960, 540) / cam.zoom.x / 2.0
	var ws: Vector2 = world.world_size_px()
	cam.position = cam.position.clamp(half, ws - half)
	var s := Game.sim.s
	var target := Color.WHITE
	match s.phase:
		"dusk":
			target = Color(1, 1, 1).lerp(Color(0.95, 0.7, 0.62), clampf(float(s.t) / Data.PHASE_LEN.dusk, 0.0, 1.0))
		"night":
			target = Color(0.55, 0.58, 0.85)
		"dawn":
			target = Color(0.95, 0.78, 0.8).lerp(Color.WHITE, clampf(float(s.t) / Data.PHASE_LEN.dawn, 0.0, 1.0))
	tint.color = tint.color.lerp(target, clampf(delta * 3.0, 0.0, 1.0))


func _to_title() -> void:
	Game.running = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
