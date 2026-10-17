extends Control
## v0.3 大地图。规则仍在 Campaign。这里只改怎么点：先点我方城，再点目标，行军或攻城自动判。

const Baseline := preload("res://data/campaign_baseline.gd")
const AdvisorScript := preload("res://scripts/advisor.gd")
const _TOKEN := preload("res://scripts/city_token.gd")
const _ICON := preload("res://scripts/card_icon.gd")
const _TOKEN_SIZE := Vector2(108, 86)

const _INK := Color(0.17, 0.09, 0.06)
const _PAPER := Color(0.95, 0.91, 0.82)
const _CREAM := Color(0.98, 0.95, 0.88)
const _CARMINE := Color(0.58, 0.12, 0.1)
const _GOLD := Color(0.78, 0.62, 0.32)
const _MUTED := Color(0.38, 0.26, 0.16)

var _selected_id := ""
var _pick := ""
var _markers: Dictionary = {}
var _in_battle := false
var _turn_busy := false
var _end_locked_until := 0
var _advisor_lock := false

var _hint: Label
var _log: Label
var _turn: Label
var _stats: Label
var _yuan_line: Label
var _popup: PanelContainer
var _popup_title: Label
var _march_button: Button
var _march_reason: Label
var _attack_button: Button
var _attack_reason: Label
var _hold_button: Button
var _hold_reason: Label
var _end_button: Button
var _end_reason: Label
var _cards: Dictionary = {}
var _city_layer: Control
var _map_host: Control
var _help_button: Button
var _advisor_panel: PanelContainer
var _advisor_list: VBoxContainer
var _guide: Control
var _guide_text: Label
var _guide_target: Control
var _battle: Control
var _battle_title: Label
var _battle_body: Label
var _battle_skip: Button
var _battle_close: Button
var _battle_src := ""
var _battle_dst := ""
var _battle_done := false
var _credits: Control
var _mute_button: Button
var _volume: HSlider


func _ready() -> void:
	_install_font_fallback()
	_build_ui()
	_build_markers()
	_build_battle()
	_build_credits()
	_city_layer.resized.connect(_position_markers)
	resized.connect(_position_markers)
	_position_markers.call_deferred()
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


func _install_font_fallback() -> void:
	var font := get_theme_default_font()
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.16, 0.08, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_build_top())
	column.add_child(_build_hint())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	body.add_child(_build_map_column())
	body.add_child(_build_side())
	_build_guide()


func _build_top() -> Control:
	var bar := PanelContainer.new()
	_paint(bar, Color(0.36, 0.1, 0.08), _GOLD, 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var title := Label.new()
	title.text = "改命：天下"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.74))
	row.add_child(title)
	_stats = Label.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.clip_text = true
	_stats.add_theme_font_size_override("font_size", 15)
	_stats.add_theme_color_override("font_color", _PAPER)
	_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stats)
	_turn = Label.new()
	_turn.add_theme_font_size_override("font_size", 18)
	_turn.add_theme_color_override("font_color", _GOLD)
	row.add_child(_turn)
	var volume_name := Label.new()
	volume_name.text = "音量"
	volume_name.add_theme_color_override("font_color", _PAPER)
	row.add_child(volume_name)
	_volume = HSlider.new()
	_volume.custom_minimum_size = Vector2(110, 0)
	_volume.min_value = 0
	_volume.max_value = 1
	_volume.step = 0.01
	_volume.value = Bgm.master_linear
	_volume.tooltip_text = "音量。拉到最左就是静音。"
	_volume.value_changed.connect(_on_volume)
	row.add_child(_volume)
	_mute_button = Button.new()
	_mute_button.text = "静音"
	_mute_button.pressed.connect(_on_mute)
	row.add_child(_mute_button)
	return bar


func _build_hint() -> Control:
	var panel := PanelContainer.new()
	_paint(panel, _PAPER, Color(0.45, 0.28, 0.14), 2)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", _INK)
	panel.add_child(_hint)
	return panel


func _build_map_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 2.4
	column.add_theme_constant_override("separation", 8)
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paint(map_panel, Color(0.55, 0.42, 0.28), Color(0.28, 0.16, 0.1), 3)
	column.add_child(map_panel)
	var host := Control.new()
	host.custom_minimum_size = Vector2(560, 320)
	host.clip_contents = true
	host.resized.connect(_layout_overlays)
	map_panel.add_child(host)
	_map_host = host
	var canvas := Control.new()
	canvas.set_script(load("res://scripts/map_canvas.gd"))
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(canvas)
	_city_layer = Control.new()
	_city_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_city_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_city_layer.gui_input.connect(_on_map_blank)
	host.add_child(_city_layer)
	var help := Button.new()
	help.name = "HelpButton"
	help.text = "帮我选"
	help.focus_mode = Control.FOCUS_NONE
	help.custom_minimum_size = Vector2(92, 92)
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", _INK)
	_round_button(help)
	help.pressed.connect(_on_help)
	host.add_child(help)
	_help_button = help
	_advisor_panel = PanelContainer.new()
	_advisor_panel.visible = false
	_advisor_panel.custom_minimum_size = Vector2(340, 0)
	_paint(_advisor_panel, _CREAM, _CARMINE, 2)
	host.add_child(_advisor_panel)
	var advisor_box := VBoxContainer.new()
	advisor_box.add_theme_constant_override("separation", 6)
	_advisor_panel.add_child(advisor_box)
	var advisor_head := HBoxContainer.new()
	advisor_box.add_child(advisor_head)
	var advisor_title := Label.new()
	advisor_title.text = "可以这样走"
	advisor_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advisor_title.add_theme_font_size_override("font_size", 18)
	advisor_title.add_theme_color_override("font_color", _CARMINE)
	advisor_head.add_child(advisor_title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: _advisor_panel.hide())
	advisor_head.add_child(close)
	_advisor_list = VBoxContainer.new()
	_advisor_list.add_theme_constant_override("separation", 4)
	advisor_box.add_child(_advisor_list)
	_popup = PanelContainer.new()
	_popup.visible = false
	_paint(_popup, _CREAM, _GOLD, 2)
	column.add_child(_popup)
	var pop_box := VBoxContainer.new()
	pop_box.add_theme_constant_override("separation", 6)
	_popup.add_child(pop_box)
	_popup_title = Label.new()
	_popup_title.add_theme_font_size_override("font_size", 18)
	_popup_title.add_theme_color_override("font_color", _INK)
	pop_box.add_child(_popup_title)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	pop_box.add_child(actions)
	var march := _action_slot("行军")
	var attack := _action_slot("攻城")
	var hold := _action_slot("固守")
	_march_button = march["button"]
	_march_reason = march["reason"]
	_attack_button = attack["button"]
	_attack_reason = attack["reason"]
	_hold_button = hold["button"]
	_hold_reason = hold["reason"]
	actions.add_child(march["root"])
	actions.add_child(attack["root"])
	actions.add_child(hold["root"])
	_march_button.pressed.connect(_on_march_mode)
	_attack_button.pressed.connect(_on_attack_mode)
	_hold_button.pressed.connect(_on_hold)
	return column


func _action_slot(title: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 18)
	box.add_child(button)
	var reason := Label.new()
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.custom_minimum_size = Vector2(0, 36)
	reason.add_theme_font_size_override("font_size", 13)
	box.add_child(reason)
	return {"root": box, "button": button, "reason": reason}


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	for spec in [
		["levy", "征粮", "粮草 +%d，民心 -%d" % [Baseline.LEVY_GRAIN, Baseline.LEVY_MORALE]],
		["spend", "发帑", "银两 -%d，民心 +%d" % [Baseline.SPEND_SILVER, Baseline.SPEND_MORALE]],
		["train", "练兵", "银两 -%d，粮草 -%d，兵力 +%d" % [Baseline.TRAIN_SILVER, Baseline.TRAIN_GRAIN, Baseline.TRAIN_TROOPS]],
	]:
		side.add_child(_make_card(str(spec[0]), str(spec[1]), str(spec[2])))
	_yuan_line = Label.new()
	_yuan_line.add_theme_color_override("font_color", Color(0.93, 0.86, 0.7))
	_yuan_line.add_theme_font_size_override("font_size", 13)
	side.add_child(_yuan_line)
	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(0, 48)
	_log.add_theme_font_size_override("font_size", 14)
	_log.add_theme_color_override("font_color", Color(0.96, 0.9, 0.74))
	side.add_child(_log)
	var saves := HBoxContainer.new()
	saves.add_theme_constant_override("separation", 6)
	side.add_child(saves)
	for pair in [["存档", _on_save], ["读档", _on_load], ["新局", _on_new_game], ["署名", _on_credits]]:
		var button := Button.new()
		button.text = str(pair[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(pair[1])
		saves.add_child(button)
	_end_button = Button.new()
	_end_button.text = "下一回合"
	_end_button.custom_minimum_size = Vector2(0, 72)
	_end_button.add_theme_font_size_override("font_size", 28)
	_end_button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	_end_button.add_theme_color_override("font_disabled_color", Color(0.85, 0.8, 0.74))
	_style_end(_end_button)
	_end_button.pressed.connect(_on_end_turn)
	side.add_child(_end_button)
	_end_reason = Label.new()
	_end_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_reason.add_theme_font_size_override("font_size", 13)
	side.add_child(_end_reason)
	return side


func _make_card(kind: String, title: String, detail: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 78)
	_paint(panel, _CREAM, Color(0.45, 0.22, 0.14), 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon := Control.new()
	icon.set_script(_ICON)
	icon.kind = kind
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(_on_civil.bind(kind))
	text.add_child(button)
	var sub := Label.new()
	sub.text = detail
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", _MUTED)
	text.add_child(sub)
	var reason := Label.new()
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_theme_font_size_override("font_size", 13)
	text.add_child(reason)
	_cards[kind] = {"button": button, "reason": reason, "panel": panel}
	return panel


func _build_guide() -> void:
	_guide = Control.new()
	_guide.set_script(load("res://scripts/guide_overlay.gd"))
	_guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)
	var bubble := PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint(bubble, Color(0.99, 0.96, 0.86), _CARMINE, 2)
	_guide.add_child(bubble)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(box)
	_guide_text = Label.new()
	_guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_text.custom_minimum_size = Vector2(280, 0)
	_guide_text.add_theme_font_size_override("font_size", 20)
	_guide_text.add_theme_color_override("font_color", _INK)
	_guide_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_guide_text)
	var skip := Button.new()
	skip.text = "跳过引导"
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.pressed.connect(_on_skip_guide)
	box.add_child(skip)


func _on_skip_guide() -> void:
	Campaign.guide_skip()
	_guide.visible = false
	_guide.set_process(false)
	_show_note("引导已跳过。以后开新局也不会再出现。")


func _build_markers() -> void:
	for city in Baseline.CITIES:
		var city_id := str(city["id"])
		var button := Button.new()
		button.set_script(_TOKEN)
		button.custom_minimum_size = _TOKEN_SIZE
		button.size = _TOKEN_SIZE
		button.pressed.connect(_on_city_pressed.bind(city_id))
		_city_layer.add_child(button)
		_markers[city_id] = button


func _position_markers() -> void:
	if _city_layer == null:
		return
	var sz: Vector2 = _city_layer.size
	if sz.x < 40.0 or sz.y < 40.0:
		return
	for city_id in _markers:
		var city := Baseline.city_by_id(str(city_id))
		var button := _markers[city_id] as Control
		var pos: Vector2 = city["pos"]
		button.size = _TOKEN_SIZE
		button.position = pos * sz - _TOKEN_SIZE * 0.5
	_refresh_guide()
	_layout_overlays()


func _refresh() -> void:
	_stats.text = "银两 %d    粮草 %d    民心 %d    辽东 %d    压力 %d    世界线 %d" % [
		Campaign.silver, Campaign.grain, Campaign.morale, Campaign.liaodong, Campaign.pressure, Campaign.worldline
	]
	var turn_text := "第 %d / %d 回合" % [Campaign.turn, Baseline.TURN_LIMIT]
	if Campaign.settled:
		turn_text += " · 已结束"
	_turn.text = turn_text
	_yuan_line.text = "袁崇焕 %s　结交 %s　勤王 %s" % [
		Campaign.yuan_status,
		"是" if Campaign.befriended_yuan else "否",
		"成功" if Campaign.loyalist_success else "否",
	]
	_log.text = Campaign.log_text
	_hint.text = _next_hint()
	_mute_button.text = "取消静音" if Bgm.muted else "静音"
	_refresh_markers()
	_refresh_popup()
	_refresh_cards()
	_refresh_end()
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


func _refresh_popup() -> void:
	var show := _selected_id != "" and str(Campaign.city(_selected_id).get("faction", "")) == "明" and not _in_battle
	_popup.visible = show
	if not show:
		return
	var info := Campaign.city(_selected_id)
	_popup_title.text = "已选 %s · %s · 兵力 %d%s" % [
		info["name"],
		Campaign.display_owner(_selected_id),
		int(info["troops"]),
		" · 袁在这里" if Campaign.yuan_city == _selected_id else "",
	]
	_apply_state(_march_button, _march_reason, _march_state())
	_apply_state(_attack_button, _attack_reason, _attack_state())
	_apply_state(_hold_button, _hold_reason, _hold_state())


func _refresh_cards() -> void:
	_apply_state(_cards["levy"]["button"], _cards["levy"]["reason"], _levy_state())
	_apply_state(_cards["spend"]["button"], _cards["spend"]["reason"], _spend_state())
	_apply_state(_cards["train"]["button"], _cards["train"]["reason"], _train_state())


func _refresh_end() -> void:
	_apply_state(_end_button, _end_reason, _end_state())


func _refresh_guide() -> void:
	if Campaign.guide_done:
		_guide.visible = false
		_guide_target = null
		return
	_guide.visible = true
	_guide.set_process(true)
	var line := "先点一座亮着的城，那是你的人。"
	_guide_target = _suggest_city()
	if Campaign.guide_step == 1:
		line = "再选一个行动。点旁边的城，会自己判断是行军还是攻城。"
		_guide_target = _popup if _popup.visible else _suggest_city()
	elif Campaign.guide_step >= 2:
		line = "做完就点右下角红色的「下一回合」。"
		_guide_target = _end_button
	_guide_text.text = line
	_guide.target = _guide_target
	var bubble := _guide.get_node("Bubble") as Control
	var rect := Rect2()
	if _guide_target != null and is_instance_valid(_guide_target):
		rect = _guide_target.get_global_rect()
	var origin := Vector2(rect.position.x + rect.size.x + 12, rect.position.y)
	if origin.x + 320 > size.x:
		origin.x = maxf(12, rect.position.x - 320)
	if origin.y + 110 > size.y:
		origin.y = maxf(12, size.y - 120)
	bubble.position = origin - _guide.global_position
	bubble.reset_size()


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
	_advisor_panel.hide()
	_refresh()


func _on_march_mode() -> void:
	if _march_button.disabled:
		return
	_pick = "march"
	_show_note("行军：再点一座相邻的我方城。")
	_refresh_markers()


func _on_attack_mode() -> void:
	if _attack_button.disabled:
		return
	_pick = "attack"
	_show_note("攻城：再点一座相邻的敌城。")
	_refresh_markers()


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
	# 双击会在几百毫秒里送来第二次。只让第一次推进回合。
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
	# 只打开清单，不执行。连点也不会扣资源。
	_advisor_panel.visible = true
	_fill_advisor()


func _layout_overlays() -> void:
	if _map_host == null or _help_button == null:
		return
	var h := _map_host.size.y
	var w := _map_host.size.x
	if h < 40.0:
		return
	_help_button.size = Vector2(92, 92)
	_help_button.position = Vector2(14, h - 106)
	if not _advisor_panel.visible:
		return
	var width := minf(380.0, maxf(260.0, w - 130.0))
	var ph := _advisor_panel.get_combined_minimum_size().y
	if ph < 40.0:
		ph = 180.0
	ph = minf(ph, h - 28.0)
	_advisor_panel.size = Vector2(width, ph)
	_advisor_panel.position = Vector2(118, maxf(8.0, h - 14.0 - ph))


func _fill_advisor() -> void:
	for child in _advisor_list.get_children():
		child.queue_free()
	var recs: Array = AdvisorScript.recommend(Campaign)
	if recs.is_empty():
		var empty := Label.new()
		empty.text = "现在没有可推荐的行动。"
		_advisor_list.add_child(empty)
		return
	for action in recs:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(320, 52)
		var title := str(action.get("title", ""))
		var reason := str(action.get("reason", ""))
		button.text = "%s\n%s" % [title, reason]
		button.disabled = not bool(action.get("executable", true))
		if button.disabled:
			button.tooltip_text = reason
		button.pressed.connect(_on_advisor_pick.bind(action))
		_advisor_list.add_child(button)
	_layout_overlays.call_deferred()


func _on_advisor_pick(action: Dictionary) -> void:
	if _advisor_lock:
		return
	_advisor_lock = true
	_advisor_panel.hide()
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
		if kind == "march" or kind == "hold":
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
	_advisor_panel.hide()
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
	_advisor_panel.hide()
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


func _open_battle(src_id: String, dst_id: String, preview: Dictionary) -> void:
	_battle_src = src_id
	_battle_dst = dst_id
	_battle_done = false
	_in_battle = true
	Bgm.set_mode("battle")
	_fill_battle(preview, false)
	_battle.show()
	_refresh()
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
	if not bool(info.get("ok", false)):
		_battle_title.text = "简战"
		_battle_body.text = str(info.get("message", ""))
		_battle_skip.visible = false
		_battle_close.visible = true
		return
	_battle_title.text = "简战 · %s" % str(info["label"]) if resolved else "简战"
	var yuan := "袁部在攻的这边，战力再高一截。\n" if bool(info["yuan_bonus"]) else ""
	var hold := "守方这个回合在固守。\n" if bool(info["held"]) else ""
	var tail := "\n%s" % str(info["message"]) if resolved else "\n大约等一秒，也可以跳过。"
	_battle_body.text = "%s 出兵 %d　→　%s 守军 %d\n%s%s攻方战力 %d　守方战力 %d%s" % [
		info["src_name"],
		int(info["sent"]),
		info["dst_name"],
		int(info["defender"]),
		yuan,
		hold,
		int(info["atk_x100"]),
		int(info["def_x100"]),
		tail,
	]
	_battle_skip.visible = not resolved
	_battle_close.visible = resolved


func _build_battle() -> void:
	_battle = _modal()
	var box := _modal_box(_battle)
	_battle_title = Label.new()
	_battle_title.add_theme_font_size_override("font_size", 26)
	_battle_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	box.add_child(_battle_title)
	_battle_body = Label.new()
	_battle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_body.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	box.add_child(_battle_body)
	_battle_skip = Button.new()
	_battle_skip.text = "跳过演出"
	_battle_skip.pressed.connect(_commit_battle)
	box.add_child(_battle_skip)
	_battle_close = Button.new()
	_battle_close.text = "返回大地图"
	_battle_close.pressed.connect(_close_battle)
	box.add_child(_battle_close)
	_battle.hide()


func _close_battle() -> void:
	_battle.hide()
	_in_battle = false
	if Bgm.mode == "battle":
		Bgm.set_mode("map")
	_refresh()


func _build_credits() -> void:
	_credits = _modal()
	var box := _modal_box(_credits)
	var title := Label.new()
	title.text = "署名"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(460, 0)
	body.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
	body.text = "音乐（页面标明 CC0）\n地图 Lotus Pond — BiteMe Games\n简战 Dragon Dance — BiteMe Games\n剧情 Orien — Tozan（OpenGameArt）\n结局 Floating Lanterns — John Bartmann（Free Music Archive）\n\n字体：文泉驿微米黑，Apache-2.0。\n地图、城标和卡面图案是程序画的，没有用别人的贴图。"
	box.add_child(body)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func() -> void: _credits.hide())
	box.add_child(close)
	_credits.hide()


func _on_credits() -> void:
	_credits.show()


func _modal() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	return dim


func _modal_box(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	_paint(panel, Color(0.14, 0.08, 0.06, 0.98), _GOLD, 2)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


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
		return {"on": false, "why": "先点一座我方的城"}
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


func _apply_state(button: Button, reason: Label, state: Dictionary) -> void:
	var enabled := bool(state["on"])
	button.disabled = not enabled
	reason.text = str(state["why"])
	button.tooltip_text = reason.text
	var color := Color(0.62, 0.16, 0.12) if not enabled else _MUTED
	reason.add_theme_color_override("font_color", color)


func _show_note(text: String) -> void:
	_log.text = text


func _paint(panel: PanelContainer, fill: Color, border: Color, width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)


func _round_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _GOLD
	normal.border_color = Color(0.35, 0.16, 0.08)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(46)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = _GOLD.lightened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _style_end(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _CARMINE
	normal.border_color = _GOLD
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = _CARMINE.lightened(0.12)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = Color(0.35, 0.22, 0.18)
	off.border_color = Color(0.5, 0.38, 0.28)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", off)
