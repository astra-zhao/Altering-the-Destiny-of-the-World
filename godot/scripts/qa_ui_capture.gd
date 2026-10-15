extends Node
## 对照 v1.2 出图，或录一回合。不进正式游玩路径。
## godot --path . res://scenes/qa_ui_capture.tscn
## godot --path . --write-movie /tmp/one-turn.avi --fixed-fps 24 -- res://scenes/qa_ui_capture.tscn --movie

const SHOTS := "/opt/cursor/artifacts/screenshots"

var _movie := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--movie":
			_movie = true
	call_deferred("_reparent_and_run")


func _reparent_and_run() -> void:
	var tree := get_tree()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	_clear_guide()
	Campaign.reset()
	if _movie:
		_play_turn()
	else:
		_shots()


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var map := await _open_map()
	await _wait(0.45)
	await _shot("03-civil-disabled")
	map._on_city_pressed("C4")
	await _wait(0.35)
	await _shot("01-map-guide-seals")
	map._guide.visible = false
	await _wait(0.05)
	await _shot("02-advisor")
	map._guide.visible = true
	var preview: Dictionary = Campaign.preview_battle("C4", "C6")
	map.present_battle("C4", "C6", preview, false, 0.42)
	await _wait(0.25)
	await _shot("04-battle-run")
	map.present_battle("C4", "C6", preview, true, 1.0)
	await _wait(0.2)
	await _shot("05-battle-win")
	map.present_battle("C6", "C5", _fake_lose(), true, 1.0)
	await _wait(0.15)
	await _shot("06-battle-lose")
	map.present_battle("C4", "C6", _fake_draw(), true, 1.0)
	await _wait(0.15)
	await _shot("07-battle-draw")
	map._close_battle()
	_reach_bing()
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
	await _wait(0.55)
	await _shot("08-ending")
	print("UI_CAPTURE_OK")
	get_tree().quit(0)


func _play_turn() -> void:
	var map := await _open_map()
	await _wait(1.1)
	map._on_city_pressed("C4")
	await _wait(1.3)
	map._try_target("C6")
	await _wait(2.2)
	map._close_battle()
	await _wait(1.1)
	map._on_end_turn()
	await _wait(1.6)
	print("UI_MOVIE_OK")
	get_tree().quit(0)


func _open_map() -> Node:
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
	for _i in 40:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == "res://scenes/big_map.tscn" and scene.has_method("present_battle"):
			return scene
	push_error("大地图没有起来")
	get_tree().quit(1)
	return null


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOTS, file_name]
	var err := image.save_png(path)
	print("UI_SHOT %s %s" % [path, err])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clear_guide() -> void:
	var path := ProjectSettings.globalize_path("user://v03_guide.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _fake_lose() -> Dictionary:
	return {
		"ok": true,
		"outcome": "lose",
		"sent": 14,
		"defender": 26,
		"atk_x100": 1400,
		"def_x100": 2860,
		"yuan_bonus": false,
		"held": false,
		"terrain_pct": 110,
		"src_name": "锦州",
		"dst_name": "沈阳",
		"src_show": 14,
		"dst_show": 26,
		"src_kind": "contested",
		"dst_kind": "jin",
		"message": "",
	}


func _fake_draw() -> Dictionary:
	return {
		"ok": true,
		"outcome": "draw",
		"sent": 11,
		"defender": 10,
		"atk_x100": 1100,
		"def_x100": 1000,
		"yuan_bonus": false,
		"held": false,
		"terrain_pct": 100,
		"src_name": "宁远",
		"dst_name": "锦州",
		"src_show": 11,
		"dst_show": 10,
		"src_kind": "ming",
		"dst_kind": "contested",
		"message": "",
	}


func _reach_bing() -> void:
	Campaign.reset()
	Campaign.guide_skip()
	Campaign.hold("C4")
	Campaign.end_turn()
	if Campaign.pending_story == "s1":
		Campaign.apply_s1("A")
	var guard := 0
	while not Campaign.settled and guard < 16:
		guard += 1
		if Campaign.pending_story == "s1":
			Campaign.apply_s1("A")
			continue
		if Campaign.pending_story == "s2":
			Campaign.apply_s2("A")
			continue
		if Campaign.pending_story == "s3":
			Campaign.apply_s3("B")
			continue
		var host := "C4" if str(Campaign.city("C4")["faction"]) == "明" else ""
		if host == "":
			for id in ["C1", "C2", "C3", "C6", "C5"]:
				if str(Campaign.city(id)["faction"]) == "明":
					host = id
					break
		if host == "":
			break
		Campaign.hold(host)
		Campaign.end_turn()
