extends Node2D

@onready var buttons = $Buttons.get_children()
@onready var lasers = $Lasers.get_children()

var active_buttons = 0

func _ready() -> void:
	# Connect button signals
	for button in buttons:
		button.connect("button_state_changed", Callable(self, "_on_button_state_changed"))

func _on_button_state_changed(is_pressed: bool) -> void:
	active_buttons += 1 if is_pressed else -1

	if active_buttons == 3:
		deactivate_laser("Laser3") 

func deactivate_laser(laser_name: String) -> void:
	for laser in lasers:
		if laser.name == laser_name:
			laser.deactivate_laser()
