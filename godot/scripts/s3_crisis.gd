extends Node3D
## S3 京师危机。城头与远处烽火，写回后回地图，再结束一回合就结算。

const Kit := preload("res://scripts/story_kit.gd")

var _camera: Camera3D
var _choices: VBoxContainer
var _sub: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	_camera.position = Vector3(-1.5, 4.6, 8.5)
	_camera.look_at(Vector3(0, 1.5, -8), Vector3.UP)
	var tween := create_tween()
	tween.tween_method(_on_push, 0.0, 1.0, 2.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_reveal)


func _on_push(weight: float) -> void:
	var start := Vector3(-1.5, 4.6, 8.5)
	var finish := Vector3(1.6, 3.1, 3.4)
	_camera.position = start.lerp(finish, weight)
	_camera.look_at(Vector3(0, 1.4, -8).lerp(Vector3(0.4, 1.6, -6), weight), Vector3.UP)


func _reveal() -> void:
	var ok := Campaign.liaodong >= 55 and Campaign.pressure <= 45
	_sub.text = "烽火在远处。勤王此刻%s。" % ("能成" if ok else "还不成（要辽东≥55且压力≤45）")
	_choices.visible = true


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s3(choice_id)
	if not bool(result.get("ok", false)):
		_sub.text = str(result.get("message", ""))
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _build_world() -> void:
	var world := WorldEnvironment.new()
	world.environment = Kit.night_environment(Color(0.05, 0.04, 0.07), Color(0.18, 0.08, 0.05))
	add_child(world)
	Kit.moon(self, 0.7, Vector3(-35, 140, 0), Color(0.75, 0.7, 0.62))
	Kit.moon(self, 0.32, Vector3(-12, -40, 0), Color(1.0, 0.45, 0.18))
	var stage := Node3D.new()
	add_child(stage)
	Kit.box(stage, "Ground", Vector3(22, 0.2, 24), Vector3(0, -0.1, -2), Color(0.16, 0.14, 0.12))
	Kit.box(stage, "Wall", Vector3(14, 2.4, 0.8), Vector3(0, 1.2, -1.2), Color(0.32, 0.28, 0.24))
	Kit.box(stage, "Walk", Vector3(14, 0.2, 2.2), Vector3(0, 2.5, -0.4), Color(0.28, 0.24, 0.2))
	Kit.box(stage, "MerlonL", Vector3(0.5, 0.7, 0.4), Vector3(-4, 3.05, -1.4), Color(0.3, 0.26, 0.22))
	Kit.box(stage, "MerlonR", Vector3(0.5, 0.7, 0.4), Vector3(4, 3.05, -1.4), Color(0.3, 0.26, 0.22))
	Kit.box(stage, "Hall", Vector3(6, 2.2, 3), Vector3(-4.5, 1.1, 2.4), Color(0.22, 0.12, 0.1))
	for i in 3:
		var x := -2.0 + float(i) * 2.2
		Kit.sphere(stage, "Fire%d" % i, 0.45, Vector3(x, 0.7, -8.5), Color(1.0, 0.42, 0.08), true)
		var light := OmniLight3D.new()
		light.position = Vector3(x, 1.2, -8.0)
		light.light_color = Color(1.0, 0.45, 0.12)
		light.light_energy = 2.4
		light.omni_range = 8.0
		stage.add_child(light)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.fov = 55.0
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
	title.text = "京师危机"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	column.add_child(title)
	_sub = Label.new()
	_sub.text = "城头夜色，远处烽火。镜头推近之后再选。"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_color", Color(0.86, 0.8, 0.72))
	column.add_child(_sub)
	Kit.install_font(_sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_choices = VBoxContainer.new()
	_choices.visible = false
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)
	_add("A", "A. 倾国勤王\n辽东≥55 且后金压力≤45 才标勤王成功，并压力 -8、世界线 +5；否则世界线 +2、民心 -3")
	_add("B", "B. 固守以拖待变\n民心 +6，辽东 +3，世界线 +4")
	_add("C", "C. 开海税补饷\n银两 +20，民心 -8，世界线 +10")


func _add(choice_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 64)
	button.pressed.connect(_choose.bind(choice_id))
	_choices.add_child(button)
