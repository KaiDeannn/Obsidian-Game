extends CharacterBody3D
class_name SpirePlayer
## Battlefield player. One controller, two classes:
##  Swordsman - LMB swing (tweened arc + timed hitbox window), RMB block with a parry
##              window at block start; a parried hunter is staggered.
##  Sniper    - RMB aim: camera slides to first person, FOV narrows, scope HUD shows.
##              LMB fires a raycast with bullet adjustment: spread (hip vs ADS) and
##              gravity drop relative to a 60 m zero. Headshots deal double.
## Hierarchy: SpirePlayer(CharacterBody3D) -> CollisionShape3D ; Pivot -> SpringArm3D -> Camera3D ; Model (built in code)

signal health_changed(hp: float, max_hp: float)
signal ammo_changed(ammo: int, reserve: int)
signal aim_changed(is_aiming: bool)
signal hit_landed(target: Node3D, damage: float, headshot: bool)
signal block_state(is_blocking: bool, parried: bool)
signal shot_fired()
signal reloading(duration: float)
signal died()

const MAG_SIZE := 5
const BULLET_SPEED := 600.0
const DROP_GRAVITY := 9.8
const ZERO_RANGE := 60.0
const HIP_SPREAD := 0.035
const AIM_SPREAD := 0.0035
const SWORD_DAMAGE := 38.0
const RIFLE_DAMAGE := 70.0

@export var move_speed := 6.6
@export var sprint_speed := 9.6
@export var aim_move_speed := 2.6
@export var jump_velocity := 5.4
@export var mouse_sensitivity := 0.0022
@export var max_hp := 100.0

var combat_class: String = GameState.CLASS_SWORDSMAN
var hp := 100.0
var alive := true
var input_enabled := true
var is_aiming := false
var is_blocking := false
var ammo := MAG_SIZE
var reserve := 25

var _parry_until := 0.0
var _attacking := false
var _hitbox_open_until := 0.0
var _hitbox_opens_at := 0.0
var _attack_hits: Array[Node3D] = []
var _swing_side := 1.0
var _next_shot_time := 0.0
var _reloading := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rest_sword := Vector3(-1.5, 0.0, 0.2)
var _bob := 0.0

var model: Node3D
var sword_pivot: Node3D
var shield: Node3D
var rifle: Node3D
var muzzle: Node3D
var hitbox: Area3D
var _suit_mat: StandardMaterial3D
var _flash_light: OmniLight3D

@onready var pivot: Node3D = $Pivot
@onready var arm: SpringArm3D = $Pivot/SpringArm3D
@onready var camera: Camera3D = $Pivot/SpringArm3D/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D


func setup(cls: String) -> void:
	combat_class = cls


func _ready() -> void:
	hp = max_hp
	collision_layer = Palette.LAYER_PLAYER
	collision_mask = Palette.LAYER_WORLD | Palette.LAYER_ENEMY
	arm.add_excluded_object(get_rid())
	_build_model()
	_apply_class_visuals()
	health_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, reserve)


## Combat clock in game time (not wall time) so timing windows stay deterministic
## under fixed-FPS capture and slow frames.
var _clock := 0.0


func _now() -> float:
	return _clock


# ------------------------------------------------------------------ model
func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	_suit_mat = Palette.mat(Color(0.1, 0.12, 0.2), 0.55, 0.3)
	var trim := Palette.glow(Palette.CYAN, 2.0)
	var torso := CapsuleMesh.new()
	torso.radius = 0.33
	torso.height = 1.15
	var tm := MeshInstance3D.new()
	tm.mesh = torso
	tm.material_override = _suit_mat
	tm.position = Vector3(0, 0.95, 0)
	model.add_child(tm)
	Palette.sphere(model, 0.22, Vector3(0, 1.72, 0), Palette.mat(Color(0.12, 0.12, 0.15), 0.4, 0.5), "Helmet")
	Palette.box(model, Vector3(0.34, 0.08, 0.1), Vector3(0, 1.74, -0.18), trim, false, "Visor")
	Palette.box(model, Vector3(0.5, 0.05, 0.3), Vector3(0, 1.1, -0.3), trim, false, "ChestLight")
	for sx in [-0.18, 0.18]:
		Palette.box(model, Vector3(0.17, 0.5, 0.22), Vector3(sx, 0.28, 0), _suit_mat, false, "Leg")

	# Sword (right shoulder pivot; blade extends along pivot -Z).
	sword_pivot = Node3D.new()
	sword_pivot.name = "SwordPivot"
	sword_pivot.position = Vector3(0.45, 1.35, 0.0)
	sword_pivot.rotation = _rest_sword
	model.add_child(sword_pivot)
	Palette.box(sword_pivot, Vector3(0.07, 0.04, 1.2), Vector3(0, 0, -0.75), Palette.mat(Color(0.1, 0.08, 0.14), 0.15, 0.95), false, "Blade")
	Palette.box(sword_pivot, Vector3(0.02, 0.05, 1.15), Vector3(0, 0, -0.75), Palette.glow(Palette.VIOLET, 2.5), false, "BladeEdge")
	Palette.box(sword_pivot, Vector3(0.32, 0.06, 0.06), Vector3(0, 0, -0.12), Palette.mat(Color(0.5, 0.42, 0.2), 0.3, 0.9), false, "Guard")
	Palette.cylinder(sword_pivot, 0.035, 0.3, Vector3(0, 0, 0.08), Palette.mat(Color(0.08, 0.08, 0.08), 0.9), false, "Grip", 8)
	(sword_pivot.get_node("Grip") as Node3D).rotation.x = PI * 0.5

	# Shield (left side).
	shield = Node3D.new()
	shield.name = "Shield"
	shield.position = Vector3(-0.5, 1.1, 0.05)
	shield.rotation.y = 0.9
	model.add_child(shield)
	Palette.box(shield, Vector3(0.75, 0.95, 0.08), Vector3.ZERO, Palette.mat(Color(0.12, 0.1, 0.16), 0.2, 0.9), false, "ShieldPlate")
	Palette.box(shield, Vector3(0.1, 0.8, 0.09), Vector3.ZERO, Palette.glow(Palette.CYAN, 2.0), false, "ShieldLine")

	# Rifle (right hip, barrel along -Z).
	rifle = Node3D.new()
	rifle.name = "Rifle"
	rifle.position = Vector3(0.32, 1.25, -0.15)
	model.add_child(rifle)
	Palette.box(rifle, Vector3(0.08, 0.12, 1.35), Vector3(0, 0, -0.35), Palette.mat(Color(0.12, 0.12, 0.14), 0.3, 0.8), false, "Receiver")
	Palette.cylinder(rifle, 0.03, 0.7, Vector3(0, 0.02, -1.3), Palette.mat(Color(0.2, 0.2, 0.22), 0.3, 0.9), false, "Barrel", 8)
	(rifle.get_node("Barrel") as Node3D).rotation.x = PI * 0.5
	Palette.cylinder(rifle, 0.045, 0.4, Vector3(0, 0.12, -0.3), Palette.mat(Color(0.08, 0.08, 0.1), 0.2, 0.9), false, "Scope", 10)
	(rifle.get_node("Scope") as Node3D).rotation.x = PI * 0.5
	Palette.box(rifle, Vector3(0.09, 0.02, 1.0), Vector3(0, -0.07, -0.4), Palette.glow(Palette.CYAN, 1.8), false, "RailGlow")
	Palette.box(rifle, Vector3(0.08, 0.25, 0.3), Vector3(0, -0.15, 0.25), Palette.mat(Color(0.12, 0.12, 0.14), 0.3, 0.8), false, "Stock")
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -1.65)
	rifle.add_child(muzzle)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Palette.WARM_WHITE
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 6.0
	muzzle.add_child(_flash_light)

	# Sword hitbox in front of the body; only monitoring during the swing window.
	hitbox = Area3D.new()
	hitbox.name = "HitBox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = Palette.LAYER_ENEMY
	hitbox.monitoring = false
	hitbox.position = Vector3(0, 1.0, -1.3)
	var hb_shape := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(2.4, 1.8, 2.2)
	hb_shape.shape = hb
	hitbox.add_child(hb_shape)
	model.add_child(hitbox)


func _apply_class_visuals() -> void:
	var is_sword := combat_class == GameState.CLASS_SWORDSMAN
	sword_pivot.visible = is_sword
	shield.visible = is_sword
	rifle.visible = not is_sword
	_suit_mat.albedo_color = Color(0.16, 0.1, 0.2) if is_sword else Color(0.08, 0.14, 0.2)


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if not alive or not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * (0.35 if is_aiming else 1.0)
		rotation.y -= event.relative.x * sens
		pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * sens, -1.25, 1.0)
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("aim_block"):
		if combat_class == GameState.CLASS_SNIPER:
			set_aiming(true)
		else:
			set_blocking(true)
	elif event.is_action_released("aim_block"):
		if combat_class == GameState.CLASS_SNIPER:
			set_aiming(false)
		else:
			set_blocking(false)
	elif event.is_action_pressed("reload") and combat_class == GameState.CLASS_SNIPER:
		_reload()


func _physics_process(delta: float) -> void:
	_clock += delta
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y))
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed := move_speed
	if is_aiming or is_blocking:
		speed = aim_move_speed
	elif input_enabled and Input.is_action_pressed("sprint"):
		speed = sprint_speed
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 60.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 60.0 * delta)
	if input_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and not is_aiming:
		velocity.y = jump_velocity
	move_and_slide()

	# Locomotion bob and model lean.
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.5 and is_on_floor():
		_bob += delta * planar * 1.5
		model.position.y = absf(sin(_bob)) * 0.05
	else:
		model.position.y = lerpf(model.position.y, 0.0, 10.0 * delta)

	# Sword hit window.
	var now := _now()
	if _attacking and now >= _hitbox_opens_at and now <= _hitbox_open_until:
		if not hitbox.monitoring:
			hitbox.monitoring = true
		for body in hitbox.get_overlapping_bodies():
			if body in _attack_hits or not body.has_method("take_damage"):
				continue
			_attack_hits.append(body)
			var hit_pos: Vector3 = body.global_position + Vector3(0, 1.3, 0)
			body.take_damage(SWORD_DAMAGE, hit_pos, false, self)
			hit_landed.emit(body, SWORD_DAMAGE, false)
	elif hitbox.monitoring:
		hitbox.monitoring = false


# ------------------------------------------------------------------ swordsman
func _try_attack() -> void:
	if combat_class == GameState.CLASS_SWORDSMAN:
		_swing()
	else:
		_shoot()


func _swing() -> void:
	if _attacking or is_blocking:
		return
	_attacking = true
	_attack_hits.clear()
	var now := _now()
	_hitbox_opens_at = now + 0.08
	_hitbox_open_until = now + 0.26
	var side := _swing_side
	_swing_side = -_swing_side
	var windup := Vector3(0.9, 0.0, side * 0.7)
	var strike := Vector3(-1.1, 0.0, -side * 0.6)
	sword_pivot.rotation = windup
	var tw := create_tween()
	tw.tween_property(sword_pivot, "rotation", strike, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sword_pivot, "rotation", _rest_sword, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _attacking = false)
	# Lunge.
	velocity += -global_transform.basis.z * 2.5


func set_blocking(on: bool) -> void:
	if is_blocking == on:
		return
	is_blocking = on
	if on:
		_parry_until = _now() + 0.3
	var tw := create_tween().set_parallel(true)
	if on:
		tw.tween_property(shield, "position", Vector3(-0.1, 1.2, -0.55), 0.12)
		tw.tween_property(shield, "rotation", Vector3(0, 0, 0), 0.12)
	else:
		tw.tween_property(shield, "position", Vector3(-0.5, 1.1, 0.05), 0.15)
		tw.tween_property(shield, "rotation", Vector3(0, 0.9, 0), 0.15)
	block_state.emit(on, false)


# ------------------------------------------------------------------ sniper
func set_aiming(on: bool) -> void:
	if is_aiming == on:
		return
	is_aiming = on
	var tw := create_tween().set_parallel(true)
	tw.tween_property(arm, "spring_length", 0.05 if on else 3.2, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "fov", 16.0 if on else 75.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "h_offset", 0.0 if on else 0.55, 0.18)
	if on:
		model.visible = false
	else:
		tw.chain().tween_callback(func() -> void: model.visible = not is_aiming)
	aim_changed.emit(on)


func _drop_at(distance: float) -> float:
	var t := distance / BULLET_SPEED
	return 0.5 * DROP_GRAVITY * t * t


func _shoot() -> void:
	var now := _now()
	if _reloading or now < _next_shot_time:
		return
	if ammo <= 0:
		_reload()
		return
	ammo -= 1
	_next_shot_time = now + 1.15
	# Fire from the rendered view centre (accounts for the over-shoulder h_offset).
	var vp_centre := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(vp_centre)
	var dir := camera.project_ray_normal(vp_centre)
	var basis := camera.global_transform.basis
	# --- bullet adjustment 1: spread (hip fire vs. aimed)
	var spread := AIM_SPREAD if is_aiming else HIP_SPREAD
	dir = dir.rotated(basis.x, randf_range(-spread, spread)).rotated(basis.y, randf_range(-spread, spread)).normalized()
	# --- bullet adjustment 2: gravity drop relative to the 60 m zero
	var space := get_world_3d().direct_space_state
	var mask := Palette.LAYER_WORLD | Palette.LAYER_ENEMY
	var max_range := 320.0
	var probe := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, mask, [get_rid()])
	var first := space.intersect_ray(probe)
	var dist := origin.distance_to(first["position"]) if not first.is_empty() else max_range
	var vertical_offset := _drop_at(ZERO_RANGE) - _drop_at(dist)
	var end := origin + dir * dist + Vector3.UP * vertical_offset
	var query := PhysicsRayQueryParameters3D.create(origin, end + (end - origin).normalized() * 0.6, mask, [get_rid()])
	var hit := space.intersect_ray(query)
	var impact: Vector3 = hit["position"] if not hit.is_empty() else end
	_spawn_tracer(muzzle.global_position if not is_aiming else origin + dir * 0.4 + Vector3.DOWN * 0.15, impact)
	_muzzle_flash()
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider is Node3D and collider.has_method("take_damage"):
			var headshot: bool = impact.y > (collider as Node3D).global_position.y + 1.7
			var dmg := RIFLE_DAMAGE * (2.0 if headshot else 1.0)
			collider.take_damage(dmg, impact, headshot, self)
			hit_landed.emit(collider, dmg, headshot)
		else:
			_spawn_impact(impact)
	# Recoil.
	pivot.rotation.x += 0.035 if is_aiming else 0.06
	ammo_changed.emit(ammo, reserve)
	shot_fired.emit()
	if ammo == 0:
		_reload()


func _reload() -> void:
	if _reloading or ammo >= MAG_SIZE or reserve <= 0:
		return
	_reloading = true
	var duration := 2.2
	reloading.emit(duration)
	var tw := create_tween()
	tw.tween_property(rifle, "rotation:x", -0.5, 0.3)
	tw.tween_interval(duration - 0.6)
	tw.tween_property(rifle, "rotation:x", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		var needed := MAG_SIZE - ammo
		var taken := mini(needed, reserve)
		ammo += taken
		reserve -= taken
		_reloading = false
		ammo_changed.emit(ammo, reserve))


func _muzzle_flash() -> void:
	_flash_light.light_energy = 8.0
	var tw := create_tween()
	tw.tween_property(_flash_light, "light_energy", 0.0, 0.12)
	var flash := Palette.sphere(muzzle, 0.14, Vector3.ZERO, Palette.glow(Palette.WARM_WHITE, 6.0), "Flash")
	var tw2 := flash.create_tween()
	tw2.tween_property(flash, "scale", Vector3(0.1, 0.1, 0.1), 0.1)
	tw2.tween_callback(flash.queue_free)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = length
	mesh.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := Palette.translucent_glow(Palette.CYAN, 0.9, 4.0)
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.look_at(to, up)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)


func _spawn_impact(pos: Vector3) -> void:
	var s := Palette.sphere(get_tree().current_scene, 0.12, Vector3.ZERO, Palette.glow(Palette.AMBER, 4.0), "Impact")
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3(2.2, 2.2, 2.2), 0.18)
	tw.parallel().tween_property(s, "transparency", 1.0, 0.18)
	tw.tween_callback(s.queue_free)


# ------------------------------------------------------------------ damage
func _facing(src: Node3D) -> bool:
	var to := src.global_position - global_position
	to.y = 0.0
	return (-global_transform.basis.z).dot(to.normalized()) > 0.3


func take_damage(amount: float, source: Node3D = null) -> void:
	if not alive:
		return
	if is_blocking and source and _facing(source):
		if _now() < _parry_until:
			if source.has_method("stagger"):
				source.stagger()
			block_state.emit(true, true)
			_flash_suit(Palette.CYAN)
			return
		amount *= 0.12
		_flash_suit(Palette.CYAN)
	else:
		_flash_suit(Palette.RED)
	hp = maxf(0.0, hp - amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func _flash_suit(color: Color) -> void:
	_suit_mat.emission_enabled = true
	_suit_mat.emission = color
	_suit_mat.emission_energy_multiplier = 2.5
	var tw := create_tween()
	tw.tween_property(_suit_mat, "emission_energy_multiplier", 0.0, 0.3)


func _die() -> void:
	alive = false
	set_aiming(false)
	set_blocking(false)
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -PI * 0.45, 0.5).set_trans(Tween.TRANS_QUAD)
	died.emit()


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.visible = true
	hp = max_hp
	ammo = MAG_SIZE
	reserve = 25
	_reloading = false
	alive = true
	health_changed.emit(hp, max_hp)
	ammo_changed.emit(ammo, reserve)
