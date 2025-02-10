extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var push_force = 300.0       # Strength of the push impulse
var friction = 3.0           # Friction factor
var push_cooldown = 0.2      # Cooldown before the box can be pushed again
var can_be_pushed = true
var last_push_direction = Vector2.ZERO
const MAX_VELOCITY = 1000.0  # Maximum velocity cap

func _ready() -> void:
	animated_sprite.play("banana_box")
	print("Box script ready!")

func _physics_process(delta: float) -> void:
	# Process movement using the current velocity
	move_and_slide()
	
	# Loop through collisions from move_and_slide()
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		# Check if the collider is a Node2D and in one of the target groups
		if collider is Node2D and (collider.is_in_group("player") or collider.is_in_group("troop") or collider.is_in_group("boids")):
			apply_push(collider)
	
	# If any collision occurred, reduce the current velocity a bit
	if get_slide_collision_count() > 0:
		velocity *= 0.8
	
	# Apply friction/damping: reduce friction when moving fast
	var current_speed = velocity.length()
	if current_speed > 100:
		velocity = velocity.lerp(Vector2.ZERO, friction * 0.5 * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	
	# Cap the velocity to prevent it from going too high
	if velocity.length() > MAX_VELOCITY:
		velocity = velocity.normalized() * MAX_VELOCITY

func apply_push(body: Node2D) -> void:
	if not can_be_pushed:
		return
	
	# Confirm the body is one of the desired types by checking its group membership
	if body.is_in_group("player") or body.is_in_group("troop") or body.is_in_group("boids"):
		# Determine the push direction from the colliding body to this box
		var push_direction = (global_position - body.global_position).normalized()
		
		# If the new push is roughly in the same direction as the previous one, boost the force
		var direction_similarity = push_direction.dot(last_push_direction)
		var force_multiplier = 1.0
		if direction_similarity > 0.7:
			force_multiplier = 1.5
		
		# Compute a force that falls off with distance (within 100 pixels)
		var distance = global_position.distance_to(body.global_position)
		var adjusted_force = push_force * force_multiplier * (1.0 - clamp(distance / 100.0, 0.0, 1.0))
		
		# Debug print so you can verify values in the output
		print("Applying push: force =", adjusted_force, ", direction =", push_direction, ", distance =", distance)
		
		# Add the calculated push impulse to the box's velocity
		velocity += push_direction * adjusted_force
		
		# Update the last push direction for the next calculation
		last_push_direction = push_direction
		
		# Start the cooldown so the box isn't pushed again immediately
		can_be_pushed = false
		get_tree().create_timer(push_cooldown).timeout.connect(func():
			can_be_pushed = true
			last_push_direction = Vector2.ZERO  # Reset the push direction after cooldown
		)
