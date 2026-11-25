extends Node
## 설정 (user://settings.cfg). 창 모드·볼륨·편의 옵션.

const PATH := "user://settings.cfg"

var master := 0.8
var music := 0.6
var sfx := 0.8
var fullscreen := false
var window_scale := 2
var screen_shake := true
var damage_numbers := true
var auto_pause_dialog := true


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	master = c.get_value("audio", "master", master)
	music = c.get_value("audio", "music", music)
	sfx = c.get_value("audio", "sfx", sfx)
	fullscreen = c.get_value("video", "fullscreen", fullscreen)
	window_scale = c.get_value("video", "window_scale", window_scale)
	screen_shake = c.get_value("game", "screen_shake", screen_shake)
	damage_numbers = c.get_value("game", "damage_numbers", damage_numbers)


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", master)
	c.set_value("audio", "music", music)
	c.set_value("audio", "sfx", sfx)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "window_scale", window_scale)
	c.set_value("game", "screen_shake", screen_shake)
	c.set_value("game", "damage_numbers", damage_numbers)
	c.save(PATH)


func apply() -> void:
	_set_vol("Master", master)
	_set_vol("Music", music)
	_set_vol("SFX", sfx)
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := Vector2i(960, 540) * window_scale
		var screen := DisplayServer.screen_get_usable_rect()
		while window_scale > 1 and (size.x > screen.size.x or size.y > screen.size.y):
			window_scale -= 1
			size = Vector2i(960, 540) * window_scale
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func _set_vol(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)
