extends Node2D


@onready var button = $"Buttons"  # Use the exact node name from your scene
@onready var laser = $"Laser"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# First verify the nodes are found
	if button and laser:
		button.connect("button_pressed", Callable(laser, "deactivate_laser"))
	else:
		print("Warning: Button or Laser node not found!")
		if !button:
			print("Button node missing")
		if !laser:
			print("Laser node missing")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
