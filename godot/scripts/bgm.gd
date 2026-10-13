extends Node
## 两条占位循环：大地图低音，登基夜高音。静音关的是 BGM 总线，播放本身停不下来也不会出声。

var muted := false
var mode := "map"

var _map: AudioStreamPlayer
var _story: AudioStreamPlayer
var _map_phase := 0.0
var _story_phase := 0.0
var _fade: Tween


func _ready() -> void:
	_ensure_bus()
	_map = _make_player(-8.0)
	_story = _make_player(-80.0)
	_map.play()
	_story.play()


func set_mode(next: String) -> void:
	if next != "map" and next != "story":
		return
	if next == mode:
		return
	mode = next
	var map_db := -8.0 if mode == "map" else -80.0
	var story_db := -8.0 if mode == "story" else -80.0
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(_map, "volume_db", map_db, 0.8)
	_fade.tween_property(_story, "volume_db", story_db, 0.8)


func set_muted(value: bool) -> void:
	muted = value
	var idx := AudioServer.get_bus_index("BGM")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func toggle_muted() -> bool:
	set_muted(not muted)
	return muted


func _exit_tree() -> void:
	for player in [_map, _story]:
		if player == null:
			continue
		player.stop()
		player.stream = null


func _process(_delta: float) -> void:
	_fill(_map, "map")
	_fill(_story, "story")


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("BGM") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "BGM")
	AudioServer.set_bus_send(idx, "Master")


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.2
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "BGM"
	add_child(player)
	return player


func _fill(player: AudioStreamPlayer, kind: String) -> void:
	if player == null:
		return
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var available := playback.get_frames_available()
	var rate := 22050.0
	var low := 110.0 if kind == "map" else 246.94
	var high := 164.81 if kind == "map" else 329.63
	var lfo_hz := 0.33 if kind == "map" else 0.2
	for _i in available:
		var phase := _map_phase if kind == "map" else _story_phase
		var t := phase / rate
		var lfo := 0.62 + 0.38 * sin(t * TAU * lfo_hz)
		var sample := sin(TAU * low * t) * 0.16 + sin(TAU * high * t) * 0.07
		sample *= lfo
		playback.push_frame(Vector2(sample, sample))
		if kind == "map":
			_map_phase += 1.0
		else:
			_story_phase += 1.0
