
extends CharacterBody3D

# ==============================
# CINEMATIC SETTINGS
# ==============================

var cinematic_scene: bool = false

var cinematic_target: Node3D = null
var cinematic_destination: Vector3 = Vector3.ZERO

var cinematic_move_speed: float = 3.0
var cinematic_following: bool = false
var cinematic_moving_to_location: bool = false
var cinematic_stop_distance: float = 1.5


# ==============================
# CAMERA SETTINGS
# ==============================

@export var ZOOM_SPEED: float = 1.0
@export var MIN_ZOOM: float = 2.0
@export var MAX_ZOOM: float = 10.0


# ==============================
# PLAYER MOVEMENT SETTINGS
# ==============================

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5


# ==============================
# MOUSE SETTINGS
# ==============================

@export var MOUSE_SENSITIVITY: float = 0.003
@export var MIN_PITCH: float = -60.0
@export var MAX_PITCH: float = 60.0


# ==============================
# NODE REFERENCES
# ==============================

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D


# ==============================
# INTERNAL VARIABLES
# ==============================

var zoom_distance: float = 5.0
var mouse_look_enabled: bool = false
var camera_pitch: float = 0.0


# ==============================
# READY
# ==============================

func _ready() -> void:
	camera_pitch = camera_pivot.rotation.x

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	camera.position.z = zoom_distance


# ==============================
# CAMERA INPUT
# ==============================

func _input(event: InputEvent) -> void:
	if cinematic_scene:
		return

	# Right-click mouse look.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_look_enabled = event.pressed

			if mouse_look_enabled:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		# Scroll wheel zoom.
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_distance -= ZOOM_SPEED
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_distance += ZOOM_SPEED

			zoom_distance = clampf(
				zoom_distance,
				MIN_ZOOM,
				MAX_ZOOM
			)

			camera.position.z = zoom_distance

	# Rotate player and camera during mouse look.
	if event is InputEventMouseMotion and mouse_look_enabled:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY

		camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clampf(
			camera_pitch,
			deg_to_rad(MIN_PITCH),
			deg_to_rad(MAX_PITCH)
		)

		camera_pivot.rotation.x = camera_pitch


# ==============================
# CINEMATIC: MOVE TO LOCATION
# ==============================

func cinematic_move_to(
	target_position: Vector3,
	move_speed: float = 3.0
) -> void:
	cinematic_scene = true

	cinematic_following = false
	cinematic_target = null

	cinematic_destination = target_position
	cinematic_move_speed = move_speed
	cinematic_moving_to_location = true

	# Clear previous player movement.
	velocity.x = 0.0
	velocity.z = 0.0

	# Release mouse capture.
	mouse_look_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ==============================
# CINEMATIC: FOLLOW OBJECT
# ==============================

func cinematic_follow(
	target: Node3D,
	move_speed: float = 3.0,
	stop_distance: float = 1.5
) -> void:
	if not is_instance_valid(target):
		return

	cinematic_scene = true

	cinematic_moving_to_location = false
	cinematic_target = target
	cinematic_move_speed = move_speed
	cinematic_stop_distance = maxf(stop_distance, 0.0)
	cinematic_following = true

	# Clear previous player movement.
	velocity.x = 0.0
	velocity.z = 0.0

	mouse_look_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ==============================
# CINEMATIC: STOP
# ==============================

func cinematic_stop() -> void:
	cinematic_following = false
	cinematic_moving_to_location = false
	cinematic_target = null

	# Stop all movement immediately.
	velocity = Vector3.ZERO

	cinematic_scene = false
	mouse_look_enabled = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ==============================
# PHYSICS / MOVEMENT
# ==============================

func _physics_process(delta: float) -> void:

	# --------------------------------
	# CINEMATIC MODE
	# --------------------------------

	if cinematic_scene:
		var should_move: bool = false
		var target_position: Vector3 = global_position

		# Follow a target object.
		if cinematic_following:
			if is_instance_valid(cinematic_target):
				target_position = cinematic_target.global_position
				should_move = true
			else:
				cinematic_following = false
				cinematic_target = null

		# Move toward a fixed destination.
		elif cinematic_moving_to_location:
			target_position = cinematic_destination
			should_move = true

		# Always discard movement from player input.
		velocity.x = 0.0
		velocity.z = 0.0

		if should_move:
			var direction: Vector3 = (
				target_position - global_position
			)

			# Ground-based movement only.
			direction.y = 0.0

			var stop_distance: float = (
				cinematic_stop_distance
				if cinematic_following
				else 0.2
			)

			if direction.length() > stop_distance:
				direction = direction.normalized()

				velocity.x = direction.x * cinematic_move_speed
				velocity.z = direction.z * cinematic_move_speed

				# Face the direction of travel.
				rotation.y = atan2(
					-direction.x,
					-direction.z
				)

			else:
				velocity.x = 0.0
				velocity.z = 0.0

				# Stop at the destination but keep the cutscene active.
				if cinematic_moving_to_location:
					cinematic_moving_to_location = false

		# Gravity remains active during cutscenes.
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.y = 0.0

		move_and_slide()
		return

	# --------------------------------
	# NORMAL PLAYER MOVEMENT
	# --------------------------------

	# Gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input.
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	# Move relative to player facing direction.
	var direction: Vector3 = (
		transform.basis
		* Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	if input_dir.length_squared() > 0.001:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			SPEED
		)

	move_and_slide()
