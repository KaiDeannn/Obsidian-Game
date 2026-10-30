extends Node3D
class_name CameraRig
## Third-person camera used in the city. ORBIT = mouse-look around a character,
## CHASE = settles behind a vehicle's heading with speed-based pull-back.
## Hierarchy: CameraRig -> Yaw -> Pitch -> SpringArm3D -> Camera3D

enum Mode { ORBIT, CHASE }

@export var mouse_sensitivity := 0.0024
@export var orbit_distance := 4.6
@export var orbit_height := 1.6
@export var chase_distance := 8.5
@export var chase_height := 2.4

var target: Node3D
var mode: Mode = Mode.ORBIT
var look_enabled := true

var _yaw := 0.0
var _pitch := -0.22
var _speed_hint := 0.0

@onready var yaw_node: Node3D = $Yaw
@onready var pitch_node: Node3D = $Yaw/Pitch
@onready var arm: SpringArm3D = $Yaw/Pitch/SpringArm3D
@onready var camera: Camera3D = $Yaw/Pitch/SpringArm3D/Camera3D


func set_target(new_target: Node3D, new_mode: Mode) -> void:
	target = new_target
	mode = new_mode
	if target and mode == Mode.CHASE:
		_pitch = -0.2
	if target:
		global_position = target.global_position + Vector3.UP * (orbit_height if mode == Mode.ORBIT else chase_height)


## Speed hint (0..1) stretches the chase distance a little at high speed.
func set_speed_hint(v: float) -> void:
	_speed_hint = clampf(v, 0.0, 1.0)


func get_yaw() -> float:
	return yaw_node.rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		if mode == Mode.ORBIT:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.15, 0.55)
		else:
			# Light look-around while driving; recentres automatically.
			_yaw -= event.relative.x * mouse_sensitivity * 0.5


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var k := 1.0 - exp(-delta * 10.0)
	match mode:
		Mode.ORBIT:
			global_position = global_position.lerp(target.global_position + Vector3.UP * orbit_height, k)
			arm.spring_length = lerpf(arm.spring_length, orbit_distance, 1.0 - exp(-delta * 6.0))
		Mode.CHASE:
			var desired_yaw := target.global_rotation.y
			_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-delta * 3.5))
			global_position = global_position.lerp(target.global_position + Vector3.UP * chase_height, k)
			var dist := chase_distance + _speed_hint * 3.0
			arm.spring_length = lerpf(arm.spring_length, dist, 1.0 - exp(-delta * 4.0))
	yaw_node.rotation.y = _yaw
	pitch_node.rotation.x = _pitch
