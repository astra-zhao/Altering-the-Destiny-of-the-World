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


static func install_font(control: Control) -> void:
	var font := control.get_theme_font("font")
	var fallback := load("res://theme/cjk_system_font.tres") as Font
	if font == null or fallback == null:
		return
	for item in font.fallbacks:
		if item == fallback:
			return
	font.fallbacks.append(fallback)
