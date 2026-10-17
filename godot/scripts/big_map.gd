extends Control
## M1 大地图。城池与初值仍来自 campaign_baseline.gd，回合规则在 autoload Campaign。

const Baseline := preload("res://data/campaign_baseline.gd")
const _MARKER_SIZE := Vector2(104, 68)

var _selected_id := ""
var _pick := ""
var _markers: Dictionary = {}
var _battle: Control
var _battle_title: Label
var _battle_body: Label
var _battle_skip: Button
var _battle_close: Button
var _battle_src := ""
var _battle_dst := ""
var _battle_done := false
var _settle: Control


func _ready() -> void:
	_install_font_fallback()
	_style_chrome()
	_build_battle_overlay()
	_build_settle_overlay()
	_connect_actions()
	_build_markers()
	%CityLayer.resized.connect(_position_markers)
	_position_markers.call_deferred()
	_refresh()
	Bgm.set_mode("map")
	if Campaign.pending_story != "":
		_open_story(Campaign.pending_story)
		return
	if Campaign.settled and Campaign.ending_id != "" and not Campaign.skip_ending_scene:
		_open_ending()
		return
	Campaign.skip_ending_scene = false


func _install_font_fallback() -> void:
	var font := get_theme_default_font()
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)


func _style_chrome() -> void:
	_paint_panel(%MapPanel, Color(0.18, 0.14, 0.11, 1), Color(0.55, 0.42, 0.26, 1))
	_paint_panel(%HudPanel, Color(0.11, 0.09, 0.08, 0.96), Color(0.62, 0.48, 0.30, 0.95))
	_paint_panel(%DetailPanel, Color(0.11, 0.09, 0.08, 0.96), Color(0.62, 0.48, 0.30, 0.95))
	_style_end_button()
	%TitleLabel.add_theme_font_size_override("font_size", 28)
	%TitleLabel.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%SubtitleLabel.add_theme_font_size_override("font_size", 14)
	%SubtitleLabel.add_theme_color_override("font_color", Color(0.78, 0.70, 0.58))
	%HintLabel.add_theme_font_size_override("font_size", 13)
	%HintLabel.add_theme_color_override("font_color", Color(0.75, 0.68, 0.56))
	%VolumeLabel.add_theme_font_size_override("font_size", 14)
	%VolumeLabel.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	%HudHeading.add_theme_font_size_override("font_size", 18)
	%HudHeading.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%DetailTitle.add_theme_font_size_override("font_size", 20)
	%DetailTitle.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%DetailBody.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	%ActionHint.add_theme_font_size_override("font_size", 13)
	%ActionHint.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
	%ActionHint.max_lines_visible = 2
	%LogLabel.add_theme_font_size_override("font_size", 13)
	%LogLabel.add_theme_color_override("font_color", Color(0.93, 0.86, 0.70))
	%LogLabel.max_lines_visible = 2
	%FactionLabel.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64))
	%HudFoot.add_theme_font_size_override("font_size", 12)
	%HudFoot.add_theme_color_override("font_color", Color(0.62, 0.56, 0.46))
	for stat in Baseline.STATS:
		var label := get_node("%%%s" % _stat_node(str(stat["id"]))) as Label
		label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))
	%BefriendLabel.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))
	%LoyalistLabel.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))


func _stat_node(stat_id: String) -> String:
	match stat_id:
		"silver":
			return "SilverLabel"
		"grain":
			return "GrainLabel"
		"morale":
			return "MoraleLabel"
		"liaodong":
			return "LiaodongLabel"
		"pressure":
			return "PressureLabel"
		"worldline":
			return "WorldlineLabel"
		"yuan":
			return "YuanLabel"
		_:
			return "SilverLabel"


func _paint_panel(panel: PanelContainer, fill: Color, border: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_top = 10
	box.content_margin_right = 12
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)


func _style_end_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.28, 0.20, 0.13, 1)
	normal.border_color = Color(0.72, 0.58, 0.36, 1)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.36, 0.26, 0.16, 1)
	%EndTurnButton.add_theme_stylebox_override("normal", normal)
	%EndTurnButton.add_theme_stylebox_override("hover", hover)
	%EndTurnButton.add_theme_stylebox_override("pressed", hover)
	%EndTurnButton.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))


func _connect_actions() -> void:
	%MarchButton.pressed.connect(_on_march_pressed)
	%AttackButton.pressed.connect(_on_attack_pressed)
	%HoldButton.pressed.connect(_on_hold_pressed)
	%LevyButton.pressed.connect(_on_civil.bind("levy"))
	%SpendButton.pressed.connect(_on_civil.bind("spend"))
	%TrainButton.pressed.connect(_on_civil.bind("train"))
	%SkipButton.pressed.connect(_on_civil.bind("skip"))
	%EndTurnButton.pressed.connect(_on_end_turn)
	%SaveButton.pressed.connect(_on_save)
	%LoadButton.pressed.connect(_on_load)
	%NewButton.pressed.connect(_on_new_game)
	%MuteButton.pressed.connect(_on_mute)
	%VolumeSlider.value = Bgm.master_linear
	%VolumeSlider.value_changed.connect(_on_volume)
	%MarchButton.tooltip_text = "相邻明军城之间移兵，留 1 守军。耗粮 3，远邻耗粮 6。"
	%AttackButton.tooltip_text = "攻打相邻敌城，留 1 守军，进入简战。"
	%HoldButton.tooltip_text = "选中的明军城本回合防御 ×1.3。"
	%LevyButton.tooltip_text = "粮草 +8，民心 -4。"
	%SpendButton.tooltip_text = "银两 -6，民心 +6。"
	%TrainButton.tooltip_text = "银两 -5，粮草 -4，选中明军城兵力 +4。"


func _build_markers() -> void:
	for city in Baseline.CITIES:
		var city_id := str(city["id"])
		var button := Button.new()
		button.name = "City_%s" % city_id
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = _MARKER_SIZE
		button.size = _MARKER_SIZE
		button.set_meta("city_id", city_id)
		button.pressed.connect(_on_city_pressed.bind(city_id))
		%CityLayer.add_child(button)
		_markers[city_id] = button


func _position_markers() -> void:
	var sz: Vector2 = %CityLayer.size
	if sz.x < 40.0 or sz.y < 40.0:
		return
	for city_id in _markers:
		var city := Baseline.city_by_id(str(city_id))
		var button := _markers[city_id] as Button
		var pos: Vector2 = city["pos"]
		button.size = _MARKER_SIZE
		button.position = pos * sz - _MARKER_SIZE * 0.5


func _refresh() -> void:
	_fill_hud()
	_refresh_markers()
	if _selected_id != "":
		_show_city(_selected_id)
	_update_buttons()
	%MuteButton.text = "取消静音" if Bgm.muted else "静音"


func _fill_hud() -> void:
	var turn_text := "第 %d / %d" % [Campaign.turn, Baseline.TURN_LIMIT]
	if Campaign.settled:
		turn_text += "（已结算）"
	%TurnLabel.text = turn_text
	%SilverLabel.text = str(Campaign.silver)
	%GrainLabel.text = str(Campaign.grain)
	%MoraleLabel.text = str(Campaign.morale)
	%LiaodongLabel.text = str(Campaign.liaodong)
	%PressureLabel.text = str(Campaign.pressure)
	%WorldlineLabel.text = str(Campaign.worldline)
	%YuanLabel.text = Campaign.yuan_status
	%BefriendLabel.text = "是" if Campaign.befriended_yuan else "否"
	%LoyalistLabel.text = "成功" if Campaign.loyalist_success else "否"
	%LogLabel.text = Campaign.log_text
	for stat in Baseline.STATS:
		var label := get_node("%%%s" % _stat_node(str(stat["id"]))) as Label
		label.tooltip_text = str(stat["hint"])


func _refresh_markers() -> void:
	for city_id in _markers:
		var info := Campaign.city(str(city_id))
		var button := _markers[city_id] as Button
		var owner := Campaign.display_owner(str(city_id))
		var yuan := " · 袁" if Campaign.yuan_city == str(city_id) else ""
		button.text = "%s\n%s %d%s" % [info["name"], owner, int(info["troops"]), yuan]
		var selected := str(city_id) == _selected_id or _is_target(str(city_id))
		var fill := _owner_fill(owner)
		button.add_theme_stylebox_override("normal", _marker_box(fill, selected))
		button.add_theme_stylebox_override("hover", _marker_box(fill.lightened(0.12), selected))
		button.add_theme_stylebox_override("pressed", _marker_box(fill.darkened(0.08), true))
		button.add_theme_stylebox_override("focus", _marker_box(fill, selected))
		var font_color := _owner_font(owner)
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_pressed_color", font_color)
		button.add_theme_font_size_override("font_size", 14)


func _is_target(city_id: String) -> bool:
	if _selected_id == "" or _pick == "":
		return false
	if not Campaign.is_adjacent(_selected_id, city_id):
		return false
	var faction := str(Campaign.city(city_id)["faction"])
	if _pick == "march":
		return faction == "明"
	if _pick == "attack":
		return faction != "明"
	return false


func _show_city(city_id: String) -> void:
	var info := Campaign.city(city_id)
	if info.is_empty():
		return
	_selected_id = city_id
	%DetailTitle.text = "%s（%s）" % [info["name"], city_id]
	var note := str(info["note"])
	if note == "":
		note = "—"
	var yuan := "在此" if Campaign.yuan_city == city_id else "—"
	var hold := "本回合" if Campaign.hold_city == city_id else "—"
	%DetailBody.text = "归属：%s\n兵力：%d\n袁部：%s\n固守：%s\n备注：%s\n邻接：%s" % [
		Campaign.display_owner(city_id),
		int(info["troops"]),
		yuan,
		hold,
		note,
		_neighbor_text(city_id),
	]


func _neighbor_text(city_id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for hop in Campaign.neighbors_of(city_id):
		var other := Campaign.city(str(hop["id"]))
		var suffix := "（远）" if bool(hop["far"]) else ""
		parts.append("%s%s" % [other["name"], suffix])
	return "、".join(parts)


func _on_city_pressed(city_id: String) -> void:
	if _pick == "march" and _selected_id != "" and city_id != _selected_id:
		var marched: Dictionary = Campaign.march(_selected_id, city_id)
		%ActionHint.text = str(marched["message"])
		if bool(marched["ok"]):
			_pick = ""
			_refresh()
			return
		return
	if _pick == "attack" and _selected_id != "" and city_id != _selected_id:
		var preview: Dictionary = Campaign.preview_battle(_selected_id, city_id)
		if bool(preview["ok"]):
			_pick = ""
			_open_battle(_selected_id, city_id, preview)
			return
	_pick = ""
	_show_city(city_id)
	_refresh_markers()
	_update_buttons()
	%ActionHint.text = "已选 %s。行军或攻城后再点目标城。" % Campaign.city(city_id)["name"]


func _on_march_pressed() -> void:
	if not _require_source():
		return
	_pick = "march"
	%ActionHint.text = "行军：再点一座相邻的明军城。"
	_refresh_markers()


func _on_attack_pressed() -> void:
	if not _require_source():
		return
	_pick = "attack"
	%ActionHint.text = "攻城：再点一座相邻的敌城，进入简战。"
	_refresh_markers()


func _require_source() -> bool:
	if Campaign.settled or Campaign.main_done:
		%ActionHint.text = "本回合的主行动已经用过。"
		return false
	if _selected_id == "":
		%ActionHint.text = "先点一座明军城。"
		return false
	if str(Campaign.city(_selected_id)["faction"]) != "明":
		%ActionHint.text = "行军和攻城要从明军城出发。"
		return false
	return true


func _on_hold_pressed() -> void:
	if _selected_id == "":
		%ActionHint.text = "先点一座明军城。"
		return
	var result: Dictionary = Campaign.hold(_selected_id)
	%ActionHint.text = str(result["message"])
	_pick = ""
	_refresh()


func _on_civil(kind: String) -> void:
	var result: Dictionary = Campaign.civil(kind, _selected_id)
	%ActionHint.text = str(result["message"])
	_refresh()


func _on_end_turn() -> void:
	var result: Dictionary = Campaign.end_turn()
	_pick = ""
	_refresh()
	if not bool(result.get("ok", false)):
		%ActionHint.text = str(result["message"])
		return
	var where := str(result.get("goto", "map"))
	if where == "s1" or where == "s2" or where == "s3":
		Campaign.save_game()
		_open_story(where)
		return
	if where == "ending":
		_open_ending()


func _on_save() -> void:
	if Campaign.pending_story != "":
		%ActionHint.text = "剧情进行中不能存档。进剧情前已自动存过。"
		return
	var result: Dictionary = Campaign.save_game()
	%ActionHint.text = str(result["message"])
	_refresh()


func _on_load() -> void:
	var result: Dictionary = Campaign.load_game()
	%ActionHint.text = str(result["message"])
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
	_battle.hide()
	_settle.hide()
	Bgm.set_mode("map")
	_refresh()
	%ActionHint.text = "新局已开。旧档还在，要读才会回来。"


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


func _on_mute() -> void:
	Bgm.toggle_muted()
	_refresh()


func _on_volume(value: float) -> void:
	Bgm.set_master_linear(value)


func _update_buttons() -> void:
	var locked := Campaign.settled or Campaign.main_done
	%MarchButton.disabled = locked
	%AttackButton.disabled = locked
	%HoldButton.disabled = locked
	var civil_locked := Campaign.settled or Campaign.civil_done
	%LevyButton.disabled = civil_locked
	%SpendButton.disabled = civil_locked
	%TrainButton.disabled = civil_locked
	%SkipButton.disabled = civil_locked
	%EndTurnButton.disabled = Campaign.settled or not Campaign.main_done


func _open_battle(src_id: String, dst_id: String, preview: Dictionary) -> void:
	_battle_src = src_id
	_battle_dst = dst_id
	_battle_done = false
	Bgm.set_mode("battle")
	_fill_battle(preview, false)
	_battle.show()
	var timer := get_tree().create_timer(1.4)
	timer.timeout.connect(_commit_battle)


func _commit_battle() -> void:
	if _battle_done:
		return
	_battle_done = true
	var result: Dictionary = Campaign.commit_player_battle(_battle_src, _battle_dst)
	_fill_battle(result, true)
	_refresh()


func _fill_battle(info: Dictionary, resolved: bool) -> void:
	if not bool(info.get("ok", false)):
		_battle_title.text = "简战"
		_battle_body.text = str(info.get("message", ""))
		_battle_skip.visible = false
		_battle_close.visible = true
		return
	if resolved:
		_battle_title.text = "简战 · %s" % str(info["label"])
	else:
		_battle_title.text = "简战"
	var yuan := "袁部在攻方，有效兵力 ×1.25。\n" if bool(info["yuan_bonus"]) else ""
	var hold := "守方本回合固守。\n" if bool(info["held"]) else ""
	var terrain := "守方地形 ×%.2f。\n" % (float(info["terrain_pct"]) / 100.0)
	var tail := "\n%s" % str(info["message"]) if resolved else "\n演出约 1 秒，可跳过。"
	_battle_body.text = "曲：战鼓\n%s 出兵 %d　→　%s 守军 %d\n%s%s%s攻方强度 %d　守方强度 %d%s" % [
		info["src_name"],
		int(info["sent"]),
		info["dst_name"],
		int(info["defender"]),
		yuan,
		hold,
		terrain,
		int(info["atk_x100"]),
		int(info["def_x100"]),
		tail,
	]
	_battle_skip.visible = not resolved
	_battle_close.visible = resolved


func _build_battle_overlay() -> void:
	_battle = _modal_panel()
	var box := _modal_box(_battle)
	_battle_title = Label.new()
	_battle_title.add_theme_font_size_override("font_size", 26)
	_battle_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	box.add_child(_battle_title)
	_battle_body = Label.new()
	_battle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_body.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
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
	if Bgm.mode == "battle":
		Bgm.set_mode("map")


func _build_settle_overlay() -> void:
	_settle = _modal_panel()
	var box := _modal_box(_settle)
	var title := Label.new()
	title.text = "超时结算"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	box.add_child(title)
	var body := Label.new()
	body.name = "SettleBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	box.add_child(body)
	var close := Button.new()
	close.text = "回到地图"
	close.pressed.connect(func() -> void: _settle.hide())
	box.add_child(close)
	_settle.hide()


func _show_settle() -> void:
	var body := _settle.find_child("SettleBody", true, false) as Label
	var lines := "第 10 回合已结束。未分胜负，按当前局面强制收束，不粉饰。\nS2、S3 与结局甲乙丙丁尚未接入。\n\n"
	for line in Campaign.summary_lines():
		lines += line + "\n"
	body.text = lines + "\n" + Campaign.log_text
	_settle.show()


func _modal_panel() -> Control:
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
	panel.custom_minimum_size = Vector2(520, 280)
	_paint_panel(panel, Color(0.12, 0.1, 0.08, 0.98), Color(0.72, 0.58, 0.36, 1))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _owner_fill(owner: String) -> Color:
	if owner == "明":
		return Color(0.79, 0.64, 0.36)
	if owner == "后金":
		return Color(0.56, 0.24, 0.23)
	return Color(0.67, 0.40, 0.24)


func _owner_font(owner: String) -> Color:
	if owner == "明":
		return Color(0.18, 0.12, 0.07)
	return Color(0.97, 0.94, 0.90)


func _marker_box(fill: Color, selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(5)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	if selected:
		box.border_color = Color(0.98, 0.95, 0.86)
		box.set_border_width_all(3)
	else:
		box.border_color = Color(0.16, 0.11, 0.08, 0.45)
		box.set_border_width_all(1)
	return box
