extends Control
## 引导高亮。画在自己的 _draw 里，不挡点击。

var target: Control
var pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not visible:
		return
	pulse += delta
	queue_redraw()


func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var rect := target.get_global_rect()
	rect.position -= global_position
	rect = rect.grow(8.0)
	var alpha := 0.55 + 0.45 * absf(sin(pulse * 3.0))
	draw_rect(rect, Color(0.95, 0.82, 0.35, alpha), false, 4.0)
