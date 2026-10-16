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
	DisplayServer.window_set_size(size)
	change_scene_to_file("res://scenes/s1_night.tscn")
	await _wait_clear()
	_save("start")
	var scene := current_scene
	if scene.has_method("snap_pose"):
		scene.snap_pose("end_hall")
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("end-hall")
	if scene.has_method("snap_pose"):
		scene.snap_pose("end")
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("end")
	var camera := scene.get_node("Camera3D") as Camera3D
	print("S1_SHOT_OK size=%s viewport=%s cam=%s fov=%.2f rot=%s keep=%s lights=%d" % [size, root.get_viewport().get_visible_rect().size, camera.position, camera.fov, camera.rotation_degrees, camera.keep_aspect, _count_lights(scene)])
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


func _count_lights(scene: Node) -> int:
	var n := 0
	for node in scene.find_children("*", "Light3D", true, false):
		if node is Light3D and (node as Light3D).visible:
			n += 1
	return n


func _save(tag: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "/opt/cursor/artifacts/s1/%s-%dx%d.png" % [tag, image.get_width(), image.get_height()]
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/s1")
	image.save_png(path)
	print("S1_SAVED", path, image.get_width(), image.get_height())
