
extends Control

@onready var title_label: Label = $QuestUI/VBoxContainer/MarginContainer/Label
@onready var description_label: Label = $QuestUI/VBoxContainer/Panel/Label
@onready var progress_label: Label = $QuestUI/VBoxContainer/Panel3/Label2
@onready var reward_label: Label = $QuestUI/VBoxContainer/Panel2/Label2
@onready var quest_panel: PanelContainer = $QuestUI


@onready var inventory_panel: PanelContainer = $Inventory







func _ready() -> void:
	JobManager.job_accepted.connect(_on_job_accepted)
	JobManager.job_progress_changed.connect(_on_job_progress_changed)
	JobManager.job_completed.connect(_on_job_completed)

	refresh_quest()
	inventory_panel.visible = false
	


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		inventory_panel.visible = not inventory_panel.visible





func refresh_quest() -> void:
	if Globalvar.active_job_id == "":
		hide_quest()
		return

	show_quest()


func show_quest() -> void:
	quest_panel.visible = true
	var job: Dictionary = JobManager.jobs[Globalvar.active_job_id]
	
	title_label.text = Globalvar.active_job_title
	description_label.text = Globalvar.active_job_description

	progress_label.text = "Progress: %d / %d" % [
		Globalvar.active_job_progress,
		Globalvar.active_job_target
	]
	reward_label.text = "Reward: %d Renown | %d Points" % [
	int(job["renown_reward"]),
	int(job["points_reward"])
]


func hide_quest() -> void:
	quest_panel.visible = false


func _on_job_accepted(_job_id: String) -> void:
	refresh_quest()


func _on_job_progress_changed(progress: int, target: int) -> void:
	if Globalvar.active_job_id == "":
		return

	progress_label.text = "Progress: %d / %d" % [
		progress,
		target
	]


func _on_job_completed(_job_id: String) -> void:
	title_label.text = "Quest Completed!"
	description_label.text = "You received your rewards."
	progress_label.text = ""
	visible = true
