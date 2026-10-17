extends Control
## 结局卷轴。数字和改写记来自 Campaign，不改结算规则。
## 1280×720 的纸面坐标按 Alice 的绝对 y；其它窗口用纸高 / 368 缩放。


const Baseline := preload("res://data/campaign_baseline.gd")
const UiKit := preload("res://scripts/ui_kit.gd")
const AdvisorScript := preload("res://scripts/advisor.gd")

const PAPER_TOP := 118.0
const PAPER_H := 368.0

var _scroll: TextureRect
var _paper: Control
var _buttons: HBoxContainer
var _title: Label
var _rows: Array = []
var _avoid_bar: ColorRect
var _avoid_label: Label
var _gap_plate: ColorRect
var _gap_title: Label
var _gap_clips: Array[Control] = []
var _gap_labels: Array[Label] = []
var _tiles: Array = []
var _worldline: Label


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
	_paper.clip_contents = true
	add_child(_paper)

	_title = UiKit.label("结局 · %s" % Campaign.ending_title(), UiKit.serif, 26, UiKit.INK)
	_title.name = "EndingTitle"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = false
	_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_paper.add_child(_title)

	for row in Campaign.settlement_checks():
		_rows.append(_make_row(row))

	_avoid_bar = ColorRect.new()
	_avoid_bar.name = "AvoidBar"
	_avoid_bar.color = _avoid_bar_color()
	_avoid_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avoid_bar.clip_contents = true
	_paper.add_child(_avoid_bar)
	_avoid_label = UiKit.label("", UiKit.sans, 15, Color("FFE9D0"))
	_avoid_label.name = "AvoidLine"
	_avoid_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avoid_label.clip_text = false
	_avoid_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_avoid_bar.add_child(_avoid_label)

	_gap_plate = ColorRect.new()
	_gap_plate.name = "GapPlate"
	_gap_plate.color = _gap_plate_color()
	_gap_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(_gap_plate)
	_gap_title = UiKit.label("若要更高", UiKit.serif, 16, Color("8E2A22"))
	_gap_title.name = "GapTitle"
	_gap_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_paper.add_child(_gap_title)
	for index in 2:
		var clip := Control.new()
		clip.name = "GapClip%d" % index
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		_paper.add_child(clip)
		_gap_clips.append(clip)
		var line := UiKit.label("", UiKit.sans, 15, Color("8E2A22"))
		line.name = "GapLine%d" % index
		line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = false
		line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		clip.add_child(line)
		_gap_labels.append(line)

	var specs := [
		["icon_turn_64.png", "回合", _turn_text()],
		["icon_silver_64.png", "银两", str(Campaign.silver)],
		["icon_grain_64.png", "粮草", str(Campaign.grain)],
		["icon_minxin_64.png", "民心", str(Campaign.morale)],
		["icon_liaodong_64.png", "辽东稳固", str(Campaign.liaodong)],
		["icon_pressure_64.png", "后金压力", str(Campaign.pressure)],
	]
	for spec in specs:
		_tiles.append(_stat_tile(str(spec[0]), str(spec[1]), str(spec[2])))

	_worldline = UiKit.label(_worldline_text(), UiKit.sans, 15, UiKit.INK)
	_worldline.name = "WorldlineRow"
	_worldline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_worldline.clip_text = false
	_worldline.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_paper.add_child(_worldline)

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


func _turn_text() -> String:
	return "%d / %d" % [mini(Campaign.turn, Baseline.PLAY_TURNS), Baseline.PLAY_TURNS]


func _worldline_text() -> String:
	return "世界线偏移 %d · 袁崇焕 %s" % [Campaign.worldline, Campaign.yuan_status]


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
	plate.name = "Stat%s" % caption
	plate.clip_contents = true
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(plate)
	var icon := UiKit.icon_rect(icon_name, 28)
	plate.add_child(icon)
	var cap := UiKit.label(caption, UiKit.sans, 14, UiKit.INK_SOFT)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.clip_text = false
	plate.add_child(cap)
	var num := UiKit.label(value, UiKit.serif, 22, Color("8B1E1E") if hit else UiKit.INK)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.clip_text = false
	plate.add_child(num)
	var badge := TextureRect.new()
	badge.texture = UiKit.tex("tag_warn_red.png")
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_SCALE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = hit
	plate.add_child(badge)
	if hit:
		var word := UiKit.label("危险", UiKit.sans_bold, 13, Color("FFF6E8"))
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.add_child(word)
	plate.set_meta("icon", icon)
	plate.set_meta("caption", cap)
	plate.set_meta("value", num)
	plate.set_meta("badge", badge)
	return plate


func _make_row(row: Dictionary) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(root)
	var text := UiKit.label(str(row.get("text", "")), UiKit.sans, 15, Color("2A1A10"))
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = false
	text.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	root.add_child(text)
	var made := {"root": root, "text": text, "note": str(row.get("kind", "")) == "note"}
	if made["note"]:
		return made
	var met := bool(row.get("met", false))
	var icon := UiKit.icon_rect("icon_check_32.png" if met else "icon_cross_32.png", 28)
	root.add_child(icon)
	var tag := TextureRect.new()
	tag.texture = UiKit.tex("tag_rule_met.png" if met else "tag_rule_unmet.png")
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.stretch_mode = TextureRect.STRETCH_SCALE
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tag)
	var value := int(row.get("value", -1))
	var caption := "已满足" if met else "未满足"
	if value >= 0:
		caption += " · %d" % value
	var label := UiKit.label(caption, UiKit.sans_bold, 13, Color("FFF6E8"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.add_child(label)
	made["icon"] = icon
	made["tag"] = tag
	return made


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
	var s := _paper.size.y / PAPER_H
	var right_w := (168.0 * 2.0 + 8.0) * s
	var margin := 8.0 * s
	var right_x := _paper.size.x - margin - right_w
	var left_w := maxf(160.0 * s, right_x - margin * 2.0)
	_place_left(s, left_w, margin)
	_place_tiles(s, right_x)
	var buttons_size := _buttons.get_combined_minimum_size()
	_buttons.position = Vector2((size.x - buttons_size.x) * 0.5, size.y - 68)
	_buttons.size = buttons_size


func _avoid_bar_color() -> Color:
	# #7A1F1F，75%。最亮纸色上 #FFE9D0 仍高于 4.5:1。
	return Color(122.0 / 255.0, 31.0 / 255.0, 31.0 / 255.0, 0.75)


func _gap_plate_color() -> Color:
	# #F5EDE0，94%。压住山纹后，字色 #8E2A22 仍高于 4.5:1。
	return Color(245.0 / 255.0, 237.0 / 255.0, 224.0 / 255.0, 0.94)


func _py(abs_y: float, s: float) -> float:
	return (abs_y - PAPER_TOP) * s


func _place_left(s: float, left_w: float, margin: float) -> void:
	var title_size := maxi(16, roundi(26.0 * s))
	_title.add_theme_font_size_override("font_size", title_size)
	_title.position = Vector2(margin, _py(130.0, s))
	_title.size = Vector2(left_w, _py(162.0, s) - _py(130.0, s))
	var row_h := 36.0 * s
	var y := _py(162.0, s)
	var text_size := maxi(12, roundi(15.0 * s))
	for made in _rows:
		var root: Control = made["root"]
		root.position = Vector2(margin, y)
		root.size = Vector2(left_w, row_h)
		var text: Label = made["text"]
		text.add_theme_font_size_override("font_size", text_size)
		if made["note"]:
			text.position = Vector2.ZERO
			text.size = root.size
		else:
			var tag_w := 128.0 * s
			var icon_px := 28.0 * s
			var tag: Control = made["tag"]
			var icon: Control = made["icon"]
			tag.size = Vector2(tag_w, 28.0 * s)
			tag.position = Vector2(left_w - tag_w, (row_h - tag.size.y) * 0.5)
			icon.size = Vector2(icon_px, icon_px)
			icon.custom_minimum_size = icon.size
			icon.position = Vector2(tag.position.x - 8.0 * s - icon_px, (row_h - icon_px) * 0.5)
			text.position = Vector2.ZERO
			text.size = Vector2(maxf(40.0, icon.position.x - 6.0 * s), row_h)
		y += row_h
	var avoid_y := _py(312.0, s)
	var avoid_h := _py(334.0, s) - avoid_y
	_avoid_bar.color = _avoid_bar_color()
	_avoid_bar.position = Vector2(margin, avoid_y)
	_avoid_bar.size = Vector2(left_w, avoid_h)
	var avoid_size := maxi(15, roundi(15.0 * s))
	_avoid_label.add_theme_font_size_override("font_size", avoid_size)
	_avoid_label.add_theme_color_override("font_color", Color("FFE9D0"))
	_avoid_label.text = _avoid_text(left_w - 12.0 * s, avoid_size)
	var avoid_font := _avoid_label.get_theme_font("font")
	var avoid_box := avoid_h
	if avoid_font != null:
		avoid_box = maxf(avoid_h, avoid_font.get_height(avoid_size))
	_avoid_label.position = Vector2(6.0 * s, (avoid_h - avoid_box) * 0.5)
	_avoid_label.size = Vector2(left_w - 12.0 * s, avoid_box)
	var gaps := _shown_gaps()
	var gap_size := maxi(15, roundi(16.0 * s))
	var line_size := maxi(15, roundi(15.0 * s))
	# 回纹占纸左 −9…+23。浅底从 +24 起，标题和两行都从 +28 起，底边停在 y=412。
	var gap_x := 28.0 * s
	var plate_x := 24.0 * s
	var column_right := margin + left_w
	_gap_plate.visible = not gaps.is_empty()
	_gap_plate.color = _gap_plate_color()
	_gap_plate.position = Vector2(plate_x, _py(344.0, s))
	_gap_plate.size = Vector2(maxf(40.0, column_right - plate_x), _py(412.0, s) - _py(344.0, s))
	_gap_title.visible = not gaps.is_empty()
	_gap_title.add_theme_font_size_override("font_size", gap_size)
	_gap_title.add_theme_color_override("font_color", Color("8E2A22"))
	_gap_title.position = Vector2(gap_x, _py(344.0, s))
	_gap_title.size = Vector2(maxf(40.0, column_right - gap_x), _py(366.0, s) - _py(344.0, s))
	var slot_h := _py(390.0, s) - _py(368.0, s)
	var slot_top := _py(368.0, s)
	var line_font := _gap_labels[0].get_theme_font("font") if not _gap_labels.is_empty() else null
	var text_h := slot_h
	if line_font != null:
		text_h = maxf(slot_h, line_font.get_height(line_size))
	for index in _gap_labels.size():
		var line := _gap_labels[index]
		var clip := _gap_clips[index]
		line.visible = index < gaps.size()
		clip.visible = line.visible
		line.add_theme_font_size_override("font_size", line_size)
		line.add_theme_color_override("font_color", Color("8E2A22"))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if index < gaps.size():
			line.text = gaps[index]
		clip.position = Vector2(gap_x, slot_top + float(index) * slot_h)
		clip.size = Vector2(maxf(40.0, column_right - gap_x), slot_h)
		line.position = Vector2.ZERO
		line.size = Vector2(maxf(40.0, column_right - gap_x), text_h)


func _place_tiles(s: float, right_x: float) -> void:
	var tile := Vector2(168.0 * s, 62.0 * s)
	var gap := 8.0 * s
	var origin_y := _py(176.0, s)
	var cap_size := maxi(11, roundi(14.0 * s))
	var num_size := maxi(14, roundi(22.0 * s))
	for index in _tiles.size():
		var plate: Control = _tiles[index]
		var col := index % 2
		var row := index / 2
		plate.position = Vector2(right_x + float(col) * (tile.x + gap), origin_y + float(row) * (tile.y + gap))
		plate.size = tile
		plate.custom_minimum_size = tile
		var icon: Control = plate.get_meta("icon")
		var cap: Label = plate.get_meta("caption")
		var num: Label = plate.get_meta("value")
		var badge: Control = plate.get_meta("badge")
		var icon_px := 28.0 * s
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.size = Vector2(icon_px, icon_px)
		icon.position = Vector2(8.0 * s, (tile.y - icon_px) * 0.5)
		cap.add_theme_font_size_override("font_size", cap_size)
		cap.position = Vector2(44.0 * s, 6.0 * s)
		cap.size = Vector2(tile.x - 52.0 * s, 18.0 * s)
		num.add_theme_font_size_override("font_size", num_size)
		num.position = Vector2(44.0 * s, 26.0 * s)
		num.size = Vector2(70.0 * s, 26.0 * s)
		badge.size = Vector2(64.0 * s, 24.0 * s)
		badge.position = Vector2(tile.x - 68.0 * s, 4.0 * s)
	_worldline.add_theme_font_size_override("font_size", maxi(12, roundi(15.0 * s)))
	_worldline.position = Vector2(right_x, _py(392.0, s))
	_worldline.size = Vector2(tile.x * 2.0 + gap, 24.0 * s)


func _avoid_text(width: float, font_size: int) -> String:
	var best := Campaign.outlook_before_finale
	if best == "":
		best = AdvisorScript.best_ending(Campaign)
	var font := UiKit.sans
	for line in _avoid_candidates(best):
		if font == null or font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width + 0.5:
			return line
	var fallback: PackedStringArray = _avoid_candidates(best)
	return fallback[fallback.size() - 1]


func _avoid_candidates(best: String) -> PackedStringArray:
	var ending := Campaign.ending_id if Campaign.ending_id != "" else Campaign.resolve_ending()
	var lines := PackedStringArray()
	if ending == "丁":
		var capital := str(Campaign.city("C1")["faction"]) == "明"
		var long := "想避开：辽东回到 40 以上，或民心 ≥16 且银两 >0"
		if not capital:
			long = "想避开：京师不在，民心 ≥16 且银两 >0"
		var mid := "想避开：辽东 ≥40，或民心 ≥16 且银两 >0"
		if not capital:
			mid = "想避开：京师不在，民 ≥16 且银 >0"
		lines.append("%s　最好结局：%s" % [long, best])
		lines.append(long)
		lines.append("%s　最好结局：%s" % [mid, best])
		lines.append(mid)
	elif ending == "甲":
		lines.append("想避开：保持现状即可　最好结局：%s" % best)
		lines.append("想避开：保持现状即可")
	else:
		var plain := str(Campaign.forecast_view().get("avoid", ""))
		if plain != "":
			lines.append("%s　最好结局：%s" % [plain, best])
			lines.append(plain)
		lines.append("最好结局：%s" % best)
	if lines.is_empty():
		lines.append("最好结局：%s" % best)
	return lines


func _shown_gaps() -> PackedStringArray:
	var raw := Campaign.upgrade_gaps()
	var short := raw.size() <= 2
	for line in raw:
		if _hanzi_count(line) > 22:
			short = false
	if short:
		return raw
	return _gap_summary()


func _gap_summary() -> PackedStringArray:
	var ending := Campaign.ending_id if Campaign.ending_id != "" else Campaign.resolve_ending()
	var capital := str(Campaign.city("C1")["faction"]) == "明"
	var bits := PackedStringArray()
	if not capital:
		bits.append("京师")
	if Campaign.yuan_status == "已死":
		bits.append("袁已死")
	else:
		if Campaign.liaodong < 60:
			bits.append("辽 +%d" % (60 - Campaign.liaodong))
		if Campaign.pressure > 40:
			bits.append("压 −%d" % (Campaign.pressure - 40))
		if Campaign.worldline < 35:
			bits.append("世 +%d" % (35 - Campaign.worldline))
	var lines := PackedStringArray()
	if not bits.is_empty():
		lines.append("甲差：" + "，".join(bits))
	if ending != "乙" and capital and Campaign.liaodong < 40 and Campaign.morale < 45:
		lines.append("到乙：辽 +%d，或民 +%d" % [40 - Campaign.liaodong, 45 - Campaign.morale])
	elif ending != "乙" and not capital and lines.size() < 2:
		lines.append("到乙：须留京师")
	while lines.size() > 2:
		lines.remove_at(lines.size() - 1)
	return lines


func _hanzi_count(text: String) -> int:
	var count := 0
	var i := 0
	while i < text.length():
		if text.unicode_at(i) > 0x2E7F:
			count += 1
		i += 1
	return count


func _back_to_map() -> void:
	Campaign.skip_ending_scene = true
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _new_game() -> void:
	Campaign.reset()
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
