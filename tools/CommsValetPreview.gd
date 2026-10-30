extends "res://tools/DemoDirector.gd"
## Scripted preview of the phone comms + valet update. Taps every button with a visible
## cursor and captions each step. Movie Maker:
##   godot --path . --write-movie preview/comms_valet.avi --fixed-fps 30 res://tools/CommsValetPreview.tscn

var _cursor: Control
var _phone: PhoneUI
var _quiet := false


class Cursor extends Control:
	var ripple := 0.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if ripple > 0.0:
			draw_arc(Vector2.ZERO, 14.0 + ripple * 30.0, 0, TAU, 48, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 1.0 - ripple), 3.0, true)
		draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.55))
		draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.95))
		draw_circle(Vector2.ZERO, 4.0, UIKit.ACCENT)


# ------------------------------------------------------------------ tap helpers
func _buttons_under(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(c)
		_buttons_under(c, out)


func _button(prefix: String, index := 0, root: Node = null, quiet := false) -> Button:
	if root == null:
		root = _phone._page_host
	var found: Array = []
	_quiet = quiet
	_buttons_under(root, found)
	var i := 0
	for b in found:
		if (b as Button).text.begins_with(prefix):
			if i == index:
				return b
			i += 1
	if not _quiet:
		push_warning("button not found: %s #%d" % [prefix, index])
	return null


func _scroll_parent(c: Control) -> ScrollContainer:
	var n: Node = c.get_parent()
	while n:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


func _tap(b: Control, settle := 0.7) -> void:
	if b == null:
		return
	var sc := _scroll_parent(b)
	if sc:
		sc.ensure_control_visible(b)
		await _wait(0.3)
	var target := b.get_global_rect().get_center()
	var tw := create_tween()
	tw.tween_property(_cursor, "position", target, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await _wait(0.1)
	var rip := create_tween()
	rip.tween_property(_cursor, "ripple", 1.0, 0.35).from(0.01)
	rip.tween_property(_cursor, "ripple", 0.0, 0.01)
	if b is Button:
		(b as Button).pressed.emit()
	await _wait(settle)


func _tap_page(prefix: String, index := 0, settle := 0.7) -> void:
	await _tap(_button(prefix, index), settle)


func _tap_call(prefix: String, settle := 0.8) -> void:
	await _tap(_button(prefix, 0, _phone._call_actions), settle)


func _tap_panel(prefix: String, index := 0, settle := 0.8) -> void:
	await _tap(_button(prefix, index, _phone._call_panel), settle)


## The valet panel button sitting in the row whose name label reads `row_name`.
func _panel_row_button(prefix: String, row_name: String) -> Button:
	for row in _phone._call_panel.get_children():
		if not (row is HBoxContainer):
			continue
		var labels: Array = []
		var buttons: Array = []
		_labels_under(row, labels)
		_buttons_under(row, buttons)
		var named := false
		for l in labels:
			if (l as Label).text == row_name:
				named = true
		if not named:
			continue
		for b in buttons:
			if (b as Button).text.begins_with(prefix):
				return b
	push_warning("panel row button not found: %s / %s" % [prefix, row_name])
	return null


func _labels_under(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is Label:
			out.append(c)
		_labels_under(c, out)


func _tap_row(prefix: String, row_name: String, settle := 0.8) -> void:
	await _tap(_panel_row_button(prefix, row_name), settle)


func _type_message(text: String) -> void:
	_phone._msg_input.text = ""
	for i in range(text.length()):
		_phone._msg_input.text = text.substr(0, i + 1)
		_phone._msg_input.caret_column = i + 1
		await _wait(0.045)
	await _wait(0.3)


func _wait_valet_bar() -> void:
	var waited := 0.0
	while waited < 8.0:
		if _button("Request", 0, _phone._call_actions, true) != null:
			return
		await _wait(0.25)
		waited += 0.25


func _wait_status(vid: String, status: String, timeout := 45.0) -> void:
	var waited := 0.0
	while Valet.status(vid) != status and waited < timeout:
		await _wait(0.5)
		waited += 0.5


# ------------------------------------------------------------------ the show
func _run() -> void:
	_cursor = Cursor.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.position = Vector2(800, 500)
	_overlay.add_child(_cursor)
	_overlay.move_child(_cursor, _overlay.get_child_count() - 2)   # under the fade

	var city: Node3D = CITY_SCENE.instantiate()
	add_child(city)
	await _wait(0.4)
	var rig: CameraRig = city.get_node("CameraRig")
	var hud: CityHUD = city.get_node("CityHUD")
	_phone = city.get_node("PhoneUI")
	rig._yaw = PI                     # look toward the kerb the valet pulls up to
	GameState.add_credits(6000)
	GameState.buy_vehicle("vanta_gt", 3200)
	Valet.repair_seconds_per_percent = 0.2
	Valet.min_repair_seconds = 8.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await _fade_to(0.0, 0.8)
	await _show_card("Player Comms & Valet", "OBSIDIAN  -  PHONE UPDATE", [
		"Players in session: direct messages and voice calls",
		"Rook Hale, valet & mechanic: Request / Fix / Return",
	], 3.8)

	# ---------------- players in session
	_show_caption("Players in session", "CALLS lists every player in the session with Message and Call.")
	_phone.open("home")
	await _wait(1.2)
	await _tap_page("CALLS", 0, 1.0)
	await _wait(2.0)
	await _hide_caption()

	_show_caption("Direct messages", "Tap Message to open a thread. Texts land on the other player's phone.")
	await _tap_page("Message", 0, 0.9)
	await _type_message("where are you?")
	await _tap_page("Send", 0, 0.6)
	await _wait(3.0)
	await _type_message("spire run tonight?")
	await _tap_page("Send", 0, 0.6)
	await _wait(3.2)
	await _hide_caption()

	_show_caption("Voice call", "Call rings the other player. Live mic meter, Mute and End once it connects.")
	await _tap_page("<", 0, 0.8)
	await _tap_page("Call", 0, 1.0)
	await _wait(2.4)
	await _tap_call("Mute", 1.2)
	await _tap_call("Unmute", 1.2)
	await _wait(0.8)
	await _tap_call("End call", 0.8)
	await _hide_caption()

	_show_caption("Incoming call", "Other players can ring you anywhere in the city. Answer or Decline.")
	var ids: Array = Session.player_ids()
	Session.simulate_incoming_call(ids[1])
	await _wait(2.4)
	await _tap_call("Answer", 1.0)
	await _wait(2.6)
	await _tap_call("End call", 0.8)
	await _hide_caption()

	# ---------------- valet
	_show_caption("Valet & mechanic", "Rook Hale is a saved contact. He answers with a voice line, then Request, Fix and Return appear.")
	await _tap_page("Call Rook", 0, 1.0)
	await _wait_valet_bar()
	await _wait(1.2)
	await _hide_caption()

	_show_caption("Request", "Pick an owned car. It spawns at a road node nearby and an NPC drives it to you.")
	await _tap_call("Request", 1.2)
	await _tap_row("Send", "Vanta GT", 3.0)
	await _tap_call("End", 0.6)
	_phone.close()
	await _wait(0.4)
	await _hide_caption()
	_show_caption("Delivery", "The valet follows the roads, pulls up at the kerb beside you, climbs out and walks off.")
	await _wait_status("vanta_gt", "with you", 40.0)
	await _wait(2.5)
	await _hide_caption()

	_show_caption("Return", "Call Rook again and tap Return: the car vanishes back to the garage.")
	_phone.open("garage")
	await _wait(1.5)
	await _tap_page("Call Rook", 0, 1.0)
	await _wait_valet_bar()
	await _tap_call("Return", 1.2)
	await _tap_row("Return", "Vanta GT", 2.5)
	await _hide_caption()

	GameState.damage_vehicle("vanta_gt", 45)
	_show_caption("Fix", "A damaged car goes on Rook's lift. Repairs run in a queue with a countdown in the Garage.")
	await _tap_call("Fix", 1.2)
	await _tap_row("Fix", "Vanta GT", 2.5)
	await _tap_call("End", 0.6)
	await _wait(0.5)
	_phone.show_page("garage")
	var waited := 0.0
	while Valet.in_service("vanta_gt") and waited < 30.0:
		await _wait(0.5)
		waited += 0.5
		if fmod(waited, 2.0) < 0.5:
			_phone.show_page("garage")
	await _hide_caption()

	_show_caption("Repair complete", "Rook rings back when the car is ready and sends it straight over.")
	await _wait(1.5)
	await _tap_call("Answer", 1.0)
	await _wait(3.4)
	await _tap_call("Request", 1.2)
	await _tap_row("Send", "Vanta GT", 2.5)
	await _tap_call("End", 0.6)
	_phone.close()
	await _wait_status("vanta_gt", "with you", 40.0)
	await _wait(2.0)
	await _hide_caption()
	hud.toast("Comms + Valet: ready to play", UIKit.GREEN)
	await _wait(1.0)
	await _show_card("Comms + Valet: shipped", "OBSIDIAN  -  PHONE UPDATE", [
		"Texts, voice calls, incoming calls",
		"Request, Fix, Return with a driving valet NPC",
	], 4.0)
	await _fade_to(1.0, 0.7)
