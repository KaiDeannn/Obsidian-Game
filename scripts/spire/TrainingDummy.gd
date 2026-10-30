extends CharacterBody3D
class_name TrainingDummy
## AI target. kind DUMMY = armoured training post that tracks the player; kind HUNTER =
## patrolling melee bot that chases, winds up and strikes (parryable). Both take damage
## from sword hitboxes and sniper raycasts, show floating damage numbers, die, pay out
## Points + Renown through SpireCombat, and respawn.
## Hierarchy: TrainingDummy(CharacterBody3D, group "enemy") -> CollisionShape3D ; Model (built in code)

enum Kind { DUMMY, HUNTER }
enum State { IDLE, CHASE, WINDUP, RECOVER, STAGGER }

signal defeated(dummy: TrainingDummy)
signal damaged(dummy: TrainingDummy, amount: float, headshot: bool)

@export var kind: Kind = Kind.DUMMY
@export var respawn_time := 7.0
@export var detect_range := 16.0
@export var attack_range := 2.4
@export var move_speed := 4.3
@export var attack_damage := 12.0

var max_hp := 100.0
var hp := 100.0
var points_reward := 50
var renown_reward := 45
var alive := true
var player: Node3D

var state: State = State.IDLE
var _state_until := 0.0
var _home: Vector3
var _wander_target: Vector3
var _next_wander := 0.0
var _avoid_dir := Vector3.ZERO
var _avoid_until := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _model: Node3D
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _arm: Node3D
var _time := 0.0

@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = Palette.LAYER_ENEMY
	collision_mask = Palette.LAYER_WORLD | Palette.LAYER_PLAYER
	_home = global_position
	_wander_target = _home
	if kind == Kind.HUNTER:
		max_hp = 140.0
		points_reward = 150
		renown_reward = 90
	else:
		max_hp = 100.0
		points_reward = 50
		renown_reward = 45
	hp = max_hp
	_build_model()


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	if kind == Kind.DUMMY:
		_body_mat = Palette.mat(Color(0.55, 0.42, 0.3), 0.8)
		_eye_mat = Palette.glow(Palette.RED, 2.5)
		Palette.cylinder(_model, 0.55, 0.12, Vector3(0, 0.06, 0), Palette.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6), false, "Base", 16)
		Palette.cylinder(_model, 0.12, 1.0, Vector3(0, 0.6, 0), Palette.mat(Color(0.15, 0.15, 0.17), 0.5, 0.6), false, "Post", 8)
		var torso := CapsuleMesh.new()
		torso.radius = 0.36
		torso.height = 1.1
		var tm := MeshInstance3D.new()
		tm.mesh = torso
		tm.material_override = _body_mat
		tm.position = Vector3(0, 1.35, 0)
		_model.add_child(tm)
		Palette.sphere(_model, 0.26, Vector3(0, 2.0, 0), _body_mat, "Head")
		# Target rings on the chest.
		var ring_outer := Palette.cylinder(_model, 0.28, 0.02, Vector3(0, 1.4, -0.36), Palette.mat(Color(0.95, 0.95, 0.95), 0.6), false, "RingOuter", 20)
		ring_outer.rotation.x = PI * 0.5
		var ring_mid := Palette.cylinder(_model, 0.18, 0.025, Vector3(0, 1.4, -0.365), _eye_mat, false, "RingMid", 20)
		ring_mid.rotation.x = PI * 0.5
		var ring_in := Palette.cylinder(_model, 0.08, 0.03, Vector3(0, 1.4, -0.37), Palette.mat(Color(0.95, 0.95, 0.95), 0.6), false, "RingInner", 16)
		ring_in.rotation.x = PI * 0.5
		Palette.box(_model, Vector3(0.3, 0.06, 0.08), Vector3(0, 2.05, -0.22), _eye_mat, false, "Visor")
		for sx in [-0.5, 0.5]:
			Palette.box(_model, Vector3(0.14, 0.9, 0.14), Vector3(sx, 1.35, 0), _body_mat, false, "Arm")
	else:
		_body_mat = Palette.mat(Color(0.14, 0.12, 0.16), 0.45, 0.7)
		_eye_mat = Palette.glow(Palette.RED, 3.5)
		var torso := CapsuleMesh.new()
		torso.radius = 0.38
		torso.height = 1.2
		var tm := MeshInstance3D.new()
		tm.mesh = torso
		tm.material_override = _body_mat
		tm.position = Vector3(0, 1.25, 0)
		_model.add_child(tm)
		Palette.box(_model, Vector3(0.45, 0.5, 0.45), Vector3(0, 2.0, 0), _body_mat, false, "Head")
		Palette.box(_model, Vector3(0.4, 0.08, 0.1), Vector3(0, 2.05, -0.22), _eye_mat, false, "Visor")
		Palette.box(_model, Vector3(0.5, 0.04, 0.3), Vector3(0, 1.4, -0.32), Palette.glow(Palette.RED, 1.5), false, "ChestLight")
		for sx in [-0.26, 0.26]:
			Palette.box(_model, Vector3(0.22, 0.75, 0.26), Vector3(sx, 0.4, 0), _body_mat, false, "Leg")
		Palette.box(_model, Vector3(0.18, 0.9, 0.18), Vector3(-0.55, 1.3, 0), _body_mat, false, "ArmL")
		_arm = Node3D.new()
		_arm.position = Vector3(0.55, 1.7, 0)
		_model.add_child(_arm)
		Palette.box(_arm, Vector3(0.18, 0.9, 0.18), Vector3(0, -0.45, 0), _body_mat, false, "ArmR")
		Palette.box(_arm, Vector3(0.06, 1.1, 0.16), Vector3(0, -1.2, -0.2), Palette.glow(Palette.RED, 1.2), false, "Blade")
	Palette.label3d(_model, "TRAINING TARGET" if kind == Kind.DUMMY else "HUNTER UNIT", Vector3(0, 2.7, 0), Palette.RED if kind == Kind.HUNTER else Palette.AMBER, 28, 0.03)


func _now() -> float:
	return _time  # game-time clock, deterministic under fixed-FPS capture


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if kind == Kind.DUMMY:
		_process_dummy(delta)
	else:
		_process_hunter(delta)
	move_and_slide()


func _process_dummy(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < detect_range * 1.5:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 2.0 * delta)
	_model.position.y = sin(_time * 1.5) * 0.03


func _process_hunter(delta: float) -> void:
	var has_player: bool = is_instance_valid(player) and player.get("alive") != false
	var to_player := Vector3.ZERO
	var dist := INF
	if has_player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()
	var now := _now()
	var move_dir := Vector3.ZERO
	match state:
		State.IDLE:
			if now > _next_wander:
				_next_wander = now + randf_range(2.5, 5.0)
				_wander_target = _home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			var to_w := _wander_target - global_position
			to_w.y = 0.0
			if to_w.length() > 1.0:
				move_dir = to_w.normalized() * 0.45
			if has_player and dist < detect_range:
				state = State.CHASE
		State.CHASE:
			if not has_player or dist > detect_range * 1.8:
				state = State.IDLE
			elif dist <= attack_range:
				state = State.WINDUP
				_state_until = now + 0.55
				_animate_windup()
			else:
				move_dir = to_player.normalized()
		State.WINDUP:
			if now >= _state_until:
				_strike(dist)
				state = State.RECOVER
				_state_until = now + 1.1
		State.RECOVER:
			if now >= _state_until:
				state = State.CHASE
		State.STAGGER:
			if now >= _state_until:
				state = State.CHASE
	# Obstacle avoidance: if we are pushing into something, sidestep for a moment.
	if move_dir.length() > 0.1:
		if get_slide_collision_count() > 0 and Vector2(velocity.x, velocity.z).length() < 0.6 and now > _avoid_until:
			_avoid_dir = move_dir.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
			_avoid_until = now + 0.9
		if now < _avoid_until:
			move_dir = (_avoid_dir + move_dir * 0.3).normalized()
	var target := move_dir * move_speed
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	# Face player or motion.
	var face := to_player if (has_player and state != State.IDLE) else move_dir
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 8.0 * delta)
	# Leg bob.
	_model.position.y = absf(sin(_time * 9.0)) * 0.05 if Vector2(velocity.x, velocity.z).length() > 0.5 else 0.0


func _animate_windup() -> void:
	if not _arm:
		return
	var tw := create_tween()
	tw.tween_property(_arm, "rotation:x", -2.2, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_arm, "rotation:x", 0.9, 0.08)
	tw.tween_property(_arm, "rotation:x", 0.0, 0.5)
	_eye_mat.emission_energy_multiplier = 7.0
	var tw2 := create_tween()
	tw2.tween_property(_eye_mat, "emission_energy_multiplier", 3.5, 0.6)


func _strike(dist: float) -> void:
	if not is_instance_valid(player) or dist > attack_range + 0.8:
		return
	if player.has_method("take_damage"):
		player.take_damage(attack_damage, self)
	velocity += -global_transform.basis.z * 3.0


## Called by the player on a successful parry.
func stagger() -> void:
	if not alive:
		return
	state = State.STAGGER
	_state_until = _now() + 1.5
	velocity += global_transform.basis.z * 5.0
	_eye_mat.emission = Palette.CYAN
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", 0.35, 0.1)
	tw.tween_property(_model, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_callback(func() -> void: _eye_mat.emission = Palette.RED)
	_floating_text("PARRIED", Palette.CYAN, global_position + Vector3(0, 2.4, 0))


func take_damage(amount: float, hit_pos: Vector3, headshot: bool, source: Node3D = null) -> void:
	if not alive:
		return
	hp -= amount
	damaged.emit(self, amount, headshot)
	_floating_text(("%d" % int(amount)) + ("  HEADSHOT" if headshot else ""), Palette.GOLD if headshot else Color.WHITE, hit_pos + Vector3(0, 0.4, 0))
	# Hit flash.
	var tw := create_tween()
	_body_mat.emission_enabled = true
	_body_mat.emission = Palette.RED
	_body_mat.emission_energy_multiplier = 2.5
	tw.tween_property(_body_mat, "emission_energy_multiplier", 0.0, 0.25)
	if kind == Kind.HUNTER and source:
		var away := global_position - source.global_position
		away.y = 0.0
		velocity += away.normalized() * 4.0
		if state == State.IDLE:
			state = State.CHASE
	else:
		# Dummies rock on their post.
		var tw2 := create_tween()
		_model.rotation.x = -0.25
		tw2.tween_property(_model, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	velocity = Vector3.ZERO
	set_collision_layer_value(3, false)
	collision.set_deferred("disabled", true)
	defeated.emit(self)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "position:y", -0.6, 0.45)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_property(_model, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	_floating_text("+%d PTS   +%d RENOWN" % [points_reward, renown_reward], Palette.GREEN, global_position + Vector3(0, 2.6, 0))
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	global_position = _home
	rotation = Vector3.ZERO
	hp = max_hp
	state = State.IDLE
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_model.scale = Vector3(0.01, 0.01, 0.01)
	alive = true
	set_collision_layer_value(3, true)
	collision.disabled = false
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _floating_text(text: String, color: Color, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.02
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	get_tree().current_scene.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
