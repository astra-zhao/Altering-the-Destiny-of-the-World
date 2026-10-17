extends Control
## 内政卡上的水墨小图：谷穗、铜钱、长戈。程序绘制。

var kind := "levy"


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ink := Color(0.2, 0.1, 0.07)
	var cinnabar := Color(0.62, 0.14, 0.1)
	var box := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(box, Color(0.9, 0.84, 0.7), true)
	draw_rect(box, ink, false, 1.5)
	var mid := size * 0.5
	if kind == "spend":
		draw_circle(mid, 16, Color(0.78, 0.6, 0.28))
		draw_arc(mid, 16, 0, TAU, 24, ink, 2.0, true)
		draw_rect(Rect2(mid + Vector2(-2, -10), Vector2(4, 20)), cinnabar)
		return
	if kind == "train":
		draw_line(mid + Vector2(-8, 18), mid + Vector2(10, -16), ink, 3.0, true)
		draw_colored_polygon(PackedVector2Array([
			mid + Vector2(6, -18),
			mid + Vector2(16, -8),
			mid + Vector2(4, -6),
		]), cinnabar)
		return
	draw_line(mid + Vector2(0, 18), mid + Vector2(0, -8), Color(0.35, 0.48, 0.22), 3.0, true)
	draw_line(mid + Vector2(0, 2), mid + Vector2(-12, -6), Color(0.35, 0.48, 0.22), 2.0, true)
	draw_line(mid + Vector2(0, -2), mid + Vector2(12, -10), Color(0.35, 0.48, 0.22), 2.0, true)
	draw_circle(mid + Vector2(0, -12), 4.0, Color(0.72, 0.58, 0.22))
