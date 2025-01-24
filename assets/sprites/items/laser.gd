extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
var static_body: StaticBody2D
var is_active: bool = true

func _ready() -> void:
	animated_sprite.play("laser_on")
	# Create StaticBody2D
	static_body = StaticBody2D.new()
	add_child(static_body)
	# Copy the collision shape from Area2D to StaticBody2D
	var collision_shape = $CollisionShape2D.duplicate()
	static_body.add_child(collision_shape)

func _on_body_entered(body: Node2D) -> void:
	print("collided")

func _on_body_exited(body: Node2D) -> void:
	print("exited")
	
func deactivate_laser() -> void:
	is_active = false
	animated_sprite.play("laser_turn_off")
	animated_sprite.play("laser_off")
	
	# Disable both collision shapes
	$CollisionShape2D.set_deferred("disabled", true)  # Area2D collision
	
	# Make sure we have the static body and its collision
	if static_body and static_body.get_child_count() > 0:
		static_body.get_child(0).set_deferred("disabled", true)  # StaticBody2D collision
	
	# Optional: Make the static body inactive
	static_body.set_physics_process(false)
