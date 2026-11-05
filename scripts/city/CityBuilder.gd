extends Node3D
class_name CityBuilder
## Procedurally assembles Nova Aetheris from CityData as a bright, sunlit modern metropolis:
## glass curtain-wall towers on white podiums with terraces, balconied mid-rises with
## planters, mixed-use retail blocks, lawns, hedges, street trees, flowerbeds, pools and
## fountains, dual-carriageway roads with green medians, painted lanes, crosswalks, lamp
## posts, cafe seating, sports cars (parked and cruising), pedestrians and a waterfront.
## The road grid, block layout, property positions, job stages, zone triggers and every
## gameplay hook are unchanged; only the visuals and dressing are new.
##
## Districts: Core Plaza (centre), The Heights (NE towers + property plots),
## the Waterfront commerce blocks (SW), mixed-use wards elsewhere, pocket parks.

const P := CityData.BLOCK_PITCH
const B := CityData.BLOCK_SIZE
const LANE_OFFSET := 2.3          # centre of the inner lane, measured from the road centre line
const PARK_OFFSET := 5.0          # kerb-side parking lane
const PEDESTRIANS := 34
const TRAFFIC_CARS := 6

var _rng := RandomNumberGenerator.new()
var _property_beacons: Dictionary = {}   # id -> MeshInstance3D
var _property_labels: Dictionary = {}    # id -> Label3D
var _time := 0.0

var mat_asphalt: StandardMaterial3D
var mat_pavement: StandardMaterial3D
var mat_kerb: StandardMaterial3D
var mat_lane: StandardMaterial3D
var mat_lane_yellow: StandardMaterial3D
var mat_white: StandardMaterial3D
var mat_grey: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_glass_dark: StandardMaterial3D
var mat_glass_clear: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_pole: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_hedge: StandardMaterial3D
var mat_trunk: StandardMaterial3D
var mat_leaf: StandardMaterial3D
var mat_leaf2: StandardMaterial3D
var mat_water: StandardMaterial3D
var mat_umbrella: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_soil: StandardMaterial3D
var mat_lamp: StandardMaterial3D
var mat_sale: StandardMaterial3D
var mat_owned: StandardMaterial3D
var mat_flowers: Array[StandardMaterial3D] = []
var car_paints: Array[Color] = []


func _ready() -> void:
	_rng.seed = 20261021
	_make_materials()
	_build_ground()
	_build_roads()
	for i in range(-2, 3):
		for j in range(-2, 3):
			_build_block(i, j)
	_build_street_trees()
	_build_parked_cars()
	_build_traffic()
	_build_pedestrians()
	_build_waterfront()
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


# ------------------------------------------------------------------ materials (PBR)
func _make_materials() -> void:
	mat_asphalt = Palette.pbr(Color(0.17, 0.17, 0.165), 0.95, 0.0)
	mat_pavement = Palette.pbr(Color(0.74, 0.73, 0.7), 0.82, 0.0)
	mat_kerb = Palette.pbr(Color(0.6, 0.6, 0.58), 0.8, 0.0)
	mat_lane = Palette.pbr(Color(0.93, 0.93, 0.9), 0.6, 0.0)
	mat_lane_yellow = Palette.pbr(Color(0.92, 0.76, 0.28), 0.6, 0.0)
	mat_white = Palette.pbr(Color(0.9, 0.9, 0.88), 0.72, 0.0)
	mat_grey = Palette.pbr(Color(0.6, 0.62, 0.64), 0.78, 0.0)
	mat_glass = Palette.pbr(Color(0.5, 0.66, 0.82), 0.06, 0.88)
	mat_glass_dark = Palette.pbr(Color(0.22, 0.3, 0.38), 0.05, 0.92)
	mat_glass_clear = Palette.glass(Color(0.75, 0.88, 0.96), 0.3)
	mat_metal = Palette.pbr(Color(0.6, 0.62, 0.65), 0.3, 0.9)
	mat_pole = Palette.pbr(Color(0.86, 0.87, 0.89), 0.45, 0.6)
	mat_grass = Palette.pbr(Color(0.32, 0.54, 0.2), 0.95, 0.0)
	mat_hedge = Palette.pbr(Color(0.2, 0.43, 0.17), 0.92, 0.0)
	mat_trunk = Palette.pbr(Color(0.36, 0.26, 0.17), 0.9, 0.0)
	mat_leaf = Palette.pbr(Color(0.27, 0.52, 0.22), 0.9, 0.0)
	mat_leaf2 = Palette.pbr(Color(0.19, 0.44, 0.2), 0.9, 0.0)
	mat_water = Palette.pbr(Color(0.28, 0.58, 0.78), 0.03, 0.5, 0.86)
	mat_umbrella = Palette.pbr(Color(0.96, 0.96, 0.94), 0.7, 0.0)
	mat_wood = Palette.pbr(Color(0.55, 0.4, 0.26), 0.75, 0.0)
	mat_soil = Palette.pbr(Color(0.38, 0.3, 0.22), 0.95, 0.0)
	mat_lamp = Palette.mat(Color(0.95, 0.95, 0.9), 0.4, 0.0, Palette.WARM_WHITE, 0.6)
	mat_sale = Palette.glow(Palette.GOLD, 2.0)
	mat_owned = Palette.glow(Palette.GREEN, 2.0)
	for c in [Color(0.9, 0.2, 0.25), Color(0.95, 0.75, 0.2), Color(0.7, 0.3, 0.85), Color(0.95, 0.5, 0.6)]:
		mat_flowers.append(Palette.pbr(c, 0.7, 0.0))
	car_paints = [Color(0.85, 0.86, 0.88), Color(0.1, 0.1, 0.12), Color(0.6, 0.62, 0.66), Color(0.75, 0.08, 0.1), Color(0.12, 0.25, 0.5), Color(0.92, 0.92, 0.9), Color(0.2, 0.2, 0.22)]


# ------------------------------------------------------------------ ground & roads
func _build_ground() -> void:
	var ground := Palette.box(self, Vector3(330, 0.4, 330), Vector3(0, -0.2, 0), mat_asphalt, true, "Ground")
	ground.add_to_group("ground")


## Dual carriageways: a hedge-topped grass median between intersections, dashed lane
## dividers, solid edge lines and zebra crossings on every intersection approach.
func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	add_child(roads)
	var lanes := RoadNetwork.LANES
	var n := lanes.size()
	for a in range(n):
		var c: float = lanes[a]
		for b in range(n - 1):
			var z0: float = lanes[b] + 9.0
			var z1: float = lanes[b + 1] - 9.0
			var mid := (z0 + z1) * 0.5
			var length := z1 - z0
			# vertical road x = c, segment between two intersections
			Palette.box(roads, Vector3(2.0, 0.16, length), Vector3(c, 0.08, mid), mat_grass, false, "Median")
			Palette.box(roads, Vector3(1.0, 0.7, length - 2.0), Vector3(c, 0.5, mid), mat_hedge, true, "MedianHedge")
			# horizontal road z = c
			Palette.box(roads, Vector3(length, 0.16, 2.0), Vector3(mid, 0.08, c), mat_grass, false, "Median")
			Palette.box(roads, Vector3(length - 2.0, 0.7, 1.0), Vector3(mid, 0.5, c), mat_hedge, true, "MedianHedge")
			# dashed lane dividers at +-3.5 and solid edge lines at +-5.9
			var d := z0 + 1.0
			while d < z1 - 2.0:
				for side in [-3.5, 3.5]:
					Palette.box(roads, Vector3(0.15, 0.02, 2.0), Vector3(c + side, 0.012, d + 1.0), mat_lane, false, "Dash")
					Palette.box(roads, Vector3(2.0, 0.02, 0.15), Vector3(d + 1.0, 0.012, c + side), mat_lane, false, "Dash")
				d += 5.0
			for side in [-5.9, 5.9]:
				Palette.box(roads, Vector3(0.14, 0.02, length), Vector3(c + side, 0.012, mid), mat_lane, false, "Edge")
				Palette.box(roads, Vector3(length, 0.02, 0.14), Vector3(mid, 0.012, c + side), mat_lane, false, "Edge")
	# crosswalks on each approach to every intersection
	for a in range(n):
		for b in range(n):
			var node := Vector3(lanes[a], 0, lanes[b])
			for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
				var at: Vector3 = node + dir * 7.6
				if absf(at.x) > 150.0 or absf(at.z) > 150.0:
					continue
				var across := Vector3(1, 0, 0) if absf(dir.z) > 0.5 else Vector3(0, 0, 1)
				for k in range(-4, 5):
					var stripe_pos: Vector3 = at + across * (k * 1.3)
					var size := Vector3(0.6, 0.02, 2.6) if absf(dir.z) > 0.5 else Vector3(2.6, 0.02, 0.6)
					Palette.box(roads, size, stripe_pos + Vector3(0, 0.013, 0), mat_lane, false, "Zebra")


func _build_boundary() -> void:
	var h := CityData.CITY_HALF + 4.0
	Palette.blocker(self, Vector3(320, 30, 2), Vector3(0, 15, -h), "BoundN")
	Palette.blocker(self, Vector3(320, 30, 2), Vector3(0, 15, h), "BoundS")
	Palette.blocker(self, Vector3(2, 30, 320), Vector3(-h, 15, 0), "BoundW")
	Palette.blocker(self, Vector3(2, 30, 320), Vector3(h, 15, 0), "BoundE")
	# low white kerb and hedge so the edge of the city reads
	for side: Vector3 in [Vector3(0, 0, -h + 1.5), Vector3(0, 0, h - 1.5), Vector3(-h + 1.5, 0, 0)]:
		var size := Vector3(320, 0.5, 0.6) if side.x == 0.0 else Vector3(0.6, 0.5, 320)
		Palette.box(self, size, side + Vector3(0, 0.25, 0), mat_kerb, false)
		var hsize := Vector3(320, 1.0, 1.2) if side.x == 0.0 else Vector3(1.2, 1.0, 320)
		Palette.box(self, hsize, side + Vector3(0, 0.95, 0) + (Vector3(0, 0, -1.5) if side.z < 0 else (Vector3(0, 0, 1.5) if side.z > 0 else Vector3(-1.5, 0, 0))), mat_hedge, false)


# ------------------------------------------------------------------ blocks
func _build_block(i: int, j: int) -> void:
	var center := Vector3(i * P, 0, j * P)
	var block := Node3D.new()
	block.name = "Block_%d_%d" % [i, j]
	block.position = center
	add_child(block)
	Palette.box(block, Vector3(B, 0.3, B), Vector3(0, 0.15, 0), mat_pavement, true, "Sidewalk")
	for e: Vector3 in [Vector3(0, 0, -B * 0.5), Vector3(0, 0, B * 0.5), Vector3(-B * 0.5, 0, 0), Vector3(B * 0.5, 0, 0)]:
		var size := Vector3(B + 0.3, 0.32, 0.3) if e.x == 0.0 else Vector3(0.3, 0.32, B + 0.3)
		Palette.box(block, size, e + Vector3(0, 0.16, 0), mat_kerb, false, "Kerb")
	_build_lamps(block)
	if i == 0 and j == 0:
		_build_plaza(block)
	elif i == 2 and j == -2:
		_build_villas(block)
	elif i >= 1 and j <= -1:
		_build_towers(block)
	elif i <= -1 and j >= 1:
		_build_commerce(block)
	elif absi(i) + absi(j) == 3 and _rng.randf() < 0.6:
		_build_park(block)
	else:
		_build_midrise(block)


func _build_lamps(block: Node3D) -> void:
	var o := B * 0.5 - 1.5
	for corner: Vector3 in [Vector3(-o, 0, -o), Vector3(o, 0, -o), Vector3(-o, 0, o), Vector3(o, 0, o)]:
		_lamp_post(block, corner, -corner.normalized())


## Tall white post with a curved arm and a flat LED head reaching over the road.
func _lamp_post(parent: Node3D, at: Vector3, toward: Vector3) -> void:
	var post := Node3D.new()
	post.position = at + Vector3(0, 0.3, 0)
	post.rotation.y = atan2(toward.x, toward.z)
	parent.add_child(post)
	Palette.cylinder(post, 0.14, 7.0, Vector3(0, 3.5, 0), mat_pole, false, "Pole", 10)
	var arm := Palette.cylinder(post, 0.08, 2.6, Vector3(0, 6.9, -1.0), mat_pole, false, "Arm", 8)
	arm.rotation.x = PI * 0.5 + 0.35
	Palette.box(post, Vector3(0.4, 0.12, 1.1), Vector3(0, 7.2, -2.0), mat_pole, false, "Head")
	Palette.box(post, Vector3(0.34, 0.04, 1.0), Vector3(0, 7.13, -2.0), mat_lamp, false, "Led")


func _quadrants() -> Array[Vector3]:
	var q := B * 0.25
	return [Vector3(-q, 0, -q), Vector3(q, 0, -q), Vector3(-q, 0, q), Vector3(q, 0, q)]


# ---- dressing helpers
func _tree(parent: Node3D, at: Vector3, height := 3.6, canopy := 2.0) -> void:
	Palette.cylinder(parent, 0.2, height, at + Vector3(0, height * 0.5, 0), mat_trunk, true, "Trunk", 8)
	Palette.sphere(parent, canopy, at + Vector3(0, height + canopy * 0.55, 0), mat_leaf if _rng.randf() < 0.6 else mat_leaf2, "Canopy")
	Palette.sphere(parent, canopy * 0.7, at + Vector3(canopy * 0.4, height + canopy * 1.1, canopy * 0.2), mat_leaf2, "Canopy")


func _hedge(parent: Node3D, size: Vector3, at: Vector3) -> void:
	Palette.box(parent, size, at + Vector3(0, size.y * 0.5, 0), mat_hedge, false, "Hedge")


func _planter(parent: Node3D, at: Vector3, width := 1.6) -> void:
	Palette.box(parent, Vector3(width, 0.6, 0.7), at + Vector3(0, 0.3, 0), mat_white, false, "Planter")
	Palette.box(parent, Vector3(width - 0.2, 0.45, 0.5), at + Vector3(0, 0.78, 0), mat_hedge, false, "PlanterGreen")


func _flowerbed(parent: Node3D, at: Vector3, size: Vector2) -> void:
	Palette.box(parent, Vector3(size.x, 0.25, size.y), at + Vector3(0, 0.125, 0), mat_soil, false, "Bed")
	Palette.box(parent, Vector3(size.x + 0.3, 0.3, 0.25), at + Vector3(0, 0.15, size.y * 0.5), mat_white, false, "BedEdge")
	Palette.box(parent, Vector3(size.x + 0.3, 0.3, 0.25), at + Vector3(0, 0.15, -size.y * 0.5), mat_white, false, "BedEdge")
	for k in range(int(size.x * size.y * 0.5)):
		var p := at + Vector3(_rng.randf_range(-size.x * 0.45, size.x * 0.45), 0.35, _rng.randf_range(-size.y * 0.45, size.y * 0.45))
		Palette.sphere(parent, 0.18, p, mat_flowers[_rng.randi_range(0, mat_flowers.size() - 1)], "Flower")


func _umbrella_table(parent: Node3D, at: Vector3) -> void:
	Palette.cylinder(parent, 0.55, 0.06, at + Vector3(0, 0.75, 0), mat_white, false, "Table", 16)
	Palette.cylinder(parent, 0.04, 0.75, at + Vector3(0, 0.37, 0), mat_metal, false, "TableLeg", 8)
	Palette.cylinder(parent, 0.04, 2.4, at + Vector3(0, 1.95, 0), mat_metal, false, "UmbrellaPole", 8)
	var top := Palette.cylinder(parent, 1.3, 0.1, at + Vector3(0, 2.4, 0), mat_umbrella, false, "Umbrella", 16)
	top.scale.y = 1.0
	for k in range(3):
		var a := k * TAU / 3.0 + 0.5
		var c := at + Vector3(cos(a) * 0.95, 0, sin(a) * 0.95)
		Palette.box(parent, Vector3(0.45, 0.06, 0.45), c + Vector3(0, 0.45, 0), mat_wood, false, "Seat")
		Palette.box(parent, Vector3(0.45, 0.5, 0.06), c + Vector3(-cos(a) * 0.2, 0.7, -sin(a) * 0.2), mat_wood, false, "SeatBack").rotation.y = -a + PI * 0.5


func _bench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	b.position = at
	b.rotation.y = yaw
	parent.add_child(b)
	Palette.box(b, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.48, 0), mat_wood, false, "BenchSeat")
	Palette.box(b, Vector3(1.8, 0.45, 0.06), Vector3(0, 0.75, -0.25), mat_wood, false, "BenchBack")
	for sx in [-0.75, 0.75]:
		Palette.box(b, Vector3(0.08, 0.45, 0.5), Vector3(sx, 0.24, 0), mat_metal, false, "BenchLeg")


func _pool(parent: Node3D, at: Vector3, radius: float, fountain := true) -> void:
	Palette.cylinder(parent, radius + 0.5, 0.5, at + Vector3(0, 0.25, 0), mat_white, true, "PoolRim", 28)
	Palette.cylinder(parent, radius, 0.3, at + Vector3(0, 0.42, 0), mat_water, false, "Water", 28)
	if fountain:
		Palette.cylinder(parent, 0.35, 1.6, at + Vector3(0, 1.2, 0), mat_white, false, "Spout", 12)
		Palette.cylinder(parent, 0.9, 0.08, at + Vector3(0, 2.0, 0), mat_white, false, "SpoutBowl", 16)
		Palette.sphere(parent, 0.4, at + Vector3(0, 2.25, 0), Palette.glass(Color(0.8, 0.92, 1.0), 0.5), "Jet")


func _roof_garden(parent: Node3D, center: Vector3, size: Vector2) -> void:
	Palette.box(parent, Vector3(size.x - 1.0, 0.15, size.y - 1.0), center + Vector3(0, 0.08, 0), mat_grass, false, "RoofLawn")
	for sx in [-1.0, 1.0]:
		_hedge(parent, Vector3(size.x - 1.0, 0.7, 0.6), center + Vector3(0, 0.15, sx * (size.y * 0.5 - 0.8)))
		_hedge(parent, Vector3(0.6, 0.7, size.y - 2.4), center + Vector3(sx * (size.x * 0.5 - 0.8), 0.15, 0))
	Palette.box(parent, Vector3(size.x, 0.9, 0.12), center + Vector3(0, 0.45, size.y * 0.5), mat_glass_clear, false, "Railing")
	Palette.box(parent, Vector3(size.x, 0.9, 0.12), center + Vector3(0, 0.45, -size.y * 0.5), mat_glass_clear, false, "Railing")
	Palette.box(parent, Vector3(0.12, 0.9, size.y), center + Vector3(size.x * 0.5, 0.45, 0), mat_glass_clear, false, "Railing")
	Palette.box(parent, Vector3(0.12, 0.9, size.y), center + Vector3(-size.x * 0.5, 0.45, 0), mat_glass_clear, false, "Railing")


# ---- buildings
## Glass curtain-wall tower on a three-storey white podium with a planted terrace.
func _glass_tower(parent: Node3D, at: Vector3, fp: Vector2, height: float, retail := true) -> void:
	var podium := Vector2(fp.x + 7.0, fp.y + 7.0)
	var ph := 10.0
	Palette.box(parent, Vector3(podium.x, ph, podium.y), at + Vector3(0, 0.3 + ph * 0.5, 0), mat_white, true, "Podium")
	if retail:
		Palette.box(parent, Vector3(podium.x + 0.1, 3.4, podium.y + 0.1), at + Vector3(0, 0.3 + 2.0, 0), mat_glass_dark, false, "Storefront")
		Palette.box(parent, Vector3(podium.x + 0.6, 0.35, podium.y + 0.6), at + Vector3(0, 0.3 + 3.9, 0), mat_white, false, "Canopy")
	Palette.box(parent, Vector3(podium.x + 0.1, 2.6, podium.y + 0.1), at + Vector3(0, 0.3 + 6.6, 0), mat_glass, false, "PodiumGlass")
	# terrace on the podium roof around the tower footprint
	var ty := 0.3 + ph
	for sx in [-1.0, 1.0]:
		_hedge(parent, Vector3(podium.x - 1.5, 0.6, 0.5), at + Vector3(0, ty, sx * (podium.y * 0.5 - 0.6)))
		_hedge(parent, Vector3(0.5, 0.6, podium.y - 1.5), at + Vector3(sx * (podium.x * 0.5 - 0.6), ty, 0))
		_planter(parent, at + Vector3(sx * (fp.x * 0.5 + 2.2), ty, fp.y * 0.5 + 2.0), 1.4)
		_umbrella_table(parent, at + Vector3(sx * (fp.x * 0.5 + 2.4), ty, -(fp.y * 0.5 + 2.2)))
	# tower: glass body, white floor bands, white corner columns
	Palette.box(parent, Vector3(fp.x, height, fp.y), at + Vector3(0, ty + height * 0.5, 0), mat_glass, true, "Tower")
	var y := 3.6
	while y < height - 1.0:
		Palette.box(parent, Vector3(fp.x + 0.3, 0.32, fp.y + 0.3), at + Vector3(0, ty + y, 0), mat_white, false, "FloorBand")
		y += 3.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Palette.box(parent, Vector3(0.5, height, 0.5), at + Vector3(sx * fp.x * 0.5, ty + height * 0.5, sz * fp.y * 0.5), mat_white, false, "Column")
	Palette.box(parent, Vector3(fp.x + 0.4, 1.0, fp.y + 0.4), at + Vector3(0, ty + height + 0.5, 0), mat_white, false, "Parapet")
	_roof_garden(parent, at + Vector3(0, ty + height + 1.0, 0), Vector2(fp.x - 1.5, fp.y - 1.5))
	Palette.box(parent, Vector3(fp.x * 0.3, 2.2, fp.y * 0.3), at + Vector3(fp.x * 0.25, ty + height + 2.1, -fp.y * 0.25), mat_grey, false, "RoofPlant")


## White / grey mid-rise with balconies, glass railings and balcony planters.
func _midrise_building(parent: Node3D, at: Vector3, fp: Vector2, height: float, body: Material) -> void:
	Palette.box(parent, Vector3(fp.x, height, fp.y), at + Vector3(0, 0.3 + height * 0.5, 0), body, true, "Building")
	Palette.box(parent, Vector3(fp.x + 0.1, 3.2, fp.y + 0.1), at + Vector3(0, 0.3 + 1.9, 0), mat_glass_dark, false, "Retail")
	Palette.box(parent, Vector3(fp.x + 0.8, 0.3, fp.y + 0.8), at + Vector3(0, 0.3 + 3.6, 0), mat_white, false, "Canopy")
	var y := 6.5
	var floor_i := 0
	while y < height - 1.5:
		# window strips
		Palette.box(parent, Vector3(fp.x + 0.08, 1.5, fp.y + 0.08), at + Vector3(0, 0.3 + y, 0), mat_glass, false, "Windows")
		# balcony on the street-facing side (alternating sides)
		var side := 1.0 if floor_i % 2 == 0 else -1.0
		var bz := at.z + side * (fp.y * 0.5 + 0.75)
		Palette.box(parent, Vector3(fp.x * 0.8, 0.22, 1.5), Vector3(at.x, 0.3 + y - 0.9, bz), mat_white, false, "Balcony")
		Palette.box(parent, Vector3(fp.x * 0.8, 1.0, 0.08), Vector3(at.x, 0.3 + y - 0.3, bz + side * 0.72), mat_glass_clear, false, "BalconyRail")
		Palette.box(parent, Vector3(fp.x * 0.5, 0.45, 0.5), Vector3(at.x - fp.x * 0.1, 0.3 + y - 0.55, bz + side * 0.35), mat_hedge, false, "BalconyPlants")
		y += 3.2
		floor_i += 1
	Palette.box(parent, Vector3(fp.x + 0.3, 0.8, fp.y + 0.3), at + Vector3(0, 0.3 + height + 0.4, 0), mat_white, false, "Parapet")
	if _rng.randf() < 0.6:
		_roof_garden(parent, at + Vector3(0, 0.3 + height + 0.8, 0), Vector2(fp.x - 1.0, fp.y - 1.0))


func _build_midrise(block: Node3D) -> void:
	var mats := [mat_white, mat_grey, mat_white]
	for qpos in _quadrants():
		if _rng.randf() < 0.18:
			_flowerbed(block, qpos, Vector2(6, 4))
			_bench(block, qpos + Vector3(0, 0.3, 4.0), 0.0)
			continue
		var fp := Vector2(_rng.randf_range(11.0, 15.0), _rng.randf_range(11.0, 15.0))
		var h := _rng.randf_range(14.0, 34.0)
		_midrise_building(block, qpos, fp, h, mats[_rng.randi_range(0, 2)])
	# a little cafe terrace on the pavement edge
	for k in range(2):
		_umbrella_table(block, Vector3(-12 + k * 5.0, 0.3, 17.0))


func _build_towers(block: Node3D) -> void:
	var slots := [Vector3(-9, 0, -8), Vector3(9, 0, 8)]
	for s: Vector3 in slots:
		var fp := Vector2(_rng.randf_range(12.0, 15.0), _rng.randf_range(12.0, 15.0))
		var h := _rng.randf_range(48.0, 84.0)
		_glass_tower(block, s, fp, h)
	_flowerbed(block, Vector3(10, 0.3, -12), Vector2(6, 3))
	_flowerbed(block, Vector3(-10, 0.3, 12), Vector2(6, 3))


## Mixed-use commerce by the water: white retail and office blocks with roof gardens.
func _build_commerce(block: Node3D) -> void:
	var a := Vector3(-8, 0, -6)
	Palette.box(block, Vector3(18, 12, 22), a + Vector3(0, 6.3, 0), mat_white, true, "Commerce")
	Palette.box(block, Vector3(18.1, 3.4, 22.1), a + Vector3(0, 2.0, 0), mat_glass_dark, false, "Storefront")
	Palette.box(block, Vector3(18.1, 5.0, 22.1), a + Vector3(0, 8.0, 0), mat_glass, false, "OfficeGlass")
	Palette.box(block, Vector3(18.6, 0.3, 22.6), a + Vector3(0, 3.9, 0), mat_white, false, "Canopy")
	_roof_garden(block, a + Vector3(0, 12.4, 0), Vector2(16, 20))
	var b := Vector3(9, 0, 10)
	Palette.box(block, Vector3(16, 8, 14), b + Vector3(0, 4.3, 0), mat_grey, true, "Commerce2")
	Palette.box(block, Vector3(16.1, 3.0, 14.1), b + Vector3(0, 1.8, 0), mat_glass_dark, false, "Storefront2")
	Palette.box(block, Vector3(16.1, 1.6, 14.1), b + Vector3(0, 6.2, 0), mat_glass, false, "Windows2")
	_roof_garden(block, b + Vector3(0, 8.4, 0), Vector2(14, 12))
	Palette.box(block, Vector3(15.8, 0.8, 0.2), b + Vector3(0, 4.6, -7.1), mat_white, false, "SignBand")
	# plaza with planters and a pool between the buildings
	_pool(block, Vector3(9, 0.3, -9), 2.6, false)
	for k in range(3):
		_planter(block, Vector3(2 + k * 4.0, 0.3, 2.0), 2.4)
	_umbrella_table(block, Vector3(13, 0.3, -2))
	_umbrella_table(block, Vector3(16, 0.3, -6))


func _build_park(block: Node3D) -> void:
	Palette.box(block, Vector3(B - 4, 0.12, B - 4), Vector3(0, 0.36, 0), mat_grass, false, "Lawn")
	Palette.box(block, Vector3(B - 4, 0.14, 3.0), Vector3(0, 0.37, 0), mat_pavement, false, "Path")
	Palette.box(block, Vector3(3.0, 0.14, B - 4), Vector3(0, 0.37, 0), mat_pavement, false, "Path")
	for k in range(10):
		var tp := Vector3(_rng.randf_range(-15, 15), 0.3, _rng.randf_range(-15, 15))
		if tp.length() < 6.0 or absf(tp.x) < 2.5 or absf(tp.z) < 2.5:
			continue
		_tree(block, tp, _rng.randf_range(3.0, 4.5), _rng.randf_range(1.8, 2.6))
	_pool(block, Vector3(0, 0.3, 0), 3.0)
	for q in _quadrants():
		_flowerbed(block, q * 0.7 + Vector3(0, 0.3, 0), Vector2(4, 2.5))
	_bench(block, Vector3(6, 0.3, 2.5), PI)
	_bench(block, Vector3(-6, 0.3, -2.5), 0.0)


func _build_plaza(block: Node3D) -> void:
	# Core Plaza: white dais ringed by a reflecting pool, the obsidian spire kept as the landmark.
	_pool(block, Vector3(0, 0, 0), 13.0, false)
	Palette.cylinder(block, 10.0, 1.2, Vector3(0, 0.9, 0), mat_white, true, "Dais", 32)
	Palette.box(block, Vector3(3, 24, 3), Vector3(0, 13.5, 0), mat_glass_dark, true, "Obelisk")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Palette.box(block, Vector3(0.14, 23, 0.14), Vector3(sx * 1.5, 13.0, sz * 1.5), mat_metal, false, "ObeliskEdge")
	Palette.sphere(block, 1.0, Vector3(0, 26.3, 0), Palette.glow(Palette.VIOLET, 2.0), "ObeliskCore")
	for k in range(8):
		var a := k * TAU / 8.0
		var pp := Vector3(cos(a) * 8.0, 0, sin(a) * 8.0)
		Palette.cylinder(block, 0.45, 5.0, pp + Vector3(0, 4.0, 0), mat_white, true, "Pillar", 12)
		Palette.sphere(block, 0.3, pp + Vector3(0, 6.7, 0), mat_metal, "PillarCap")
	# bridges over the pool onto the dais
	for k in range(4):
		var yaw := k * PI * 0.5
		var b := Palette.box(block, Vector3(3.0, 0.3, 4.0), Vector3(0, 0.55, 11.5).rotated(Vector3.UP, yaw), mat_pavement, true, "Bridge")
		b.rotation.y = yaw
	# flowerbeds, trees and cafe seating around the square
	for q in _quadrants():
		_flowerbed(block, q * 1.5 + Vector3(0, 0.3, 0), Vector2(5, 3))
		_tree(block, q * 1.5 + Vector3(4.0, 0.3, 0), 4.4, 1.8)
	for k in range(4):
		_umbrella_table(block, Vector3(-16 + k * 3.2, 0.3, 14.0))
	_bench(block, Vector3(0, 0.3, 17.0), PI)
	# Core station shelter (VIP pick-up in the shuttle job happens on the road beside it).
	Palette.box(block, Vector3(10, 0.3, 4), Vector3(14, 4.2, -16), mat_white, false, "StationRoof")
	Palette.box(block, Vector3(9.6, 0.12, 3.6), Vector3(14, 4.0, -16), mat_glass_clear, false, "StationGlass")
	for sx in [-4.5, 4.5]:
		Palette.cylinder(block, 0.15, 4.0, Vector3(14 + sx, 2.3, -16), mat_pole, true, "StationPost", 8)
	Palette.box(block, Vector3(9.8, 0.4, 0.2), Vector3(14, 3.9, -17.9), mat_metal, false, "StationSign")
	_bench(block, Vector3(14, 0.3, -15.5), 0.0)


func _build_villas(block: Node3D) -> void:
	# The Heights residential plots: each property in CityData gets a house + beacon.
	Palette.box(block, Vector3(B - 4, 0.12, B - 4), Vector3(0, 0.36, 0), mat_grass, false, "Lawn")
	Palette.box(block, Vector3(B - 4, 0.14, 4), Vector3(0, 0.37, -6), mat_pavement, false, "Path")
	for prop in CityData.PROPERTIES:
		var local: Vector3 = prop["position"] - block.position
		var sz: Vector3 = prop["size"]
		var style: String = prop["style"]
		if style == "plot":
			Palette.box(block, Vector3(sz.x, 0.3, sz.z), local + Vector3(0, 0.55, 0), mat_soil, true, "Plot")
			for sx in [-1.0, 1.0]:
				for sz2 in [-1.0, 1.0]:
					Palette.box(block, Vector3(0.15, 1.2, 0.15), local + Vector3(sx * sz.x * 0.5, 1.0, sz2 * sz.z * 0.5), mat_pole, false, "Stake")
		else:
			var body_mat := mat_white if style != "loft" else mat_grey
			Palette.box(block, sz, local + Vector3(0, 0.3 + sz.y * 0.5, 0), body_mat, true, "House")
			Palette.box(block, Vector3(1.4, 2.4, 0.15), local + Vector3(0, 1.5, sz.z * 0.5 + 0.05), mat_glass_dark, false, "Door")
			var wy := 2.4
			while wy < sz.y - 0.8:
				Palette.box(block, Vector3(sz.x + 0.1, 1.2, sz.z + 0.1), local + Vector3(0, 0.3 + wy, 0), mat_glass, false, "Windows")
				wy += 3.0
			_roof_garden(block, local + Vector3(0, 0.3 + sz.y + 0.05, 0), Vector2(sz.x - 0.8, sz.z - 0.8))
			if style == "villa" or style == "penthouse":
				Palette.box(block, Vector3(3.0, 0.3, 2.0), local + Vector3(sz.x * 0.5 + 2.2, 0.45, 0), mat_water, false, "PlungePool")
				Palette.box(block, Vector3(3.3, 0.2, 2.3), local + Vector3(sz.x * 0.5 + 2.2, 0.35, 0), mat_white, false, "PoolRim")
		_hedge(block, Vector3(sz.x + 2.0, 0.6, 0.5), local + Vector3(0, 0.3, -sz.z * 0.5 - 1.2))
		# Beacon + label.
		var beacon := Palette.box(block, Vector3(0.7, 0.7, 0.7), local + Vector3(0, sz.y + 3.0, 0), mat_sale, false, "Beacon")
		beacon.rotation = Vector3(PI / 4.0, 0, PI / 4.0)
		beacon.set_meta("base_y", beacon.position.y)
		_property_beacons[prop["id"]] = beacon
		var lbl := Palette.label3d(block, "%s\nFOR SALE  %s cr" % [prop["name"], UIKit.fmt_int(prop["price"])], local + Vector3(0, sz.y + 4.6, 0), Palette.GOLD, 40, 0.035)
		_property_labels[prop["id"]] = lbl
	for k in range(4):
		_tree(block, Vector3(-16 + k * 10.0, 0.3, 14), 4.4, 1.7)


# ------------------------------------------------------------------ street dressing
func _build_street_trees() -> void:
	var trees := Node3D.new()
	trees.name = "StreetTrees"
	add_child(trees)
	for i in range(-2, 3):
		for j in range(-2, 3):
			var c := Vector3(i * P, 0.3, j * P)
			var o := B * 0.5 - 2.2
			var k := -13.5
			while k <= 13.5:
				_tree(trees, c + Vector3(k, 0, -o), 4.6, 1.5)
				_tree(trees, c + Vector3(k, 0, o), 4.6, 1.5)
				if absf(k) > 1.0:
					_tree(trees, c + Vector3(-o, 0, k), 4.6, 1.5)
					_tree(trees, c + Vector3(o, 0, k), 4.6, 1.5)
				k += 9.0


## A low, wide sports car: wedge body, raked glass cabin, spoiler, dark wheels with chrome rims.
func _sports_car(parent: Node3D, pos: Vector3, yaw: float, paint: Color) -> Node3D:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = yaw
	parent.add_child(car)
	var body := Palette.pbr(paint, 0.25, 0.7)
	var cabin := Palette.pbr(Color(0.08, 0.1, 0.13), 0.04, 0.9)
	Palette.box(car, Vector3(4.3, 0.42, 1.95), Vector3(0, 0.5, 0), body, true, "Body")
	var hood := Palette.box(car, Vector3(1.6, 0.1, 1.85), Vector3(-1.45, 0.72, 0), body, false, "Hood")
	hood.rotation.z = 0.12
	Palette.box(car, Vector3(1.9, 0.5, 1.6), Vector3(0.1, 0.95, 0), cabin, false, "Cabin")
	Palette.box(car, Vector3(0.9, 0.35, 1.7), Vector3(1.5, 0.85, 0), body, false, "Deck")
	Palette.box(car, Vector3(0.3, 0.05, 1.9), Vector3(2.0, 1.12, 0), body, false, "Spoiler")
	for sz in [-0.7, 0.7]:
		Palette.box(car, Vector3(0.05, 0.25, 0.08), Vector3(2.0, 0.98, sz), body, false, "Strut")
		Palette.box(car, Vector3(0.1, 0.12, 0.35), Vector3(-2.15, 0.55, sz), Palette.mat(Color(0.95, 0.95, 0.9), 0.3, 0.0, Palette.WARM_WHITE, 1.0), false, "Headlamp")
		Palette.box(car, Vector3(0.1, 0.1, 0.4), Vector3(2.15, 0.6, sz), Palette.mat(Color(0.6, 0.05, 0.05), 0.3, 0.0, Palette.RED, 1.2), false, "Taillamp")
	var tyre := Palette.pbr(Color(0.06, 0.06, 0.06), 0.9, 0.0)
	var rim := Palette.pbr(Color(0.8, 0.82, 0.85), 0.2, 0.95)
	for wp: Vector3 in [Vector3(-1.35, 0.34, -0.95), Vector3(-1.35, 0.34, 0.95), Vector3(1.35, 0.34, -0.95), Vector3(1.35, 0.34, 0.95)]:
		var t := Palette.cylinder(car, 0.34, 0.28, wp, tyre, false, "Tyre", 14)
		t.rotation.x = PI * 0.5
		var r := Palette.cylinder(car, 0.2, 0.3, wp, rim, false, "Rim", 10)
		r.rotation.x = PI * 0.5
	return car


func _build_parked_cars() -> void:
	var cars := Node3D.new()
	cars.name = "ParkedCars"
	add_child(cars)
	for k in range(22):
		var i := _rng.randi_range(-2, 2)
		var j := _rng.randi_range(-2, 2)
		if i == 0 and j == 0:
			continue
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var along_x := _rng.randf() < 0.5
		var off := B * 0.5 + (6.0 - PARK_OFFSET)   # against the kerb, in the outer lane
		var pos: Vector3
		var yaw := 0.0
		if along_x:
			pos = Vector3(i * P + _rng.randf_range(-13, 13), 0.0, j * P + side * off)
			yaw = 0.0 if side > 0 else PI
		else:
			pos = Vector3(i * P + side * off, 0.0, j * P + _rng.randf_range(-13, 13))
			yaw = PI * 0.5 if side < 0 else -PI * 0.5
		_sports_car(cars, pos, yaw, car_paints[_rng.randi_range(0, car_paints.size() - 1)])


## Cruising cars on the two ring roads, driven by TrafficDriver through the vehicle autopilot.
func _build_traffic() -> void:
	var traffic := Node3D.new()
	traffic.name = "Traffic"
	add_child(traffic)
	var scene: PackedScene = load("res://scenes/city/Vehicle.tscn")
	var loops := [
		[Vector3(-78, 0, -78), Vector3(78, 0, -78), Vector3(78, 0, 78), Vector3(-78, 0, 78)],
		[Vector3(-137, 0, -26), Vector3(26, 0, -26), Vector3(26, 0, 137), Vector3(-137, 0, 137)],
		[Vector3(137, 0, 26), Vector3(-26, 0, 26), Vector3(-26, 0, -137), Vector3(137, 0, -137)],
	]
	for k in range(TRAFFIC_CARS):
		var loop: Array = loops[k % loops.size()]
		var car: VehicleController = scene.instantiate()
		car.vehicle_id = "traffic"
		car.paint = car_paints[_rng.randi_range(0, car_paints.size() - 1)]
		car.name = "TrafficCar%d" % k
		var start_i := (k * 2) % loop.size()
		var a: Vector3 = loop[start_i]
		var b: Vector3 = loop[(start_i + 1) % loop.size()]
		var dir := (b - a).normalized()
		var right := dir.cross(Vector3.UP)
		car.position = a + dir * (14.0 + 20.0 * (k / loops.size())) + right * LANE_OFFSET + Vector3(0, 0.6, 0)
		car.rotation.y = atan2(-dir.x, -dir.z)
		traffic.add_child(car)
		var drv := TrafficDriver.new()
		drv.name = "TrafficDriver"
		car.add_child(drv)
		var path := PackedVector3Array()
		for n in range(loop.size()):
			path.append(loop[(start_i + 1 + n) % loop.size()])
		drv.setup(car, path, LANE_OFFSET)


func _build_pedestrians() -> void:
	var peds := Node3D.new()
	peds.name = "Pedestrians"
	add_child(peds)
	var o := B * 0.5 - 1.0
	for k in range(PEDESTRIANS):
		var i := _rng.randi_range(-2, 2)
		var j := _rng.randi_range(-2, 2)
		var c := Vector3(i * P, 0.3, j * P)
		var loop := PackedVector3Array([c + Vector3(-o, 0, -o), c + Vector3(o, 0, -o), c + Vector3(o, 0, o), c + Vector3(-o, 0, o)])
		if _rng.randf() < 0.5:
			loop.reverse()
		var ped := Pedestrian.new()
		ped.name = "Pedestrian%d" % k
		peds.add_child(ped)
		ped.setup(loop, _rng.randf_range(1.1, 1.7), _rng.randf(), _rng.randi())


## The city's east edge opens onto water: a quay with railings, benches and trees, then the lake.
func _build_waterfront() -> void:
	var wf := Node3D.new()
	wf.name = "Waterfront"
	add_child(wf)
	var h := CityData.CITY_HALF
	Palette.box(wf, Vector3(110, 0.6, 330), Vector3(h + 4.0 + 55.0, -0.5, 0), mat_water, false, "Lake")
	Palette.box(wf, Vector3(3.0, 1.2, 330), Vector3(h + 4.0 + 0.5, -0.2, 0), mat_white, false, "QuayWall")
	Palette.box(wf, Vector3(8.0, 0.3, 330), Vector3(h - 2.0, 0.15, 0), mat_pavement, false, "Promenade")
	Palette.box(wf, Vector3(0.1, 1.1, 330), Vector3(h + 1.9, 0.85, 0), mat_glass_clear, false, "Railing")
	Palette.box(wf, Vector3(0.12, 0.08, 330), Vector3(h + 1.9, 1.4, 0), mat_metal, false, "Handrail")
	var z := -140.0
	while z <= 140.0:
		_tree(wf, Vector3(h - 4.5, 0.3, z), 4.8, 1.7)
		_bench(wf, Vector3(h - 1.0, 0.3, z + 5.0), PI * 0.5)
		z += 20.0


func _build_district_signs() -> void:
	Palette.label3d(self, "THE HEIGHTS", Vector3(78, 46, -78), Palette.WARM_WHITE, 110, 0.06)
	Palette.label3d(self, "NEON DOCKS", Vector3(-78, 22, 78), Palette.WARM_WHITE, 110, 0.06)
	Palette.label3d(self, "CORE PLAZA", Vector3(0, 30, 0), Palette.WARM_WHITE, 90, 0.06)
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
