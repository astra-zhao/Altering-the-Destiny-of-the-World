extends SceneTree
func _initialize() -> void:
	_run()
func _peak() -> float:
	var i := AudioServer.get_bus_index("Master")
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
func _w(s: float) -> void:
	await create_timer(s).timeout
func _probe(label: String) -> void:
	var m := -200.0
	for k in 20:
		await _w(0.1)
		m = maxf(m, _peak())
	print("QA_AUDIO %s driver=%s peak_db=%.1f mode=%s" % [label, AudioServer.get_driver_name(), m, str(root.get_node("Bgm").mode)])
func _scene(p: String) -> void:
	change_scene_to_file(p)
	for i in 30: await process_frame
func _run() -> void:
	await process_frame
	var bgm = root.get_node("Bgm")
	await _w(1.0)
	await _probe("地图")
	bgm.set_mode("battle"); await _w(1.0); await _probe("简战")
	await _scene("res://scenes/s1_night.tscn"); await _w(1.0); await _probe("剧情S1")
	await _scene("res://scenes/ending.tscn"); await _w(1.0); await _probe("结算")
	await _scene("res://scenes/big_map.tscn"); await _w(1.0)
	bgm.set_master_linear(0.0); await _w(0.5); await _probe("滑条=0")
	bgm.set_master_linear(1.0); await _w(0.5); await _probe("滑条=1.0")
	bgm.set_master_linear(0.8); await _w(0.3)
	quit()
