class_name Palette
## Shared material + primitive helpers so both scenes read as one art direction:
## obsidian blacks, cyan/violet neon, ash greys and amber fire.

const OBSIDIAN := Color(0.07, 0.07, 0.08)
const CYAN := Color(0.78, 0.86, 1.0)      # primary light: pale window blue (name kept for callers)
const VIOLET := Color(1.0, 0.88, 0.7)     # secondary light: warm window white (name kept for callers)
const AMBER := Color(1.0, 0.62, 0.2)
const RED := Color(1.0, 0.25, 0.3)
const GOLD := Color(1.0, 0.8, 0.3)
const GREEN := Color(0.35, 1.0, 0.55)
const WARM_WHITE := Color(1.0, 0.92, 0.78)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_VEHICLE := 8
const LAYER_TRIGGER := 16


static func mat(albedo: Color, roughness := 0.85, metallic := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


## Self-lit neon material.
static func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	return mat(color * 0.35, 0.4, 0.0, color, energy)


static func glass(color: Color, alpha := 0.55) -> StandardMaterial3D:
	var m := mat(Color(color.r, color.g, color.b, alpha), 0.08, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func translucent_glow(color: Color, alpha := 0.35, energy := 2.5) -> StandardMaterial3D:
	var m := glow(color, energy)
	m.albedo_color.a = alpha
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Adds a box. With collide=true the result is a StaticBody3D (layer World) wrapping the mesh.
static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, collide := true, node_name := "Box") -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not collide:
		mi.name = node_name
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := _static_body(node_name, pos)
	var shape := BoxShape3D.new()
	shape.size = size
	body.add_child(mi)
	body.add_child(_collision(shape))
	parent.add_child(body)
	return body


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, collide := true, node_name := "Cylinder", segments := 24) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not collide:
		mi.name = node_name
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := _static_body(node_name, pos)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	body.add_child(mi)
	body.add_child(_collision(shape))
	parent.add_child(body)
	return body


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material, node_name := "Sphere") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Invisible collision volume (boundaries, blockers).
static func blocker(parent: Node, size: Vector3, pos: Vector3, node_name := "Blocker") -> StaticBody3D:
	var body := _static_body(node_name, pos)
	var shape := BoxShape3D.new()
	shape.size = size
	body.add_child(_collision(shape))
	parent.add_child(body)
	return body


static func label3d(parent: Node, text: String, pos: Vector3, color: Color, font_size := 64, pixel_size := 0.04) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


static func omni(parent: Node, pos: Vector3, color: Color, energy := 2.0, range_m := 12.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = false
	parent.add_child(light)
	return light


static func _static_body(node_name: String, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	return body


static func _collision(shape: Shape3D) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	return cs
