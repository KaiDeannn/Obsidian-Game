
extends Area3D
class_name ItemPickup

@export var item_data: ItemData
@export_range(1, 9999) var amount: int = 1

var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if collected:
		return

	if not body.is_in_group("players"):
		return

	if item_data == null:
		push_warning("ItemPickup has no ItemData assigned.")
		return

	Inventory.register_item_data(item_data)

	if Inventory.add_item(item_data.item_id, amount):
		collected = true
		queue_free()
