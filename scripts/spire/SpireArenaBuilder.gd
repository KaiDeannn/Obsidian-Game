extends Node3D
class_name SpireArenaBuilder
## Builds the "Central Plaza" of The Spire Ruins: ash-stone plaza, ruined perimeter walls,
## the shattered spire on a raised dais with four ramps, scattered cover (barricades,
## crates, slabs), two elevated vantage platforms with ramps, a broken colonnade,
## rubble and brazier lights. All geometry is on physics layer World (used for LOS).

const HALF := 60.0

var _rng := RandomNumberGenerator.new()
var mat_floor: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_stone_dark: StandardMaterial3D
var mat_crate: StandardMaterial3D
var mat_barricade: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_obsidian: StandardMaterial3D
var mat_crack: StandardMaterial3D
var mat_fire: StandardMaterial3D
var mat_hazard: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 777
	mat_floor = Palette.mat(Color(0.3, 0.29, 0.3), 0.95)
	mat_stone = Palette.mat(Color(0.42, 0.38, 0.36), 0.9)
	mat_stone_dark = Palette.mat(Color(0.24, 0.22, 0.22), 0.92)
	mat_crate = Palette.mat(Color(0.35, 0.26, 0.16), 0.85)
	mat_barricade = Palette.mat(Color(0.2, 0.22, 0.26), 0.6, 0.4)
	mat_metal = Palette.mat(Color(0.3, 0.32, 0.36), 0.35, 0.8)
	mat_obsidian = Palette.mat(Palette.OBSIDIAN, 0.1, 0.9)
	mat_crack = Palette.glow(Palette.VIOLET, 2.6)
	mat_fire = Palette.glow(Palette.AMBER, 3.5)
	mat_hazard = Palette.glow(Palette.AMBER, 1.0)
	_build_floor()
	_build_walls()
	_build_spire()
	_build_cover()
	_build_vantage(Vector3(38, 0, 38), PI * 0.75)
	_build_vantage(Vector3(-38, 0, -38), -PI * 0.25)
	_build_ruin_shell(Vector3(-40, 0, 40))
	_build_ruin_shell(Vector3(40, 0, -40))
	_build_colonnade()
	_build_rubble()
	_build_braziers()
	Palette.label3d(self, "CENTRAL PLAZA", Vector3(0, 36, 0), Palette.VIOLET, 110, 0.06)


func _build_floor() -> void:
	Palette.box(self, Vector3(HALF * 2 + 12, 0.4, HALF * 2 + 12), Vector3(0, -0.2, 0), mat_floor, true, "Plaza")
	# Paving pattern: darker lanes and scorch marks.
	for c in [-40.0, -20.0, 20.0, 40.0]:
		Palette.box(self, Vector3(0.4, 0.02, HALF * 2), Vector3(c, 0.01, 0), mat_stone_dark, false, "Seam")
		Palette.box(self, Vector3(HALF * 2, 0.02, 0.4), Vector3(0, 0.01, c), mat_stone_dark, false, "Seam")
	for k in range(14):
		var p := Vector3(_rng.randf_range(-50, 50), 0.015, _rng.randf_range(-50, 50))
		var s := Palette.box(self, Vector3(_rng.randf_range(2, 6), 0.02, _rng.randf_range(1, 3)), p, Palette.mat(Color(0.12, 0.1, 0.1), 1.0), false, "Scorch")
		s.rotation.y = _rng.randf_range(0, TAU)
	# Spawn pad.
	Palette.cylinder(self, 4.0, 0.1, Vector3(0, 0.05, 48), Palette.translucent_glow(Palette.CYAN, 0.3, 1.5), false, "SpawnPad", 32)


func _build_walls() -> void:
	# Ruined perimeter: segments with varying height and occasional gaps, plus blockers.
	var seg := 15.0
	for side in range(4):
		for k in range(8):
			if (k == 3 and side % 2 == 0) or (k == 5 and side % 2 == 1):
				continue  # a gap - broken through
			var along := -HALF + seg * 0.5 + k * seg
			var h := _rng.randf_range(4.0, 9.5)
			var pos: Vector3
			var size: Vector3
			match side:
				0: pos = Vector3(along, h * 0.5, -HALF); size = Vector3(seg, h, 2.0)
				1: pos = Vector3(HALF, h * 0.5, along); size = Vector3(2.0, h, seg)
				2: pos = Vector3(along, h * 0.5, HALF); size = Vector3(seg, h, 2.0)
				_: pos = Vector3(-HALF, h * 0.5, along); size = Vector3(2.0, h, seg)
			Palette.box(self, size, pos, mat_stone if k % 2 == 0 else mat_stone_dark, true, "Wall")
			# Jagged cap.
			var cap_size := Vector3(size.x * 0.4, 1.4, size.z * 0.4)
			if side % 2 == 0:
				cap_size.z = 2.0
			else:
				cap_size.x = 2.0
			Palette.box(self, cap_size, pos + Vector3(0, h * 0.5 + 0.6, 0), mat_stone_dark, false, "WallCap")
	var h := HALF + 5.0
	Palette.blocker(self, Vector3(150, 40, 2), Vector3(0, 20, -h), "BoundN")
	Palette.blocker(self, Vector3(150, 40, 2), Vector3(0, 20, h), "BoundS")
	Palette.blocker(self, Vector3(2, 40, 150), Vector3(-h, 20, 0), "BoundW")
	Palette.blocker(self, Vector3(2, 40, 150), Vector3(h, 20, 0), "BoundE")


func _ramp(parent: Node3D, from_edge: Vector3, yaw: float, length: float, rise: float, width := 4.0) -> void:
	# Box tilted so its far end sits on the ground; from_edge is the top edge centre.
	var angle := atan2(rise, length)
	var slope_len := sqrt(length * length + rise * rise)
	var pivot := Node3D.new()
	pivot.position = from_edge
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var ramp := Palette.box(pivot, Vector3(width, 0.4, slope_len), Vector3(0, -rise * 0.5, length * 0.5), mat_stone, true, "Ramp")
	ramp.rotation.x = angle
	Palette.box(pivot, Vector3(width + 0.2, 0.08, 0.6), Vector3(0, 0.05, 0.1), mat_hazard, false, "RampEdge")


func _build_spire() -> void:
	# Raised octagonal dais with a shattered obsidian spire.
	var dais_h := 2.6
	var dais_r := 10.0
	Palette.cylinder(self, dais_r, dais_h, Vector3(0, dais_h * 0.5, 0), mat_stone, true, "Dais", 8)
	Palette.cylinder(self, dais_r - 0.4, 0.1, Vector3(0, dais_h + 0.05, 0), mat_stone_dark, false, "DaisTop", 8)
	for k in range(4):
		var yaw := k * PI * 0.5
		var edge := Vector3(0, dais_h, dais_r - 0.8).rotated(Vector3.UP, yaw)
		_ramp(self, edge, yaw, 9.0, dais_h, 4.5)
	# Spire column, cracked and leaning.
	var spire := Palette.cylinder(self, 2.6, 26.0, Vector3(0, dais_h + 13.0, 0), mat_obsidian, true, "SpireColumn", 10)
	spire.rotation.z = deg_to_rad(9.0)
	spire.position.x -= 1.2
	for k in range(5):
		var crack := Palette.box(spire, Vector3(0.18, _rng.randf_range(4, 9), 0.18), Vector3(cos(k * 1.3) * 2.55, _rng.randf_range(-9, 9), sin(k * 1.3) * 2.55), mat_crack, false, "Crack")
		crack.rotation.z = _rng.randf_range(-0.2, 0.2)
	Palette.sphere(self, 1.6, Vector3(-3.0, dais_h + 26.5, 0), Palette.glow(Palette.VIOLET, 4.5), "SpireCore")
	# Broken shards around the base.
	for k in range(6):
		var a := k * TAU / 6.0 + 0.4
		var shard := Palette.box(self, Vector3(1.2, _rng.randf_range(2, 4), 1.2), Vector3(cos(a) * 6.0, dais_h + 0.8, sin(a) * 6.0), mat_obsidian, true, "Shard")
		shard.rotation = Vector3(_rng.randf_range(-0.3, 0.3), a, _rng.randf_range(-0.3, 0.3))
	Palette.omni(self, Vector3(0, dais_h + 4.0, 0), Palette.VIOLET, 3.5, 22.0)


func _build_cover() -> void:
	var cover := Node3D.new()
	cover.name = "Cover"
	add_child(cover)
	# Symmetric rings of cover around the dais.
	var ring_specs := [[18.0, 6, "barricade"], [28.0, 8, "slab"], [40.0, 8, "crate"]]
	for spec in ring_specs:
		var r: float = spec[0]
		var n: int = spec[1]
		var kind: String = spec[2]
		for k in range(n):
			var a := k * TAU / n + (0.3 if kind == "slab" else 0.0)
			var pos := Vector3(cos(a) * r, 0, sin(a) * r)
			if absf(pos.x) > 44 and absf(pos.z) > 44:
				continue  # keep corners for platforms
			match kind:
				"barricade":
					var b := Palette.box(cover, Vector3(4.0, 1.5, 1.0), pos + Vector3(0, 0.75, 0), mat_barricade, true, "Barricade")
					b.rotation.y = a + PI * 0.5
					Palette.box(b, Vector3(3.8, 0.1, 0.1), Vector3(0, 0.8, -0.52), mat_hazard, false, "Stripe")
				"slab":
					var s := Palette.box(cover, Vector3(3.2, 2.2, 1.2), pos + Vector3(0, 1.1, 0), mat_stone, true, "Slab")
					s.rotation.y = a + _rng.randf_range(-0.3, 0.3)
				"crate":
					var c := Palette.box(cover, Vector3(1.9, 1.9, 1.9), pos + Vector3(0, 0.95, 0), mat_crate, true, "Crate")
					c.rotation.y = _rng.randf_range(0, TAU)
					if _rng.randf() < 0.5:
						Palette.box(cover, Vector3(1.6, 1.6, 1.6), pos + Vector3(0.3, 2.7, 0.2), mat_crate, true, "CrateTop")
	# A few tall metal pillars to break sightlines across the open middle.
	for p in [Vector3(12, 0, -24), Vector3(-12, 0, 24), Vector3(24, 0, 12), Vector3(-24, 0, -12)]:
		Palette.box(cover, Vector3(1.4, 5.0, 1.4), p + Vector3(0, 2.5, 0), mat_metal, true, "Pylon")
		Palette.box(cover, Vector3(0.2, 4.6, 0.2), p + Vector3(0, 2.5, -0.72), Palette.glow(Palette.CYAN, 1.8), false, "PylonLight")


func _build_vantage(center: Vector3, ramp_yaw: float) -> void:
	# Elevated 12x12 platform at 6 m with parapet, pillars and a long ramp toward the middle.
	var h := 6.0
	var size := 12.0
	Palette.box(self, Vector3(size, 0.6, size), center + Vector3(0, h - 0.3, 0), mat_stone, true, "VantageDeck")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Palette.box(self, Vector3(1.2, h - 0.6, 1.2), center + Vector3(sx * (size * 0.5 - 0.8), (h - 0.6) * 0.5, sz * (size * 0.5 - 0.8)), mat_stone_dark, true, "VantagePillar")
	# Parapet on the two outward sides.
	var outward := center.normalized()
	for side: Vector3 in [Vector3(outward.x, 0, 0), Vector3(0, 0, outward.z)]:
		var pos := center + side * (size * 0.5 - 0.3) + Vector3(0, h + 0.5, 0)
		var sz := Vector3(size, 1.0, 0.6) if absf(side.z) > 0 else Vector3(0.6, 1.0, size)
		Palette.box(self, sz, pos, mat_stone_dark, true, "Parapet")
	# Ramp: top edge on the side facing the plaza centre.
	var toward := -outward
	var edge := center + toward * (size * 0.5) + Vector3(0, h, 0)
	_ramp(self, edge, ramp_yaw, 16.0, h, 4.0)
	Palette.omni(self, center + Vector3(0, h + 3.0, 0), Palette.CYAN, 1.6, 16.0)
	Palette.label3d(self, "VANTAGE", center + Vector3(0, h + 6.0, 0), Palette.CYAN, 40, 0.035)


func _build_ruin_shell(center: Vector3) -> void:
	# L-shaped broken building shell with window openings - good sniper cover.
	var outward := center.normalized()
	var h := 9.0
	var wall_a := Palette.box(self, Vector3(14, h, 1.2), center + Vector3(0, h * 0.5, outward.z * 6.0), mat_stone, true, "ShellWallA")
	var wall_b := Palette.box(self, Vector3(1.2, h, 14), center + Vector3(outward.x * 6.0, h * 0.5, 0), mat_stone, true, "ShellWallB")
	for w: Node3D in [wall_a, wall_b]:
		for k in range(2):
			var off := (-3.0 if k == 0 else 3.0)
			var win := Palette.box(w, Vector3(2.0 if w == wall_a else 1.4, 1.6, 1.4 if w == wall_a else 2.0), Vector3(off if w == wall_a else 0, 1.6, 0 if w == wall_a else off), Palette.mat(Color(0.04, 0.04, 0.05)), false, "Window")
			win.visible = true
	Palette.box(self, Vector3(14, 0.6, 7), center + Vector3(0, h, outward.z * 3.0), mat_stone_dark, true, "ShellFloor")
	Palette.box(self, Vector3(6, 0.2, 6), center + Vector3(-outward.x * 2.0, 0.1, -outward.z * 2.0), mat_stone_dark, true, "ShellSlab")


func _build_colonnade() -> void:
	for x in [-22.0, 22.0]:
		for z in range(-30, 31, 10):
			var full := _rng.randf() < 0.65
			var h := 7.5 if full else _rng.randf_range(1.5, 3.5)
			Palette.cylinder(self, 0.8, h, Vector3(x, h * 0.5, z), mat_stone, true, "Column", 12)
			if full:
				Palette.box(self, Vector3(2.0, 0.6, 2.0), Vector3(x, h + 0.3, z), mat_stone_dark, true, "Capital")


func _build_rubble() -> void:
	for k in range(26):
		var p := Vector3(_rng.randf_range(-54, 54), 0, _rng.randf_range(-54, 54))
		if p.length() < 14.0:
			continue
		var r := _rng.randf_range(0.5, 1.4)
		var s := Palette.sphere(self, r, p + Vector3(0, r * 0.5, 0), mat_stone_dark, "Rubble")
		s.scale = Vector3(1.0, 0.6, 1.0)


func _build_braziers() -> void:
	for p in [Vector3(16, 0, 16), Vector3(-16, 0, 16), Vector3(16, 0, -16), Vector3(-16, 0, -16), Vector3(0, 0, 44), Vector3(44, 0, 0), Vector3(-44, 0, 0), Vector3(0, 0, -44)]:
		Palette.cylinder(self, 0.6, 1.2, p + Vector3(0, 0.6, 0), mat_metal, true, "Brazier", 10)
		Palette.sphere(self, 0.45, p + Vector3(0, 1.45, 0), mat_fire, "Flame")
		Palette.omni(self, p + Vector3(0, 2.2, 0), Palette.AMBER, 2.4, 12.0)
