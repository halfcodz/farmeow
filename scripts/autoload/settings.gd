extends Node
## 설정 (user://settings.cfg)

const PATH := "user://meowmory_settings.cfg"

var master := 0.85
var music := 0.6
var sfx := 0.85
var fullscreen := false
var shake := true


func _ready() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		master = c.get_value("a", "master", master)
		music = c.get_value("a", "music", music)
		sfx = c.get_value("a", "sfx", sfx)
		fullscreen = c.get_value("v", "fullscreen", fullscreen)
		shake = c.get_value("g", "shake", shake)
	apply(true)


func save() -> void:
	var c := ConfigFile.new()
	c.set_value("a", "master", master)
	c.set_value("a", "music", music)
	c.set_value("a", "sfx", sfx)
	c.set_value("v", "fullscreen", fullscreen)
	c.set_value("g", "shake", shake)
	c.save(PATH)


func apply(first: bool = false) -> void:
	for pair in [["Master", master], ["Music", music], ["SFX", sfx]]:
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
		AudioServer.set_bus_mute(i, pair[1] <= 0.001)
	if DisplayServer.get_name() == "headless": return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if first:
			# 화면에 들어가는 가장 큰 16:9 창 (1920x1080 우선)
			var scr := DisplayServer.screen_get_usable_rect()
			var size := Vector2i(1920, 1080)
			for s in [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]:
				size = s
				if s.x <= scr.size.x and s.y <= scr.size.y - 40: break
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(scr.position + (scr.size - size) / 2)
