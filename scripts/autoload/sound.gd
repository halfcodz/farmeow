extends Node
## 음악(교차 페이드)과 효과음. 모두 CC0 또는 자체 합성.

const SFX := {
	"step": ["retro/movement/sfx_movement_footsteps1a", "retro/movement/sfx_movement_footsteps1b"],
	"jump": ["synth/jump"],
	"djump": ["synth/djump"],
	"land": ["synth/land"],
	"dash": ["synth/dash"],
	"swish": ["synth/swish", "synth/swish2"],
	"hit": ["retro/general/sfx_damage_hit2", "retro/general/sfx_damage_hit5", "retro/general/sfx_damage_hit7"],
	"thump": ["synth/thump"],
	"crit": ["synth/crit"],
	"kill": ["rpg/NPC_slime_slime3", "rpg/NPC_slime_slime6", "rpg/NPC_beetle_bite-small2"],
	"hurt": ["synth/hurt"],
	"orb": ["synth/orb"],
	"heal": ["synth/heal"],
	"wisp": ["synth/wisp"],
	"memory": ["synth/memory"],
	"shrine": ["synth/shrine"],
	"ability": ["synth/legend"],
	"meow": ["synth/meow1", "synth/meow2", "synth/meow3"],
	"meow_sad": ["synth/meow_sad"],
	"mew": ["synth/mew_short"],
	"text": ["synth/text"],
	"click": ["ui/click_002", "ui/click_003"],
	"hover": ["ui/tick_001"],
	"open": ["ui/open_001"],
	"close": ["ui/close_001"],
	"confirm": ["ui/confirmation_001"],
	"growl": ["rpg/NPC_gutteral_beast_mnstr2", "rpg/NPC_gutteral_beast_mnstr7"],
	"roar": ["synth/roar"],
	"boss_hit": ["rpg/NPC_ogre_ogre1", "rpg/NPC_ogre_ogre3"],
	"slam": ["retro/explosions/sfx_exp_medium3", "retro/explosions/sfx_exp_short_hard2"],
	"boom": ["retro/explosions/sfx_exp_short_soft1", "retro/explosions/sfx_exp_short_soft4"],
	"spit": ["retro/weapons/sfx_wpn_laser2"],
	"flap": ["rpg/inventory_cloth"],
	"wall": ["retro/movement/sfx_movement_ladder1a"],
	"whoosh": ["synth/whoosh"],
	"pop": ["synth/pop"],
	"gate": ["retro/explosions/sfx_exp_shortest_hard1"],
}

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _cur := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _mk("Music")
	_b = _mk("Music")
	_amb = _mk("Music")
	for i in 16: _pool.append(_mk("SFX"))


func _mk(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load(path: String) -> AudioStream:
	if not _cache.has(path): _cache[path] = load(path)
	return _cache[path]


func music(name: String, fade: float = 1.5) -> void:
	if name == _cur: return
	_cur = name
	var old := _a if _a.playing else _b
	var nxt := _b if old == _a else _a
	var tw := create_tween().set_parallel(true)
	if name != "":
		var s := _load("res://assets/music/%s.ogg" % name) as AudioStreamOggVorbis
		s.loop = true
		nxt.stream = s
		nxt.volume_db = -40
		nxt.play()
		tw.tween_property(nxt, "volume_db", 0.0, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)


func ambience(on: bool) -> void:
	if on and not _amb.playing:
		var s := _load("res://assets/music/ambience.ogg") as AudioStreamOggVorbis
		s.loop = true
		_amb.stream = s
		_amb.volume_db = -14
		_amb.play()
	elif not on:
		_amb.stop()


func play(name: String, vol: float = 0.0, pitch: float = 1.0, jitter: float = 0.07) -> void:
	if not SFX.has(name): return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -999)) < 35: return
	_last[name] = now
	var list: Array = SFX[name]
	var s := _load("res://assets/sfx/%s.ogg" % list[randi() % list.size()])
	if s == null: return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol
			p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
			p.play()
			return
