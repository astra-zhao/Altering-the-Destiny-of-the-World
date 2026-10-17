extends Button
## 城标是画出来的印鉴和城楼，没有外部贴图。

var city_name := ""
var owner_name := ""
var troops := 0
var marked := false
var hinted := false
var yuan_here := false
var holding := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	flat = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)


func redraw() -> void:
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 30.0)
	var fill := Color(0.56, 0.16, 0.13)
	if owner_name == "明":
		fill = Color(0.80, 0.64, 0.32)
	elif owner_name == "争议":
		fill = Color(0.62, 0.38, 0.2)
	draw_circle(center, 20.0, fill.darkened(0.18))
	draw_circle(center + Vector2(0, -1), 18.0, fill)
	var roof := PackedVector2Array([
		center + Vector2(0, -16),
		center + Vector2(13, -2),
		center + Vector2(-13, -2),
	])
	draw_colored_polygon(roof, Color(0.28, 0.08, 0.07))
	draw_rect(Rect2(center + Vector2(-7, -1), Vector2(14, 11)), Color(0.95, 0.9, 0.78))
	draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 7)), Color(0.25, 0.12, 0.08))
	if marked:
		draw_arc(center, 25.0, 0, TAU, 36, Color(0.98, 0.88, 0.45), 3.0, true)
	elif hinted:
		draw_arc(center, 25.0, 0, TAU, 28, Color(0.72, 0.52, 0.22, 0.95), 1.6, true)
	var font := get_theme_default_font()
	if font == null:
		return
	var ink := Color(0.16, 0.09, 0.05)
	draw_string(font, Vector2(0, size.y - 16), city_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, ink)
	var sub := "%s %d" % [owner_name, troops]
	if yuan_here:
		sub += " · 袁"
	if holding:
		sub += " · 守"
	draw_string(font, Vector2(0, size.y - 1), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.32, 0.18, 0.1))
