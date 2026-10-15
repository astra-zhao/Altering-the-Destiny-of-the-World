extends Button
## 城印。名称和兵力是字体，不烤在 city_badge 上。
## 切图只有 normal / hover / selected。按下时用 selected，让按下这一下能看见。

const UiKit := preload("res://scripts/ui_kit.gd")

const _SIZE := Vector2(172, 168)
const _BADGE := Vector2(104, 104)
const _RING := Vector2(160, 160)

var city_name := ""
var owner_name := ""
var troops := 0
var marked := false
var hinted := false
var yuan_here := false
var holding := false

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
	_name = UiKit.label("", UiKit.serif, 20, UiKit.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.outline(_name, 6)
	add_child(_name)
	_num = UiKit.label("", UiKit.serif, 22, UiKit.CREAM)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.outline(_num, 4)
	add_child(_num)
	_layout()
	_paint()


func badge_center() -> Vector2:
	return Vector2(_SIZE.x * 0.5, 22.0 + _BADGE.y * 0.5)


func redraw() -> void:
	_paint()


func _layout() -> void:
	_name.position = Vector2(-16, 0)
	_name.size = Vector2(_SIZE.x + 32, 22)
	var badge_pos := Vector2((_SIZE.x - _BADGE.x) * 0.5, 22)
	_badge.position = badge_pos
	_badge.size = _BADGE
	var ring_pos := badge_pos + (_BADGE - _RING) * 0.5
	_ring.position = ring_pos
	_ring.size = _RING
	_num.position = badge_pos + Vector2(0, 28)
	_num.size = Vector2(_BADGE.x, 44)


func _paint() -> void:
	if _badge == null:
		return
	var kind := "jin"
	if owner_name == "明":
		kind = "ming"
	elif owner_name == "争议":
		kind = "contested"
	var state := "normal"
	if marked or _down:
		state = "selected"
	elif _hover or hinted:
		state = "hover"
	_badge.texture = UiKit.tex("city_badge_%s_%s.png" % [kind, state])
	_ring.visible = marked
	var title := city_name
	if yuan_here:
		title += " · 袁"
	if holding:
		title += " · 守"
	_name.text = title
	_num.text = str(troops)
	z_index = 0


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
