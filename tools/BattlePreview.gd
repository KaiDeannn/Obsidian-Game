extends "res://tools/EngineerWeaponsPreview.gd"
## Preview of the opening cinematic and the battle system. Movie Maker:
##   godot --path . --write-movie preview/battle.avi --fixed-fps 30 res://tools/BattlePreview.tscn

func _tap_in(prefix: String, root: Node, settle := 0.8) -> void:
	await _tap(_button(prefix, 0, root), settle)


func _pick_seed(mode: String, pref: String, want_melee: bool) -> int:
	for seed_value in range(60):
		var m := Battle.setup_match(mode, pref, [], seed_value, true)
		var cls: String = m["opponents"][0]["class"]
		if (cls in ["Swordsman", "Ninja"]) == want_melee:
			return seed_value
	return 0


func _fight(spire: Node3D, seconds: float) -> void:
	var t := 0.0
	while t < seconds and spire.match_active:
		var p: SpirePlayer = spire.player
		var foe: Node3D = null
		var best := INF
		for f in spire.fighters:
			if is_instance_valid(f) and f.team == "enemy" and f.alive:
				var d: float = f.global_position.distance_to(p.global_position)
				if d < best:
					best = d
					foe = f
		if foe and p.alive:
			var to := foe.global_position - p.global_position
			to.y = 0.0
			p.rotation.y = atan2(-to.x, -to.z)
			if to.length() > 2.4:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
				p._swing()
		await _wait(0.3)
		t += 0.3
	Input.action_release("move_forward")


func _run() -> void:
	_cursor = Cursor.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.position = Vector2(800, 500)
	_overlay.add_child(_cursor)
	_overlay.move_child(_cursor, _overlay.get_child_count() - 2)

	# ---------------------------------------------------------------- opening cinematic
	GameState.intro_played = false
	var city: Node3D = CITY_SCENE.instantiate()
	add_child(city)
	_fade.modulate.a = 0.0
	await _wait(0.5)
	var ctrl: Node = city
	while Cinematic.is_playing:
		await _wait(0.25)
	await _wait(2.0)

	# ---------------------------------------------------------------- match setup on the phone
	_phone = city.get_node("PhoneUI")
	var rig: CameraRig = city.get_node("CameraRig")
	var player: PlayerController = city.get_node("Player")
	var gate: CityGate = city.get_node("CityGate")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_caption("Battles app", "Solo battles, tournaments and clan wars. You only ever fight your own rank.")
	_phone.open("home")
	await _wait(1.0)
	await _tap_page("BATTLES", 0, 1.2)
	await _wait(2.0)
	await _scroll_to(600, 2.5)
	await _hide_caption()
	_show_caption("Preferred battlefield", "Pick a map. If your opponent prefers another, the system chooses at random.")
	await _tap_page("Prefer this map", 0, 1.4)
	await _wait(1.0)
	var sc := _page_scroll()
	await _scroll_to(int(sc.get_v_scroll_bar().max_value) if sc else 2000, 2.0)
	await _hide_caption()
	_show_caption("Find match", "Your match is ready. Follow the markers to your portal. Good luck!")
	var seed_value := _pick_seed("solo", "rooftop", true)
	Battle._rng.seed = seed_value
	await _tap_page("Find match", 0, 1.0)
	while Cinematic.is_playing:
		await _wait(0.25)
	await _wait(2.0)
	await _hide_caption()

	# ---------------------------------------------------------------- the portal
	_show_caption("Your portal", "The Spire gate is marked on the HUD and the mini-map. Press E there to enter.")
	await _fade_to(1.0, 0.4)
	player.global_position = CityData.GATE_POSITION + Vector3(0, 0.6, 34)
	player.rotation.y = 0.0
	rig._yaw = 0.0
	rig._pitch = -0.15
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.2)
	await _fade_to(0.0, 0.5)
	Input.action_press("move_forward")
	await _wait(4.2)
	Input.action_release("move_forward")
	await _wait(1.5)
	await _hide_caption()
	await _fade_to(1.0, 0.5)
	city.queue_free()
	await _wait(0.3)

	# ---------------------------------------------------------------- solo battle
	var spire: Node3D = SPIRE.instantiate()
	add_child(spire)
	await _wait(0.5)
	await _fade_to(0.0, 0.5)
	var hud: SpireHUD = spire.get_node("SpireHUD")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_caption("Solo battle", "Class select shows the match. Deploy, and the arena fly-in plays before the countdown.")
	await _wait(1.5)
	await _tap_in("Deploy as Swordsman", hud._class_select, 0.5)
	await _hide_caption()
	while not spire.match_active:
		await _wait(0.25)
	_show_caption("Fight", "One opponent of your rank. Go down and the attempt restarts; down them and you win.")
	await _fight(spire, 26.0)
	if spire.match_active:
		for f in spire.fighters:
			if is_instance_valid(f) and f.alive:
				f.take_damage(9999.0, f.global_position, false, spire.player)
	await _wait(1.0)
	await _hide_caption()
	_show_caption("Results", "Renown and Points paid out. Rematch, or return to the city.")
	await _wait(4.5)
	await _hide_caption()
	await _fade_to(1.0, 0.5)
	spire.queue_free()
	await _wait(0.3)

	# ---------------------------------------------------------------- clan war
	Battle.setup_match("clan_war", "ruins", ["Juno Hale", "Teo Varga", "Bram Okafor", "Kael Dusk"], 9)
	spire = SPIRE.instantiate()
	add_child(spire)
	await _wait(0.5)
	await _fade_to(0.0, 0.5)
	hud = spire.get_node("SpireHUD")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_caption("Clan war", "Ashfall vs Ironveil, five a side at one rank tier. Allies in cyan on the map, enemy dots coloured by weapon.")
	await _wait(1.5)
	await _tap_in("Deploy as Swordsman", hud._class_select, 0.5)
	while not spire.match_active:
		await _wait(0.25)
	await _wait(1.0)
	await _hide_caption()
	_show_caption("First to eight", "Fighters respawn. The score line counts the war; time limit four minutes.")
	await _fight(spire, 24.0)
	await _hide_caption()
	await _wait(0.5)
	await _show_card("Cinematics + Battles: shipped", "OBSIDIAN  -  UPDATE 4", [
		"Opening fly-over, match-ready and arena cinematics",
		"Solo, Tournament and Clan War on three battlefields",
	], 4.0)
	await _fade_to(1.0, 0.7)
