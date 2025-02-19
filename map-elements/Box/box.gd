extends RigidBody2D
## A pushable box that can be moved by entities.

## The animated sprite for the box sprite.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Call on tree enter. Initializes all properties.
func _ready() -> void:
	# Set up physics properties
	gravity_scale = 0.0  # No gravity since we're top-down
	linear_damp = 5.0    # High damping to prevent sliding
	lock_rotation = true # Prevent the box from rotating
	contact_monitor = true
	max_contacts_reported = 4
	animated_sprite.play("banana_box")
