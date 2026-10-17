extends Control
## 标题页。背景复用登基夜殿堂，不新做 3D。设置和确认框先用现有字和切图，版式等 Alice。

const HALL := preload("res://scenes/s1_night.tscn")
const UiKit := preload("res://scripts/ui_kit.gd")

var _continue: Button
var _note: Label
var _settings: Control
var _volume: HSlider
var _mute: Button
var _dialog: Control
var _dialog_title: Label
var _dialog_body: Label
var _dialog_ok: Button
var _dialog_cancel: Button
var _dialog_action := ""


func _ready() -> void:
	UiKit.boot()
	_mount_hall()
	_build_menu()
	_build_settings()
	_build_dialog()
	_sync_continue()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()


func _mount_hall() -> void:
	var hall := HALL.instantiate()
	hall.backdrop_only = true
	hall.name = "Hall"
	add_child(hall)
	move_child(hall, 0)


func _build_menu() -> void:
	var wash := ColorRect.new()
	wash.color = Color(0.05, 0.03, 0.02, 0.42)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wash.offset_bottom = 176
	add_child(wash)
	var title := UiKit.label("改命：天下", UiKit.serif, 64, Color("FFF3D6"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -420
	title.offset_right = 420
	title.offset_top = 48
	title.offset_bottom = 124
	UiKit.outline(title, 8)
	add_child(title)
	var sub := UiKit.label("明末 · 苍凉家国", UiKit.serif, 22, UiKit.GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -320
	sub.offset_right = 320
	sub.offset_top = 124
	sub.offset_bottom = 160
	UiKit.outline(sub, 6)
	add_child(sub)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -150
	column.offset_right = 150
	column.offset_top = -360
	column.offset_bottom = -56
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_END
	add_child(column)
	var start := _menu_button("开始游戏", true)
	start.name = "StartButton"
	start.pressed.connect(_on_start)
	column.add_child(start)
	_continue = _menu_button("继续", false)
	_continue.name = "ContinueButton"
	_continue.pressed.connect(_on_continue)
	column.add_child(_continue)
	var settings := _menu_button("设置", false)
	settings.name = "SettingsButton"
	settings.pressed.connect(open_settings)
	column.add_child(settings)
	var quit := _menu_button("退出", false)
	quit.name = "QuitButton"
	quit.pressed.connect(_on_quit)
	column.add_child(quit)
	_note = UiKit.label("", UiKit.sans, 16, UiKit.CREAM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_note.offset_left = -360
	_note.offset_right = 360
	_note.offset_top = -48
	_note.offset_bottom = -16
	add_child(_note)


func _menu_button(text: String, filled: bool) -> Button:
	var button := UiKit.painted_button(text, filled, 300)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.28, 0.26, 0.24, 0.88)
	disabled.border_color = Color(0.45, 0.42, 0.38)
	disabled.set_border_width_all(2)
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	disabled.content_margin_top = 6
	disabled.content_margin_bottom = 6
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.52))
	return button


func _build_settings() -> void:
	_settings = _dim_layer("SettingsLayer")
	_settings.z_index = 10
	var panel := _paper(520, 420)
	_settings.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_top = 24
	box.offset_right = -28
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := UiKit.label("设置", UiKit.serif, 28, Color("FFF3D6"))
	box.add_child(heading)
	box.add_child(UiKit.label("音量", UiKit.sans, 16, UiKit.CREAM))
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 1
	_volume.step = 0.01
	_volume.value = Bgm.master_linear
	_volume.custom_minimum_size = Vector2(0, 28)
	_volume.value_changed.connect(_on_volume)
	box.add_child(_volume)
	_mute = UiKit.painted_button("静音", false, 160)
	_mute.pressed.connect(_on_mute)
	box.add_child(_mute)
	var reset := UiKit.painted_button("重置新手引导", false, 280)
	reset.pressed.connect(open_reset_confirm)
	box.add_child(reset)
	var clear := UiKit.painted_button("清空存档", true, 280)
	clear.pressed.connect(open_clear_confirm)
	box.add_child(clear)
	var close := UiKit.painted_button("关闭", false, 160)
	close.pressed.connect(_close_settings)
	box.add_child(close)
	_refresh_mute()


func _build_dialog() -> void:
	_dialog = _dim_layer("ConfirmLayer")
	_dialog.z_index = 20
	var panel := _paper(760, 300)
	_dialog.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_top = 22
	box.offset_right = -28
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_dialog_title = UiKit.label("", UiKit.serif, 26, Color("FFF3D6"))
	box.add_child(_dialog_title)
	_dialog_body = UiKit.label("", UiKit.sans, 18, UiKit.CREAM)
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.custom_minimum_size = Vector2(680, 88)
	box.add_child(_dialog_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_dialog_ok = UiKit.painted_button("", true, 160)
	_dialog_ok.name = "ConfirmOk"
	_dialog_ok.pressed.connect(accept_confirm)
	row.add_child(_dialog_ok)
	_dialog_cancel = UiKit.painted_button("", false, 160)
	_dialog_cancel.name = "ConfirmCancel"
	_dialog_cancel.pressed.connect(decline_confirm)
	row.add_child(_dialog_cancel)


func _dim_layer(node_name: String) -> Control:
	var dim := ColorRect.new()
	dim.name = node_name
	dim.color = Color(0.02, 0.015, 0.01, 0.62)
	dim.visible = false
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	return dim


func _paper(width: float, height: float) -> Control:
	var panel := UiKit.nine("panel_frame_l.png", 26)
	panel.custom_minimum_size = Vector2(width, height)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_right = width * 0.5
	panel.offset_bottom = height * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func _sync_continue() -> void:
	_continue.disabled = not Campaign.has_campaign_save()


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
	_volume.value = Bgm.master_linear
	_refresh_mute()
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false


func _on_volume(value: float) -> void:
	Bgm.set_master_linear(value)


func _on_mute() -> void:
	Bgm.toggle_muted()
	_refresh_mute()


func _refresh_mute() -> void:
	if _mute == null:
		return
	_mute.text = "取消静音" if Bgm.muted else "静音"


func open_clear_confirm() -> void:
	_open_dialog("clear")


func open_reset_confirm() -> void:
	_open_dialog("reset")


func _open_dialog(action: String) -> void:
	_dialog_action = action
	if action == "clear":
		_dialog_title.text = "清空存档？"
		_dialog_body.text = "你的战役进度和新手引导记录会被删除，无法恢复。音量等设置不受影响。"
		_dialog_ok.text = "清空"
		_dialog_cancel.text = "再想想"
	elif action == "reset":
		_dialog_title.text = "重置新手引导？"
		_dialog_body.text = "下次进入大地图时，会再次显示新手引导。你的战役进度不受影响。"
		_dialog_ok.text = "重置"
		_dialog_cancel.text = "取消"
	else:
		_dialog_title.text = "开始新局？"
		_dialog_body.text = "已有存档。开始新的一局会覆盖旧档，无法恢复。"
		_dialog_ok.text = "开始"
		_dialog_cancel.text = "再想想"
	_dialog.visible = true


func accept_confirm() -> void:
	var action := _dialog_action
	_dialog.visible = false
	_dialog_action = ""
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
