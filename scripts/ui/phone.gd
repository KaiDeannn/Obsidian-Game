extends PanelContainer

@onready var application_grid = $VBoxContainer/MarginContainer2/CenterContainer/ApplicationGrid
@onready var call_contact_ui = $VBoxContainer/MarginContainer2/CenterContainer/Call_Contact_UI
@onready var property_app = $VBoxContainer/MarginContainer2/CenterContainer/Property_UI
@onready var vehicle_app = $VBoxContainer/MarginContainer2/CenterContainer/Vehicle_UI



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _on_back_button_pressed() -> void:
	application_grid.show()
	call_contact_ui.hide()
	vehicle_app.hide()
	property_app.hide()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_call_contacts_pressed() -> void:
	application_grid.hide()
	call_contact_ui.show()


func _on_property_app_pressed() -> void:
	application_grid.hide()
	property_app.show()

func _on_vehicle_app_pressed() -> void:
	application_grid.hide()
	vehicle_app.show()
