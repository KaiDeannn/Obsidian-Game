extends Node
## JobManager (autoload "JobManager")
## Holds the city job board, the active job and its multi-stage objectives.
## The city controller feeds it the controlled actor's position every frame; when the
## actor reaches the current objective the job advances and finally pays out
## Credits (GameState) and Renown (RankManager).

signal job_started(job: Dictionary)
signal objective_changed(position: Vector3, label: String, stage: int, total: int)
signal job_completed(job: Dictionary, credits: int, renown: int)
signal job_cancelled(job: Dictionary)

const REACH_DISTANCE := 4.5

var jobs: Array[Dictionary] = []
var active_job: Dictionary = {}
var stage_index: int = 0
var completed_counts: Dictionary = {}


func _ready() -> void:
	jobs = CityData.JOBS.duplicate(true)


func get_job(job_id: String) -> Dictionary:
	for job in jobs:
		if job["id"] == job_id:
			return job
	return {}


func has_active() -> bool:
	return not active_job.is_empty()


func is_active(job_id: String) -> bool:
	return has_active() and active_job["id"] == job_id


func times_completed(job_id: String) -> int:
	return int(completed_counts.get(job_id, 0))


func start_job(job_id: String) -> bool:
	if has_active():
		return false
	var job := get_job(job_id)
	if job.is_empty():
		return false
	active_job = job
	stage_index = 0
	job_started.emit(job)
	_emit_objective()
	return true


func cancel_job() -> void:
	if not has_active():
		return
	var job := active_job
	active_job = {}
	stage_index = 0
	job_cancelled.emit(job)


func stage_count() -> int:
	return active_job["stages"].size() if has_active() else 0


func current_objective() -> Vector3:
	if not has_active():
		return Vector3.ZERO
	return active_job["stages"][stage_index]["pos"]


func current_label() -> String:
	if not has_active():
		return ""
	return active_job["stages"][stage_index]["label"]


## Called every frame by the scene controller with the player's (or vehicle's) position.
func report_actor_position(pos: Vector3) -> void:
	if not has_active():
		return
	var target := current_objective()
	var flat := Vector2(pos.x - target.x, pos.z - target.z)
	if flat.length() <= REACH_DISTANCE:
		_advance()


func _advance() -> void:
	stage_index += 1
	if stage_index >= stage_count():
		_complete()
	else:
		_emit_objective()


func _emit_objective() -> void:
	objective_changed.emit(current_objective(), current_label(), stage_index + 1, stage_count())


func _complete() -> void:
	var job := active_job
	var credits: int = job["credits"]
	var renown: int = job["renown"]
	# Property perk: every owned Heights property adds +5% credits.
	var bonus := int(credits * 0.05 * GameState.owned_properties.size())
	credits += bonus
	GameState.add_credits(credits)
	RankManager.add_renown(renown)
	GameState.jobs_completed += 1
	completed_counts[job["id"]] = times_completed(job["id"]) + 1
	active_job = {}
	stage_index = 0
	job_completed.emit(job, credits, renown)
