extends CharacterBody3D
class_name PlayerController
## City on-foot controller. WASD relative to the camera, sprint, jump, and seamless
## vehicle entry/exit via the InteractArea (detects bodies on the Vehicle layer).
## Hierarchy: Player(CharacterBody3D) -> CollisionShape3D, Model, InteractArea(Area3D)

signal entered_vehicle(vehicle: VehicleController)
signal exited_vehicle(vehicle: VehicleController)
signal interact_prompt(text: String)

@export var walk_speed := 5.6
@export var run_speed := 9.2
@export var acceleration := 12.0
@export var jump_velocity := 5.2
@export var turn_speed := 14.0

var camera_rig: CameraRig
var input_enabled := true
var in_vehicle := false
var current_vehicle: VehicleController
var _nearby_vehicle: VehicleController
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0

@onready var model: Node3D = $Model
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interact_area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group("players")
	_build_model()
	interact_area.body_entered.connect(_on_interact_body_entered)
	interact_area.body_exited.connect(_on_interact_body_exited)


func _build_model() -> void:
	var suit := Palette.mat(Color(0.12, 0.14, 0.22), 0.6, 0.2)
	var trim := Palette.glow(Palette.CYAN, 2.0)
	var skin := Palette.mat(Color(0.75, 0.6, 0.5), 0.9)
	var torso := CapsuleMesh.new()
	torso.radius = 0.32
	torso.height = 1.15
	var torso_mi := MeshInstance3D.new()
	torso_mi.mesh = torso
	torso_mi.material_override = suit
	torso_mi.position = Vector3(0, 0.95, 0)
	model.add_child(torso_mi)
	Palette.sphere(model, 0.22, Vector3(0, 1.72, 0), skin, "Head")
	Palette.box(model, Vector3(0.34, 0.08, 0.1), Vector3(0, 1.76, -0.17), trim, false, "Visor")
	Palette.box(model, Vector3(0.5, 0.06, 0.3), Vector3(0, 1.05, -0.3), trim, false, "ChestLight")
	Palette.box(model, Vector3(0.4, 0.55, 0.22), Vector3(0, 1.05, 0.3), Palette.mat(Color(0.08, 0.08, 0.1), 0.7), false, "Pack")
	for sx in [-0.18, 0.18]:
		Palette.box(model, Vector3(0.16, 0.5, 0.2), Vector3(sx, 0.28, 0), suit, false, "Leg")


func _physics_process(delta: float) -> void:
	if in_vehicle:
		if is_instance_valid(current_vehicle):
			global_position = current_vehicle.global_position
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := camera_rig.get_yaw() if camera_rig else rotation.y
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := run_speed if (input_enabled and Input.is_action_pressed("sprint")) else walk_speed
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta * speed)
	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	move_and_slide()
	# Simple locomotion bob so the character does not slide like a statue.
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.5 and is_on_floor():
		_bob_time += delta * planar * 1.6
		model.position.y = absf(sin(_bob_time)) * 0.06
		model.rotation.z = sin(_bob_time) * 0.03
	else:
		model.position.y = lerpf(model.position.y, 0.0, 10.0 * delta)
		model.rotation.z = lerpf(model.rotation.z, 0.0, 10.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("interact"):
		if in_vehicle:
			exit_vehicle()
		elif is_instance_valid(_nearby_vehicle):
			enter_vehicle(_nearby_vehicle)


func enter_vehicle(vehicle: VehicleController) -> void:
	if in_vehicle or vehicle.has_driver():
		return
	in_vehicle = true
	current_vehicle = vehicle
	visible = false
	collision.disabled = true
	velocity = Vector3.ZERO
	vehicle.set_driver(self)
	interact_prompt.emit("[E] Exit vehicle")
	entered_vehicle.emit(vehicle)


func exit_vehicle() -> void:
	if not in_vehicle:
		return
	var vehicle := current_vehicle
	vehicle.release_driver()
	var side := vehicle.global_transform.basis.x
	global_position = vehicle.global_position - side * 2.2 + Vector3.UP * 0.4
	rotation.y = vehicle.global_rotation.y
	visible = true
	collision.disabled = false
	in_vehicle = false
	current_vehicle = null
	velocity = Vector3.ZERO
	_nearby_vehicle = vehicle
	interact_prompt.emit("[E] Enter vehicle")
	exited_vehicle.emit(vehicle)


func _on_interact_body_entered(body: Node3D) -> void:
	if body is VehicleController and not in_vehicle:
		_nearby_vehicle = body
		interact_prompt.emit("[E] Enter vehicle")


func _on_interact_body_exited(body: Node3D) -> void:
	if body == _nearby_vehicle and not in_vehicle:
		_nearby_vehicle = null
		interact_prompt.emit("")
