extends "res://levels/default_level.gd"
## Script for Level 3 logic

## All the buttons within the scene.
@onready var buttons = $World/Buttons.get_children()

## All the lasers within the scene.
@onready var lasers = $World/Lasers.get_children()

## Mapping to track each button's state
var _button_states = {}


## Called upon scene enter. Any initialization logic should live here.
func _ready() -> void:
	# Initialize button states and connect signals
	for button in buttons:
		_button_states[button] = false  # All buttons start as unpressed
		button.connect("button_state_changed", Callable(self, "_on_button_state_changed").bind(button))


## Handles button state changes.
## @param is_pressed the flag for whether the button has been pressed
## @param button the button being pressed
func _on_button_state_changed(is_pressed: bool, button: Node) -> void:
	# Update the state of the specific button
	_button_states[button] = is_pressed

	# Check if all buttons are pressed
	if _are_all_buttons_pressed():
		deactivate_laser("Laser3")


## Deactivates the given laser by name.
## @param laser_name the name of the laser node to deactivate
func deactivate_laser(laser_name: String) -> void:
	for laser in lasers:
		if laser.name == laser_name:
			laser.deactivate_laser()


## Helper function to check whether all buttons in the current scene have
## been pressed.
func _are_all_buttons_pressed() -> bool:
	# Return true if all buttons in the dictionary are pressed
	for button in _button_states:
		if not _button_states[button]:
			return false
	return true
