extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
var static_body: StaticBody2D
var is_active: bool = true
var body_in_laser: Node2D = null

func _ready() -> void:
	animated_sprite.play("laser_on")

	# Create StaticBody2D for the laser
	static_body = StaticBody2D.new()
	add_child(static_body)

	# Copy the collision shape to the static body
	var collision_shape = $CollisionShape2D.duplicate()
	static_body.add_child(collision_shape)

func _physics_process(delta: float) -> void:
	if is_active and body_in_laser:
		# Deal damage to the player while they are in the laser
		if body_in_laser.is_in_group("player"):
			body_in_laser.take_damage(1.0 * delta)

func _on_body_entered(body: Node2D) -> void:
	if is_active and body.is_in_group("player"):
		print("Player entered the laser!")
		body_in_laser = body  # Track the player node
		body.take_damage(1.0)  # Initial damage on entry

func _on_body_exited(body: Node2D) -> void:
	if body == body_in_laser:
		body_in_laser = null  # Clear the reference when the player leaves

func deactivate_laser() -> void:
	is_active = false
	animated_sprite.play("laser_turn_off")
	animated_sprite.play("laser_off")

	# Disable collisions for Area2D
	$CollisionShape2D.set_deferred("disabled", true)

	# Disable collisions for StaticBody2D
	if static_body and static_body.get_child_count() > 0:
		static_body.get_child(0).set_deferred("disabled", true)
