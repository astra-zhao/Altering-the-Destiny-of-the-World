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
	var particles := 0
	var particle_amount := 0
	for node in scene.find_children("*", "GPUParticles3D", true, false):
		particles += 1
		particle_amount += (node as GPUParticles3D).amount
	for node in scene.find_children("*", "CPUParticles3D", true, false):
		particles += 1
		particle_amount += (node as CPUParticles3D).amount
	print("S1_SCENE lights=%d particles=%d amount=%d" % [int(scene.call("_count_lights")), particles, particle_amount])
	var shots: Array = [
		["t0", 0.0, false],
		["mid", 6.0, false],
		["end", 12.0, false],
		["end-hall", 12.0, true],
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
	var clear_frames := 0
	for _i in 90:
		await process_frame
		var scene := current_scene
		if scene == null or not scene.has_method("debug_seek"):
			continue
		if int(scene.get("_warm_left")) > 0:
			clear_frames = 0
			continue
		var fade := root.get_node_or_null("Fade")
		if fade == null:
			continue
		var rect: ColorRect = fade.get("_rect")
		if rect != null and rect.color.a < 0.02:
			clear_frames += 1
			if clear_frames >= 3:
				await RenderingServer.frame_post_draw
				print("S1_FADE_CLEAR a=%.3f" % rect.color.a)
				return
		else:
			clear_frames = 0
	await RenderingServer.frame_post_draw


func _save(tag: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "/opt/cursor/artifacts/s1/%s-%dx%d.png" % [tag, image.get_width(), image.get_height()]
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/s1")
	image.save_png(path)
	print("S1_SAVED", path, image.get_width(), image.get_height())
	if tag == "t0" or tag == "end":
		var crop_w := mini(560, image.get_width())
		var crop_h := mini(240, image.get_height())
		var crop := image.get_region(Rect2i(0, 0, crop_w, crop_h))
		var crop_path := "/opt/cursor/artifacts/s1/lantern-%s-%dx%d.png" % [tag, image.get_width(), image.get_height()]
		crop.save_png(crop_path)
		print("S1_SAVED", crop_path, crop.get_width(), crop.get_height())
