extends SceneTree
## Temporary S1 frame grab. Export-excluded. English only.


func _initialize() -> void:
	_run()


func _run() -> void:
	var size := Vector2i(1280, 720)
	if OS.get_environment("S1_W") != "":
		size = Vector2i(int(OS.get_environment("S1_W")), int(OS.get_environment("S1_H")))
	OS.set_environment("S1_SNAP", "start")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.min_size = Vector2i(640, 480)
	root.size = size
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(size)
	change_scene_to_file("res://scenes/s1_night.tscn")
	await _wait_clear()
	var scene := current_scene
	var shots: Array = [
		["t0", 0.0, false],
		["early", 1.6, false],
		["hint", 4.0, false],
		["mid", 6.0, false],
		["late", 10.5, false],
		["t12", 12.0, false],
		["end", 12.0, true],
	]
	for spec in shots:
		var tag := str(spec[0])
		scene.debug_seek(float(spec[1]), bool(spec[2]))
		for _i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		_save(tag)
		var title: Rect2 = scene.push_title_rect()
		print("S1_TITLE_RECT %s %.1f %.1f %.1f %.1f" % [tag, title.position.x, title.position.y, title.size.x, title.size.y])
		var hint := scene.get_node_or_null("UI/SkipHint") as CanvasItem
		if hint != null:
			var hint_rect := (hint as Control).get_global_rect()
			print("S1_HINT %s vis=%s a=%.2f %.1f %.1f %.1f %.1f" % [tag, hint.visible, hint.modulate.a, hint_rect.position.x, hint_rect.position.y, hint_rect.size.x, hint_rect.size.y])
	var camera := scene.get_node("Camera3D") as Camera3D
	print("S1_SHOT_OK size=%s viewport=%s cam=%s fov=%.2f rot=%s" % [size, root.get_viewport().get_visible_rect().size, camera.position, camera.fov, camera.rotation_degrees])
	quit(0)


func _wait_clear() -> void:
	for _i in 50:
		await process_frame
		var fade := root.get_node_or_null("Fade")
		if fade == null:
			continue
		var rect: ColorRect = fade.get("_rect")
		if rect != null and rect.color.a < 0.02:
			await process_frame
			await RenderingServer.frame_post_draw
			return
	await RenderingServer.frame_post_draw


func _save(tag: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "/opt/cursor/artifacts/s1/%s-%dx%d.png" % [tag, image.get_width(), image.get_height()]
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/s1")
	image.save_png(path)
	print("S1_SAVED", path, image.get_width(), image.get_height())
