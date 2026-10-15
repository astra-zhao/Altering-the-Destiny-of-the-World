extends Control
## 只画邻接线。底图是 bg_map_liaodong，城的落点由大地图按示意坐标摆。
## 实线是普通邻接，虚线是 campaign_baseline 里 far=true 的远邻（大同—宁远）。

const Baseline := preload("res://data/campaign_baseline.gd")
const UiKit := preload("res://scripts/ui_kit.gd")

var _points: Dictionary = {}
var _hot: Array = []
var redraw_count := 0


func _ready() -> void:
	UiKit.boot()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_points(points: Dictionary) -> void:
	_points = points
	queue_redraw()


func set_hot(routes: Array) -> void:
	if _same_hot(routes):
		return
	_hot = routes.duplicate(true)
	queue_redraw()


func _same_hot(routes: Array) -> bool:
	if routes.size() != _hot.size():
		return false
	for i in routes.size():
		var next: Dictionary = routes[i]
		var prev: Dictionary = _hot[i]
		if str(next.get("a", "")) != str(prev.get("a", "")):
			return false
		if str(next.get("b", "")) != str(prev.get("b", "")):
			return false
		if bool(next.get("far", false)) != bool(prev.get("far", false)):
			return false
	return true


func _hot_far(a_id: String, b_id: String) -> bool:
	for route in _hot:
		var left := str(route.get("a", ""))
		var right := str(route.get("b", ""))
		if (left == a_id and right == b_id) or (left == b_id and right == a_id):
			return bool(route.get("far", false))
	return false


func _is_hot(a_id: String, b_id: String) -> bool:
	for route in _hot:
		var left := str(route.get("a", ""))
		var right := str(route.get("b", ""))
		if (left == a_id and right == b_id) or (left == b_id and right == a_id):
			return true
	return false


func _draw() -> void:
	redraw_count += 1
	if _points.is_empty():
		return
	var solid := Color(0.831, 0.659, 0.294, 0.92)
	var faded := Color(0.831, 0.659, 0.294, 0.55)
	var hot_color := Color(0.98, 0.86, 0.45, 1.0)
	for route in Baseline.ROUTES:
		var a_id := str(route["a"])
		var b_id := str(route["b"])
		var a: Vector2 = _points.get(a_id, Vector2.INF)
		var b: Vector2 = _points.get(b_id, Vector2.INF)
		if a == Vector2.INF or b == Vector2.INF:
			continue
		var hot := _is_hot(a_id, b_id)
		if bool(route["far"]):
			draw_dashed_line(a, b, hot_color if hot else faded, 4.0 if hot else 2.0, 9.0, true, true)
			_draw_route_label(a, b, "远邻")
		elif hot:
			draw_line(a, b, hot_color, 4.2, true)
		else:
			draw_line(a, b, solid, 2.4, true)
	var sea: Vector2 = size * Vector2(0.80, 0.84)
	_draw_caption(sea, "渤海", 28, Color(0.62, 0.74, 0.8, 0.78))


func _draw_route_label(a: Vector2, b: Vector2, text: String) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 8.0:
		return
	var dir := delta / length
	var normal := Vector2(-dir.y, dir.x)
	var font := UiKit.sans if UiKit.sans != null else ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var best := (a + b) * 0.5
	var best_score := -100000.0
	# 中点落在京师上。改到两段空隙里，并躲开顶栏和城印。
	for along_v in [0.30, 0.40, 0.60, 0.70]:
		var mid: Vector2 = a.lerp(b, float(along_v))
		for sign_v in [-1.0, 1.0]:
			var sign := float(sign_v)
			for dist_v in [32.0, 52.0, 74.0]:
				var dist := float(dist_v)
				var center: Vector2 = mid + normal * sign * dist
				var baseline: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.4)
				var box := Rect2(baseline.x - 2.0, baseline.y - text_size.y, text_size.x + 4.0, text_size.y + 4.0)
				var score := 100000.0
				for id in _points:
					score = minf(score, box.get_center().distance_to(_points[id]) - 90.0)
				if box.position.y < 148.0:
					score -= 500.0
				if box.end.x > size.x - 270.0:
					score -= 300.0
				if box.end.y > size.y - 210.0 and box.position.x < 500.0:
					score -= 300.0
				if score > best_score:
					best_score = score
					best = baseline
	_draw_caption(best, text, font_size, UiKit.GOLD)


func _draw_caption(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := UiKit.sans if font_size < 24 else UiKit.serif
	if font == null:
		font = ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.08, 0.05, 0.03, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
