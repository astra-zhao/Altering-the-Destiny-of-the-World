extends RefCounted
## S2/S3 共用的低模零件。场景根仍是 Node3D，网格在运行时放进树里。


static func box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, albedo: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, mesh, pos, albedo, metallic, false)


static func cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, albedo: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _mesh(parent, node_name, mesh, pos, albedo, 0.0, false)


static func sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, albedo: Color, emissive: bool) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(parent, node_name, mesh, pos, albedo, 0.0, emissive)


static func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, albedo: Color, metallic: float, emissive: bool) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = 0.35 if metallic > 0.2 else 0.86
	if emissive:
		mat.emission_enabled = true
		mat.emission = albedo
		mat.emission_energy_multiplier = 3.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = mat
	parent.add_child(inst)
	return inst


static func night_environment(background: Color, fog_color: Color) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.12, 0.11)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.8
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.02
	env.fog_light_color = fog_color
	return env


static func moon(parent: Node3D, energy: float, rotation: Vector3, color: Color) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.rotation_degrees = rotation
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 40.0
	parent.add_child(light)
	return light


static func install_font(root: Node) -> void:
	var font := load("res://assets/ui/NotoSansSC-Regular.otf") as FontFile
	if font == null or root == null:
		return
	font.allow_system_fallback = false
	font.fallbacks.clear()
	_pin_subset(root, font)


static func _pin_subset(node: Node, font: Font) -> void:
	if node is Label or node is Button:
		(node as Control).add_theme_font_override("font", font)
	for child in node.get_children():
		_pin_subset(child, font)
