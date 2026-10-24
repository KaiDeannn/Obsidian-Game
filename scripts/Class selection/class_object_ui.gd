extends Control

signal clicked(class_data: Class_Data)

var class_data: Class_Data

@onready var icon: TextureRect = $Icon
@onready var text: Label = $Text
@onready var button: Button = $Icon/Button

func _ready() -> void:
	text.text = class_data.class_type_name
	icon.texture = class_data.icon
	button.pressed.connect(selected_class)

func selected_class() -> void:
	clicked.emit(class_data)
