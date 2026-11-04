extends Node
## Cinematic (autoload "Cinematic"). Data-driven camera sequences that any scene can play:
##   Cinematic.play(shots, {"resolve": Callable})   or   Cinematic.play_named("city_intro", opts)
## A shot is a Dictionary (see CinematicData for the catalogue):
##   {"type": "fly",   "from": {"pos", "look"}, "to": {"pos", "look"}, "duration", "ease", "fov", "title", "subtitle"}
##   {"type": "orbit", "center", "radius", "height", "from_angle", "to_angle", "duration", ...}
##   {"type": "track", "node": NodePath|Node3D, "offset", "look_offset", "duration", ...}   follows a moving node
##   {"type": "hold",  "duration", "title", "subtitle"}                                     keeps the last camera
## Any "pos"/"look"/"center" may be a String key instead of a Vector3; the caller's "resolve"
## Callable turns it into a live position (e.g. "player_back"), so sequences stay reusable
## across scenes. Letterbox bars, titles, fade and a Space/Esc skip are built in. The camera
## is a temporary Camera3D; the previously current camera is restored when the sequence ends.

signal started(name: String)
signal shot_started(index: int, shot: Dictionary)
signal finished(name: String, skipped: bool)

const SKIP_ACTIONS := ["ui_accept", "ui_cancel", "jump"]

var is_playing := false
var current_name := ""

var _cam: Camera3D
var _prev_cam: Camera3D
var _layer: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _title: Label
var _subtitle: Label
var _skip_hint: Label
var _fade: ColorRect
var _skip_requested := false
var _resolve: Callable
var _shot_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


# ------------------------------------------------------------------ public API
func play_named(sequence_name: String, opts: Dictionary = {}) -> void:
	var shots: Array = CinematicData.SEQUENCES.get(sequence_name, [])
	if shots.is_empty():
		push_warning("Cinematic: unknown sequence %s" % sequence_name)
		return
	await play(shots, opts, sequence_name)


## Plays a list of shots. opts: "resolve" (Callable(String) -> Dictionary {"pos","look"} or Vector3),
## "fade_in" (bool, default true), "fade_out" (bool, default true), "skippable" (default true),
## "letterbox" (default true).
func play(shots: Array, opts: Dictionary = {}, sequence_name := "custom") -> void:
	if is_playing:
		return
	is_playing = true
	current_name = sequence_name
	_skip_requested = false
	_resolve = opts.get("resolve", Callable())
	var skippable: bool = opts.get("skippable", true)
	var scene := get_tree().current_scene
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "CinematicCamera"
	_cam.far = 900.0
	scene.add_child(_cam)
	_cam.current = true
	_skip_hint.visible = skippable
	_set_letterbox(opts.get("letterbox", true))
	started.emit(sequence_name)
	if opts.get("fade_in", true):
		_fade.color.a = 1.0
		_fade.visible = true
	var i := 0
	for shot in shots:
		if _skip_requested:
			break
		shot_started.emit(i, shot)
		await _run_shot(shot, i == 0 and opts.get("fade_in", true))
		i += 1
	if _skip_requested or opts.get("fade_out", true):
		await _fade_to(1.0, 0.35 if _skip_requested else 0.6)
	_set_letterbox(false)
	_show_text("", "")
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	is_playing = false
	current_name = ""
	var skipped := _skip_requested
	finished.emit(sequence_name, skipped)
	# reveal in the background so callers resume the moment the sequence ends
	_reveal()


func _reveal() -> void:
	await get_tree().process_frame
	if is_playing:
		return          # another sequence took over; it owns the fade now
	await _fade_to(0.0, 0.5)
	if not is_playing:
		_fade.visible = false


func skip() -> void:
	if is_playing:
		_skip_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or not _skip_hint.visible:
		return
	for a in SKIP_ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			skip()
			get_viewport().set_input_as_handled()
			return


# ------------------------------------------------------------------ shots
func _run_shot(shot: Dictionary, first: bool) -> void:
	var duration: float = float(shot.get("duration", 4.0))
	_cam.fov = float(shot.get("fov", 62.0))
	_show_text(str(shot.get("title", "")), str(shot.get("subtitle", "")))
	match str(shot.get("type", "fly")):
		"fly":
			var a := _resolve_point(shot["from"])
			var b := _resolve_point(shot["to"])
			_place(a)
			if first:
				_fade_to(0.0, 1.0)
			await _tween_between(a, b, duration, str(shot.get("ease", "in_out")))
		"orbit":
			var center := _resolve_vec(shot["center"])
			var r: float = float(shot.get("radius", 30.0))
			var h: float = float(shot.get("height", 15.0))
			var a0: float = deg_to_rad(float(shot.get("from_angle", 0.0)))
			var a1: float = deg_to_rad(float(shot.get("to_angle", 120.0)))
			var look_h: float = float(shot.get("look_height", 4.0))
			var state := {"t": 0.0}
			_place({"pos": center + Vector3(cos(a0) * r, h, sin(a0) * r), "look": center + Vector3(0, look_h, 0)})
			if first:
				_fade_to(0.0, 1.0)
			_shot_tween = create_tween()
			_shot_tween.tween_method(func(t: float) -> void:
				var ang := lerpf(a0, a1, t)
				_place({"pos": center + Vector3(cos(ang) * r, h, sin(ang) * r), "look": center + Vector3(0, look_h, 0)}), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await _wait_tween(_shot_tween)
			state["t"] = 1.0
		"track":
			var node: Node3D = _resolve_node(shot["node"])
			var offset: Vector3 = shot.get("offset", Vector3(0, 3, 6))
			var look_offset: Vector3 = shot.get("look_offset", Vector3(0, 1.2, 0))
			var elapsed := 0.0
			while elapsed < duration and not _skip_requested and is_instance_valid(node):
				var dt := get_process_delta_time()
				elapsed += dt
				var want := node.global_position + node.global_transform.basis * offset
				_cam.global_position = _cam.global_position.lerp(want, 1.0 - exp(-dt * 4.0))
				_cam.look_at(node.global_position + look_offset, Vector3.UP)
				await get_tree().process_frame
		"hold":
			if first:
				_fade_to(0.0, 1.0)
			await _wait(duration)
	var hold: float = float(shot.get("hold", 0.0))
	if hold > 0.0 and not _skip_requested:
		await _wait(hold)


func _tween_between(a: Dictionary, b: Dictionary, duration: float, ease_name: String) -> void:
	_shot_tween = create_tween()
	var trans := Tween.TRANS_SINE
	var ease := Tween.EASE_IN_OUT
	match ease_name:
		"linear":
			trans = Tween.TRANS_LINEAR
		"out":
			ease = Tween.EASE_OUT
		"in":
			ease = Tween.EASE_IN
	_shot_tween.tween_method(func(t: float) -> void:
		_place({"pos": (a["pos"] as Vector3).lerp(b["pos"], t), "look": (a["look"] as Vector3).lerp(b["look"], t)}), 0.0, 1.0, duration).set_trans(trans).set_ease(ease)
	await _wait_tween(_shot_tween)


## Waits for a shot tween, but returns at once when the sequence is skipped (a killed
## tween never emits `finished`, so polling is the only safe way).
func _wait_tween(tw: Tween) -> void:
	while is_instance_valid(tw) and tw.is_valid() and tw.is_running() and not _skip_requested:
		await get_tree().process_frame
	if is_instance_valid(tw) and tw.is_valid():
		tw.kill()


func _place(p: Dictionary) -> void:
	if not is_instance_valid(_cam):
		return
	_cam.global_position = p["pos"]
	var look: Vector3 = p["look"]
	if look.distance_to(_cam.global_position) > 0.01:
		_cam.look_at(look, Vector3.UP)


func _resolve_point(v: Variant) -> Dictionary:
	if v is Dictionary:
		return {"pos": _resolve_vec(v["pos"]), "look": _resolve_vec(v["look"])}
	if v is String and _resolve.is_valid():
		var r: Variant = _resolve.call(v)
		if r is Dictionary:
			return r
	push_warning("Cinematic: cannot resolve point %s" % str(v))
	return {"pos": Vector3.ZERO, "look": Vector3.FORWARD}


func _resolve_vec(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is String and _resolve.is_valid():
		var r: Variant = _resolve.call(v)
		if r is Vector3:
			return r
		if r is Dictionary:
			return r["pos"]
	return Vector3.ZERO


func _resolve_node(v: Variant) -> Node3D:
	if v is Node3D:
		return v
	if v is String and _resolve.is_valid():
		var r: Variant = _resolve.call(v)
		if r is Node3D:
			return r
	if v is NodePath or v is String:
		return get_tree().current_scene.get_node_or_null(NodePath(str(v))) as Node3D
	return null


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip_requested:
		t += get_process_delta_time()
		await get_tree().process_frame


# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_top)
	_bar_top.anchor_right = 1.0
	_bar_top.offset_bottom = 0
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_bottom)
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.offset_top = 0
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(text_box)
	text_box.anchor_left = 0.0
	text_box.anchor_right = 1.0
	text_box.anchor_top = 1.0
	text_box.anchor_bottom = 1.0
	text_box.offset_top = -210
	text_box.offset_bottom = -120
	text_box.offset_left = 80
	text_box.offset_right = -80
	_title = UIKit.label("", 52, UIKit.TEXT)
	_title.modulate.a = 0.0
	text_box.add_child(_title)
	_subtitle = UIKit.label("", 18, UIKit.TEXT_DIM)
	_subtitle.modulate.a = 0.0
	text_box.add_child(_subtitle)
	_skip_hint = UIKit.label("SPACE  skip", 12, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_skip_hint.visible = false
	_layer.add_child(_skip_hint)
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -200
	_skip_hint.offset_right = -24
	_skip_hint.offset_top = -40
	_skip_hint.offset_bottom = -16
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	UIKit.full_rect(_fade)


func _set_letterbox(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	var h := 86.0 if on else 0.0
	tw.tween_property(_bar_top, "offset_bottom", h, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar_bottom, "offset_top", -h, 0.5).set_trans(Tween.TRANS_SINE)


func _show_text(title: String, subtitle: String) -> void:
	var tw := create_tween().set_parallel(true)
	if title == "" and subtitle == "":
		tw.tween_property(_title, "modulate:a", 0.0, 0.4)
		tw.tween_property(_subtitle, "modulate:a", 0.0, 0.4)
		return
	_title.text = title
	_subtitle.text = subtitle
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	tw.tween_property(_title, "modulate:a", 1.0, 0.7).set_delay(0.2)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 0.7).set_delay(0.5)


func _fade_to(a: float, dur: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, dur)
	await tw.finished
