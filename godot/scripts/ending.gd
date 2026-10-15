extends Control
## 结局卷轴。数字和改写记来自 Campaign，不改结算规则。


const Baseline := preload("res://data/campaign_baseline.gd")
const UiKit := preload("res://scripts/ui_kit.gd")

var _scroll: TextureRect
var _paper: Control
var _bar_track: NinePatchRect
var _bar_fill: NinePatchRect
var _buttons: HBoxContainer


func _ready() -> void:
	UiKit.boot()
	Bgm.set_mode("ending")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	if Campaign.ending_id == "":
		Campaign.ending_id = Campaign.resolve_ending()
	_build()
	resized.connect(_layout)
	_layout.call_deferred()


func _build() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = UiKit.tex("bg_ending_night.jpg")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_scroll = TextureRect.new()
	_scroll.texture = UiKit.tex("ending_scroll.png")
	_scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scroll.stretch_mode = TextureRect.STRETCH_SCALE
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)

	_paper = Control.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(column)

	var title := UiKit.label("结局 · %s" % Campaign.ending_title(), UiKit.serif, 40, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var world := HBoxContainer.new()
	world.add_theme_constant_override("separation", 8)
	world.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(world)
	world.add_child(UiKit.icon_rect("icon_worldline_64.png", 36))
	world.add_child(UiKit.label("世界线偏移", UiKit.sans, 18, UiKit.INK))
	var shift := UiKit.label(str(Campaign.worldline), UiKit.serif, 28, UiKit.CINNABAR)
	world.add_child(shift)
	_bar_track = UiKit.nine("bar_bg.png", 6, 0, 6, 0)
	_bar_track.custom_minimum_size = Vector2(160, 14)
	_bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	world.add_child(_bar_track)
	_bar_track.clip_contents = true
	_bar_fill = UiKit.nine("bar_fill_cinnabar.png", 6, 0, 6, 0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_track.add_child(_bar_fill)
	_bar_track.resized.connect(_fit_worldline)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	var rewrite := VBoxContainer.new()
	rewrite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewrite.add_theme_constant_override("separation", 6)
	body.add_child(rewrite)
	rewrite.add_child(UiKit.label("改写记", UiKit.serif, 22, UiKit.INK))
	for line in Campaign.rewrite_lines():
		var bullet := UiKit.label("· " + line, UiKit.sans, 16, UiKit.INK_SOFT)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(160, 0)
		bullet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewrite.add_child(bullet)
	var yuan_color := UiKit.WARN if Campaign.yuan_status == "已死" else UiKit.INK
	var yuan := UiKit.label("袁崇焕  %s" % Campaign.yuan_status, UiKit.sans_bold, 16, yuan_color)
	rewrite.add_child(yuan)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var tiles := [
		["icon_turn_64.png", "回合", "%d / %d" % [Campaign.turn, Baseline.TURN_LIMIT]],
		["icon_silver_64.png", "银两", str(Campaign.silver)],
		["icon_grain_64.png", "粮草", str(Campaign.grain)],
		["icon_minxin_64.png", "民心", str(Campaign.morale)],
		["icon_liaodong_64.png", "辽东稳固", str(Campaign.liaodong)],
		["icon_pressure_64.png", "后金压力", str(Campaign.pressure)],
	]
	for spec in tiles:
		grid.add_child(_stat_tile(str(spec[0]), str(spec[1]), str(spec[2])))

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_buttons)
	var again := UiKit.painted_button("再来一局", true, 200)
	again.pressed.connect(_new_game)
	_buttons.add_child(again)
	var back := UiKit.painted_button("回到大地图", false, 220)
	back.pressed.connect(_back_to_map)
	_buttons.add_child(back)

	var credit := UiKit.label("配乐：Floating Lanterns · John Bartmann · CC0", UiKit.sans, 14, Color(0.82, 0.8, 0.74, 0.9))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	credit.offset_top = -22
	credit.offset_bottom = -4
	credit.offset_left = -420
	credit.offset_right = 420
	add_child(credit)


func _stat_tile(icon_name: String, caption: String, value: String) -> Control:
	var plate := UiKit.nine("tile_stat.png", 6)
	plate.custom_minimum_size = Vector2(196, 66)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	row.offset_right = -8
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(UiKit.icon_rect(icon_name, 36))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiKit.label(caption, UiKit.sans, 14, UiKit.INK_SOFT))
	text.add_child(UiKit.label(value, UiKit.serif, 22, UiKit.INK))
	return plate


func _layout() -> void:
	if _scroll == null or size.x < 100.0:
		return
	var max_w := size.x - 36.0
	var max_h := size.y - 86.0
	var scale := minf(max_w / 1144.0, max_h / 682.0)
	var scroll_size := Vector2(1144, 682) * scale
	_scroll.position = Vector2((size.x - scroll_size.x) * 0.5, 4)
	_scroll.size = scroll_size
	_paper.position = _scroll.position + scroll_size * Vector2(0.055, 0.12)
	_paper.size = scroll_size * Vector2(0.89, 0.54)
	var buttons_size := _buttons.get_combined_minimum_size()
	_buttons.position = Vector2((size.x - buttons_size.x) * 0.5, size.y - 68)
	_buttons.size = buttons_size
	_fit_worldline.call_deferred()


func _fit_worldline() -> void:
	if _bar_track == null or _bar_fill == null:
		return
	var ratio := clampf(float(Campaign.worldline) / 40.0, 0.0, 1.0)
	var width := _bar_track.size.x
	if width < 8.0:
		width = _bar_track.custom_minimum_size.x
	var bar_h := _bar_track.size.y
	if bar_h < 8.0:
		bar_h = 14.0
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 0.0
	_bar_fill.offset_left = 0.0
	_bar_fill.offset_top = 2.0
	_bar_fill.offset_right = maxf(12.0, width * ratio)
	_bar_fill.offset_bottom = bar_h - 2.0


func _back_to_map() -> void:
	Campaign.skip_ending_scene = true
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _new_game() -> void:
	Campaign.reset()
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
