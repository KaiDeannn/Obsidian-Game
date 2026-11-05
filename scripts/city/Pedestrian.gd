extends Node3D
class_name Pedestrian
## Street-level walking NPC: a simple code-built figure that follows a closed loop along
## the pavement at walking pace with a leg swing. Visual only (no collision), so it never
## interferes with driving, the valet or job triggers.

var speed := 1.4
var _loop := PackedVector3Array()
var _index := 0
var _phase := 0.0
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func setup(loop: PackedVector3Array, walk_speed: float, start_t: float, seed_value: int) -> void:
	_loop = loop
	speed = walk_speed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build(rng)
	# start somewhere along the loop
	_index = rng.randi_range(0, loop.size() - 1)
	var a := loop[_index]
	var b := loop[(_index + 1) % loop.size()]
	global_position = a.lerp(b, start_t)
	_index = (_index + 1) % loop.size()


func _build(rng: RandomNumberGenerator) -> void:
	var skins := [Color(0.85, 0.7, 0.58), Color(0.62, 0.45, 0.32), Color(0.45, 0.3, 0.2), Color(0.92, 0.8, 0.7)]
	var tops := [Color(0.92, 0.92, 0.9), Color(0.15, 0.2, 0.35), Color(0.55, 0.6, 0.68), Color(0.8, 0.3, 0.3), Color(0.2, 0.45, 0.4), Color(0.1, 0.1, 0.12)]
	var bottoms := [Color(0.15, 0.17, 0.22), Color(0.4, 0.42, 0.48), Color(0.25, 0.3, 0.45), Color(0.85, 0.85, 0.82)]
	var skin := Palette.pbr(skins[rng.randi_range(0, skins.size() - 1)], 0.85, 0.0)
	var top := Palette.pbr(tops[rng.randi_range(0, tops.size() - 1)], 0.8, 0.0)
	var bottom := Palette.pbr(bottoms[rng.randi_range(0, bottoms.size() - 1)], 0.8, 0.0)
	var h := rng.randf_range(0.92, 1.06)
	scale = Vector3(h, h, h)
	var torso := CapsuleMesh.new()
	torso.radius = 0.2
	torso.height = 0.75
	var tm := MeshInstance3D.new()
	tm.mesh = torso
	tm.material_override = top
	tm.position = Vector3(0, 1.12, 0)
	add_child(tm)
	Palette.sphere(self, 0.14, Vector3(0, 1.66, 0), skin, "Head")
	Palette.box(self, Vector3(0.3, 0.06, 0.3), Vector3(0, 1.74, 0), Palette.pbr(Color(0.15, 0.12, 0.1), 0.9, 0.0), false, "Hair")
	for sx in [-0.11, 0.11]:
		var leg := Node3D.new()
		leg.position = Vector3(sx, 0.8, 0)
		add_child(leg)
		Palette.box(leg, Vector3(0.14, 0.8, 0.16), Vector3(0, -0.4, 0), bottom, false, "Leg")
		Palette.box(leg, Vector3(0.15, 0.08, 0.26), Vector3(0, -0.82, 0.05), Palette.pbr(Color(0.1, 0.1, 0.1), 0.7, 0.0), false, "Shoe")
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(sx * 2.4, 1.4, 0)
		add_child(arm)
		Palette.box(arm, Vector3(0.1, 0.62, 0.12), Vector3(0, -0.31, 0), top, false, "Arm")
		Palette.sphere(arm, 0.06, Vector3(0, -0.65, 0), skin, "Hand")
		_arms.append(arm)


func _process(delta: float) -> void:
	if _loop.size() < 2:
		return
	var target := _loop[_index]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		_index = (_index + 1) % _loop.size()
		return
	var dir := to.normalized()
	global_position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 6.0 * delta)
	_phase += delta * speed * 4.2
	for k in range(_legs.size()):
		var s := 1.0 if k == 0 else -1.0
		_legs[k].rotation.x = sin(_phase) * 0.55 * s
		_arms[k].rotation.x = -sin(_phase) * 0.45 * s
