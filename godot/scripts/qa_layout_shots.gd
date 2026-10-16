extends SceneTree
## 三尺寸版式出图。不进游玩路径。
## godot --path godot -s res://scripts/qa_layout_shots.gd

const AdvisorScript := preload("res://scripts/advisor.gd")

var _dir := "/opt/cursor/artifacts/layout"
var _size := Vector2i(1280, 720)
var _campaign


func _initialize() -> void:
	_campaign = root.get_node("Campaign")
	_run()


func _run() -> void:
	_write_guide()
	for pair in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(1920, 1080)]:
		_size = pair
		_apply_size()
		await process_frame
		await process_frame
		await _map_shots()
		await _ending_shot()
	print("LAYOUT_SHOTS_OK")
	quit(0)


func _map_shots() -> void:
	AdvisorScript.set_self_pick(false)
	_campaign.reset()
	_campaign.guide_done = true
	_campaign.guide_step = 3
	var map := await _open("res://scenes/big_map.tscn")
	if map == null:
		return
	await _warn(map, 22, 8, 50)
	await _shot("warn-yellow")
	_print_warn(map, "yellow")
	await _warn(map, 10, 0, 30)
	await _shot("warn-red")
	_print_warn(map, "red")
	_campaign.reset()
	_campaign.guide_done = true
	_campaign.turn = 6
	_layout_map(map)
	map._refresh()
	await _shot("hint-turn6")
	_print_hint(map, 6)
	_campaign.turn = 7
	_layout_map(map)
	map._refresh()
	await _shot("hint-turn7")
	_print_hint(map, 7)
	_campaign.turn = 10
	_layout_map(map)
	map._refresh()
	await _shot("turn10-top")
	print("LAYOUT_TURN10 shown=%s stored=%d rect=%s" % [map._chips["turn"].text, _campaign.turn, map._chips["turn"].get_global_rect()])


func _ending_shot() -> void:
	_campaign.reset()
	_campaign.guide_done = true
	_campaign.turn = 10
	_campaign.s1_done = true
	_campaign.s2_done = true
	_campaign.s3_done = true
	_campaign.liaodong = 32
	_campaign.pressure = 41
	_campaign.worldline = 20
	_campaign.morale = 7
	_campaign.silver = 40
	_campaign.yuan_status = "前线可用"
	_campaign.city("C1")["faction"] = "明"
	_campaign.ending_id = _campaign.resolve_ending()
	_campaign.outlook_before_finale = "乙"
	_campaign.settled = true
	var page := await _open("res://scenes/ending.tscn")
	if page == null:
		return
	await _shot("ending-ding")
	_print_ending(page)


func _warn(map: Node, morale: int, silver: int, liao: int) -> void:
	_campaign.morale = morale
	_campaign.silver = silver
	_campaign.liaodong = liao
	_campaign.turn = 3
	_layout_map(map)
	map._refresh()
	await process_frame


func _print_warn(map: Node, tag: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	print("LAYOUT_CHROME %s chip_row=%s forecast=%s top=%s" % [_size, map._chip_row.get_global_rect(), map._forecast_bar.get_global_rect(), map._top.get_global_rect()])
	for plate in map._chip_meta:
		var meta: Dictionary = map._chip_meta[plate]
		var warn: Control = meta["tag"]
		if not (plate as CanvasItem).is_visible_in_tree() or not warn.visible:
			continue
		var value: Label = meta["value"]
		var slot := str((plate as Node).get_meta("slot", ""))
		var ink := _ink_box(image, value.get_global_rect().grow(2.0), value.get_theme_color("font_color"))
		var tag_rect := warn.get_global_rect()
		var hit := tag_rect.intersects(ink)
		print("LAYOUT_WARN %s %s slot=%s tag=%s value=%s ink=%s hit=%s text=%s" % [tag, _size, slot, tag_rect, value.get_global_rect(), ink, hit, value.text])


func _print_hint(map: Node, turn: int) -> void:
	var banner: Control = map._turn_banner
	var row: Control = map._hint_row
	print("LAYOUT_HINT turn=%d banner=%s vis=%s hint_row=%s text=%s" % [turn, banner.get_global_rect(), banner.visible, row.get_global_rect(), map._hint.text])


func _print_ending(page: Node) -> void:
	var paper: Control = page._paper
	print("LAYOUT_PAPER %s paper=%s viewport=%s" % [_size, paper.get_global_rect(), root.get_viewport().get_visible_rect().size])
	for node_name in ["EndingTitle", "AvoidBar", "AvoidLine", "GapTitle", "GapLine0", "GapLine1", "WorldlineRow"]:
		var node := _find(page, node_name)
		if node is CanvasItem and (node as CanvasItem).visible:
			print("LAYOUT_END %s %s rect=%s text=%s" % [_size, node_name, (node as Control).get_global_rect(), _text_of(node)])
	for tile in page._tiles:
		print("LAYOUT_TILE %s %s rect=%s" % [_size, (tile as Node).name, (tile as Control).get_global_rect()])
	var shown := ""
	for row in page._rows:
		shown += str((row["text"] as Label).text) + " | "
	print("LAYOUT_ROWS %s %s" % [_size, shown])
	var avoid: Label = page._avoid_label
	var gap0: Label = page._gap_labels[0]
	var gap1: Label = page._gap_labels[1]
	var image := root.get_viewport().get_texture().get_image()
	print("LAYOUT_TYPE avoid_size=%s avoid_color=%s avoid_rect=%s metrics=%s" % [avoid.get_theme_font_size("font_size"), avoid.get_theme_color("font_color"), avoid.get_global_rect(), _font_metrics(avoid)])
	print("LAYOUT_TYPE bar_color=%s bar_rect=%s design_y=%s" % [page._avoid_bar.color, page._avoid_bar.get_global_rect(), _design_span(paper, page._avoid_bar.get_global_rect())])
	print("LAYOUT_TYPE gap_title_size=%s gap_title_color=%s rect=%s design_y=%s" % [page._gap_title.get_theme_font_size("font_size"), page._gap_title.get_theme_color("font_color"), page._gap_title.get_global_rect(), _design_span(paper, page._gap_title.get_global_rect())])
	var clip0: Control = page._gap_clips[0]
	var clip1: Control = page._gap_clips[1]
	var ink0 := _ink_red(image, clip0.get_global_rect())
	var ink1 := _ink_red(image, clip1.get_global_rect())
	var ink_avoid := _ink_cream(image, page._avoid_bar.get_global_rect())
	print("LAYOUT_TYPE gap0_size=%s color=%s clip=%s design_y=%s ink=%s ink_design=%s text=%s" % [gap0.get_theme_font_size("font_size"), gap0.get_theme_color("font_color"), clip0.get_global_rect(), _design_span(paper, clip0.get_global_rect()), ink0, _design_span(paper, ink0), gap0.text])
	print("LAYOUT_TYPE gap1_size=%s color=%s clip=%s design_y=%s ink=%s ink_design=%s text=%s head=%s" % [gap1.get_theme_font_size("font_size"), gap1.get_theme_color("font_color"), clip1.get_global_rect(), _design_span(paper, clip1.get_global_rect()), ink1, _design_span(paper, ink1), gap1.text, gap1.text.substr(0, 2)])
	print("LAYOUT_TYPE avoid_ink=%s avoid_ink_design=%s" % [ink_avoid, _design_span(paper, ink_avoid)])
	print("LAYOUT_GAPS %s | %s || avoid=%s turn_stored=%d" % [gap0.text, gap1.text, avoid.text, _campaign.turn])


func _font_metrics(label: Label) -> String:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if font == null:
		return "none"
	return "h=%.2f ascent=%.2f descent=%.2f" % [font.get_height(size), font.get_ascent(size), font.get_descent(size)]


func _design_span(paper: Control, rect: Rect2) -> String:
	if rect.size == Vector2.ZERO:
		return "empty"
	var s := paper.size.y / 368.0
	var top := 118.0 + (rect.position.y - paper.get_global_rect().position.y) / s
	var bottom := 118.0 + (rect.end.y - paper.get_global_rect().position.y) / s
	var left := rect.position.x
	return "x=%.2f y=%.2f..%.2f" % [left, top, bottom]


func _find(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _text_of(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	return ""


func _ink_box(image: Image, rect: Rect2, color: Color) -> Rect2:
	var x0 := clampi(int(floor(rect.position.x)), 0, image.get_width() - 1)
	var y0 := clampi(int(floor(rect.position.y)), 0, image.get_height() - 1)
	var x1 := clampi(int(ceil(rect.end.x)), 0, image.get_width())
	var y1 := clampi(int(ceil(rect.end.y)), 0, image.get_height())
	var min_x := x1
	var min_y := y1
	var max_x := x0
	var max_y := y0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			if _near(image.get_pixel(x, y), color):
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
			x += 1
		y += 1
	if max_x <= min_x or max_y <= min_y:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.42


func _ink_span(image: Image, rect: Rect2, match: Callable) -> Rect2:
	var x0 := clampi(int(floor(rect.position.x)), 0, image.get_width() - 1)
	var y0 := clampi(int(floor(rect.position.y)), 0, image.get_height() - 1)
	var x1 := clampi(int(ceil(rect.end.x)), 0, image.get_width())
	var y1 := clampi(int(ceil(rect.end.y)), 0, image.get_height())
	var min_x := x1
	var min_y := y1
	var max_x := x0
	var max_y := y0
	var y := y0
	while y < y1:
		var x := x0
		while x < x1:
			if match.call(image.get_pixel(x, y)):
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
			x += 1
		y += 1
	if max_x <= min_x or max_y <= min_y:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func _ink_red(image: Image, rect: Rect2) -> Rect2:
	return _ink_span(image, rect, func(pixel: Color) -> bool:
		return pixel.r > 0.45 and pixel.r > pixel.g + 0.16 and pixel.r > pixel.b + 0.18 and pixel.g < 0.63
	)


func _ink_cream(image: Image, rect: Rect2) -> Rect2:
	return _ink_span(image, rect, func(pixel: Color) -> bool:
		return pixel.r > 0.9 and pixel.g > 0.8 and pixel.b > 0.7 and pixel.r + 0.02 >= pixel.g and pixel.g + 0.02 >= pixel.b
	)


func _open(path: String) -> Node:
	change_scene_to_file(path)
	for _i in 40:
		await process_frame
		var scene := current_scene
		if scene != null and scene.scene_file_path == path:
			_apply_size()
			await process_frame
			await process_frame
			if scene.has_method("_layout"):
				scene._layout()
			if scene.has_method("_layout_chrome"):
				scene._layout_chrome()
			await process_frame
			return scene
	push_error("场景没有起来 %s" % path)
	quit(1)
	return null


func _layout_map(map: Node) -> void:
	_apply_size()
	if map.has_method("_layout_chrome"):
		map._layout_chrome()


func _shot(file_name: String) -> void:
	var fade := root.get_node_or_null("Fade")
	if fade != null and "_rect" in fade:
		var guard := 0
		while fade._rect.color.a > 0.02 and guard < 120:
			await process_frame
			guard += 1
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_dir)
	var path := "%s/%dx%d-%s.png" % [_dir, _size.x, _size.y, file_name]
	var err := image.save_png(path)
	print("LAYOUT_SHOT %s err=%s image=%dx%d window=%s" % [path, err, image.get_width(), image.get_height(), root.size])


func _apply_size() -> void:
	var window := root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = 1.0
	window.min_size = Vector2i(640, 480)
	window.size = _size
	DisplayServer.window_set_min_size(Vector2i(640, 480))
	DisplayServer.window_set_size(_size)


func _write_guide() -> void:
	var file := FileAccess.open("user://v03_guide.json", FileAccess.WRITE)
	if file != null:
		file.store_string("{\"dismissed\":true}")
