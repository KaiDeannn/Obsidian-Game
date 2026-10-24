
extends Node

signal inventory_changed
signal inventory_save_failed
signal equipment_changed

const MAX_SLOTS: int = 18
const SAVE_PATH: String = "user://inventory_save.json"
const ITEM_DIRECTORY: String = "res://ResourcesFilesTres/inventory"

var item_definitions: Array[ItemData] = []
var items: Array[Dictionary] = []

# Equipment stores item IDs, with one item per equipment slot.
# Example: {"1": "iron_sword", "2": "iron_helmet"}
var equipped_items: Dictionary = {}


func _ready() -> void:
	_load_item_definitions()

	items.clear()

	for i in range(MAX_SLOTS):
		items.append({})

	items = _load_local_inventory()
	equipped_items = _load_local_equipment()

	inventory_changed.emit()
	equipment_changed.emit()


# --------------------------------------------------
# ITEM DEFINITIONS
# --------------------------------------------------

func register_item_data(data: ItemData) -> void:
	if data == null or data.item_id.is_empty():
		return

	for i in range(item_definitions.size()):
		var existing: ItemData = item_definitions[i]

		if existing != null and existing.item_id == data.item_id:
			# Replace the existing definition with the new resource.
			item_definitions[i] = data
			return

	item_definitions.append(data)


func _load_item_definitions() -> void:
	item_definitions.clear()
	_scan_item_directory(ITEM_DIRECTORY)


func _scan_item_directory(directory_path: String) -> void:
	var dir := DirAccess.open(directory_path)

	if dir == null:
		push_warning("Item directory not found: " + directory_path)
		return

	dir.list_dir_begin()

	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var resource_path: String = directory_path.path_join(file_name)

		if dir.current_is_dir():
			_scan_item_directory(resource_path)
		elif file_name.ends_with(".tres"):
			var resource := load(resource_path) as ItemData

			if resource != null:
				register_item_data(resource)

		file_name = dir.get_next()

	dir.list_dir_end()


func get_item_data(item_id: String) -> ItemData:
	for definition: ItemData in item_definitions:
		if definition != null and definition.item_id == item_id:
			return definition

	return null


# --------------------------------------------------
# INVENTORY SLOTS
# --------------------------------------------------

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	return items[index].duplicate()


func add_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var definition: ItemData = get_item_data(item_id)

	if definition == null:
		push_warning("Unknown inventory item: " + item_id)
		return false

	var max_stack: int = definition.max_stack if definition.stackable else 1
	max_stack = max(1, max_stack)

	var capacity: int = 0

	for slot: Dictionary in items:
		if slot.is_empty():
			capacity += max_stack
		elif definition.stackable and str(slot.get("id", "")) == item_id:
			var current_amount: int = int(slot.get("amount", 0))
			capacity += max(0, max_stack - current_amount)

	if amount > capacity:
		return false

	var remaining: int = amount

	if definition.stackable:
		for i in range(items.size()):
			if str(items[i].get("id", "")) != item_id:
				continue

			var current_amount: int = int(items[i].get("amount", 0))
			var space: int = max_stack - current_amount
			var added: int = min(remaining, space)

			if added <= 0:
				continue

			items[i]["amount"] = current_amount + added
			remaining -= added

			if remaining <= 0:
				break

	while remaining > 0:
		var empty_index: int = -1

		for i in range(items.size()):
			if items[i].is_empty():
				empty_index = i
				break

		if empty_index == -1:
			return false

		var stack_amount: int = min(remaining, max_stack)

		items[empty_index] = {
			"id": item_id,
			"amount": stack_amount
		}

		remaining -= stack_amount

	_save_inventory()
	inventory_changed.emit()
	return true


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or get_item_count(item_id) < amount:
		return false

	var remaining: int = amount

	for i in range(items.size()):
		if str(items[i].get("id", "")) != item_id:
			continue

		var current_amount: int = int(items[i].get("amount", 0))
		var removed: int = min(remaining, current_amount)

		current_amount -= removed
		remaining -= removed

		if current_amount <= 0:
			items[i] = {}
		else:
			items[i]["amount"] = current_amount

		if remaining <= 0:
			break

	_save_inventory()
	inventory_changed.emit()
	return true


func move_or_merge_slots(source: int, destination: int) -> bool:
	if source < 0 or source >= items.size():
		return false

	if destination < 0 or destination >= items.size():
		return false

	if source == destination:
		return false

	var source_slot: Dictionary = items[source].duplicate()
	var destination_slot: Dictionary = items[destination].duplicate()

	if source_slot.is_empty():
		return false

	if destination_slot.is_empty():
		items[destination] = source_slot
		items[source] = {}

		_save_inventory()
		inventory_changed.emit()
		return true

	var source_id: String = str(source_slot.get("id", ""))
	var destination_id: String = str(destination_slot.get("id", ""))

	if source_id == destination_id:
		var definition: ItemData = get_item_data(source_id)

		if definition != null and definition.stackable:
			var max_stack: int = max(1, definition.max_stack)
			var source_amount: int = int(source_slot.get("amount", 0))
			var destination_amount: int = int(destination_slot.get("amount", 0))
			var space: int = max_stack - destination_amount

			if space > 0:
				var moved: int = min(source_amount, space)

				destination_slot["amount"] = destination_amount + moved
				source_amount -= moved

				items[destination] = destination_slot

				if source_amount <= 0:
					items[source] = {}
				else:
					source_slot["amount"] = source_amount
					items[source] = source_slot

				_save_inventory()
				inventory_changed.emit()
				return true

	items[source] = destination_slot
	items[destination] = source_slot

	_save_inventory()
	inventory_changed.emit()
	return true


func get_item_count(item_id: String) -> int:
	var total: int = 0

	for slot: Dictionary in items:
		if str(slot.get("id", "")) == item_id:
			total += int(slot.get("amount", 0))

	return total


# --------------------------------------------------
# EQUIPMENT
# --------------------------------------------------

func equip_item_from_inventory(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= items.size():
		return false

	var slot: Dictionary = items[inventory_index]

	if slot.is_empty():
		return false

	var item_id: String = str(slot.get("id", ""))
	var definition: ItemData = get_item_data(item_id)

	if definition == null or not definition.is_equippable():
		return false

	var equipment_slot: int = int(definition.equipment_slot)
	var slot_key: String = str(equipment_slot)

	# Remove the selected item from its inventory slot.
	var old_slot: Dictionary = slot.duplicate()
	items[inventory_index] = {}

	# If another item occupies this equipment slot,
	# return it to the inventory slot we just freed.
	if equipped_items.has(slot_key):
		var previous_item_id: String = str(equipped_items[slot_key])
		var previous_definition: ItemData = get_item_data(previous_item_id)

		if previous_definition == null:
			items[inventory_index] = old_slot
			return false

		equipped_items.erase(slot_key)

		items[inventory_index] = {
			"id": previous_item_id,
			"amount": 1
		}

	equipped_items[slot_key] = item_id

	_save_inventory()
	_save_equipment()

	inventory_changed.emit()
	equipment_changed.emit()
	return true


func unequip_item(equipment_slot: ItemData.EquipmentSlot) -> bool:
	var slot_key: String = str(int(equipment_slot))

	if not equipped_items.has(slot_key):
		return false

	var item_id: String = str(equipped_items[slot_key])

	# Only unequip when there is room in the inventory.
	var empty_index: int = -1

	for i in range(items.size()):
		if items[i].is_empty():
			empty_index = i
			break

	if empty_index == -1:
		return false

	items[empty_index] = {
		"id": item_id,
		"amount": 1
	}

	equipped_items.erase(slot_key)

	_save_inventory()
	_save_equipment()

	inventory_changed.emit()
	equipment_changed.emit()
	return true


func get_equipped_item(equipment_slot: ItemData.EquipmentSlot) -> ItemData:
	var slot_key: String = str(int(equipment_slot))
	var item_id: String = str(equipped_items.get(slot_key, ""))

	if item_id.is_empty():
		return null

	return get_item_data(item_id)


func is_item_equipped(item_id: String) -> bool:
	return equipped_items.values().has(item_id)


func get_equipment_bonus(stat_name: StringName) -> float:
	var total: float = 0.0

	for item_id: Variant in equipped_items.values():
		var definition: ItemData = get_item_data(str(item_id))

		if definition == null:
			continue

		match stat_name:
			&"damage":
				total += definition.bonus_damage
			&"defense":
				total += definition.bonus_defense
			&"health":
				total += definition.bonus_health
			&"speed":
				total += definition.bonus_speed

	return total


# --------------------------------------------------
# SAVING
# --------------------------------------------------

func _save_inventory() -> bool:
	var save_data: Dictionary = {
		"version": 2,
		"items": items
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Could not save inventory: " + SAVE_PATH)
		inventory_save_failed.emit()
		return false

	file.store_string(JSON.stringify(save_data))
	file.close()
	return true


func _save_equipment() -> bool:
	var save_path: String = "user://equipment_save.json"
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("Could not save equipment: " + save_path)
		inventory_save_failed.emit()
		return false

	file.store_string(JSON.stringify({
		"version": 1,
		"equipped": equipped_items
	}))

	file.close()
	return true


func _load_local_equipment() -> Dictionary:
	var save_path: String = "user://equipment_save.json"

	if not FileAccess.file_exists(save_path):
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		return {}

	var saved_equipment: Variant = parsed.get("equipped", {})

	if not saved_equipment is Dictionary:
		return {}

	var validated: Dictionary = {}

	for key: Variant in saved_equipment:
		var item_id: String = str(saved_equipment[key])
		var definition: ItemData = get_item_data(item_id)

		if definition == null or not definition.is_equippable():
			continue

		if str(int(definition.equipment_slot)) != str(key):
			continue

		# Prevent one item from occupying multiple equipment slots.
		if validated.values().has(item_id):
			continue

		validated[str(key)] = item_id

	return validated


func _load_local_inventory() -> Array[Dictionary]:
	var loaded: Array[Dictionary] = []

	for i in range(MAX_SLOTS):
		loaded.append({})

	if not FileAccess.file_exists(SAVE_PATH):
		return loaded

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("Could not open inventory save.")
		return loaded

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed is Dictionary:
		push_warning("Inventory save is invalid.")
		return loaded

	var saved_items: Variant = parsed.get("items", [])

	if not saved_items is Array:
		return loaded

	for i in range(min(saved_items.size(), MAX_SLOTS)):
		var saved_slot: Variant = saved_items[i]

		if not saved_slot is Dictionary:
			continue

		var saved_item_id: String = str(saved_slot.get("id", ""))
		var saved_amount: int = int(saved_slot.get("amount", 0))
		var definition: ItemData = get_item_data(saved_item_id)

		if definition == null or saved_amount <= 0:
			continue

		var limit: int = max(1, definition.max_stack) if definition.stackable else 1

		if saved_amount > limit:
			continue

		loaded[i] = {
			"id": saved_item_id,
			"amount": saved_amount
		}

	return loaded
