extends TrainingDummy
class_name BattleFighter
## An AI combatant in a match: one of the six classes from the design document, on the
## enemy or ally team. Melee classes (Swordsman, Ninja) reuse the hunter chase / wind-up /
## strike loop against the nearest opposing fighter; ranged classes (Sniper, Archer,
## Assault) hold a distance band and fire line-of-sight shots; the Engineer lobs charges
## that explode where the target stands. Fighters report their weapon category so the
## tactical mini-map can colour their dot (document: Vision System), die without
## respawning unless the match says otherwise, and remember who downed them.

var fighter_class := "Swordsman"
var team := "enemy"            # "enemy" or "ally"
var fighter_name := ""
var weapon_category := "melee"
var rank := "D"
var respawns := false
var target: Node3D
var kills := 0
var last_attacker: Node3D

var _ranged := false
var _explosive := false
var _shot_damage := 20.0
var _fire_interval := 1.5
var _keep_min := 8.0
var _keep_max := 16.0
var _fire_range := 22.0
var _next_fire := 0.0
var _prop: Node3D
var _team_color: Color = Palette.RED


## Call before adding to the tree. data: {"name", "class", "team", "rank", "weapon"}.
func setup(data: Dictionary) -> void:
	fighter_name = str(data.get("name", "Fighter"))
	fighter_class = str(data.get("class", "Swordsman"))
	team = str(data.get("team", "enemy"))
	rank = str(data.get("rank", "D"))
	weapon_category = str(data.get("weapon", BattleData.class_info(fighter_class)["weapon"]))
	kind = Kind.HUNTER
	match fighter_class:
		"Swordsman":
			attack_damage = 14.0
			attack_range = 2.4
			move_speed = 4.6
		"Ninja":
			attack_damage = 11.0
			attack_range = 2.2
			move_speed = 5.8
		"Sniper":
			_ranged = true
			_shot_damage = 34.0
			_fire_interval = 2.4
			_keep_min = 16.0
			_keep_max = 30.0
			_fire_range = 34.0
			move_speed = 3.8
		"Archer":
			_ranged = true
			_shot_damage = 17.0
			_fire_interval = 1.2
			_keep_min = 9.0
			_keep_max = 20.0
			_fire_range = 24.0
			move_speed = 4.4
		"Assault":
			_ranged = true
			_shot_damage = 8.0
			_fire_interval = 0.38
			_keep_min = 5.0
			_keep_max = 13.0
			_fire_range = 18.0
			move_speed = 4.8
		"Engineer":
			_ranged = true
			_explosive = true
			_shot_damage = 22.0
			_fire_interval = 2.6
			_keep_min = 8.0
			_keep_max = 16.0
			_fire_range = 20.0
			move_speed = 4.0
	detect_range = 60.0


func _ready() -> void:
	super._ready()
	# Rank scales toughness: D 120 hp, C 145, B 170 ...
	max_hp = 120.0 + 25.0 * RankManager.rank_index_of(rank)
	hp = max_hp
	points_reward = 10
	renown_reward = 5
	if team == "ally":
		remove_from_group("enemy")
		add_to_group("ally")
		collision_layer = Palette.LAYER_PLAYER      # the player's blade ignores teammates
	_tint_for_team()


func _tint_for_team() -> void:
	_team_color = UIKit.ACCENT if team == "ally" else Palette.RED
	_eye_mat.emission = _team_color
	_body_mat.albedo_color = Color(0.12, 0.16, 0.22) if team == "ally" else Color(0.18, 0.1, 0.12)
	_prop = Node3D.new()
	_prop.name = "ClassProp"
	_model.add_child(_prop)
	var glow := Palette.glow(BattleData.WEAPON_COLORS.get(weapon_category, Palette.RED), 1.8)
	match fighter_class:
		"Sniper", "Assault":
			var r := Palette.box(_prop, Vector3(0.08, 0.1, 1.3 if fighter_class == "Sniper" else 0.9), Vector3(0.5, 1.25, -0.5), Palette.mat(Color(0.12, 0.12, 0.14), 0.3, 0.8), false, "Rifle")
			Palette.box(r, Vector3(0.1, 0.02, 1.0 if fighter_class == "Sniper" else 0.7), Vector3(0, -0.06, 0), glow, false, "Rail")
		"Archer":
			var bow := Palette.box(_prop, Vector3(0.05, 1.4, 0.08), Vector3(-0.55, 1.3, -0.1), Palette.mat(Color(0.35, 0.22, 0.12), 0.8), false, "Bow")
			Palette.box(bow, Vector3(0.015, 1.3, 0.015), Vector3(0, 0, 0.14), glow, false, "String")
		"Engineer":
			Palette.box(_prop, Vector3(0.5, 0.35, 0.3), Vector3(0, 1.0, 0.45), Palette.mat(Color(0.25, 0.27, 0.3), 0.5, 0.6), false, "Pack")
			Palette.sphere(_prop, 0.12, Vector3(0.3, 1.2, 0.45), glow, "Charge")
		"Ninja":
			for sx in [-0.5, 0.5]:
				var b := Palette.box(_prop, Vector3(0.05, 0.03, 0.5), Vector3(sx, 1.1, -0.2), Palette.mat(Color(0.1, 0.1, 0.12), 0.2, 0.9), false, "Blade")
				Palette.box(b, Vector3(0.015, 0.035, 0.45), Vector3.ZERO, glow, false, "Edge")


func _physics_process(delta: float) -> void:
	if not alive:
		return
	target = _pick_target()
	player = target           # the inherited hunter loop chases / strikes `player`
	if _ranged:
		_time += delta
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		_process_ranged(delta)
		move_and_slide()
	else:
		super._physics_process(delta)


func _pick_target() -> Node3D:
	var candidates: Array = []
	if team == "enemy":
		for p in get_tree().get_nodes_in_group("players"):
			candidates.append(p)
		for a in get_tree().get_nodes_in_group("ally"):
			candidates.append(a)
	else:
		for e in get_tree().get_nodes_in_group("enemy"):
			candidates.append(e)
	var best: Node3D = null
	var best_d := INF
	for c in candidates:
		if not (c is Node3D) or c == self or c.get("alive") == false:
			continue
		var d := (c as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _process_ranged(delta: float) -> void:
	var move_dir := Vector3.ZERO
	if is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
		if dist > _keep_max:
			move_dir = dir
		elif dist < _keep_min:
			move_dir = -dir
		else:
			# strafe a little so the fighter is not a static target
			move_dir = dir.cross(Vector3.UP) * sin(_time * 0.7) * 0.5
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
		if dist <= _fire_range and _time >= _next_fire and _has_los(target):
			_next_fire = _time + _fire_interval
			_fire(target)
	if state == State.STAGGER:
		move_dir = Vector3.ZERO
		if _time >= _state_until:
			state = State.IDLE
	var want := move_dir * move_speed
	velocity.x = move_toward(velocity.x, want.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 14.0 * delta)
	_model.position.y = absf(sin(_time * 9.0)) * 0.05 if Vector2(velocity.x, velocity.z).length() > 0.5 else 0.0


func _has_los(t: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), t.global_position + Vector3(0, 1.2, 0), Palette.LAYER_WORLD)
	return space.intersect_ray(q).is_empty()


func _fire(t: Node3D) -> void:
	var from := global_position + Vector3(0, 1.5, 0)
	if _explosive:
		var at := t.global_position
		var charge := Palette.sphere(get_tree().current_scene, 0.18, Vector3.ZERO, Palette.glow(BattleData.WEAPON_COLORS["explosive"], 3.0), "Charge")
		charge.global_position = from
		var tw := charge.create_tween()
		tw.tween_property(charge, "global_position", at + Vector3(0, 0.2, 0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			var blast := Palette.sphere(get_tree().current_scene, 1.0, Vector3.ZERO, Palette.translucent_glow(BattleData.WEAPON_COLORS["explosive"], 0.5, 3.0), "Blast")
			blast.global_position = at + Vector3(0, 0.6, 0)
			blast.scale = Vector3(0.3, 0.3, 0.3)
			var tw2 := blast.create_tween()
			tw2.tween_property(blast, "scale", Vector3(3.2, 3.2, 3.2), 0.25)
			tw2.parallel().tween_property(blast, "transparency", 1.0, 0.3)
			tw2.tween_callback(blast.queue_free)
			for v in _victims():
				if v.global_position.distance_to(at) <= 3.2:
					_hurt(v, _shot_damage)
			charge.queue_free())
		return
	# hitscan with a little spread; Snipers are accurate, Assault sprays
	var spread := 0.01 if fighter_class == "Sniper" else (0.06 if fighter_class == "Assault" else 0.03)
	var dir := (t.global_position + Vector3(0, 1.2, 0) - from).normalized()
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread)).rotated(Vector3.RIGHT, randf_range(-spread, spread))
	var end := from + dir * _fire_range
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, end, Palette.LAYER_WORLD | Palette.LAYER_PLAYER | Palette.LAYER_ENEMY, [get_rid()])
	var hit := space.intersect_ray(q)
	var impact := end
	if not hit.is_empty():
		impact = hit["position"]
		var col: Object = hit["collider"]
		if col is Node3D and col != self and col.has_method("take_damage") and _is_opponent(col):
			_hurt(col, _shot_damage)
	_tracer(from, impact)


func _victims() -> Array:
	var out: Array = []
	if team == "enemy":
		for p in get_tree().get_nodes_in_group("players"):
			out.append(p)
		for a in get_tree().get_nodes_in_group("ally"):
			out.append(a)
	else:
		for e in get_tree().get_nodes_in_group("enemy"):
			out.append(e)
	return out


func _is_opponent(n: Node) -> bool:
	if team == "enemy":
		return n.is_in_group("players") or n.is_in_group("ally")
	return n.is_in_group("enemy")


## Damage either kind of target: the player (amount, source) or another fighter.
func _hurt(t: Node3D, amount: float) -> void:
	if t is SpirePlayer:
		t.take_damage(amount, self)
	elif t.has_method("take_damage"):
		t.take_damage(amount, t.global_position + Vector3(0, 1.3, 0), false, self)


func _strike(dist: float) -> void:
	if not is_instance_valid(target) or dist > attack_range + 0.8:
		return
	_hurt(target, attack_damage)
	velocity += -global_transform.basis.z * 3.0


func _tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = 0.015
	mesh.height = length
	mesh.radial_segments = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := Palette.translucent_glow(BattleData.WEAPON_COLORS.get(weapon_category, Palette.AMBER), 0.8, 3.0)
	mi.material_override = m
	get_tree().current_scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.look_at(to, up)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)


func take_damage(amount: float, hit_pos: Vector3, headshot: bool, source: Node3D = null) -> void:
	if source:
		last_attacker = source
	super.take_damage(amount, hit_pos, headshot, source)


func _die() -> void:
	alive = false
	velocity = Vector3.ZERO
	set_collision_layer_value(3, false)
	set_collision_layer_value(2, false)
	collision.set_deferred("disabled", true)
	if last_attacker is BattleFighter:
		(last_attacker as BattleFighter).kills += 1
	defeated.emit(self)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "position:y", -0.6, 0.45)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_property(_model, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	_floating_text("DOWNED", _team_color, global_position + Vector3(0, 2.6, 0))
	if respawns:
		get_tree().create_timer(respawn_time).timeout.connect(revive)


## Bring the fighter back at full health (new round / clan war respawn / solo restart).
func revive(at: Vector3 = Vector3.INF) -> void:
	if not is_inside_tree():
		return
	if at != Vector3.INF:
		_home = at
	global_position = _home
	rotation = Vector3.ZERO
	hp = max_hp
	state = State.IDLE
	last_attacker = null
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_model.scale = Vector3(0.01, 0.01, 0.01)
	alive = true
	if team == "ally":
		set_collision_layer_value(2, true)
	else:
		set_collision_layer_value(3, true)
	collision.disabled = false
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
