class_name WeaponModels
## Loads the Engineer weapon models (assets/weapons/engineer/*.glb, built in Blender by
## tools/build_weapon_models.py) for three uses: held by the Engineer in the Spire, carried
## on the player's back in the city, and as the live munition a launcher fires or a hand
## throws. Launchers are modelled pointing along -Z (Godot forward) with the pistol grip
## near the origin; grenades stand upright, centred; the mine lies on the ground plane.

const MODEL_DIR := "res://assets/weapons/engineer/"


static func kind(w: Dictionary) -> String:
	return str(w.get("kind", "grenade"))


static func is_launcher(w: Dictionary) -> bool:
	return kind(w) == "launcher"


static func is_thrown(w: Dictionary) -> bool:
	return kind(w) == "grenade"


static func _instance(w: Dictionary) -> Node3D:
	var path := MODEL_DIR + str(w.get("id", "")) + ".glb"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var node := scene.instantiate() as Node3D
		if node:
			return node
	# fallback so a missing model never breaks the game
	var fallback := Node3D.new()
	Palette.sphere(fallback, 0.08, Vector3.ZERO, Palette.glow(w.get("color", Palette.AMBER), 2.0), "Fallback")
	return fallback


## The weapon as the Engineer holds it.
static func build(w: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_%s" % w.get("id", "x")
	var model := _instance(w)
	root.add_child(model)
	match kind(w):
		"launcher":
			model.position = Vector3(0, 0.2, 0.05)       # grip into the hand
		"mine":
			model.scale = Vector3(0.55, 0.55, 0.55)
			model.rotation.x = -PI * 0.5                  # carried flat against the chest
		_:
			model.scale = Vector3(1.9, 1.9, 1.9)          # hand grenades read at third-person distance
	return root


## What flies through the air: the grenade itself, or a small glowing round for launchers.
static func build_munition(w: Dictionary) -> Node3D:
	var root := Node3D.new()
	match kind(w):
		"launcher":
			var color: Color = w.get("color", Palette.AMBER)
			var shell := Palette.cylinder(root, 0.05, 0.22, Vector3.ZERO, Palette.pbr(Color(0.12, 0.12, 0.14), 0.35, 0.85), false, "Shell", 14)
			shell.rotation.x = PI * 0.5
			Palette.sphere(root, 0.07, Vector3(0, 0, -0.12), Palette.glow(color, 3.0), "Tip")
			Palette.sphere(root, 0.05, Vector3(0, 0, 0.14), Palette.translucent_glow(color, 0.6, 3.0), "Trail")
		"mine":
			root.add_child(_instance(w))
		_:
			var model := _instance(w)
			model.scale = Vector3(1.9, 1.9, 1.9)
			root.add_child(model)
	return root


## Merged bounds of every mesh under `node`, in the space of `node`'s parent.
static func bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[node, node.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node3D = item[0]
		var xf: Transform3D = item[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var box: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			if c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
	return out


## A lit product stage inside `vp`: the weapon's real model centred on a turntable, sky
## reflections for the metal, three lights, and a camera fitted to the model's size.
## Used by the phone's 3D viewer and by tools/RenderWeaponCards. Returns the turntable.
static func stage(vp: SubViewport, w: Dictionary, yaw := 0.0, aspect := 1.6) -> Node3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.11, 0.13)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.56, 0.68)
	sky_mat.sky_horizon_color = Color(0.86, 0.86, 0.9)
	sky_mat.ground_horizon_color = Color(0.42, 0.42, 0.45)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.12)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	for spec: Array in [[Vector3(-38, 40, 0), 1.2, true], [Vector3(-12, -120, 0), 0.5, false], [Vector3(-25, 172, 0), 0.9, false]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.shadow_enabled = spec[2]
		vp.add_child(light)
	var turntable := Node3D.new()
	turntable.rotation.y = yaw
	vp.add_child(turntable)
	var model := _instance(w)
	turntable.add_child(model)
	var box := bounds(model)
	model.position -= box.get_center()
	var dir := Vector3(0, 0.62 if kind(w) == "mine" else 0.3, 1).normalized()
	var elev := asin(dir.y)
	var half_v := deg_to_rad(15.0)
	var half_h := atan(tan(half_v) * aspect)
	var r_h := Vector2(box.size.x, box.size.z).length() * 0.5
	var r_v := box.size.y * 0.5 * cos(elev) + r_h * sin(elev)
	var dist := maxf(r_h / tan(half_h), r_v / tan(half_v)) * 1.12
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.01
	cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * dist)
	vp.add_child(cam)
	return turntable
