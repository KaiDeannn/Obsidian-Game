
extends Resource
class_name ItemData

enum EquipmentSlot {
	NONE,
	WEAPON,
	HELMET,
	CHEST,
	LEGS,
	BOOTS,
	ACCESSORY
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

@export_group("Item Information")
@export var item_id: String = ""
@export var display_name: String = "New Item"
@export var icon: Texture2D
@export_multiline var description: String = ""

@export_group("Inventory")
@export var stackable: bool = true
@export_range(1, 9999) var max_stack: int = 99

@export_group("Value")
@export var item_value: int = 0

@export_group("Rarity")
@export var rarity: Rarity = Rarity.COMMON

@export_group("Equipment")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE

@export_group("Equipment Stats")
@export var bonus_damage: float = 0.0
@export var bonus_defense: float = 0.0
@export var bonus_health: float = 0.0
@export var bonus_speed: float = 0.0


func is_equippable() -> bool:
	return equipment_slot != EquipmentSlot.NONE


func get_equipment_slot_name() -> String:
	match equipment_slot:
		EquipmentSlot.WEAPON:
			return "Weapon"
		EquipmentSlot.HELMET:
			return "Helmet"
		EquipmentSlot.CHEST:
			return "Chest"
		EquipmentSlot.LEGS:
			return "Legs"
		EquipmentSlot.BOOTS:
			return "Boots"
		EquipmentSlot.ACCESSORY:
			return "Accessory"
		_:
			return "None"


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		Rarity.MYTHIC:
			return "Mythic"
		_:
			return "Common"


func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color("#B8C0CC")
		Rarity.UNCOMMON:
			return Color("#55D66B")
		Rarity.RARE:
			return Color("#4B9BFF")
		Rarity.EPIC:
			return Color("#B875FF")
		Rarity.LEGENDARY:
			return Color("#FFAA45")
		Rarity.MYTHIC:
			return Color("#FF5268")
		_:
			return Color("#B8C0CC")
