extends Area2D

@onready var animated_sprite = $AnimatedSprite2D

var static_body: StaticBody2D
var is_active: bool = true

func _ready() -> void:
	animated_sprite.play("closed")
	# Connect to the animation_finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Create a StaticBody2D to hold a collision shape for the door.
	static_body = StaticBody2D.new()
	add_child(static_body)
	var collision_shape = $CollisionShape2D.duplicate()
	static_body.add_child(collision_shape)

func _on_animation_finished() -> void:
	if not is_active and animated_sprite.animation == "door_open":
		animated_sprite.play("opened")

func _physics_process(delta: float) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	pass

func _on_body_exited(body: Node2D) -> void:
	pass

# This method permanently opens the door.
func deactivate_laser() -> void:
	is_active = false
	animated_sprite.play("door_open")

	# Disable the Area2D's collision shape.
	$CollisionShape2D.set_deferred("disabled", true)

	# Disable the collision shape on the StaticBody2D.
	if static_body and static_body.get_child_count() > 0:
		static_body.get_child(0).set_deferred("disabled", true)
