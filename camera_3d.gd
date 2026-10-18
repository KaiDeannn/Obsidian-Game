
extends Camera3D

@export var height: float = 40.0
@export var map_size: float = 30.0

var target: Node3D

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = map_size
	target = get_tree().get_first_node_in_group("players") as Node3D

	if target == null:
		push_warning("Minimap: No player found in group 'player'.")

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D

	if not is_instance_valid(target):
		return

	global_position = target.global_position + Vector3.UP * height
	global_rotation = Vector3(deg_to_rad(-90), 0.0, 0.0)
