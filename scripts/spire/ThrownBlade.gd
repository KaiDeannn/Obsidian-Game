extends Node3D
class_name ThrownBlade
## A thrown premium weapon (shuriken, tri-blade, razor) in flight. Spins forward, hits
## enemies it overlaps, and depending on the weapon's trait: pierces through several
## targets (The Ruin), burns (Ember-Scythe), ricochets to a second enemy (Golden Razor)
## or flies back to the thrower and can hit on the way home (The Crescent).

signal returned
signal hit(target: Node3D, damage: float)

var weapon: Dictionary
var thrower: Node3D
var direction := Vector3.FORWARD
var speed := 26.0
var max_range := 24.0
var pierce := 1
var returns := false
var ricochets := false
var burn := false

var _travelled := 0.0
var _returning := false
var _hits: Array[Node3D] = []
var _area: Area3D
var _spin := 0.0
var _done := false


func launch(w: Dictionary, from: Node3D, dir: Vector3) -> void:
	weapon = w
	thrower = from
	direction = dir.normalized()
	var trait_id := str(w.get("trait", ""))
	pierce = 3 if trait_id == "unbroken" else 1
	returns = trait_id == "returns"
	ricochets = trait_id == "razor"
	burn = trait_id == "burning"
	speed = 34.0 if trait_id == "razor" else 26.0
	add_child(WeaponModels.build(w))
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Palette.LAYER_ENEMY
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	cs.shape = sphere
	_area.add_child(cs)
	add_child(_area)
	var light := OmniLight3D.new()
	light.light_color = w.get("color", Palette.CYAN)
	light.light_energy = 1.6
	light.omni_range = 3.0
	add_child(light)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_spin += delta * 18.0
	rotation.y = _spin
	var step := speed * delta
	if _returning:
		if not is_instance_valid(thrower):
			_finish()
			return
		var home := thrower.global_position + Vector3(0, 1.2, 0)
		var to := home - global_position
		if to.length() <= step + 0.3:
			_finish()
			return
		direction = to.normalized()
	global_position += direction * step
	_travelled += step
	for body in _area.get_overlapping_bodies():
		if body in _hits or not body.has_method("take_damage"):
			continue
		_hits.append(body)
		var dmg := randf_range(float(weapon["damage_min"]), float(weapon["damage_max"]))
		body.take_damage(dmg, body.global_position + Vector3(0, 1.3, 0), false, thrower)
		hit.emit(body, dmg)
		if burn and body.has_method("take_damage"):
			_apply_burn(body)
		if ricochets:
			ricochets = false
			var next := _nearest_enemy(body, 7.0)
			if next:
				direction = (next.global_position + Vector3(0, 1.2, 0) - global_position).normalized()
				_travelled = 0.0
				continue
		if _hits.size() >= pierce and not _returning:
			if returns:
				_returning = true
				_hits.clear()
			else:
				_finish()
			return
	if _travelled >= max_range and not _returning:
		if returns:
			_returning = true
			_hits.clear()
		else:
			_finish()


func _nearest_enemy(exclude: Node3D, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == exclude or not (e is Node3D) or e in _hits:
			continue
		if e.get("alive") == false:
			continue
		var d := (e as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _apply_burn(target: Node3D) -> void:
	var ticks := 3
	var tick_dmg := 8.0
	var t := get_tree()
	for i in range(ticks):
		t.create_timer(0.8 * (i + 1)).timeout.connect(func() -> void:
			if is_instance_valid(target) and target.get("alive") != false and target.has_method("take_damage"):
				target.take_damage(tick_dmg, target.global_position + Vector3(0, 1.6, 0), false, thrower)
				if target.has_method("_floating_text"):
					target._floating_text("BURN", Palette.AMBER, target.global_position + Vector3(0, 2.2, 0)))


func _finish() -> void:
	if _done:
		return
	_done = true
	returned.emit()
	queue_free()
