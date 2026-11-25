extends Control
## 타이틀: 밤숲 배경 위에 걷는 보리와 루미, 큰 로고, 메뉴

var t := 0.0
var _menu: VBoxContainer
var _settings := false


func _ready() -> void:
	size = Vector2(1920, 1080)
	theme = UiKit.theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	bgl.add_child(preload("res://scripts/level/background.gd").new())
	var logo := Art.label("MEOWMORY", 150, Color(0.75, 0.9, 1.0), false, 16)
	logo.add_theme_font_override("font", Art.font_title)
	logo.position = Vector2(0, 150)
	logo.size = Vector2(1920, 180)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(logo)
	var sub := Art.label("보리와 잊힘의 숲  ·  데모", 44, UiKit.GOLD, false, 8)
	sub.position = Vector2(0, 340)
	sub.size = Vector2(1920, 60)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	_menu = VBoxContainer.new()
	_menu.position = Vector2(700, 520)
	_menu.size = Vector2(520, 400)
	_menu.add_theme_constant_override("separation", 18)
	add_child(_menu)
	var foot := Art.label("모티프: 모리스 마테를링크 『파랑새』  ·  그래픽: 냥이농장 도트 + Kenney (CC0)  ·  폰트: Galmuri", 24, Color(0.6, 0.68, 0.82), false, 4)
	foot.position = Vector2(0, 1030)
	foot.size = Vector2(1920, 40)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)
	_build()
	Sound.music("forest")


func _build() -> void:
	for n in _menu.get_children(): n.queue_free()
	var first: Button
	if Game.has_save():
		first = UiKit.button("이어하기", func(): _start(false))
		_menu.add_child(first)
	var nb := UiKit.button("새로 시작", func(): _start(true))
	_menu.add_child(nb)
	if first == null: first = nb
	_menu.add_child(UiKit.button("설정", func(): _open_settings()))
	_menu.add_child(UiKit.button("종료", func():
		Settings.save()
		get_tree().quit()))
	first.call_deferred("grab_focus")


func _start(fresh: bool) -> void:
	if fresh:
		Game.new_run()
	else:
		Game.load_game()
	Sound.play("wisp")
	var fade := ColorRect.new()
	fade.size = Vector2(1920, 1080)
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	await tw.finished
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.new_game = fresh
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	queue_free()


func _open_settings() -> void:
	for n in _menu.get_children(): n.queue_free()
	var pm := preload("res://scripts/ui/pause_menu.gd")
	# 같은 설정 화면 재사용
	var p: Control = pm.new()
	add_child(p)
	p.visible = true
	p._build_settings()
	var back: Button = p.get_child(1).get_child(p.get_child(1).get_child_count() - 1)
	back.pressed.connect(func():
		Settings.save()
		p.queue_free()
		_build())


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	# 땅 띠와 걷는 보리, 따라오는 루미
	var gy := 960.0
	for i in 30:
		draw_texture_rect(Art.pp(2), Rect2(i * 72, gy, 72, 72), false, Color(0.4, 0.48, 0.68))
	var x := fmod(t * 90.0, 2300.0) - 200.0
	var f := 3 + int(t * 10.0) % 4
	draw_texture_rect(Art.cat(0, f), Rect2(x - 32, gy - 64, 64, 64), false, Color(0.9, 0.92, 1.0))
	var lp := Vector2(x - 70, gy - 110 + sin(t * 3.0) * 10)
	draw_texture_rect(Art.soft_tex, Rect2(lp - Vector2(60, 60), Vector2(120, 120)), false, Color(0.35, 0.75, 1.0, 0.6))
	draw_texture_rect(Art.soft_tex, Rect2(lp - Vector2(18, 18), Vector2(36, 36)), false, Color(0.8, 0.97, 1.0, 1.0))
