extends Node3D
## S1 登基夜。低模夜殿，镜头推近之后才放出 A/B/C。写回规则仍在 Campaign.apply_s1。

const _PUSH_SEC := 2.15
const _CAM_START := Vector3(0, 6.4, 12.2)
const _CAM_END := Vector3(0, 2.85, 3.15)
const _FOV_START := 62.0
const _FOV_END := 46.0

@onready var _camera: Camera3D = $Camera3D
@onready var _look: Marker3D = $LookTarget
@onready var _choices: Control = $UI/Layout/Column/Choices
@onready var _sub: Label = $UI/Layout/Column/Sub


func _ready() -> void:
	_install_font_fallback()
	_orient_lights()
	Bgm.set_mode("story")
	_choices.visible = false
	_sub.text = "宫城夜景 · 镜头推近"
	_camera.position = _CAM_START
	_camera.fov = _FOV_START
	_aim()
	var tween := create_tween()
	tween.tween_method(_on_push, 0.0, 1.0, _PUSH_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_reveal_choices)


func _orient_lights() -> void:
	$MoonLight.rotation_degrees = Vector3(-58, 32, 0)
	$FillLight.rotation_degrees = Vector3(-18, 168, 0)


func _on_push(weight: float) -> void:
	_camera.position = _CAM_START.lerp(_CAM_END, weight)
	_camera.fov = lerpf(_FOV_START, _FOV_END, weight)
	_aim()


func _aim() -> void:
	_camera.look_at(_look.global_position, Vector3.UP)


func _reveal_choices() -> void:
	_sub.text = "选定后立刻写回局面，回到大地图。"
	_choices.visible = true
	_choices.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_choices, "modulate:a", 1.0, 0.4)


func _install_font_fallback() -> void:
	var font := _sub.get_theme_font("font")
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s1(choice_id)
	if not bool(result.get("ok", false)):
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
