extends Node
## 四条循环：地图、简战、剧情、结局。程序生成 WAV，静音关 BGM 总线，主音量走 Master。

var muted := false
var mode := "map"
## 0..1，1 是 0 dB。默认不满格，听得清，纯音不顶满。
var master_linear := 0.8

var _players: Dictionary = {}
var _fade: Tween

const _ACTIVE_DB := -4.0
const _IDLE_DB := -80.0
const _RATE := 22050
const _FADE_SEC := 0.6


func _ready() -> void:
	_ensure_bus()
	set_master_linear(master_linear)
	_players["map"] = _make_player("map", _wav("map"), _ACTIVE_DB)
	_players["battle"] = _make_player("battle", _wav("battle"), _IDLE_DB)
	_players["story"] = _make_player("story", _wav("story"), _IDLE_DB)
	_players["ending"] = _make_player("ending", _wav("ending"), _IDLE_DB)
	for key in _players:
		(_players[key] as AudioStreamPlayer).play()


func track(kind: String) -> AudioStreamPlayer:
	return _players.get(kind) as AudioStreamPlayer


func set_mode(next: String) -> void:
	if not _players.has(next):
		return
	if next == mode:
		_keep_playing()
		return
	mode = next
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	for key in _players:
		var db := _ACTIVE_DB if key == mode else _IDLE_DB
		_fade.tween_property(_players[key], "volume_db", db, _FADE_SEC)
	_keep_playing()


func set_master_linear(value: float) -> void:
	master_linear = clampf(value, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var db := -80.0 if master_linear <= 0.001 else linear_to_db(master_linear)
	AudioServer.set_bus_volume_db(idx, db)


func set_muted(value: bool) -> void:
	muted = value
	var idx := AudioServer.get_bus_index("BGM")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func _exit_tree() -> void:
	_release_players()


func _keep_playing() -> void:
	for key in _players:
		var player := _players[key] as AudioStreamPlayer
		if player != null and not player.playing:
			player.play()


func _release_players() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
		_fade = null
	for key in _players.keys():
		var player := _players[key] as AudioStreamPlayer
		if player == null:
			continue
		player.stop()


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("BGM") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "BGM")
	AudioServer.set_bus_send(idx, "Master")


func _make_player(kind: String, stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "Track_%s" % kind
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "BGM"
	# CoreAudio（编辑器 F5 和 macOS .app）没有 sample 播放。强制 SAMPLE 时
	# AudioServer 只警告 "driver doesn't support sample playback"，混音器不出力。
	# STREAM 才走 audio_server_process，声卡听得到。Dummy 无头也能进入 playing。
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	return player


func _wav(kind: String) -> AudioStreamWAV:
	var frames := _RATE
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(_RATE)
		var sample := clampf(_tone(kind, t), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _tone(kind: String, t: float) -> float:
	if kind == "battle":
		var beat := fmod(t, 0.5)
		var env := exp(-beat * 14.0)
		var drum := sin(TAU * 72.0 * t) * env * 0.42
		var tick := sin(TAU * 196.0 * beat) * env * 0.12
		return drum + tick
	if kind == "story":
		var lfo := 0.72 + 0.28 * sin(t * TAU * 0.2)
		return (sin(TAU * 247.0 * t) * 0.11 + sin(TAU * 330.0 * t) * 0.05) * lfo
	if kind == "ending":
		var end_lfo := 0.55 + 0.45 * sin(t * TAU * 0.12)
		return (sin(TAU * 98.0 * t) * 0.12 + sin(TAU * 146.0 * t) * 0.05) * end_lfo
	var map_lfo := 0.62 + 0.38 * sin(t * TAU * 0.33)
	return (sin(TAU * 110.0 * t) * 0.15 + sin(TAU * 165.0 * t) * 0.06) * map_lfo
