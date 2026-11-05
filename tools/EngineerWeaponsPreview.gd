extends "res://tools/CommsValetPreview.gd"
## Scripted preview of the Engineer class and its ten Legendary & Mythic weapons.
## Movie Maker:
##   godot --path . --write-movie preview/engineer_weapons.avi --fixed-fps 30 res://tools/EngineerWeaponsPreview.tscn

const SPIRE := preload("res://scenes/spire/SpireRuins.tscn")

var _spire: Node3D
var _hud: SpireHUD
var _player: SpirePlayer
var _dummies: Array = []


func _page_scroll() -> ScrollContainer:
	var found: Array = []
	_scrolls_under(_phone._page_host, found)
	return found[0] if not found.is_empty() else null


func _scrolls_under(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is ScrollContainer and c.is_visible_in_tree():
			out.append(c)
		_scrolls_under(c, out)


func _scroll_to(value: int, dur: float) -> void:
	var sc := _page_scroll()
	if sc == null:
		return
	var tw := create_tween()
	tw.tween_property(sc, "scroll_vertical", value, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _pad_all() -> void:
	for d in _dummies:
		(d as TrainingDummy).hp = 5000.0


## Equip a weapon and stand `dist` metres from the dummy cluster, facing it, with a
## third-person framing that shows the weapon in hand and the targets ahead.
func _arm(weapon_id: String, dist: float, pitch := -0.14) -> void:
	GameState.equip_premium(weapon_id)
	_player.cycle_weapon(0)
	var centre: Vector3 = (_dummies[0] as TrainingDummy).global_position
	_player.global_position = centre + Vector3(0, 0, dist)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.pivot.rotation.x = pitch
	_player.arm.spring_length = 3.3
	_player.camera.h_offset = 0.8
	_pad_all()
	await _showcase()
	await _wait(0.5)


## A short close-up of the weapon in the Engineer's hands, seen from the front-right,
## before cutting back to the chase camera.
func _showcase(dur := 2.2) -> void:
	var launcher := WeaponModels.is_launcher(_player.weapon)
	var focus: Vector3 = _player.tool_pivot.global_position + (Vector3(0, 0.12, -0.3) if launcher else Vector3(0, 0.05, 0))
	var from: Vector3 = focus + (Vector3(1.75, 0.3, -1.05) if launcher else Vector3(0.75, 0.16, -0.7))
	var to: Vector3 = focus + (Vector3(1.95, 0.35, -0.35) if launcher else Vector3(0.9, 0.2, -0.35))
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	_spire.add_child(cam)
	cam.global_position = from
	cam.look_at(focus, Vector3.UP)
	cam.current = true
	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		cam.global_position = from.lerp(to, smoothstep(0.0, 1.0, t / dur))
		cam.look_at(focus, Vector3.UP)
	_player.camera.current = true
	cam.queue_free()


func _use(times := 1, gap := 1.2) -> void:
	for i in range(times):
		_player._next_use = 0.0
		_player._use_weapon()
		await _wait(gap)


func _run() -> void:
	_cursor = Cursor.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.position = Vector2(800, 500)
	_overlay.add_child(_cursor)
	_overlay.move_child(_cursor, _overlay.get_child_count() - 2)

	# ---------------------------------------------------------------- city: the arsenal on the phone
	GameState.intro_played = true
	var city: Node3D = CITY_SCENE.instantiate()
	add_child(city)
	await _wait(0.4)
	_phone = city.get_node("PhoneUI")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade_to(0.0, 0.8)
	await _show_card("Engineer Weapons", "OBSIDIAN  -  LEGENDARY & MYTHIC", [
		"Three launchers, six grenades and the Hellfire-Mine",
		"Modelled from the design document, each with its own detonation",
	], 4.0)
	_show_caption("Weapons app", "All ten Engineer weapons, shown as their real in-game models, with type, damage and effect. Tap Equip to carry one.")
	_phone.open("home")
	await _wait(1.0)
	await _tap_page("WEAPONS", 0, 1.2)
	var sc := _page_scroll()
	var bottom: int = int(sc.get_v_scroll_bar().max_value) if sc else 4000
	await _scroll_to(bottom, 18.0)
	await _wait(0.5)
	await _scroll_to(0, 1.4)
	await _tap_page("Equip", 0, 1.4)
	await _hide_caption()
	_phone.close()

	# ---------------------------------------------------------------- spire
	await _fade_to(1.0, 0.4)
	city.queue_free()
	await _wait(0.2)
	_spire = SPIRE.instantiate()
	add_child(_spire)
	await _wait(0.4)
	_hud = _spire.get_node("SpireHUD")
	for i in range(1, 5):
		_dummies.append(_spire.get_node("Enemies/Dummy%d" % i))
	var base: Vector3 = (_dummies[0] as TrainingDummy).global_position
	(_dummies[1] as TrainingDummy).global_position = base + Vector3(3.2, 0, -1.0)
	(_dummies[2] as TrainingDummy).global_position = base + Vector3(-3.2, 0, -1.0)
	(_dummies[3] as TrainingDummy).global_position = base + Vector3(0, 0, -4.0)
	for h in ["Hunter1", "Hunter2", "Hunter3"]:
		var hn := _spire.get_node_or_null("Enemies/" + h)
		if hn:
			hn.queue_free()
	await _fade_to(0.0, 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_caption("A third class: Engineer", "Deploy with 3. LMB fires, throws or places the weapon; Q switches between all ten.")
	await _wait(1.2)
	await _tap(_button("Deploy as Engineer", 0, _hud._class_select), 0.6)
	_player = _spire.player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _hide_caption()

	_show_caption("Oathkeeper  -  Mythic  -  88-100", "Redcore grenade launcher. Slow to fire; each round arcs true and blasts a 5.5 m area.")
	await _arm("oathkeeper", 15.0)
	await _use(2, 2.2)
	await _hide_caption()

	_show_caption("Sunblaze  -  Legendary  -  42-50", "Compact launcher: three searing rounds in quick succession.")
	await _arm("sunblaze", 13.0)
	await _use(2, 1.8)
	await _hide_caption()

	_show_caption("Skyfall  -  Legendary  -  75-85", "Plasma rocket launcher: a straight bolt that detonates on impact with splash damage.")
	await _arm("skyfall", 16.0)
	await _use(2, 1.8)
	await _hide_caption()

	_show_caption("Cinder-Canister  -  Legendary  -  65-75", "High-explosive hand grenade. Clean detonation, quickest to throw again.")
	await _arm("cinder_canister", 17.0)
	await _use(2, 2.0)
	await _hide_caption()

	_show_caption("Sol-Orb  -  Legendary  -  78-90", "Solar grenade: bursts, then embers keep burning the ground.")
	await _arm("sol_orb", 17.0)
	await _use(1, 5.5)
	await _hide_caption()

	_show_caption("Frost-Stasis  -  Legendary  -  30-45", "Cryo-grenade: everything caught in the flash is frozen in place.")
	await _arm("frost_stasis", 17.0)
	await _use(1, 4.5)
	await _hide_caption()

	_show_caption("Scarlet-Fuse  -  Legendary  -  72-82", "Timed grenade: the dial counts down, then a shockwave throws enemies off their feet.")
	await _arm("scarlet_fuse", 17.0)
	await _use(1, 5.0)
	await _hide_caption()

	_show_caption("Void-Orb  -  Legendary  -  70-80", "Dark energy grenade: pulls everything inward, then crushes it.")
	await _arm("void_orb", 17.0)
	await _use(1, 4.0)
	(_dummies[1] as TrainingDummy).global_position = base + Vector3(3.2, 0, -1.0)
	(_dummies[2] as TrainingDummy).global_position = base + Vector3(-3.2, 0, -1.0)
	(_dummies[3] as TrainingDummy).global_position = base + Vector3(0, 0, -4.0)
	(_dummies[0] as TrainingDummy).global_position = base
	await _hide_caption()

	_show_caption("Hellfire-Mine  -  Legendary  -  75-88", "Proximity mine: placed ahead of you, arms in a second, bursts when an enemy steps close.")
	await _arm("hellfire_mine", 4.0, -0.2)
	await _use(1, 3.2)
	await _hide_caption()

	_show_caption("Sunstone  -  Mythic  -  90-115", "Crystal-forged grenade: an 8 m shatter burst and a blinding flash. One of a kind.")
	await _arm("sunstone", 19.0)
	await _use(1, 4.0)
	await _hide_caption()

	await _show_card("Engineer arsenal: shipped", "OBSIDIAN  -  UPDATE 5", [
		"Ten weapons with real models and their own effects",
		"New playable class in The Spire",
	], 4.0)
	await _fade_to(1.0, 0.7)
