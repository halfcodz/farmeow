extends Node
## 진행 상태 · 입력 설정 · 저장 · 히트스톱

signal shake(amount: float)
signal state_changed

const SAVE := "user://meowmory_save.json"

var max_hp := 5
var hp := 5
var orbs := 0
var orbs_total := 0
var has_double := false
var has_dash := false
var memories: Array = []         # 찾은 기억 번호
var flags := {}                  # 본 대사 · 연출
var checkpoint := Vector2.ZERO   # 사당 위치 (월드 px)
var boss_down := false
var deaths := 0
var playtime := 0.0
var in_dialog := false

var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func _process(delta: float) -> void:
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0
	if not get_tree().paused: playtime += delta


## 타격 순간 시간을 거의 멈춘다 (손맛)
func hitstop(sec: float) -> void:
	Engine.time_scale = 0.03
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(sec * 1000.0))


func kick(amount: float) -> void:
	if Settings.shake: shake.emit(amount)


func new_run() -> void:
	max_hp = 5; hp = 5; orbs = 0; orbs_total = 0
	has_double = false; has_dash = false
	memories = []; flags = {}; checkpoint = Vector2.ZERO
	boss_down = false; deaths = 0; playtime = 0.0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE)


func save_game() -> void:
	var d := {"max_hp": max_hp, "orbs": orbs, "orbs_total": orbs_total, "double": has_double, "dash": has_dash,
		"memories": memories, "flags": flags, "cx": checkpoint.x, "cy": checkpoint.y, "boss": boss_down,
		"deaths": deaths, "playtime": playtime}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not has_save(): return false
	var d = JSON.parse_string(FileAccess.open(SAVE, FileAccess.READ).get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return false
	max_hp = int(d.max_hp); hp = max_hp; orbs = int(d.orbs); orbs_total = int(d.get("orbs_total", 0))
	has_double = d.double; has_dash = d.dash
	memories = []
	for m in d.memories: memories.append(int(m))
	flags = d.flags; checkpoint = Vector2(d.cx, d.cy); boss_down = d.boss
	deaths = int(d.get("deaths", 0)); playtime = float(d.get("playtime", 0.0))
	return true


# ── 입력: 키보드 + 게임패드 (Steam Deck 포함) ──

func _key(action: String, keys: Array, pads: Array = [], mouse: Array = []) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in pads:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(action, e)


func _axis(action: String, axis: int, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_key("left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_key("right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_key("up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_key("down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_axis("up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("down", JOY_AXIS_LEFT_Y, 1.0)
	_key("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A])
	_key("attack", [KEY_X, KEY_J], [JOY_BUTTON_X], [MOUSE_BUTTON_LEFT])
	_key("dash", [KEY_C, KEY_SHIFT, KEY_L], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B], [MOUSE_BUTTON_RIGHT])
	_key("interact", [KEY_E, KEY_ENTER], [JOY_BUTTON_Y])
	_key("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
