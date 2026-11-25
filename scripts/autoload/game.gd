extends Node
## 시뮬레이션을 고정 스텝(20Hz)으로 돌리고, 저장/불러오기를 맡는다.

const SAVE_PATH := "user://farmeow_save.json"

var sim: Sim
var running := false
var paused := false
var modal_pause := 0     # 대화창/결과창이 열려 있으면 > 0
var _acc := 0.0
var hitstop := 0.0   # 큰 타격 순간 잠깐 멈춤 (손맛)
var offline_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_summary() -> Dictionary:
	if not has_save(): return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return {}
	return {"day": int(d.get("day", 1)), "chapter": int(d.get("chapter", 1)), "difficulty": d.get("difficulty", "normal"),
		"prestige": int(d.get("prestige", 0)), "playtime": float(d.get("playtime", 0.0))}


func start_new(difficulty: String) -> void:
	sim = Sim.new()
	sim.new_game(difficulty)
	_bind()
	offline_result = {}
	running = true
	paused = false
	modal_pause = 0
	save_game()


func continue_game() -> bool:
	if not has_save(): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return false
	_fix_types(d)
	sim = Sim.new()
	sim.load_state(d)
	_bind()
	var away := Time.get_unix_time_from_system() - float(d.get("last_saved", Time.get_unix_time_from_system()))
	offline_result = sim.apply_offline(away) if sim.s.phase == "day" or sim.s.phase == "dawn" or sim.s.phase == "dusk" else {}
	running = true
	paused = false
	modal_pause = 0
	return true


## JSON은 숫자를 전부 float로 돌려주므로 정수여야 하는 키를 되돌린다
func _fix_types(d: Dictionary) -> void:
	for k in ["day", "seeds", "fodder", "candy", "prestige", "next_uid", "chapter", "speed"]:
		if d.has(k): d[k] = int(d[k])
	for c in d.get("cats", []):
		for k in ["uid", "rarity", "level", "xp", "lives", "fur", "nurse_cd", "kills", "joined"]:
			if c.has(k): c[k] = int(c[k])
	for t in d.get("tiles", []):
		t.stars = int(t.get("stars", 0))
	var seen := []
	for v in d.get("seen_intro", []): seen.append(int(v))
	d.seen_intro = seen


func _bind() -> void:
	sim.event.connect(_on_sim_event)


func _on_sim_event(kind: String, data: Dictionary) -> void:
	match kind:
		"save": save_game()
		"sfx": Sound.play(data.name)


func save_game() -> void:
	if sim == null: return
	sim.s.last_saved = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(sim.s))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _process(delta: float) -> void:
	if not running or sim == null: return
	if paused or modal_pause > 0: return
	if hitstop > 0.0:
		hitstop -= delta
		return
	_acc += minf(delta, 0.25) * float(sim.s.speed)
	var steps := 0
	while _acc >= Sim.TICK and steps < 80:
		sim.tick(Sim.TICK)
		_acc -= Sim.TICK
		steps += 1


func set_speed(v: int) -> void:
	if sim == null: return
	sim.s.speed = clampi(v, 1, 3)
	if sim.s.speed == 3 and int(sim.s.day) < 10 and int(sim.s.prestige) == 0:
		sim.s.speed = 2
		sim.toast("3배속은 10일째부터 열려요", "warn")


func cycle_speed() -> void:
	if sim == null: return
	var nxt := int(sim.s.speed) + 1
	if nxt > 3 or (nxt == 3 and int(sim.s.day) < 10 and int(sim.s.prestige) == 0): nxt = 1
	sim.s.speed = nxt


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if running: save_game()
		Settings.save_settings()
