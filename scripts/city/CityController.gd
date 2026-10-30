extends Node3D
## Scene controller for Nova Aetheris. Wires the player, vehicle, camera rig, HUD,
## smartphone and job system together, and owns mouse-capture state.
## Hierarchy: see README (NovaAetheris.tscn).

@onready var player: PlayerController = $Player
@onready var vehicle: VehicleController = $Vehicle
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: CityHUD = $CityHUD
@onready var phone: PhoneUI = $PhoneUI
@onready var gate: CityGate = $CityGate
@onready var objective_marker: ObjectiveMarker = $ObjectiveMarker
@onready var moon: DirectionalLight3D = $MoonLight

var _actor: Node3D


func _ready() -> void:
	moon.rotation_degrees = Vector3(-48, 35, 0)
	player.camera_rig = camera_rig
	_actor = player
	if GameState.arrival_from_spire:
		GameState.arrival_from_spire = false
		player.global_position = CityData.GATE_POSITION + Vector3(0, 0.6, 10)
		player.rotation.y = PI
		camera_rig._yaw = PI
	camera_rig.set_target(player, CameraRig.Mode.ORBIT)

	player.entered_vehicle.connect(_on_entered_vehicle)
	player.exited_vehicle.connect(_on_exited_vehicle)
	player.interact_prompt.connect(hud.set_prompt)
	gate.prompt_changed.connect(hud.set_prompt)
	phone.visibility_toggled.connect(_on_phone_toggled)
	hud.phone_pressed.connect(phone.toggle)

	JobManager.job_started.connect(_on_job_started)
	JobManager.objective_changed.connect(_on_objective_changed)
	JobManager.job_completed.connect(_on_job_completed)
	JobManager.job_cancelled.connect(_on_job_cancelled)
	if JobManager.has_active():
		_on_objective_changed(JobManager.current_objective(), JobManager.current_label(), JobManager.stage_index + 1, JobManager.stage_count())

	hud.minimap.bind(player, vehicle)
	# Comms + valet: the parked starter car is the player's Aether Compact.
	Valet.reset()
	Valet.register_deployed(vehicle.vehicle_id, vehicle)
	phone.notified.connect(hud.toast)
	Valet.driver_dispatched.connect(_on_valet_dispatched)
	Valet.vehicle_returned.connect(func(vid: String) -> void: hud.toast("%s returned to the garage" % GameState.vehicle_info(vid)["name"], UIKit.ACCENT))
	Valet.repair_started.connect(func(vid: String, sec: float) -> void: hud.toast("%s is on Rook's lift  -  %s" % [GameState.vehicle_info(vid)["name"], Valet.fmt_seconds(sec)], UIKit.AMBER))
	GameState.vehicle_damage_changed.connect(_on_vehicle_damage)
	_set_mouse_captured(true)
	hud.toast("Welcome to Nova Aetheris", UIKit.ACCENT)
	hud.toast("Press P to open your phone and pick up a job", UIKit.TEXT_DIM)


func _process(_delta: float) -> void:
	JobManager.report_actor_position(_actor.global_position)
	var driving := player.in_vehicle and is_instance_valid(player.current_vehicle)
	var mph := player.current_vehicle.get_mph() if driving else Vector2(player.velocity.x, player.velocity.z).length() * 2.23694
	hud.minimap.set_speed(mph, driving)
	camera_rig.set_speed_hint(mph / 90.0 if driving else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		phone.toggle()
	elif event.is_action_pressed("ui_cancel"):
		if phone.is_open:
			phone.close()
		else:
			_set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventMouseButton and event.pressed and not phone.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_set_mouse_captured(true)


func _set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	camera_rig.look_enabled = captured


# ----------------------------------------------------------------- vehicle
func _on_entered_vehicle(v: VehicleController) -> void:
	_actor = v
	hud.minimap.vehicle = v
	camera_rig.set_target(v, CameraRig.Mode.CHASE)
	hud.toast("Driving  -  W/S throttle, A/D steer, Space handbrake, E exit", UIKit.TEXT_DIM)


func _on_exited_vehicle(_v: VehicleController) -> void:
	_actor = player
	camera_rig.set_target(player, CameraRig.Mode.ORBIT)


# ----------------------------------------------------------------- phone
func _on_phone_toggled(open: bool) -> void:
	_set_mouse_captured(not open)
	player.input_enabled = not open
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v is VehicleController:
			v.input_enabled = not open


# ----------------------------------------------------------------- valet
func _on_valet_dispatched(vid: String, eta: float) -> void:
	hud.toast("Rook is sending your %s  -  ETA %s" % [GameState.vehicle_info(vid)["name"], Valet.fmt_seconds(eta)], UIKit.AMBER)


func _on_vehicle_damage(vid: String, damage: int) -> void:
	if damage >= 100:
		hud.toast("%s is wrecked  -  call Rook to fix it" % GameState.vehicle_info(vid)["name"], UIKit.RED)
	elif damage >= 60:
		hud.toast("%s badly damaged (%d%%)" % [GameState.vehicle_info(vid)["name"], damage], UIKit.AMBER)


# ----------------------------------------------------------------- jobs
func _on_job_started(job: Dictionary) -> void:
	hud.toast("Job accepted: %s" % job["title"], UIKit.ACCENT)


func _on_objective_changed(pos: Vector3, label: String, stage: int, total: int) -> void:
	objective_marker.show_at(pos, label)
	hud.set_objective(label, stage, total)
	hud.minimap.objective = pos
	hud.minimap.has_objective = true


func _on_job_completed(job: Dictionary, credits: int, renown: int) -> void:
	objective_marker.hide_marker()
	hud.clear_objective()
	hud.minimap.has_objective = false
	hud.toast("%s complete  +%s credits  +%d renown" % [job["title"], UIKit.fmt_int(credits), renown], UIKit.GREEN)


func _on_job_cancelled(_job: Dictionary) -> void:
	objective_marker.hide_marker()
	hud.clear_objective()
	hud.minimap.has_objective = false
	hud.toast("Job cancelled", UIKit.RED)
