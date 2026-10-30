extends Node
## Exports both game maps (all generated geometry, materials and lights) to glTF so they
## can be opened in Blender / any DCC. Run headless:
##   godot --headless --path . res://tools/ExportMaps.tscn

const OUT_DIR := "res://preview/maps/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _export("res://scenes/city/NovaAetheris.tscn", "nova_aetheris")
	await _export("res://scenes/spire/SpireRuins.tscn", "spire_ruins")
	get_tree().quit()


func _export(scene_path: String, out_name: String) -> void:
	var scene: Node = load(scene_path).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# Strip UI / camera rigs / helper nodes that carry no map geometry.
	for n in [scene.get_node_or_null("CityHUD"), scene.get_node_or_null("PhoneUI"), scene.get_node_or_null("SpireHUD"), scene.get_node_or_null("CameraRig"), scene.get_node_or_null("ObjectiveMarker")]:
		if n:
			n.get_parent().remove_child(n)
			n.free()
	_name_nodes(scene)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err != OK:
		push_error("append_from_scene failed: %d" % err)
	var path := OUT_DIR + out_name + ".glb"
	err = doc.write_to_filesystem(state, path)
	print("%s -> %s (err %d), nodes: %d" % [scene_path, ProjectSettings.globalize_path(path), err, _count(scene)])
	scene.queue_free()
	await get_tree().process_frame


## Give generated nodes stable, descriptive names so Blender's outliner is readable.
func _name_nodes(root: Node) -> void:
	var counters := {}
	for n in root.find_children("*", "", true, false):
		var base := n.name.rstrip("0123456789")
		if base == "" or base == "@":
			base = n.get_class()
		counters[base] = counters.get(base, 0) + 1
		n.name = "%s_%03d" % [base, counters[base]]


func _count(root: Node) -> int:
	return root.find_children("*", "", true, false).size()
