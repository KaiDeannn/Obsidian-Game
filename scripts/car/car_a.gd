
extends VehicleBody3D
var current_speed
@export var engine_power: float = 40.0
@export var brake_power: float = 30.0
@export var max_steering_angle: float = 0.45
@export var steering_speed: float = 2.0
@export var exit_distance: float = 2.5

@onready var front_left: VehicleWheel3D = $FrontLeft
@onready var front_right: VehicleWheel3D = $FrontRight
@onready var rear_left: VehicleWheel3D = $RearLeft
@onready var rear_right: VehicleWheel3D = $RearRight

@onready var interaction_area: Area3D = $InteractionArea
@onready var seat_position: Marker3D = $SeatPosition

var nearby_player: CharacterBody3D = null
var player: CharacterBody3D = null
var is_driving: bool = false
var current_steering: float = 0.0


func _ready() -> void:
	# Front wheels steer.
	front_left.use_as_steering = true
	front_right.use_as_steering = true

	# Rear wheels provide traction.
	rear_left.use_as_traction = true
	rear_right.use_as_traction = true

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not is_driving:
		nearby_player = body
		print("Press E to enter the car")


func _on_body_exited(body: Node3D) -> void:
	if body == nearby_player:
		nearby_player = null


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if event.is_echo():
		return

	if is_driving:
		exit_car()
	elif is_instance_valid(nearby_player):
		enter_car(nearby_player)



func enter_car(body: CharacterBody3D) -> void:
	player = body
	nearby_player = null
	is_driving = true

	# Disable the player's physics and input.
	player.set_physics_process(false)
	player.set_process_input(false)

	# Hide the player's visuals without moving its collider
	# into the car's collision shape.
	player.hide()

	# Disable the player's collision while driving.
	var collision := player.get_node_or_null("CollisionShape3D")
	if collision is CollisionShape3D:
		collision.set_deferred("disabled", true)

	print("Entered car successfully")




func exit_car() -> void:
	if not is_instance_valid(player):
		is_driving = false
		return

	is_driving = false
	engine_force = 0.0
	brake =  brake_power
	steering = 0.0
	current_speed = 0.0

	# Calculate a position beside the car.
	var exit_position: Vector3 = (
		global_position
		+ global_basis.x * exit_distance
		+ Vector3.UP * 1.0
	)

	# Move player out of the car.
	player.global_position = exit_position
	player.velocity = Vector3.ZERO

	# Restore the player's collision.
	var collision := player.get_node_or_null("CollisionShape3D")
	if collision is CollisionShape3D:
		collision.set_deferred("disabled", false)

	# Restore player visibility and controls.
	player.show()
	player.set_physics_process(true)
	player.set_process_input(true)

	player = null



func _physics_process(delta: float) -> void:
	if is_driving and is_instance_valid(player):
		player.global_position = seat_position.global_position

		var throttle := Input.get_axis(
			"move_backward",
			"move_forward"
		)

		var steer_input := Input.get_axis(
			"move_left",
			"move_right"
		)

		engine_force = throttle * engine_power
		brake = 0.0 if absf(throttle) > 0.01 else brake_power

		var target_steering := (
			-steer_input * max_steering_angle
		)

		current_steering = move_toward(
			current_steering,
			target_steering,
			steering_speed * delta
		)

		steering = current_steering
	else:
		engine_force = 0.0
		brake = 5.0
		steering = 0.0
