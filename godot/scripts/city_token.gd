extends Button
## 城印。名称和兵力是字体，不烤在 city_badge 上。
## 切图只有 normal / hover / selected。按下时用 selected，让按下这一下能看见。

const UiKit := preload("res://scripts/ui_kit.gd")

const _SIZE := Vector2(160, 160)
const _BADGE := Vector2(104, 104)
const _RING := Vector2(160, 160)
const _NAME_LIMIT := 78.0

var city_name := ""
var owner_name := ""
var troops := 0
var marked := false
var hinted := false
var lit := false
var yuan_here := false
var holding := false
var paint_count := 0

var _ring: TextureRect
var _badge: TextureRect
var _name: Label
var _num: Label
var _hover := false
var _down := false


func _ready() -> void:
	UiKit.boot()
	custom_minimum_size = _SIZE
	size = _SIZE
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	_ring = TextureRect.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.texture = UiKit.tex("ring_select.png")
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring.visible = false
	add_child(_ring)
	_badge = TextureRect.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_badge)
	_name = UiKit.label("", UiKit.serif, 15, UiKit.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiKit.outline(_name, 4)
	add_child(_name)
	_num = UiKit.label("", UiKit.serif, 20, UiKit.CREAM)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.outline(_num, 4)
	add_child(_num)
	_layout()
	_paint()


func badge_center() -> Vector2:
	return _SIZE * 0.5


func redraw() -> void:
	_paint()


func _layout() -> void:
	var badge_pos := (_SIZE - _BADGE) * 0.5
	_badge.position = badge_pos
	_badge.size = _BADGE
	_ring.position = badge_pos + (_BADGE - _RING) * 0.5
	_ring.size = _RING
	_name.position = badge_pos + Vector2((_BADGE.x - _NAME_LIMIT) * 0.5, 22)
	_name.size = Vector2(_NAME_LIMIT, 22)
	_num.position = badge_pos + Vector2(8, 46)
	_num.size = Vector2(_BADGE.x - 16, 32)


func _paint() -> void:
	if _badge == null:
		return
	paint_count += 1
	var kind := "jin"
	if owner_name == "明":
		kind = "ming"
	elif owner_name == "争议":
		kind = "contested"
	var state := "normal"
	if marked or _down:
		state = "selected"
	elif _hover or hinted or lit:
		state = "hover"
	_badge.texture = UiKit.tex("city_badge_%s_%s.png" % [kind, state])
	_ring.visible = marked or lit
	_ring.modulate = Color(1, 0.86, 0.45, 0.9) if lit and not marked else Color.WHITE
	var title := city_name
	if yuan_here:
		title += " · 袁"
	if holding:
		title += " · 守"
	_name.text = title
	_fit_title(title)
	_num.text = str(troops)
	z_index = 0


func _fit_title(title: String) -> void:
	var px := 15
	var font := UiKit.serif
	if font != null:
		while px > 10 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x > _NAME_LIMIT:
			px -= 1
	_name.add_theme_font_size_override("font_size", px)


func _on_enter() -> void:
	_hover = true
	_paint()


func _on_exit() -> void:
	_hover = false
	_down = false
	_paint()


func _on_down() -> void:
	_down = true
	_paint()


func _on_up() -> void:
	_down = false
	_paint()
