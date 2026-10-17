extends Node
## 三条循环：地图低音、简战鼓点、登基夜高音。做成 WAV 循环，避免 AudioStreamGeneratorPlayback 在退出时泄漏。静音关的是 BGM 总线，三条一起哑。

var muted := false
var mode := "map"

var _players: Dictionary = {}
var _fade: Tween

const _ACTIVE_DB := -8.0
const _IDLE_DB := -80.0
const _RATE := 22050
const _FADE_SEC := 0.6


func _ready() -> void:
	_ensure_bus()
	_players["map"] = _make_player(_wav("map"), _ACTIVE_DB)
	_players["battle"] = _make_player(_wav("battle"), _IDLE_DB)
	_players["story"] = _make_player(_wav("story"), _IDLE_DB)
	# Dummy 驱动播不了 sample，而且本来就没有声卡。真驱动用 sample，停止时会马上释放，退出才不会报播放泄漏。
	if AudioServer.get_driver_name() != "Dummy":
		for key in _players:
			(_players[key] as AudioStreamPlayer).play()


func set_mode(next: String) -> void:
	if not _players.has(next):
		return
	if next == mode:
		return
	mode = next
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	for key in _players:
		var db := _ACTIVE_DB if key == mode else _IDLE_DB
		_fade.tween_property(_players[key], "volume_db", db, _FADE_SEC)


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


func _make_player(stream: AudioStreamWAV, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "BGM"
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
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
	var map_lfo := 0.62 + 0.38 * sin(t * TAU * 0.33)
	return (sin(TAU * 110.0 * t) * 0.15 + sin(TAU * 165.0 * t) * 0.06) * map_lfo
