
extends Node3D

enum NPCType {
	QUEST_GIVER,
	FRIENDLY,
	HOSTILE
}

@export var npc_type: NPCType = NPCType.QUEST_GIVER
@export var marker_height: float = 2.0
@export var marker_radius: float = 0.35

var marker: MeshInstance3D


func _ready() -> void:
	create_marker()


func create_marker() -> void:
	marker = MeshInstance3D.new()
	marker.name = "MinimapMarker"

	var sphere := SphereMesh.new()
	sphere.radius = marker_radius
	sphere.height = marker_radius * 2.0
	marker.mesh = sphere

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = get_marker_color()

	marker.material_override = material
	marker.position = Vector3(0.0, marker_height, 0.0)

	marker.layers = 2
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(marker)


func get_marker_color() -> Color:
	match npc_type:
		NPCType.QUEST_GIVER:
			return Color("bbdd00ff")
		NPCType.FRIENDLY:
			return Color("#55D878")
		NPCType.HOSTILE:
			return Color("#EF6461")

	return Color.WHITE
