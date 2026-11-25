class_name Lumi
extends Node2D
## 빛의 정령 루미 — 보리의 어깨 근처를 맴돌며 길을 밝힌다.

var world: Node
var player: Player
var t := 0.0
var joined := false
var vel := Vector2.ZERO
var pulse := 0.0
var _light: PointLight2D


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_light = world.add_light(self, Color(0.55, 0.85, 1.0), 1.5, 1.4)
	z_index = 5


func _process(delta: float) -> void:
	t += delta
	pulse = maxf(0.0, pulse - delta * 2.0)
	var target: Vector2
	if joined:
		target = player.global_position + Vector2(-player.facing * 14.0, -24.0 + sin(t * 2.2) * 3.0)
	else:
		target = global_position + Vector2(sin(t * 1.3) * 0.3, sin(t * 2.0) * 0.2)
	var d := target - global_position
	vel = vel.lerp(d * 6.0, minf(1.0, delta * 5.0))
	global_position += vel * delta
	_light.energy = 1.3 + 0.2 * sin(t * 3.0) + pulse
	if randf() < 0.5:
		world.fx_add.mote(global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2)), Color(0.5, 0.85, 1.0, 0.7), -vel * 0.1 + Vector2(0, 4), 0.6, 1.2)
	queue_redraw()


func flash() -> void:
	pulse = 1.0


func _draw() -> void:
	var s := 1.0 + 0.1 * sin(t * 5.0) + pulse * 0.4
	draw_texture_rect(Art.soft_tex, Rect2(Vector2(-18, -18) * s, Vector2(36, 36) * s), false, Color(0.3, 0.7, 1.0, 0.55))
	draw_texture_rect(Art.soft_tex, Rect2(Vector2(-7, -7) * s, Vector2(14, 14) * s), false, Color(0.7, 0.95, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 1.6, Color(1, 1, 1))
	for k in 2:
		var a := t * 3.0 + k * PI
		draw_circle(Vector2(cos(a) * 6, sin(a) * 3), 0.8, Color(0.7, 0.95, 1.0, 0.8))
