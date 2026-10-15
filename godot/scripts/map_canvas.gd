extends Control
## 程序绘制的示意地图：纸色、远山、海岸、邻接线。没有外部贴图。
## 城的位置仍是 campaign_baseline 里的示意坐标。

const Baseline := preload("res://data/campaign_baseline.gd")

const _INK := Color(0.28, 0.18, 0.12, 0.9)
const _INK_SOFT := Color(0.36, 0.24, 0.16, 0.45)
const _PAPER := Color(0.84, 0.75, 0.6, 1)
const _WATER := Color(0.38, 0.5, 0.54, 0.55)
const _MOUNT := Color(0.42, 0.36, 0.3, 0.28)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var sz := size
	if sz.x < 32.0 or sz.y < 32.0:
		return
	draw_rect(Rect2(Vector2.ZERO, sz), _PAPER, true)
	_draw_wash(sz)
	_draw_mountains(sz)
	_draw_water(sz)
	draw_rect(Rect2(Vector2(8, 8), sz - Vector2(16, 16)), Color(0.35, 0.22, 0.12, 0.55), false, 2.0)
	_draw_routes(sz)
	_draw_captions(sz)


func _draw_wash(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, sz.y * 0.62), Vector2(sz.x * 0.46, sz.y * 0.38)), Color(0.78, 0.68, 0.5, 0.35), true)
	draw_circle(Vector2(sz.x * 0.22, sz.y * 0.3), sz.y * 0.22, Color(0.9, 0.82, 0.66, 0.35))
	draw_rect(Rect2(Vector2(sz.x * 0.58, 0), Vector2(sz.x * 0.2, sz.y * 0.5)), Color(0.72, 0.6, 0.44, 0.18), true)


func _draw_mountains(sz: Vector2) -> void:
	var ridges := [
		[Vector2(0.04, 0.42), Vector2(0.12, 0.22), Vector2(0.2, 0.4), Vector2(0.28, 0.18), Vector2(0.36, 0.38)],
		[Vector2(0.62, 0.22), Vector2(0.7, 0.08), Vector2(0.78, 0.2), Vector2(0.86, 0.06), Vector2(0.96, 0.18)],
	]
	for ridge in ridges:
		var poly := PackedVector2Array()
		for point in ridge:
			poly.append(Vector2(point) * sz)
		poly.append(Vector2(ridge[-1].x, ridge[0].y + 0.08) * sz)
		poly.append(Vector2(ridge[0].x, ridge[0].y + 0.08) * sz)
		draw_colored_polygon(poly, _MOUNT)


func _draw_water(sz: Vector2) -> void:
	var water := PackedVector2Array([
		Vector2(0.48 * sz.x, sz.y),
		Vector2(sz.x, sz.y),
		Vector2(sz.x, 0.55 * sz.y),
		Vector2(0.8 * sz.x, 0.62 * sz.y),
		Vector2(0.62 * sz.x, 0.78 * sz.y),
	])
	draw_colored_polygon(water, _WATER)
	draw_polyline(water, Color(0.22, 0.32, 0.36, 0.35), 1.5, true)


func _draw_routes(sz: Vector2) -> void:
	for route in Baseline.ROUTES:
		var a := _city_point(str(route["a"]), sz)
		var b := _city_point(str(route["b"]), sz)
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if bool(route["far"]):
			draw_dashed_line(a, b, _INK_SOFT, 1.6, 8.0, true, true)
		else:
			draw_line(a, b, _INK, 2.2, true)


func _draw_captions(sz: Vector2) -> void:
	_draw_caption(Vector2(0.06, 0.08) * sz, "西", 15, _INK_SOFT)
	_draw_caption(Vector2(0.8, 0.08) * sz, "东北", 15, _INK_SOFT)
	_draw_caption(Vector2(0.18, 0.58) * sz, "畿辅", 16, _INK_SOFT)
	_draw_caption(Vector2(0.58, 0.46) * sz, "辽东", 16, _INK_SOFT)
	_draw_caption(Vector2(0.7, 0.88) * sz, "海（示意）", 13, Color(0.18, 0.28, 0.32, 0.75))


func _draw_caption(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _city_point(id: String, sz: Vector2) -> Vector2:
	var city := Baseline.city_by_id(id)
	if city.is_empty():
		return Vector2.INF
	return city["pos"] * sz
