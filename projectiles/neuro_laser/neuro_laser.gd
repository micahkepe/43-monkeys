extends "res://projectiles/projectiles_script.gd"

func _ready() -> void:
	animation_name = "laser_default"

	# Call the parent _ready() to run the default projectile logic.
	super._ready()

	velocity = velocity
	scale = Vector2(3.5, 3.5)
