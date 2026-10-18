extends Node3D
@export var fade_duration: float = 2.0
var elapsed: float = 0.0
var fading: bool = false
var fade_material: StandardMaterial3D
@onready var mesh_instance: MeshInstance3D = $GateMesh



func _ready() -> void:
	var original_material: Material = mesh_instance.get_surface_override_material(0)
	
	if original_material == null and mesh_instance.mesh != null:
		original_material = mesh_instance.mesh.surface_get_material(0)
	if original_material is StandardMaterial3D:
		fade_material = original_material.duplicate()
	else:
		fade_material = StandardMaterial3D.new()
	fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, fade_material)
@onready var player = $"../Player"
func _process(delta: float) -> void:
	if not fading:
		return
	elapsed += delta
	var alpha: float = clampf(1.0 - elapsed / fade_duration, 0.0, 1.0)
	
	var color: Color = fade_material.albedo_color
	color.a = alpha
	fade_material.albedo_color = color
	if alpha <= 0.0:
		mesh_instance.visible = false
		fading = false
		player.cinematic_scene = true
		player.cinematic_follow($GateArea/GateEnterPlayerArea, 3.0, 0.0)

		
		
func player_entered_gate():
	var dialogue_text: String= "Hey there. I see you just arrived. Fresh off the gates, right? No place to stay, no credits in your pocket… I know what that feels like. You look like someone who's willing to work. Need a job? I've got small tasks — deliveries, simple runs. Nothing dangerous yet, but it'll pay. I've sent someone to pick you up. Look to your right — they're less than a minute away. No need to walk far. They'll bring you straight to me. See you soon."
	await $"../GameUI".play_typewriter_effect(dialogue_text)
	player.cinematic_scene = false
	
	
func vanish() -> void:
	if fading or not mesh_instance.visible:
		return
	if fade_duration <= 0.0:
		mesh_instance.visible = false
		return
	elapsed = 0.0
	fading = true

func _on_trigger_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		print("Player entered the area!")
		vanish()


func _on_gate_enter_player_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		print("PLAYER ENTERED THE GATE")
		player_entered_gate()
		$GateArea/GateEnterPlayerArea.queue_free()
	
	
