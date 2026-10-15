extends RefCounted
## S1/S2/S3 的 v1.3 选择卡。3D 场景保留，只叠渐暗遮罩和卡片。

const UiKit := preload("res://scripts/ui_kit.gd")
const AdvisorScript := preload("res://scripts/advisor.gd")


static func mount(layer: Node, spec: Dictionary) -> Control:
	UiKit.boot()
	var root := Control.new()
	root.name = "StoryBoard"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var shade := TextureRect.new()
	shade.texture = UiKit.tex("shade_story.png")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var plaque := UiKit.nine("panel_plaque_title.png", 20)
	plaque.position = Vector2(28, 18)
	plaque.size = Vector2(430, 112)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plaque)
	var kicker := UiKit.label(str(spec.get("kicker", "")), UiKit.sans, 14, UiKit.GOLD)
	kicker.position = Vector2(28, 16)
	plaque.add_child(kicker)
	var title := UiKit.label(str(spec.get("title", "")), UiKit.serif, 32, Color("FFF3D6"))
	title.position = Vector2(24, 36)
	plaque.add_child(title)
	var sub := UiKit.label(str(spec.get("sub", "")), UiKit.sans, 15, UiKit.CREAM)
	sub.position = Vector2(24, 76)
	sub.custom_minimum_size = Vector2(370, 22)
	plaque.add_child(sub)
	var tabs: Array = spec.get("tabs", [])
	if not tabs.is_empty():
		var tab_row := HBoxContainer.new()
		tab_row.position = Vector2(28, 138)
		tab_row.add_theme_constant_override("separation", 8)
		root.add_child(tab_row)
		for tab in tabs:
			tab_row.add_child(_tab(str(tab["text"]), tab["on_press"]))
	var choices: Array = spec.get("choices", [])
	var row := HBoxContainer.new()
	row.name = "StoryCards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	var which := str(spec.get("which", ""))
	var star: Dictionary = AdvisorScript.story_star(Campaign, which) if which != "" else {}
	var starred := str(star.get("choice", ""))
	var show_star := not AdvisorScript.self_pick()
	var on_choose: Callable = spec["on_choose"]
	for choice in choices:
		row.add_child(_card(choice, starred, show_star, on_choose))
	var foot := UiKit.label("选定后立刻写回局面，回到大地图。", UiKit.sans, 14, UiKit.CREAM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_top = -28
	foot.offset_bottom = -8
	foot.offset_left = -280
	foot.offset_right = 280
	root.add_child(foot)
	root.resized.connect(func() -> void:
		_place_cards(root, row)
	)
	_place_cards(root, row)
	return root


static func _place_cards(root: Control, row: Control) -> void:
	var width := root.size.x
	if width < 100.0:
		width = 1280.0
	var height := root.size.y
	if height < 100.0:
		height = 720.0
	var block := row.get_combined_minimum_size()
	row.position = Vector2((width - block.x) * 0.5, height - block.y - 48.0)
	row.size = block


static func _tab(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96, 34)
	if UiKit.serif != null:
		button.add_theme_font_override("font", UiKit.serif)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("FFF3D6"))
	var off := UiKit.style_tex("tab_look_off.png", 8, 4)
	var on := UiKit.style_tex("tab_look_on.png", 8, 4)
	button.add_theme_stylebox_override("normal", off)
	button.add_theme_stylebox_override("hover", on)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("focus", on)
	button.pressed.connect(on_press)
	return button


static func _card(choice: Dictionary, starred: String, show_star: bool, on_choose: Callable) -> Control:
	var choice_id := str(choice["id"])
	var locked := bool(choice.get("locked", false))
	var is_star := show_star and choice_id == starred and not locked
	var button := Button.new()
	button.name = "StoryCard_%s" % choice_id
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = false
	button.custom_minimum_size = Vector2(260, 196)
	button.z_index = 1
	button.set_meta("choice_id", choice_id)
	button.set_meta("starred", is_star)
	var normal := "card_story_disabled.png" if locked else ("card_story_recommend.png" if is_star else "card_story_normal.png")
	var hover := "card_story_disabled.png" if locked else "card_story_hover.png"
	var pressed := "card_story_disabled.png" if locked else "card_story_selected.png"
	button.add_theme_stylebox_override("normal", UiKit.style_tex(normal, 20, 14))
	button.add_theme_stylebox_override("hover", UiKit.style_tex(hover, 20, 14))
	button.add_theme_stylebox_override("pressed", UiKit.style_tex(pressed, 20, 14))
	button.add_theme_stylebox_override("disabled", UiKit.style_tex("card_story_disabled.png", 20, 14))
	button.add_theme_stylebox_override("focus", UiKit.style_tex(pressed, 20, 14))
	button.add_theme_stylebox_override("hover_pressed", UiKit.style_tex(pressed, 20, 14))
	button.disabled = locked
	if not locked:
		button.pressed.connect(func() -> void:
			button.disabled = true
			on_choose.call(choice_id)
		)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.clip_contents = true
	body.position = Vector2(16, 18)
	body.size = Vector2(228, 164)
	body.add_theme_constant_override("separation", 6)
	button.add_child(body)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	body.add_child(head)
	var seal := TextureRect.new()
	seal.texture = UiKit.tex("seal_choice_locked.png" if locked else "seal_choice_normal.png")
	seal.custom_minimum_size = Vector2(44, 44)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(seal)
	var letter := UiKit.label(choice_id, UiKit.serif, 22, Color("FFF3D6"))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	seal.add_child(letter)
	var name := UiKit.label(str(choice["title"]), UiKit.serif, 22, Color("6A5A46") if locked else UiKit.GOLD)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(name)
	var chips := HFlowContainer.new()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.custom_minimum_size = Vector2(228, 28)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	body.add_child(chips)
	for part in choice.get("parts", []):
		chips.add_child(_fx(str(part["text"]), str(part["kind"])))
	if locked:
		var why := UiKit.label(str(choice.get("lock_reason", "")), UiKit.sans_bold, 14, Color("E85D4C"))
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(why)
	if is_star:
		var badge := TextureRect.new()
		badge.name = "BadgeBest"
		badge.texture = UiKit.tex("badge_best.png")
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_SCALE
		badge.z_index = 4
		badge.position = Vector2(260.0 - 140.0 + 10.0, -16.0)
		badge.size = Vector2(140, 58)
		button.add_child(badge)
		var ribbon := UiKit.label("★ 最优", UiKit.serif, 20, Color("2A1A10"))
		ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ribbon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
		ribbon.offset_top = -4
		badge.add_child(ribbon)
	return button


static func _fx(text: String, kind: String) -> Control:
	var file := "chip_fx_status.png"
	var color := UiKit.CREAM
	if kind == "gain":
		file = "chip_fx_gain.png"
		color = UiKit.GAIN
	elif kind == "cost":
		file = "chip_fx_cost.png"
		color = UiKit.LOSS
	elif kind == "world":
		file = "chip_fx_world.png"
		color = Color("FFD978")
	var chip := UiKit.nine(file, 6)
	chip.custom_minimum_size = Vector2(0, 28)
	var label := UiKit.label(text, UiKit.sans, 13, color)
	label.position = Vector2(8, 2)
	chip.add_child(label)
	chip.custom_minimum_size = Vector2(label.get_combined_minimum_size().x + 16.0, 28)
	return chip
