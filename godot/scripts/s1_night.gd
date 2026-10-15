extends Node3D
## S1 登基夜。低模夜殿，镜头推近之后才放出 A/B/C。写回规则仍在 Campaign.apply_s1。

const Kit := preload("res://scripts/story_kit.gd")
const StoryBoard := preload("res://scripts/story_board.gd")
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
	Kit.install_font($UI)
	_orient_lights()
	_polish_light()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
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


func _polish_light() -> void:
	var env := $WorldEnvironment.environment as Environment
	if env != null:
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_strength = 0.85
		env.glow_bloom = 0.16
		env.glow_hdr_threshold = 0.8
		env.fog_enabled = true
		env.fog_light_color = Color(0.16, 0.12, 0.18)
		env.fog_density = 0.014
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.ambient_light_energy = 0.55
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(0.95, 0.72, 0.42)
	rim.light_energy = 0.38
	rim.rotation_degrees = Vector3(-24, -150, 0)
	add_child(rim)


func _on_push(weight: float) -> void:
	_camera.position = _CAM_START.lerp(_CAM_END, weight)
	_camera.fov = lerpf(_FOV_START, _FOV_END, weight)
	_aim()


func _aim() -> void:
	_camera.look_at(_look.global_position, Vector3.UP)


func _reveal_choices() -> void:
	_choices.visible = false
	var layout := get_node_or_null("UI/Layout") as CanvasItem
	if layout != null:
		layout.visible = false
	if $UI.get_node_or_null("StoryBoard") != null:
		return
	StoryBoard.mount($UI, {
		"which": "s1",
		"kicker": "剧情 1/3",
		"title": "登基夜",
		"sub": "先看清朝局，再定这一夜怎么走。",
		"on_choose": _choose,
		"choices": [
			{"id": "A", "title": "先稳朝堂", "parts": [{"text": "银两 +5", "kind": "gain"}, {"text": "世界线 +5", "kind": "world"}]},
			{"id": "B", "title": "先重辽东", "parts": [{"text": "辽东 +8", "kind": "gain"}, {"text": "银两 -5", "kind": "cost"}, {"text": "结交袁", "kind": "status"}, {"text": "世界线 +10", "kind": "world"}]},
			{"id": "C", "title": "先安民", "parts": [{"text": "民心 +10", "kind": "gain"}, {"text": "粮草 -5", "kind": "cost"}, {"text": "世界线 +5", "kind": "world"}]},
		],
	})


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s1(choice_id)
	if not bool(result.get("ok", false)):
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")
