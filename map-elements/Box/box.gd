extends RigidBody2D
## A pushable box that can be moved by entities.

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 5.0
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 4
	animated_sprite.play("banana_box")
	add_to_group("moveables")
	print_debug("Box collision_layer: ", collision_layer, " | collision_mask: ", collision_mask)

func _on_body_entered(body: Node) -> void:
	print_debug("Box hit by: ", body.name)
