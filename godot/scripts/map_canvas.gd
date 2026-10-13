extends Control
## 示意地图：羊皮纸底、渤海色块、城池邻接线。城钮由 big_map.gd 叠在同一坐标系上。

const Baseline := preload("res://data/campaign_baseline.gd")

const _INK := Color(0.32, 0.23, 0.15, 0.88)
const _INK_SOFT := Color(0.36, 0.26, 0.17, 0.55)
const _PAPER := Color(0.851, 0.78, 0.651, 1)
const _WATER := Color(0.42, 0.55, 0.58, 0.42)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var sz := size
	if sz.x < 32.0 or sz.y < 32.0:
		return
	draw_rect(Rect2(Vector2.ZERO, sz), _PAPER, true)
	_draw_water(sz)
	draw_rect(Rect2(Vector2(10, 10), sz - Vector2(20, 20)), Color(0.45, 0.34, 0.22, 0.28), false, 1.5)
	_draw_routes(sz)
	_draw_captions(sz)


func _draw_water(sz: Vector2) -> void:
	var water := PackedVector2Array([
		Vector2(0.50 * sz.x, sz.y),
		Vector2(sz.x, sz.y),
		Vector2(sz.x, 0.58 * sz.y),
		Vector2(0.78 * sz.x, 0.66 * sz.y),
		Vector2(0.58 * sz.x, 0.82 * sz.y),
	])
	draw_colored_polygon(water, _WATER)


func _draw_routes(sz: Vector2) -> void:
	for route in Baseline.ROUTES:
		var a := _city_point(str(route["a"]), sz)
		var b := _city_point(str(route["b"]), sz)
		if a == Vector2.INF or b == Vector2.INF:
			continue
		if bool(route["far"]):
			draw_dashed_line(a, b, _INK_SOFT, 1.6, 8.0, true, true)
			_draw_caption((a + b) * 0.5 + Vector2(8, -8), "远", 13, _INK)
		else:
			draw_line(a, b, _INK, 2.0, true)
		draw_circle(a, 4.0, _INK)
		draw_circle(b, 4.0, _INK)


func _draw_captions(sz: Vector2) -> void:
	_draw_caption(Vector2(0.08, 0.10) * sz, "西", 14, _INK_SOFT)
	_draw_caption(Vector2(0.78, 0.08) * sz, "东北", 14, _INK_SOFT)
	_draw_caption(Vector2(0.20, 0.62) * sz, "畿辅", 15, _INK_SOFT)
	_draw_caption(Vector2(0.60, 0.48) * sz, "辽东", 15, _INK_SOFT)
	_draw_caption(Vector2(0.72, 0.86) * sz, "渤海（示意）", 13, Color(0.22, 0.32, 0.36, 0.7))


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
