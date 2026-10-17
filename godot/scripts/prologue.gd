extends Control
## 开篇三张字卡。每张约 7 秒，点击或空格进下一张。最后一张进登基夜，不把同一次按键再送给推镜。

const HALL := preload("res://scenes/s1_night.tscn")
const UiKit := preload("res://scripts/ui_kit.gd")
const CARD_SEC := 7.0
const LINES: PackedStringArray = [
	"天启七年，熹宗驾崩。十七岁的信王朱由检，在一夜之间成了大明天子。",
	"朝堂上阉党余波未平，陕北连年大旱，辽东后金兵临城下，国库里没有多少银子。",
	"史书里，这个王朝只剩十七年。这一次，由你来选。",
]

var _index := 0
var _left := CARD_SEC
var _leaving := false
var _timer_on := true
var _cooldown := 0.0
var _body: Label
var _count: Label


func _ready() -> void:
	UiKit.boot()
	Campaign.release_skip_guard_if_idle()
	var hall := HALL.instantiate()
	hall.backdrop_only = true
	hall.name = "Hall"
	add_child(hall)
	move_child(hall, 0)
	_build()
	_show()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()


func _build() -> void:
	var shade := TextureRect.new()
	shade.texture = UiKit.tex("shade_story.png")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate = Color(1, 1, 1, 0.88)
	add_child(shade)
	var panel := UiKit.nine("panel_frame_l.png", 26)
	panel.name = "PrologueCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_top = -150
	panel.offset_right = 460
	panel.offset_bottom = 150
	add_child(panel)
	_count = UiKit.label("", UiKit.sans, 16, UiKit.GOLD)
	_count.position = Vector2(36, 28)
	_count.size = Vector2(200, 28)
	panel.add_child(_count)
	_body = UiKit.label("", UiKit.serif, 30, Color("FFF3D6"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.position = Vector2(48, 72)
	_body.size = Vector2(824, 180)
	panel.add_child(_body)
	var hint := UiKit.label("点击或按空格继续", UiKit.sans, 16, UiKit.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -280
	hint.offset_top = -48
	hint.offset_right = -28
	hint.offset_bottom = -16
	add_child(hint)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if _leaving or not _timer_on:
		return
	_left -= delta
	if _left <= 0.0:
		_advance(false)


func _show() -> void:
	_body.text = LINES[_index]
	_count.text = "%d / %d" % [_index + 1, LINES.size()]


func card_text() -> String:
	return LINES[_index]


func card_index() -> int:
	return _index


func present(index: int) -> void:
	_index = clampi(index, 0, LINES.size() - 1)
	_timer_on = false
	_left = CARD_SEC
	_show()


func advance_for_test() -> void:
	_cooldown = 0.0
	_advance(true)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if Campaign.swallow_skip_guard(event):
		get_viewport().set_input_as_handled()
		return
	if not _is_advance(event):
		return
	get_viewport().set_input_as_handled()
	_advance(true)


func _is_advance(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		return key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
	return false


func _advance(from_input: bool) -> void:
	if _leaving or _cooldown > 0.0:
		return
	_cooldown = 0.05
	if _index >= LINES.size() - 1:
		_leaving = true
		_timer_on = false
		if from_input:
			Campaign.arm_skip_guard()
		_enter_s1()
		return
	_index += 1
	_left = CARD_SEC
	_show()


func _enter_s1() -> void:
	if str(Campaign.pending_story) != "s1":
		Campaign.pending_story = "s1"
	Bgm.set_mode("story")
	get_tree().change_scene_to_file("res://scenes/s1_night.tscn")
