extends SceneTree
## Temporary S1 frame probe. Does not change materials. Export-excluded.


func _initialize() -> void:
	_run()


func _run() -> void:
	var window := root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	window.min_size = Vector2i(640, 480)
	window.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	change_scene_to_file("res://scenes/s1_night.tscn")
	for _i in 25:
		await process_frame
	var scene := current_scene
	var camera := scene.get_node("Camera3D") as Camera3D
	var samples: Array[float] = []
	var elapsed := 0.0
	var last_z := camera.position.z
	var jumped := false
	var reversed := false
	var worst := 1000.0
	var worst_at := 0.0
	while elapsed < 60.0:
		await process_frame
		var dt := window.get_process_delta_time()
		if dt <= 0.0:
			continue
		elapsed += dt
		var fps := 1.0 / dt
		samples.append(fps)
		if fps < worst:
			worst = fps
			worst_at = elapsed
		var z := camera.position.z
		if z - last_z > 0.02:
			reversed = true
		if absf(z - last_z) > 0.35:
			jumped = true
		last_z = z
	var sum := 0.0
	for value in samples:
		sum += value
	var average := sum / float(samples.size())
	var renderer := RenderingServer.get_current_rendering_method()
	print("S1_FPS frames=%d avg=%.2f min=%.2f min_at=%.2f jumped=%s reversed=%s z_end=%.3f renderer=%s" % [samples.size(), average, worst, worst_at, jumped, reversed, camera.position.z, renderer])
	quit(0)
