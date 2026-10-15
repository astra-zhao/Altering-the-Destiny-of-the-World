extends RefCounted
## v1.2 切图与字体。文字一律走字体节点，不烤进图。
## 九宫格边距与 README-切图清单.md 一致。

const DIR := "res://assets/ui/"

const GOLD := Color("d4a84b")
const CREAM := Color("f5ede0")
const GAIN := Color("9ad98a")
const LOSS := Color("f0a27a")
const CINNABAR := Color("8b1e1e")
const WARN := Color("e85d4c")
const INK := Color("2a1810")
const INK_SOFT := Color("5c4632")

static var serif: Font
static var sans: Font
static var sans_bold: Font
static var _textures: Dictionary = {}


static func boot() -> void:
	if serif != null:
		return
	serif = _load_font("NotoSerifSC-Bold.otf")
	sans = _load_font("NotoSansSC-Regular.otf")
	sans_bold = _load_font("NotoSansSC-Bold.otf")


static func tex(file_name: String) -> Texture2D:
	if _textures.has(file_name):
		return _textures[file_name]
	var loaded: Variant = load(DIR + file_name)
	var texture := loaded as Texture2D
	_textures[file_name] = texture
	return texture


static func nine(file_name: String, left: int, top: int = -1, right: int = -1, bottom: int = -1) -> NinePatchRect:
	var node := NinePatchRect.new()
	node.texture = tex(file_name)
	node.patch_margin_left = left
	node.patch_margin_top = left if top < 0 else top
	node.patch_margin_right = left if right < 0 else right
	node.patch_margin_bottom = left if bottom < 0 else bottom
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func style_tex(file_name: String, margin: int, pad: int = -1) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex(file_name)
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	var inset := pad if pad >= 0 else maxi(4, margin - 8)
	box.content_margin_left = inset
	box.content_margin_top = inset
	box.content_margin_right = inset
	box.content_margin_bottom = inset
	return box


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node


static func outline(node: Label, size: int = 5) -> void:
	node.add_theme_constant_override("outline_size", size)
	node.add_theme_color_override("font_outline_color", Color(0.07, 0.04, 0.03, 0.92))


static func icon_rect(file_name: String, px: float) -> TextureRect:
	var node := TextureRect.new()
	node.texture = tex(file_name)
	node.custom_minimum_size = Vector2(px, px)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return node


static func painted_button(text: String, filled: bool, wide: float = 220) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(wide, 46)
	if serif != null:
		button.add_theme_font_override("font", serif)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("fff6e4"))
	button.add_theme_color_override("font_pressed_color", CREAM)
	var normal := StyleBoxFlat.new()
	normal.bg_color = CINNABAR if filled else Color(0.16, 0.1, 0.07, 0.94)
	normal.border_color = GOLD
	normal.set_border_width_all(2)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.14)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button


static func link_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	if sans != null:
		button.add_theme_font_override("font", sans)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 8
	empty.content_margin_right = 8
	empty.content_margin_top = 4
	empty.content_margin_bottom = 4
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	return button


static func seal_button(prefix: String) -> TextureButton:
	var button := TextureButton.new()
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	paint_seal(button, prefix, false, false)
	return button


static func paint_seal(button: TextureButton, prefix: String, picked: bool, hovering: bool = false) -> void:
	button.modulate = Color.WHITE
	button.self_modulate = Color.WHITE
	var face := "normal"
	if button.disabled:
		face = "disabled"
	elif picked:
		face = "selected"
	elif hovering:
		face = "hover"
	var hover_face := "selected" if picked else "hover"
	var pressed_face := "selected" if picked else "pressed"
	if button.disabled:
		hover_face = "disabled"
		pressed_face = "disabled"
	button.texture_normal = tex("%s_%s.png" % [prefix, face])
	button.texture_hover = tex("%s_%s.png" % [prefix, hover_face])
	button.texture_pressed = tex("%s_%s.png" % [prefix, pressed_face])
	button.texture_disabled = tex("%s_disabled.png" % prefix)
	button.texture_focused = tex("%s_%s.png" % [prefix, hover_face])


static func _load_font(file_name: String) -> Font:
	var loaded: Variant = load(DIR + file_name)
	var font := loaded as Font
	if font == null:
		return load("res://theme/WenQuanYiMicroHei.ttf") as Font
	var wen := load("res://theme/WenQuanYiMicroHei.ttf") as Font
	if wen != null and font is FontFile:
		var file := font as FontFile
		var seen := false
		for item in file.fallbacks:
			if item == wen:
				seen = true
				break
		if not seen:
			file.fallbacks.append(wen)
	return font
