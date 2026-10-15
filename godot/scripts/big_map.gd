extends Control
## v0.4 大地图。规则仍在 Campaign。画面换成 Alice 的 UI v1.2 切图。
## 点选仍是：先点我方城，再点目标，行军或攻城自动判。

const Baseline := preload("res://data/campaign_baseline.gd")
const AdvisorScript := preload("res://scripts/advisor.gd")
const UiKit := preload("res://scripts/ui_kit.gd")
const _TOKEN := preload("res://scripts/city_token.gd")

## 示意方位仍按 campaign_baseline：西在左，东北在右上。像素躲开 HUD、内政、帮我选和印章。
const CITY_POS := {
	"C3": Vector2(0.11, 0.36),
	"C1": Vector2(0.30, 0.42),
	"C2": Vector2(0.17, 0.48),
	"C4": Vector2(0.46, 0.34),
	"C6": Vector2(0.59, 0.27),
	"C5": Vector2(0.70, 0.23),
}

var _selected_id := ""
var _pick := ""
var _markers: Dictionary = {}
var _in_battle := false
var _turn_busy := false
var _end_locked_until := 0
var _advisor_lock := false

var _routes: Control
var _city_layer: Control
var _top: Control
var _chip_row: HBoxContainer
var _tool_row: HBoxContainer
var _chips: Dictionary = {}
var _hint_row: HBoxContainer
var _hint: Label
var _log: Label
var _side: VBoxContainer
var _yuan_line: Label
var _cards: Dictionary = {}
var _actions: VBoxContainer
var _action_title: Label
var _action_why: Label
var _seals: Dictionary = {}
var _end_button: TextureButton
var _end_label: Label
var _end_reason: Label
var _help_button: Button
var _advisor_panel: NinePatchRect
var _advisor_list: VBoxContainer
var _guide: Control
var _guide_bubble: Control
var _guide_num: Label
var _guide_panel: Control
var _guide_text: Label
var _guide_target: Control
var _battle: Control
var _battle_frame: NinePatchRect
var _battle_title_plate: NinePatchRect
var _battle_columns: HBoxContainer
var _battle_error: Label
var _atk_name: Label
var _atk_role: Label
var _atk_badge: TextureRect
var _atk_num: Label
var _atk_extra: Label
var _atk_mod: Label
var _atk_power: Label
var _def_name: Label
var _def_role: Label
var _def_badge: TextureRect
var _def_num: Label
var _def_extra: Label
var _def_mod: Label
var _def_power: Label
var _vs: Label
var _stamp: TextureRect
var _result: Label
var _progress_box: VBoxContainer
var _battle_track: Control
var _battle_fill: NinePatchRect
var _battle_skip: Button
var _battle_close: Button
var _battle_src := ""
var _battle_dst := ""
var _battle_done := false
var _battle_tween: Tween
var _credits: Control
var _mute_button: Button
var _volume: HSlider


func _ready() -> void:
	UiKit.boot()
	_build_ui()
	_build_markers()
	_build_battle()
	_build_credits()
	resized.connect(_layout_chrome)
	_layout_chrome.call_deferred()
	_refresh()
	Bgm.set_mode("map")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	if Campaign.pending_story != "":
		_open_story(Campaign.pending_story)
		return
	if Campaign.settled and Campaign.ending_id != "" and not Campaign.skip_ending_scene:
		_open_ending()
		return
	Campaign.skip_ending_scene = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_clear_selection()
		_show_note("已取消选择。")
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = UiKit.tex("bg_map_liaodong.jpg")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_routes = Control.new()
	_routes.set_script(load("res://scripts/map_canvas.gd"))
	_routes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_routes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_routes)
	_city_layer = Control.new()
	_city_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_city_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_city_layer.gui_input.connect(_on_map_blank)
	add_child(_city_layer)
	_build_actions()
	_build_top()
	_build_hint_row()
	_build_side()
	_build_advisor()
	_build_end()
	_build_guide()


func _build_top() -> void:
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.z_index = 6
	add_child(_top)
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 4)
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_chip_row)
	for spec in [
		["silver", "icon_silver_64.png", "银两"],
		["grain", "icon_grain_64.png", "粮草"],
		["morale", "icon_minxin_64.png", "民心"],
		["liaodong", "icon_liaodong_64.png", "辽东稳固"],
		["pressure", "icon_pressure_64.png", "后金压力"],
		["turn", "icon_turn_64.png", "回合"],
	]:
		_chips[str(spec[0])] = _add_chip(str(spec[1]), str(spec[2]))
	_tool_row = HBoxContainer.new()
	_tool_row.add_theme_constant_override("separation", 2)
	_tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tool_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_tool_row)
	for pair in [["存档", _on_save], ["读档", _on_load], ["新局", _on_new_game], ["署名", _on_credits]]:
		_tool_row.add_child(_compact_link(str(pair[0]), pair[1]))
	_tool_row.add_child(UiKit.icon_rect("icon_volume_64.png", 22))
	_volume = HSlider.new()
	_volume.custom_minimum_size = Vector2(64, 28)
	_volume.min_value = 0
	_volume.max_value = 1
	_volume.step = 0.01
	_volume.value = Bgm.master_linear
	_volume.tooltip_text = "音量。拉到最左就是静音。"
	_style_slider(_volume)
	_volume.value_changed.connect(_on_volume)
	_tool_row.add_child(_volume)
	_mute_button = _compact_link("静音", _on_mute)
	_tool_row.add_child(_mute_button)


func _compact_link(text: String, handler: Callable) -> Button:
	var button := UiKit.link_button(text)
	button.add_theme_font_size_override("font_size", 14)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 3
	empty.content_margin_right = 3
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.pressed.connect(handler)
	return button


func _add_chip(icon_name: String, caption: String) -> Label:
	var plate := UiKit.nine("hud_chip_normal.png", 10)
	plate.custom_minimum_size = Vector2(158, 46)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_row.add_child(plate)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 3
	row.offset_right = -6
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(UiKit.icon_rect(icon_name, 40))
	var name := UiKit.label(caption, UiKit.sans, 13, UiKit.CREAM)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var value := UiKit.label("0", UiKit.serif, 18, UiKit.GOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	return value


func _build_hint_row() -> void:
	_hint_row = HBoxContainer.new()
	_hint_row.z_index = 6
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.clip_contents = true
	add_child(_hint_row)
	var plate := UiKit.nine("panel_frame_s.png", 10)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.custom_minimum_size = Vector2(280, 68)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.add_child(plate)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_top = 6
	column.offset_right = -12
	column.offset_bottom = -6
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var prefix := UiKit.label("下一步", UiKit.serif, 18, UiKit.GOLD)
	row.add_child(prefix)
	_hint = UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.custom_minimum_size = Vector2(40, 22)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_hint)
	_log = UiKit.label("", UiKit.sans, 14, UiKit.GOLD)
	_log.clip_text = true
	_log.custom_minimum_size = Vector2(40, 18)
	_log.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_log)


func _build_side() -> void:
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 4)
	_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_side.z_index = 6
	add_child(_side)
	var head := UiKit.label("内政", UiKit.serif, 26, UiKit.GOLD)
	UiKit.outline(head, 5)
	_side.add_child(head)
	var sub := UiKit.label("每回合可选一项", UiKit.sans, 14, UiKit.CREAM)
	UiKit.outline(sub, 4)
	_side.add_child(sub)
	_yuan_line = UiKit.label("", UiKit.sans, 14, UiKit.CREAM)
	UiKit.outline(_yuan_line, 4)
	_side.add_child(_yuan_line)
	_side.add_child(_make_card("levy", "征粮", [
		{"text": "粮+%d" % Baseline.LEVY_GRAIN, "color": UiKit.GAIN},
		{"text": "民心-%d" % Baseline.LEVY_MORALE, "color": UiKit.LOSS},
	]))
	_side.add_child(_make_card("spend", "发帑", [
		{"text": "银-%d" % Baseline.SPEND_SILVER, "color": UiKit.LOSS},
		{"text": "民心+%d" % Baseline.SPEND_MORALE, "color": UiKit.GAIN},
	]))
	_side.add_child(_make_card("train", "练兵", [
		{"text": "银-%d" % Baseline.TRAIN_SILVER, "color": UiKit.LOSS},
		{"text": "粮-%d" % Baseline.TRAIN_GRAIN, "color": UiKit.LOSS},
		{"text": "兵力+%d" % Baseline.TRAIN_TROOPS, "color": UiKit.GAIN},
	]))


func _make_card(kind: String, title: String, parts: Array) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(272, 108)
	button.add_theme_stylebox_override("normal", UiKit.style_tex("card_neizheng_normal.png", 20, 14))
	button.add_theme_stylebox_override("hover", UiKit.style_tex("card_neizheng_hover.png", 20, 14))
	button.add_theme_stylebox_override("pressed", UiKit.style_tex("card_neizheng_pressed.png", 20, 14))
	button.add_theme_stylebox_override("disabled", UiKit.style_tex("card_neizheng_disabled.png", 20, 14))
	button.add_theme_stylebox_override("focus", UiKit.style_tex("card_neizheng_selected.png", 20, 14))
	button.add_theme_stylebox_override("hover_pressed", UiKit.style_tex("card_neizheng_selected.png", 20, 14))
	button.pressed.connect(_on_civil.bind(kind))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_top = 12
	row.offset_right = -12
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)
	var icon_name := "icon_grain_64.png"
	if kind == "spend":
		icon_name = "icon_silver_64.png"
	elif kind == "train":
		icon_name = "icon_lianbing_64.png"
	row.add_child(UiKit.icon_rect(icon_name, 48))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var name := UiKit.label(title, UiKit.serif, 24, UiKit.GOLD)
	text.add_child(name)
	var deltas := HBoxContainer.new()
	deltas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deltas.add_theme_constant_override("separation", 8)
	text.add_child(deltas)
	for part in parts:
		deltas.add_child(UiKit.label(str(part["text"]), UiKit.sans, 15, part["color"]))
	var reason := UiKit.label("", UiKit.sans, 14, UiKit.WARN)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(reason)
	_cards[kind] = {"button": button, "reason": reason, "title": name}
	return button


func _build_actions() -> void:
	_actions = VBoxContainer.new()
	_actions.visible = false
	_actions.z_index = 1
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_theme_constant_override("separation", 2)
	_city_layer.add_child(_actions)
	_action_title = UiKit.label("主行动", UiKit.serif, 16, UiKit.GOLD)
	_action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.outline(_action_title, 4)
	_actions.add_child(_action_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_child(row)
	_seals["march"] = _seal_slot(row, "btn_action_march", "行军", _on_march_mode)
	_seals["attack"] = _seal_slot(row, "btn_action_siege", "攻城", _on_attack_mode)
	_seals["hold"] = _seal_slot(row, "btn_action_hold", "固守", _on_hold)
	_action_why = UiKit.label("", UiKit.sans, 13, UiKit.WARN)
	_action_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_why.custom_minimum_size = Vector2(360, 0)
	UiKit.outline(_action_why, 3)
	_actions.add_child(_action_why)


func _seal_slot(parent: Node, prefix: String, caption: String, handler: Callable) -> Dictionary:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(144, 0)
	parent.add_child(box)
	var button := UiKit.seal_button(prefix)
	button.custom_minimum_size = Vector2(144, 144)
	button.ignore_texture_size = true
	button.pressed.connect(handler)
	box.add_child(button)
	var plaque_wrap := CenterContainer.new()
	plaque_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plaque_wrap)
	var plaque := UiKit.nine("plaque_cinnabar_normal.png", 8)
	plaque.custom_minimum_size = Vector2(96, 34)
	plaque_wrap.add_child(plaque)
	var name := UiKit.label(caption, UiKit.serif, 20, UiKit.CREAM)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.set_anchors_preset(Control.PRESET_FULL_RECT)
	plaque.add_child(name)
	var reason := UiKit.label("", UiKit.sans, 13, UiKit.WARN)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.clip_text = true
	reason.custom_minimum_size = Vector2(116, 32)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.outline(reason, 3)
	box.add_child(reason)
	button.mouse_entered.connect(_on_seal_hover.bind(prefix, true))
	button.mouse_exited.connect(_on_seal_hover.bind(prefix, false))
	return {"button": button, "reason": reason, "plaque": plaque, "prefix": prefix, "hover": false}


func _build_end() -> void:
	_end_reason = UiKit.label("", UiKit.sans, 14, UiKit.WARN)
	_end_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_reason.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_reason.custom_minimum_size = Vector2(188, 44)
	_end_reason.clip_text = true
	_end_reason.z_index = 6
	UiKit.outline(_end_reason, 4)
	add_child(_end_reason)
	_end_button = UiKit.seal_button("btn_next_turn")
	_end_button.custom_minimum_size = Vector2(188, 188)
	_end_button.z_index = 6
	_end_button.pressed.connect(_on_end_turn)
	add_child(_end_button)
	_end_label = UiKit.label("下一回合", UiKit.serif, 28, UiKit.CREAM)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_button.add_child(_end_label)


func _build_advisor() -> void:
	_help_button = UiKit.painted_button("帮我选", true, 148)
	_help_button.add_theme_font_size_override("font_size", 20)
	_help_button.visible = false
	_help_button.z_index = 5
	_help_button.pressed.connect(_on_help)
	add_child(_help_button)
	_advisor_panel = UiKit.nine("panel_advisor.png", 20)
	_advisor_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_advisor_panel.clip_contents = true
	_advisor_panel.custom_minimum_size = Vector2(470, 214)
	_advisor_panel.z_index = 5
	add_child(_advisor_panel)
	var inner := MarginContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_top", 14)
	inner.add_theme_constant_override("margin_bottom", 12)
	_advisor_panel.add_child(inner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	inner.add_child(column)
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 44)
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var avatar := UiKit.icon_rect("advisor_avatar.png", 44)
	head.add_child(avatar)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(UiKit.label("帮我选", UiKit.serif, 20, UiKit.GOLD))
	titles.add_child(UiKit.label("谋士献策 · 点一条即执行", UiKit.sans, 13, UiKit.CREAM))
	var fold := UiKit.link_button("收起")
	fold.pressed.connect(func() -> void:
		_advisor_panel.hide()
		_layout_chrome()
	)
	head.add_child(fold)
	_advisor_list = VBoxContainer.new()
	_advisor_list.add_theme_constant_override("separation", 2)
	column.add_child(_advisor_list)
	_advisor_panel.hide()


func _build_guide() -> void:
	_guide = Control.new()
	_guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.z_index = 8
	add_child(_guide)
	_guide_bubble = Control.new()
	_guide_bubble.custom_minimum_size = Vector2(32, 32)
	_guide_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.add_child(_guide_bubble)
	var bubble_tex := TextureRect.new()
	bubble_tex.texture = UiKit.tex("bubble_step.png")
	bubble_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bubble_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_bubble.add_child(bubble_tex)
	_guide_num = UiKit.label("1", UiKit.serif, 16, UiKit.INK)
	_guide_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guide_num.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide_bubble.add_child(_guide_num)
	_guide_panel = UiKit.nine("panel_frame_s.png", 10)
	_guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.add_child(_guide_panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 8
	box.offset_right = -12
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_panel.add_child(box)
	_guide_text = UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	_guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_text.custom_minimum_size = Vector2(260, 0)
	box.add_child(_guide_text)
	var skip := UiKit.link_button("跳过引导")
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.pressed.connect(_on_skip_guide)
	box.add_child(skip)


func _on_skip_guide() -> void:
	Campaign.guide_skip()
	_guide.visible = false
	_show_note("引导已跳过。以后开新局也不会再出现。")


func _build_markers() -> void:
	for city in Baseline.CITIES:
		var city_id := str(city["id"])
		var button := Button.new()
		button.set_script(_TOKEN)
		button.pressed.connect(_on_city_pressed.bind(city_id))
		_city_layer.add_child(button)
		_markers[city_id] = button
	_city_layer.move_child(_actions, _city_layer.get_child_count() - 1)


func _layout_chrome() -> void:
	if _top == null or size.x < 80.0:
		return
	_top.position = Vector2(8, 8)
	_top.size = Vector2(size.x - 16, 50)
	var tools := _tool_row.get_combined_minimum_size()
	_tool_row.position = Vector2(_top.size.x - tools.x, 2)
	_tool_row.size = Vector2(tools.x, 46)
	var chip_span := maxf(0.0, _tool_row.position.x - 6.0)
	_chip_row.position = Vector2(0, 2)
	_chip_row.size = Vector2(chip_span, 46)
	var hint_w := minf(560.0, size.x - 320.0)
	_hint_row.position = Vector2(8, 62)
	_hint_row.size = Vector2(hint_w, 68)
	_side.position = Vector2(size.x - 284, 62)
	var side_min := _side.get_combined_minimum_size()
	var side_limit := size.y - 248.0
	_side.size = Vector2(272, minf(maxf(side_min.y, 280.0), maxf(200.0, side_limit - _side.position.y)))
	_end_button.position = Vector2(size.x - 200, size.y - 196)
	_end_button.size = Vector2(188, 188)
	_end_reason.position = Vector2(size.x - 204, _end_button.position.y - 50)
	_end_reason.size = Vector2(188, 48)
	_layout_advisor()
	_position_markers()
	_layout_battle()


func _layout_advisor() -> void:
	if _advisor_panel == null:
		return
	if not _advisor_panel.visible:
		_help_button.visible = true
		_help_button.position = Vector2(16, size.y - 70)
		return
	_help_button.visible = false
	var height := 214.0
	var width := 470.0
	_advisor_panel.position = Vector2(12, size.y - 8 - height)
	_advisor_panel.size = Vector2(width, height)


func _position_markers() -> void:
	if _city_layer == null:
		return
	var sz := size
	if sz.x < 40.0 or sz.y < 40.0:
		return
	var points := {}
	for city_id in _markers:
		var button: Control = _markers[city_id]
		var pos: Vector2 = CITY_POS.get(str(city_id), Vector2(0.5, 0.5))
		var center := pos * sz
		button.position = center - button.badge_center()
		points[str(city_id)] = center
	if _routes != null and _routes.has_method("set_points"):
		_routes.set_points(points)
	_layout_actions()
	_refresh_guide()


func _layout_actions() -> void:
	if _actions == null or not _actions.visible or _selected_id == "" or not _markers.has(_selected_id):
		return
	var token: Control = _markers[_selected_id]
	var center: Vector2 = token.position + token.badge_center()
	var block := _actions.get_combined_minimum_size()
	if block.x < 80.0:
		block = Vector2(460, 210)
	var origin := Vector2(center.x - block.x * 0.5, center.y + 40.0)
	origin = _clear_of(origin, block, _action_spots(center, block), true)
	_actions.position = origin
	_actions.size = block


func _refresh() -> void:
	_chips["silver"].text = str(Campaign.silver)
	_chips["grain"].text = str(Campaign.grain)
	_chips["morale"].text = str(Campaign.morale)
	_chips["liaodong"].text = str(Campaign.liaodong)
	_chips["pressure"].text = str(Campaign.pressure)
	var turn_text := "%d/%d" % [Campaign.turn, Baseline.TURN_LIMIT]
	if Campaign.settled:
		turn_text += " 完"
	_chips["turn"].text = turn_text
	_yuan_line.text = "袁崇焕 %s" % Campaign.yuan_status
	_log.text = Campaign.log_text
	var hint := _next_hint()
	if hint.begins_with("下一步："):
		hint = hint.substr(4)
	elif hint.begins_with("下一步:"):
		hint = hint.substr(4)
	_hint.text = hint
	_mute_button.text = "取消静音" if Bgm.muted else "静音"
	_refresh_markers()
	_refresh_popup()
	_refresh_cards()
	_refresh_end()
	_fill_advisor()
	_refresh_guide()


func _next_hint() -> String:
	if _in_battle:
		return "下一步：这一仗还在打。可以等一下，或点「跳过演出」。"
	if Campaign.settled:
		return "下一步：这一局已经结束。可以读档，或开一局新的。"
	if Campaign.pending_story != "":
		return "下一步：要进剧情了。里面的选项得你自己点。"
	if not Campaign.main_done and _selected_id == "":
		return "下一步：先点一座我方的城（金色的）。"
	if not Campaign.main_done:
		return "下一步：点旁边的城出兵，或在下面选固守。右边的内政也可以先做。"
	if not Campaign.civil_done:
		return "下一步：内政还能做一次。不做的话，直接点「下一回合」。"
	return "下一步：点右下角红色的「下一回合」。"


func _refresh_markers() -> void:
	for city_id in _markers:
		var info := Campaign.city(str(city_id))
		var token = _markers[city_id]
		token.city_name = str(info["name"])
		token.owner_name = Campaign.display_owner(str(city_id))
		token.troops = int(info["troops"])
		token.marked = str(city_id) == _selected_id
		token.hinted = _selected_id != "" and str(city_id) != _selected_id and Campaign.is_adjacent(_selected_id, str(city_id))
		token.yuan_here = Campaign.yuan_city == str(city_id)
		token.holding = Campaign.hold_city == str(city_id)
		token.tooltip_text = "%s，%s，兵力 %d。点它可选中或作为目标。" % [info["name"], token.owner_name, int(info["troops"])]
		token.redraw()
		if token.marked:
			_city_layer.move_child(token, _city_layer.get_child_count() - 1)
	if _actions != null:
		_city_layer.move_child(_actions, _city_layer.get_child_count() - 1)


func _refresh_popup() -> void:
	var show := _selected_id != "" and str(Campaign.city(_selected_id).get("faction", "")) == "明" and not _in_battle
	_actions.visible = show
	if not show:
		return
	_apply_seal("march", _march_state(), _pick == "march")
	_apply_seal("attack", _attack_state(), _pick == "attack")
	_apply_seal("hold", _hold_state(), false)
	var whys: PackedStringArray = []
	for which in ["march", "attack", "hold"]:
		var slot: Dictionary = _seals[which]
		var why := str((slot["reason"] as Label).text)
		(slot["reason"] as Label).visible = false
		if why != "" and not whys.has(why):
			whys.append(why)
	_action_why.visible = not whys.is_empty()
	_action_why.text = "\n".join(whys)
	_layout_actions()


func _apply_seal(which: String, state: Dictionary, picked: bool) -> void:
	var slot: Dictionary = _seals[which]
	var button: TextureButton = slot["button"]
	var reason: Label = slot["reason"]
	var plaque: NinePatchRect = slot["plaque"]
	var enabled := bool(state["on"])
	button.disabled = not enabled
	reason.visible = not enabled
	reason.text = str(state["why"]) if not enabled else ""
	button.tooltip_text = str(state["why"])
	UiKit.paint_seal(button, str(slot["prefix"]), picked, bool(slot["hover"]))
	var mode := "normal"
	if not enabled:
		mode = "disabled"
	elif picked:
		mode = "selected"
	elif bool(slot["hover"]):
		mode = "hover"
	plaque.texture = UiKit.tex("plaque_cinnabar_%s.png" % mode)


func _on_seal_hover(prefix: String, inside: bool) -> void:
	for which in _seals:
		if str(_seals[which]["prefix"]) == prefix:
			_seals[which]["hover"] = inside
	if _actions.visible:
		_refresh_popup()


func _refresh_cards() -> void:
	_apply_card("levy", _levy_state())
	_apply_card("spend", _spend_state())
	_apply_card("train", _train_state())


func _apply_card(kind: String, state: Dictionary) -> void:
	var card: Dictionary = _cards[kind]
	var button: Button = card["button"]
	var reason: Label = card["reason"]
	var title: Label = card["title"]
	var enabled := bool(state["on"])
	button.disabled = not enabled
	reason.visible = not enabled
	reason.text = str(state["why"]) if not enabled else ""
	button.tooltip_text = str(state["why"])
	title.add_theme_color_override("font_color", Color(0.62, 0.56, 0.48) if not enabled else UiKit.GOLD)


func _refresh_end() -> void:
	var state := _end_state()
	var enabled := bool(state["on"])
	_end_button.disabled = not enabled
	_end_button.modulate = Color.WHITE
	_end_button.self_modulate = Color.WHITE
	if enabled:
		_end_button.texture_normal = UiKit.tex("btn_next_turn_normal.png")
		_end_button.texture_hover = UiKit.tex("btn_next_turn_hover.png")
		_end_button.texture_pressed = UiKit.tex("btn_next_turn_pressed.png")
		_end_button.texture_focused = UiKit.tex("btn_next_turn_normal.png")
	else:
		var gray := UiKit.tex("btn_next_turn_disabled.png")
		_end_button.texture_normal = gray
		_end_button.texture_hover = gray
		_end_button.texture_pressed = gray
		_end_button.texture_disabled = gray
		_end_button.texture_focused = gray
	_end_reason.visible = not enabled
	_end_reason.text = str(state["why"]) if not enabled else ""
	_end_button.tooltip_text = str(state["why"])
	_end_label.add_theme_color_override("font_color", Color(0.72, 0.66, 0.6) if not enabled else UiKit.CREAM)


func _refresh_guide() -> void:
	if _guide == null:
		return
	if Campaign.guide_done or _in_battle:
		_guide.visible = false
		_guide_target = null
		return
	_guide.visible = true
	var line := "先点一座亮着的城，那是你的人。"
	var step_no := "1"
	_guide_target = _suggest_city()
	if Campaign.guide_step == 1:
		line = "再选一个行动。点旁边的城，会自己判断是行军还是攻城。"
		step_no = "2"
		_guide_target = _actions if _actions.visible else _suggest_city()
	elif Campaign.guide_step >= 2:
		line = "做完就点右下角红色的「下一回合」。"
		step_no = "3"
		_guide_target = _end_button
	_guide_text.text = line
	_guide_num.text = step_no
	var rect := Rect2()
	if _guide_target != null and is_instance_valid(_guide_target) and _guide_target.is_visible_in_tree():
		rect = _guide_target.get_global_rect()
	var panel := Vector2(300, 84)
	var origin := Vector2.ZERO
	if _actions != null and _actions.visible and Campaign.guide_step >= 1:
		origin = Vector2(488, size.y - 96)
	else:
		origin = _clear_of(rect.position + Vector2(rect.size.x + 12, 8), panel, _guide_spots(rect, panel), false)
	if _advisor_panel != null and _advisor_panel.visible:
		var adv := _advisor_panel.get_global_rect()
		var guide_rect := Rect2(origin, panel)
		if guide_rect.intersects(adv):
			origin.x = adv.end.x + 8.0
			if origin.x + panel.x > size.x - 8.0:
				origin = Vector2(maxf(8.0, adv.position.x), maxf(140.0, adv.position.y - panel.y - 8.0))
	_guide_bubble.position = rect.position + Vector2(-4, -10) - _guide.global_position
	_guide_bubble.size = Vector2(32, 32)
	_guide_panel.position = origin - _guide.global_position
	_guide_panel.size = panel


func _action_spots(center: Vector2, block: Vector2) -> Array:
	return [
		Vector2(center.x - block.x * 0.5, center.y + 58.0),
		Vector2(center.x - block.x * 0.15, center.y + 58.0),
		Vector2(center.x - block.x * 0.85, center.y + 58.0),
		Vector2(center.x + 36.0, center.y - block.y * 0.45),
		Vector2(center.x - block.x - 12.0, center.y - block.y * 0.2),
		Vector2(center.x - block.x * 0.5, center.y - block.y - 28.0),
	]


func _guide_spots(target: Rect2, panel: Vector2) -> Array:
	return [
		target.position + Vector2(target.size.x + 12, 8),
		Vector2(target.position.x - panel.x - 12, target.position.y),
		Vector2(target.position.x, target.position.y - panel.y - 14),
		Vector2(target.position.x + target.size.x - panel.x, target.position.y - panel.y - 14),
		Vector2(target.position.x, target.end.y + 12),
		Vector2(16, 140),
		Vector2(240, 140),
		Vector2(size.x * 0.34, 140),
		Vector2(500, size.y - 102),
	]


func _clear_of(preferred: Vector2, block: Vector2, spots: Array, for_actions: bool) -> Vector2:
	var obstacles: Array[Rect2] = []
	var ceiling := 136.0
	obstacles.append(Rect2(0, 0, size.x, ceiling))
	if _side != null:
		obstacles.append(Rect2(_side.position, _side.size))
	if _end_button != null:
		obstacles.append(_end_button.get_global_rect().grow(6))
	if _advisor_panel != null and _advisor_panel.visible:
		obstacles.append(_advisor_panel.get_global_rect())
	if _hint_row != null:
		obstacles.append(_hint_row.get_global_rect())
	for city_id in _markers:
		if for_actions and str(city_id) == _selected_id:
			continue
		if not for_actions and _guide_target == _markers[city_id]:
			continue
		var token: Control = _markers[city_id]
		obstacles.append(token.get_global_rect().grow(4))
	if _actions != null and _actions.visible:
		var seal_rect := _actions.get_global_rect()
		for which in _seals:
			var slot: Dictionary = _seals[which]
			seal_rect = seal_rect.merge((slot["button"] as Control).get_global_rect())
			seal_rect = seal_rect.merge((slot["plaque"] as Control).get_global_rect())
		obstacles.append(seal_rect.grow(8))
	var best := preferred
	var best_hit := INF
	var pool: Array = [preferred]
	pool.append_array(spots)
	for spot in pool:
		var point := spot as Vector2
		var right_limit := size.x - 8.0
		if _side != null:
			right_limit = _side.position.x - 8.0
		point.x = clampf(point.x, 8.0, maxf(8.0, right_limit - block.x))
		point.y = clampf(point.y, ceiling, maxf(ceiling, size.y - 8.0 - block.y))
		var box := Rect2(point, block)
		var hit := 0.0
		for obs in obstacles:
			if box.intersects(obs):
				var overlap := box.intersection(obs)
				hit += overlap.size.x * overlap.size.y
		if hit > 0.0:
			hit += 100000.0
		hit += point.distance_to(preferred) * 0.35
		if hit < best_hit:
			best_hit = hit
			best = point
	return best


func _suggest_city() -> Control:
	if _markers.has("C4") and str(Campaign.city("C4")["faction"]) == "明":
		return _markers["C4"]
	for city_id in _markers:
		if str(Campaign.city(str(city_id))["faction"]) == "明":
			return _markers[city_id]
	return _end_button


func _on_city_pressed(city_id: String) -> void:
	if _in_battle:
		_show_note("战斗进行中，先看完这一仗。")
		return
	if Campaign.settled:
		_show_note("这局已经结束。")
		return
	if _selected_id != "" and city_id != _selected_id and not Campaign.main_done:
		_try_target(city_id)
		return
	if city_id == _selected_id:
		_show_note("还是这座城。点旁边另一座，或按 Esc 取消。")
		return
	_pick = ""
	if str(Campaign.city(city_id)["faction"]) != "明":
		_selected_id = ""
		_refresh()
		_show_note("这是对方的城。先点你自己的城。")
		return
	_selected_id = city_id
	Campaign.guide_note_city()
	_refresh()
	_show_note("已选 %s。点相邻的城就能出兵，也可以选固守。" % Campaign.city(city_id)["name"])


func _try_target(city_id: String) -> void:
	if not Campaign.is_adjacent(_selected_id, city_id):
		_show_note("两城不相邻，走不过去。局面没有变。")
		return
	var src_faction := str(Campaign.city(_selected_id)["faction"])
	var dst_faction := str(Campaign.city(city_id)["faction"])
	if src_faction != "明":
		_show_note("要先点我方的城。局面没有变。")
		return
	if _pick == "march" and dst_faction != "明":
		_show_note("行军只能去我方的城。局面没有变。")
		return
	if _pick == "attack" and dst_faction == "明":
		_show_note("攻城要打对方的城。局面没有变。")
		return
	var attack := dst_faction != "明"
	if _pick == "march":
		attack = false
	elif _pick == "attack":
		attack = true
	if attack:
		var preview: Dictionary = Campaign.preview_battle(_selected_id, city_id)
		if not bool(preview.get("ok", false)):
			_show_note(str(preview.get("message", "攻不了。")))
			return
		_pick = ""
		_open_battle(_selected_id, city_id, preview)
		return
	var marched: Dictionary = Campaign.march(_selected_id, city_id)
	_show_note(str(marched.get("message", "")))
	if bool(marched.get("ok", false)):
		_pick = ""
		Campaign.guide_note_action()
		_refresh()


func _on_map_blank(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clear_selection()
		_show_note("已取消选择。")


func _clear_selection() -> void:
	_selected_id = ""
	_pick = ""
	_refresh()


func _on_march_mode() -> void:
	if bool(_seals["march"]["button"].disabled):
		return
	_pick = "march"
	_show_note("行军：再点一座相邻的我方城。")
	_refresh_markers()
	_refresh_popup()


func _on_attack_mode() -> void:
	if bool(_seals["attack"]["button"].disabled):
		return
	_pick = "attack"
	_show_note("攻城：再点一座相邻的敌城。")
	_refresh_markers()
	_refresh_popup()


func _on_hold() -> void:
	if _selected_id == "":
		_show_note("先点一座我方的城。")
		return
	var result: Dictionary = Campaign.hold(_selected_id)
	_show_note(str(result.get("message", "")))
	if bool(result.get("ok", false)):
		_pick = ""
		Campaign.guide_note_action()
	_refresh()


func _on_civil(kind: String) -> void:
	if _in_battle:
		_show_note("战斗进行中，先看完这一仗。")
		return
	var result: Dictionary = Campaign.civil(kind, _selected_id)
	_show_note(str(result.get("message", "")))
	_refresh()


func _on_end_turn() -> void:
	if _turn_busy or _in_battle:
		_show_note("战斗进行中，先看完这一仗。" if _in_battle else "这一回合正在结算。")
		return
	if Time.get_ticks_msec() < _end_locked_until:
		return
	_turn_busy = true
	var result: Dictionary = Campaign.end_turn()
	_pick = ""
	_refresh()
	if not bool(result.get("ok", false)):
		_show_note(str(result.get("message", "")))
		_turn_busy = false
		return
	_end_locked_until = Time.get_ticks_msec() + 450
	_finish_turn(result)
	_turn_busy = false


func _finish_turn(result: Dictionary) -> void:
	Campaign.guide_note_end()
	var where := str(result.get("goto", "map"))
	if where == "s1" or where == "s2" or where == "s3":
		Campaign.save_game()
		_open_story(where)
		return
	if where == "ending":
		_open_ending()
		return
	_refresh()


func _on_help() -> void:
	_advisor_panel.visible = true
	_fill_advisor()
	_layout_advisor()
	_refresh_guide()


func _fill_advisor() -> void:
	if _advisor_list == null or not _advisor_panel.visible:
		_layout_advisor()
		return
	for child in _advisor_list.get_children():
		_advisor_list.remove_child(child)
		child.queue_free()
	var recs: Array = AdvisorScript.recommend(Campaign)
	if recs.is_empty():
		var empty := UiKit.label("现在没有可推荐的行动。", UiKit.sans, 15, UiKit.CREAM)
		_advisor_list.add_child(empty)
		_layout_advisor()
		return
	var index := 0
	for action in recs:
		_advisor_list.add_child(_advisor_row(index, action))
		index += 1
	_layout_advisor()


func _advisor_row(index: int, action: Dictionary) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.custom_minimum_size = Vector2(446, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", _row_style("row_recommend_normal.png"))
	button.add_theme_stylebox_override("hover", _row_style("row_recommend_hover.png"))
	button.add_theme_stylebox_override("pressed", _row_style("row_recommend_pressed.png"))
	button.add_theme_stylebox_override("disabled", _row_style("row_recommend_disabled.png"))
	button.add_theme_stylebox_override("focus", _row_style("row_recommend_selected.png"))
	button.add_theme_stylebox_override("hover_pressed", _row_style("row_recommend_selected.png"))
	button.disabled = not bool(action.get("executable", true))
	var reason_text := str(action.get("reason", ""))
	button.tooltip_text = "%s\n%s" % [str(action.get("title", "")), reason_text]
	button.pressed.connect(_on_advisor_pick.bind(action))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 0
	row.offset_right = -8
	row.offset_bottom = 0
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(row)
	var bubble := Control.new()
	bubble.custom_minimum_size = Vector2(26, 26)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bubble)
	var bubble_tex := TextureRect.new()
	bubble_tex.texture = UiKit.tex("bubble_step.png")
	bubble_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bubble_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(bubble_tex)
	var num := UiKit.label(str(index + 1), UiKit.serif, 14, UiKit.INK)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble.add_child(num)
	var title := UiKit.label(str(action.get("title", "")), UiKit.serif, 16, UiKit.CREAM)
	title.custom_minimum_size = Vector2(0, 28)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var reason := UiKit.label(reason_text, UiKit.sans, 13, Color(0.86, 0.8, 0.7))
	reason.clip_text = true
	reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason.custom_minimum_size = Vector2(40, 28)
	reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reason)
	return button


func _row_style(file_name: String) -> StyleBoxTexture:
	var box := UiKit.style_tex(file_name, 6, 0)
	box.content_margin_left = 0
	box.content_margin_top = 0
	box.content_margin_right = 0
	box.content_margin_bottom = 0
	return box


func _on_advisor_pick(action: Dictionary) -> void:
	if _advisor_lock:
		return
	_advisor_lock = true
	var kind := str(action.get("kind", ""))
	if kind == "attack":
		var preview: Dictionary = Campaign.preview_battle(str(action.get("src", "")), str(action.get("dst", "")))
		if not bool(preview.get("ok", false)):
			_show_note(str(preview.get("message", "")))
			_advisor_lock = false
			return
		_selected_id = str(action.get("src", _selected_id))
		_open_battle(str(action.get("src", "")), str(action.get("dst", "")), preview)
		_advisor_lock = false
		return
	if kind == "end_turn":
		_advisor_lock = false
		_on_end_turn()
		return
	var result: Dictionary = AdvisorScript.execute(Campaign, action)
	_show_note(str(result.get("message", "")))
	if bool(result.get("ok", false)) and (kind == "march" or kind == "hold"):
		Campaign.guide_note_action()
		_pick = ""
	_refresh()
	_advisor_lock = false


func _on_save() -> void:
	if Campaign.pending_story != "":
		_show_note("剧情进行中不能存档。进剧情前已经自动存过。")
		return
	var result: Dictionary = Campaign.save_game()
	_show_note(str(result.get("message", "")))


func _on_load() -> void:
	var result: Dictionary = Campaign.load_game()
	_show_note(str(result.get("message", "")))
	if not bool(result.get("ok", false)):
		return
	_selected_id = ""
	_pick = ""
	if Campaign.pending_story != "":
		_open_story(Campaign.pending_story)
		return
	if Campaign.settled and Campaign.ending_id != "":
		_open_ending()
		return
	_refresh()


func _on_new_game() -> void:
	Campaign.reset()
	_selected_id = ""
	_pick = ""
	if _battle != null:
		_battle.hide()
	_in_battle = false
	Bgm.set_mode("map")
	_refresh()
	_show_note("新的一局。旧档还在，要读才会回来。")


func _on_volume(value: float) -> void:
	Bgm.set_master_linear(value)


func _on_mute() -> void:
	Bgm.toggle_muted()
	_refresh()


func _open_story(which: String) -> void:
	var path := "res://scenes/s1_night.tscn"
	if which == "s2":
		path = "res://scenes/s2_yuan.tscn"
	elif which == "s3":
		path = "res://scenes/s3_crisis.tscn"
	Bgm.set_mode("story")
	get_tree().change_scene_to_file(path)


func _open_ending() -> void:
	Bgm.set_mode("ending")
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


func present_battle(src_id: String, dst_id: String, info: Dictionary, resolved: bool, progress: float = 0.45) -> void:
	_battle_src = src_id
	_battle_dst = dst_id
	_battle_done = resolved
	_in_battle = true
	_fill_battle(info, resolved)
	_set_battle_progress(1.0 if resolved else progress)
	_battle.show()
	_layout_battle()
	_refresh()


func _open_battle(src_id: String, dst_id: String, preview: Dictionary) -> void:
	if _battle_tween != null and _battle_tween.is_valid():
		_battle_tween.kill()
	present_battle(src_id, dst_id, preview, false, 0.02)
	Bgm.set_mode("battle")
	_battle_tween = create_tween()
	_battle_tween.tween_method(_set_battle_progress, 0.02, 1.0, 1.2)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(_commit_battle)


func _commit_battle() -> void:
	if _battle_done:
		return
	_battle_done = true
	var result: Dictionary = Campaign.commit_player_battle(_battle_src, _battle_dst)
	_fill_battle(result, true)
	if bool(result.get("ok", false)):
		Campaign.guide_note_action()
	_refresh()


func _fill_battle(info: Dictionary, resolved: bool) -> void:
	var ok := bool(info.get("ok", false))
	_battle_columns.visible = ok
	_battle_error.visible = not ok
	_battle_skip.visible = ok and not resolved
	_battle_close.visible = (not ok) or resolved
	_vs.visible = ok and not resolved
	_stamp.visible = ok and resolved
	_result.visible = ok and resolved
	_progress_box.visible = ok and not resolved
	if not ok:
		_battle_error.text = str(info.get("message", ""))
		return
	var src_show := int(info.get("src_show", int(info["sent"]) + 1))
	var dst_show := int(info.get("dst_show", int(info["defender"])))
	_atk_name.text = str(info["src_name"])
	_def_name.text = str(info["dst_name"])
	_atk_role.text = "攻方"
	_def_role.text = "守军"
	_atk_num.text = str(src_show)
	_def_num.text = str(dst_show)
	_atk_extra.visible = true
	_def_extra.visible = true
	_def_extra.text = ""
	if int(info["sent"]) != src_show:
		_atk_extra.text = "出兵 %d" % int(info["sent"])
	else:
		_atk_extra.text = ""
	_atk_mod.text = "袁部 ×1.25" if bool(info["yuan_bonus"]) else "×1.00"
	var terrain := "地形 ×%s" % _fmt_mul(int(info["terrain_pct"]))
	if bool(info["held"]):
		terrain += " · 固守 ×1.30"
	_def_mod.text = terrain
	_atk_power.text = "有效兵力 %s" % _fmt_power(int(info["atk_x100"]))
	_def_power.text = "有效兵力 %s" % _fmt_power(int(info["def_x100"]))
	var src_kind := _badge_kind(_battle_src, str(info.get("src_kind", "")))
	var dst_kind := _badge_kind(_battle_dst, str(info.get("dst_kind", "")))
	_atk_badge.texture = UiKit.tex("city_badge_%s_normal.png" % src_kind)
	_def_badge.texture = UiKit.tex("city_badge_%s_normal.png" % dst_kind)
	if resolved:
		var outcome := str(info.get("outcome", "draw"))
		var line := "平 · 两损"
		var color := UiKit.CREAM
		if outcome == "win":
			line = "胜 · 占城"
			color = UiKit.GOLD
		elif outcome == "lose":
			line = "负 · 退回"
			color = Color("c9d7ea")
		_result.text = line
		_result.add_theme_color_override("font_color", color)
		if outcome == "win" or outcome == "lose" or outcome == "draw":
			_stamp.texture = UiKit.tex("stamp_%s.png" % outcome)


func _fmt_power(x100: int) -> String:
	var value := float(x100) / 100.0
	if x100 % 100 == 0 or x100 % 10 == 0:
		return "%.1f" % value
	return "%.2f" % value


func _fmt_mul(pct: int) -> String:
	return "%.2f" % (float(pct) / 100.0)


func _badge_kind(city_id: String, override: String) -> String:
	if override != "":
		return override
	var owner := Campaign.display_owner(city_id)
	if owner == "明":
		return "ming"
	if owner == "争议":
		return "contested"
	if owner == "":
		return "ming"
	return "jin"


func _set_battle_progress(value: float) -> void:
	if _battle_fill == null or _battle_track == null:
		return
	var ratio := clampf(value, 0.0, 1.0)
	var width := _battle_track.size.x
	if width < 8.0:
		width = _battle_track.custom_minimum_size.x
	_battle_fill.anchor_right = 0.0
	_battle_fill.offset_left = 0.0
	_battle_fill.offset_right = width * ratio


func _build_battle() -> void:
	_battle = Control.new()
	_battle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle.visible = false
	_battle.z_index = 20
	add_child(_battle)
	var bg := TextureRect.new()
	bg.texture = UiKit.tex("bg_battle_banners.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.add_child(bg)
	_battle_frame = UiKit.nine("panel_frame_l.png", 26)
	_battle_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.add_child(_battle_frame)
	_battle_title_plate = UiKit.nine("panel_frame_m.png", 20)
	_battle.add_child(_battle_title_plate)
	var title := UiKit.label("简战", UiKit.serif, 28, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_title_plate.add_child(title)
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 48
	content.offset_top = 36
	content.offset_right = -48
	content.offset_bottom = -78
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_frame.add_child(content)
	_battle_error = UiKit.label("", UiKit.sans, 18, UiKit.CREAM)
	_battle_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_battle_error)
	_battle_columns = HBoxContainer.new()
	_battle_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_battle_columns.add_theme_constant_override("separation", 12)
	content.add_child(_battle_columns)
	var atk := _battle_column(true)
	var center := _battle_center()
	var defense := _battle_column(false)
	_battle_columns.add_child(atk)
	_battle_columns.add_child(center)
	_battle_columns.add_child(defense)
	var button_row := CenterContainer.new()
	content.add_child(button_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	button_row.add_child(buttons)
	_battle_skip = UiKit.painted_button("跳过演出", false, 200)
	_battle_skip.pressed.connect(_commit_battle)
	buttons.add_child(_battle_skip)
	_battle_close = UiKit.painted_button("返回大地图", true, 220)
	_battle_close.pressed.connect(_close_battle)
	buttons.add_child(_battle_close)


func _battle_column(attacker: bool) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := UiKit.label("", UiKit.serif, 28, UiKit.GOLD)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(160, 36)
	box.add_child(name)
	var role := UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role.custom_minimum_size = Vector2(160, 22)
	box.add_child(role)
	# 切图有效圆 84/104。放到 164，画面上的城印直径约 132。
	var holder_wrap := CenterContainer.new()
	holder_wrap.custom_minimum_size = Vector2(164, 164)
	holder_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder_wrap)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(164, 164)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder_wrap.add_child(holder)
	var badge := TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2.ZERO
	badge.size = Vector2(164, 164)
	holder.add_child(badge)
	var num := UiKit.label("", UiKit.serif, 36, UiKit.CREAM)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.position = Vector2(16, 54)
	num.size = Vector2(132, 56)
	UiKit.outline(num, 4)
	holder.add_child(num)
	var extra := UiKit.label("", UiKit.sans, 15, UiKit.CREAM)
	extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	extra.custom_minimum_size = Vector2(140, 22)
	box.add_child(extra)
	var mod := UiKit.label("", UiKit.sans, 16, UiKit.GOLD)
	mod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mod.custom_minimum_size = Vector2(160, 22)
	box.add_child(mod)
	var power := UiKit.label("", UiKit.serif, 18, UiKit.CREAM)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power.custom_minimum_size = Vector2(160, 24)
	box.add_child(power)
	if attacker:
		_atk_name = name
		_atk_role = role
		_atk_badge = badge
		_atk_num = num
		_atk_extra = extra
		_atk_mod = mod
		_atk_power = power
	else:
		_def_name = name
		_def_role = role
		_def_badge = badge
		_def_num = num
		_def_extra = extra
		_def_mod = mod
		_def_power = power
	return box


func _battle_center() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var stage := CenterContainer.new()
	stage.custom_minimum_size = Vector2(180, 160)
	box.add_child(stage)
	_vs = UiKit.label("VS", UiKit.serif, 48, UiKit.GOLD)
	stage.add_child(_vs)
	_stamp = TextureRect.new()
	_stamp.custom_minimum_size = Vector2(160, 160)
	_stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_stamp)
	_result = UiKit.label("", UiKit.serif, 26, UiKit.GOLD)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result)
	_progress_box = VBoxContainer.new()
	_progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress_box.add_theme_constant_override("separation", 6)
	box.add_child(_progress_box)
	_battle_track = UiKit.nine("bar_bg.png", 6, 0, 6, 0)
	_battle_track.custom_minimum_size = Vector2(240, 14)
	_progress_box.add_child(_battle_track)
	_battle_fill = UiKit.nine("bar_fill_gold.png", 6, 0, 6, 0)
	_battle_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_fill.offset_top = 1
	_battle_fill.offset_bottom = -1
	_battle_fill.anchor_right = 0.05
	_battle_track.add_child(_battle_fill)
	var fighting := UiKit.label("交战中……", UiKit.sans, 16, UiKit.CREAM)
	fighting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_box.add_child(fighting)
	return box


func _layout_battle() -> void:
	if _battle_frame == null or not _battle.visible:
		return
	var frame := Vector2(minf(1040, size.x - 48), minf(560, size.y - 36))
	var origin := (size - frame) * 0.5
	_battle_frame.position = origin
	_battle_frame.size = frame
	_battle_title_plate.position = origin + Vector2(frame.x * 0.5 - 90, -18)
	_battle_title_plate.size = Vector2(180, 50)


func _close_battle() -> void:
	if _battle_tween != null and _battle_tween.is_valid():
		_battle_tween.kill()
	_battle.hide()
	_in_battle = false
	if Bgm.mode == "battle":
		Bgm.set_mode("map")
	_refresh()


func _build_credits() -> void:
	_credits = Control.new()
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits.visible = false
	_credits.z_index = 30
	add_child(_credits)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_credits.add_child(dim)
	var frame := UiKit.nine("panel_frame_l.png", 26)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -360
	frame.offset_top = -250
	frame.offset_right = 360
	frame.offset_bottom = 250
	_credits.add_child(frame)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 36
	box.offset_top = 28
	box.offset_right = -36
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	var title := UiKit.label("署名", UiKit.serif, 32, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.text = "音乐（页面标明 CC0）\n地图 Lotus Pond — BiteMe Games\n简战 Dragon Dance — BiteMe Games\n剧情 Orien — Tozan（OpenGameArt）\n结局 Floating Lanterns — John Bartmann（Free Music Archive）\n\n字体：Noto Serif / Sans CJK SC（SIL OFL 1.1）。缺字回退文泉驿微米黑（Apache-2.0）。\n美术：AI 辅助生成（Grok Bot，2026-10-15），后期由 Alice 处理。"
	box.add_child(body)
	var close := UiKit.painted_button("关闭", false, 160)
	close.pressed.connect(func() -> void: _credits.hide())
	box.add_child(close)


func _on_credits() -> void:
	_credits.show()


func _march_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.main_done:
		return {"on": false, "why": "这个回合的主行动已经用过"}
	if _selected_id == "" or str(Campaign.city(_selected_id)["faction"]) != "明":
		return {"on": false, "why": "先点一座我方的城"}
	if int(Campaign.city(_selected_id)["troops"]) < 2:
		return {"on": false, "why": "兵力不足，至少留 1 人守城"}
	var near := false
	var far_only := false
	for hop in Campaign.neighbors_of(_selected_id):
		if str(Campaign.city(str(hop["id"]))["faction"]) != "明":
			continue
		near = true
		if bool(hop["far"]):
			far_only = true
		else:
			far_only = false
			break
	if not near:
		return {"on": false, "why": "没有相邻的我方城"}
	var cost := Baseline.MARCH_GRAIN_FAR if far_only else Baseline.MARCH_GRAIN
	if Campaign.grain < cost:
		return {"on": false, "why": "粮草不足（需要 %d）" % cost}
	return {"on": true, "why": "再点相邻我方城。近邻耗粮 %d，远邻耗粮 %d。" % [Baseline.MARCH_GRAIN, Baseline.MARCH_GRAIN_FAR]}


func _attack_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.main_done:
		return {"on": false, "why": "这个回合的主行动已经用过"}
	if _selected_id == "" or str(Campaign.city(_selected_id)["faction"]) != "明":
		return {"on": false, "why": "先点一座我方的城"}
	if int(Campaign.city(_selected_id)["troops"]) < 2:
		return {"on": false, "why": "兵力不足，出不了兵"}
	var any_enemy := false
	for hop in Campaign.neighbors_of(_selected_id):
		if str(Campaign.city(str(hop["id"]))["faction"]) != "明":
			any_enemy = true
			break
	if not any_enemy:
		return {"on": false, "why": "旁边没有可打的城"}
	return {"on": true, "why": "再点相邻的敌城。打不打得过，开战前会先算给你看。"}


func _hold_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.main_done:
		return {"on": false, "why": "这个回合的主行动已经用过"}
	if _selected_id == "" or str(Campaign.city(_selected_id)["faction"]) != "明":
		return {"on": false, "why": "先点一座我方的城"}
	return {"on": true, "why": "这城本回合更难被打下，人不移动。"}


func _levy_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.civil_done:
		return {"on": false, "why": "这个回合的内政已经做过"}
	return {"on": true, "why": "粮草 +%d，民心 -%d。" % [Baseline.LEVY_GRAIN, Baseline.LEVY_MORALE]}


func _spend_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.civil_done:
		return {"on": false, "why": "这个回合的内政已经做过"}
	if Campaign.silver < Baseline.SPEND_SILVER:
		return {"on": false, "why": "银两不足（需要 %d）" % Baseline.SPEND_SILVER}
	return {"on": true, "why": "银两 -%d，民心 +%d。" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE]}


func _train_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中"}
	if Campaign.settled or Campaign.civil_done:
		return {"on": false, "why": "这个回合的内政已经做过"}
	if _selected_id == "" or str(Campaign.city(_selected_id)["faction"]) != "明":
		return {"on": false, "why": "请先选中己方城池"}
	if Campaign.silver < Baseline.TRAIN_SILVER or Campaign.grain < Baseline.TRAIN_GRAIN:
		return {"on": false, "why": "需要银 %d、粮 %d" % [Baseline.TRAIN_SILVER, Baseline.TRAIN_GRAIN]}
	return {"on": true, "why": "这城兵力 +%d。" % Baseline.TRAIN_TROOPS}


func _end_state() -> Dictionary:
	if _in_battle:
		return {"on": false, "why": "战斗进行中，先看完这一仗"}
	if Campaign.settled:
		return {"on": false, "why": "这局已经结束"}
	if not Campaign.main_done:
		return {"on": false, "why": "先完成主行动：行军、攻城或固守"}
	return {"on": true, "why": "点下去，这一回合才算过完。"}


func _show_note(text: String) -> void:
	_log.text = text


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	track.set_corner_radius_all(3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.GOLD
	fill.set_corner_radius_all(3)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			if Vector2(x, y).distance_to(Vector2(7.5, 7.5)) <= 6.5:
				image.set_pixel(x, y, UiKit.CREAM)
	var grab := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber", grab)
	slider.add_theme_icon_override("grabber_highlight", grab)
	slider.add_theme_icon_override("grabber_disabled", grab)
