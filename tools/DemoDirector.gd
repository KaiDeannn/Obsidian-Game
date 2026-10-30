extends Node
## DemoDirector — scripted ~60 s client preview that walks through every feature of the
## prototype with on-screen captions. Designed for Godot's Movie Maker mode:
##   godot --path . --write-movie preview/obsidian_preview.avi --fixed-fps 30 \
##         --resolution 1920x1080 res://tools/DemoPreview.tscn
## Everything is driven through the real gameplay APIs (Input actions, phone pages,
## class deploy, swings, shots), so what the client sees is the actual build running.

const CITY_SCENE := preload("res://scenes/city/NovaAetheris.tscn")
const SPIRE_SCENE := preload("res://scenes/spire/SpireRuins.tscn")

var _overlay: CanvasLayer
var _fade: ColorRect
var _caption: PanelContainer
var _caption_title: Label
var _caption_sub: Label
var _caption_bar: ColorRect
var _card: Control
var _card_title: Label
var _card_sub: Label
var _card_lines: VBoxContainer
var _chapter: Label
var _step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_overlay()
	await _run()
	get_tree().quit()


# ====================================================================== helpers
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _fade_to(alpha: float, dur := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, dur)
	await tw.finished


func _cut(action: Callable) -> void:
	await _fade_to(1.0, 0.3)
	action.call()
	await _wait(0.15)
	await _fade_to(0.0, 0.4)


func _show_caption(title: String, sub: String) -> void:
	_step += 1
	_caption_title.text = title
	_caption_sub.text = sub
	_chapter.text = "%02d" % _step
	_caption.visible = true
	_caption.modulate.a = 0.0
	_caption.position.x = -40.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_caption, "modulate:a", 1.0, 0.35)
	tw.tween_property(_caption, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _hide_caption() -> void:
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 0.0, 0.3)
	await tw.finished
	_caption.visible = false


func _show_card(title: String, sub: String, lines: Array[String], dur: float) -> void:
	_card_title.text = title
	_card_sub.text = sub
	for c in _card_lines.get_children():
		c.queue_free()
	for l in lines:
		var lab := UIKit.label(l, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		lab.modulate.a = 0.0
		_card_lines.add_child(lab)
	_card.visible = true
	_card.modulate.a = 0.0
	_card_title.scale = Vector2(0.92, 0.92)
	_card_title.pivot_offset = _card_title.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_property(_card_title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var i := 0
	for lab in _card_lines.get_children():
		tw.tween_property(lab, "modulate:a", 1.0, 0.4).set_delay(0.5 + i * 0.25)
		i += 1
	await _wait(dur)
	var tw2 := create_tween()
	tw2.tween_property(_card, "modulate:a", 0.0, 0.5)
	await tw2.finished
	_card.visible = false


func _press(action: String, sec: float) -> void:
	Input.action_press(action)
	await _wait(sec)
	Input.action_release(action)


func _face(player: Node3D, target: Vector3, eye_height := 1.55) -> void:
	var eye := player.global_position + Vector3(0, eye_height, 0)
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	if player is SpirePlayer:
		player.pivot.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


# ====================================================================== overlay
func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	# Caption (bottom-left).
	_caption = UIKit.panel(Color(0.03, 0.035, 0.06, 0.88), 10, Color(1, 1, 1, 0.1), 16)
	_caption.visible = false
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_caption)
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 36
	_caption.offset_right = 640
	_caption.offset_top = -176
	_caption.offset_bottom = -64
	var row := UIKit.hbox(14)
	_caption.add_child(row)
	_caption_bar = ColorRect.new()
	_caption_bar.color = UIKit.ACCENT
	_caption_bar.custom_minimum_size = Vector2(5, 0)
	row.add_child(_caption_bar)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var top := UIKit.hbox(10)
	_chapter = UIKit.label("01", 13, UIKit.ACCENT)
	top.add_child(_chapter)
	top.add_child(UIKit.label("FEATURE", 13, UIKit.TEXT_DIM))
	col.add_child(top)
	_caption_title = UIKit.label("", 30, UIKit.TEXT)
	col.add_child(_caption_title)
	_caption_sub = UIKit.wrapped("", 16, UIKit.TEXT_DIM)
	col.add_child(_caption_sub)

	# Full-screen card (intro / outro).
	_card = Control.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_card)
	UIKit.full_rect(_card)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.78)
	_card.add_child(bg)
	UIKit.full_rect(bg)
	var centre := CenterContainer.new()
	_card.add_child(centre)
	UIKit.full_rect(centre)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(v)
	var frame := UIKit.panel(Color(0.04, 0.04, 0.07, 0.9), 22, UIKit.ACCENT2, 40)
	frame.custom_minimum_size = Vector2(860, 0)
	v.add_child(frame)
	var fv := UIKit.vbox(12)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(fv)
	_card_sub = UIKit.label("", 16, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	fv.add_child(_card_sub)
	_card_title = UIKit.label("", 64, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	fv.add_child(_card_title)
	var line := ColorRect.new()
	line.color = UIKit.ACCENT2
	line.custom_minimum_size = Vector2(0, 2)
	fv.add_child(line)
	_card_lines = UIKit.vbox(6)
	_card_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	fv.add_child(_card_lines)

	# Fade.
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)
	UIKit.full_rect(_fade)
	_fade.modulate.a = 1.0


# ====================================================================== the show
func _run() -> void:
	# ---------------------------------------------------------------- CITY
	var city: Node3D = CITY_SCENE.instantiate()
	add_child(city)
	await _wait(0.3)
	var player: PlayerController = city.get_node("Player")
	var vehicle: VehicleController = city.get_node("Vehicle")
	var rig: CameraRig = city.get_node("CameraRig")
	var hud: CityHUD = city.get_node("CityHUD")
	var phone: PhoneUI = city.get_node("PhoneUI")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rig._pitch = -0.08
	rig._yaw = -0.15
	rig.set_target(player, CameraRig.Mode.ORBIT)
	var intro_tw := create_tween()
	intro_tw.tween_property(rig, "_yaw", -1.15, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_to(0.0, 1.0)
	await _show_card("OBSIDIAN", "VERTICAL SLICE  ·  CLIENT PREVIEW",
		["Nova Aetheris — the city hub", "The Spire Ruins — the battlefield", "Built in Godot 4 · GDScript · every system playable"], 3.6)

	# On foot.
	_show_caption("Nova Aetheris", "Open-world hub: on-foot exploration with sprint, jump and orbit camera")
	rig._yaw = 0.35
	var walk_tw := create_tween()
	walk_tw.tween_property(rig, "_yaw", -0.4, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Input.action_press("sprint")
	await _press("move_forward", 3.2)
	Input.action_release("sprint")
	await _hide_caption()

	# Vehicle.
	await _cut(func() -> void:
		player.global_position = vehicle.global_position - vehicle.global_transform.basis.x * 2.4 + Vector3.UP * 0.4
		player.rotation.y = vehicle.rotation.y
		rig._yaw = vehicle.rotation.y + 0.6)
	_show_caption("Vehicle", "Seamless entry, arcade handling, speed-sensitive steering — speedometer turns yellow at 50 mph, red past 70")
	await _wait(0.6)
	player.enter_vehicle(vehicle)
	await _wait(0.4)
	Input.action_press("move_forward")
	await _wait(2.6)
	await _press("move_left", 0.5)
	await _wait(0.9)
	Input.action_release("move_forward")
	await _press("jump", 1.2)
	await _hide_caption()

	# Phone.
	await _cut(func() -> void:
		player.exit_vehicle()
		rig._yaw = vehicle.rotation.y + 2.4
		rig._pitch = -0.25)
	_show_caption("Smartphone", "P toggles the animated phone: Jobs board, Property listings, live Stats")
	phone.open()
	await _wait(1.4)
	phone.show_page("jobs")
	await _wait(1.8)
	JobManager.start_job("courier_docks")
	phone.show_page("jobs")
	await _wait(1.2)
	phone.show_page("property")
	await _wait(1.0)
	phone._confirm_property_id = "heights_plot_07"
	phone._rebuild("property")
	await _wait(1.0)
	phone._confirm_property_id = ""
	GameState.buy_property("heights_plot_07", 950)
	phone._rebuild("property")
	await _wait(1.2)
	phone.show_page("stats")
	await _wait(1.6)
	phone.close()
	await _hide_caption()

	# Jobs.
	_show_caption("Job objectives", "Accepted jobs drop a beacon in the world and on the mini-map; completion pays Credits + Renown")
	await _cut(func() -> void:
		vehicle.global_position = Vector3(-78, 0.6, 122)
		vehicle.rotation.y = 0.0
		vehicle.forward_speed = 0.0
		player.global_position = vehicle.global_position
		player.enter_vehicle(vehicle)
		rig._yaw = 0.0)
	await _press("move_forward", 2.2)
	await _wait(0.6)
	await _cut(func() -> void:
		vehicle.global_position = Vector3(78, 0.6, -86)
		vehicle.rotation.y = 0.0
		vehicle.forward_speed = 0.0
		rig._yaw = 0.0)
	await _press("move_forward", 2.0)
	await _wait(1.6)
	await _hide_caption()

	# Gate.
	_show_caption("Spire Gate", "Walk into the portal at the city's edge to transit to the battlefield")
	await _cut(func() -> void:
		player.exit_vehicle()
		player.global_position = Vector3(0, 0.6, -128)
		player.rotation.y = 0.0
		rig._yaw = 0.0
		rig._pitch = -0.12)
	Input.action_press("sprint")
	await _press("move_forward", 2.6)
	Input.action_release("sprint")
	await _wait(1.6)
	await _hide_caption()
	await _fade_to(1.0, 0.6)
	city.queue_free()
	await _wait(0.2)

	# ---------------------------------------------------------------- SPIRE
	var spire: Node3D = SPIRE_SCENE.instantiate()
	add_child(spire)
	var cine := Camera3D.new()
	cine.position = Vector3(26, 18, 62)
	spire.add_child(cine)
	cine.look_at(Vector3(0, 8, 0))
	cine.current = true
	await _wait(0.3)
	var shud: SpireHUD = spire.get_node("SpireHUD")
	await _fade_to(0.0, 0.8)
	_show_caption("The Spire Ruins", "Central Plaza arena: cover rings, ramps, vantage platforms, hunter bots — choose Swordsman or Sniper")
	await _wait(2.8)
	await _hide_caption()
	shud.class_chosen.emit(GameState.CLASS_SWORDSMAN)
	cine.queue_free()
	await _wait(0.3)
	var sp: SpirePlayer = spire.player
	var dummy1: TrainingDummy = spire.get_node("Enemies/Dummy1")
	var hunter: TrainingDummy = spire.get_node("Enemies/Hunter1")

	# Swordsman.
	await _cut(func() -> void:
		sp.global_position = dummy1.global_position + Vector3(0, 0, 2.3)
		_face(sp, dummy1.global_position + Vector3(0, 1.0, 0)))
	_show_caption("Swordsman", "Tweened strikes with timed hitbox windows, a block, and a parry that staggers attackers")
	await _wait(0.5)
	for i in range(3):
		sp._swing()
		await _wait(0.6)
	await _wait(0.8)
	hunter.global_position = sp.global_position + (-sp.global_transform.basis.z) * 2.1
	hunter.player = sp
	hunter.state = TrainingDummy.State.RECOVER
	hunter._state_until = 999.0
	_face(sp, hunter.global_position + Vector3(0, 1.0, 0))
	hunter._animate_windup()
	await _wait(0.45)
	sp.set_blocking(true)
	await _wait(0.05)
	sp.take_damage(12.0, hunter)
	await _wait(1.1)
	sp.set_blocking(false)
	await _wait(0.2)
	for i in range(4):
		_face(sp, hunter.global_position + Vector3(0, 1.0, 0))
		sp._swing()
		await _wait(0.55)
	await _wait(0.8)
	await _hide_caption()

	# Sniper.
	shud.class_chosen.emit(GameState.CLASS_SNIPER)
	await _wait(0.2)
	sp = spire.player
	var d3: TrainingDummy = spire.get_node("Enemies/Dummy3")
	var d5: TrainingDummy = spire.get_node("Enemies/Dummy5")
	var d2: TrainingDummy = spire.get_node("Enemies/Dummy2")
	await _cut(func() -> void:
		sp.global_position = Vector3(36, 6.6, 34)
		_face(sp, d3.global_position + Vector3(0, 1.95, 0)))
	_show_caption("Sniper", "Scope zoom to first person, raycast ballistics with spread and gravity drop, headshots deal double")
	await _wait(0.8)
	sp.set_aiming(true)
	await _wait(0.9)
	sp._shoot()
	await _wait(1.5)
	_face(sp, d5.global_position + Vector3(0, 1.95, 0))
	await _wait(0.5)
	sp._shoot()
	await _wait(1.5)
	_face(sp, d2.global_position + Vector3(0, 1.95, 0))
	await _wait(0.5)
	sp._shoot()
	await _wait(1.3)
	sp.set_aiming(false)
	await _hide_caption()

	# Mini-map LOS.
	_show_caption("Tactical mini-map", "Live top-down render with a heading arrow; enemy markers only appear while in line of sight")
	_face(sp, Vector3(0, 6, 0))
	await _wait(3.0)
	await _hide_caption()

	# Rank.
	_show_caption("Rank advancement", "Renown from jobs and takedowns climbs the D → C → B → A → S ladder")
	await _wait(0.6)
	shud.reward_popup("MATCH COMPLETE   +150 RENOWN")
	RankManager.add_renown(150)
	await _wait(3.4)
	RankModal._dismiss()
	await _wait(0.5)
	await _hide_caption()

	# Store.
	_show_caption("Armory — two-step purchase rule", "Step 1 verifies rank (Mythic & Legendary need Rank C); only then do purchase options open")
	shud.toggle_store()
	await _wait(0.4)
	shud.store._selected_id = "obsidian_edge"
	shud.store.refresh()
	await _wait(1.8)
	shud.store._step2_open = true
	shud.store._build_detail()
	await _wait(1.6)
	shud.store._selected_id = "spire_sigil"
	shud.store._step2_open = true
	shud.store.refresh()
	await _wait(1.0)
	GameState.buy_gear("spire_sigil", 1500, "credits")
	shud.store.refresh()
	await _wait(1.4)
	await _hide_caption()
	shud.toggle_store()

	# Outro.
	await _show_card("Ready for review", "OBSIDIAN  ·  VERTICAL SLICE",
		["City: driving, smartphone, jobs, property, gate", "Battlefield: 2 classes, AI targets, LOS mini-map", "Progression: Renown, Rank C modal, two-step Armory", "Next: your feedback shapes the full build"], 4.6)
	await _fade_to(1.0, 0.8)
