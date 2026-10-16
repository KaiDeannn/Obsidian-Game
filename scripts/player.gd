
extends CharacterBody3D

@export var ZOOM_SPEED: float = 1.0
@export var MIN_ZOOM: float = 2.0
@export var MAX_ZOOM: float = 10.0

@onready var camera: Camera3D = $CameraPivot/Camera3D

var zoom_distance: float = 5.0

@onready var camera_pivot: Node3D = $CameraPivot

@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5
@export var MOUSE_SENSITIVITY: float = 0.003

@export var MIN_PITCH: float = -60.0
@export var MAX_PITCH: float = 60.0

var mouse_look_enabled: bool = false
var camera_pitch: float = 0.0


func _ready() -> void:
	camera_pitch = camera_pivot.rotation.x
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	
	# Zoom with mouse scroll wheel
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance -= ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance += ZOOM_SPEED
	zoom_distance = clamp(zoom_distance,MIN_ZOOM,MAX_ZOOM)
	camera.position.z = zoom_distance
	
	
	
	# Hold right mouse button to rotate the player.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_look_enabled = event.pressed

			if mouse_look_enabled:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Horizontal mouse movement rotates the player itself.
	if event is InputEventMouseMotion and mouse_look_enabled:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY

		# Vertical mouse movement tilts the camera only.
		camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(MIN_PITCH),
			deg_to_rad(MAX_PITCH)
		)

		camera_pivot.rotation.x = camera_pitch


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement relative to the player's facing direction.
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction := (
		transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	if input_dir.length_squared() > 0.001:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()
