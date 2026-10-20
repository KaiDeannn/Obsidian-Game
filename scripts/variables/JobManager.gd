
extends Node

signal job_accepted(job_id: String)
signal job_progress_changed(progress: int, target: int)
signal job_completed(job_id: String)

# Job definitions
var jobs: Dictionary = {
	"delivery_001": {
		"title": "First Delivery",
		"description": "Deliver the package to the gatekeeper.",
		"target": 1,
		"renown_reward": 10,
		"points_reward": 5
	},
	"hunt_001": {
		"title": "Clear the Wilds",
		"description": "Defeat 5 hostile creatures.",
		"target": 5,
		"renown_reward": 25,
		"points_reward": 10
	}
}


func can_accept_job(job_id: String) -> bool:
	if not jobs.has(job_id):
		return false

	if Globalvar.active_job_id != "":
		return false

	if Globalvar.completed_jobs.has(job_id):
		return false

	return true


func accept_job(job_id: String) -> bool:
	if not can_accept_job(job_id):
		return false

	var job: Dictionary = jobs[job_id]

	Globalvar.active_job_id = job_id
	Globalvar.active_job_title = job["title"]
	Globalvar.active_job_description = job["description"]
	Globalvar.active_job_progress = 0
	Globalvar.active_job_target = job["target"]

	job_accepted.emit(job_id)
	job_progress_changed.emit(0, Globalvar.active_job_target)

	print("Accepted job: ", Globalvar.active_job_title)
	return true


func add_job_progress(amount: int = 1) -> void:
	if Globalvar.active_job_id == "":
		return

	if amount <= 0:
		return

	Globalvar.active_job_progress = min(
		Globalvar.active_job_progress + amount,
		Globalvar.active_job_target
	)

	job_progress_changed.emit(
		Globalvar.active_job_progress,
		Globalvar.active_job_target
	)

	if Globalvar.active_job_progress >= Globalvar.active_job_target:
		complete_job()


func complete_job() -> void:
	var job_id: String = Globalvar.active_job_id

	if job_id == "" or not jobs.has(job_id):
		return

	var job: Dictionary = jobs[job_id]

	Globalvar.current_renown += int(job["renown_reward"])
	Globalvar.current_points += int(job["points_reward"])

	if not Globalvar.completed_jobs.has(job_id):
		Globalvar.completed_jobs.append(job_id)

	print("Job completed: ", job["title"])
	print("Renown: +", job["renown_reward"])
	print("Points: +", job["points_reward"])

	Globalvar.active_job_id = ""
	Globalvar.active_job_title = ""
	Globalvar.active_job_description = ""
	Globalvar.active_job_progress = 0
	Globalvar.active_job_target = 0

	job_completed.emit(job_id)


func get_job_status(job_id: String) -> String:
	if Globalvar.completed_jobs.has(job_id):
		return "Completed"

	if Globalvar.active_job_id == job_id:
		return "Active"

	if jobs.has(job_id):
		return "Available"

	return "Unknown"
