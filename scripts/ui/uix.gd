extends Control

@onready var title_label: Label = $QuestUI/VBoxContainer/MarginContainer/Label
@onready var description_label: Label = $QuestUI/VBoxContainer/Panel/Label
@onready var progress_label: Label = $QuestUI/VBoxContainer/Panel3/Label2
@onready var reward_label: Label = $QuestUI/VBoxContainer/Panel2/Label2
@onready var quest_panel: PanelContainer = $QuestUI
@onready var RankAdvPanel: Control = $RankAdvancementPanel

@onready var inventory_panel: PanelContainer = $Inventory
@onready var equip_button: Button = $Inventory/MarginContainer/HBoxContainer/InventoryPanel/CenterContainer/GridContainer/EquipButton
@onready var unequip_button: Button = $Inventory/MarginContainer/HBoxContainer/InventoryPanel/CenterContainer/GridContainer/UnequipButton
@onready var weapon_panel = $Inventory/MarginContainer/HBoxContainer/WeaponPanel/MarginContainer3/GridContainer/WeaponPanel
@onready var class_name_label: Label = $Inventory/MarginContainer/HBoxContainer/WeaponPanel/MarginContainer2/MarginContainer/ClassNameLabel

@onready var rankup_messageLabel: Label = $RankAdvancementPanel/VBoxContainer/Label
@onready var currentRankLabel: Label = $RankAdvancementPanel/VBoxContainer/Label2
@onready var next_rank_label: Label = $RankAdvancementPanel/VBoxContainer/Label3

@onready var rank_label: Label = $ProfilePanel/HBoxContainer/VBoxContainer2/MarginContainer/GridContainer/HBoxContainer/RankLabel
@onready var renown_label: Label = $ProfilePanel/HBoxContainer/VBoxContainer2/MarginContainer/GridContainer/HBoxContainer/RenownLabel

@export var slot_gap: int = 6
@export var slot_size: Vector2 = Vector2(72, 72)

@onready var inventory_grid: GridContainer = $Inventory/MarginContainer/HBoxContainer/InventoryPanel/InventoryGrid

const DRAG_THRESHOLD: float = 8.0

var notification_id: int = 0
var slot_panels: Array[Panel] = []

var dragging: bool = false
var pending_drag: bool = false
var drag_source: int = -1
var drag_start_position: Vector2 = Vector2.ZERO
var drag_icon: TextureRect

var selected_slot_index: int = -1
var selected_equipment_slot: int = -1
var weapon_icon: TextureRect


func _ready() -> void:
	RankAdvPanel.hide()
	inventory_panel.hide()

	equip_button.pressed.connect(_on_equip_button_pressed)
	unequip_button.pressed.connect(_on_unequip_button_pressed)

	RankManager.rank_up_message.connect(_on_rank_up)
	JobManager.job_accepted.connect(_on_job_accepted)
	JobManager.job_progress_updated.connect(_on_job_progress_updated)
	JobManager.job_completed.connect(_on_job_completed)

	if inventory_grid == null:
		push_error("InventoryGrid was not found.")
		return

	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", slot_gap)
	inventory_grid.add_theme_constant_override("v_separation", slot_gap)

	_prepare_existing_slots()
	_create_drag_icon()
	_prepare_weapon_panel()

	if not Inventory.inventory_changed.is_connected(_refresh_inventory):
		Inventory.inventory_changed.connect(_refresh_inventory)

	if Inventory.has_signal("equipment_changed"):
		var callback := Callable(self, "_refresh_equipment_ui")
		if not Inventory.is_connected("equipment_changed", callback):
			Inventory.connect("equipment_changed", callback)

	_refresh_inventory()
	_refresh_equipment_ui()
	_refresh_class_name()
	refresh_quest()
	update_rank_ui()


func _process(_delta: float) -> void:
	update_rank_ui()
	_refresh_class_name()

	if inventory_panel.visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if dragging:
		_update_drag_icon_position()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		inventory_panel.visible = not inventory_panel.visible

		if inventory_panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			_cancel_drag()

		get_viewport().set_input_as_handled()
		return

	if not inventory_panel.visible:
		return

	if event is InputEventMouseMotion and pending_drag and not dragging:
		var distance := drag_start_position.distance_to(get_global_mouse_position())
		if distance >= DRAG_THRESHOLD:
			_start_drag(drag_source)

	if dragging:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
				_finish_drag()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			_update_drag_icon_position()


# RANK UI


func update_rank_ui() -> void:
	rank_label.text = "Rank: " + Globalvar.current_rank
	currentRankLabel.text = "Rank: " + Globalvar.current_rank
	renown_label.text = "Renown: %d" % Globalvar.current_renown
	next_rank_label.text = RankManager.get_rank_progress_text()


func _on_rank_up(message: String, new_rank: String) -> void:
	notification_id += 1
	var this_notification := notification_id

	rankup_messageLabel.text = message
	currentRankLabel.text = "Rank: " + new_rank
	RankAdvPanel.show()

	await get_tree().create_timer(5.0).timeout

	if this_notification == notification_id:
		RankAdvPanel.hide()


# --------------------------------------------------
# QUEST UI
# --------------------------------------------------

func _on_job_progress_updated(
	_job_id: String,
	_progress: int,
	_target: int
) -> void:
	show_quest()


func refresh_quest() -> void:
	if Globalvar.active_job_id == "":
		hide_quest()
	else:
		show_quest()


func show_quest() -> void:
	if Globalvar.active_job_id == "":
		hide_quest()
		return

	if not JobManager.jobs.has(Globalvar.active_job_id):
		hide_quest()
		return

	quest_panel.show()

	var job: QuestData = JobManager.jobs[Globalvar.active_job_id]

	title_label.text = Globalvar.active_job_title
	description_label.text = Globalvar.active_job_description

	progress_label.text = "Progress: %d / %d" % [
		Globalvar.active_job_progress,
		Globalvar.active_job_target
	]

	reward_label.text = "Reward: %d Renown | %d Credits" % [
		job.renown_reward,
		job.credits_reward
	]


func hide_quest() -> void:
	quest_panel.hide()


func _on_job_accepted(_job_id: String) -> void:
	refresh_quest()


func _on_job_progress_changed(progress: int, target: int) -> void:
	if Globalvar.active_job_id == "":
		return

	progress_label.text = "Progress: %d / %d" % [progress, target]


func _on_job_completed(_job_id: String) -> void:
	title_label.text = "Quest Completed!"
	description_label.text = "You received your rewards."
	progress_label.text = ""
	quest_panel.show()


#inventory

func _prepare_existing_slots() -> void:
	slot_panels.clear()

	for child in inventory_grid.get_children():
		if not child is Panel:
			continue

		var panel := child as Panel
		slot_panels.append(panel)
		panel.custom_minimum_size = slot_size
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var icon_rect := panel.get_node_or_null("ItemIcon") as TextureRect
		if icon_rect == null:
			icon_rect = TextureRect.new()
			icon_rect.name = "ItemIcon"
			panel.add_child(icon_rect)

		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 6
		icon_rect.offset_top = 6
		icon_rect.offset_right = -6
		icon_rect.offset_bottom = -6
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var amount_label := panel.get_node_or_null("Amount") as Label
		if amount_label == null:
			amount_label = Label.new()
			amount_label.name = "Amount"
			panel.add_child(amount_label)

		amount_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		amount_label.offset_left = -32
		amount_label.offset_top = -24
		amount_label.offset_right = -4
		amount_label.offset_bottom = -4
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var callback := Callable(self, "_on_slot_gui_input").bind(slot_panels.size() - 1)
		if not panel.gui_input.is_connected(callback):
			panel.gui_input.connect(callback)

	if slot_panels.size() != Inventory.MAX_SLOTS:
		push_warning(
			"InventoryGrid has %d slots; expected %d."
			% [slot_panels.size(), Inventory.MAX_SLOTS]
		)


func _select_inventory_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_panels.size():
		return

	var slot: Dictionary = Inventory.get_slot(slot_index)
	if slot.is_empty():
		selected_slot_index = -1
		selected_equipment_slot = -1
		_update_slot_highlights()
		_update_equipment_highlight()
		return

	selected_slot_index = slot_index
	selected_equipment_slot = -1
	_update_slot_highlights()
	_update_equipment_highlight()

	var definition: ItemData = Inventory.get_item_data(str(slot.get("id", "")))
	if definition != null:
		print("Selected item: ", definition.display_name)


func _update_slot_highlights() -> void:
	for i in range(slot_panels.size()):
		slot_panels[i].self_modulate = (
			Color(1.0, 0.85, 0.45, 1.0)
			if i == selected_slot_index
			else Color.WHITE
		)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not inventory_panel.visible:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			_select_inventory_slot(slot_index)

			var slot: Dictionary = Inventory.get_slot(slot_index)
			if slot.is_empty():
				pending_drag = false
				drag_source = -1
				return

			drag_start_position = get_global_mouse_position()
			drag_source = slot_index
			pending_drag = true
		else:
			if pending_drag and not dragging:
				pending_drag = false
				drag_source = -1
			elif dragging:
				_finish_drag()

#------------------equipmenttttttttttttttttttttttttttt
func _prepare_weapon_panel() -> void:
	weapon_panel.clip_contents = true

	weapon_icon = weapon_panel.get_node_or_null("ItemIcon") as TextureRect
	if weapon_icon == null:
		weapon_icon = TextureRect.new()
		weapon_icon.name = "ItemIcon"
		weapon_panel.add_child(weapon_icon)

	weapon_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_icon.offset_left = 6
	weapon_icon.offset_top = 6
	weapon_icon.offset_right = -6
	weapon_icon.offset_bottom = -6
	weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_child_controls_mouse_filter_ignore(weapon_panel)
	var callback := Callable(self, "_on_weapon_panel_gui_input")
	if not weapon_panel.gui_input.is_connected(callback):
		weapon_panel.gui_input.connect(callback)
	_update_equipment_highlight()


func _set_child_controls_mouse_filter_ignore(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_child_controls_mouse_filter_ignore(child)


func _on_weapon_panel_gui_input(event: InputEvent) -> void:
	if not inventory_panel.visible or dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			selected_slot_index = -1
			selected_equipment_slot = ItemData.EquipmentSlot.WEAPON
			_update_slot_highlights()
			_update_equipment_highlight()
			print("Selected equipped weapon slot")


func _update_equipment_highlight() -> void:
	if not is_instance_valid(weapon_panel):
		return
	weapon_panel.self_modulate = (
		Color(1.0, 0.85, 0.45, 1.0)
		if selected_equipment_slot == ItemData.EquipmentSlot.WEAPON
		else Color.WHITE
	)


func _on_equip_button_pressed() -> void:
	if selected_slot_index < 0:
		print("Equip failed: Select an inventory item first.")
		return

	var slot: Dictionary = Inventory.get_slot(selected_slot_index)
	if slot.is_empty():
		print("Equip failed: The selected slot is empty.")
		selected_slot_index = -1
		_update_slot_highlights()
		return

	var item_id := str(slot.get("id", ""))
	var definition: ItemData = Inventory.get_item_data(item_id)

	if definition == null:
		print("Equip failed: Item definition not found: ", item_id)
		return

	if not definition.is_equippable():
		print("Equip failed: ", definition.display_name, " cannot be equipped.")
		return

	if not Inventory.has_method("equip_item_from_inventory"):
		push_error("InventoryManager is missing equip_item_from_inventory().")
		return

	var current_id := _get_equipped_weapon_id()
	if current_id == item_id:
		print("Already equipped: ", definition.display_name)
		return

	var result: Variant = Inventory.call("equip_item_from_inventory", selected_slot_index)
	if result is bool and not result:
		print("Equip failed: InventoryManager rejected the item.")
		return

	if _get_equipped_weapon_id() != item_id:
		print("Equip failed: InventoryManager did not store the weapon.")
		_refresh_inventory()
		_refresh_equipment_ui()
		return

	print("Equipped: ", definition.display_name)
	selected_slot_index = -1
	selected_equipment_slot = -1
	_update_slot_highlights()
	_update_equipment_highlight()
	_refresh_inventory()
	_refresh_equipment_ui()


func _on_unequip_button_pressed() -> void:
	if selected_equipment_slot != ItemData.EquipmentSlot.WEAPON:
		print("Unequip failed: Click the equipped weapon slot first.")
		return

	var current_id := _get_equipped_weapon_id()
	if current_id == "":
		print("Unequip failed: No weapon is equipped.")
		return

	if not Inventory.has_method("unequip_item"):
		push_error("InventoryManager is missing unequip_item().")
		return

	var weapon_slot: int = ItemData.EquipmentSlot.WEAPON
	var result: Variant = Inventory.call("unequip_item", weapon_slot)
	if result is bool and not result:
		print("Unequip failed: InventoryManager rejected the request.")
		return

	if _get_equipped_weapon_id() != "":
		print("Unequip failed: The weapon is still marked as equipped.")
		return

	var definition: ItemData = Inventory.get_item_data(current_id)
	var weapon_name := definition.display_name if definition != null else current_id
	print("Unequipped: ", weapon_name)
	selected_equipment_slot = -1
	_update_equipment_highlight()
	_refresh_inventory()
	_refresh_equipment_ui()


func _get_equipped_weapon_id() -> String:
	if not Inventory.has_method("get_equipped_item"):
		return ""

	var equipped: Variant = Inventory.call(
		"get_equipped_item",
		ItemData.EquipmentSlot.WEAPON
	)

	if equipped is Dictionary:
		return str(equipped.get("id", equipped.get("item_id", "")))

	if equipped is ItemData:
		return equipped.item_id

	return ""


func _refresh_equipment_ui() -> void:
	if not is_instance_valid(weapon_icon):
		return

	var weapon_id := _get_equipped_weapon_id()
	if weapon_id == "":
		weapon_icon.texture = null
		weapon_panel.tooltip_text = "No weapon equipped"
		return

	var definition: ItemData = Inventory.get_item_data(weapon_id)
	if definition == null:
		weapon_icon.texture = null
		weapon_panel.tooltip_text = "Equipped weapon: " + weapon_id
		return

	weapon_icon.texture = definition.icon
	weapon_panel.tooltip_text = definition.display_name
	print("Weapon slot UI updated: ", definition.display_name)


func _refresh_class_name() -> void:
	if not is_instance_valid(class_name_label):
		return

	var class_value := _get_selected_class_value()
	if class_value.is_empty():
		class_name_label.text = "No Class Selected"
		return

	class_name_label.text = _format_class_name(class_value)


func _get_selected_class_value() -> String:
	# Check common Globalvar names without referencing a missing property directly.
	var possible_names: Array[String] = [
		"picked_class",
		"current_class",
		"player_class",
		"selected_class",
		"chosen_class",
		"class_name"
	]

	for property_info in Globalvar.get_property_list():
		var property_name := str(property_info.get("name", ""))
		if possible_names.has(property_name):
			var value: Variant = Globalvar.get(property_name)
			if value != null and not str(value).strip_edges().is_empty():
				return str(value).strip_edges()
	return ""


func _format_class_name(raw_name: String) -> String:
	var value := raw_name.strip_edges()
	if value.is_empty():
		return "No Class Selected"

	# Convert identifiers such as "heroA" or "hero_a" into readable labels.
	value = value.replace("_", " ").replace("-", " ")
	var readable := ""
	for i in range(value.length()):
		var character := value.substr(i, 1)
		if i > 0 and character == character.to_upper() and character != character.to_lower():
			readable += " "
		readable += character
	return readable.capitalize()


# --------------------------------------------------
# DRAG AND DROP
# --------------------------------------------------

func _create_drag_icon() -> void:
	drag_icon = TextureRect.new()
	drag_icon.name = "DragIcon"
	drag_icon.custom_minimum_size = slot_size
	drag_icon.size = slot_size
	drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.z_index = 100
	drag_icon.visible = false
	add_child(drag_icon)


func _start_drag(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_panels.size():
		return

	var slot: Dictionary = Inventory.get_slot(slot_index)
	if slot.is_empty():
		return

	var definition: ItemData = Inventory.get_item_data(str(slot.get("id", "")))
	if definition == null or definition.icon == null:
		return

	dragging = true
	pending_drag = false
	drag_source = slot_index
	drag_icon.texture = definition.icon
	drag_icon.visible = true
	drag_icon.modulate = Color(1, 1, 1, 0.85)
	_update_drag_icon_position()


func _update_drag_icon_position() -> void:
	if is_instance_valid(drag_icon):
		drag_icon.position = get_global_mouse_position() - slot_size / 2.0


func _finish_drag() -> void:
	var source := drag_source
	var destination := _get_slot_at_mouse()

	if source >= 0 and destination >= 0 and destination != source:
		Inventory.move_or_merge_slots(source, destination)

	_cancel_drag()


func _cancel_drag() -> void:
	dragging = false
	pending_drag = false
	drag_source = -1

	if is_instance_valid(drag_icon):
		drag_icon.texture = null
		drag_icon.hide()


func _get_slot_at_mouse() -> int:
	var mouse_position := get_global_mouse_position()

	for i in range(slot_panels.size()):
		var panel: Panel = slot_panels[i]
		if is_instance_valid(panel) and panel.get_global_rect().has_point(mouse_position):
			return i

	return -1


# --------------------------------------------------
# INVENTORY DISPLAY
# --------------------------------------------------

func _refresh_inventory() -> void:
	if not is_instance_valid(inventory_grid):
		return

	for i in range(slot_panels.size()):
		if i >= Inventory.MAX_SLOTS:
			break

		var panel: Panel = slot_panels[i]
		var icon_rect := panel.get_node("ItemIcon") as TextureRect
		var amount_label := panel.get_node("Amount") as Label
		var slot: Dictionary = Inventory.get_slot(i)

		if slot.is_empty():
			icon_rect.texture = null
			amount_label.text = ""
			panel.tooltip_text = ""
			continue

		var item_id := str(slot.get("id", ""))
		var amount := int(slot.get("amount", 0))
		var definition: ItemData = Inventory.get_item_data(item_id)

		icon_rect.texture = definition.icon if definition != null else null
		amount_label.text = str(amount) if amount > 1 else ""

		if definition != null:
			panel.tooltip_text = (
				definition.display_name
				+ "\nRarity: " + definition.get_rarity_name()
				+ "\n" + definition.description
			)
		else:
			panel.tooltip_text = ""

	_update_slot_highlights()
