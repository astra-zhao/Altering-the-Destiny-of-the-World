extends SceneTree
## 无头自检：地图、简战、剧情 S1–S3、结算的 BGM 播放器在播、音量听得见、流里有数据。
## godot --headless --path godot -s res://scripts/bgm_check.gd

var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var bgm := root.get_node_or_null("Bgm")
	if bgm == null:
		_fail("autoload Bgm 不在场景树上")
		await _finish()
		return
	print("BGM_CHECK driver=%s" % AudioServer.get_driver_name())
	_check_master(bgm)
	await _visit("地图", "res://scenes/big_map.tscn", "map", bgm)
	bgm.set_mode("battle")
	await _expect("简战", "battle", bgm)
	await _visit("剧情S1", "res://scenes/s1_night.tscn", "story", bgm)
	await _visit("剧情S2", "res://scenes/s2_yuan.tscn", "story", bgm)
	await _visit("剧情S3", "res://scenes/s3_crisis.tscn", "story", bgm)
	await _visit("结算", "res://scenes/ending.tscn", "ending", bgm)
	await _visit("回到地图", "res://scenes/big_map.tscn", "map", bgm)
	_check_mute(bgm)
	await _finish()


func _visit(label: String, path: String, kind: String, bgm: Node) -> void:
	var err := change_scene_to_file(path)
	if err != OK:
		_fail("%s 无法加载 %s（%s）" % [label, path, error_string(err)])
		return
	var loaded := false
	for _i in 40:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			loaded = true
			break
	if not loaded:
		_fail("%s 场景没有换成 %s" % [label, path])
		return
	await _expect(label, kind, bgm)


func _expect(label: String, kind: String, bgm: Node) -> void:
	await _wait_sec(1.0)
	if str(bgm.mode) != kind:
		_fail("%s 模式是 %s，期望 %s" % [label, str(bgm.mode), kind])
	for track_name in ["map", "battle", "story", "ending"]:
		var other := bgm.track(track_name) as AudioStreamPlayer
		if other == null or not other.playing:
			_fail("%s 切换后 %s 播放器没有在播" % [label, track_name])
	var player := bgm.track(kind) as AudioStreamPlayer
	if player == null:
		_fail("%s 没有 %s 播放器" % [label, kind])
		return
	var stream := player.stream as AudioStreamWAV
	var bytes := stream.data.size() if stream != null else 0
	print(
		"BGM_CHECK %s mode=%s playing=%s vol=%.1f bytes=%d type=%s"
		% [label, kind, player.playing, player.volume_db, bytes, player.playback_type]
	)
	if not player.playing:
		_fail("%s 的 %s 播放器没有 playing" % [label, kind])
	if player.volume_db <= -60.0:
		_fail("%s 的 %s 音量 %.1f dB，没有高于 -60 dB" % [label, kind, player.volume_db])
	if stream == null or stream.data.is_empty() or not _wav_has_samples(stream):
		_fail("%s 的 %s 流是空的" % [label, kind])
	elif stream.loop_mode != AudioStreamWAV.LOOP_FORWARD or stream.loop_end <= stream.loop_begin:
		_fail("%s 的 %s 没有向前循环" % [label, kind])
	if player.playback_type != AudioServer.PLAYBACK_TYPE_STREAM:
		_fail("%s 的 %s 仍是 Sample 播放，macOS CoreAudio 会丢声" % [label, kind])


func _check_master(bgm: Node) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx < 0:
		_fail("没有 Master 总线")
		return
	var db := AudioServer.get_bus_volume_db(idx)
	print("BGM_CHECK master_db=%.1f linear=%.2f" % [db, float(bgm.master_linear)])
	if db <= -60.0:
		_fail("主音量 %.1f dB，默认听不见" % db)
	var bgm_idx := AudioServer.get_bus_index("BGM")
	if bgm_idx < 0:
		_fail("没有 BGM 总线")
	elif AudioServer.is_bus_mute(bgm_idx):
		_fail("BGM 总线默认被静音")


func _check_mute(bgm: Node) -> void:
	var idx := AudioServer.get_bus_index("BGM")
	if idx < 0:
		return
	var muted: bool = bgm.toggle_muted()
	if not muted or not AudioServer.is_bus_mute(idx):
		_fail("静音开关没有关掉 BGM 总线")
	var player := bgm.track("map") as AudioStreamPlayer
	if player == null or not player.playing or player.volume_db <= -60.0:
		_fail("静音把播放器停掉或拉低了音量，取消静音后回不来")
	bgm.toggle_muted()
	if AudioServer.is_bus_mute(idx):
		_fail("取消静音后 BGM 总线仍是静音")


func _wav_has_samples(stream: AudioStreamWAV) -> bool:
	var size := stream.data.size()
	if size < 4:
		return false
	var step := maxi(2, (size / 2) / 32 * 2)
	var i := 0
	while i + 1 < size:
		if stream.data.decode_s16(i) != 0:
			return true
		i += step
	return false


func _wait_sec(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	var guard := 0
	while Time.get_ticks_msec() - start < int(seconds * 1000.0) and guard < 600:
		await process_frame
		guard += 1


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var bgm := root.get_node_or_null("Bgm")
	if bgm != null and bgm.has_method("release_playback"):
		bgm.release_playback()
		await _wait_sec(0.45)
	if _failures.is_empty():
		print("BGM_CHECK_OK")
		quit(0)
		return
	for message in _failures:
		print("BGM_CHECK_FAIL %s" % message)
	quit(1)
