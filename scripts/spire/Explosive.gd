extends Node3D
class_name Explosive
## A live Engineer munition: a launcher round, a thrown grenade or a placed mine. It
## carries the weapon's model, flies (ballistic arc or straight), and detonates on impact,
## on a timer, or when an enemy steps inside its trigger radius. The effect comes from the
## weapon's "trait" (CityData.PREMIUM_WEAPONS):
##   blast       area damage with falloff              (Oathkeeper, Sunblaze, Skyfall, Cinder-Canister, Hellfire-Mine)
##   burn        burst + a burning zone that keeps ticking (Sol-Orb)
##   freeze      light damage + enemies immobilised    (Frost-Stasis)
##   concussion  damage + heavy knockback and stagger  (Scarlet-Fuse, timed)
##   implosion   drags enemies inward, then crushes    (Void-Orb)
##   shatter     huge burst, blinding flash, hurts the thrower if too close (Sunstone)

signal detonated(at: Vector3, hits: int)

const MASK_SOLID := Palette.LAYER_WORLD | Palette.LAYER_ENEMY

var weapon: Dictionary
var thrower: Node3D
var velocity := Vector3.ZERO
var gravity_scale := 1.0
var mode := "impact"            # impact | timed | proximity
var fuse := 0.0
var armed := false
var done := false

var _age := 0.0
var _model: Node3D
var _label: Label3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _resting := false


## from: world position. vel: initial velocity. Launchers pass gravity 0..1, grenades 1.
func launch(w: Dictionary, owner_node: Node3D, from: Vector3, vel: Vector3, how: String, fuse_time := 0.0, gravity := 1.0) -> void:
	weapon = w
	thrower = owner_node
	global_position = from
	velocity = vel
	mode = how
	fuse = fuse_time
	gravity_scale = gravity
	_model = WeaponModels.build_munition(w)
	add_child(_model)
	var light := OmniLight3D.new()
	light.light_color = w.get("color", Palette.AMBER)
	light.light_energy = 1.4
	light.omni_range = 3.5
	add_child(light)
	if how == "timed":
		_label = Palette.label3d(self, "", Vector3(0, 0.6, 0), w.get("color", Palette.RED), 44, 0.02)
	if how == "proximity":
		_resting = true
		get_tree().create_timer(float(w.get("arm_time", 1.0))).timeout.connect(func() -> void: armed = true)


func _physics_process(delta: float) -> void:
	if done:
		return
	_age += delta
	if mode == "proximity":
		if armed:
			for e: Node3D in _enemies():
				if e.global_position.distance_to(global_position) <= float(weapon.get("trigger_radius", 2.6)):
					detonate()
					return
		return
	if mode == "timed":
		var left := fuse - _age
		if _label:
			_label.text = "%d" % int(ceil(maxf(left, 0.0)))
		if left <= 0.0:
			detonate()
			return
	if _resting:
		return
	velocity.y -= _gravity * gravity_scale * delta
	var step := velocity * delta
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if thrower is CollisionObject3D:
		exclude.append((thrower as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, MASK_SOLID, exclude)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position += step
		if _model:
			_model.rotate_x(delta * 7.0)
			_model.rotate_y(delta * 3.0)
		if _age > 8.0 or global_position.y < -20.0:
			detonate()
		return
	global_position = hit["position"] + (hit["normal"] as Vector3) * 0.08
	if mode == "impact":
		detonate()
	else:
		# timed grenades bounce once or twice, then lie still until the fuse runs out
		var n: Vector3 = hit["normal"]
		velocity = velocity.bounce(n) * 0.32
		if velocity.length() < 1.6:
			_resting = true
			velocity = Vector3.ZERO


func _enemies() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.has_method("take_damage") and e.get("alive") != false:
			out.append(e)
	return out


func _roll() -> float:
	return randf_range(float(weapon["damage_min"]), float(weapon["damage_max"]))


func _hurt(e: Node3D, amount: float) -> void:
	e.take_damage(amount, e.global_position + Vector3(0, 1.3, 0), false, thrower)
	if is_instance_valid(thrower) and thrower.has_signal("hit_landed"):
		thrower.emit_signal("hit_landed", e, amount, false)


## Damage every enemy within radius: full at the centre, `edge` of it at the rim.
func _area_damage(radius: float, amount: float, edge := 0.5) -> int:
	var hits := 0
	for e: Node3D in _enemies():
		var d: float = e.global_position.distance_to(global_position)
		if d <= radius:
			_hurt(e, amount * lerpf(1.0, edge, clampf(d / radius, 0.0, 1.0)))
			hits += 1
	return hits


func detonate() -> void:
	if done:
		return
	done = true
	var at := global_position
	var radius: float = float(weapon.get("radius", 4.0))
	var color: Color = weapon.get("color", Palette.AMBER)
	var hits := 0
	match str(weapon.get("trait", "blast")):
		"burn":
			hits = _area_damage(radius, _roll() * 0.45)
			_burn_zone(at, radius, color)
		"freeze":
			hits = _area_damage(radius, _roll(), 0.8)
			for e: Node3D in _enemies():
				if e.global_position.distance_to(at) <= radius and e.has_method("freeze"):
					e.freeze(float(weapon.get("freeze_time", 3.5)))
		"concussion":
			var dmg := _roll()
			for e: Node3D in _enemies():
				var d: float = e.global_position.distance_to(at)
				if d <= radius:
					_hurt(e, dmg * lerpf(1.0, 0.6, d / radius))
					hits += 1
					var away: Vector3 = e.global_position - at
					away.y = 0.0
					if e is CharacterBody3D:
						(e as CharacterBody3D).velocity += away.normalized() * 13.0 + Vector3.UP * 4.0
					if e.has_method("stagger"):
						e.stagger("CONCUSSED")
		"implosion":
			_implode(at, radius, color)
			if _model:
				_model.visible = false
			return
		"shatter":
			hits = _area_damage(radius, _roll(), 0.6)
			if is_instance_valid(thrower) and thrower.global_position.distance_to(at) <= radius * 0.5 and thrower.has_method("take_damage"):
				thrower.take_damage(_roll() * 0.4, null)
			if is_instance_valid(thrower) and thrower.has_signal("flash_requested") and thrower.global_position.distance_to(at) <= radius * 2.5:
				thrower.emit_signal("flash_requested", 0.9)
		_:
			hits = _area_damage(radius, _roll())
	_blast_visual(at, radius, color)
	_finish(at, hits, true)


func _finish(at: Vector3, hits: int, free_now: bool) -> void:
	detonated.emit(at, hits)
	if _model:
		_model.visible = false
	if _label:
		_label.visible = false
	if free_now:
		queue_free()


# ------------------------------------------------------------------ effects
func _blast_visual(at: Vector3, radius: float, color: Color) -> void:
	var scene := get_tree().current_scene
	var ball := Palette.sphere(scene, 1.0, Vector3.ZERO, Palette.translucent_glow(color, 0.55, 3.2), "Blast")
	ball.global_position = at
	ball.scale = Vector3(0.2, 0.2, 0.2)
	var tw := ball.create_tween()
	tw.tween_property(ball, "scale", Vector3(radius, radius, radius), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ball, "transparency", 1.0, 0.32)
	tw.tween_callback(ball.queue_free)
	var ring := Palette.cylinder(scene, 1.0, 0.05, Vector3.ZERO, Palette.translucent_glow(color, 0.5, 2.6), false, "Shockwave", 32)
	ring.global_position = at + Vector3(0, 0.15, 0)
	ring.scale = Vector3(0.3, 1.0, 0.3)
	var tw2 := ring.create_tween()
	tw2.tween_property(ring, "scale", Vector3(radius * 1.25, 1.0, radius * 1.25), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(ring, "transparency", 1.0, 0.4)
	tw2.tween_callback(ring.queue_free)
	var light := Palette.omni(scene, Vector3.ZERO, color, 8.0, radius * 2.5)
	light.global_position = at + Vector3(0, 1.0, 0)
	var tw3 := light.create_tween()
	tw3.tween_property(light, "light_energy", 0.0, 0.4)
	tw3.tween_callback(light.queue_free)


## Sol-Orb: embers keep burning where it burst.
func _burn_zone(at: Vector3, radius: float, color: Color) -> void:
	var scene := get_tree().current_scene
	var zone := Palette.cylinder(scene, radius, 0.06, Vector3.ZERO, Palette.translucent_glow(color, 0.3, 2.0), false, "BurnZone", 32)
	zone.global_position = at + Vector3(0, 0.1, 0)
	var ticks := 6
	var per_tick := _roll() * 0.55 / ticks
	var who := thrower
	var tree := get_tree()
	for i in range(ticks):
		tree.create_timer(0.6 * (i + 1)).timeout.connect(func() -> void:
			if not is_instance_valid(zone):
				return
			for e in tree.get_nodes_in_group("enemy"):
				if e is Node3D and e.has_method("take_damage") and e.get("alive") != false and (e as Node3D).global_position.distance_to(at) <= radius:
					e.take_damage(per_tick, (e as Node3D).global_position + Vector3(0, 1.6, 0), false, who)
					if e.has_method("_floating_text"):
						e._floating_text("BURN", color, (e as Node3D).global_position + Vector3(0, 2.2, 0)))
	var tw := zone.create_tween()
	tw.tween_interval(0.6 * ticks)
	tw.tween_property(zone, "transparency", 1.0, 0.5)
	tw.tween_callback(zone.queue_free)


## Void-Orb: a dark field drags enemies to the centre, then collapses on them.
func _implode(at: Vector3, radius: float, color: Color) -> void:
	var scene := get_tree().current_scene
	var field := Palette.sphere(scene, 1.0, Vector3.ZERO, Palette.translucent_glow(color, 0.4, 2.0), "VoidField")
	field.global_position = at + Vector3(0, 0.8, 0)
	field.scale = Vector3(radius, radius, radius)
	var pull_time := 0.75
	var tw := field.create_tween()
	tw.tween_property(field, "scale", Vector3(0.4, 0.4, 0.4), pull_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for e: Node3D in _enemies():
		if e.global_position.distance_to(at) <= radius:
			var target: Vector3 = at + (e.global_position - at).normalized() * 1.0
			target.y = e.global_position.y
			var te: Tween = e.create_tween()
			te.tween_property(e, "global_position", target, pull_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			if e.has_method("stagger"):
				e.stagger("PULLED")
	tw.tween_callback(func() -> void:
		var hits := _area_damage(radius * 0.45, _roll(), 0.85)
		_blast_visual(at, radius * 0.5, color)
		field.queue_free()
		detonated.emit(at, hits)
		queue_free())
