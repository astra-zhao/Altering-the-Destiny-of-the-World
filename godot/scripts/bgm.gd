extends Node
## 四条循环：地图、简战、剧情、结局。默认读 audio/tracks 里的 OGG，缺文件才退回程序音。静音关 BGM 总线，主音量走 Master。

var muted := false
var mode := "map"
## 0..1，1 是 0 dB。默认不满格，听得清，纯音不顶满。滑条和静音会记在本机。
var master_linear := 0.8

var _players: Dictionary = {}
var _fade: Tween
var _released := false
var _quit_scheduled := false

const _ACTIVE_DB := -4.0
const _IDLE_DB := -80.0
const _RATE := 22050
const _FADE_SEC := 0.6
const _PREFS_PATH := "user://audio_prefs.json"
## 换曲只替换这四个文件，文件名不要改。
const TRACK_FILES := {
	"map": "res://audio/tracks/map.ogg",
	"battle": "res://audio/tracks/battle.ogg",
	"story": "res://audio/tracks/story.ogg",
	"ending": "res://audio/tracks/ending.ogg",
}


func _ready() -> void:
	_ensure_bus()
	_load_prefs()
	set_master_linear(master_linear)
	set_muted(muted)
	_players["map"] = _make_player("map", _load_stream("map"), _ACTIVE_DB)
	_players["battle"] = _make_player("battle", _load_stream("battle"), _IDLE_DB)
	_players["story"] = _make_player("story", _load_stream("story"), _IDLE_DB)
	_players["ending"] = _make_player("ending", _load_stream("ending"), _IDLE_DB)
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
	_save_prefs()


func set_muted(value: bool) -> void:
	muted = value
	var idx := AudioServer.get_bus_index("BGM")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
	_save_prefs()


func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	# 通知先于 close_requested。先关掉自动退出，等音频线程把 Stream 淡出删掉再 quit，
	# 否则退出时会漏掉 WAV 和 playback。
	var tree := get_tree()
	if tree != null:
		tree.auto_accept_quit = false
	_schedule_quit()


func _schedule_quit() -> void:
	if _quit_scheduled:
		return
	_quit_scheduled = true
	release_playback()
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func() -> void:
		if is_inside_tree():
			get_tree().quit()
	)


func release_playback() -> void:
	if _released:
		return
	_released = true
	if _fade != null and _fade.is_valid():
		_fade.kill()
		_fade = null
	for key in _players.keys():
		var player := _players[key] as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	release_playback()


func _keep_playing() -> void:
	for key in _players:
		var player := _players[key] as AudioStreamPlayer
		if player != null and not player.playing:
			player.play()


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("BGM") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "BGM")
	AudioServer.set_bus_send(idx, "Master")


func _load_prefs() -> void:
	if not FileAccess.file_exists(_PREFS_PATH):
		return
	var file := FileAccess.open(_PREFS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var linear: Variant = parsed.get("linear", null)
	if typeof(linear) == TYPE_FLOAT or typeof(linear) == TYPE_INT:
		master_linear = clampf(float(linear), 0.0, 1.0)
	if typeof(parsed.get("muted", null)) == TYPE_BOOL:
		muted = bool(parsed["muted"])


func _save_prefs() -> void:
	var file := FileAccess.open(_PREFS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"linear": master_linear, "muted": muted}))


func _load_stream(kind: String) -> AudioStream:
	var path := str(TRACK_FILES.get(kind, ""))
	if path != "" and ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is AudioStreamOggVorbis:
			var stream := (loaded as AudioStreamOggVorbis).duplicate(true) as AudioStreamOggVorbis
			stream.loop = true
			stream.loop_offset = 0.0
			return stream
	push_warning("缺少可替换曲目 %s，暂用程序音。" % path)
	return _wav(kind)


func _make_player(kind: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
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
