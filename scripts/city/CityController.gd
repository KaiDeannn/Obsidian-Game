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
var _in_cinematic := false


func _ready() -> void:
	moon.rotation_degrees = Vector3(-52, 38, 0)      # mid-afternoon sun
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
	# Battle system: a pending match puts the portal marker on the Spire gate.
	Battle.match_ready.connect(_on_match_ready)
	Battle.match_cleared.connect(_on_match_cleared)
	if Battle.has_pending():
		_on_match_ready(Battle.pending)
	if Battle.last_result.size() > 0 and GameState.arrival_from_spire == false and not Battle.last_result.get("announced", false):
		Battle.last_result["announced"] = true
		hud.toast("%s: %s   +%d renown  +%d pts" % [Battle.last_result["mode_name"], "VICTORY" if Battle.last_result["won"] else "DEFEAT", Battle.last_result["renown"], Battle.last_result["points"]], UIKit.GREEN if Battle.last_result["won"] else UIKit.RED)
	if not GameState.intro_played:
		GameState.intro_played = true
		_play_intro()
	else:
		hud.toast("Welcome to Nova Aetheris", UIKit.ACCENT)
		hud.toast("Press P to open your phone and pick up a job", UIKit.TEXT_DIM)


# ----------------------------------------------------------------- cinematics
## Opening fly-over (CinematicData "city_intro"). Input and HUD are off until it ends.
func _play_intro() -> void:
	_in_cinematic = true
	hud.visible = false
	player.input_enabled = false
	camera_rig.look_enabled = false
	await Cinematic.play_named("city_intro", {"resolve": _resolve_cine_point})
	_in_cinematic = false
	camera_rig._yaw = player.rotation.y
	hud.visible = true
	player.input_enabled = not phone.is_open
	camera_rig.look_enabled = true
	_set_mouse_captured(true)
	hud.toast("Welcome to Nova Aetheris", UIKit.ACCENT)
	hud.toast("Press P to open your phone and pick up a job", UIKit.TEXT_DIM)


## Live anchors for sequences: the camera can end exactly where gameplay's camera sits.
func _resolve_cine_point(key: String) -> Variant:
	var p := player.global_position
	var back := player.global_transform.basis.z
	match key:
		"player_back":
			return {"pos": p + back * 4.6 + Vector3.UP * 2.3, "look": p + Vector3.UP * 1.4}
		"player_high":
			return {"pos": p + back * 10.0 + Vector3.UP * 9.0, "look": CityData.GATE_POSITION + Vector3.UP * 8.0}
		"player_head":
			return p + Vector3.UP * 1.6
		"gate":
			return CityData.GATE_POSITION
		"player":
			return player
	return Vector3.ZERO


# ----------------------------------------------------------------- battles
func _on_match_ready(m: Dictionary) -> void:
	objective_marker.show_at(CityData.GATE_POSITION, "YOUR PORTAL  -  %s" % m["mode_name"])
	hud.set_objective("Match ready: %s on %s. Follow the markers to your portal." % [m["mode_name"], m["map_name"]], 1, 1)
	hud.minimap.objective = CityData.GATE_POSITION
	hud.minimap.has_objective = true
	gate.set_match_pending(true, m["mode_name"])
	hud.toast(m["message"], UIKit.GREEN)
	if not _in_cinematic and not Cinematic.is_playing and is_inside_tree():
		_match_cinematic()


func _match_cinematic() -> void:
	_in_cinematic = true
	player.input_enabled = false
	camera_rig.look_enabled = false
	await Cinematic.play_named("match_ready", {"resolve": _resolve_cine_point, "letterbox": true})
	_in_cinematic = false
	camera_rig._yaw = player.rotation.y
	player.input_enabled = not phone.is_open
	camera_rig.look_enabled = not phone.is_open


func _on_match_cleared() -> void:
	gate.set_match_pending(false, "")
	if not JobManager.has_active():
		objective_marker.hide_marker()
		hud.clear_objective()
		hud.minimap.has_objective = false


func _process(_delta: float) -> void:
	JobManager.report_actor_position(_actor.global_position)
	var driving := player.in_vehicle and is_instance_valid(player.current_vehicle)
	var mph := player.current_vehicle.get_mph() if driving else Vector2(player.velocity.x, player.velocity.z).length() * 2.23694
	hud.minimap.set_speed(mph, driving)
	camera_rig.set_speed_hint(mph / 90.0 if driving else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _in_cinematic:
		return
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
