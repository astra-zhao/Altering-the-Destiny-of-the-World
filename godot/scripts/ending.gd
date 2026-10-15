extends Control
## 结局卷轴。数字和改写记来自 Campaign，不改结算规则。


const Baseline := preload("res://data/campaign_baseline.gd")
const UiKit := preload("res://scripts/ui_kit.gd")
const AdvisorScript := preload("res://scripts/advisor.gd")

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
	_paper.clip_contents = true
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(column)

	var title := UiKit.label("结局 · %s" % Campaign.ending_title(), UiKit.serif, 28, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var basis := UiKit.label("第 8 回合到了终局，天下按当时的局面结算。不是中途被判出局。", UiKit.sans, 15, Color("2a1a10"))
	basis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	basis.autowrap_mode = TextServer.AUTOWRAP_OFF
	basis.clip_text = false
	column.add_child(basis)
	var rewrite_line := "改写记：" + " ".join(Campaign.rewrite_lines())
	var rewrite := UiKit.label(rewrite_line, UiKit.sans, 14, Color("2a1a10"))
	rewrite.autowrap_mode = TextServer.AUTOWRAP_OFF
	rewrite.clip_text = true
	rewrite.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(rewrite)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_child(split)
	split.add_child(_why_block())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	split.add_child(grid)
	var tiles := [
		["icon_turn_64.png", "回合", "%d / %d" % [Campaign.turn, Baseline.PLAY_TURNS]],
		["icon_silver_64.png", "银两", str(Campaign.silver)],
		["icon_grain_64.png", "粮草", str(Campaign.grain)],
		["icon_minxin_64.png", "民心", str(Campaign.morale)],
		["icon_liaodong_64.png", "辽东稳固", str(Campaign.liaodong)],
		["icon_pressure_64.png", "后金压力", str(Campaign.pressure)],
	]
	for spec in tiles:
		grid.add_child(_stat_tile(str(spec[0]), str(spec[1]), str(spec[2])))
	var yuan := UiKit.label("袁崇焕 %s · 世界线 %d" % [Campaign.yuan_status, Campaign.worldline], UiKit.sans, 14, UiKit.INK)
	var yuan_row := HBoxContainer.new()
	yuan_row.add_child(yuan)
	grid.add_child(yuan_row)

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
	var hit := false
	var hits: Dictionary = Campaign.stat_hits()
	if caption == "民心" and hits.has("morale"):
		hit = true
	elif caption == "银两" and hits.has("silver"):
		hit = true
	elif caption == "辽东稳固" and hits.has("liaodong"):
		hit = true
	var plate := UiKit.nine("tile_stat_hit.png" if hit else "tile_stat.png", 6)
	plate.custom_minimum_size = Vector2(168, 52)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_top = 6
	row.offset_right = -8
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(UiKit.icon_rect(icon_name, 28))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiKit.label(caption, UiKit.sans, 14, UiKit.INK_SOFT))
	text.add_child(UiKit.label(value, UiKit.serif, 22, Color("8B1E1E") if hit else UiKit.INK))
	if hit:
		var badge := TextureRect.new()
		badge.texture = UiKit.tex("tag_warn_red.png")
		badge.custom_minimum_size = Vector2(64, 24)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_SCALE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(100, 2)
		badge.size = Vector2(64, 24)
		plate.add_child(badge)
		var word := UiKit.label("危险", UiKit.sans_bold, 13, Color("FFF6E8"))
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(word)
		plate.clip_contents = false
	return plate


func _why_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ending := Campaign.ending_id if Campaign.ending_id != "" else Campaign.resolve_ending()
	box.add_child(UiKit.label("为什么是「%s」" % ending, UiKit.serif, 18, UiKit.INK))
	var best := Campaign.outlook_before_finale
	if best == "":
		best = AdvisorScript.best_ending(Campaign)
	box.add_child(UiKit.label("当前最好结局：%s" % best, UiKit.sans_bold, 15, Color("D4A84B")))
	for row in Campaign.settlement_checks():
		if str(row.get("kind", "")) == "note":
			box.add_child(UiKit.label(str(row.get("text", "")), UiKit.sans, 14, UiKit.INK_SOFT))
			continue
		box.add_child(_rule_row(row))
	var gaps := Campaign.upgrade_gaps()
	if not gaps.is_empty():
		box.add_child(UiKit.label("若要更高", UiKit.serif, 16, UiKit.INK))
		for gap in gaps:
			box.add_child(UiKit.label(gap, UiKit.sans, 13, Color("8B1E1E")))
	return box


func _rule_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := UiKit.label(str(row.get("text", "")), UiKit.sans, 15, Color("2A1A10"))
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var met := bool(row.get("met", false))
	var icon := UiKit.icon_rect("icon_check_32.png" if met else "icon_cross_32.png", 28)
	line.add_child(icon)
	var tag := TextureRect.new()
	tag.texture = UiKit.tex("tag_rule_met.png" if met else "tag_rule_unmet.png")
	tag.custom_minimum_size = Vector2(128, 28)
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.stretch_mode = TextureRect.STRETCH_SCALE
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(tag)
	var value := int(row.get("value", -1))
	var caption := "已满足" if met else "未满足"
	if value >= 0:
		caption += " · %d" % value
	var label := UiKit.label(caption, UiKit.sans_bold, 13, Color("FFF6E8"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.add_child(label)
	return line


func _layout() -> void:
	if _scroll == null or size.x < 100.0:
		return
	var max_w := size.x - 36.0
	var max_h := size.y - 86.0
	var scale := minf(max_w / 1144.0, max_h / 682.0)
	var scroll_size := Vector2(1144, 682) * scale
	_scroll.position = Vector2((size.x - scroll_size.x) * 0.5, 4)
	_scroll.size = scroll_size
	_paper.position = _scroll.position + scroll_size * Vector2(0.08, 0.18)
	_paper.size = scroll_size * Vector2(0.84, 0.58)
	var buttons_size := _buttons.get_combined_minimum_size()
	_buttons.position = Vector2((size.x - buttons_size.x) * 0.5, size.y - 68)
	_buttons.size = buttons_size
	_fit_worldline.call_deferred()


func _fit_worldline() -> void:
	if _bar_track == null or _bar_fill == null:
		return
	var ratio := clampf(float(Campaign.worldline) / 100.0, 0.0, 1.0)
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
