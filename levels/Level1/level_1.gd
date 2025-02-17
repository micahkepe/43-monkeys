extends Node2D

# Get all buttons and lasers from the scene tree.
@onready var buttons = $World/Buttons.get_children()
@onready var lasers = $ForegroundTiles/Lasers.get_children()

## A dictionary to track the state of each button.
var _button_states = {}

#------------------------------------------------------------------
# PUZZLE FLAGS
#------------------------------------------------------------------

## Tracker for whether the lasers 1, 2, 3 are deactivated (first button puzzle)
var _lasers_1_2_3_deactivated: bool = false


## Tracker for whether the lasers 1, 2, 3 are deactivated (first button puzzle)
var _laser_4_deactivated: bool = false


#############

func _ready() -> void:
	for button in buttons:
		# Initialize each button's state as false (not pressed)
		_button_states[button] = false
		# Connect the button's signal to our callback.
		# (Note: we bind the button node so our callback knows which button sent the signal.)
		button.connect("button_state_changed", Callable(self, "on_button_state_changed").bind(button))

# This callback is called whenever a button's state changes.
func on_button_state_changed(is_pressed: bool, button: Node) -> void:
	_button_states[button] = is_pressed

	# Check if both Buttons1 and Buttons2 are pressed.
	if are_buttons_1_2_pressed():
		deactivate_lasers_1_2_3()
		_lasers_1_2_3_deactivated = true

	# Check if Buttons3,4,5,6 are all pressed
	if are_buttons_3_4_5_6_pressed():
		deactivate_laser_4()
		_laser_4_deactivated = true

# Returns true only if both Buttons1 and Buttons2 are pressed.
func are_buttons_1_2_pressed() -> bool:
	for button in _button_states.keys():
		if button.name in ["Buttons1", "Buttons2"]:
			if not _button_states[button]:
				return false
	return true

# Returns true only if Buttons3,4,5,6 are all pressed.
func are_buttons_3_4_5_6_pressed() -> bool:
	for button in _button_states.keys():
		if button.name in ["Buttons3", "Buttons4", "Buttons5", "Buttons6"]:
			if not _button_states[button]:
				return false
	return true

# Iterates through all lasers and deactivates Laser1, Laser2, and Laser3.
func deactivate_lasers_1_2_3() -> void:
	# already done
	if _lasers_1_2_3_deactivated:
		return

	for laser in lasers:
		if laser.name in ["Laser1", "Laser2", "Laser3"]:
			laser.deactivate_laser()

# Deactivates Laser4 when all required buttons are pressed.
func deactivate_laser_4() -> void:
	# you already completed this, no need to deactivate again
	if _laser_4_deactivated:
		return

	for laser in lasers:
		if laser.name == "Laser4":
			laser.deactivate_laser()
