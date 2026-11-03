extends "res://tools/CommsValetPreview.gd"
## Scripted preview of the Premium Shop and the functional Ninja weapons. Movie Maker:
##   godot --path . --write-movie preview/premium_weapons.avi --fixed-fps 30 res://tools/PremiumWeaponsPreview.tscn

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


## Redeploy the Swordsman with a weapon, standing `dist` metres in front of dummy `idx`,
## with a third-person framing that keeps the blade and the target in view.
func _arm(weapon_id: String, idx: int, dist: float, side := 0.0) -> void:
	GameState.equip_premium(weapon_id)
	_hud.class_chosen.emit(GameState.CLASS_SWORDSMAN)
	await _wait(0.25)
	_player = _spire.player
	var d: TrainingDummy = _dummies[idx]
	_player.global_position = d.global_position + Vector3(side, 0, dist)
	_player.rotation.y = atan2(-(d.global_position.x - _player.global_position.x), -(d.global_position.z - _player.global_position.z))
	_player.pivot.rotation.x = -0.28
	_player.arm.spring_length = 5.2
	_player.camera.h_offset = 0.9
	await _wait(0.5)


func _pad_all() -> void:
	for d in _dummies:
		(d as TrainingDummy).hp = 5000.0


func _run() -> void:
	_cursor = Cursor.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.position = Vector2(800, 500)
	_overlay.add_child(_cursor)
	_overlay.move_child(_cursor, _overlay.get_child_count() - 2)

	# ---------------------------------------------------------------- city + shop
	var city: Node3D = CITY_SCENE.instantiate()
	add_child(city)
	await _wait(0.4)
	var rig: CameraRig = city.get_node("CameraRig")
	_phone = city.get_node("PhoneUI")
	GameState.add_aether(9000)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _fade_to(0.0, 0.8)
	await _show_card("Premium Weapons", "OBSIDIAN  -  NINJA LEGENDARY & MYTHIC", [
		"Twelve weapons from the design document, sold for Aether",
		"Equip one and fight with it in the Spire",
	], 4.0)

	_show_caption("Premium Shop", "A new PREMIUM app on the phone. Artwork, rarity, damage range, price in Aether and each weapon's trait.")
	_phone.open("home")
	await _wait(1.0)
	await _tap_page("PREMIUM", 0, 1.2)
	await _wait(1.2)
	var sc := _page_scroll()
	var bottom: int = int(sc.get_v_scroll_bar().max_value) if sc else 4000
	await _scroll_to(bottom, 22.0)
	await _wait(0.6)
	await _scroll_to(0, 1.6)
	await _hide_caption()

	_show_caption("Buy and equip", "Buy with a confirm step. The first weapon equips itself; any owned weapon can be equipped from here.")
	await _tap_page("Buy", 0, 1.0)
	await _tap_page("Confirm", 0, 1.6)
	await _wait(1.6)
	await _hide_caption()

	_show_caption("Carried in the city", "The equipped weapon rides on your back while you roam Nova Aetheris.")
	_phone.close()
	await _wait(0.4)
	var tw := create_tween()
	tw.tween_property(rig, "_yaw", rig._yaw + TAU, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await _hide_caption()

	# ---------------------------------------------------------------- spire
	await _fade_to(1.0, 0.4)
	city.queue_free()
	await _wait(0.2)
	_spire = SPIRE.instantiate()
	add_child(_spire)
	await _wait(0.4)
	_hud = _spire.get_node("SpireHUD")
	for i in range(1, 6):
		_dummies.append(_spire.get_node("Enemies/Dummy%d" % i))
	var base: Vector3 = (_dummies[0] as TrainingDummy).global_position
	(_dummies[3] as TrainingDummy).global_position = base + Vector3(3.0, 0, 0)
	for wid in ["dragons_breath", "starlit_edge", "starfall_dagger", "thunder_chain", "the_crescent", "the_ruin", "golden_razor", "ember_scythe", "last_honour", "prisma_guard"]:
		GameState.buy_premium(wid, int(CityData.premium_weapon(wid)["price"]))
	_pad_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _fade_to(0.0, 0.5)

	_show_caption("The Dragon's Breath  -  Mythic  -  DMG 72-85", "Every third strike breathes a flame wave 6 m ahead.")
	await _arm("dragons_breath", 3, 2.6)
	for i in range(3):
		_player._swing()
		await _wait(0.6)
	await _wait(1.2)
	_player._swing(); await _wait(0.6)
	_player._swing(); await _wait(0.6)
	_player._swing(); await _wait(1.4)
	await _hide_caption()

	_show_caption("The Starlit Edge  -  Legendary  -  DMG 58-68", "40% longer reach and a 25% chance to crit for double damage.")
	_pad_all()
	await _arm("starlit_edge", 3, 3.4)
	for i in range(6):
		_player._swing()
		await _wait(0.55)
	await _wait(0.8)
	await _hide_caption()

	_show_caption("The Starfall Dagger  -  Legendary  -  DMG 36-44", "Hits pull the enemy toward you and stagger it.")
	_pad_all()
	await _arm("starfall_dagger", 3, 2.4)
	for i in range(3):
		_player._swing()
		await _wait(0.9)
	await _wait(0.8)
	await _hide_caption()

	_show_caption("The Prisma-Guard  -  Legendary  -  DMG 70-85", "Compact dagger: 40% faster strikes and a longer lunge.")
	_pad_all()
	await _arm("prisma_guard", 3, 2.6)
	for i in range(6):
		_player._swing()
		await _wait(0.34)
	await _wait(0.8)
	await _hide_caption()

	_show_caption("The Thunder Chain  -  Legendary  -  DMG 52-60 per strike", "Sweeps every enemy within 4.5 m in a full circle.")
	_pad_all()
	await _arm("thunder_chain", 0, 1.8, 1.6)
	for i in range(3):
		_player._sweep()
		await _wait(0.9)
	await _wait(0.8)
	await _hide_caption()

	_show_caption("The Crescent  -  Legendary  -  DMG 45-52", "Thrown. Flies back to your hand and can hit on the way home.")
	_pad_all()
	await _arm("the_crescent", 0, 8.0)
	_player.pivot.rotation.x = -0.12
	_player._throw()
	await _wait(2.6)
	_player._throw()
	await _wait(2.6)
	await _hide_caption()

	_show_caption("The Ruin  -  Mythic  -  DMG 55-65", "Thrown. Pierces through up to three enemies in a line.")
	_pad_all()
	# line up three dummies for the piercing throw
	(_dummies[1] as TrainingDummy).global_position = base + Vector3(0, 0, -3.2)
	(_dummies[2] as TrainingDummy).global_position = base + Vector3(0, 0, -6.4)
	await _arm("the_ruin", 0, 7.0)
	_player.pivot.rotation.x = -0.12
	_player._throw()
	await _wait(1.6)
	_player._throw()
	await _wait(1.8)
	await _hide_caption()

	_show_caption("The Golden Razor  -  Legendary  -  DMG 38-45", "Thrown fast. Ricochets to a second enemy within 7 m.")
	_pad_all()
	await _arm("golden_razor", 0, 6.0, -1.0)
	_player.pivot.rotation.x = -0.12
	for i in range(4):
		_player._throw()
		await _wait(0.5)
	await _wait(1.4)
	await _hide_caption()

	_show_caption("The Ember-Scythe  -  Legendary  -  DMG 48-56", "Thrown. Targets keep burning afterwards: 3 x 8 damage.")
	_pad_all()
	await _arm("ember_scythe", 3, 6.0)
	_player.pivot.rotation.x = -0.12
	_player._throw()
	await _wait(3.4)
	await _hide_caption()

	_show_caption("The Last Honour  -  Mythic  -  DMG 100-110", "Every takedown restores 25 health.")
	_pad_all()
	await _arm("last_honour", 3, 2.6)
	(_dummies[3] as TrainingDummy).hp = 90.0
	_player.hp = 40.0
	_player.health_changed.emit(_player.hp, _player.max_hp)
	await _wait(0.6)
	_player._swing()
	await _wait(2.2)
	await _hide_caption()

	await _show_card("Premium Weapons: shipped", "OBSIDIAN  -  PHONE UPDATE 3", [
		"Shop, Aether, equip, carried in the city",
		"Twelve weapons with their own damage and traits in the Spire",
	], 4.0)
	await _fade_to(1.0, 0.7)
