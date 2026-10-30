extends Node3D
class_name ObjectiveMarker
## World-space beacon for the active job objective: light beam, spinning ring, label.

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _label: Label3D
var _time := 0.0


func _ready() -> void:
	_beam = Palette.cylinder(self, 0.7, 40.0, Vector3(0, 20, 0), Palette.translucent_glow(Palette.CYAN, 0.28, 2.0), false, "Beam", 16)
	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.9
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = Palette.glow(Palette.CYAN, 3.0)
	_ring.position = Vector3(0, 0.4, 0)
	add_child(_ring)
	_label = Palette.label3d(self, "OBJECTIVE", Vector3(0, 4.5, 0), Palette.CYAN, 48, 0.035)
	visible = false


func show_at(pos: Vector3, label: String) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	_label.text = label.to_upper()
	visible = true


func hide_marker() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_ring.rotation.y += delta * 1.5
	_ring.position.y = 0.4 + sin(_time * 2.0) * 0.15
	_beam.scale.x = 1.0 + sin(_time * 3.0) * 0.1
	_beam.scale.z = _beam.scale.x
