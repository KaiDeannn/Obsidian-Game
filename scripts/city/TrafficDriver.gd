extends Node3D
class_name TrafficDriver
## Ambient traffic: drives a VehicleController around a closed loop of road nodes forever,
## on the inner lane (right-hand side of each segment), through the vehicle's autopilot
## inputs. Slows for corners, reverses briefly when stuck. The player can crash into it.

@export var cruise_speed := 9.5
@export var corner_speed := 4.5
@export var lane_offset := 2.3

var vehicle: VehicleController
var loop := PackedVector3Array()
var index := 0
var _stuck := 0.0
var _reverse := 0.0


func setup(car: VehicleController, road_loop: PackedVector3Array, offset: float) -> void:
	vehicle = car
	loop = road_loop
	lane_offset = offset
	vehicle.autopilot = true
	vehicle.set_driver(self)
	vehicle.max_speed = 14.0


func _goal() -> Vector3:
	var a: Vector3 = loop[(index - 1 + loop.size()) % loop.size()]
	var b: Vector3 = loop[index]
	return RoadNetwork.lane_point(a, b, vehicle.global_position, lane_offset, 7.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(vehicle) or loop.size() < 2:
		return
	var goal := _goal()
	var pos := vehicle.global_position
	var node: Vector3 = loop[index]
	var flat := Vector2(node.x - pos.x, node.z - pos.z)
	if flat.length() < 4.0 + lane_offset:
		index = (index + 1) % loop.size()
		return
	var local := vehicle.to_local(goal)
	var angle := atan2(local.x, -local.z)
	var steer := clampf(-angle * 1.8, -1.0, 1.0)
	var desired := corner_speed if absf(angle) > 0.4 or flat.length() < 10.0 else cruise_speed
	var throttle := 0.0
	if vehicle.forward_speed < desired - 0.5:
		throttle = 1.0
	elif vehicle.forward_speed > desired + 1.5:
		throttle = -1.0
	if _reverse > 0.0:
		_reverse -= delta
		throttle = -1.0
		steer = -steer
	elif throttle > 0.0 and absf(vehicle.forward_speed) < 0.4:
		_stuck += delta
		if _stuck > 1.5:
			_stuck = 0.0
			_reverse = 1.0
	else:
		_stuck = 0.0
	vehicle.auto_throttle = throttle
	vehicle.auto_steer = steer
	vehicle.auto_brake = false
