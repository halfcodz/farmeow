extends Node
## 게임 데이터(JSON)와 텍스처를 한 곳에서 불러온다.
## 수치는 원작 냥이농장(meowfarm)의 src/data 를 그대로 내보낸 것이다.

const GRID := 11
const CENTER := 5
const DIRS := ["N", "E", "S", "W"]
const DIR_NAME := {"N": "북", "E": "동", "S": "남", "W": "서"}
const LANES := [4, 5, 6]
const PHASE_LEN := {"day": 90.0, "dusk": 8.0, "dawn": 6.0}
const CAT_MAX_LIVES := 9
const CAT_CAP_BASE := 8
const CAT_CAP_MAX := 20
const ADOPT_SEED_COST := 12
const FULLNESS_DRAIN := 100.0 / (90.0 * 4.0)
const ZONE_UNLOCK := {
	"A": {"day": 1, "base": 45.0, "mult": 1.5},
	"C": {"day": 1, "base": 90.0, "mult": 1.42},
	"B": {"day": 6, "base": 700.0, "mult": 1.4},
	"D": {"day": 8, "base": 1500.0, "mult": 1.3},
}
const DIFFICULTY := {
	"easy": {"name": "느긋하게", "hp": 0.7, "dmg": 0.75, "house": 1.4, "permadeath": false,
		"desc": "좀비가 약하고, 고양이가 영구히 떠나지 않아요."},
	"normal": {"name": "보통", "hp": 1.0, "dmg": 1.0, "house": 1.0, "permadeath": true,
		"desc": "원작 냥이농장의 밸런스 그대로."},
	"hard": {"name": "고양이 지옥", "hp": 1.35, "dmg": 1.25, "house": 0.85, "permadeath": true,
		"desc": "모든 밤이 보스전처럼 느껴져요."},
}

var crops: Array = []
var defenses: Array = []
var jobs: Array = []
var rarities: Array = []
var zombies: Array = []
var research: Array = []
var nights: Array = []
var chapters: Array = []
var cat_names: Array = []

var crop_by_id := {}
var def_by_id := {}
var job_by_id := {}
var zombie_by_id := {}
var research_by_id := {}

var tex := {}
var font_main: Font
var font_bold: Font
var font_small: Font
var font_tiny: Font
var font_big: Font


func _ready() -> void:
	crops = _json("crops")
	defenses = _json("defenses")
	jobs = _json("jobs")
	rarities = _json("rarities")
	zombies = _json("zombies")
	research = _json("research")
	nights = _json("nights")
	chapters = _json("chapters")
	cat_names = _json("cat_names")
	for c in crops: crop_by_id[c.id] = c
	for d in defenses: def_by_id[d.id] = d
	for j in jobs: job_by_id[j.id] = j
	for z in zombies: zombie_by_id[z.id] = z
	for r in research: research_by_id[r.id] = r
	font_main = _font("Galmuri11")
	font_bold = _font("Galmuri11-Bold")
	font_small = _font("Galmuri9")
	font_tiny = _font("Galmuri7")
	font_big = _font("Galmuri14")


func _json(name: String) -> Variant:
	var f := FileAccess.open("res://assets/data/%s.json" % name, FileAccess.READ)
	if f == null:
		push_error("data missing: " + name)
		return []
	return JSON.parse_string(f.get_as_text())


func _font(name: String) -> Font:
	var f: FontFile = load("res://assets/fonts/%s.ttf" % name)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## 텍스처 캐시
func t(path: String) -> Texture2D:
	if not tex.has(path):
		var full := path if path.begins_with("res://") else "res://assets/" + path
		tex[path] = load(full)
	return tex[path]


## 16px 타일시트(packed, 간격 0)의 index번째 칸
func tile(sheet: String, index: int, cols: int = 12, size: int = 16) -> AtlasTexture:
	var key := "%s#%d" % [sheet, index]
	if not tex.has(key):
		var a := AtlasTexture.new()
		a.atlas = t(sheet)
		a.region = Rect2((index % cols) * size, (index / cols) * size, size, size)
		tex[key] = a
	return tex[key]


func farm_tile(i: int) -> AtlasTexture:
	return tile("free/kenney_tiny_farm/tilemap_packed.png", i)


func town_tile(i: int) -> AtlasTexture:
	return tile("free/kenney_tiny_town/tilemap_packed.png", i)


func battle_tile(i: int) -> AtlasTexture:
	return tile("free/kenney_tiny_battle/tilemap_packed.png", i, 18)


func dungeon_tile(i: int) -> AtlasTexture:
	return tile("free/kenney_tinydungeon/tilemap_packed.png", i)


func ui_tile(i: int) -> AtlasTexture:
	return tile("free/kenney_ui_pixel_adventure/small_thick.png", i, 23)


func onebit(i: int) -> AtlasTexture:
	return tile("free/kenney_1bit/colored_transparent_packed.png", i, 48)


## 스프라이트 시트의 한 프레임 (원작 코드 도트를 내보낸 PNG)
func frame(path: String, index: int, w: int = 16, h: int = 16, row: int = 0) -> AtlasTexture:
	var key := "%s@%d,%d" % [path, index, row]
	if not tex.has(key):
		var a := AtlasTexture.new()
		a.atlas = t(path)
		a.region = Rect2(index * w, row * h, w, h)
		tex[key] = a
	return tex[key]


func crop_icon(id: String) -> Texture2D:
	return t("sprites/crops/%s_icon.png" % id)


func crop_stage(id: String, stage: int) -> AtlasTexture:
	return frame("sprites/crops/%s.png" % id, clampi(stage, 0, 3))


func turret_frame(id: String, i: int) -> AtlasTexture:
	return frame("sprites/turrets/%s.png" % id, i)


func zombie_frame(id: String, i: int) -> AtlasTexture:
	var s: int = 32 if int(zombie_by_id[id].size) == 2 else 16
	return frame("sprites/zombies/%s.png" % id, i, s, s)


## 고양이: 열 = idle0 idle1 walk0..3 act0 act1 down / 행 = 털색 0..5
func cat_frame(job: String, fur: int, i: int) -> AtlasTexture:
	return frame("sprites/cats/%s.png" % job, i, 16, 16, fur % 6)


## 좀비가 된 동물의 원래 모습 (도감 초상화, Kenney Animal Pack Redux)
const ZOMBIE_PORTRAIT := {
	"rat": "rabbit", "hare": "rabbit", "boar": "pig", "hedgehog": "hippo", "crow": "parrot",
	"mole": "sloth", "boomer": "frog", "shaman": "snake", "ghost": "owl",
	"bossBear": "bear", "bossPumpkin": "gorilla", "bossChicken": "chicken", "bossCat": "panda",
	"bossDark": "walrus",
}

func portrait(zid: String) -> Texture2D:
	return t("free/kenney_animal_pack_redux/%s.png" % ZOMBIE_PORTRAIT.get(zid, "bear"))


## 음식 아이콘 (16x16 Food, CC0) — 사료/요리
func food(name: String) -> Texture2D:
	return t("free/food16/%s.png" % name)


# ── 수식 (원작과 동일) ──────────────────────────────────────

func hire_cost(job: Dictionary, owned: int) -> int:
	return int(ceil(float(job.hireCost) * pow(1.55, owned)))


func research_cost(r: Dictionary, level: int) -> int:
	return int(ceil(float(r.baseCost) * pow(2.1, level)))


func level_mul(level: int) -> float:
	return pow(1.08, level - 1)


func xp_to_next(level: int) -> int:
	return int(round(30.0 * pow(1.28, level - 1)))


func star_mul(stars: int) -> float:
	return pow(1.4, stars)


func upgrade_seed_cost(stars: int) -> int:
	return 2 + stars * 3


func night_len(n: int) -> float:
	return 45.0 + min(n, 25) * 1.6


func ring_of(x: int, y: int) -> int:
	return maxi(absi(x - CENTER), absi(y - CENTER))


func zone_of(x: int, y: int) -> String:
	var r := ring_of(x, y)
	if r <= 1: return "house"
	if r == 2: return "A"
	if r == 3: return "B"
	if r == 4: return "C"
	return "D"


func on_lane(x: int, y: int) -> bool:
	return absi(x - CENTER) <= 1 or absi(y - CENTER) <= 1


## 밤 계획. 100일 이후는 61~100을 돌려 쓰며 체력만 키운다 (끝없는 밤).
func night_plan(n: int) -> Dictionary:
	if n <= nights.size():
		return nights[n - 1]
	var base_n := 61 + ((n - 61) % 40)
	var p: Dictionary = nights[base_n - 1].duplicate(true)
	var mul := pow(1.12, n - 100)
	for s in p.spawns:
		s[4] = round(s[4] * mul)
	p.baseHp = round(p.baseHp * mul)
	p.dmgRef = p.dmgRef * mul
	p.night = n
	return p


func chapter_for_day(day: int) -> Dictionary:
	for c in chapters:
		if day <= int(c.to):
			return c
	return {}


func fmt(v: float) -> String:
	var a := absf(v)
	var units := [[1e12, "T"], [1e9, "B"], [1e6, "M"], [1e4, "K"]]
	for u in units:
		if a >= u[0]:
			var x: float = v / u[0]
			return ("%.1f" % x if absf(x) < 100 else "%d" % int(x)) + u[1]
	return "%d" % int(round(v))
