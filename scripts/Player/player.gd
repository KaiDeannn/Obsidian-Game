
extends Node3D

# ----- State Groups -----
enum Moving_State { WALKING, RUNNING, JUMPING }

# ----- Camera Nodes -----
@onready var camera: Camera3D = $"Camera pivot/Spring arm/Camera"
@onready var camera_pivot: Node3D = $"Camera pivot"
@onready var spring_arm: SpringArm3D = $"Camera pivot/Spring arm"

# ----- Character Nodes -----
@onready var main_character: CharacterBody3D = $"Main character"
@onready var mesh: MeshInstance3D = $"Main character/Mesh"
@onready var collision: CollisionShape3D = $"Main character/Collision"

@onready var cinematic_manager = $"../CinematicManager"

# ----- Camera Variables -----
@export_category("Camera Variables")
@export var MIN_PITCH: float = -60.0
@export var MAX_PITCH: float = 60.0
@export var MOUSE_SENSITIVITY: float = 0.003

var camera_pitch: float = 0.0

# ----- Camera Zoom -----
@export_category("Camera Zoom")
@export var ZOOM_SPEED: float = 1.0
@export var MIN_ZOOM: float = 2.0
@export var MAX_ZOOM: float = 10.0

var zoom_distance: float = 5.0

# ----- Flags -----
var _mouse_look_enabled: bool = false
var _can_handle_physics: bool = true
var _can_follow_camera: bool = true

# ----- Player Variables -----
@export_category("Player Variables")
@export var SPEED: float = 5.0
@export var JUMP_VELOCITY: float = 4.5

# ----- State Machine -----
var current_state = Moving_State.WALKING


func _ready() -> void:
	camera_pitch = spring_arm.rotation.x
	zoom_distance = spring_arm.spring_length

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ----- Input -----
func _input(event: InputEvent) -> void:
	# Jump
	if event.is_action_pressed("jump") \
	and current_state != Moving_State.JUMPING:
		_enter_jump_state()

	# Mouse buttons and zoom
	if event is InputEventMouseButton:
		# Right mouse button: hold to look
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_look_enabled = event.pressed

			if _mouse_look_enabled:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

			get_viewport().set_input_as_handled()

		# Zoom in
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP \
		and event.pressed:
			zoom_distance -= ZOOM_SPEED
			_update_zoom()

		# Zoom out
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN \
		and event.pressed:
			zoom_distance += ZOOM_SPEED
			_update_zoom()

	# Camera movement while right-click is held
	if event is InputEventMouseMotion and _mouse_look_enabled:
		# Horizontal camera rotation
		camera_pivot.rotate_y(
			-event.relative.x * MOUSE_SENSITIVITY
		)

		# Vertical camera rotation
		camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(MIN_PITCH),
			deg_to_rad(MAX_PITCH)
		)

		spring_arm.rotation.x = camera_pitch


func _update_zoom() -> void:
	zoom_distance = clamp(
		zoom_distance,
		MIN_ZOOM,
		MAX_ZOOM
	)

	spring_arm.spring_length = zoom_distance


# ----- Process -----
func _process(delta: float) -> void:
	match current_state:
		Moving_State.WALKING:
			_handle_walking_state()

		Moving_State.RUNNING:
			_handle_running_state()

		Moving_State.JUMPING:
			_handle_jump_state()

	if _can_follow_camera:
		follow_camera(4.0, delta)


func _physics_process(delta: float) -> void:
	if _can_handle_physics:
		main_character._handle_physics(delta)


# ----- Walking State -----
func _enter_walking_state() -> void:
	current_state = Moving_State.WALKING


func _handle_walking_state() -> void:
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction := (
		camera_pivot.global_basis *
		Vector3(input_dir.x, 0.0, input_dir.y)
	)

	direction.y = 0.0
	direction = direction.normalized()

	if direction:
		var target_angle := atan2(direction.x, direction.z)

		mesh.rotation.y = lerp_angle(
			mesh.rotation.y,
			target_angle,
			0.15
		)

	main_character._handle_walking(direction, SPEED)


# ----- Running State -----
func _enter_running_state() -> void:
	current_state = Moving_State.RUNNING


func _handle_running_state() -> void:
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
        "move_backward"
	)

	var direction := (
		camera_pivot.global_basis *
		Vector3(input_dir.x, 0.0, input_dir.y)
	)

	direction.y = 0.0
	direction = direction.normalized()

	if direction:
		var target_angle := atan2(direction.x, direction.z)

		mesh.rotation.y = lerp_angle(
			mesh.rotation.y,
			target_angle,
			0.15
		)

	main_character._handle_running(direction, SPEED * 2.0)


# ----- Jumping State -----
func _enter_jump_state() -> void:
	current_state = Moving_State.JUMPING
	main_character.jump(JUMP_VELOCITY)


func _handle_jump_state() -> void:
	if main_character.is_on_floor():
		_end_jump_state()


func _end_jump_state() -> void:
	_enter_walking_state()


# ----- Follow Camera -----
func follow_camera(speed: float, delta: float) -> void:
	camera_pivot.global_position = camera_pivot.global_position.lerp(
		main_character.global_position,
		speed * delta
	)
