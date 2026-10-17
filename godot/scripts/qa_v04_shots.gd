extends SceneTree
## v0.4 开局截图。1280×720。不进游玩路径。
## godot --path godot -s res://scripts/qa_v04_shots.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	_prepare_window()
	_clear_user_files()
	for _i in 2:
		await process_frame
	change_scene_to_file("res://scenes/title_screen.tscn")
	var title := await _wait_scene("TitleScreen")
	if title == null:
		quit(1)
		return
	await _settle()
	_lift_fade()
	await _shot("title")
	title.open_clear_confirm()
	await _settle()
	_lift_fade()
	await _shot("confirm-clear")
	title.decline_confirm()
	title.open_reset_confirm()
	await _settle()
	await _shot("confirm-reset")
	title.decline_confirm()
	_write_text("user://campaign_m2.json", "{\"version\":3}")
	title._sync_continue()
	var enabled := title.find_child("ContinueButton", true, false) as Button
	if enabled.disabled:
		print("V04_SHOT_FAIL continue stayed disabled with a save")
		quit(1)
		return
	title.open_clear_confirm()
	title.accept_confirm()
	await _settle()
	_lift_fade()
	var disabled := title.find_child("ContinueButton", true, false) as Button
	print("V04_CONTINUE_AFTER_CLEAR disabled=%s" % disabled.disabled)
	if not disabled.disabled:
		print("V04_SHOT_FAIL continue still enabled after clear")
		quit(1)
		return
	await _shot("title-continue-disabled")
	title._on_start()
	var prologue := await _wait_scene("Prologue")
	if prologue == null:
		quit(1)
		return
	await _settle()
	_lift_fade()
	prologue.present(0)
	await _shot("prologue-1")
	prologue.present(1)
	await _shot("prologue-2")
	prologue.present(2)
	await _shot("prologue-3")
	prologue.advance_for_test()
	var s1 := await _wait_scene("S1Night")
	if s1 == null:
		quit(1)
		return
	for _i in 8:
		await process_frame
	s1.debug_seek(0.2, false)
	_lift_fade()
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	await _shot("s1-start")
	s1._choose("B")
	var map := await _wait_scene("BigMap")
	if map == null:
		quit(1)
		return
	for _i in 8:
		await process_frame
	if map.has_method("_layout_chrome"):
		map._layout_chrome()
	_lift_fade()
	await RenderingServer.frame_post_draw
	var guide: CanvasItem = map.get("_guide")
	var campaign := root.get_node("Campaign")
	print("V04_MAP turn=%d s1=%s guide=%s" % [int(campaign.turn), str(campaign.s1_done), guide != null and guide.visible])
	await _shot("map-after-s1")
	_write_manifest()
	print("V04_SHOTS_OK")
	quit(0)


func _prepare_window() -> void:
	var size := Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.min_size = Vector2i(640, 480)
	root.size = size
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(size)


func _settle() -> void:
	for _i in 6:
		await process_frame
	await RenderingServer.frame_post_draw


func _lift_fade() -> void:
	var fade := root.get_node_or_null("Fade")
	if fade == null:
		return
	var rect := fade.get("_rect") as ColorRect
	if rect != null:
		rect.color.a = 0.0


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/v04")
	var path := "/opt/cursor/artifacts/v04/%s.png" % tag
	var err := image.save_png(path)
	print("V04_SAVED %s %d %d err=%d" % [path, image.get_width(), image.get_height(), err])


func _wait_scene(node_name: String) -> Node:
	for _i in 240:
		await process_frame
		var scene := current_scene
		if scene != null and scene.name == node_name:
			return scene
	print("V04_SHOT_FAIL missing %s now %s" % [node_name, str(current_scene)])
	return null


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


func _clear_user_files() -> void:
	for path in ["user://campaign_m2.json", "user://v03_guide.json", "user://audio_prefs.json", "user://advisor_prefs.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_manifest() -> void:
	var lines := PackedStringArray()
	lines.append("{")
	lines.append("  \"viewport\": \"1280x720\",")
	lines.append("  \"shots\": [")
	var names := [
		"title",
		"confirm-clear",
		"confirm-reset",
		"title-continue-disabled",
		"prologue-1",
		"prologue-2",
		"prologue-3",
		"s1-start",
		"map-after-s1",
	]
	for i in names.size():
		var comma := "," if i < names.size() - 1 else ""
		lines.append("    \"%s.png\"%s" % [names[i], comma])
	lines.append("  ]")
	lines.append("}")
	var path := "/opt/cursor/artifacts/v04/manifest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		print("V04_MANIFEST %s" % path)
