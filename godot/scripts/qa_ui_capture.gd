extends Node
## 对照界面出图。不进正式游玩路径，导出预设会排除本脚本。
## godot --path . res://scenes/qa_ui_capture.tscn -- --clear-guide --shots-dir=/tmp/ui-shots
## 可选：--size=1280x720  --prefix=  --set=full|layout  --movie

const AdvisorScript := preload("res://scripts/advisor.gd")

var _movie := false
var _clear_guide_flag := false
var _shots_dir := ""
var _prefix := ""
var _set := "full"
var _size := Vector2i(1280, 720)
var _missing := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--movie":
			_movie = true
		elif arg == "--clear-guide":
			_clear_guide_flag = true
		elif arg.begins_with("--shots-dir="):
			_shots_dir = arg.trim_prefix("--shots-dir=")
		elif arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--set="):
			_set = arg.trim_prefix("--set=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				_size = Vector2i(int(parts[0]), int(parts[1]))
	if _shots_dir == "":
		_shots_dir = ProjectSettings.globalize_path("user://ui_shots")
	call_deferred("_reparent_and_run")


func _reparent_and_run() -> void:
	var tree := get_tree()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	_apply_size()
	if _clear_guide_flag:
		_clear_guide()
	Campaign.reset()
	if _movie:
		_play_turn()
	else:
		_shots()


func _apply_size() -> void:
	var window := get_window()
	# 关掉拉伸，根控件就是窗口像素。1024×600 才能按这个尺寸排，而不是仍按 1280 缩放。
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.min_size = Vector2i(mini(_size.x, 640), mini(_size.y, 400))
	window.size = _size
	DisplayServer.window_set_size(_size)


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var map := await _open_map()
	await _wait(0.45)
	_note_glyphs()
	_dump_layout("ui01-before", map)
	await _shot("13-ui01-before")
	await _shot("09-next-turn-disabled")
	await _shot("03-civil-disabled")
	_dump_card(map)
	if _set == "layout":
		map._on_city_pressed("C4")
		await _wait(0.35)
		map._on_help()
		await _wait(0.2)
		_dump_layout("step2", map)
		_note_glyphs()
		await _shot("15-step2-no-overlap")
		await _shot("01-map-guide-seals")
		print("UI_CAPTURE_OK")
		get_tree().quit(0)
		return
	_pick_hold(map)
	await _wait(0.35)
	_dump_layout("ui01-after", map)
	_note_glyphs()
	await _shot("14-ui01-after")
	Campaign.reset()
	map = await _open_map()
	await _wait(0.35)
	map._on_city_pressed("C4")
	await _wait(0.35)
	map._on_help()
	await _wait(0.2)
	_dump_layout("step2", map)
	_note_glyphs()
	await _shot("15-step2-no-overlap")
	await _shot("01-map-guide-seals")
	map._advisor_panel.hide()
	map._layout_chrome()
	map._on_march_mode()
	await _wait(0.1)
	await _shot("11-action-selected")
	map._pick = ""
	map._refresh_popup()
	map._on_seal_hover("btn_action_hold", true)
	await _wait(0.05)
	await _shot("12-action-hover")
	map._on_seal_hover("btn_action_hold", false)
	map._guide.visible = true
	var preview: Dictionary = Campaign.preview_battle("C4", "C6")
	map.present_battle("C4", "C6", preview, false, 0.42)
	await _wait(0.25)
	_note_glyphs()
	_dump_battle(map)
	await _shot("04-battle-run")
	map.present_battle("C4", "C6", preview, true, 1.0)
	await _wait(0.2)
	_note_glyphs()
	await _shot("05-battle-win")
	map.present_battle("C6", "C5", _fake_lose(), true, 1.0)
	await _wait(0.15)
	await _shot("06-battle-lose")
	map.present_battle("C4", "C6", _fake_draw(), true, 1.0)
	await _wait(0.15)
	await _shot("07-battle-draw")
	map._close_battle()
	map._advisor_panel.hide()
	map._on_city_pressed("C4")
	map._on_hold()
	map._clear_selection()
	map._guide.visible = false
	await _wait(0.25)
	_note_glyphs()
	await _shot("10-next-turn-normal")
	_reach_bing()
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
	await _wait(0.55)
	_note_glyphs()
	await _shot("08-ending")
	_measure_contrast()
	_print_missing()
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


func _pick_hold(map: Node) -> void:
	var recs: Array = AdvisorScript.recommend(Campaign)
	for action in recs:
		if str(action.get("kind", "")) == "hold":
			print("UI01_PICK %s" % str(action.get("title", "")))
			map._on_advisor_pick(action)
			return
	push_error("没有固守推荐")


func _open_map() -> Node:
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
	for _i in 40:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == "res://scenes/big_map.tscn" and scene.has_method("present_battle"):
			_apply_size()
			await get_tree().process_frame
			await get_tree().process_frame
			if scene.has_method("_layout_chrome"):
				scene._layout_chrome()
			return scene
	push_error("大地图没有起来")
	get_tree().quit(1)
	return null


func _dump_layout(tag: String, map: Node) -> void:
	var adv: Control = map._advisor_panel
	var guide: Control = map._guide_panel
	var adv_rect := adv.get_global_rect()
	var guide_rect := guide.get_global_rect()
	var skip := _find_skip(guide)
	var skip_inside := true
	if skip != null:
		var skip_rect := skip.get_global_rect()
		skip_inside = guide_rect.encloses(skip_rect.grow(-1.0))
		print("SKIP %s rect=%s inside=%s" % [tag, skip_rect, skip_inside])
	var hit_adv := guide.visible and guide_rect.intersects(adv_rect)
	print(
		"LAYOUT %s map=%s step=%d bubble=%s adv=%s guide=%s guide_adv=%s"
		% [tag, map.size, int(Campaign.guide_step), str(map._guide_num.text), adv_rect, guide_rect, hit_adv]
	)
	if map._actions != null and map._actions.visible:
		var action_rect: Rect2 = map._actions.get_global_rect()
		print("ACTIONS %s rect=%s hit_guide=%s" % [tag, action_rect, guide.visible and guide_rect.intersects(action_rect)])
	for city_id in map._markers:
		var token: Control = map._markers[city_id]
		var token_rect := token.get_global_rect()
		if adv.visible and token_rect.intersects(adv_rect):
			print("OVERLAP_ADVISOR %s %s %s" % [tag, city_id, token_rect])
		if guide.visible and token_rect.intersects(guide_rect):
			print("OVERLAP_GUIDE %s %s %s" % [tag, city_id, token_rect])


func _dump_card(map: Node) -> void:
	var reason: Label = map._cards["train"]["reason"]
	var end_reason: Control = map._end_reason
	var overlap := reason.get_global_rect().intersects(end_reason.get_global_rect())
	print("TRAIN_REASON text=%s rect=%s end=%s overlap=%s" % [reason.text, reason.get_global_rect(), end_reason.get_global_rect(), overlap])


func _dump_battle(map: Node) -> void:
	if map._atk_badge == null:
		return
	var atk: Vector2 = map._atk_badge.get_global_rect().size
	var def: Vector2 = map._def_badge.get_global_rect().size
	print("BADGE atk=%s def=%s visible_disc=%.1f" % [atk, def, atk.x * 84.0 / 104.0])


func _find_skip(node: Node) -> Button:
	if node is Button and str((node as Button).text) == "跳过引导":
		return node as Button
	for child in node.get_children():
		var found := _find_skip(child)
		if found != null:
			return found
	return null


func _note_glyphs() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_walk_glyphs(scene)


func _walk_glyphs(node: Node) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Label:
		var label := node as Label
		var font: Font = label.get_theme_font("font")
		var text := label.text
		var i := 0
		while i < text.length():
			var code := text.unicode_at(i)
			i += 1
			if code <= 32:
				continue
			if font == null or not font.has_char(code):
				_missing[char(code)] = true
	for child in node.get_children():
		_walk_glyphs(child)


func _print_missing() -> void:
	var chars: Array = _missing.keys()
	chars.sort()
	if chars.is_empty():
		print("MISSING_GLYPHS none")
	else:
		print("MISSING_GLYPHS %s" % "".join(chars))


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s%s.png" % [_shots_dir, _prefix, file_name]
	var err := image.save_png(path)
	print("UI_SHOT %s %s" % [path, err])
	if file_name == "08-ending":
		_measure_contrast_image(image)


func _measure_contrast() -> void:
	pass


func _measure_contrast_image(image: Image) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_measure_node(image, scene)


func _measure_node(image: Image, node: Node) -> void:
	if node is Label:
		var label := node as Label
		var text := label.text
		if text == "改写记" or text.begins_with("·") or text.begins_with("袁崇焕"):
			var rect := label.get_global_rect()
			var fg := label.get_theme_color("font_color")
			var paper := _sample_paper(image, rect, fg)
			print(
				"CONTRAST text=%s fg=#%s paper=#%s ratio=%.2f"
				% [text.substr(0, 18), fg.to_html(false), paper.to_html(false), _wcag(fg, paper)]
			)
	for child in node.get_children():
		_measure_node(image, child)


func _sample_paper(image: Image, rect: Rect2, fg: Color) -> Color:
	var x0 := clampi(int(rect.position.x), 0, image.get_width() - 1)
	var y0 := clampi(int(rect.position.y) - 6, 0, image.get_height() - 1)
	var x1 := clampi(int(rect.end.x), 0, image.get_width() - 1)
	var y1 := clampi(int(rect.position.y) + 4, 0, image.get_height() - 1)
	var acc := Color(0, 0, 0, 0)
	var count := 0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var px := image.get_pixel(x, y)
			if _wcag(px, fg) < 1.6:
				continue
			acc += px
			count += 1
	if count == 0:
		return image.get_pixel(x0, y0)
	return Color(acc.r / count, acc.g / count, acc.b / count, 1.0)


func _wcag(a: Color, b: Color) -> float:
	var lighter := maxf(_luminance(a), _luminance(b))
	var darker := minf(_luminance(a), _luminance(b))
	return (lighter + 0.05) / (darker + 0.05)


func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


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
