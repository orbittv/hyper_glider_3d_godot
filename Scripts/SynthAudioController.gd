class_name SynthAudioController
extends Node

## Аудио-контроллер игры Hyper Glider 3D на базе WAV/MP3 ресурсов (res://Assets/).
## Обеспечивает бесшовный луп Synthwave-музыки, полифонический пул SFX без утечек ObjectDB,
## звуки плазменных пушек, пулемёта, квантового лазера, ракет, раскола 3D-метеоритов и прорыва в Гипер-туннель.

const SFX_POOL_SIZE: int = 8
const BASE_MUSIC_DB: float = -15.0
const BASE_SFX_DB: float = -5.0

var music_volume: float = 0.85
var sfx_volume: float = 0.90

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _last_asteroid_explode_msec: int = 0
var _last_laser_hum_msec: int = 0
var _last_plasma_fire_msec: int = 0

var _stream_music: AudioStreamMP3
var _stream_orb_pickup: AudioStreamWAV
var _stream_orb_winning: AudioStreamWAV
var _stream_graze: AudioStreamWAV
var _stream_hyperjump: AudioStreamWAV
var _stream_shield_hit: AudioStreamWAV
var _stream_shield_restore: AudioStreamWAV
var _stream_asteroid_explode: AudioStreamWAV
var _stream_game_over: AudioStreamWAV
var _stream_ui_click: AudioStreamWAV
var _stream_bullet_fire: AudioStreamWAV
var _stream_missile_launch: AudioStreamWAV


func _ready() -> void:
	_load_wav_streams()
	_setup_players()
	apply_volumes(music_volume, sfx_volume)


func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	for p: AudioStreamPlayer in _sfx_pool:
		if p != null:
			p.stop()
			p.stream = null
	_stream_music = null
	_stream_orb_pickup = null
	_stream_orb_winning = null
	_stream_graze = null
	_stream_hyperjump = null
	_stream_shield_hit = null
	_stream_shield_restore = null
	_stream_asteroid_explode = null
	_stream_game_over = null
	_stream_ui_click = null
	_stream_bullet_fire = null
	_stream_missile_launch = null


func _load_wav_streams() -> void:
	_stream_music = load("res://Assets/Music/Sprint_Select8.mp3") as AudioStreamMP3
	if _stream_music != null:
		_stream_music.loop = true

	_stream_orb_pickup = load("res://Assets/Audio/SfxOrbPickup.wav") as AudioStreamWAV
	_stream_orb_winning = load("res://Assets/Audio/SfxOrbWinning.wav") as AudioStreamWAV
	_stream_graze = load("res://Assets/Audio/SfxGraze.wav") as AudioStreamWAV
	_stream_hyperjump = load("res://Assets/Audio/SfxHyperjump.wav") as AudioStreamWAV
	_stream_shield_hit = load("res://Assets/Audio/SfxShieldHit.wav") as AudioStreamWAV
	_stream_shield_restore = load("res://Assets/Audio/SfxShieldRestore.wav") as AudioStreamWAV
	_stream_asteroid_explode = load("res://Assets/Audio/SfxAsteroidExplode.wav") as AudioStreamWAV
	_stream_game_over = load("res://Assets/Audio/SfxGameOver.wav") as AudioStreamWAV
	_stream_ui_click = load("res://Assets/Audio/SfxUiClick.wav") as AudioStreamWAV
	_stream_bullet_fire = load("res://Assets/Audio/SfxBulletFire.wav") as AudioStreamWAV
	_stream_missile_launch = load("res://Assets/Audio/SfxMissileLaunch.wav") as AudioStreamWAV


func _setup_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _stream_music
	add_child(_music_player)
	if _stream_music != null and DisplayServer.get_name() != "headless":
		_music_player.play()

	_sfx_pool.clear()
	for i: int in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)


func apply_volumes(new_music_vol: float, new_sfx_vol: float) -> void:
	music_volume = clampf(new_music_vol, 0.0, 1.0)
	sfx_volume = clampf(new_sfx_vol, 0.0, 1.0)

	if _music_player != null:
		if music_volume <= 0.01:
			_music_player.volume_db = -80.0
		else:
			_music_player.volume_db = BASE_MUSIC_DB + linear_to_db(music_volume)


func set_hyper_mode(enabled: bool) -> void:
	if _music_player != null:
		_music_player.pitch_scale = 1.12 if enabled else 1.0


func set_tunnel_mode(enabled: bool) -> void:
	if _music_player != null:
		_music_player.pitch_scale = 1.18 if enabled else 1.0


func _play_sfx(stream: AudioStreamWAV, pitch: float = 1.0, vol_scale: float = 1.0) -> void:
	if stream == null or sfx_volume <= 0.01 or _sfx_pool.is_empty() or DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = null
	for i: int in range(_sfx_pool.size()):
		var idx: int = (_sfx_cursor + i) % _sfx_pool.size()
		if not _sfx_pool[idx].playing:
			player = _sfx_pool[idx]
			_sfx_cursor = (idx + 1) % _sfx_pool.size()
			break
	if player == null:
		player = _sfx_pool[_sfx_cursor]
		_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = BASE_SFX_DB + linear_to_db(clampf(sfx_volume * vol_scale, 0.001, 1.0))
	player.play()


func play_orb_pickup(is_high_energy: bool, combo: int = 1) -> void:
	var combo_pitch: float = float(clampi(combo - 1, 0, 5)) * 0.03
	var high_lift: float = 0.08 if is_high_energy else 0.0
	_play_sfx(_stream_orb_pickup, randf_range(0.94, 1.08) + combo_pitch + high_lift, 0.80)


func play_weapon_pickup() -> void:
	_play_sfx(_stream_orb_winning, randf_range(0.98, 1.06), 0.95)


func play_graze(combo: int = 1) -> void:
	var combo_pitch: float = float(clampi(combo - 1, 0, 5)) * 0.04
	_play_sfx(_stream_graze, randf_range(0.96, 1.05) + combo_pitch, 0.88)


func play_hyperjump() -> void:
	_play_sfx(_stream_hyperjump, 1.0, 1.0)


func play_black_hole_enter() -> void:
	_play_sfx(_stream_hyperjump, 0.78, 1.0)
	_play_sfx(_stream_orb_winning, 1.15, 0.85)


func play_shield_hit() -> void:
	_play_sfx(_stream_shield_hit, 1.0, 1.0)


func play_shield_restore() -> void:
	_play_sfx(_stream_shield_restore, 1.0, 0.9)


func play_asteroid_explode() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_asteroid_explode_msec < 55:
		return
	_last_asteroid_explode_msec = now_msec
	_play_sfx(_stream_asteroid_explode, randf_range(0.88, 1.14), 0.95)


func play_bomb_explode() -> void:
	_play_sfx(_stream_asteroid_explode, randf_range(0.65, 0.76), 1.0)
	_play_sfx(_stream_hyperjump, randf_range(1.26, 1.40), 0.65)


func play_game_over() -> void:
	_play_sfx(_stream_game_over, 1.0, 1.0)


func play_ui_click() -> void:
	_play_sfx(_stream_ui_click, randf_range(0.98, 1.04), 0.75)


func play_plasma_fire(is_heavy: bool = false) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_plasma_fire_msec < 65:
		return
	_last_plasma_fire_msec = now_msec
	var pitch: float = randf_range(0.62, 0.74) if is_heavy else randf_range(0.82, 0.95)
	var vol: float = 0.78 if is_heavy else 0.56
	_play_sfx(_stream_bullet_fire, pitch, vol)


func play_bullet_fire() -> void:
	_play_sfx(_stream_bullet_fire, randf_range(1.02, 1.16), 0.52)


func play_laser_hum() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_laser_hum_msec < 120:
		return
	_last_laser_hum_msec = now_msec
	_play_sfx(_stream_graze, randf_range(1.26, 1.40), 0.42)


func play_missile_launch() -> void:
	_play_sfx(_stream_missile_launch, randf_range(0.95, 1.06), 0.88)


func play_enemy_fire() -> void:
	_play_sfx(_stream_bullet_fire, randf_range(0.48, 0.58), 0.50)


func play_boss_warning() -> void:
	_play_sfx(_stream_shield_hit, 0.62, 0.95)


func play_boss_explode() -> void:
	_play_sfx(_stream_asteroid_explode, 0.56, 1.0)
	_play_sfx(_stream_hyperjump, 0.82, 0.95)
