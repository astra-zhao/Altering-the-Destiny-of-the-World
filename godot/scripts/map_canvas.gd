extends Control
## 只画邻接线。底图是 bg_map_liaodong，城的落点由大地图按示意坐标摆。
## 实线是普通邻接，虚线是 campaign_baseline 里 far=true 的远邻（大同—宁远）。

const Baseline := preload("res://data/campaign_baseline.gd")
const UiKit := preload("res://scripts/ui_kit.gd")

var _points: Dictionary = {}


func _ready() -> void:
	UiKit.boot()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_points(points: Dictionary) -> void:
	_points = points
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	var solid := Color(0.831, 0.659, 0.294, 0.92)
	var faded := Color(0.831, 0.659, 0.294, 0.55)
	for route in Baseline.ROUTES:
		var a: Vector2 = _points.get(str(route["a"]), Vector2.INF)
		var b: Vector2 = _points.get(str(route["b"]), Vector2.INF)
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if bool(route["far"]):
			draw_dashed_line(a, b, faded, 2.0, 9.0, true, true)
			_draw_route_label(a, b, "运粮")
		else:
			draw_line(a, b, solid, 2.4, true)
	var sea: Vector2 = size * Vector2(0.80, 0.84)
	_draw_caption(sea, "渤海", 28, Color(0.62, 0.74, 0.8, 0.78))


func _draw_route_label(a: Vector2, b: Vector2, text: String) -> void:
	var delta := b - a
	if delta.length() < 8.0:
		return
	var mid := (a + b) * 0.5
	var normal := Vector2(-delta.y, delta.x).normalized()
	_draw_caption(mid + normal * 14.0 + Vector2(-18, -8), text, 15, UiKit.GOLD)


func _draw_caption(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := UiKit.sans if font_size < 24 else UiKit.serif
	if font == null:
		font = ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.08, 0.05, 0.03, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
