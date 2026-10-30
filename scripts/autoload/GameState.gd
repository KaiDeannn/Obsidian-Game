extends Node
## GameState (autoload "GameState")
## Persistent, scene-independent player data: wallet, match points, class, holdings.
## Renown and Rank live in RankManager; this node only mirrors convenience getters.

signal credits_changed(new_amount: int)
signal points_changed(new_amount: int)
signal class_changed(new_class: String)
signal property_purchased(property_id: String)
signal gear_purchased(gear_id: String)
signal vehicle_purchased(vehicle_id: String)
signal vehicle_damage_changed(vehicle_id: String, damage: int)

const CLASS_SWORDSMAN := "Swordsman"
const CLASS_SNIPER := "Sniper"

var credits: int = 2500
var points: int = 0
var selected_class: String = CLASS_SWORDSMAN
var owned_properties: Array[String] = []
var owned_gear: Array[String] = []
var owned_vehicles: Array[String] = ["aether_compact"]
var vehicle_damage: Dictionary = {}       # vehicle_id -> 0..100
var jobs_completed: int = 0
var kills: int = 0
## When true, the city scene spawns the player at the Spire gate (returning from battle).
var arrival_from_spire: bool = false


func _ready() -> void:
	_ensure_input_actions()


# ---------------------------------------------------------------- wallet
func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	credits_changed.emit(credits)


func spend_credits(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


func add_points(amount: int) -> void:
	points = maxi(0, points + amount)
	points_changed.emit(points)


func spend_points(amount: int) -> bool:
	if points < amount:
		return false
	points -= amount
	points_changed.emit(points)
	return true


# ---------------------------------------------------------------- class
func set_class(combat_class: String) -> void:
	selected_class = combat_class
	class_changed.emit(combat_class)


# ---------------------------------------------------------------- holdings
func owns_property(property_id: String) -> bool:
	return owned_properties.has(property_id)


func buy_property(property_id: String, price: int) -> bool:
	if owns_property(property_id):
		return false
	if not spend_credits(price):
		return false
	owned_properties.append(property_id)
	property_purchased.emit(property_id)
	return true


func owns_gear(gear_id: String) -> bool:
	return owned_gear.has(gear_id)


## currency is "credits" or "points".
func buy_gear(gear_id: String, price: int, currency: String) -> bool:
	if owns_gear(gear_id):
		return false
	var ok := spend_points(price) if currency == "points" else spend_credits(price)
	if not ok:
		return false
	owned_gear.append(gear_id)
	gear_purchased.emit(gear_id)
	return true


# ---------------------------------------------------------------- vehicles
func owns_vehicle(vehicle_id: String) -> bool:
	return owned_vehicles.has(vehicle_id)


func buy_vehicle(vehicle_id: String, price: int) -> bool:
	if owns_vehicle(vehicle_id):
		return false
	if not spend_credits(price):
		return false
	owned_vehicles.append(vehicle_id)
	vehicle_purchased.emit(vehicle_id)
	return true


func vehicle_damage_of(vehicle_id: String) -> int:
	return int(vehicle_damage.get(vehicle_id, 0))


func damage_vehicle(vehicle_id: String, amount: int) -> void:
	var d := clampi(vehicle_damage_of(vehicle_id) + amount, 0, 100)
	vehicle_damage[vehicle_id] = d
	vehicle_damage_changed.emit(vehicle_id, d)


func repair_vehicle(vehicle_id: String) -> void:
	vehicle_damage[vehicle_id] = 0
	vehicle_damage_changed.emit(vehicle_id, 0)


static func vehicle_info(vehicle_id: String) -> Dictionary:
	for v in CityData.VEHICLES:
		if v["id"] == vehicle_id:
			return v
	return {"id": vehicle_id, "name": vehicle_id, "price": 0, "paint": Color(0.1, 0.1, 0.12), "desc": ""}


# ---------------------------------------------------------------- input safety net
## project.godot already defines every action; this guarantees the prototype still
## runs if the input map is ever reset in the editor.
func _ensure_input_actions() -> void:
	var key_actions := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "phone": KEY_P,
		"reload": KEY_R, "store": KEY_B, "class_1": KEY_1, "class_2": KEY_2,
	}
	for action: String in key_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = key_actions[action]
			InputMap.action_add_event(action, ev)
	var mouse_actions := {"attack": MOUSE_BUTTON_LEFT, "aim_block": MOUSE_BUTTON_RIGHT}
	for action: String in mouse_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventMouseButton.new()
			ev.button_index = mouse_actions[action]
			InputMap.action_add_event(action, ev)
