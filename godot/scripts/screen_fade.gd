extends CanvasLayer
## 切场景时从墨色淡入。不挡鼠标，也不改音频。

var _rect: ColorRect


func _ready() -> void:
	layer = 80
	_rect = ColorRect.new()
	_rect.color = Color(0.05, 0.03, 0.02, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func fade_in() -> void:
	if _rect == null:
		return
	_rect.color = Color(0.05, 0.03, 0.02, 1)
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, 0.35)
