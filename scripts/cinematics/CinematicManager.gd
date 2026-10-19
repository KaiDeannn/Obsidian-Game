
extends Node

@export var cinematic_camera: Camera3D
@onready var player_camera: Camera3D=$"../Player/Camera pivot/Spring arm/Camera"
@onready var player_controller: Node3D=$"../Player"
@onready var main_character: CharacterBody3D=$"../Player/Main character"

var cinematic_tween: Tween
var cinematic_active: bool = false


func play_marker(
	marker: Marker3D,
	duration: float = 2.0,
	hold_time: float = 2.0
) -> void:
	if cinematic_active:
		return

	cinematic_active = true

	player_controller.set("_cinematic_active", true)
	player_controller.set("_can_follow_camera", false)
	player_controller.set("_can_handle_physics", false)
	player_controller.set("_mouse_look_enabled", false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Start the cinematic camera at the current gameplay view.
	cinematic_camera.global_transform = player_camera.global_transform
	cinematic_camera.make_current()

	# Move to the marker's exact world transform.
	cinematic_tween = create_tween()
	cinematic_tween.set_parallel(true)
	cinematic_tween.set_trans(Tween.TRANS_SINE)
	cinematic_tween.set_ease(Tween.EASE_IN_OUT)

	cinematic_tween.tween_property(
		cinematic_camera,
		"global_position",
		marker.global_position,
		duration
	)

	cinematic_tween.tween_property(
		cinematic_camera,
		"global_rotation",
		marker.global_rotation,
		duration
	)

	await cinematic_tween.finished
	await get_tree().create_timer(hold_time).timeout

	# Return to gameplay.
	player_camera.make_current()

	player_controller.set("_can_follow_camera", true)
	player_controller.set("_can_handle_physics", true)
	player_controller.set("_cinematic_active", false)

	cinematic_active = false
