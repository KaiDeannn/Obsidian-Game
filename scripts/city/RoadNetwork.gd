class_name RoadNetwork
## Road graph for Nova Aetheris, derived from CityData's grid: every lane centre line
## sits at x or z in LANES, so the drivable network is a 6x6 lattice of intersections
## joined by straight road segments. The valet uses it to pick a spawn node near the
## player and to drive a path along the roads instead of cutting through blocks.

const LANES: Array[float] = [-137.0, -78.0, -26.0, 26.0, 78.0, 137.0]


static func node_count() -> int:
	return LANES.size() * LANES.size()


static func node_position(index: int) -> Vector3:
	@warning_ignore("integer_division")
	var a := index / LANES.size()
	var b := index % LANES.size()
	return Vector3(LANES[a], 0.0, LANES[b])


## All intersection positions - exposed for the minimap/debug and the valet spawn search.
static func all_nodes() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(node_count()):
		out.append(node_position(i))
	return out


static func nearest_node(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in range(node_count()):
		var p := node_position(i)
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


## The closest point on any lane centre line to `pos` (the kerb-side stop beside the player).
static func nearest_lane_point(pos: Vector3) -> Vector3:
	var best := Vector3(pos.x, 0.0, pos.z)
	var best_d := INF
	for lane in LANES:
		# vertical lane x = lane
		var px := Vector3(lane, 0.0, clampf(pos.z, LANES[0], LANES[LANES.size() - 1]))
		var dx := Vector2(px.x - pos.x, px.z - pos.z).length()
		if dx < best_d:
			best_d = dx
			best = px
		# horizontal lane z = lane
		var pz := Vector3(clampf(pos.x, LANES[0], LANES[LANES.size() - 1]), 0.0, lane)
		var dz := Vector2(pz.x - pos.x, pz.z - pos.z).length()
		if dz < best_d:
			best_d = dz
			best = pz
	return best


static func _build_astar() -> AStar3D:
	var astar := AStar3D.new()
	var n := LANES.size()
	for i in range(node_count()):
		astar.add_point(i, node_position(i))
	for a in range(n):
		for b in range(n):
			var id := a * n + b
			if a + 1 < n:
				astar.connect_points(id, (a + 1) * n + b)
			if b + 1 < n:
				astar.connect_points(id, a * n + b + 1)
	return astar


## Road-following path between two intersections (inclusive), as world positions.
static func path_between(from_index: int, to_index: int) -> PackedVector3Array:
	var astar := _build_astar()
	return astar.get_point_path(from_index, to_index)


## Pick an intersection the valet can spawn at: on the road, at least `min_d` metres
## from `pos` and as close to `min_d` as possible so the delivery stays short.
static func spawn_node_near(pos: Vector3, min_d := 45.0, max_d := 130.0) -> int:
	var best := -1
	var best_d := INF
	for i in range(node_count()):
		var p := node_position(i)
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d >= min_d and d <= max_d and d < best_d:
			best_d = d
			best = i
	if best == -1:
		best = nearest_node(pos)
	return best
