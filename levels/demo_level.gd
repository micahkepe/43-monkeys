extends Node2D

@onready var buttons = $Buttons.get_children()  # All the buttons
@onready var lasers = $Lasers.get_children()  # All the lasers

var button_states = {}  # Dictionary to track each button's state

func _ready() -> void:
	# Initialize button states and connect signals
	for button in buttons:
		button_states[button] = false  # All buttons start as unpressed
		button.connect("button_state_changed", Callable(self, "_on_button_state_changed").bind(button))

func _on_button_state_changed(is_pressed: bool, button: Node) -> void:
	# Update the state of the specific button
	button_states[button] = is_pressed

	# Check if all buttons are pressed
	if _are_all_buttons_pressed():
		deactivate_laser("Laser3")

func deactivate_laser(laser_name: String) -> void:
	for laser in lasers:
		if laser.name == laser_name:
			laser.deactivate_laser()

func _are_all_buttons_pressed() -> bool:
	# Return true if all buttons in the dictionary are pressed
	for button in button_states:
		if not button_states[button]:
			return false
	return true
