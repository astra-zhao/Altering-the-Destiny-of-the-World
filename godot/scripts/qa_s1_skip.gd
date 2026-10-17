extends SceneTree
## Skip, spam-click, unskipped timing, and enter/exit leak probe. English only.


func _initialize() -> void:
	_run()


func _run() -> void:
	if not await _warm_skip():
		quit(1)
		return
	await _spam()
	await _unskipped()
	await _leak()
	print("S1_SKIP_PROBE_OK")
	quit(0)


func _warm_skip() -> bool:
	for kind in ["space", "click"]:
		OS.set_environment("S1_SNAP", "")
		_prepare_window(Vector2i(1280, 720))
		change_scene_to_file("res://scenes/s1_night.tscn")
		var scene: Node = null
		var warm_left := 0
		for _i in 8:
			await process_frame
			scene = current_scene
			if scene == null:
				continue
			warm_left = int(scene.get("_warm_left"))
			if warm_left > 0:
				break
		if scene == null:
			print("S1_WARM_SKIP_FAIL kind=%s reason=no_scene" % kind)
			return false
		var done_during := bool(scene.get("_push_done"))
		if kind == "space":
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.physical_keycode = KEY_SPACE
			key.pressed = true
			key.echo = false
			scene._unhandled_input(key)
		else:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = true
			mouse.position = Vector2(640, 360)
			scene._unhandled_input(mouse)
		var queued := bool(scene.get("_skip_queued"))
		var skipping_now := bool(scene.get("_skipping"))
		print("S1_WARM_SKIP_ARM kind=%s warm_left=%d queued=%s skipping=%s done=%s" % [kind, warm_left, queued, skipping_now, done_during])
		if warm_left <= 0 or not queued or skipping_now or done_during:
			print("S1_WARM_SKIP_FAIL kind=%s reason=not_queued_during_warmup" % kind)
			return false
		var guard := 0
		while not bool(scene.get("_push_done")) and guard < 180:
			await process_frame
			guard += 1
		var camera := scene.get_node("Camera3D") as Camera3D
		var dist: float = camera.position.distance_to(Vector3(0, 1.5, 0))
		var counts := _count(scene)
		var buttons := 0
		var board := scene.get_node_or_null("UI/StoryBoard")
		if board != null:
			for node in board.find_children("*", "BaseButton", true, false):
				buttons += 1
		print("S1_WARM_SKIP_AFTER kind=%s done=%s frames=%d cam=%s dist=%.4f boards=%d cards=%d buttons=%d" % [kind, scene.get("_push_done"), guard, camera.position, dist, counts.x, counts.y, buttons])
		if not bool(scene.get("_push_done")) or dist > 0.05 or counts.x != 1 or counts.y != 3 or buttons != 3:
			print("S1_WARM_SKIP_FAIL kind=%s" % kind)
			return false
	print("S1_WARM_SKIP_OK")
	return true


func _spam() -> void:
	OS.set_environment("S1_SNAP", "start")
	_prepare_window(Vector2i(1280, 720))
	change_scene_to_file("res://scenes/s1_night.tscn")
	for _i in 3:
		await process_frame
	var scene := current_scene
	var before := _count(scene)
	print("S1_SPAM_BEFORE boards=%d cards=%d" % [before.x, before.y])
	_burst(scene)
	var guard := 0
	while not bool(scene.get("_push_done")) and guard < 180:
		_burst(scene)
		await process_frame
		guard += 1
	_burst(scene)
	for _i in 6:
		await process_frame
	var after := _count(scene)
	var camera := scene.get_node("Camera3D") as Camera3D
	var held: Vector3 = camera.position
	for _i in 8:
		await process_frame
	var drift: float = camera.position.distance_to(held)
	var board := scene.get_node_or_null("UI/StoryBoard") as CanvasItem
	var interactive := 0
	if board != null:
		for node in board.find_children("*", "BaseButton", true, false):
			var button := node as BaseButton
			if button.visible and not button.disabled and button.mouse_filter == Control.MOUSE_FILTER_STOP:
				interactive += 1
	print("S1_SPAM_AFTER boards=%d cards=%d interactive=%d drift=%.5f frames=%d cam=%s board_vis=%s" % [after.x, after.y, interactive, drift, guard, camera.position, board != null and board.visible])


func _unskipped() -> void:
	OS.set_environment("S1_SNAP", "")
	_prepare_window(Vector2i(1280, 720))
	change_scene_to_file("res://scenes/s1_night.tscn")
	for _i in 2:
		await process_frame
	var scene := current_scene
	var worst := 0.0
	var worst_clock := 0.0
	var samples := 0
	var over_25 := 0
	var file := FileAccess.open("/tmp/s1_frames.txt", FileAccess.WRITE)
	var last := Time.get_ticks_usec()
	var guard := 0
	while not bool(scene.get("_push_done")) and guard < 900:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		var clock := float(scene.get("_clock"))
		if file != null:
			file.store_line("%.3f %.2f" % [clock, dt])
		if dt > worst:
			worst = dt
			worst_clock = clock
		if dt >= 25.0:
			over_25 += 1
		samples += 1
		guard += 1
	if file != null:
		file.close()
	var after := _count(scene)
	print("S1_UNSKIPPED done=%s frames=%d worst_ms=%.2f worst_t=%.2f over25=%d boards=%d cards=%d" % [scene.get("_push_done"), samples, worst, worst_clock, over_25, after.x, after.y])


func _leak() -> void:
	OS.set_environment("S1_SNAP", "start")
	var packed := load("res://scenes/s1_night.tscn") as PackedScene
	var before_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var before_objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var before_orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for _i in 10:
		var node := packed.instantiate()
		root.add_child(node)
		await process_frame
		await process_frame
		node.queue_free()
		await process_frame
		await process_frame
	await process_frame
	var after_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var after_objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var after_orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	print("S1_LEAK nodes %d -> %d objects %d -> %d orphans %d -> %d" % [before_nodes, after_nodes, before_objects, after_objects, before_orphans, after_orphans])


func _burst(scene: Node) -> void:
	if scene.has_method("_skip_push"):
		scene.call("_skip_push")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(640, 360)
	scene._unhandled_input(mouse)
	for keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = true
		key.echo = false
		scene._unhandled_input(key)
		Input.parse_input_event(key)


func _count(scene: Node) -> Vector2i:
	var boards := 0
	var cards := 0
	for node in scene.find_children("*", "", true, false):
		var node_name := str(node.name)
		if node_name == "StoryBoard":
			boards += 1
		elif node_name.begins_with("StoryCard_"):
			cards += 1
	return Vector2i(boards, cards)


func _prepare_window(size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.min_size = Vector2i(640, 480)
	root.size = size
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(size)
