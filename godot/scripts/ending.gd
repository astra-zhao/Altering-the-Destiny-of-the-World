extends Control
## 结算页。世界线条、三条改写、结局曲。优先级已在 Campaign.resolve_ending。


func _ready() -> void:
	Bgm.set_mode("ending")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	if Campaign.ending_id == "":
		Campaign.ending_id = Campaign.resolve_ending()
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.04, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = Campaign.ending_title()
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	column.add_child(title)

	var sub := Label.new()
	sub.text = "世界线偏移 %d。条越长，改写越多。优先级：甲 > 乙 > 丁 > 丙。" % Campaign.worldline
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	column.add_child(sub)
	_install_font(sub)

	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(0, 18)
	track.color = Color(0.15, 0.13, 0.11)
	column.add_child(track)
	var fill := ColorRect.new()
	var width := clampf(float(Campaign.worldline) / 100.0, 0.0, 1.0)
	fill.anchor_right = width
	fill.anchor_bottom = 1.0
	fill.color = Color(0.72, 0.55, 0.28)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

	var heading := Label.new()
	heading.text = "你改写了什么"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74))
	column.add_child(heading)
	for line in Campaign.rewrite_lines():
		var bullet := Label.new()
		bullet.text = "· " + line
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76))
		column.add_child(bullet)

	var stats := Label.new()
	stats.text = "\n".join(Campaign.summary_lines())
	stats.add_theme_color_override("font_color", Color(0.75, 0.72, 0.64))
	column.add_child(stats)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var credit := Label.new()
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	credit.text = "音乐（CC0）：Lotus Pond、Dragon Dance — BiteMe Games；Orien — Tozan；Floating Lanterns — John Bartmann。字体：文泉驿微米黑（Apache-2.0）。"
	column.add_child(credit)

	var back := Button.new()
	back.text = "回到大地图"
	back.pressed.connect(_back_to_map)
	row.add_child(back)
	var fresh := Button.new()
	fresh.text = "新局"
	fresh.pressed.connect(_new_game)
	row.add_child(fresh)


func _install_font(control: Control) -> void:
	var font := control.get_theme_font("font")
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)


func _back_to_map() -> void:
	Campaign.skip_ending_scene = true
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _new_game() -> void:
	Campaign.reset()
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
