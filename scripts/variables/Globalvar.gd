extends Node

var current_scene=null
var current_class="None"
var current_rank="D"
var current_renown: int=0
var current_points: int=0




func _ready():
	var root = get_tree().root
	# Using a negative index counts from the end, so this gets the last child node of `root`.
	current_scene = root.get_child(-1)
	print(current_scene)






















# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
