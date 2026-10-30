extends Area3D
class_name CityGate
## Main gate to The Spire. Entering the trigger shows a confirm prompt; [E] loads the
## battlefield scene. Reacts to the player on foot or the vehicle they are driving.
## Hierarchy: CityGate(Area3D) -> CollisionShape3D (visuals are built in code)

signal prompt_changed(text: String)

const SPIRE_SCENE := "res://scenes/spire/SpireRuins.tscn"

var _inside := false
var _portal_mat: StandardMaterial3D
var _ring: Node3D
var _time := 0.0
var _travelling := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visuals()


func _build_visuals() -> void:
	var obsidian := Palette.mat(Palette.OBSIDIAN, 0.1, 0.9)
	var edge := Palette.glow(Palette.VIOLET, 2.2)
	for sx in [-6.0, 6.0]:
		Palette.box(self, Vector3(3.0, 16.0, 3.0), Vector3(sx, 8.0, 0), obsidian, true, "Pillar")
		Palette.box(self, Vector3(0.2, 15.5, 0.2), Vector3(sx + (1.5 if sx < 0 else -1.5), 7.8, 1.55), edge, false, "PillarEdge")
		Palette.box(self, Vector3(0.2, 15.5, 0.2), Vector3(sx + (1.5 if sx < 0 else -1.5), 7.8, -1.55), edge, false, "PillarEdge")
		Palette.omni(self, Vector3(sx, 4.0, 2.5), Palette.VIOLET, 3.0, 14.0)
	Palette.box(self, Vector3(15.0, 2.2, 3.2), Vector3(0, 17.0, 0), obsidian, true, "Lintel")
	Palette.box(self, Vector3(14.6, 0.3, 0.3), Vector3(0, 16.0, 1.6), edge, false, "LintelGlow")
	_portal_mat = Palette.translucent_glow(Palette.VIOLET, 0.3, 2.5)
	Palette.box(self, Vector3(9.0, 15.0, 0.15), Vector3(0, 8.4, 0), _portal_mat, false, "PortalField")
	_ring = Palette.cylinder(self, 3.8, 0.25, Vector3(0, 8.4, 0), Palette.glow(Palette.CYAN, 3.0), false, "PortalRing", 32)
	_ring.rotation.x = PI / 2.0
	Palette.label3d(self, "SPIRE GATE", Vector3(0, 20.0, 0), Palette.VIOLET, 96, 0.06)
	Palette.label3d(self, "TRANSIT TO THE SPIRE RUINS", Vector3(0, 3.0, 4.0), Palette.CYAN, 36, 0.03)
	# Approach markers.
	for k in range(4):
		var z := 8.0 + k * 5.0
		for sx in [-5.5, 5.5]:
			Palette.box(self, Vector3(0.5, 0.1, 1.5), Vector3(sx, 0.05, z), Palette.glow(Palette.CYAN, 1.5), false, "ApproachLight")


func _process(delta: float) -> void:
	_time += delta
	_portal_mat.emission_energy_multiplier = 2.2 + sin(_time * 2.6) * 0.9
	_portal_mat.albedo_color.a = 0.25 + sin(_time * 2.6) * 0.08
	if _ring:
		_ring.rotation.z += delta * 0.8
		_ring.scale = Vector3.ONE * (1.0 + sin(_time * 2.6) * 0.04)


func _unhandled_input(event: InputEvent) -> void:
	if _inside and not _travelling and event.is_action_pressed("interact"):
		travel()


func travel() -> void:
	_travelling = true
	prompt_changed.emit("Transit engaged...")
	var tw := create_tween()
	tw.tween_property(_portal_mat, "emission_energy_multiplier", 12.0, 0.45)
	await tw.finished
	get_tree().change_scene_to_file(SPIRE_SCENE)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController or body is VehicleController:
		if body is VehicleController and not body.has_driver():
			return
		_inside = true
		prompt_changed.emit("SPIRE GATE  -  Press [E] to travel to The Spire Ruins")


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController or body is VehicleController:
		_inside = false
		if not _travelling:
			prompt_changed.emit("")
