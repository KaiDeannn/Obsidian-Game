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
	await _test_engineer_weapons()
	await _test_cinematic()
	await _test_battle_setup()
	await _test_battle_matches()
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
	# engineer weapons: all available, equip and cycle
	_check(CityData.PREMIUM_WEAPONS.size() == 10, "10 Engineer weapons in the arsenal")
	_check(GameState.equipped_premium == "cinder_canister", "starts with the Cinder-Canister equipped")
	_check(GameState.equip_premium("oathkeeper") and GameState.equipped_weapon()["name"] == "Oathkeeper", "equips the Oathkeeper")
	_check(GameState.cycle_premium(-1) == "skyfall" and GameState.cycle_premium(1) == "oathkeeper", "cycling wraps around the arsenal")
	_check(not GameState.equip_premium("not_a_weapon"), "cannot equip an unknown weapon")
	var models_ok := true
	for w in CityData.PREMIUM_WEAPONS:
		if not ResourceLoader.exists(WeaponModels.MODEL_DIR + str(w["id"]) + ".glb") or not ResourceLoader.exists(w["image"]):
			models_ok = false
	_check(models_ok, "every weapon has an imported 3D model and its card picture")


func _test_city() -> void:
	print("\n[City]")
	GameState.intro_played = true
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
	phone.show_page("weapons")
	_check(phone._pages["weapons"].get_child_count() >= 2, "weapons page builds")
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
	GameState.intro_played = true
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


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await _wait_seconds(0.1)
		t += 0.1
	return cond.call()


func _test_cinematic() -> void:
	print("\n[Cinematic system]")
	GameState.intro_played = true
	var city: Node3D = load("res://scenes/city/NovaAetheris.tscn").instantiate()
	add_child(city)
	await _frames(5)
	var rig_cam: Camera3D = city.get_node("CameraRig/Yaw/Pitch/SpringArm3D/Camera3D")
	var shots := [
		{"type": "fly", "from": {"pos": Vector3(0, 30, -100), "look": Vector3.ZERO}, "to": {"pos": Vector3(0, 30, -60), "look": Vector3.ZERO}, "duration": 0.4, "title": "T", "subtitle": "S"},
		{"type": "orbit", "center": Vector3.ZERO, "radius": 20.0, "height": 10.0, "from_angle": 0.0, "to_angle": 90.0, "duration": 0.4},
		{"type": "hold", "duration": 0.2},
	]
	var ended := [false, false]
	Cinematic.finished.connect(func(_n: String, skipped: bool) -> void: ended[0] = true; ended[1] = skipped, CONNECT_ONE_SHOT)
	Cinematic.play(shots, {"fade_in": false, "fade_out": false}, "test")
	await _wait_seconds(0.15)
	_check(Cinematic.is_playing and get_viewport().get_camera_3d() != null and get_viewport().get_camera_3d().name == "CinematicCamera", "a sequence takes over with its own camera")
	_check(Cinematic._bar_top.offset_bottom > 0.0 or Cinematic._title.text == "T", "letterbox and titles are shown")
	var done := await _wait_until(func() -> bool: return not Cinematic.is_playing, 4.0)
	_check(done and ended[0] and not ended[1], "fly / orbit / hold sequence finishes by itself")
	await _frames(2)
	_check(get_viewport().get_camera_3d() == rig_cam, "gameplay camera is restored afterwards")
	ended = [false, false]
	Cinematic.finished.connect(func(_n: String, skipped: bool) -> void: ended[0] = true; ended[1] = skipped, CONNECT_ONE_SHOT)
	Cinematic.play([{"type": "hold", "duration": 5.0}], {"fade_in": false}, "long")
	await _wait_seconds(0.1)
	Cinematic.skip()
	done = await _wait_until(func() -> bool: return ended[0], 3.0)
	_check(done and ended[1], "skip ends a sequence early and reports it")
	var ctrl: Node = city
	Cinematic.play([{"type": "fly", "from": "player_back", "to": "player_back", "duration": 0.2}], {"fade_in": false, "fade_out": false, "resolve": ctrl._resolve_cine_point}, "resolve")
	await _wait_seconds(0.05)
	var cam := get_viewport().get_camera_3d()
	var player: Node3D = city.get_node("Player")
	_check(cam != null and cam.global_position.distance_to(player.global_position) < 8.0, "String anchors resolve to live scene positions")
	await _wait_until(func() -> bool: return not Cinematic.is_playing, 3.0)
	_check(CinematicData.SEQUENCES.has("city_intro") and CinematicData.SEQUENCES["city_intro"].size() == 4, "opening sequence is a four-shot catalogue entry")
	city.queue_free()
	await _frames(2)
	# the opening plays once on first entry and hands back control
	GameState.intro_played = false
	var city2: Node3D = load("res://scenes/city/NovaAetheris.tscn").instantiate()
	add_child(city2)
	await _wait_seconds(0.4)
	var hud2: CanvasLayer = city2.get_node("CityHUD")
	var player2: PlayerController = city2.get_node("Player")
	_check(Cinematic.is_playing and Cinematic.current_name == "city_intro" and not hud2.visible and not player2.input_enabled, "opening cinematic plays on first entry, HUD and controls off")
	_check(GameState.intro_played, "opening is marked as played")
	Cinematic.skip()
	await _wait_until(func() -> bool: return not Cinematic.is_playing, 3.0)
	await _wait_seconds(0.3)
	_check(hud2.visible and player2.input_enabled, "after the opening the HUD and controls return")
	city2.queue_free()
	await _frames(2)


func _test_battle_setup() -> void:
	print("\n[Battle system: match setup]")
	Battle.history.clear()
	var m := Battle.setup_match("solo", "ruins", [], 7)
	_check(m["rank"] == RankManager.rank_letter() and m["opponents"][0]["rank"] == RankManager.rank_letter(), "Golden Rule: the opponent is exactly your rank")
	_check(m["message"] == BattleData.MATCH_READY_MESSAGE, "match-ready message matches the document")
	var same := false
	var differ := false
	for seed_value in range(40):
		var mm := Battle.setup_match("solo", "rooftop", [], seed_value)
		var ok := false
		if mm["opponent_pref"] == "rooftop":
			same = true
			ok = mm["map"] == "rooftop"
		else:
			differ = true
			ok = BattleData.map_by_id(mm["map"])["id"] == mm["map"]
		if not ok:
			same = false
			break
	_check(same and differ, "map rule: shared preference keeps the map, different preferences let the system choose")
	Battle.setup_match("solo", "ruins", [], 7)
	GameState.intro_played = true
	var city: Node3D = load("res://scenes/city/NovaAetheris.tscn").instantiate()
	add_child(city)
	await _frames(5)
	var hud: CityHUD = city.get_node("CityHUD")
	var player: PlayerController = city.get_node("Player")
	_check(hud._objective_label.text.begins_with("Match ready"), "pending match puts the portal objective on the HUD")
	_check(hud.minimap.has_objective and hud.minimap.objective == CityData.GATE_POSITION, "mini-map marks the Spire gate as your portal")
	if Cinematic.is_playing:
		Cinematic.skip()
		await _wait_until(func() -> bool: return not Cinematic.is_playing, 4.0)
	player.global_position = CityData.GATE_POSITION + Vector3(0, 0.6, 1)
	await _frames(6)
	_check(hud._prompt.text.begins_with("YOUR PORTAL"), "gate prompt becomes the match portal")
	Battle.clear()
	_check(not Battle.has_pending() and not hud._objective_panel.visible, "cancelling clears the match and the marker")
	city.queue_free()
	await _frames(2)
	_check(Battle.can_enter_tournament(RankManager.rank_letter()) and not Battle.can_enter_tournament("S"), "tournaments: only your own tier is open")
	var eligible := Battle.eligible_clan_members("D")
	_check(eligible.size() == 4, "clan war: only online members at the tier are eligible (%d)" % eligible.size())
	var cw := Battle.setup_match("clan_war", "forest", ["Juno Hale", "Teo Varga", "Bram Okafor", "Kael Dusk", "Ilse Moor", "Sera Lind"], 2)
	_check(cw["allies"].size() == 4 and cw["opponents"].size() == 5, "clan war fields you + 4 picked members against five")
	Battle.clear()


func _spire_match(mode: String, map_id: String, allies: Array, seed_value: int) -> Node3D:
	Battle.setup_match(mode, map_id, allies, seed_value)
	var spire: Node3D = load("res://scenes/spire/SpireRuins.tscn").instantiate()
	add_child(spire)
	await _frames(5)
	var hud: SpireHUD = spire.get_node("SpireHUD")
	hud.class_chosen.emit(GameState.CLASS_SWORDSMAN)
	await _wait_seconds(0.3)
	if Cinematic.is_playing:
		Cinematic.skip()
	await _wait_until(func() -> bool: return spire.match_active, 12.0)
	return spire


func _test_battle_matches() -> void:
	print("\n[Battle system: matches in the Spire]")
	var renown_start := RankManager.renown
	var rank_idx0 := RankManager.rank_index
	var points0 := GameState.points
	# ---- arena variants build on their own
	Battle.clear()
	for variant in [["rooftop", "Roof"], ["forest", "Trunk"], ["ruins", "Dais"]]:
		var a: SpireArenaBuilder = load("res://scripts/spire/SpireArenaBuilder.gd").new()
		a.map_id = variant[0]
		add_child(a)
		_check(a.get_node_or_null(variant[1]) != null, "%s builds (%s)" % [BattleData.map_by_id(variant[0])["name"], variant[1]])
		a.queue_free()
	await _frames(2)
	# ---- solo
	Battle.setup_match("solo", "forest", [], 3)
	var chosen: String = Battle.pending["map"]
	var spire: Node3D = await _spire_match("solo", "forest", [], 3)
	var hud: SpireHUD = spire.get_node("SpireHUD")
	var arena: SpireArenaBuilder = spire.get_node("Arena")
	_check(spire.is_battle() and arena.map_id == chosen, "pending match loads the battlefield the system settled on (%s)" % BattleData.map_by_id(chosen)["name"])
	_check(spire.match_active and spire.fighters.size() == 1 and spire.fighters[0].team == "enemy", "solo match starts with one opponent after the intro and countdown")
	_check(hud._match_label.visible and hud._match_label.text.begins_with("SOLO"), "match line on the HUD")
	var player: SpirePlayer = spire.player
	var foe: BattleFighter = spire.fighters[0]
	_check(foe.rank == RankManager.rank_letter() and foe.weapon_category in BattleData.WEAPON_COLORS, "opponent carries your rank and a weapon category for the vision dots")
	# player downed: the attempt restarts
	player.take_damage(9999.0, foe)
	await _frames(2)
	_check(not spire.match_active and spire.attempts == 2, "solo death stops the clock and counts a new attempt")
	await _wait_until(func() -> bool: return spire.match_active, 5.0)
	_check(spire.match_active and player.alive and foe.alive, "attempt restarts with both fighters back on their feet")
	var renown0 := RankManager.renown
	foe.take_damage(9999.0, foe.global_position, false, player)
	await _frames(3)
	_check(not Battle.has_pending() and Battle.last_result["won"] and Battle.last_result["mode"] == "solo", "downing the opponent wins the solo battle")
	_check(RankManager.renown == renown0 + 120 + 5 and Battle.last_result["points"] == 60, "solo win pays 120 renown + 60 points (plus the takedown)")
	_check(hud.results_open(), "results screen opens")
	spire.queue_free()
	await _frames(2)
	# ---- ranged AI fighter fires at the player
	spire = await _spire_match("solo", "ruins", [], 5)
	player = spire.player
	player.global_position = Vector3(8, 0.6, 46)
	var sniper: BattleFighter = spire._spawn_fighter({"name": "Test Sniper", "class": "Sniper", "team": "enemy", "rank": "D", "weapon": "ranged"}, Vector3(8, 0.6, 34))
	var hp0 := player.hp
	await _wait_seconds(3.5)
	_check(player.hp < hp0, "ranged fighter lands line-of-sight shots on the player (%.0f -> %.0f)" % [hp0, player.hp])
	sniper.queue_free()
	spire.queue_free()
	Battle.clear()
	await _frames(2)
	# ---- tournament: elimination -> spectate -> loss reward
	spire = await _spire_match("tournament", "rooftop", [], 4)
	hud = spire.get_node("SpireHUD")
	arena = spire.get_node("Arena")
	_check(hud._match_label.text.begins_with("TOURNAMENT"), "tournament match line")
	player = spire.player
	player.take_damage(9999.0, spire.fighters[0])
	await _wait_until(func() -> bool: return not Battle.last_result.is_empty() and Battle.last_result["mode"] == "tournament", 8.0)
	_check(Battle.last_result["mode"] == "tournament" and not Battle.last_result["won"] and Battle.last_result["renown"] == 40, "eliminated in round one: spectate, then the loss reward")
	spire.queue_free()
	await _frames(2)
	# ---- clan war: five a side, kill target wins
	spire = await _spire_match("clan_war", "ruins", ["Juno Hale", "Teo Varga", "Bram Okafor", "Kael Dusk"], 6)
	hud = spire.get_node("SpireHUD")
	player = spire.player
	var allies := get_tree().get_nodes_in_group("ally").size()
	var enemies := 0
	for f in spire.fighters:
		if f.team == "enemy":
			enemies += 1
	_check(allies == 4 and enemies == 5, "clan war fields you + 4 allies against 5 (allies %d, enemies %d)" % [allies, enemies])
	_check(hud._match_label.text.begins_with("CLAN WAR"), "clan war score line")
	var target: int = int(Battle.mode_info("clan_war")["kill_target"])
	var downed := 0
	while downed < target:
		for f in spire.fighters:
			if downed >= target:
				break
			if f.team == "enemy" and f.alive:
				f.take_damage(9999.0, f.global_position, false, player)
				downed += 1
		await _frames(2)
		for f in spire.fighters:
			if f.team == "enemy" and not f.alive:
				f.revive()
		await _frames(2)
	await _wait_until(func() -> bool: return not Battle.last_result.is_empty() and Battle.last_result["mode"] == "clan_war", 4.0)
	_check(Battle.last_result["mode"] == "clan_war" and Battle.last_result["won"] and int(Battle.last_result["stats"]["score"]["ally"]) >= target, "reaching the kill target wins the clan war")
	spire.queue_free()
	Battle.clear()
	await _frames(2)
	# match rewards crossed the Rank C threshold: put progression back so the later
	# sections see the same world they were written against
	while RankModal._showing:
		RankModal._dismiss()
		await _frames(1)
	RankModal._queue.clear()
	get_tree().paused = false
	RankManager.renown = renown_start
	RankManager.rank_index = rank_idx0
	GameState.points = points0


func _test_engineer_weapons() -> void:
	print("\n[Engineer weapons in the Spire]")
	var spire: Node3D = load("res://scenes/spire/SpireRuins.tscn").instantiate()
	add_child(spire)
	await _frames(5)
	var hud: SpireHUD = spire.get_node("SpireHUD")
	# far dummies with padded health so nothing dies here (kills would shift renown totals)
	var d1: TrainingDummy = spire.get_node("Enemies/Dummy5")
	var d2: TrainingDummy = spire.get_node("Enemies/Dummy4")
	var d3: TrainingDummy = spire.get_node("Enemies/Dummy3")
	for h in ["Hunter1", "Hunter2", "Hunter3"]:
		spire.get_node("Enemies/" + h).queue_free()
	var home1 := d1.global_position
	d2.global_position = home1 + Vector3(3.0, 0, 0)
	for dmy in [d1, d2, d3]:
		dmy.hp = 5000.0
	GameState.equip_premium("oathkeeper")
	hud.class_chosen.emit(GameState.CLASS_ENGINEER)
	await _frames(3)
	var player: SpirePlayer = spire.player
	_check(player.combat_class == GameState.CLASS_ENGINEER and player.weapon.get("id", "") == "oathkeeper", "Engineer class deploys with the equipped weapon")
	_check(player.tool_pivot.visible and player.tool_pivot.get_node_or_null("Weapon_oathkeeper") != null and not player.sword_pivot.visible, "the launcher model is in the Engineer's hands")
	_check(hud._weapon_label.text.begins_with("Oathkeeper") and hud._state_label.text.begins_with("LMB to fire"), "HUD shows the weapon, type, damage and effect")
	# --- launcher: arcing round, area blast on two targets
	player.global_position = home1 + Vector3(0, 0, 12.0)
	player.rotation.y = 0.0
	player.pivot.rotation.x = 0.0
	await _frames(3)
	player._use_weapon()
	var hit := await _wait_until(func() -> bool: return d1.hp < 5000.0, 3.0)
	_check(hit and 5000.0 - d1.hp <= 100.0 and 5000.0 - d1.hp >= 40.0, "Oathkeeper round lands and blasts the target (%.0f)" % (5000.0 - d1.hp))
	_check(d2.hp < 5000.0, "the blast also catches a second enemy 3 m away")
	# --- Q switches weapons live
	player.cycle_weapon(1)
	_check(player.weapon.get("id", "") == "sol_orb" and player.tool_pivot.get_node_or_null("Weapon_sol_orb") != null and hud._weapon_label.text.begins_with("Sol-Orb"), "Q swaps to the next weapon in hand and on the HUD")
	# --- Sol-Orb: burst, then the burn zone keeps ticking
	player.global_position = home1 + Vector3(0, 0, 17.0)
	d1.hp = 5000.0
	await _frames(3)
	player._next_use = 0.0
	player._use_weapon()
	await _wait_until(func() -> bool: return d1.hp < 5000.0, 3.5)
	var after_burst := d1.hp
	await _wait_seconds(2.2)
	_check(after_burst < 5000.0 and d1.hp < after_burst, "Sol-Orb bursts and its embers keep burning (%.0f then %.0f)" % [5000.0 - after_burst, 5000.0 - d1.hp])
	# --- Frost-Stasis freezes
	GameState.equip_premium("frost_stasis")
	player.cycle_weapon(0)
	await _wait_seconds(4.2)          # let the Sol-Orb embers burn out first
	d1.hp = 5000.0
	player._next_use = 0.0
	player._use_weapon()
	var frozen := await _wait_until(func() -> bool: return d1.is_frozen(), 3.5)
	_check(frozen and 5000.0 - d1.hp <= 45.0, "Frost-Stasis freezes the target for light damage (%.0f)" % (5000.0 - d1.hp))
	# --- Scarlet-Fuse: timed
	GameState.equip_premium("scarlet_fuse")
	player.cycle_weapon(0)
	await _wait_seconds(4.5)          # let the burn zone and the freeze expire
	d1.hp = 5000.0
	player._next_use = 0.0
	player._use_weapon()
	await _wait_seconds(1.6)
	_check(d1.hp == 5000.0, "Scarlet-Fuse does not go off on landing")
	var went := await _wait_until(func() -> bool: return d1.hp < 5000.0, 3.0)
	_check(went and 5000.0 - d1.hp >= 43.0, "Scarlet-Fuse detonates when the 2.5 s dial runs out (%.0f)" % (5000.0 - d1.hp))
	# --- Void-Orb drags enemies together
	GameState.equip_premium("void_orb")
	player.cycle_weapon(0)
	await _wait_seconds(2.0)          # the concussion knockback has to settle
	for dmy in [d1, d2]:
		dmy.velocity = Vector3.ZERO
	d1.global_position = home1
	d2.global_position = home1 + Vector3(5.0, 0, 0)
	d1.hp = 5000.0
	d2.hp = 5000.0
	await _frames(4)
	player._next_use = 0.0
	player._use_weapon()
	await _wait_until(func() -> bool: return d1.hp < 5000.0 or d2.hp < 5000.0, 4.5)
	await _wait_seconds(0.3)
	var gap := d1.global_position.distance_to(d2.global_position)
	_check(gap < 3.5, "Void-Orb pulls enemies inward before it crushes them (gap %.1f m)" % gap)
	# --- Hellfire-Mine: arms, then proximity burst; three at a time
	GameState.equip_premium("hellfire_mine")
	player.cycle_weapon(0)
	d3.hp = 5000.0
	player.global_position = d3.global_position + Vector3(0, 0, 3.0)
	player.rotation.y = 0.0
	await _frames(3)
	player._next_use = 0.0
	player._use_weapon()
	_check(player.active_mines() == 1, "Hellfire-Mine is placed ahead of the Engineer")
	await _wait_seconds(0.5)
	_check(d3.hp == 5000.0, "the mine is inert while it arms")
	var boom := await _wait_until(func() -> bool: return d3.hp < 5000.0, 2.5)
	_check(boom and player.active_mines() == 0, "armed mine bursts on the enemy standing within reach")
	player.global_position = Vector3(0, 0.6, 48)
	await _frames(3)
	for i in range(4):
		player._next_use = 0.0
		player._use_weapon()
		player.global_position += Vector3(3.0, 0, 0)
		await _frames(3)
	_check(player.active_mines() == 3, "only three mines stay active; the oldest is recalled")
	# --- Sunstone: huge burst, flash, and it hurts a thrower who stands too close
	GameState.equip_premium("sunstone")
	player.cycle_weapon(0)
	var flashes := [0]
	player.flash_requested.connect(func(_s: float) -> void: flashes[0] += 1)
	player.global_position = Vector3(20, 0.6, 48)
	player.pivot.rotation.x = -1.2
	player.hp = player.max_hp
	await _frames(3)
	player._next_use = 0.0
	player._use_weapon()
	await _wait_until(func() -> bool: return flashes[0] > 0, 3.0)
	_check(flashes[0] > 0 and player.hp < player.max_hp, "Sunstone blinds and burns a thrower who stands too close (hp %.0f)" % player.hp)
	# --- the other classes are untouched
	hud.class_chosen.emit(GameState.CLASS_SWORDSMAN)
	await _frames(2)
	player = spire.player
	_check(player.weapon.is_empty() and player.sword_pivot.visible and not player.tool_pivot.visible, "Swordsman still carries the obsidian blade only")
	GameState.equip_premium("cinder_canister")
	spire.queue_free()
	await _frames(2)


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
