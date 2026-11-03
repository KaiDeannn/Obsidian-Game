class_name WeaponModels
## Code-built models for the Premium Shop weapons (CityData.PREMIUM_WEAPONS), so an
## equipped weapon is visible in the Swordsman's hand in the Spire, on the player's back
## in the city, and as the spinning projectile for thrown kinds. Each entry's "kind"
## picks the silhouette, its "color" tints the glowing edges.

## A held weapon. Blades extend along -Z from the grip (matches SpirePlayer's sword pivot).
static func build(w: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_%s" % w.get("id", "x")
	var glow := Palette.glow(w.get("color", Palette.CYAN), 2.6)
	var steel := Palette.mat(Color(0.75, 0.76, 0.8), 0.25, 0.95)
	var dark := Palette.mat(Color(0.08, 0.07, 0.1), 0.2, 0.9)
	var gold := Palette.mat(Color(0.85, 0.68, 0.25), 0.3, 0.95)
	var grip := Palette.mat(Color(0.25, 0.08, 0.1), 0.9)
	match str(w.get("kind", "blade")):
		"dagger":
			Palette.box(root, Vector3(0.06, 0.03, 0.55), Vector3(0, 0, -0.38), dark, false, "Blade")
			Palette.box(root, Vector3(0.02, 0.04, 0.5), Vector3(0, 0, -0.38), glow, false, "Edge")
			Palette.box(root, Vector3(0.2, 0.05, 0.05), Vector3(0, 0, -0.08), steel, false, "Guard")
			_grip(root, grip, 0.2)
		"katana":
			Palette.box(root, Vector3(0.05, 0.03, 1.1), Vector3(0, 0, -0.7), steel, false, "Blade")
			Palette.box(root, Vector3(0.015, 0.035, 1.05), Vector3(0.02, 0, -0.7), glow, false, "Edge")
			Palette.cylinder(root, 0.09, 0.03, Vector3(0, 0, -0.12), gold, false, "Tsuba", 12)
			(root.get_node("Tsuba") as Node3D).rotation.x = PI * 0.5
			_grip(root, grip, 0.3)
		"flame":
			# jagged flame-shaped blade: staggered boxes
			for i in range(5):
				var z := -0.25 - i * 0.2
				var wdt := 0.14 - i * 0.015
				Palette.box(root, Vector3(wdt, 0.035, 0.22), Vector3((i % 2) * 0.05 - 0.025, 0, z), steel, false, "Flame")
			Palette.box(root, Vector3(0.02, 0.04, 1.0), Vector3(0, 0, -0.7), glow, false, "Script")
			Palette.sphere(root, 0.07, Vector3(0, 0, -0.1), gold, "DragonHead")
			_grip(root, grip, 0.3)
		"crystal":
			Palette.box(root, Vector3(0.07, 0.04, 0.6), Vector3(0, 0, -0.42), Palette.glass(Color(0.75, 0.6, 0.95), 0.7), false, "Crystal")
			Palette.box(root, Vector3(0.03, 0.05, 0.5), Vector3(0, 0, -0.42), glow, false, "Mist")
			Palette.sphere(root, 0.05, Vector3(0, 0, -0.1), glow, "Rose")
			_grip(root, grip, 0.2)
		"star":
			for k in range(4):
				var p := Palette.box(root, Vector3(0.06, 0.02, 0.5), Vector3.ZERO, steel, false, "Point")
				p.rotation.y = k * PI * 0.5
				p.position = Vector3(sin(k * PI * 0.5) * 0.22, 0, -cos(k * PI * 0.5) * 0.22)
			Palette.cylinder(root, 0.1, 0.03, Vector3.ZERO, gold, false, "Hub", 12)
			Palette.cylinder(root, 0.05, 0.035, Vector3.ZERO, glow, false, "Core", 12)
		"triblade":
			for k in range(3):
				var a := k * TAU / 3.0
				var p := Palette.box(root, Vector3(0.07, 0.02, 0.42), Vector3.ZERO, dark, false, "Blade")
				p.rotation.y = a + 0.5
				p.position = Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2)
				var e := Palette.box(root, Vector3(0.02, 0.025, 0.4), Vector3.ZERO, glow, false, "Vein")
				e.rotation.y = a + 0.5
				e.position = p.position + Vector3(0, 0.002, 0)
			Palette.cylinder(root, 0.08, 0.03, Vector3.ZERO, gold, false, "Ring", 12)
		"razor":
			var a := Palette.box(root, Vector3(0.08, 0.025, 0.5), Vector3(0.05, 0, -0.15), gold, false, "Stem")
			a.rotation.y = 0.35
			var b := Palette.box(root, Vector3(0.08, 0.025, 0.4), Vector3(-0.12, 0, -0.1), gold, false, "Arm")
			b.rotation.y = -0.9
			Palette.box(root, Vector3(0.025, 0.03, 0.45), Vector3(0.05, 0.002, -0.15), glow, false, "Edge").rotation.y = 0.35
		"chain":
			for k in range(12):
				var a := k * TAU / 12.0
				var link := Palette.box(root, Vector3(0.12, 0.02, 0.08), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), steel, false, "Link")
				link.rotation.y = -a
				var spark := Palette.box(root, Vector3(0.05, 0.025, 0.05), Vector3(cos(a) * 0.3, 0.002, sin(a) * 0.3), glow, false, "Spark")
				spark.rotation.y = -a
			_grip(root, grip, 0.25)
		_:   # "blade": straight sword
			Palette.box(root, Vector3(0.07, 0.035, 1.0), Vector3(0, 0, -0.65), dark, false, "Blade")
			Palette.box(root, Vector3(0.02, 0.045, 0.95), Vector3(0, 0, -0.65), glow, false, "Edge")
			Palette.box(root, Vector3(0.3, 0.05, 0.06), Vector3(0, 0, -0.12), gold, false, "Guard")
			_grip(root, grip, 0.28)
	return root


static func _grip(root: Node3D, mat: Material, length: float) -> void:
	var g := Palette.cylinder(root, 0.03, length, Vector3(0, 0, length * 0.5 - 0.02), mat, false, "Grip", 8)
	g.rotation.x = PI * 0.5


## True for weapons that leave the hand when attacking.
static func is_thrown(w: Dictionary) -> bool:
	return str(w.get("kind", "")) in ["star", "triblade", "razor"]
