extends Node2D
## 타이틀 배경: 낮 농장 풍경 + 행진하는 고양이와 뒤쫓는 좀비

var time := 0.0
var _var: Array = []
var _walkers: Array = []


func _ready() -> void:
	scale = Vector2(2, 2)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 30 * 18: _var.append(r.randi() % 100)
	var jobs := ["farmer", "sword", "archer", "chef", "mage", "guard", "nurse", "merchant"]
	for k in jobs.size():
		_walkers.append({"kind": "cat", "id": jobs[k], "fur": k % 6, "x": -20.0 - k * 26.0})
	for z in ["rat", "hare", "boar", "crow"]:
		_walkers.append({"kind": "zombie", "id": z, "x": -260.0 - _walkers.size() * 8.0})


func _process(delta: float) -> void:
	time += delta
	for w in _walkers:
		w.x += delta * (22.0 if w.kind == "cat" else 21.0)
		if w.x > 520: w.x -= 640
	queue_redraw()


func _draw() -> void:
	for y in 17:
		for x in 30:
			var v: int = _var[y * 30 + x]
			draw_texture(Data.town_tile(0 if v < 75 else (1 if v < 92 else 2)), Vector2(x, y) * 16)
	# 밭 고랑과 작물
	var crops := ["carrot", "cabbage", "corn", "tomato", "strawberry", "pumpkin", "watermelon", "grape"]
	for row in 2:
		for i in 8:
			var p := Vector2(64 + i * 16, 168 + row * 16)
			draw_texture(Data.t("sprites/terrain/tilled.png"), p)
			draw_texture(Data.crop_stage(crops[(i + row * 3) % 8], 3 if (i + row) % 3 else 2), p + Vector2(0, -1 if fmod(time * 2 + i, 2.0) < 1 else 0))
	# 헛간 (Kenney Tiny Farm)
	var barn := [[90, 91, 92], [102, 103, 104], [114, 115, 116]]
	for yy in 3:
		for xx in 3:
			draw_texture(Data.farm_tile(barn[yy][xx]), Vector2(330 + xx * 16, 150 + yy * 16))
	draw_texture(Data.t("sprites/terrain/house.png"), Vector2(250, 160))
	for d in [[4, 10, 140], [16, 30, 150], [3, 410, 140], [15, 440, 160], [5, 20, 230], [28, 450, 230], [27, 420, 240]]:
		draw_texture(Data.town_tile(d[0]), Vector2(d[1], d[2]))
	for d in [[96, 390, 186], [97, 406, 186], [85, 300, 200], [83, 200, 196], [83, 216, 200], [122, 180, 230], [120, 120, 236], [121, 150, 244]]:
		draw_texture(Data.farm_tile(d[0]), Vector2(d[1], d[2]))
	# 행진
	for w in _walkers:
		var p := Vector2(w.x, 246)
		var f := int(time * 8.0) % 4
		if w.kind == "cat":
			draw_texture(Data.cat_frame(w.id, w.fur, 2 + f), p)
		else:
			draw_set_transform(p + Vector2(16, 0), 0.0, Vector2(-1, 1))
			draw_texture(Data.zombie_frame(w.id, f), Vector2(0, -6 if w.id == "crow" else 0))
			draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, 480, 270), Color(0.1, 0.06, 0.15, 0.25))
