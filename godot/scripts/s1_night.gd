extends Node3D
## S1 登基夜。构图和灯光按 v1.4 画面方向。写回仍走 Campaign.apply_s1。
## 文字卡片和遮罩由 StoryBoard 叠上，这里不改。

const Kit := preload("res://scripts/story_kit.gd")
const StoryBoard := preload("res://scripts/story_board.gd")
const UiKit := preload("res://scripts/ui_kit.gd")
const _HALL_AUDIO := preload("res://audio/s1/hall.ogg")
const _TEX := {
	"floor_brick.png": preload("res://assets/s1/floor_brick.png"),
	"column_lacquer.png": preload("res://assets/s1/column_lacquer.png"),
	"screen_panel.png": preload("res://assets/s1/screen_panel.png"),
	"throne_face.png": preload("res://assets/s1/throne_face.png"),
	"window_lattice.png": preload("res://assets/s1/window_lattice.png"),
	"shaft.png": preload("res://assets/s1/shaft.png"),
	"fog_sheet.png": preload("res://assets/s1/fog_sheet.png"),
	"mote.png": preload("res://assets/s1/mote.png"),
	"lantern_glow.png": preload("res://assets/s1/lantern_glow.png"),
}
const _PUSH_SEC := 12.0
const _SKIP_SEC := 0.35
const _CAM_START := Vector3(0, 1.7, 3.0)
const _CAM_END := Vector3(0, 1.5, 0)
const _FOV := 39.6
const _PITCH := -3.3
const _ASH_AMOUNT := 90
const _DUST_AMOUNT := 80
const _PREBUILD_AT := 2.5

@onready var _camera: Camera3D = $Camera3D
@onready var _choices: Control = $UI/Layout/Column/Choices

var _flames: Array[OmniLight3D] = []
var _flame_base: Array[float] = []
var _fog_sheets: Array[MeshInstance3D] = []
var _push_tween: Tween
var _clock := 0.0
var _push_started := false
var _skipping := false
var _push_done := false
var _board: Control
var _chrome: Control
var _plaque: NinePatchRect
var _title_label: Label
var _skip_hint: Label
var _skip_from := Vector3.ZERO
var _hold_clock := false
var _warm_frames := 0
var _push_wall := 0
var _skip_wall := 0


func _ready() -> void:
	var started := Time.get_ticks_usec()
	UiKit.boot()
	_preload_story_textures()
	Kit.install_font($UI)
	_clear_old_hall()
	_build_hall()
	_build_lights()
	_build_atmosphere()
	_ambience()
	_build_push_chrome()
	Bgm.set_mode("story")
	if has_node("/root/Fade"):
		get_node("/root/Fade").fade_in()
	_choices.visible = false
	for node in _choices.get_children():
		if node is BaseButton:
			(node as BaseButton).focus_mode = Control.FOCUS_NONE
	get_viewport().gui_release_focus()
	_camera.position = _CAM_START
	_camera.fov = _FOV
	_camera.rotation_degrees = Vector3(_PITCH, 0, 0)
	_camera.near = 0.06
	_camera.far = 80.0
	_apply_chrome()
	print("S1_BUILD_MS %.2f" % [(Time.get_ticks_usec() - started) / 1000.0])
	var snap := OS.get_environment("S1_SNAP")
	if snap == "end":
		_clock = _PUSH_SEC
		_camera.position = _CAM_END
		_prebuild_board()
		_finish_reveal()
		return
	if snap == "start":
		_push_started = true
		return
	_push_started = true
	_start_push()


func _exit_tree() -> void:
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
		_push_tween = null


func _process(delta: float) -> void:
	var i := 0
	for flame in _flames:
		var wobble := 0.08 * sin(_clock * TAU * 2.4 + float(i) * 1.7)
		flame.light_energy = _flame_base[i] * (1.0 + wobble)
		i += 1
	for sheet in _fog_sheets:
		var mat := sheet.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.uv1_offset.x += delta * 0.01
	if _warm_frames > 0 and not _push_done and not _hold_clock:
		_warm_frames -= 1
		if _warm_frames == 0 and _board != null:
			_board.visible = false
	if not _push_started or _push_done or _hold_clock:
		if _hold_clock:
			_apply_chrome()
		return
	_clock += delta
	_apply_chrome()
	if _board == null and _clock >= _PREBUILD_AT:
		_prebuild_board()
	if delta >= 0.080:
		print("S1_SPIKE_MS %.2f t=%.2f" % [delta * 1000.0, _clock])


func _unhandled_input(event: InputEvent) -> void:
	if _push_done or _skipping:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_skip_push()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_ESCAPE:
			_skip_push()
			get_viewport().set_input_as_handled()


func _start_push() -> void:
	if _skipping or _push_done:
		return
	_push_started = true
	_push_wall = Time.get_ticks_usec()
	_push_tween = create_tween()
	_push_tween.tween_method(_on_push, 0.0, 1.0, _PUSH_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_push_tween.tween_callback(_finish_reveal)


func _on_push(weight: float) -> void:
	_camera.position = _CAM_START.lerp(_CAM_END, weight)
	if weight >= 1.0:
		_camera.position = _CAM_END


func _skip_push() -> void:
	if _skipping or _push_done:
		return
	_skipping = true
	_push_started = true
	_skip_wall = Time.get_ticks_usec()
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
	_skip_from = _camera.position
	_push_tween = create_tween()
	_push_tween.tween_method(_on_skip_move, 0.0, 1.0, _SKIP_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_push_tween.tween_callback(_finish_reveal)


func _on_skip_move(weight: float) -> void:
	_camera.position = _skip_from.lerp(_CAM_END, weight)
	if weight >= 1.0:
		_camera.position = _CAM_END


func snap_pose(which: String) -> void:
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
	_camera.rotation_degrees = Vector3(_PITCH, 0, 0)
	_camera.fov = _FOV
	if which == "end":
		_camera.position = _CAM_END
		_finish_reveal()
	elif which == "end_hall":
		_camera.position = _CAM_END
	else:
		_camera.position = _CAM_START


func debug_seek(seconds: float, reveal: bool = false) -> void:
	if _push_tween != null and _push_tween.is_valid():
		_push_tween.kill()
	_push_started = true
	_push_done = false
	_hold_clock = true
	_clock = seconds
	var span := clampf(seconds / _PUSH_SEC, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - span, 3.0)
	_camera.position = _CAM_START.lerp(_CAM_END, eased)
	_camera.rotation_degrees = Vector3(_PITCH, 0, 0)
	_camera.fov = _FOV
	if _chrome != null:
		_chrome.visible = true
	if _skip_hint != null:
		_skip_hint.visible = true
	_apply_chrome()
	if seconds >= _PREBUILD_AT and _board == null:
		_prebuild_board()
	if reveal:
		_finish_reveal()


func push_title_rect() -> Rect2:
	if _title_label == null:
		return Rect2()
	return _title_label.get_global_rect()


func _clear_old_hall() -> void:
	for node_name in ["MoonLight", "FillLight", "ThroneLight", "EmberLightL", "EmberLightR", "RimLight"]:
		var node := get_node_or_null(node_name)
		if node != null:
			node.free()
	var court := get_node_or_null("Court")
	if court == null:
		return
	for child in court.get_children():
		child.free()


func _build_hall() -> void:
	var court: Node3D = $Court
	var floor_mat := _lit(Color.WHITE, 0.45, 0.06)
	floor_mat.albedo_texture = _tex("floor_brick.png")
	floor_mat.uv1_scale = Vector3(12.0 / 0.9, 28.0 / 0.9, 1)
	_box(court, "Floor", Vector3(12, 0.2, 28), Vector3(0, -0.1, -11), floor_mat)
	var lacquer := _lit(Color.WHITE, 0.4, 0.05)
	lacquer.albedo_texture = _tex("column_lacquer.png")
	lacquer.uv1_scale = Vector3(1.0, 2.2, 1)
	var step_red := _lit(Color("4A1008"), 0.62, 0.04)
	var gold := _lit(Color("C6A15A"), 0.34, 0.62)
	var stone := _lit(Color("2A241C"), 0.72, 0.0)
	# 三级台阶，前沿 z=-14/-15/-16，台面到 z=-24。
	_box(court, "Step1", Vector3(11.0, 0.4, 10.0), Vector3(0, 0.2, -19.0), step_red)
	_box(court, "Step2", Vector3(9.2, 0.4, 9.0), Vector3(0, 0.6, -19.5), step_red)
	_box(court, "Step3", Vector3(7.6, 0.4, 8.0), Vector3(0, 1.0, -20.0), gold)
	for side in [-1.0, 1.0]:
		for depth in [-6.0, -10.0, -14.0]:
			var pos := Vector3(side * 4.2, 5.5, depth)
			_cylinder(court, "Column", 0.38, 11.0, pos, lacquer, 12)
			_cylinder(court, "Collar", 0.46, 0.14, pos + Vector3(0, -3.4, 0), gold, 12)
			_cylinder(court, "Capital", 0.52, 0.2, pos + Vector3(0, 5.35, 0), gold, 12)
			_cylinder(court, "Base", 0.52, 0.28, pos + Vector3(0, -5.25, 0), stone, 12)
	_box(court, "LeftWall", Vector3(0.35, 11, 24), Vector3(-6.0, 5.5, -12), _lit(Color("140E10"), 0.86, 0.0))
	_box(court, "RightWall", Vector3(0.35, 11, 24), Vector3(6.0, 5.5, -12), _lit(Color("140E10"), 0.86, 0.0))
	_box(court, "BackWall", Vector3(12, 11, 0.4), Vector3(0, 5.5, -24), _lit(Color("120C0E"), 0.88, 0.0))
	_box(court, "Ceiling", Vector3(12, 0.3, 24), Vector3(0, 11.1, -12), _lit(Color("0C0A0C"), 0.92, 0.0))
	var screen_mat := _painted("screen_panel.png", 0.55, 0.16)
	_box(court, "Screen", Vector3(6.8, 5.4, 0.18), Vector3(0, 3.9, -21.9), screen_mat)
	var face := _painted("throne_face.png", 0.48, 0.42)
	var throne := _quad(court, "ThroneFace", Vector2(2.9, 3.75), Vector3(0, 3.075, -19.5), face)
	throne.rotation_degrees = Vector3(0, 0, 0)
	_box(court, "Seat", Vector3(2.15, 0.42, 1.15), Vector3(0, 1.41, -18.85), _lit(Color("1A100E"), 0.7, 0.05))
	_box(court, "Cushion", Vector3(1.45, 0.16, 0.62), Vector3(0, 1.68, -18.5), _lit(Color("7A1C14"), 0.58, 0.0))
	for side in [-1.0, 1.0]:
		_cylinder(court, "Post", 0.055, 1.35, Vector3(side * 0.95, 2.15, -19.15), gold, 8)
	_windows(court)
	_lantern_mesh(court, Vector3(-3.6, 3.0, -19.5), true)
	_lantern_mesh(court, Vector3(3.6, 3.0, -19.5), true)
	_lantern_mesh(court, Vector3(-2.6, 3.4, -13.5), true)
	_lantern_mesh(court, Vector3(2.6, 3.4, -13.5), true)
	_lantern_mesh(court, Vector3(-2.8, 3.6, -9.5), false)
	_lantern_mesh(court, Vector3(2.8, 3.6, -9.5), false)
	_candle(court, Vector3(-1.9, 2.7, -17.5))
	_candle(court, Vector3(1.9, 2.7, -17.5))


func _windows(court: Node3D) -> void:
	var side_mat := _window_mat(Color("3A5E92"), 0.32)
	var spans: Array[Vector2] = [Vector2(-10.5, -7.5), Vector2(-14.5, -11.0), Vector2(-19.0, -15.0)]
	for span in spans:
		var z: float = (span.x + span.y) * 0.5
		var depth: float = absf(span.y - span.x)
		for side in [-1.0, 1.0]:
			var pane := _quad(court, "SideWindow", Vector2(depth, 4.4), Vector3(side * 5.72, 4.0, z), side_mat)
			pane.rotation_degrees = Vector3(0, 90 if side > 0.0 else -90, 0)
	var high := _window_mat(Color("5C8AC8"), 0.42)
	var back := _quad(court, "HighWindow", Vector2(10.0, 2.8), Vector3(0, 8.2, -23.72), high)
	back.rotation_degrees = Vector3(0, 0, 0)


func _build_lights() -> void:
	var compat := RenderingServer.get_current_rendering_method() != "forward_plus"
	_omni("L1", Vector3(-3.6, 3.0, -19.5), Color("FFB45A"), 3.0, 8.0, false)
	_omni("L2", Vector3(3.6, 3.0, -19.5), Color("FFB45A"), 3.0, 8.0, false)
	_omni("L3", Vector3(-1.9, 2.7, -17.5), Color("FFC878"), 2.0, 6.0, true)
	_omni("L4", Vector3(1.9, 2.7, -17.5), Color("FFC878"), 2.0, 6.0, true)
	_omni("L5", Vector3(-2.6, 3.4, -13.5), Color("FFB45A"), 2.0, 7.0, false)
	_omni("L6", Vector3(2.6, 3.4, -13.5), Color("FFB45A"), 2.0, 7.0, false)
	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.light_color = Color("5E8CC8")
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-36.9, -69.5, 0)
	moon.shadow_enabled = not compat
	if moon.shadow_enabled:
		moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0A0E16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1B2433")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.86
	# 起始值 1.06 会把暗部较弱通道压成 0。收到 0.93，暗部留得住颜色，卡片区也不被抬过 30。
	env.adjustment_contrast = 0.93
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.012
	env.fog_light_color = Color("141C28")
	env.fog_aerial_perspective = 0.3
	env.volumetric_fog_enabled = false
	if compat:
		env.glow_enabled = false
	else:
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_hdr_threshold = 1.0
		env.glow_bloom = 0.1
		env.glow_strength = 0.7


func _build_atmosphere() -> void:
	var shaft_mat := _sheet(Color("5E8CC8"), 0.22, "shaft.png")
	# 斜向对着镜头，亮端在左窗、暗端落到台阶前，不伸进卡片带。
	var shafts := [
		[Vector3(-2.6, 2.35, -10.4), Vector3(22, 16, 26), Vector2(1.5, 5.6)],
		[Vector3(-2.35, 2.15, -13.5), Vector3(20, 14, 22), Vector2(1.4, 5.2)],
		[Vector3(-1.9, 1.95, -16.5), Vector3(18, 12, 16), Vector2(1.3, 4.6)],
	]
	for item in shafts:
		var shaft := _quad($Court, "LightShaft", item[2], item[0], shaft_mat)
		shaft.rotation_degrees = item[1]
	var fog_mat := _sheet(Color("5A6A88"), 0.1, "fog_sheet.png")
	fog_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var z := -8.0
	for index in 6:
		var alpha := 0.06 + float(index) * 0.014
		var mat := fog_mat.duplicate() as StandardMaterial3D
		mat.albedo_color.a = alpha
		var sheet := _quad($Court, "FogSheet", Vector2(12, 2), Vector3(0, 0.85, z), mat)
		_fog_sheets.append(sheet)
		z -= 2.0
	var warm := _sheet(Color("FFB45A"), 0.08, "fog_sheet.png")
	warm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_fog_sheets.append(_quad($Court, "WarmFog", Vector2(8, 1.6), Vector3(0, 1.6, -18.2), warm))
	_fog_sheets.append(_quad($Court, "WarmFog2", Vector2(6, 1.2), Vector3(0, 2.2, -20.4), warm.duplicate()))
	_streaks()
	_moon_pool()
	# 粒子停在卡片带之上：近处贴地的灰会投进 y>440。
	_particles("Ash", _ASH_AMOUNT, Color("FFC878"), 0.7, Vector2(0.02, 0.05), Vector3(0.02, 0.02, 0), Vector3(3.6, 2.1, 5.0), Vector3(0, 3.2, -13.0), false)
	_particles("Dust", _DUST_AMOUNT, Color("9CBEF0"), 0.55, Vector2(0.015, 0.04), Vector3(0.01, 0.01, 0), Vector3(1.5, 1.6, 3.6), Vector3(-3.3, 2.8, -13.2), true)
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_glow_billboards()


func _streaks() -> void:
	var mat := _sheet(Color("FFB45A"), 0.11, "shaft.png")
	# 光痕贴在看得见的台面和台阶前的地面上，不伸进 y>440 的卡片带。
	var spots := [
		Vector3(-1.15, 1.24, -17.6), Vector3(1.15, 1.24, -17.6),
		Vector3(-2.3, 1.24, -17.2), Vector3(2.3, 1.24, -17.2),
		Vector3(-1.5, 0.84, -15.3), Vector3(1.5, 0.84, -15.3),
		Vector3(-0.7, 0.06, -13.15), Vector3(0.7, 0.06, -13.15),
	]
	for spot in spots:
		var streak := _quad($Court, "FloorStreak", Vector2(0.22, 1.5), spot, mat)
		streak.rotation_degrees = Vector3(-90, 0, 0)


func _moon_pool() -> void:
	var mat := _sheet(Color("8EB4E0"), 0.16, "shaft.png")
	var pool := _quad($Court, "MoonPool", Vector2(3.8, 1.5), Vector3(-0.35, 0.055, -13.05), mat)
	pool.rotation_degrees = Vector3(-90, 0, 0)


func _glow_billboards() -> void:
	var mat := _sheet(Color("FFB45A"), 0.24, "lantern_glow.png")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var spots := [
		Vector3(-3.6, 3.0, -19.5), Vector3(3.6, 3.0, -19.5),
		Vector3(-1.9, 2.7, -17.5), Vector3(1.9, 2.7, -17.5),
		Vector3(-2.6, 3.4, -13.5), Vector3(2.6, 3.4, -13.5),
	]
	for spot in spots:
		_quad($Court, "LanternGlow", Vector2(1.15, 1.15), spot, mat)
	var far := mat.duplicate() as StandardMaterial3D
	far.albedo_color.a = 0.22
	_quad($Court, "FarGlow", Vector2(0.7, 0.7), Vector3(-2.8, 3.6, -9.5), far)
	_quad($Court, "FarGlow", Vector2(0.7, 0.7), Vector3(2.8, 3.6, -9.5), far)


func _particles(node_name: String, amount: int, color: Color, alpha: float, size_range: Vector2, gravity: Vector3, extents: Vector3, pos: Vector3, dust: bool) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(size_range.y, size_range.y)
	var mat := _sheet(color, alpha, "mote.png")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	var compat := RenderingServer.get_current_rendering_method() != "forward_plus"
	if compat:
		var cpu := CPUParticles3D.new()
		cpu.name = node_name
		cpu.amount = amount
		cpu.lifetime = 8.0
		cpu.preprocess = 2.0
		cpu.lifetime_randomness = 0.25
		cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cpu.emission_box_extents = extents
		cpu.direction = Vector3(0, 1, 0)
		cpu.spread = 26.0
		cpu.initial_velocity_min = 0.02 if dust else 0.05
		cpu.initial_velocity_max = 0.06 if dust else 0.15
		cpu.gravity = gravity
		cpu.scale_amount_min = size_range.x / size_range.y
		cpu.scale_amount_max = 1.0
		cpu.color = Color(color.r, color.g, color.b, alpha)
		cpu.mesh = quad
		cpu.position = pos
		cpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cpu.custom_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
		$Court.add_child(cpu)
		return
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = 8.0
	particles.preprocess = 2.0
	particles.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3(0, 1, 0)
	process.spread = 26.0
	process.initial_velocity_min = 0.02 if dust else 0.05
	process.initial_velocity_max = 0.06 if dust else 0.15
	process.gravity = gravity
	process.scale_min = size_range.x / size_range.y
	process.scale_max = 1.0
	process.color = Color(color.r, color.g, color.b, alpha)
	particles.process_material = process
	particles.position = pos
	$Court.add_child(particles)


func _ambience() -> void:
	var stream := _HALL_AUDIO
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "HallAmbience"
	player.stream = stream
	player.volume_db = -24.0
	player.bus = "Master"
	add_child(player)
	player.play()


func _build_push_chrome() -> void:
	var title_node := get_node_or_null("UI/Layout/Column/Title") as CanvasItem
	if title_node != null:
		title_node.visible = false
	var sub_node := get_node_or_null("UI/Layout/Column/Sub") as CanvasItem
	if sub_node != null:
		sub_node.visible = false
	# 切图原大 430×112，九宫格 margin 6。字和深色牌心从第一帧就在，金框 1.5 秒渐显。
	# 若整块从 0 渐显，0 秒时字会重新叠在亮窗格上，对比过不了 4.5:1。
	var chrome := Control.new()
	chrome.name = "PushChrome"
	chrome.position = Vector2(28, 16)
	chrome.size = Vector2(430, 112)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(chrome)
	_chrome = chrome
	var backing := ColorRect.new()
	backing.name = "PushBacking"
	backing.color = Color("14100C")
	backing.position = Vector2(24, 22)
	backing.size = Vector2(382, 66)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(backing)
	var plaque := UiKit.nine("panel_plaque_title.png", 6)
	plaque.name = "PushPlaque"
	plaque.position = Vector2.ZERO
	plaque.size = chrome.size
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.modulate.a = 0.0
	chrome.add_child(plaque)
	_plaque = plaque
	_title_label = UiKit.label("登基夜", UiKit.serif, 32, Color("FFF3D6"))
	_title_label.position = Vector2(32, 24)
	_title_label.size = Vector2(366, 36)
	chrome.add_child(_title_label)
	var sub := UiKit.label("宫城夜景 · 镜头推近", UiKit.sans, 15, Color("F5EDE0"))
	sub.position = Vector2(32, 60)
	sub.size = Vector2(366, 24)
	chrome.add_child(sub)
	_skip_hint = UiKit.label("点击或按空格继续", UiKit.sans, 14, Color("D4A84B"))
	_skip_hint.name = "SkipHint"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_skip_hint)
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -220.0
	_skip_hint.offset_top = -36.0
	_skip_hint.offset_right = -18.0
	_skip_hint.offset_bottom = -12.0


func _apply_chrome() -> void:
	if _plaque != null and not _push_done:
		var fade := clampf(_clock / 1.5, 0.0, 1.0)
		_plaque.modulate.a = fade
	if _skip_hint == null or _push_done:
		return
	if _clock < 3.0:
		_skip_hint.modulate.a = 0.0
	else:
		_skip_hint.modulate.a = clampf((_clock - 3.0) / 0.4, 0.0, 1.0)


func _board_spec() -> Dictionary:
	return {
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
	}


func _prebuild_board() -> void:
	if _board != null:
		return
	var started := Time.get_ticks_usec()
	_board = StoryBoard.mount($UI, _board_spec())
	_board.modulate.a = 0.0
	_board.visible = true
	_mute_mouse(_board)
	_warm_frames = 2
	print("S1_PREBUILD_MS %.2f t=%.2f" % [(Time.get_ticks_usec() - started) / 1000.0, _clock])


func _finish_reveal() -> void:
	if _push_done:
		return
	var started := Time.get_ticks_usec()
	_push_done = true
	_warm_frames = 0
	_camera.position = _CAM_END
	_camera.rotation_degrees = Vector3(_PITCH, 0, 0)
	_choices.visible = false
	var layout := get_node_or_null("UI/Layout") as CanvasItem
	if layout != null:
		layout.visible = false
	if _chrome != null:
		_chrome.visible = false
	if _skip_hint != null:
		_skip_hint.visible = false
	if _board == null:
		_prebuild_board()
	_restore_card_mouse()
	_board.visible = true
	_board.modulate.a = 1.0
	var since_push := -1.0
	var since_skip := -1.0
	if _push_wall > 0:
		since_push = (Time.get_ticks_usec() - _push_wall) / 1000000.0
	if _skip_wall > 0:
		since_skip = (Time.get_ticks_usec() - _skip_wall) / 1000000.0
	print("S1_REVEAL_MS %.2f t=%.2f boards=%d since_push=%.3f since_skip=%.3f" % [(Time.get_ticks_usec() - started) / 1000.0, _clock, $UI.find_children("StoryBoard", "Control", true, false).size(), since_push, since_skip])


func _choose(choice_id: String) -> void:
	var result: Dictionary = Campaign.apply_s1(choice_id)
	if not bool(result.get("ok", false)):
		return
	Bgm.set_mode("map")
	get_tree().change_scene_to_file("res://scenes/big_map.tscn")


func _omni(node_name: String, pos: Vector3, color: Color, energy: float, radius: float, flame: bool) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	add_child(light)
	if flame:
		_flames.append(light)
		_flame_base.append(energy)


func _lantern_mesh(parent: Node3D, pos: Vector3, near_throne: bool) -> void:
	var energy := 0.9 if near_throne else 0.4
	var body := _emissive(Color("FFB45A"), energy)
	_cylinder(parent, "Lantern", 0.16, 0.46, pos, body, 6)
	var cap := _lit(Color("C6A15A"), 0.32, 0.7)
	_cylinder(parent, "LanternCap", 0.2, 0.06, pos + Vector3(0, 0.26, 0), cap, 6)
	_cylinder(parent, "LanternCap", 0.18, 0.05, pos + Vector3(0, -0.26, 0), cap, 6)
	_cylinder(parent, "Cord", 0.012, 0.55, pos + Vector3(0, 0.55, 0), _lit(Color("2A2118"), 0.6, 0.2), 4)
	var tassel := _lit(Color("6A1810"), 0.55, 0.0)
	_cylinder(parent, "Tassel", 0.018, 0.32, pos + Vector3(0, -0.46, 0), tassel, 4)


func _candle(parent: Node3D, pos: Vector3) -> void:
	_cylinder(parent, "Candle", 0.035, 0.7, pos + Vector3(0, -0.15, 0), _lit(Color("C8B090"), 0.55, 0.0), 8)
	var stick := _lit(Color("3A3028"), 0.5, 0.3)
	_cylinder(parent, "Candlestick", 0.05, 0.9, pos + Vector3(0, -0.55, 0), stick, 8)
	var flame := _emissive(Color("FFC878"), 2.4)
	_cylinder(parent, "Flame", 0.03, 0.16, pos + Vector3(0, 0.26, 0), flame, 6)


func _window_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.04, 0.06)
	mat.roughness = 0.72
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_texture = _tex("window_lattice.png")
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _painted(file_name: String, roughness: float, emission_energy: float) -> StandardMaterial3D:
	var mat := _lit(Color.WHITE, roughness, 0.16)
	var tex := _tex(file_name)
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_texture = tex
	mat.emission_energy_multiplier = emission_energy
	return mat


func _lit(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _lit(color, 0.45, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _sheet(color: Color, alpha: float, file_name: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.albedo_texture = _tex(file_name)
	return mat


func _preload_story_textures() -> void:
	var started := Time.get_ticks_usec()
	var files := [
		"panel_plaque_title.png", "shade_story.png",
		"card_story_normal.png", "card_story_hover.png", "card_story_selected.png",
		"card_story_disabled.png", "card_story_recommend.png",
		"seal_choice_normal.png", "seal_choice_locked.png", "badge_best.png",
		"chip_fx_gain.png", "chip_fx_cost.png", "chip_fx_world.png", "chip_fx_status.png",
	]
	for file_name in files:
		UiKit.tex(file_name)
	print("S1_PRELOAD_MS %.2f s1_tex=%d ui_tex=%d audio=%s" % [(Time.get_ticks_usec() - started) / 1000.0, _TEX.size(), files.size(), _HALL_AUDIO.resource_path])


func _mute_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_mute_mouse(child)


func _restore_card_mouse() -> void:
	if _board == null:
		return
	for node in _board.find_children("*", "BaseButton", true, false):
		(node as BaseButton).mouse_filter = Control.MOUSE_FILTER_STOP


func _tex(file_name: String) -> Texture2D:
	return _TEX[file_name] as Texture2D


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, mesh, pos, mat)


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, mat: Material, segments: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _mesh(parent, node_name, mesh, pos, mat)


func _quad(parent: Node3D, node_name: String, size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var inst := _mesh(parent, node_name, mesh, pos, mat)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = mat
	parent.add_child(inst)
	return inst
