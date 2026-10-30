extends Node
## Headless smoke test. Run with:
##   godot --headless --path . res://tools/SmokeTest.tscn
## Exercises the gameplay systems without input devices and exits 0 on success, 1 on failure.

var _failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _test_progression()
	await _test_city()
	await _test_comms_valet()
	await _test_spire()
	await _test_rank_modal()
	print("\nSMOKE TEST %s  (%d failure(s))" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_progression() -> void:
	print("\n[Progression]")
	_check(RankManager.rank_letter() == "D", "starts at Rank D")
	_check(GameState.credits == 2500, "starts with 2,500 credits")
	_check(not RankManager.meets_rank("C"), "Rank C gear is locked at Rank D")
	_check(GameState.buy_property("heights_plot_07", 950), "buys Ridge Plot 7")
	_check(GameState.credits == 1550, "credits deducted after property purchase")
	_check(not GameState.buy_property("heights_plot_07", 950), "cannot buy an owned property twice")
	_check(not GameState.buy_property("heights_penthouse_03", 6500), "insufficient credits rejected")
	_check(JobManager.start_job("patrol_core"), "accepts Perimeter Sweep")
	_check(not JobManager.start_job("courier_docks"), "only one active job at a time")
	var before := GameState.credits
	for stage in JobManager.active_job["stages"]:
		JobManager.report_actor_position(stage["pos"] + Vector3(1, 0, 1))
	_check(not JobManager.has_active(), "job completes after visiting every stage")
	_check(GameState.credits == before + 300 + 15, "job pays 300 cr + 5% property perk")
	_check(RankManager.renown == 150, "job pays 150 renown")


func _test_city() -> void:
	print("\n[City]")
	var city: Node3D = load("res://scenes/city/NovaAetheris.tscn").instantiate()
	add_child(city)
	await _frames(5)
	var player: PlayerController = city.get_node("Player")
	var vehicle: VehicleController = city.get_node("Vehicle")
	var rig: CameraRig = city.get_node("CameraRig")
	var hud: CityHUD = city.get_node("CityHUD")
	var phone: PhoneUI = city.get_node("PhoneUI")
	_check(city.get_node("CityBuilder").get_child_count() > 30, "city geometry generated")
	_check(rig.mode == CameraRig.Mode.ORBIT, "camera orbits player on foot")
	# Walk forward.
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	_check(player.global_position.z < 11.0, "player walks with W")
	# Enter vehicle, drive, check speedometer colour logic.
	player.enter_vehicle(vehicle)
	_check(player.in_vehicle and vehicle.has_driver(), "player enters vehicle")
	_check(rig.mode == CameraRig.Mode.CHASE, "camera switches to chase mode")
	Input.action_press("move_forward")
	await _frames(150)
	var mph := vehicle.get_mph()
	Input.action_release("move_forward")
	_check(mph > 20.0, "vehicle accelerates (%.0f mph)" % mph)
	_check(hud.minimap._speed_label.text.ends_with("MPH"), "speedometer shows mph")
	hud.minimap.set_speed(30, true)
	var green := hud.minimap._speed_label.get_theme_color("font_color")
	hud.minimap.set_speed(60, true)
	var yellow := hud.minimap._speed_label.get_theme_color("font_color")
	hud.minimap.set_speed(85, true)
	var red := hud.minimap._speed_label.get_theme_color("font_color")
	_check(green == UIKit.GREEN and yellow == UIKit.AMBER and red == UIKit.RED, "speedometer colour thresholds 50 / 70 mph")
	player.exit_vehicle()
	_check(not player.in_vehicle and not vehicle.has_driver(), "player exits vehicle")
	# Phone.
	phone.toggle()
	_check(phone.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "phone opens and frees the mouse")
	phone.show_page("jobs")
	_check(phone._pages["jobs"].get_child_count() >= 2, "jobs app lists tasks")
	phone.show_page("property")
	phone.show_page("stats")
	phone.toggle()
	_check(not phone.is_open, "phone closes")
	# Gate prompt.
	player.global_position = CityData.GATE_POSITION + Vector3(0, 0.6, 1)
	await _frames(6)
	_check(hud._prompt.text.contains("Spire"), "gate trigger shows travel prompt")
	city.queue_free()
	await _frames(2)


func _test_comms_valet() -> void:
	print("\n[Comms + Valet]")
	var city: Node3D = load("res://scenes/city/NovaAetheris.tscn").instantiate()
	add_child(city)
	await _frames(5)
	var player: PlayerController = city.get_node("Player")
	var phone: PhoneUI = city.get_node("PhoneUI")
	var hud: CityHUD = city.get_node("CityHUD")
	# --- session roster, texts, calls
	_check(not Session.is_online() and Session.player_ids().size() == 3, "offline session has a simulated roster of 3")
	phone.open("contacts")
	_check(phone._pages["contacts"].get_child_count() >= 2, "contacts page builds")
	var juno: int = Session.player_ids()[0]
	phone.open_messages(juno)
	_check(phone._msg_input != null, "message thread opens with a composer")
	phone._msg_input.text = "where are you?"
	phone._send_message()
	_check(Session.threads[juno].size() == 1 and Session.threads[juno][0]["from_me"], "text sent to player")
	await _wait_seconds(2.8)
	_check(Session.threads[juno].size() == 2 and not Session.threads[juno][1]["from_me"], "player replies to the text")
	phone.call_player(juno)
	_check(Session.call_state == "calling" and phone._call_root.visible, "outgoing call rings the player")
	await _wait_seconds(1.8)
	_check(Session.call_state == "active" and phone._call_timer.visible, "call connects with a timer and mic meter")
	_check(Session.toggle_mute() and Session.mic_muted, "mute toggles")
	phone._end_call()
	_check(Session.call_state == "idle" and not phone._call_root.visible, "call ends and the overlay closes")
	var teo: int = Session.player_ids()[1]
	Session.simulate_incoming_call(teo)
	_check(phone._call_root.visible and phone._call_state.text == "INCOMING CALL", "incoming call shows Answer / Decline")
	phone._answer_call()
	_check(Session.call_state == "active", "incoming call answered")
	phone._end_call()
	# --- valet: Rook answers with the greeting, then Request / Fix / Return
	phone.call_contact("mechanic")
	_check(phone._call_root.visible and phone._call_name.text == "Rook Hale", "calling Rook shows the contact overlay")
	await _wait_seconds(1.6)
	_check(phone._call_text.text.begins_with("Hey, how can I help you"), "Rook answers with the greeting line")
	_check(phone._voice.playing or DisplayServer.get_name() == "headless", "greeting voice line plays")
	await _wait_seconds(3.6)
	var labels: Array = []
	for b in phone._call_actions.get_children():
		labels.append((b as Button).text)
	_check(labels == ["Request", "Fix", "Return", "End"], "valet bar shows Request, Fix, Return after the greeting")
	phone._set_valet_mode("request")
	_check(Valet.request_blocker("aether_compact") == "It's parked right next to you.", "car parked beside you cannot be re-requested")
	# buy a second car and have it delivered
	GameState.add_credits(5000)
	_check(GameState.buy_vehicle("vanta_gt", 3200), "buys the Vanta GT")
	_check(Valet.request("vanta_gt"), "Request dispatches a valet driver")
	_check(Valet.status("vanta_gt") == "en route" and Valet.en_route.size() == 1, "vehicle is en route")
	var car: VehicleController = Valet.en_route["vanta_gt"].vehicle
	var spawn_d := car.global_position.distance_to(player.global_position)
	_check(spawn_d >= 40.0, "spawned at a road node away from the player (%.0f m)" % spawn_d)
	var spawn_lane := RoadNetwork.nearest_lane_point(car.global_position)
	_check(spawn_lane.distance_to(Vector3(car.global_position.x, 0, car.global_position.z)) < 1.5, "spawn point sits on a road lane")
	_check(car.has_driver() and car.autopilot, "valet NPC is driving (player cannot enter)")
	var waited := 0.0
	while Valet.status("vanta_gt") == "en route" and waited < 60.0:
		await _wait_seconds(0.5)
		waited += 0.5
	var final_d := car.global_position.distance_to(player.global_position)
	_check(Valet.status("vanta_gt") == "with you", "valet delivers the car (%.0fs)" % waited)
	_check(final_d <= 14.0, "car parked at the kerb beside the player (%.1f m)" % final_d)
	_check(not car.has_driver() and not car.autopilot, "NPC climbs out: car is free to enter")
	# Return
	_check(Valet.return_vehicle("vanta_gt"), "Return removes the car")
	await _frames(2)
	_check(Valet.status("vanta_gt") == "garaged" and not is_instance_valid(car), "car disappears immediately")
	# Fix
	GameState.damage_vehicle("vanta_gt", 40)
	Valet.repair_seconds_per_percent = 0.05
	Valet.min_repair_seconds = 1.0
	_check(Valet.fix("vanta_gt"), "Fix queues the damaged car")
	_check(Valet.in_service("vanta_gt") and Valet.status("vanta_gt") == "in service", "car is in the service queue")
	_check(not Valet.fix("vanta_gt"), "cannot queue the same car twice")
	phone._end_call()
	_check(not phone._call_root.visible, "hanging up on Rook closes the overlay")
	await _wait_seconds(2.6)
	_check(GameState.vehicle_damage_of("vanta_gt") == 0 and not Valet.in_service("vanta_gt"), "repair finishes and damage resets")
	_check(phone._call_root.visible and phone._call_state.text == "INCOMING CALL" and phone._call_name.text == "Rook Hale", "Rook calls back when the repair is done")
	phone._answer_call()
	await _wait_seconds(0.3)
	_check(phone._call_text.text.contains("fixed"), "callback line reports the repaired car")
	# second delivery of the same car after Return + Fix (regression: must not get stuck)
	_check(Valet.request("vanta_gt"), "repaired car can be requested again")
	var car2: VehicleController = Valet.en_route["vanta_gt"].vehicle
	var drv2: ValetDriver = Valet.en_route["vanta_gt"]
	print("    spawn2 at ", car2.global_position, " path=", drv2.path)
	waited = 0.0
	while Valet.status("vanta_gt") == "en route" and waited < 45.0:
		await _wait_seconds(1.0)
		waited += 1.0
		if int(waited) % 5 == 0:
			print("    t=%.0f pos=%s speed=%.1f wp=%d/%d" % [waited, car2.global_position, car2.forward_speed, drv2.waypoint_index if is_instance_valid(drv2) else -1, drv2.path.size() if is_instance_valid(drv2) else -1])
	_check(Valet.status("vanta_gt") == "with you", "second delivery arrives (%.0fs)" % waited)
	phone._end_call()
	phone._end_call()
	phone.close()
	city.queue_free()
	await _frames(2)


func _wait_seconds(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _test_spire() -> void:
	print("\n[Spire]")
	var spire: Node3D = load("res://scenes/spire/SpireRuins.tscn").instantiate()
	add_child(spire)
	await _frames(5)
	var hud: SpireHUD = spire.get_node("SpireHUD")
	_check(hud._class_select.visible, "class selection shown on arrival")
	# Swordsman.
	hud.class_chosen.emit(GameState.CLASS_SWORDSMAN)
	await _frames(2)
	var player: SpirePlayer = spire.player
	_check(player != null and player.combat_class == GameState.CLASS_SWORDSMAN, "swordsman deployed")
	var dummy: TrainingDummy = spire.get_node("Enemies/Dummy1")
	player.global_position = dummy.global_position + Vector3(0, 0, 2.2)
	player.rotation.y = 0.0
	await _frames(2)
	var hp0 := dummy.hp
	player._swing()
	await _frames(20)
	_check(dummy.hp < hp0, "sword strike damages target (%.0f -> %.0f)" % [hp0, dummy.hp])
	var points0 := GameState.points
	for i in range(4):
		player._swing()
		await _frames(35)
	_check(not dummy.alive, "target defeated after repeated strikes")
	_check(GameState.points == points0 + 50, "takedown grants 50 points")
	_check(RankManager.renown == 150 + 45, "takedown grants 45 renown")
	# Block / parry.
	var hunter: TrainingDummy = spire.get_node("Enemies/Hunter1")
	hunter.global_position = player.global_position + Vector3(0, 0, -2.0)
	await _frames(2)
	player.take_damage(10.0, hunter)
	_check(is_equal_approx(player.hp, 90.0), "unblocked hit deals full damage")
	player.set_blocking(true)
	player.take_damage(10.0, hunter)
	_check(is_equal_approx(player.hp, 90.0) and hunter.state == TrainingDummy.State.STAGGER, "parry negates damage and staggers hunter")
	await get_tree().create_timer(0.4).timeout
	player.take_damage(10.0, hunter)
	_check(player.hp > 88.0 and player.hp < 90.0, "late block reduces damage")
	player.set_blocking(false)
	# Sniper.
	hud.class_chosen.emit(GameState.CLASS_SNIPER)
	await _frames(2)
	player = spire.player
	_check(player.combat_class == GameState.CLASS_SNIPER, "sniper deployed")
	var target: TrainingDummy = spire.get_node("Enemies/Dummy2")
	player.global_position = target.global_position + Vector3(0, 0, 8.0)
	player.rotation.y = 0.0
	player.pivot.rotation.x = 0.0
	player.set_aiming(true)
	await get_tree().create_timer(0.35).timeout
	_check(hud._scope.visible, "scope overlay shown while aiming")
	var thp := target.hp
	player._shoot()
	await _frames(2)
	_check(player.ammo == 4, "shot consumes ammo")
	_check(target.hp < thp, "raycast shot damages target (%.0f -> %.0f)" % [thp, target.hp])
	player.set_aiming(false)
	# Line of sight on the tactical map.
	var map := hud.minimap
	var seen := map.has_line_of_sight(target)
	Palette.box(spire, Vector3(4, 4, 0.5), player.global_position + Vector3(0, 1.5, -3), Palette.mat(Color.GRAY), true, "TestWall")
	await _frames(2)
	var hidden := map.has_line_of_sight(target)
	_check(seen and not hidden, "mini-map LOS: visible before wall, hidden behind wall")
	# Store two-step rule.
	hud.toggle_store()
	_check(hud.store.visible, "armory opens")
	hud.store._selected_id = "obsidian_edge"
	hud.store.refresh()
	var detail_text := ""
	for c in hud.store._detail.get_children():
		detail_text += _collect_text(c)
	_check(detail_text.contains("LOCKED") and not detail_text.contains("Buy for"), "Mythic gear locked at Rank D with no purchase options")
	hud.toggle_store()
	spire.queue_free()
	await _frames(2)


func _collect_text(n: Node) -> String:
	var s := ""
	if n is Label:
		s += n.text + " "
	if n is Button:
		s += n.text + " "
	for c in n.get_children():
		s += _collect_text(c)
	return s


func _test_rank_modal() -> void:
	print("\n[Rank]")
	var fired := []
	RankManager.rank_advanced.connect(func(n: String, o: String) -> void: fired.append([o, n]))
	RankManager.add_renown(500 - RankManager.renown)
	_check(RankManager.rank_letter() == "C" and fired.size() == 1, "reaching 500 renown advances D -> C")
	await get_tree().create_timer(0.1).timeout
	_check(RankModal._root.visible and RankModal._title.text == "Congratulations — Advanced to Rank C", "rank modal shows congratulations")
	_check(get_tree().paused, "modal pauses the game")
	RankModal._dismiss()
	await get_tree().create_timer(0.4).timeout
	_check(not get_tree().paused, "dismissing modal resumes the game")
	_check(RankManager.meets_rank("C"), "Rank C gear now passes verification")
	_check(GameState.buy_gear("obsidian_edge", 900, "points") == false, "cannot buy gear without enough points")
	GameState.add_points(1000)
	_check(GameState.buy_gear("obsidian_edge", 900, "points"), "buys Mythic gear with points at Rank C")
