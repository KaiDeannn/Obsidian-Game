
extends StaticBody3D

const JOB_ID: String = "delivery_001"

@export var typewriter_speed: float = 0.035

@onready var interaction_area: Area3D = $Area3D
@onready var message: Label3D = $Message

var player_nearby: bool = false
var typing: bool = false
var full_text: String = ""
var char_index: int = 0
var typewriter_timer: float = 0.0

var waiting_for_acceptance: bool = false


func _ready() -> void:
	message.text = ""
	message.visible = false

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if typing:
		typewriter_timer += delta

		if typewriter_timer >= typewriter_speed:
			typewriter_timer = 0.0
			char_index += 1
			message.text = full_text.substr(0, char_index)

			if char_index >= full_text.length():
				typing = false

	if player_nearby and Input.is_action_just_pressed("interact"):
		if typing:
			finish_typing()
		else:
			interact()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		player_nearby = true
		show_message("Press E to interact")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		player_nearby = false
		typing = false
		waiting_for_acceptance = false
		hide_message()


func interact() -> void:
	if waiting_for_acceptance:
		accept_delivery_job()
		return

	var status: String = JobManager.get_job_status(JOB_ID)

	match status:
		"Available":
			waiting_for_acceptance = true
			show_message(
				"I have a delivery job for you.\n" +
				"Deliver this package to the gatekeeper.\n" +
				"Reward: 10 Renown and 5 Points.\n\n" +
                "Press E to accept."
			)

		"Active":
			show_message(
				"You already have this job.\n" +
                "Deliver the package to the gatekeeper!"
			)

		"Completed":
			show_message(
				"Thanks for delivering the package!\n" +
                "I appreciate your help."
			)

		_:
			show_message("I have nothing for you right now.")


func accept_delivery_job() -> void:
	waiting_for_acceptance = false

	if JobManager.accept_job(JOB_ID):
		show_message(
			"Excellent! The job is yours.\n" +
            "Deliver the package to the gatekeeper."
		)
		print("You accepted the First Delivery job!")
	else:
		show_message("You cannot accept this job right now.")


func show_message(text: String) -> void:
	full_text = text
	char_index = 0
	typewriter_timer = 0.0

	message.text = ""
	message.visible = true
	typing = true


func finish_typing() -> void:
	message.text = full_text
	char_index = full_text.length()
	typing = false


func hide_message() -> void:
	message.visible = false
	message.text = ""
