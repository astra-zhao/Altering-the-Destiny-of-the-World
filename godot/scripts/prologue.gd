extends Control
## 开篇三张字卡。每张约 7 秒，点击或空格进下一张。最后一张进登基夜，不把同一次按键再送给推镜。
## 文字框按 Alice v1.4：(160, 160, 960, 360)。

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
var _dots: Control


func _ready() -> void:
	UiKit.boot()
	Campaign.release_skip_guard_if_idle()
	_build()
	_show()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = UiKit.tex("bg_story_s1.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := TextureRect.new()
	shade.texture = _prologue_shade()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -640
	stage.offset_top = -360
	stage.offset_right = 640
	stage.offset_bottom = 360
	add_child(stage)
	var panel := UiKit.nine("panel_frame_l.png", 26)
	panel.name = "PrologueCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(160, 160)
	panel.size = Vector2(960, 360)
	stage.add_child(panel)
	_body = UiKit.label("", _spaced(UiKit.serif, 3), 26, Color("F5EDE0"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.add_theme_constant_override("line_spacing", 22)
	_body.position = Vector2(98, 74)
	_body.size = Vector2(764, 204)
	panel.add_child(_body)
	_dots = Control.new()
	_dots.position = Vector2(613, 624)
	_dots.size = Vector2(54, 12)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	stage.add_child(_dots)
	var hint := UiKit.label("点击或空格跳过", UiKit.sans_bold, 14, Color("CDBB97"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 678)
	hint.size = Vector2(1280, 20)
	stage.add_child(hint)


func _draw_dots() -> void:
	for i in LINES.size():
		var center := Vector2(5 + i * 22, 6)
		if i == _index:
			_dots.draw_circle(center, 5, Color("D4A84B"))
		else:
			_dots.draw_arc(center, 4.2, 0, TAU, 24, Color("D4A84B"), 1.5, true)


func _prologue_shade() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	gradient.colors = PackedColorArray([
		Color8(6, 4, 2, 184),
		Color8(6, 4, 2, 140),
		Color8(6, 4, 2, 199),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0.5, 0)
	tex.fill_to = Vector2(0.5, 1)
	return tex


func _spaced(font: Font, pixels: int) -> Font:
	if font == null:
		return font
	var varied := FontVariation.new()
	varied.base_font = font
	varied.spacing_glyph = pixels
	return varied


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
	if _dots != null:
		_dots.queue_redraw()


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
