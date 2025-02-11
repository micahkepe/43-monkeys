extends Node2D

# Get all buttons and lasers from the scene tree.
@onready var buttons = $World/Buttons.get_children()
@onready var lasers = $ForegroundTiles/Lasers.get_children()

# A dictionary to track the state of each button.
var button_states = {}

func _ready() -> void:
	for button in buttons:
		# Initialize each button's state as false (not pressed)
		button_states[button] = false
		# Connect the button's signal to our callback.
		# (Note: we bind the button node so our callback knows which button sent the signal.)
		button.connect("button_state_changed", Callable(self, "on_button_state_changed").bind(button))

# This callback is called whenever a button's state changes.
func on_button_state_changed(is_pressed: bool, button: Node) -> void:
	button_states[button] = is_pressed
	
	# Check if both Buttons1 and Buttons2 are pressed.
	if are_buttons_1_2_pressed():
		deactivate_lasers_1_2_3()
	
	# Check if Buttons3,4,5,6 are all pressed
	if are_buttons_3_4_5_6_pressed():
		deactivate_laser_4()

# Returns true only if both Buttons1 and Buttons2 are pressed.
func are_buttons_1_2_pressed() -> bool:
	for button in button_states.keys():
		if button.name in ["Buttons1", "Buttons2"]:
			if not button_states[button]:
				return false
	return true

# Returns true only if Buttons3,4,5,6 are all pressed.
func are_buttons_3_4_5_6_pressed() -> bool:
	for button in button_states.keys():
		if button.name in ["Buttons3", "Buttons4", "Buttons5", "Buttons6"]:
			if not button_states[button]:
				return false
	return true

# Iterates through all lasers and deactivates Laser1, Laser2, and Laser3.
func deactivate_lasers_1_2_3() -> void:
	for laser in lasers:
		if laser.name in ["Laser1", "Laser2", "Laser3"]:
			laser.deactivate_laser()

# Deactivates Laser4 when all required buttons are pressed.
func deactivate_laser_4() -> void:
	for laser in lasers:
		if laser.name == "Laser4":
			laser.deactivate_laser()
