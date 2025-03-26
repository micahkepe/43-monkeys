extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	# Override default values for the banana projectile.
	animation_name = "orb_pulse"
	use_shadow = true
	
	print("wizard orb at:", global_position)
	# Call the parent _ready() to run the default projectile logic.
	super._ready()
	
	scale = Vector2(3.5, 3.5)
