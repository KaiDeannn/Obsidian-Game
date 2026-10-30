extends Node
## Valet (autoload "Valet"). Rook Hale's automated valet & mechanic service behind the
## phone's Mechanic contact:
##  - Request: spawn the chosen owned vehicle at a road node near the player and have a
##    ValetDriver NPC drive it to the player's live position, park and climb out.
##  - Return: the vehicle disappears immediately (back to the garage).
##  - Fix: a damaged vehicle goes onto the mechanic's service queue; repairs run on a
##    timer (seconds per damage percent) and the vehicle is pristine when it comes back.
## The scene registers its starting car with register_deployed() so the service knows
## which vehicles are already out in the world.

signal state_changed
signal driver_dispatched(vehicle_id: String, eta_seconds: float)
signal vehicle_delivered(vehicle_id: String, vehicle: Node3D)
signal vehicle_returned(vehicle_id: String)
signal repair_started(vehicle_id: String, seconds: float)
signal repair_finished(vehicle_id: String)

const VEHICLE_SCENE := "res://scenes/city/Vehicle.tscn"

@export var repair_seconds_per_percent := 0.5
@export var min_repair_seconds := 6.0
@export var min_spawn_distance := 45.0
@export var max_spawn_distance := 130.0

var deployed: Dictionary = {}       # vehicle_id -> VehicleController in the world
var en_route: Dictionary = {}       # vehicle_id -> ValetDriver
var service_queue: Array[Dictionary] = []   # {"id", "remaining", "total"} - first entry is on the lift
var last_delivery_eta := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ============================================================ queries
func status(vehicle_id: String) -> String:
	if en_route.has(vehicle_id):
		return "en route"
	if is_deployed(vehicle_id):
		return "with you"
	if in_service(vehicle_id):
		return "in service"
	return "garaged"


func is_deployed(vehicle_id: String) -> bool:
	return deployed.has(vehicle_id) and is_instance_valid(deployed[vehicle_id])


func in_service(vehicle_id: String) -> bool:
	for job in service_queue:
		if job["id"] == vehicle_id:
			return true
	return false


func repair_remaining(vehicle_id: String) -> float:
	for job in service_queue:
		if job["id"] == vehicle_id:
			return float(job["remaining"])
	return 0.0


func repair_seconds_for(vehicle_id: String) -> float:
	return maxf(min_repair_seconds, GameState.vehicle_damage_of(vehicle_id) * repair_seconds_per_percent)


## "" when the vehicle can be requested, else the reason Rook gives.
func request_blocker(vehicle_id: String) -> String:
	if not GameState.owns_vehicle(vehicle_id):
		return "You don't own that one."
	if en_route.has(vehicle_id):
		return "Already on its way to you."
	if in_service(vehicle_id):
		return "That one's still on the lift."
	if is_deployed(vehicle_id):
		var car: Node3D = deployed[vehicle_id]
		var player := _player()
		if player and car.global_position.distance_to(player.global_position) < 25.0:
			return "It's parked right next to you."
	if GameState.vehicle_damage_of(vehicle_id) >= 100:
		return "That one's a wreck - let me fix it first."
	return ""


func clean_up_dead() -> void:
	for id in deployed.keys():
		if not is_instance_valid(deployed[id]):
			deployed.erase(id)


# ============================================================ scene hooks
func register_deployed(vehicle_id: String, vehicle: Node3D) -> void:
	deployed[vehicle_id] = vehicle
	state_changed.emit()


func reset() -> void:
	deployed.clear()
	en_route.clear()
	service_queue.clear()
	state_changed.emit()


# ============================================================ REQUEST
func request(vehicle_id: String) -> bool:
	clean_up_dead()
	if request_blocker(vehicle_id) != "":
		return false
	var player := _player()
	if player == null:
		return false
	# A car left somewhere else in the city is "collected" by the valet first.
	if is_deployed(vehicle_id):
		_despawn(vehicle_id)
	var spawn_index := RoadNetwork.spawn_node_near(player.global_position, min_spawn_distance, max_spawn_distance)
	var end_index := RoadNetwork.nearest_node(player.global_position)
	var road: PackedVector3Array = RoadNetwork.path_between(spawn_index, end_index)
	var kerb := RoadNetwork.nearest_lane_point(player.global_position)
	var path := PackedVector3Array()
	for i in range(1, road.size()):
		path.append(road[i])
	if path.is_empty() or path[path.size() - 1].distance_to(kerb) > 1.0:
		path.append(kerb)

	var info := GameState.vehicle_info(vehicle_id)
	var car: VehicleController = load(VEHICLE_SCENE).instantiate()
	car.vehicle_id = vehicle_id
	car.paint = info["paint"]
	car.name = "Valet_%s" % vehicle_id
	var spawn := road[0] + Vector3(0, 0.6, 0)
	var first := path[0]
	var face := Vector3(first.x - spawn.x, 0.0, first.z - spawn.z)
	get_tree().current_scene.add_child(car)
	car.global_position = spawn
	if face.length() > 0.1:
		car.rotation.y = atan2(-face.x, -face.z)
	var driver := ValetDriver.new()
	driver.name = "ValetDriver"
	car.add_child(driver)
	driver.setup(car, player, path)
	en_route[vehicle_id] = driver
	last_delivery_eta = driver.eta_seconds()
	driver.arrived.connect(func() -> void: _on_delivered(vehicle_id, car))
	driver_dispatched.emit(vehicle_id, last_delivery_eta)
	state_changed.emit()
	return true


func _on_delivered(vehicle_id: String, car: Node3D) -> void:
	en_route.erase(vehicle_id)
	deployed[vehicle_id] = car
	vehicle_delivered.emit(vehicle_id, car)
	state_changed.emit()


# ============================================================ RETURN
func return_vehicle(vehicle_id: String) -> bool:
	clean_up_dead()
	if en_route.has(vehicle_id):
		var driver: ValetDriver = en_route[vehicle_id]
		en_route.erase(vehicle_id)
		if is_instance_valid(driver) and is_instance_valid(driver.vehicle):
			driver.vehicle.queue_free()
		vehicle_returned.emit(vehicle_id)
		state_changed.emit()
		return true
	if not is_deployed(vehicle_id):
		return false
	_despawn(vehicle_id)
	vehicle_returned.emit(vehicle_id)
	state_changed.emit()
	return true


func _despawn(vehicle_id: String) -> void:
	var car: Node3D = deployed[vehicle_id]
	deployed.erase(vehicle_id)
	if not is_instance_valid(car):
		return
	var player := _player()
	if player and player.get("in_vehicle") and player.get("current_vehicle") == car:
		player.call("exit_vehicle")
	car.queue_free()


# ============================================================ FIX
func fix(vehicle_id: String) -> bool:
	clean_up_dead()
	if not GameState.owns_vehicle(vehicle_id) or in_service(vehicle_id) or en_route.has(vehicle_id):
		return false
	if GameState.vehicle_damage_of(vehicle_id) <= 0:
		return false
	if is_deployed(vehicle_id):
		_despawn(vehicle_id)
	var seconds := repair_seconds_for(vehicle_id)
	service_queue.append({"id": vehicle_id, "remaining": seconds, "total": seconds})
	repair_started.emit(vehicle_id, seconds)
	state_changed.emit()
	return true


func _process(delta: float) -> void:
	if service_queue.is_empty():
		return
	var job: Dictionary = service_queue[0]
	job["remaining"] = float(job["remaining"]) - delta
	if float(job["remaining"]) <= 0.0:
		service_queue.pop_front()
		GameState.repair_vehicle(job["id"])
		repair_finished.emit(job["id"])
		state_changed.emit()


# ============================================================ helpers
func _player() -> Node3D:
	for n in get_tree().get_nodes_in_group("players"):
		if n is Node3D:
			return n
	return null


static func fmt_seconds(sec: float) -> String:
	var s := int(ceil(sec))
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60] if s >= 60 else "%ds" % s
