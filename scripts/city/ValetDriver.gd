extends Node3D
class_name ValetDriver
## NPC chauffeur. Attached to a VehicleController by the Valet service, it takes the
## wheel through the vehicle's autopilot inputs, follows a RoadNetwork path to the kerb
## nearest the player, turns in for the last few metres, stops, climbs out and walks off.
## The car drives on its own physics, so it brakes, steers and collides like the player.

signal arrived

@export var park_distance := 6.5
@export var kerb_park_distance := 16.0   # if the kerb stops us this close, park on the roadside
@export var cruise_speed := 15.0        # m/s on straights
@export var corner_speed := 5.5
@export var give_up_after := 80.0       # seconds before parking wherever it is

var vehicle: VehicleController
var target: Node3D
var path: PackedVector3Array = PackedVector3Array()
var waypoint_index := 0
var elapsed := 0.0
var parked := false

var _npc: Node3D
var _stuck_time := 0.0
var _reverse_time := 0.0
var _kerb_time := 0.0


func setup(car: VehicleController, player: Node3D, road_path: PackedVector3Array) -> void:
	vehicle = car
	target = player
	path = road_path
	vehicle.autopilot = true
	vehicle.set_driver(self)             # occupied: the player cannot climb in mid-delivery
	_npc = _build_npc()
	vehicle.model.add_child(_npc)
	_npc.position = Vector3(-0.35, 0.95, 0.1)


func eta_seconds() -> float:
	var d := 0.0
	var prev: Vector3 = vehicle.global_position if is_instance_valid(vehicle) else Vector3.ZERO
	for i in range(waypoint_index, path.size()):
		d += Vector2(path[i].x - prev.x, path[i].z - prev.z).length()
		prev = path[i]
	return d / (cruise_speed * 0.7) + 3.0


func _physics_process(delta: float) -> void:
	if parked or not is_instance_valid(vehicle):
		return
	elapsed += delta
	if not is_instance_valid(target):
		_park()
		return
	var pos := vehicle.global_position
	var goal: Vector3
	var final_leg := waypoint_index >= path.size()
	if final_leg:
		goal = target.global_position
	else:
		goal = path[waypoint_index]
		var reach := 3.0 if waypoint_index == path.size() - 1 else 4.5
		if Vector2(goal.x - pos.x, goal.z - pos.z).length() < reach:
			waypoint_index += 1
			return
	var flat := Vector2(goal.x - pos.x, goal.z - pos.z)
	var dist := flat.length()
	if final_leg and dist <= park_distance:
		_stop_and_park()
		return
	if elapsed > give_up_after:
		_stop_and_park()
		return

	# steering: angle to the goal in the car's frame (-Z forward, +X right)
	var local := vehicle.to_local(goal)
	var angle := atan2(local.x, -local.z)
	var steer := clampf(-angle * 1.8, -1.0, 1.0)
	# desired speed: slow for corners and for the approach
	var desired := cruise_speed
	if absf(angle) > 0.5:
		desired = corner_speed
	var remaining := dist
	if not final_leg:
		for i in range(waypoint_index + 1, path.size()):
			remaining += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	desired = minf(desired, 2.5 + remaining * 0.45)
	var throttle := 0.0
	if vehicle.forward_speed < desired - 0.5:
		throttle = 1.0
	elif vehicle.forward_speed > desired + 1.5:
		throttle = -1.0

	# kerb stop: on the last leg a sidewalk kerb may block the car - that is close enough
	if final_leg and dist <= kerb_park_distance and throttle > 0.0 and absf(vehicle.forward_speed) < 0.4:
		_kerb_time += delta
		if _kerb_time > 0.8:
			_stop_and_park()
			return
	else:
		_kerb_time = 0.0

	# un-stick: if we are pushing but not moving, back up briefly
	if _reverse_time > 0.0:
		_reverse_time -= delta
		throttle = -1.0
		steer = -steer
	elif throttle > 0.0 and absf(vehicle.forward_speed) < 0.4:
		_stuck_time += delta
		if _stuck_time > 1.5:
			_stuck_time = 0.0
			_reverse_time = 1.0
	else:
		_stuck_time = 0.0

	vehicle.auto_throttle = throttle
	vehicle.auto_steer = steer
	vehicle.auto_brake = false


func _stop_and_park() -> void:
	vehicle.auto_throttle = 0.0
	vehicle.auto_steer = 0.0
	vehicle.auto_brake = true
	if absf(vehicle.forward_speed) < 0.6:
		_park()


func _park() -> void:
	if parked:
		return
	parked = true
	vehicle.autopilot = false
	vehicle.auto_brake = false
	vehicle.forward_speed = 0.0
	vehicle.velocity = Vector3.ZERO
	vehicle.release_driver()
	# the chauffeur climbs out on the kerb side and walks away
	if _npc:
		var world := vehicle.get_parent()
		var side := vehicle.global_transform.basis.x
		var out_pos := vehicle.global_position + side * 1.8 + Vector3(0, 0, 0)
		_npc.get_parent().remove_child(_npc)
		world.add_child(_npc)
		_npc.global_position = Vector3(out_pos.x, vehicle.global_position.y - 0.55, out_pos.z)
		_npc.scale = Vector3.ONE
		var away := out_pos + side * 10.0 + vehicle.global_transform.basis.z * 4.0
		var tw := _npc.create_tween()
		tw.tween_property(_npc, "global_position", Vector3(away.x, _npc.global_position.y, away.z), 4.0)
		tw.parallel().tween_property(_npc, "rotation:y", atan2(-(away.x - out_pos.x), -(away.z - out_pos.z)), 0.3)
		tw.tween_property(_npc, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
		tw.tween_callback(_npc.queue_free)
	arrived.emit()
	queue_free()


func _build_npc() -> Node3D:
	var npc := Node3D.new()
	npc.name = "ValetNPC"
	var suit := Palette.mat(Color(0.75, 0.42, 0.12), 0.7, 0.1)
	var skin := Palette.mat(Color(0.65, 0.5, 0.4), 0.9)
	Palette.box(npc, Vector3(0.36, 0.5, 0.24), Vector3(0, 0.5, 0), suit, false, "Torso")
	Palette.sphere(npc, 0.16, Vector3(0, 0.92, 0), skin, "Head")
	Palette.box(npc, Vector3(0.34, 0.08, 0.34), Vector3(0, 1.03, 0), Palette.mat(Color(0.12, 0.1, 0.1), 0.8), false, "Cap")
	for sx in [-0.1, 0.1]:
		Palette.box(npc, Vector3(0.14, 0.45, 0.16), Vector3(sx, 0.05, 0), Palette.mat(Color(0.1, 0.1, 0.12), 0.8), false, "Leg")
	return npc
