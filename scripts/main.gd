extends Node
## 게임 장면: 배경 · 월드 · HUD · 대화 · 회상 · 일시정지 · 데모 끝

const WORLD := preload("res://scripts/level/world.gd")

var world: Node2D
var hud: Control
var dlg: Control
var mem: Control
var _flash: ColorRect
var _fade: ColorRect
var _pause: Control
var _music_lock := false
var new_game := false


func _ready() -> void:
	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	var bg := preload("res://scripts/level/background.gd").new()
	bgl.add_child(bg)
	world = WORLD.new()
	world.main = self
	add_child(world)
	bg.world = world
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = preload("res://scripts/ui/hud.gd").new()
	ui.add_child(hud)
	world.boss_bar.connect(hud.set_boss)
	var top := CanvasLayer.new()
	top.layer = 20
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	_flash = ColorRect.new()
	_flash.size = Vector2(1920, 1080)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_flash)
	dlg = preload("res://scripts/ui/dialogue.gd").new()
	top.add_child(dlg)
	mem = preload("res://scripts/ui/memory_scene.gd").new()
	top.add_child(mem)
	_fade = ColorRect.new()
	_fade.size = Vector2(1920, 1080)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fade)
	_pause = preload("res://scripts/ui/pause_menu.gd").new()
	_pause.main = self
	top.add_child(_pause)
	Sound.ambience(true)
	if new_game or not Game.flags.has("prologue"):
		await _prologue()
	else:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, 1.0)


func _prologue() -> void:
	Game.flags["prologue"] = true
	world.player.locked = true
	world.player.dead = false
	var box := VBoxContainer.new()
	box.size = Vector2(1920, 1080)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	_fade.add_child(box)
	Sound.music("", 0.1)
	for line in Story.PROLOGUE:
		var l := Art.label(line, 48, Color(0.85, 0.9, 1.0), false, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		box.add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.0)
		Sound.play("wisp", -16, 0.7)
		await get_tree().create_timer(1.8).timeout
	await get_tree().create_timer(0.8).timeout
	var tw2 := create_tween()
	tw2.tween_property(box, "modulate:a", 0.0, 1.0)
	tw2.tween_property(_fade, "color:a", 0.0, 2.0)
	await tw2.finished
	box.queue_free()
	area_title("잊힘의 숲", "깨어난 공터")
	world.area_shown["깨어난 공터"] = true
	Sound.play("meow", -6, 0.9)
	world.player.locked = false


func _process(_d: float) -> void:
	if _music_lock or world.boss_state == "fight" or mem.visible: return
	if world.boss_state == "done" and world.player.global_position.x > 150 * 18:
		Sound.music("dreams")
		return
	var x: float = world.player.global_position.x / 18.0
	var name := "forest"
	if x >= 136: name = "darkforest"
	elif x >= 80: name = "hope"
	elif x >= 64: name = "peaceful"
	Sound.music(name)


func area_title(name: String, sub: String = "") -> void:
	hud.area_title(name, sub)


func toast(text: String) -> void:
	hud.toast(text)


func flash(c: Color, a: float) -> void:
	_flash.color = Color(c.r, c.g, c.b, a)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.4)


func dialog(lines: Array, cb: Callable = Callable()) -> void:
	if dlg.visible:
		await dlg.finished
		await get_tree().create_timer(0.15).timeout
	dlg.start(lines, cb)


func memory_scene(id: int, cb: Callable) -> void:
	_music_lock = true
	mem.play(id)
	await mem.done
	_music_lock = false
	if cb.is_valid(): cb.call()


func ability_card(id: String) -> void:
	if id == "double": area_title("파랑새의 깃털", "공중에서 한 번 더 점프 (Space)")
	else: area_title("바람의 발톱", "순식간에 내달리기 (C)")


func on_death() -> void:
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(func(): world.respawn())
	tw.tween_interval(0.4)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)


func demo_end() -> void:
	_music_lock = true
	Sound.music("dreams")
	world.player.locked = true
	Game.save_game()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 2.0)
	await tw.finished
	var box := VBoxContainer.new()
	box.size = Vector2(1920, 1080)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.modulate.a = 0.0
	_fade.add_child(box)
	var title := Art.label("MEOWMORY", 120, UiKit.BLUE, false, 12)
	title.add_theme_font_override("font", Art.font_title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for l in [["보리의 여정은 정식판에서 계속됩니다.", 44, UiKit.TEXT], ["", 20, UiKit.TEXT],
		["찾은 기억  %d / 3" % Game.memories.size(), 36, UiKit.SUB],
		["모은 빛 조각  %d" % Game.orbs_total, 36, UiKit.SUB],
		["쓰러진 횟수  %d" % Game.deaths, 36, UiKit.SUB],
		["플레이 시간  %d분 %d초" % [int(Game.playtime) / 60, int(Game.playtime) % 60], 36, UiKit.SUB],
		["", 20, UiKit.TEXT], ["데모를 플레이해 주셔서 고마워요!", 40, UiKit.GOLD]]:
		var lb := Art.label(l[0], l[1], l[2], false, 6)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lb)
	var b := UiKit.button("타이틀로", func():
		Sound.ambience(false)
		get_tree().change_scene_to_file("res://scenes/title.tscn"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw2 := create_tween()
	tw2.tween_property(box, "modulate:a", 1.0, 1.5)
	b.grab_focus()


func to_title() -> void:
	get_tree().paused = false
	Game.in_dialog = false
	Game.save_game()
	Sound.ambience(false)
	get_tree().change_scene_to_file("res://scenes/title.tscn")
