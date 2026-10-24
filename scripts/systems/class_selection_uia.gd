extends Control

var _picked_class: Class_Data

@onready var _description_text : Label = $"Description"
@onready var select_button: Button = $"MarginContainer/Main container/Select Button"
@onready var class_container: HBoxContainer = $"MarginContainer/Main container/Class container"

@export var classes: Array[Class_Data] = []
@export var class_object_ui_scene: PackedScene

func _ready() -> void:
	select_button.pressed.connect(selection_finished)
	_description_text.text = "Select a Class to show it's description!"
	for class_data in classes:
		var class_object_ui = class_object_ui_scene.instantiate()
		class_object_ui.class_data = class_data
		class_object_ui.selected_class.connect(selected_class)
		class_container.add_child(class_object_ui)

func selection_finished() -> void:
	#Here we finish selection
	pass

func selected_class(class_data: Class_Data) -> void:
	_picked_class = class_data
	_description_text.text = class_data.description
