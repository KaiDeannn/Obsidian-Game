extends Node


var current_scene: Node = null
var current_class: String = "None"
var current_rank: String = "D"
var current_renown: int = 0
var current_credits: int = 0
var current_points: int = 0
var player_name: String = "Player"

# Active quest
var active_job_id: String = ""
var active_job_title: String = ""
var active_job_description: String = ""
var active_job_progress: int = 0
var active_job_target: int = 0

# Completed quest IDs
var completed_jobs: Array[String] = []

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(-1)
	print(player_name)
	print(current_scene )






















func _process(_delta: float) -> void:
	pass
