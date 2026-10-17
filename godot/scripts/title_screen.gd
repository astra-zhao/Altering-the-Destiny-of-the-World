extends Control
## 标题页、设置和确认框。版式按 Alice v1.4（1280×720）。

const UiKit := preload("res://scripts/ui_kit.gd")
const STAGE := Vector2(1280, 720)

var _continue: Button
var _save_hint: Label
var _note: Label
var _settings: Control
var _volume_slider: Control
var _volume_readout: Label
var _dialog: Control
var _dialog_title: Label
var _dialog_body: Label
var _dialog_ok: Button
var _dialog_cancel: Button
var _dialog_action := ""
var _settings_was_open := false


func _ready() -> void:
	UiKit.boot()
	_build_backdrop(_title_shade())
	var stage := _stage()
	_build_menu(stage)
	_build_settings()
	_build_dialog()
	_sync_continue()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()


func _build_backdrop(shade_tex: Texture2D) -> void:
	var bg := TextureRect.new()
	bg.name = "StoryBackdrop"
	bg.texture = UiKit.tex("bg_story_s1.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := TextureRect.new()
	shade.texture = shade_tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _stage() -> Control:
	var stage := Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -STAGE.x * 0.5
	stage.offset_top = -STAGE.y * 0.5
	stage.offset_right = STAGE.x * 0.5
	stage.offset_bottom = STAGE.y * 0.5
	add_child(stage)
	return stage


func _build_menu(stage: Control) -> void:
	var title := UiKit.label("改命：天下", _spaced(UiKit.serif, 18), 72, Color("F3E2BF"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Noto 的字面比字号矮一截，标签上移后墨迹顶边才落在 y=88。
	title.position = Vector2(0, 67)
	title.size = Vector2(STAGE.x, 110)
	UiKit.outline(title, 8)
	stage.add_child(title)
	stage.add_child(_gold_rule(178))
	stage.add_child(_gold_rule(198))
	var sub := UiKit.label("明末 · 苍凉家国", _spaced(UiKit.serif, 10), 18, Color("CDBB97"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.position = Vector2(0, 205)
	sub.size = Vector2(STAGE.x, 26)
	UiKit.outline(sub, 4)
	stage.add_child(sub)
	var start := _menu_button(stage, "开始游戏", 470, 280, "primary")
	start.name = "StartButton"
	start.pressed.connect(_on_start)
	_continue = _menu_button(stage, "继续", 470, 360, "disabled")
	_continue.name = "ContinueButton"
	_continue.pressed.connect(_on_continue)
	_save_hint = UiKit.label("暂无存档", UiKit.sans_bold, 12, Color("E85D4C"))
	_save_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_hint.position = Vector2(470, 416)
	_save_hint.size = Vector2(340, 18)
	stage.add_child(_save_hint)
	var settings := _menu_button(stage, "设置", 470, 440, "secondary")
	settings.name = "SettingsButton"
	settings.pressed.connect(open_settings)
	var quit := _menu_button(stage, "退出", 470, 520, "secondary")
	quit.name = "QuitButton"
	quit.pressed.connect(_on_quit)
	var version := UiKit.label("v0.4", UiKit.sans_bold, 13, Color(232.0 / 255.0, 213.0 / 255.0, 181.0 / 255.0, 0.45))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.position = Vector2(1160, 684)
	version.size = Vector2(102, 22)
	stage.add_child(version)
	_note = UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(200, 640)
	_note.size = Vector2(880, 24)
	stage.add_child(_note)


func _menu_button(stage: Control, text: String, x: float, y: float, kind: String) -> Button:
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.45)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = Vector2(x, y + 5)
	shadow.size = Vector2(340, 56)
	stage.add_child(shadow)
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.position = Vector2(x, y)
	button.size = Vector2(340, 56)
	button.custom_minimum_size = Vector2(340, 56)
	var fill := TextureRect.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.show_behind_parent = true
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_right = -2
	fill.offset_bottom = -2
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	button.add_child(fill)
	_paint_menu(button, kind)
	button.mouse_entered.connect(func() -> void:
		if button.disabled:
			return
		var base := str(button.get_meta("kind"))
		_paint_menu(button, "primary_hot" if base == "primary" else "secondary_hot")
	)
	button.mouse_exited.connect(func() -> void:
		if button.disabled:
			return
		_paint_menu(button, str(button.get_meta("kind")))
	)
	button.set_meta("kind", kind)
	stage.add_child(button)
	return button


func _paint_menu(button: Button, kind: String) -> void:
	var top := Color("4A3420")
	var bottom := Color("1C140C")
	var border := Color("D4A84B")
	var font_color := Color("E8D5B5")
	var font_size := 22
	var spacing := 10
	if kind == "primary" or kind == "primary_hot":
		top = Color("C43C2C") if kind == "primary_hot" else Color("B3382C")
		bottom = Color("6A1812")
		font_color = Color("FFF3E0")
		font_size = 24
		spacing = 8
	elif kind == "secondary_hot":
		top = Color("5C4030")
		bottom = Color("2A1C12")
		font_color = Color("FFF6E4")
	elif kind == "disabled":
		top = Color("3A342E")
		bottom = Color("221E1A")
		border = Color("6B635A")
		font_color = Color("6B635A")
	var fill := button.get_node("Fill") as TextureRect
	fill.texture = _vgrad(top, bottom)
	var box := _clear_border(border)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)
	var disabled := _clear_border(Color("6B635A"))
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_override("font", _spaced(UiKit.serif, spacing))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color("6B635A"))


func _clear_border(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box


func _gold_rule(y: float) -> TextureRect:
	var line := TextureRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(500, y)
	line.size = Vector2(280, 2)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.831, 0.659, 0.294, 0))
	gradient.set_offset(0, 0)
	gradient.add_point(0.5, Color("D4A84B"))
	gradient.add_point(1.0, Color(0.831, 0.659, 0.294, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 280
	tex.height = 2
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	line.texture = tex
	return line


func _title_shade() -> Texture2D:
	return _shade([
		[0.0, Color8(8, 5, 3, 158)],
		[0.35, Color8(8, 5, 3, 115)],
		[0.72, Color8(8, 5, 3, 199)],
		[1.0, Color8(8, 5, 3, 235)],
	])


func _shade(stops: Array) -> Texture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		offsets.append(float(stop[0]))
		colors.append(stop[1])
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	return tex


func _vgrad(top: Color, bottom: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 4
	tex.height = 64
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	return tex


func _spaced(font: Font, pixels: int) -> Font:
	if font == null:
		return font
	var varied := FontVariation.new()
	varied.base_font = font
	varied.spacing_glyph = pixels
	return varied


func _build_settings() -> void:
	_settings = _modal("SettingsLayer", Color8(6, 4, 2, 184), 10)
	var stage := _settings.get_node("Stage") as Control
	_lacquer_panel(stage, Rect2(340, 110, 600, 500), Color("2A2118"), Color("14100C"))
	var heading := UiKit.label("设置", _spaced(UiKit.serif, 14), 32, Color("F3E2BF"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.position = Vector2(340, 138)
	heading.size = Vector2(600, 48)
	UiKit.outline(heading, 4)
	stage.add_child(heading)
	var close := _lacquer_button(stage, "×", Rect2(864, 142, 40, 40), "close_x")
	close.pressed.connect(_close_settings)
	stage.add_child(_gold_rule_at(348, 204, 584))
	var icon := UiKit.icon_rect("icon_volume_64.png", 28)
	icon.position = Vector2(376, 210)
	stage.add_child(icon)
	var volume_label := UiKit.label("音量", _spaced(UiKit.serif, 6), 22, Color("E8D5B5"))
	volume_label.position = Vector2(416, 206)
	volume_label.size = Vector2(72, 36)
	stage.add_child(volume_label)
	_volume_slider = Control.new()
	_volume_slider.position = Vector2(504, 207)
	_volume_slider.size = Vector2(340, 28)
	_volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_volume_slider.gui_input.connect(_on_volume_input)
	_volume_slider.draw.connect(_draw_volume_slider)
	stage.add_child(_volume_slider)
	_volume_readout = UiKit.label("70", UiKit.serif, 18, Color("D4A84B"))
	_volume_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_readout.position = Vector2(868, 208)
	_volume_readout.size = Vector2(48, 28)
	stage.add_child(_volume_readout)
	var reset := _lacquer_button(stage, "重置新手引导", Rect2(384, 280, 512, 52), "secondary")
	reset.pressed.connect(open_reset_confirm)
	var clear := _lacquer_button(stage, "清空存档", Rect2(384, 348, 512, 52), "danger")
	clear.pressed.connect(open_clear_confirm)
	var done := _lacquer_button(stage, "关闭", Rect2(384, 424, 512, 52), "close_bot")
	done.pressed.connect(_close_settings)
	_sync_volume_ui(Bgm.master_linear)


func _build_dialog() -> void:
	_dialog = _modal("ConfirmLayer", Color8(4, 2, 1, 199), 20)
	var stage := _dialog.get_node("Stage") as Control
	_lacquer_panel(stage, Rect2(320, 180, 640, 360), Color("2A2118"), Color("120E0A"))
	_dialog_title = UiKit.label("", _spaced(UiKit.serif, 8), 30, Color("F3E2BF"))
	_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_title.position = Vector2(320, 216)
	_dialog_title.size = Vector2(640, 40)
	UiKit.outline(_dialog_title, 3)
	stage.add_child(_dialog_title)
	stage.add_child(_gold_rule_at(530, 266, 220))
	_dialog_body = UiKit.label("", _spaced(UiKit.serif, 2), 18, Color("E8D5B5"))
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_body.add_theme_constant_override("line_spacing", 15)
	_dialog_body.position = Vector2(380, 288)
	_dialog_body.size = Vector2(520, 120)
	stage.add_child(_dialog_body)
	_dialog_ok = _lacquer_button(stage, "", Rect2(354, 432, 200, 52), "danger_fill")
	_dialog_ok.name = "ConfirmOk"
	_dialog_ok.pressed.connect(accept_confirm)
	_dialog_cancel = _lacquer_button(stage, "", Rect2(582, 432, 200, 52), "secondary")
	_dialog_cancel.name = "ConfirmCancel"
	_dialog_cancel.pressed.connect(decline_confirm)


func _modal(node_name: String, shade_color: Color, layer_z: int) -> Control:
	var layer := Control.new()
	layer.name = node_name
	layer.visible = false
	layer.z_index = layer_z
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var blur := ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.material = _blur_material()
	layer.add_child(blur)
	var shade := ColorRect.new()
	shade.color = shade_color
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var stage := Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -STAGE.x * 0.5
	stage.offset_top = -STAGE.y * 0.5
	stage.offset_right = STAGE.x * 0.5
	stage.offset_bottom = STAGE.y * 0.5
	layer.add_child(stage)
	return layer


func _blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;\nvoid fragment() {\n\tCOLOR = textureLod(screen_texture, SCREEN_UV, 2.0);\n}\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _lacquer_panel(stage: Control, rect: Rect2, top: Color, bottom: Color) -> void:
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.55)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.position = rect.position + Vector2(0, 14)
	shadow.size = rect.size
	stage.add_child(shadow)
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color("D4A84B")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", box)
	var fill := TextureRect.new()
	fill.texture = _vgrad(top, bottom)
	fill.show_behind_parent = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_right = -2
	fill.offset_bottom = -2
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(fill)
	stage.add_child(panel)


func _lacquer_button(stage: Control, text: String, rect: Rect2, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size
	var fill := TextureRect.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.show_behind_parent = true
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_right = -2
	fill.offset_bottom = -2
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	button.add_child(fill)
	button.set_meta("kind", kind)
	_paint_lacquer(button, kind)
	stage.add_child(button)
	return button


func _paint_lacquer(button: Button, kind: String) -> void:
	var top := Color("4A3420")
	var bottom := Color("1C140C")
	var border := Color("D4A84B")
	var font_color := Color("E8D5B5")
	var font_size := 20
	var spacing := 6
	var font: Font = UiKit.serif
	match kind:
		"danger":
			top = Color("3A1A14")
			bottom = Color("1A0C0A")
			border = Color("C43C2C")
			font_color = Color("E85D4C")
		"danger_fill":
			top = Color("A02820")
			bottom = Color("5A1010")
			border = Color("E85D4C")
			font_color = Color("FFF3E0")
			font_size = 22
			spacing = 8
		"close_bot":
			font_size = 18
			spacing = 10
		"close_x":
			font = UiKit.sans_bold
			font_size = 22
			spacing = 0
		"pale":
			top = Color("3A342E")
			bottom = Color("1C1814")
			border = Color("A89060")
			font_color = Color("CDBB97")
			spacing = 10
		"confirm_secondary":
			font_size = 20
			spacing = 6
		_:
			font_size = 22 if kind == "confirm_main" else 20
			spacing = 8 if kind == "confirm_main" else 6
	var fill := button.get_node("Fill") as TextureRect
	fill.texture = _vgrad(top, bottom)
	var box := _clear_border(border)
	if kind == "close_x":
		box.set_border_width_all(2)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_font_override("font", _spaced(font, spacing))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.12))
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)


func _gold_rule_at(x: float, y: float, width: float) -> TextureRect:
	var line := TextureRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(x, y)
	line.size = Vector2(width, 2)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.831, 0.659, 0.294, 0),
		Color("D4A84B"),
		Color(0.831, 0.659, 0.294, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = maxi(int(width), 2)
	tex.height = 2
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	line.texture = tex
	return line


func _draw_volume_slider() -> void:
	var width := _volume_slider.size.x
	var ratio := clampf(Bgm.master_linear, 0.0, 1.0)
	var track := Rect2(0, 7, width, 14)
	_volume_slider.draw_rect(track, Color("0E0A08"))
	_volume_slider.draw_rect(Rect2(track.position, Vector2(maxf(width * ratio, 2.0), 14)), Color("D4A84B"))
	var center := Vector2(clampf(width * ratio, 11.0, width - 11.0), 14.0)
	_volume_slider.draw_circle(center, 11.0, Color("D4A84B"))
	_volume_slider.draw_circle(center, 6.0, Color("F3E2BF"))
	_volume_slider.draw_arc(center, 10.0, 0.0, TAU, 28, Color("F3E2BF"), 1.5, true)


func _on_volume_input(event: InputEvent) -> void:
	var slider := _volume_slider
	var local := Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		local = mouse.position
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		local = (event as InputEventMouseMotion).position
	else:
		return
	var ratio := clampf(local.x / maxf(slider.size.x, 1.0), 0.0, 1.0)
	Bgm.set_master_linear(ratio)
	_sync_volume_ui(ratio)


func _sync_volume_ui(ratio: float) -> void:
	if _volume_readout == null:
		return
	_volume_readout.text = str(roundi(clampf(ratio, 0.0, 1.0) * 100.0))
	if _volume_slider != null:
		_volume_slider.queue_redraw()


func _sync_continue() -> void:
	var has_save := Campaign.has_campaign_save()
	_continue.disabled = not has_save
	_continue.set_meta("kind", "secondary" if has_save else "disabled")
	_paint_menu(_continue, str(_continue.get_meta("kind")))
	if _save_hint != null:
		_save_hint.visible = not has_save


func _on_start() -> void:
	if Campaign.has_campaign_save():
		_open_dialog("overwrite")
		return
	_begin_new_game()


func _begin_new_game() -> void:
	Campaign.prepare_fresh_campaign()
	Campaign.arm_skip_guard()
	Bgm.set_mode("story")
	get_tree().change_scene_to_file("res://scenes/prologue.tscn")


func _on_continue() -> void:
	if _continue.disabled:
		return
	var result: Dictionary = Campaign.load_game()
	if not bool(result.get("ok", false)):
		_note.text = str(result.get("message", ""))
		_sync_continue()
		return
	Campaign.arm_skip_guard()
	var path := str(Campaign.resume_scene())
	if path.ends_with("ending.tscn"):
		Bgm.set_mode("ending")
	elif path.ends_with("big_map.tscn"):
		Bgm.set_mode("map")
	else:
		Bgm.set_mode("story")
	get_tree().change_scene_to_file(path)


func _on_quit() -> void:
	get_tree().quit()


func open_settings() -> void:
	_sync_volume_ui(Bgm.master_linear)
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false


func open_clear_confirm() -> void:
	_open_dialog("clear")


func open_reset_confirm() -> void:
	_open_dialog("reset")


func _open_dialog(action: String) -> void:
	_dialog_action = action
	_settings_was_open = _settings.visible
	if action == "clear":
		_dialog_title.text = "清空存档？"
		_dialog_body.text = "你的战役进度和新手引导记录会被删除，无法恢复。音量等设置不受影响。"
		_dialog_ok.text = "清空"
		_dialog_cancel.text = "再想想"
		_paint_lacquer(_dialog_ok, "danger_fill")
		_paint_lacquer(_dialog_cancel, "confirm_secondary")
	elif action == "reset":
		_dialog_title.text = "重置新手引导？"
		_dialog_body.text = "下次进入大地图时，会再次显示新手引导。你的战役进度不受影响。"
		_dialog_ok.text = "重置"
		_dialog_cancel.text = "取消"
		_paint_lacquer(_dialog_ok, "confirm_main")
		_paint_lacquer(_dialog_cancel, "pale")
	else:
		_dialog_title.text = "开始新局？"
		_dialog_body.text = "已有存档。开始新的一局会覆盖旧档，无法恢复。"
		_dialog_ok.text = "开始"
		_dialog_cancel.text = "再想想"
		_paint_lacquer(_dialog_ok, "danger_fill")
		_paint_lacquer(_dialog_cancel, "confirm_secondary")
	_settings.visible = false
	_dialog.visible = true


func accept_confirm() -> void:
	var action := _dialog_action
	_dialog.visible = false
	_dialog_action = ""
	if action != "overwrite" and _settings_was_open:
		_settings.visible = true
	if action == "clear":
		Campaign.clear_campaign_files()
		_sync_continue()
		_note.text = ""
		return
	if action == "reset":
		Campaign.reset_guide_record()
		return
	if action == "overwrite":
		_settings.visible = false
		_begin_new_game()


func decline_confirm() -> void:
	_dialog.visible = false
	_dialog_action = ""
	if _settings_was_open:
		_settings.visible = true
