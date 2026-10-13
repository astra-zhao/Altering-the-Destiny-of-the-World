extends Control
## S1 登基夜占位。夜色宫城 + 镜头推近，三选一后按大纲写回，再回大地图。

const _CHOICES := [
	{"id": "A", "text": "A. 先稳朝堂\n银两 +5，世界线 +5"},
	{"id": "B", "text": "B. 先重辽东、点名袁崇焕\n辽东 +8，银两 -5，结交袁，世界线 +10"},
	{"id": "C", "text": "C. 先安民\n民心 +10，粮草 -5，世界线 +5"},
]


func _ready() -> void:
	_install_font_fallback()
	Bgm.set_mode("story")
	_build()


func _install_font_fallback() -> void:
	var font := get_theme_default_font()
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.07, 0.12)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "登基夜"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74))
	column.add_child(title)

	var sub := Label.new()
	sub.text = "宫城夜景 · 镜头推近。选定后立刻写回局面，回到大地图。"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.86))
	column.add_child(sub)

	var court := Control.new()
	court.custom_minimum_size = Vector2(0, 220)
	court.size_flags_vertical = Control.SIZE_EXPAND_FILL
	court.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(court)
	court.draw.connect(_draw_court.bind(court))
	court.scale = Vector2(0.92, 0.92)
	court.resized.connect(func() -> void: court.pivot_offset = court.size * 0.5)
	var tween := create_tween()
	tween.tween_property(court, "scale", Vector2.ONE, 1.0)

	for choice in _CHOICES:
		var button := Button.new()
		button.text = str(choice["text"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 64)
		button.pressed.connect(_choose.bind(str(choice["id"])))
		column.add_child(button)


func _draw_court(court: Control) -> void:
	var sz := court.size
	if sz.x < 20.0:
		return
	court.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.1, 0.16), true)
	var moon := Vector2(sz.x * 0.82, sz.y * 0.28)
	court.draw_circle(moon, 28.0, Color(0.9, 0.9, 0.82, 0.9))
	var throne := Rect2(sz.x * 0.38, sz.y * 0.42, sz.x * 0.24, sz.y * 0.38)
	court.draw_rect(throne, Color(0.45, 0.32, 0.16), true)
	court.draw_rect(throne.grow(-6), Color(0.72, 0.58, 0.28), false, 2.0)
	var font := get_theme_default_font()
	if font == null:
		return
	court.draw_string(font, Vector2(sz.x * 0.4, sz.y * 0.22), "镜头推近", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.82, 0.7, 0.8))


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s1(choice_id)
	if not bool(result.get("ok", false)):
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
