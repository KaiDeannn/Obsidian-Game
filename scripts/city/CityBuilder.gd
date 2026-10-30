extends Node3D
class_name CityBuilder
## Procedurally assembles Nova Aetheris from CityData so the layout stays in sync with
## jobs, properties and the mini-map. All geometry is static, on physics layer World.
##
## Districts: Core Plaza (centre), The Heights (NE towers + property plots),
## Neon Docks (SW warehouses), mixed mid-rise wards elsewhere, pocket parks.

const P := CityData.BLOCK_PITCH
const B := CityData.BLOCK_SIZE

var _rng := RandomNumberGenerator.new()
var _property_beacons: Dictionary = {}   # id -> MeshInstance3D
var _property_labels: Dictionary = {}    # id -> Label3D
var _time := 0.0

var mat_asphalt: StandardMaterial3D
var mat_sidewalk: StandardMaterial3D
var mat_tower: StandardMaterial3D
var mat_mid_a: StandardMaterial3D
var mat_mid_b: StandardMaterial3D
var mat_mid_c: StandardMaterial3D
var mat_dock: StandardMaterial3D
var mat_window_cyan: StandardMaterial3D
var mat_window_warm: StandardMaterial3D
var mat_window_violet: StandardMaterial3D
var mat_obsidian: StandardMaterial3D
var mat_lane: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_leaf: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_lamp: StandardMaterial3D
var mat_pole: StandardMaterial3D
var mat_villa: StandardMaterial3D
var mat_roof: StandardMaterial3D
var mat_sale: StandardMaterial3D
var mat_owned: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 20261021
	_make_materials()
	_build_ground()
	_build_lane_lines()
	for i in range(-2, 3):
		for j in range(-2, 3):
			_build_block(i, j)
	_build_parked_cars()
	_build_boundary()
	_build_district_signs()
	GameState.property_purchased.connect(_on_property_purchased)
	for prop in CityData.PROPERTIES:
		if GameState.owns_property(prop["id"]):
			_on_property_purchased(prop["id"])


func _process(delta: float) -> void:
	_time += delta
	for id in _property_beacons:
		var beacon: MeshInstance3D = _property_beacons[id]
		beacon.rotation.y += delta * 1.2
		beacon.position.y = beacon.get_meta("base_y") + sin(_time * 2.0 + beacon.position.x) * 0.25


# ------------------------------------------------------------------ materials
func _make_materials() -> void:
	mat_asphalt = Palette.mat(Color(0.075, 0.078, 0.1), 0.95)
	mat_sidewalk = Palette.mat(Color(0.2, 0.21, 0.26), 0.9)
	mat_tower = Palette.mat(Color(0.05, 0.08, 0.14), 0.15, 0.85)
	mat_mid_a = Palette.mat(Color(0.18, 0.19, 0.24), 0.8)
	mat_mid_b = Palette.mat(Color(0.26, 0.22, 0.24), 0.8)
	mat_mid_c = Palette.mat(Color(0.14, 0.17, 0.2), 0.7, 0.2)
	mat_dock = Palette.mat(Color(0.22, 0.16, 0.12), 0.9)
	mat_window_cyan = Palette.glow(Palette.CYAN, 0.9)
	mat_window_warm = Palette.glow(Palette.WARM_WHITE, 1.1)
	mat_window_violet = Palette.glow(Palette.VIOLET, 0.9)
	mat_obsidian = Palette.mat(Palette.OBSIDIAN, 0.1, 0.9)
	mat_lane = Palette.glow(Color(1.0, 0.75, 0.35), 0.45)
	mat_trunk = Palette.mat(Color(0.2, 0.14, 0.1), 0.95)
	mat_leaf = Palette.mat(Color(0.08, 0.3, 0.22), 0.9)
	mat_grass = Palette.mat(Color(0.1, 0.22, 0.14), 0.95)
	mat_lamp = Palette.glow(Palette.WARM_WHITE, 2.6)
	mat_pole = Palette.mat(Color(0.12, 0.12, 0.14), 0.5, 0.6)
	mat_villa = Palette.mat(Color(0.82, 0.78, 0.7), 0.85)
	mat_roof = Palette.mat(Color(0.2, 0.12, 0.14), 0.8)
	mat_sale = Palette.glow(Palette.GOLD, 2.5)
	mat_owned = Palette.glow(Palette.GREEN, 2.5)


# ------------------------------------------------------------------ ground & roads
func _build_ground() -> void:
	var ground := Palette.box(self, Vector3(330, 0.4, 330), Vector3(0, -0.2, 0), mat_asphalt, true, "Ground")
	ground.add_to_group("ground")


func _build_lane_lines() -> void:
	var lines := Node3D.new()
	lines.name = "LaneLines"
	add_child(lines)
	for c in [-137.0, -78.0, -26.0, 26.0, 78.0, 137.0]:
		Palette.box(lines, Vector3(0.25, 0.02, 300), Vector3(c, 0.012, 0), mat_lane, false, "LaneX")
		Palette.box(lines, Vector3(300, 0.02, 0.25), Vector3(0, 0.012, c), mat_lane, false, "LaneZ")


func _build_boundary() -> void:
	var h := CityData.CITY_HALF + 4.0
	Palette.blocker(self, Vector3(320, 30, 2), Vector3(0, 15, -h), "BoundN")
	Palette.blocker(self, Vector3(320, 30, 2), Vector3(0, 15, h), "BoundS")
	Palette.blocker(self, Vector3(2, 30, 320), Vector3(-h, 15, 0), "BoundW")
	Palette.blocker(self, Vector3(2, 30, 320), Vector3(h, 15, 0), "BoundE")
	# Low glowing kerb so the edge of the city reads visually.
	var kerb := Palette.glow(Palette.VIOLET, 0.8)
	Palette.box(self, Vector3(320, 0.6, 0.6), Vector3(0, 0.3, -h + 1.5), kerb, false)
	Palette.box(self, Vector3(320, 0.6, 0.6), Vector3(0, 0.3, h - 1.5), kerb, false)
	Palette.box(self, Vector3(0.6, 0.6, 320), Vector3(-h + 1.5, 0.3, 0), kerb, false)
	Palette.box(self, Vector3(0.6, 0.6, 320), Vector3(h - 1.5, 0.3, 0), kerb, false)


# ------------------------------------------------------------------ blocks
func _build_block(i: int, j: int) -> void:
	var center := Vector3(i * P, 0, j * P)
	var block := Node3D.new()
	block.name = "Block_%d_%d" % [i, j]
	block.position = center
	add_child(block)
	Palette.box(block, Vector3(B, 0.3, B), Vector3(0, 0.15, 0), mat_sidewalk, true, "Sidewalk")
	_build_lamps(block)
	if i == 0 and j == 0:
		_build_plaza(block)
	elif i == 2 and j == -2:
		_build_villas(block)
	elif i >= 1 and j <= -1:
		_build_towers(block)
	elif i <= -1 and j >= 1:
		_build_docks(block)
	elif absi(i) + absi(j) == 3 and _rng.randf() < 0.6:
		_build_park(block)
	else:
		_build_midrise(block)


func _build_lamps(block: Node3D) -> void:
	var o := B * 0.5 - 1.5
	for corner in [Vector3(-o, 0, -o), Vector3(o, 0, -o), Vector3(-o, 0, o), Vector3(o, 0, o)]:
		Palette.cylinder(block, 0.12, 5.0, corner + Vector3(0, 2.8, 0), mat_pole, false, "LampPole", 8)
		Palette.sphere(block, 0.32, corner + Vector3(0, 5.4, 0), mat_lamp, "LampHead")


## Four quadrants per block, each may hold one footprint.
func _quadrants() -> Array[Vector3]:
	var q := B * 0.25
	return [Vector3(-q, 0, -q), Vector3(q, 0, -q), Vector3(-q, 0, q), Vector3(q, 0, q)]


func _building(parent: Node3D, footprint: Vector2, height: float, pos: Vector3, body_mat: Material, window_mat: Material, band_step: float, band_height := 0.45) -> void:
	Palette.box(parent, Vector3(footprint.x, height, footprint.y), pos + Vector3(0, 0.3 + height * 0.5, 0), body_mat, true, "Building")
	var y := 3.0
	var count := 0
	while y < height - 2.0 and count < 14:
		Palette.box(parent, Vector3(footprint.x + 0.12, band_height, footprint.y + 0.12), pos + Vector3(0, 0.3 + y, 0), window_mat, false, "Band")
		y += band_step
		count += 1
	# Roof detail: vent block + antenna light.
	Palette.box(parent, Vector3(footprint.x * 0.35, 1.4, footprint.y * 0.35), pos + Vector3(footprint.x * 0.2, 0.3 + height + 0.7, -footprint.y * 0.15), mat_mid_c, false, "RoofVent")
	Palette.sphere(parent, 0.25, pos + Vector3(-footprint.x * 0.3, 0.3 + height + 1.0, footprint.y * 0.3), Palette.glow(Palette.RED, 3.0), "RoofBeacon")


func _build_midrise(block: Node3D) -> void:
	var mats := [mat_mid_a, mat_mid_b, mat_mid_c]
	for qpos in _quadrants():
		if _rng.randf() < 0.18:
			continue
		var fp := Vector2(_rng.randf_range(11.0, 16.0), _rng.randf_range(11.0, 16.0))
		var h := _rng.randf_range(12.0, 34.0)
		_building(block, fp, h, qpos, mats[_rng.randi_range(0, 2)], mat_window_warm, 4.0)


func _build_towers(block: Node3D) -> void:
	# Two slender towers per Heights block with cyan edge lighting.
	var slots := [Vector3(-9, 0, -8), Vector3(9, 0, 8)]
	for s in slots:
		var fp := Vector2(_rng.randf_range(13.0, 17.0), _rng.randf_range(13.0, 17.0))
		var h := _rng.randf_range(48.0, 84.0)
		_building(block, fp, h, s, mat_tower, mat_window_cyan if _rng.randf() < 0.6 else mat_window_violet, 9.0, 0.35)
		# Vertical neon spines on the four edges.
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				Palette.box(block, Vector3(0.2, h, 0.2), s + Vector3(sx * fp.x * 0.5, 0.3 + h * 0.5, sz * fp.y * 0.5), mat_window_cyan, false, "Spine")
		# Crown.
		Palette.box(block, Vector3(fp.x * 0.6, 1.2, fp.y * 0.6), s + Vector3(0, 0.3 + h + 0.6, 0), mat_window_violet, false, "Crown")
	Palette.omni(block, Vector3(0, 6, 0), Palette.CYAN, 1.4, 22.0)


func _build_docks(block: Node3D) -> void:
	# Long warehouses, container stacks and amber loading lights.
	var w1 := Vector3(-8, 0, -6)
	Palette.box(block, Vector3(18, 9, 24), w1 + Vector3(0, 4.8, 0), mat_dock, true, "Warehouse")
	Palette.box(block, Vector3(18.2, 1.0, 0.3), w1 + Vector3(0, 7.5, 12.1), Palette.glow(Palette.AMBER, 1.8), false, "DockSign")
	Palette.box(block, Vector3(6, 6, 0.3), w1 + Vector3(-4, 3.3, 12.1), Palette.mat(Color(0.1, 0.1, 0.12), 0.6, 0.6), false, "Door")
	var w2 := Vector3(9, 0, 10)
	Palette.box(block, Vector3(16, 7, 14), w2 + Vector3(0, 3.8, 0), mat_mid_b, true, "Warehouse2")
	Palette.box(block, Vector3(16.2, 0.6, 0.3), w2 + Vector3(0, 5.8, -7.1), Palette.glow(Palette.AMBER, 1.8), false, "DockSign2")
	var colors := [Color(0.75, 0.25, 0.2), Color(0.2, 0.45, 0.7), Color(0.85, 0.6, 0.15), Color(0.25, 0.55, 0.3)]
	for k in range(7):
		var cpos := Vector3(_rng.randf_range(2, 16), 0, _rng.randf_range(-16, -4))
		var stack := 1 + int(_rng.randf() < 0.5)
		for s in range(stack):
			Palette.box(block, Vector3(2.4, 2.5, 6.0), cpos + Vector3(0, 0.3 + 1.25 + s * 2.5, 0), Palette.mat(colors[(k + s) % colors.size()], 0.7, 0.3), true, "Container")
	Palette.omni(block, Vector3(0, 5, 0), Palette.AMBER, 1.6, 20.0)


func _build_park(block: Node3D) -> void:
	Palette.box(block, Vector3(B - 4, 0.12, B - 4), Vector3(0, 0.36, 0), mat_grass, false, "Lawn")
	for k in range(9):
		var tp := Vector3(_rng.randf_range(-15, 15), 0, _rng.randf_range(-15, 15))
		if tp.length() < 5.0:
			continue
		var th := _rng.randf_range(2.5, 4.0)
		Palette.cylinder(block, 0.25, th, tp + Vector3(0, 0.3 + th * 0.5, 0), mat_trunk, true, "Trunk", 8)
		Palette.sphere(block, _rng.randf_range(1.8, 2.8), tp + Vector3(0, 0.3 + th + 1.2, 0), mat_leaf, "Canopy")
	# Fountain.
	Palette.cylinder(block, 3.2, 0.8, Vector3(0, 0.7, 0), mat_sidewalk, true, "FountainRim", 20)
	Palette.cylinder(block, 2.8, 0.2, Vector3(0, 1.15, 0), Palette.translucent_glow(Palette.CYAN, 0.5, 1.5), false, "Water", 20)
	Palette.cylinder(block, 0.4, 2.2, Vector3(0, 1.9, 0), mat_obsidian, false, "Spout", 10)
	Palette.omni(block, Vector3(0, 3, 0), Palette.CYAN, 1.2, 10.0)


func _build_plaza(block: Node3D) -> void:
	# Core Plaza: obsidian obelisk ringed by pillars - the city's landmark.
	Palette.cylinder(block, 10.0, 0.5, Vector3(0, 0.55, 0), Palette.mat(Color(0.12, 0.12, 0.17), 0.6, 0.3), true, "Dais", 32)
	Palette.box(block, Vector3(3, 24, 3), Vector3(0, 12.8, 0), mat_obsidian, true, "Obelisk")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Palette.box(block, Vector3(0.12, 23, 0.12), Vector3(sx * 1.5, 12.3, sz * 1.5), mat_window_violet, false, "ObeliskEdge")
	Palette.sphere(block, 1.0, Vector3(0, 25.6, 0), Palette.glow(Palette.VIOLET, 4.0), "ObeliskCore")
	for k in range(8):
		var a := k * TAU / 8.0
		var pp := Vector3(cos(a) * 8.0, 0, sin(a) * 8.0)
		Palette.cylinder(block, 0.5, 5.0, pp + Vector3(0, 3.3, 0), mat_obsidian, true, "Pillar", 12)
		Palette.sphere(block, 0.3, pp + Vector3(0, 6.0, 0), mat_window_cyan, "PillarCap")
	for k in range(4):
		var a := k * TAU / 4.0 + PI / 4.0
		Palette.omni(block, Vector3(cos(a) * 6, 4, sin(a) * 6), Palette.VIOLET, 2.2, 16.0)
	# Core station shelter (VIP pick-up in the shuttle job happens on the road beside it).
	Palette.box(block, Vector3(10, 0.3, 4), Vector3(14, 4.2, -16), mat_tower, false, "StationRoof")
	for sx in [-4.5, 4.5]:
		Palette.cylinder(block, 0.15, 4.0, Vector3(14 + sx, 2.3, -16), mat_pole, true, "StationPost", 8)
	Palette.box(block, Vector3(9.8, 0.4, 0.2), Vector3(14, 3.9, -17.9), mat_window_cyan, false, "StationSign")


func _build_villas(block: Node3D) -> void:
	# The Heights residential plots: each property in CityData gets a house + beacon.
	Palette.box(block, Vector3(B - 4, 0.12, B - 4), Vector3(0, 0.36, 0), mat_grass, false, "Lawn")
	Palette.box(block, Vector3(B - 4, 0.14, 5), Vector3(0, 0.37, -6), mat_sidewalk, false, "Path")
	for prop in CityData.PROPERTIES:
		var local: Vector3 = prop["position"] - block.position
		var sz: Vector3 = prop["size"]
		var style: String = prop["style"]
		if style == "plot":
			Palette.box(block, Vector3(sz.x, 0.3, sz.z), local + Vector3(0, 0.55, 0), Palette.mat(Color(0.3, 0.25, 0.2), 0.95), true, "Plot")
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					Palette.box(block, Vector3(0.15, 1.2, 0.15), local + Vector3(sx * sz.x * 0.5, 1.0, sz2 * sz.z * 0.5), mat_pole, false, "Stake")
		else:
			var body_mat := mat_villa if style == "villa" else (mat_tower if style == "penthouse" else mat_obsidian)
			Palette.box(block, sz, local + Vector3(0, 0.3 + sz.y * 0.5, 0), body_mat, true, "House")
			# Door + window glow.
			Palette.box(block, Vector3(1.2, 2.2, 0.15), local + Vector3(0, 1.4, sz.z * 0.5 + 0.05), Palette.glow(Palette.AMBER, 1.5), false, "Door")
			var wy := 2.8
			while wy < sz.y - 0.8:
				Palette.box(block, Vector3(sz.x + 0.1, 0.4, sz.z + 0.1), local + Vector3(0, 0.3 + wy, 0), mat_window_warm if style == "villa" else mat_window_cyan, false, "Band")
				wy += 3.0
			if style == "villa":
				var roof := Palette.box(block, Vector3(sz.x * 0.75, sz.x * 0.75, sz.z + 0.6), local + Vector3(0, 0.3 + sz.y, 0), mat_roof, true, "Roof")
				roof.rotation.z = PI / 4.0
			else:
				Palette.box(block, Vector3(sz.x * 0.7, 0.6, sz.z * 0.7), local + Vector3(0, 0.3 + sz.y + 0.3, 0), mat_window_violet, false, "RoofGlow")
		# Beacon + label.
		var beacon := Palette.box(block, Vector3(0.7, 0.7, 0.7), local + Vector3(0, sz.y + 3.0, 0), mat_sale, false, "Beacon")
		beacon.rotation = Vector3(PI / 4.0, 0, PI / 4.0)
		beacon.set_meta("base_y", beacon.position.y)
		_property_beacons[prop["id"]] = beacon
		var lbl := Palette.label3d(block, "%s\nFOR SALE  %s cr" % [prop["name"], UIKit.fmt_int(prop["price"])], local + Vector3(0, sz.y + 4.6, 0), Palette.GOLD, 40, 0.035)
		_property_labels[prop["id"]] = lbl
	Palette.omni(block, Vector3(0, 6, 0), Palette.GOLD, 1.0, 26.0)


func _build_parked_cars() -> void:
	var cars := Node3D.new()
	cars.name = "ParkedCars"
	add_child(cars)
	var colors := [Color(0.1, 0.1, 0.12), Color(0.5, 0.52, 0.56), Color(0.35, 0.08, 0.1), Color(0.08, 0.2, 0.4), Color(0.6, 0.45, 0.1)]
	for k in range(18):
		var i := _rng.randi_range(-2, 2)
		var j := _rng.randi_range(-2, 2)
		if i == 0 and j == 0:
			continue
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var along_x := _rng.randf() < 0.5
		var off := B * 0.5 + 1.8
		var pos: Vector3
		var rot := 0.0
		if along_x:
			pos = Vector3(i * P + _rng.randf_range(-14, 14), 0.55, j * P + side * off)
		else:
			pos = Vector3(i * P + side * off, 0.55, j * P + _rng.randf_range(-14, 14))
			rot = PI / 2.0
		var c: Color = colors[_rng.randi_range(0, colors.size() - 1)]
		var car := Palette.box(cars, Vector3(4.2, 0.7, 1.9), pos, Palette.mat(c, 0.35, 0.6), true, "ParkedCar")
		car.rotation.y = rot
		Palette.box(car, Vector3(2.0, 0.55, 1.6), Vector3(-0.2, 0.6, 0), Palette.glass(Color(0.1, 0.15, 0.25), 0.8), false, "Cabin")


func _build_district_signs() -> void:
	Palette.label3d(self, "THE HEIGHTS", Vector3(78, 42, -78), Palette.CYAN, 110, 0.06)
	Palette.label3d(self, "NEON DOCKS", Vector3(-78, 22, 78), Palette.AMBER, 110, 0.06)
	Palette.label3d(self, "CORE PLAZA", Vector3(0, 30, 0), Palette.VIOLET, 90, 0.06)
	Palette.label3d(self, "WEST WARDS", Vector3(-78, 26, -52), Palette.WARM_WHITE, 80, 0.06)


# ------------------------------------------------------------------ property feedback
func _on_property_purchased(property_id: String) -> void:
	if _property_beacons.has(property_id):
		(_property_beacons[property_id] as MeshInstance3D).material_override = mat_owned
	if _property_labels.has(property_id):
		var lbl: Label3D = _property_labels[property_id]
		var prop := _property_by_id(property_id)
		lbl.text = "%s\nOWNED" % prop.get("name", "")
		lbl.modulate = Palette.GREEN


func _property_by_id(property_id: String) -> Dictionary:
	for prop in CityData.PROPERTIES:
		if prop["id"] == property_id:
			return prop
	return {}
