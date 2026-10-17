extends Node3D
## S2 袁崇焕生死。朝堂与法场两个机位，写回后回大地图。剧情中不提供存档。

const Kit := preload("res://scripts/story_kit.gd")

var _camera: Camera3D
var _choices: VBoxContainer
var _sub: Label
var _court := Vector3(0.2, 3.4, 7.4)
var _field := Vector3(5.6, 2.5, 1.6)
var _choice_cam := Vector3(1.4, 2.7, 5.2)
var _look_court := Vector3(0.0, 1.3, -2.2)
var _look_field := Vector3(4.2, 0.9, -0.6)


func _ready() -> void:
	_build_world()
	_build_ui()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	_camera.position = _court
	_aim(_look_court)
	var tween := create_tween()
	tween.tween_method(_move.bind(_court, _field, _look_court, _look_field), 0.0, 1.0, 1.35)
	tween.tween_interval(0.25)
	tween.tween_method(_move.bind(_field, _choice_cam, _look_field, _look_court), 0.0, 1.0, 1.15)
	tween.tween_callback(_reveal)


func _move(weight: float, start: Vector3, finish: Vector3, look_a: Vector3, look_b: Vector3) -> void:
	_camera.position = start.lerp(finish, weight)
	_aim(look_a.lerp(look_b, weight))


func _aim(point: Vector3) -> void:
	_camera.look_at(point, Vector3.UP)


func _reveal() -> void:
	_sub.text = "选定后立刻写回。D 要先在登基夜结交袁。"
	_choices.visible = true


func _look_mode(mode: String) -> void:
	var tween := create_tween()
	if mode == "field":
		tween.tween_method(_move.bind(_camera.position, _field, _look_court, _look_field), 0.0, 1.0, 0.7)
		_sub.text = "法场。处死走这里。"
	else:
		tween.tween_method(_move.bind(_camera.position, _court, _look_field, _look_court), 0.0, 1.0, 0.7)
		_sub.text = "朝堂。赦与复职走这里。"


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s2(choice_id)
	if not bool(result.get("ok", false)):
		_sub.text = str(result.get("message", ""))
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _build_world() -> void:
	var world := WorldEnvironment.new()
	world.environment = Kit.night_environment(Color(0.03, 0.035, 0.06), Color(0.1, 0.08, 0.12))
	add_child(world)
	Kit.moon(self, 0.9, Vector3(-50, 20, 0), Color(0.7, 0.76, 0.95))
	Kit.moon(self, 0.28, Vector3(-18, 160, 0), Color(0.95, 0.7, 0.42))
	var warm := OmniLight3D.new()
	warm.position = Vector3(0.2, 2.4, -1.5)
	warm.light_color = Color(1.0, 0.72, 0.4)
	warm.light_energy = 2.2
	warm.omni_range = 9.0
	add_child(warm)
	var field_light := OmniLight3D.new()
	field_light.position = Vector3(4.2, 2.2, -0.4)
	field_light.light_color = Color(0.95, 0.35, 0.2)
	field_light.light_energy = 1.6
	field_light.omni_range = 6.0
	add_child(field_light)

	var court := Node3D.new()
	court.name = "Court"
	add_child(court)
	Kit.box(court, "Floor", Vector3(16, 0.2, 18), Vector3(1.5, -0.1, 0), Color(0.22, 0.2, 0.18))
	Kit.box(court, "Dais", Vector3(3.2, 0.35, 2.4), Vector3(0, 0.2, -2.4), Color(0.32, 0.08, 0.07), 0.1)
	Kit.box(court, "Seat", Vector3(1.3, 0.22, 0.8), Vector3(0, 0.55, -2.5), Color(0.72, 0.54, 0.22), 0.6)
	Kit.box(court, "Back", Vector3(1.5, 1.6, 0.16), Vector3(0, 1.4, -2.95), Color(0.32, 0.08, 0.07), 0.1)
	Kit.cylinder(court, "PillarL", 0.28, 3.6, Vector3(-2.4, 1.8, -1.2), Color(0.34, 0.1, 0.08))
	Kit.cylinder(court, "PillarR", 0.28, 3.6, Vector3(2.4, 1.8, -1.2), Color(0.34, 0.1, 0.08))
	Kit.box(court, "Yard", Vector3(4.2, 0.08, 3.4), Vector3(4.2, 0.02, -0.4), Color(0.28, 0.12, 0.1))
	Kit.cylinder(court, "PostL", 0.08, 2.2, Vector3(3.4, 1.1, -0.8), Color(0.15, 0.1, 0.08))
	Kit.cylinder(court, "PostR", 0.08, 2.2, Vector3(5.0, 1.1, -0.8), Color(0.15, 0.1, 0.08))
	Kit.box(court, "Beam", Vector3(1.8, 0.1, 0.1), Vector3(4.2, 2.15, -0.8), Color(0.2, 0.12, 0.1))

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.fov = 52.0
	add_child(_camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var title := Label.new()
	title.text = "袁崇焕生死"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76))
	column.add_child(title)
	_sub = Label.new()
	_sub.text = "朝堂与法场。镜头先看杀，再回到抉择。"
	_sub.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	column.add_child(_sub)
	Kit.install_font(_sub)
	var look_row := HBoxContainer.new()
	column.add_child(look_row)
	var court_btn := Button.new()
	court_btn.text = "看朝堂"
	court_btn.pressed.connect(_look_mode.bind("court"))
	look_row.add_child(court_btn)
	var field_btn := Button.new()
	field_btn.text = "看法场"
	field_btn.pressed.connect(_look_mode.bind("field"))
	look_row.add_child(field_btn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_choices = VBoxContainer.new()
	_choices.visible = false
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)
	_add_choice("A", "A. 处死\n袁=已死，辽东 -20，后金压力 +15，世界线 +5")
	_add_choice("B", "B. 下狱\n袁=闲置，辽东 -8，世界线 +15")
	_add_choice("C", "C. 复辽职\n袁=前线可用，辽东 +12，银 -10，民心 -5，世界线 +30")
	var locked := not Campaign.befriended_yuan
	var d_text := "D. 调京营\n袁=京营，辽东 +4，世界线 +20"
	if locked:
		d_text += "\n尚未结交袁，不能选"
	_add_choice("D", d_text, locked)


func _add_choice(choice_id: String, text: String, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 58)
	button.disabled = disabled
	button.pressed.connect(_choose.bind(choice_id))
	_choices.add_child(button)
