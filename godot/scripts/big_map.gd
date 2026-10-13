extends Control
## M0 空壳大地图。城池与局面初值见 data/campaign_baseline.gd（对齐 v0.2 策略大纲 §1）。
## 「切换→抉择→写回」只提示 M1 流程，不改银两、粮草、民心、辽东、后金压力、世界线或袁崇焕。

const Baseline := preload("res://data/campaign_baseline.gd")
const _MARKER_SIZE := Vector2(96, 54)

const _STAT_LABELS := {
	"silver": "SilverLabel",
	"grain": "GrainLabel",
	"morale": "MoraleLabel",
	"liaodong": "LiaodongLabel",
	"pressure": "PressureLabel",
	"worldline": "WorldlineLabel",
	"yuan": "YuanLabel",
}

var _selected_id := ""
var _markers: Dictionary = {}


func _ready() -> void:
	_install_font_fallback()
	_style_chrome()
	_fill_hud()
	_build_markers()
	%StoryButton.pressed.connect(_on_story_stub_pressed)
	%CityLayer.resized.connect(_position_markers)
	_position_markers.call_deferred()


func _install_font_fallback() -> void:
	# 主字体是内嵌的 TTF 子集。系统字体只补子集里没有的字。
	# 不把文泉驿 TTC 放在前面：Linux 上它会被选中，但画出来是方框。
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
	_style_story_button()
	%TitleLabel.add_theme_font_size_override("font_size", 28)
	%TitleLabel.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%SubtitleLabel.add_theme_font_size_override("font_size", 14)
	%SubtitleLabel.add_theme_color_override("font_color", Color(0.78, 0.70, 0.58))
	%HintLabel.add_theme_font_size_override("font_size", 13)
	%HintLabel.add_theme_color_override("font_color", Color(0.75, 0.68, 0.56))
	%HudHeading.add_theme_font_size_override("font_size", 18)
	%HudHeading.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%DetailTitle.add_theme_font_size_override("font_size", 20)
	%DetailTitle.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
	%DetailBody.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	%StoryNote.add_theme_font_size_override("font_size", 13)
	%StoryNote.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64))
	%FactionLabel.add_theme_color_override("font_color", Color(0.82, 0.76, 0.64))
	%HudFoot.add_theme_font_size_override("font_size", 12)
	%HudFoot.add_theme_color_override("font_color", Color(0.62, 0.56, 0.46))
	for stat in Baseline.STATS:
		var label := get_node("%%%s" % _STAT_LABELS[str(stat["id"])]) as Label
		label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.66))


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


func _style_story_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.28, 0.20, 0.13, 1)
	normal.border_color = Color(0.72, 0.58, 0.36, 1)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.36, 0.26, 0.16, 1)
	%StoryButton.add_theme_stylebox_override("normal", normal)
	%StoryButton.add_theme_stylebox_override("hover", hover)
	%StoryButton.add_theme_stylebox_override("pressed", hover)
	%StoryButton.add_theme_stylebox_override("focus", normal)
	%StoryButton.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	%StoryButton.add_theme_color_override("font_hover_color", Color(0.98, 0.95, 0.88))
	%StoryButton.add_theme_color_override("font_pressed_color", Color(0.98, 0.95, 0.88))


func _fill_hud() -> void:
	%TurnLabel.text = "第 %d / %d（不推进）" % [Baseline.TURN, Baseline.TURN_LIMIT]
	%TurnLabel.tooltip_text = "回合上限 10。M0 不结算、不进入下一回合。"
	%FactionLabel.text = Baseline.FACTION_LINE
	%StoryNote.text = Baseline.STORY_IDLE
	%DetailTitle.text = "城池"
	%DetailBody.text = "点击地图上的城池，查看归属、备注与邻接。"
	for stat in Baseline.STATS:
		var label := get_node("%%%s" % _STAT_LABELS[str(stat["id"])]) as Label
		label.text = str(stat["value"])
		label.tooltip_text = str(stat["hint"])


func _build_markers() -> void:
	for city in Baseline.CITIES:
		var city_id := str(city["id"])
		var button := Button.new()
		button.name = "City_%s" % city_id
		button.text = "%s\n%s" % [city["name"], _owner_short(str(city["owner"]))]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = _MARKER_SIZE
		button.size = _MARKER_SIZE
		button.tooltip_text = "%s · %s" % [city["name"], city["owner"]]
		button.set_meta("city_id", city_id)
		button.pressed.connect(_on_city_pressed.bind(city_id))
		%CityLayer.add_child(button)
		_markers[city_id] = button
	_refresh_marker_styles()


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


func _on_city_pressed(city_id: String) -> void:
	var city := Baseline.city_by_id(city_id)
	if city.is_empty():
		return
	_selected_id = city_id
	%DetailTitle.text = "%s（%s）" % [city["name"], city["id"]]
	var note := str(city["note"])
	if note == "":
		note = "—"
	%DetailBody.text = "归属：%s\n备注：%s\n邻接：%s" % [city["owner"], note, _neighbor_text(city_id)]
	_refresh_marker_styles()


func _on_story_stub_pressed() -> void:
	# M1：切到 S1/S2/S3，给出抉择，再把局面写回这块面板。M0 停在说明。
	%StoryNote.text = Baseline.STORY_PRESSED


func _neighbor_text(city_id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for route in Baseline.ROUTES:
		var other := ""
		if str(route["a"]) == city_id:
			other = str(route["b"])
		elif str(route["b"]) == city_id:
			other = str(route["a"])
		else:
			continue
		var city := Baseline.city_by_id(other)
		var suffix := "（远）" if bool(route["far"]) else ""
		parts.append("%s%s" % [city["name"], suffix])
	return "、".join(parts)


func _refresh_marker_styles() -> void:
	for city_id in _markers:
		var city := Baseline.city_by_id(str(city_id))
		var button := _markers[city_id] as Button
		var owner := str(city["owner"])
		var selected := str(city_id) == _selected_id
		var fill := _owner_fill(owner)
		button.add_theme_stylebox_override("normal", _marker_box(fill, selected))
		button.add_theme_stylebox_override("hover", _marker_box(fill.lightened(0.12), selected))
		button.add_theme_stylebox_override("pressed", _marker_box(fill.darkened(0.08), true))
		button.add_theme_stylebox_override("focus", _marker_box(fill, selected))
		var font_color := _owner_font(owner)
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_pressed_color", font_color)
		button.add_theme_font_size_override("font_size", 15)


func _owner_short(owner: String) -> String:
	if owner.begins_with("争议"):
		return "争议"
	return owner


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
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	if selected:
		box.border_color = Color(0.98, 0.95, 0.86)
		box.set_border_width_all(3)
	else:
		box.border_color = Color(0.16, 0.11, 0.08, 0.45)
		box.set_border_width_all(1)
	return box
