extends Node
## 음악/효과음. 모든 소리는 CC0 무료 에셋 (assets/CREDITS.md 참고).

const MUSIC := {
	"title": "juhani_title_screen",
	"day": "town_theme",
	"day2": "juhani_level_1",
	"night": "juhani_level_2",
	"night2": "juhani_level_3",
	"boss": "nes_boss",
	"final": "nes_mars",
	"map": "nes_map",
	"ending": "juhani_ending",
}

## 이름 → 후보 파일들 (무작위로 하나 재생해 단조로움을 줄인다)
const SFX := {
	"click": ["ui/click_001", "ui/click_002", "ui/click_003"],
	"hover": ["ui/tick_001", "ui/tick_002"],
	"open": ["ui/open_001", "ui/open_002"],
	"close": ["ui/close_001", "ui/close_002"],
	"error": ["ui/error_004", "ui/error_006"],
	"confirm": ["ui/confirmation_001", "ui/confirmation_002"],
	"toggle": ["ui/toggle_001", "ui/toggle_002"],
	"plant": ["rpg/inventory_cloth", "rpg/inventory_wood-small"],
	"harvest": ["retro/general_sounds/sfx_sounds_interaction5", "retro/general_sounds/sfx_sounds_interaction7"],
	"coin": ["retro/general_sounds/sfx_coin_single1", "retro/general_sounds/sfx_coin_single2", "retro/general_sounds/sfx_coin_single3"],
	"coins": ["retro/general_sounds/sfx_coin_cluster3", "retro/general_sounds/sfx_coin_cluster5"],
	"unlock": ["retro/general_sounds/sfx_sounds_powerup2", "retro/general_sounds/sfx_sounds_powerup4"],
	"hire": ["retro/general_sounds/sfx_sounds_fanfare1"],
	"levelup": ["retro/general_sounds/sfx_sounds_powerup10"],
	"shoot": ["retro/weapons/sfx_weapon_singleshot2", "retro/weapons/sfx_weapon_singleshot7"],
	"lob": ["retro/weapons/sfx_wpn_cannon1", "retro/weapons/sfx_wpn_cannon3"],
	"laser": ["retro/weapons/sfx_wpn_laser6", "retro/weapons/sfx_wpn_laser8"],
	"zap": ["retro/weapons/sfx_wpn_laser2"],
	"boom": ["retro/explosions/sfx_exp_short_soft1", "retro/explosions/sfx_exp_short_soft4"],
	"bigboom": ["retro/explosions/sfx_exp_medium3", "retro/explosions/sfx_exp_long2"],
	"slash": ["rpg/battle_swing", "rpg/battle_swing2", "rpg/battle_swing3"],
	"magic": ["rpg/battle_magic1", "rpg/battle_spell"],
	"hit": ["retro/general_sounds/sfx_damage_hit1", "retro/general_sounds/sfx_damage_hit3"],
	"zdie": ["rpg/NPC_slime_slime3", "rpg/NPC_slime_slime6", "rpg/NPC_beetle_bite-small2"],
	"zgrowl": ["rpg/NPC_gutteral_beast_mnstr2", "rpg/NPC_gutteral_beast_mnstr7"],
	"boss": ["rpg/NPC_giant_giant2", "rpg/NPC_ogre_ogre3"],
	"ghost": ["rpg/NPC_shade_shade4"],
	"wilt": ["retro/general_sounds/sfx_sounds_damage1"],
	"house": ["retro/general_sounds/sfx_sounds_impact4", "retro/general_sounds/sfx_sounds_impact9"],
	"catdown": ["retro/general_sounds/sfx_sounds_negative1"],
	"alarm": ["retro/general_sounds/sfx_alarm_loop3"],
	"dusk": ["retro/general_sounds/sfx_sound_nagger1"],
	"dawn": ["retro/general_sounds/sfx_sounds_fanfare3"],
	"fail": ["retro/general_sounds/sfx_sound_shutdown1"],
	"quest": ["retro/general_sounds/sfx_sounds_powerup16"],
	"heal": ["rpg/inventory_bubble2"],
	"eat": ["rpg/misc_burp"],
	"door": ["rpg/world_door"],
	"step": ["retro/movement/sfx_movement_footsteps1a"],
	"pause": ["retro/general_sounds/sfx_sounds_pause1_in"],
	"meow": ["synth/meow1", "synth/meow2", "synth/meow3", "synth/mew_short"],
	"meow_sad": ["synth/meow_sad"],
	"crit": ["synth/crit"],
	"combo": ["synth/combo"],
	"jackpot": ["synth/jackpot"],
	"bigwin": ["synth/bigwin"],
	"slot_tick": ["synth/slot_tick"],
	"slot_stop": ["synth/slot_stop"],
	"lose": ["synth/lose"],
	"card": ["synth/card_flip"],
	"rare": ["synth/rare"],
	"legend": ["synth/legend"],
	"pop": ["synth/pop"],
	"whoosh": ["synth/whoosh"],
	"rooster": ["synth/rooster"],
	"thit": ["retro/general_sounds/sfx_sounds_impact1", "retro/general_sounds/sfx_sounds_impact2"],
	"freeze": ["retro/general_sounds/sfx_sounds_interaction20"],
	"reveal": ["retro/general_sounds/sfx_sounds_powerup6"],
	"unpause": ["retro/general_sounds/sfx_sounds_pause1_out"],
}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _mk_player("Music")
	_music_b = _mk_player("Music")
	for i in 12:
		_pool.append(_mk_player("SFX"))


func _mk_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		var s = load(path)
		_cache[path] = s
	return _cache[path]


func music(key: String) -> void:
	if key == _current:
		return
	_current = key
	var file: String = MUSIC.get(key, "")
	var s := _stream("res://assets/audio/music/%s.ogg" % file) as AudioStreamOggVorbis
	if s == null:
		return
	s.loop = true
	var old := _music_a if _music_a.playing else _music_b
	var nxt := _music_b if old == _music_a else _music_a
	nxt.stream = s
	nxt.volume_db = -40
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, 1.2)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(old.stop)


func play(name: String, pitch_jitter: float = 0.06, vol_db: float = 0.0) -> void:
	if not SFX.has(name):
		return
	# 같은 소리가 한 프레임에 수십 번 겹치지 않게 (밤 전투 대비)
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < (70 if name in ["hit", "slash", "coin", "zdie", "shoot", "thit", "zgrowl"] else 40):
		return
	_last_play[name] = now
	var list: Array = SFX[name]
	var s := _stream("res://assets/audio/sfx/%s.ogg" % list[randi() % list.size()])
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = vol_db
			p.play()
			return
