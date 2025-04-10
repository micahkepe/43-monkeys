extends Area2D

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _collision_shape = $CollisionShape2D

# Set to store all bodies currently inside the laser
var bodies_in_laser: Array = []

# Damage interval
@export var damage_interval: float = 1.0  # Time in seconds between damage ticks
var damage_timer: float = 0.0  # Tracks the elapsed time since the last damage tick

func _ready() -> void:
	# Disable the collision box initially
	#_collision_shape.disabled = true

	# Play the start_up animation
	_animated_sprite.play("idle")
	
	# Automatically free this node after 5 seconds
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _on_body_entered(body: Node) -> void:
	print("=== IM IN THERE")
	# Add the body to the set of tracked bodies
	if body.has_method("take_damage"):
		bodies_in_laser.append(body)

func _on_body_exited(body: Node) -> void:
	# Remove the body from the set when it exits the laser
	bodies_in_laser.erase(body)

func _process(delta: float) -> void:
	# Only deal damage if the laser is in the "idle" state
	if _animated_sprite.animation != "idle":
		return

	# Update the damage timer
	damage_timer += delta

	# If the timer exceeds the damage interval, deal damage
	if damage_timer >= damage_interval:
		damage_timer = 0.0  # Reset the timer

		# Deal damage to all bodies currently in the laser
		for body in bodies_in_laser:
			if body and body.has_method("take_damage"):  # Ensure the body still exists
				body.take_damage(2.0)

func _physics_process(delta: float) -> void:
		print("BEAM AT: ", global_position)
