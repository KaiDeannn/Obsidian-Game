
extends StaticBody3D

@export var typewriter_speed: float = 0.035

@onready var interaction_area: Area3D = $Area3D
@onready var message: Label3D = $Message

var player_nearby: bool = false
var typing: bool = false
var full_text: String = ""
var char_index: int = 0
var typewriter_timer: float = 0.0

var waiting_for_acceptance: bool = false
var selected_job_id: String = ""


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
		selected_job_id = ""
		hide_message()


func interact() -> void:
	if waiting_for_acceptance:
		accept_selected_job()
		return

	if Globalvar.active_job_id != "":
		var active_job: QuestData = JobManager.get_quest(
			Globalvar.active_job_id
		)

		if active_job != null:
			show_message(
				"You already have an active job.\n" +
				active_job.title + "\n" +
				active_job.description
			)
		else:
			show_message("Finish your current job first.")

		return

	selected_job_id = JobManager.get_next_available_quest_id()

	if selected_job_id.is_empty():
		show_message("I have no more jobs for you.")
		return

	var job: QuestData = JobManager.get_quest(selected_job_id)

	if job == null:
		show_message("I couldn't find that job.")
		push_error("Quest resource not found: " + selected_job_id)
		return

	var reward_text: String = (
		"Reward: %d Renown and %d Credits.\n\n"
		% [job.renown_reward, job.credits_reward]
	)

	waiting_for_acceptance = true

	show_message(
		"I have a job for you: " + job.title + "\n" +
		job.description + "\n" +
		reward_text +
		"Press E to accept."
	)


func accept_selected_job() -> void:
	if selected_job_id.is_empty():
		waiting_for_acceptance = false
		return

	var job_id: String = selected_job_id

	waiting_for_acceptance = false
	selected_job_id = ""

	if JobManager.accept_job(job_id):
		var job: QuestData = JobManager.get_quest(job_id)

		if job != null:
			show_message(
				"Job accepted!\n" +
				job.title + "\n" +
				job.description
			)
		else:
			show_message("Job accepted!")

		print("Accepted quest: ", job_id)
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
