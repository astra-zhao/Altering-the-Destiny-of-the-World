extends Node
## v0.3.1 界面出图。不进游玩路径。
## godot --path godot res://scenes/qa_v031_shots.tscn

const AdvisorScript := preload("res://scripts/advisor.gd")

var _dir := "/tmp/v031-shots"


func _ready() -> void:
	call_deferred("_reparent_and_run")


func _reparent_and_run() -> void:
	var tree := get_tree()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	_apply_size()
	_write_guide()
	AdvisorScript.set_self_pick(false)
	Campaign.reset()
	Campaign.guide_done = true
	Campaign.guide_step = 3
	var map := await _open("res://scenes/big_map.tscn")
	if map == null:
		return
	await _wait(0.4)
	_layout(map)
	await _forecast(map, "yi", 40, 50, 0, 35, 40, "前线可用")
	await _shot("forecast-yi")
	_print_forecast(map)
	await _forecast(map, "jia", 60, 40, 35, 35, 40, "前线可用")
	await _shot("forecast-jia")
	await _forecast(map, "bing", 36, 50, 20, 30, 20, "前线可用")
	await _shot("forecast-bing")
	_print_forecast(map)
	await _forecast(map, "ding", 32, 50, 20, 10, 0, "前线可用")
	await _shot("forecast-ding")
	_warn(map, 22, 8, 40)
	await _shot("warn-yellow")
	_warn(map, 10, 0, 30)
	await _shot("warn-red")
	Campaign.reset()
	Campaign.guide_done = true
	Campaign.turn = 6
	_layout(map)
	map._refresh()
	await _shot("banner-turn6")
	Campaign.reset()
	Campaign.guide_done = true
	_layout(map)
	map._refresh()
	map._on_city_pressed("C2")
	await _wait(0.2)
	map._on_march_mode()
	await _wait(0.2)
	await _shot("march-highlight")
	map._on_help()
	await _wait(0.2)
	await _shot("advisor-star")
	AdvisorScript.set_self_pick(true)
	map._fill_advisor()
	await _wait(0.1)
	await _shot("advisor-self-pick")
	AdvisorScript.set_self_pick(false)
	await _story("res://scenes/s1_night.tscn", "s1")
	await _story("res://scenes/s2_yuan.tscn", "s2")
	await _story("res://scenes/s3_crisis.tscn", "s3")
	await _ending()
	print("V031_SHOTS_OK")
	get_tree().quit(0)


func _forecast(map: Node, _tag: String, liao: int, pressure: int, world: int, morale: int, silver: int, yuan: String) -> void:
	Campaign.liaodong = liao
	Campaign.pressure = pressure
	Campaign.worldline = world
	Campaign.morale = morale
	Campaign.silver = silver
	Campaign.yuan_status = yuan
	Campaign.city("C1")["faction"] = "明"
	_layout(map)
	map._refresh()
	await _wait(0.05)


func _warn(map: Node, morale: int, silver: int, liao: int) -> void:
	Campaign.morale = morale
	Campaign.silver = silver
	Campaign.liaodong = liao
	_layout(map)
	map._refresh()
	map._log.text = Campaign.danger_line()
	await _wait(0.05)


func _print_forecast(map: Node) -> void:
	var bar: Control = map._forecast_bar
	var bits: Control = map._forecast_bits
	var text := ""
	for child in bits.get_children():
		if child is Label:
			text += (child as Label).text
	print("SHOT_FORECAST rect=%s text=%s avoid_rect=%s" % [bar.get_global_rect(), text, bits.get_global_rect()])


func _story(path: String, tag: String) -> void:
	Campaign.reset()
	Campaign.guide_done = true
	Campaign.turn = 2 if tag == "s1" else (4 if tag == "s2" else 8)
	Campaign.pending_story = tag
	if tag == "s2":
		Campaign.s1_done = true
		Campaign.befriended_yuan = false
	if tag == "s3":
		Campaign.s1_done = true
		Campaign.s2_done = true
		Campaign.turn = 8
	await _open(path)
	await _wait(3.3)
	await _shot(tag)


func _ending() -> void:
	Campaign.reset()
	Campaign.guide_done = true
	Campaign.turn = 8
	Campaign.s1_done = true
	Campaign.s2_done = true
	Campaign.s3_done = true
	Campaign.liaodong = 32
	Campaign.pressure = 41
	Campaign.worldline = 20
	Campaign.morale = 7
	Campaign.silver = 40
	Campaign.yuan_status = "前线可用"
	Campaign.ending_id = Campaign.resolve_ending()
	Campaign.outlook_before_finale = "乙"
	Campaign.settled = true
	await _open("res://scenes/ending.tscn")
	await _wait(0.6)
	await _shot("ending-fail")
	print("SHOT_ENDING ending=%s" % Campaign.ending_id)


func _open(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	for _i in 50:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			_apply_size()
			await get_tree().process_frame
			return scene
	push_error("场景没有起来 %s" % path)
	get_tree().quit(1)
	return null


func _layout(map: Node) -> void:
	map.size = Vector2(1280, 720)
	if map.has_method("_layout_chrome"):
		map._layout_chrome()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_dir)
	var path := "%s/%s.png" % [_dir, file_name]
	var err := image.save_png(path)
	print("V031_SHOT %s %s %dx%d" % [path, err, image.get_width(), image.get_height()])


func _apply_size() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))


func _write_guide() -> void:
	var file := FileAccess.open("user://v03_guide.json", FileAccess.WRITE)
	if file != null:
		file.store_string("{\"dismissed\":true}")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
