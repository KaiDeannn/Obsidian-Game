extends CharacterBody3D
class_name VehicleController
## Arcade vehicle on a CharacterBody3D: throttle/brake/reverse, speed-sensitive steering,
## grip blending (handbrake drift) and collision speed loss. Only drives while it has a driver.
## Hierarchy: Vehicle(CharacterBody3D) -> CollisionShape3D, Model(Node3D; wheels/lights built in code)

signal speed_changed(mph: float)
signal impact(severity: float)

## Which catalogue entry this body is (CityData.VEHICLES); set before adding to the tree.
@export var vehicle_id := "aether_compact"
@export var paint := Color(0.09, 0.08, 0.12)

@export var max_speed := 42.0            # m/s  (~94 mph)
@export var max_reverse_speed := 9.0
@export var acceleration := 13.0
@export var brake_force := 30.0
@export var drag := 3.0
@export var steer_rate := 2.3            # rad/s at full steering, low speed
@export var grip := 7.0

var driver: Node3D
var input_enabled := true
var forward_speed := 0.0
## Autopilot: when true the valet driver feeds these instead of the keyboard.
var autopilot := false
var auto_throttle := 0.0
var auto_steer := 0.0
var auto_brake := false
var _impact_cooldown := 0.0

var _steer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _wheel_spin := 0.0
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _body: Node3D
var _headlights: Array[SpotLight3D] = []

@onready var model: Node3D = $Model


func _ready() -> void:
	add_to_group("vehicles")
	_build_model()
	_set_lights(false)


func display_name() -> String:
	return str(GameState.vehicle_info(vehicle_id)["name"])


func has_driver() -> bool:
	return is_instance_valid(driver)


func set_driver(p: Node3D) -> void:
	driver = p
	_set_lights(true)


func release_driver() -> void:
	driver = null
	_set_lights(false)


func get_mph() -> float:
	return absf(forward_speed) * 2.23694


func _build_model() -> void:
	var paint_mat := Palette.pbr(paint, 0.22, 0.75)
	var cabin_mat := Palette.pbr(Color(0.08, 0.1, 0.13), 0.04, 0.9)
	var trim := Palette.pbr(Color(0.12, 0.12, 0.13), 0.5, 0.3)
	_body = Node3D.new()
	_body.name = "Body"
	model.add_child(_body)
	Palette.box(_body, Vector3(2.0, 0.42, 4.3), Vector3(0, 0.5, 0), paint_mat, false, "Chassis")
	var hood := Palette.box(_body, Vector3(1.85, 0.1, 1.6), Vector3(0, 0.72, -1.45), paint_mat, false, "Hood")
	hood.rotation.x = -0.12
	Palette.box(_body, Vector3(1.6, 0.5, 1.9), Vector3(0, 0.95, 0.1), cabin_mat, false, "Cabin")
	Palette.box(_body, Vector3(1.7, 0.35, 0.9), Vector3(0, 0.85, 1.5), paint_mat, false, "Deck")
	Palette.box(_body, Vector3(1.9, 0.05, 0.3), Vector3(0, 1.12, 2.0), paint_mat, false, "Spoiler")
	for sx in [-0.7, 0.7]:
		Palette.box(_body, Vector3(0.08, 0.25, 0.05), Vector3(sx, 0.98, 2.0), paint_mat, false, "Strut")
	Palette.box(_body, Vector3(2.02, 0.12, 0.3), Vector3(0, 0.3, -2.1), trim, false, "Splitter")
	Palette.box(_body, Vector3(2.02, 0.1, 4.0), Vector3(0, 0.3, 0), trim, false, "Sill")
	for sx in [-0.65, 0.65]:
		Palette.box(_body, Vector3(0.4, 0.12, 0.1), Vector3(sx, 0.56, -2.15), Palette.mat(Color(0.95, 0.95, 0.9), 0.3, 0.0, Palette.WARM_WHITE, 1.2), false, "Headlamp")
		Palette.box(_body, Vector3(0.45, 0.1, 0.1), Vector3(sx, 0.62, 2.15), Palette.mat(Color(0.6, 0.05, 0.05), 0.3, 0.0, Palette.RED, 1.5), false, "Taillamp")
		var spot := SpotLight3D.new()
		spot.position = Vector3(sx, 0.6, -2.2)
		spot.rotation_degrees = Vector3(-6, 180, 0)
		spot.light_color = Palette.WARM_WHITE
		spot.light_energy = 3.0
		spot.spot_range = 24.0
		spot.spot_angle = 32.0
		spot.shadow_enabled = false
		_body.add_child(spot)
		_headlights.append(spot)
	var tyre := Palette.pbr(Color(0.06, 0.06, 0.06), 0.9, 0.0)
	var rim := Palette.pbr(Color(0.82, 0.84, 0.87), 0.2, 0.95)
	for wp in [Vector3(-1.0, 0.36, -1.4), Vector3(1.0, 0.36, -1.4), Vector3(-1.0, 0.36, 1.4), Vector3(1.0, 0.36, 1.4)]:
		var hub := Node3D.new()
		hub.position = wp
		model.add_child(hub)
		var w := Palette.cylinder(hub, 0.36, 0.3, Vector3.ZERO, tyre, false, "Tyre", 16)
		w.rotation.z = PI / 2.0
		var r := Palette.cylinder(hub, 0.22, 0.32, Vector3.ZERO, rim, false, "Rim", 12)
		r.rotation.z = PI / 2.0
		_wheels.append(hub)
		if wp.z < 0:
			_front_wheels.append(hub)


func _set_lights(on: bool) -> void:
	for l in _headlights:
		l.visible = on


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if autopilot:
		throttle = auto_throttle
		steer_in = auto_steer
		handbrake = auto_brake
	elif has_driver() and input_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")

	# ---- longitudinal
	if throttle > 0.0:
		if forward_speed < -0.2:
			forward_speed = move_toward(forward_speed, 0.0, brake_force * delta)
		else:
			forward_speed = move_toward(forward_speed, max_speed, acceleration * throttle * delta)
	elif throttle < 0.0:
		if forward_speed > 0.2:
			forward_speed = move_toward(forward_speed, 0.0, brake_force * delta)
		else:
			forward_speed = move_toward(forward_speed, -max_reverse_speed, acceleration * 0.6 * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, drag * delta)
	if handbrake:
		forward_speed = move_toward(forward_speed, 0.0, brake_force * 1.3 * delta)

	# ---- steering: fades in with speed, dampens at high speed
	var speed_factor := clampf(absf(forward_speed) / 7.0, 0.0, 1.0)
	var high_speed_damp := 1.0 - 0.55 * clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
	_steer = lerpf(_steer, steer_in, 1.0 - exp(-delta * 9.0))
	var direction_sign := 1.0 if forward_speed >= 0.0 else -1.0
	rotation.y += _steer * steer_rate * speed_factor * high_speed_damp * direction_sign * delta

	# ---- velocity: blend lateral toward heading (grip), keep gravity
	var fwd := -global_transform.basis.z
	var target := fwd * forward_speed
	var g := grip * (0.3 if handbrake else 1.0)
	var blend := clampf(g * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, target.x, blend)
	velocity.z = lerpf(velocity.z, target.z, blend)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	# ---- impact: lose speed when hitting something head-on, and take body damage
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) < 0.5 and n.dot(fwd) < -0.4:
			var hit_speed := absf(forward_speed)
			forward_speed *= 0.25
			# no damage while an NPC (valet, traffic) is at the wheel
			if hit_speed > 5.0 and _impact_cooldown <= 0.0 and not autopilot:
				_impact_cooldown = 0.6
				var severity := clampf(hit_speed / max_speed, 0.0, 1.0)
				GameState.damage_vehicle(vehicle_id, int(round(4.0 + severity * 30.0)))
				impact.emit(severity)

	# ---- visuals
	_wheel_spin += forward_speed * delta / 0.36
	for i in range(_wheels.size()):
		var hub := _wheels[i]
		hub.rotation.x = _wheel_spin
		if _front_wheels.has(hub):
			hub.rotation.y = _steer * 0.45
	if _body:
		_body.rotation.z = lerpf(_body.rotation.z, -_steer * clampf(absf(forward_speed) / max_speed, 0, 1) * 0.08, 6.0 * delta)
		_body.rotation.x = lerpf(_body.rotation.x, -throttle * 0.02, 6.0 * delta)
	speed_changed.emit(get_mph())
