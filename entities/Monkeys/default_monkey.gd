extends CharacterBody2D
## A single monkey in the monkey troop.
##
## Handles walking animation, collision avoidance, and enemy detection.

var locked: bool = false

## The AnimatedSprite2D node that plays the monkey's walking animation.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## RayCast nodes for collision avoidance
@onready var _raycast_front: RayCast2D = null
@onready var _raycast_left: RayCast2D = null
@onready var _raycast_right: RayCast2D = null

## Vision detection RayCast
@onready var _raycast_vision: RayCast2D = null

## RayCast vision left (short)
@onready var _raycast_vision_7_5_left: RayCast2D

## RayCast vision right (short)
@onready var _raycast_vision_7_5_right: RayCast2D

## RayCast vision left (long)
@onready var _raycast_vision_15_left: RayCast2D

## RayCast vision right (long)
@onready var _raycast_vision_15_right: RayCast2D

## The HealthBar node to display the monkey's health
@onready var health_bar = $HealthBar

## The PackedScene for the banana boomerang projectile
@export var banana_boomerang_scene: PackedScene

## The monkey's attack range
@export var attack_range: float = 400.0

## The monkey's attack cool down
var attack_timer: float = 0.0

## The time (in seconds) between attacks; the effective cooldown period
@export var attack_cooldown = 1.3

## Whether the monkey is currently detecting an enemy
var _enemy_in_sight: bool = false

## The detected enemy, if any
var _current_enemy = null

## Collision avoidance settings
@export var collision_avoidance_distance: float = 50.0
@export var collision_avoidance_angle: float = 45.0

## Vision detection settings
@export var vision_range: float = 200.0

## The range of the monkey's vision angle
@export var vision_angle: float = 60.0

## The maximum health of the monkey (in total heart units)
@export var max_health: int = 5

## The current health of the monkey
var current_health : int

## Cooldown for taking damage
var damage_cooldown: float = 1.5

## The current cooldown for taking damage
var current_cooldown: float = 0.0

## Whether the monkey is currently caged.
var is_caged: bool = false

## Track the last velocity of the monkey to check for changes.
var _last_velocity: Vector2 = Vector2.ZERO

@export var paralyzed: bool = false
var frozen_position: Vector2


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)
	health_bar.hide() # Hide the health bar initially

	# Set initial animation to "_walk_down"
	_animated_sprite.play("idle")

	# Setup RayCasts for collision avoidance
	_setup_collision_raycasts()

	# Setup RayCast for vision detection
	_setup_vision_raycast()


## Setup RayCasts for collision detection
func _setup_collision_raycasts() -> void:
	# Front RayCast
	_raycast_front = RayCast2D.new()
	_raycast_front.name = "RayCastFront"
	_raycast_front.enabled = true
	_raycast_front.target_position = Vector2(collision_avoidance_distance, 0)
	add_child(_raycast_front)

	# Left RayCast
	_raycast_left = RayCast2D.new()
	_raycast_left.name = "RayCastLeft"
	_raycast_left.enabled = true
	_raycast_left.target_position = Vector2(collision_avoidance_distance, 0).rotated(deg_to_rad(-collision_avoidance_angle))
	add_child(_raycast_left)

	# Right RayCast
	_raycast_right = RayCast2D.new()
	_raycast_right.name = "RayCastRight"
	_raycast_right.enabled = true
	_raycast_right.target_position = Vector2(collision_avoidance_distance, 0).rotated(deg_to_rad(collision_avoidance_angle))
	add_child(_raycast_right)

func _setup_vision_raycast() -> void:
	# Angles for vision rays
	var angles = {
		"0": 0.0,
		"-7.5": -7.5,
		"7.5": 7.5,
		"-15": -15.0,
		"15": 15.0
	}

	# Iterate and create raycasts dynamically
	for angle_label in angles.keys():
		var raycast = RayCast2D.new()
		raycast.name = "RayCastVision_" + angle_label
		raycast.enabled = true
		raycast.target_position = Vector2(vision_range, 0).rotated(deg_to_rad(angles[angle_label]))
		raycast.collision_mask = 2  # Assuming enemies are on layer 2
		add_child(raycast)

		# Assign raycast to its corresponding variable
		match angle_label:
			"0":
				_raycast_vision = raycast
			"-7.5":
				_raycast_vision_7_5_left = raycast
			"7.5":
				_raycast_vision_7_5_right = raycast
			"-15":
				_raycast_vision_15_left = raycast
			"15":
				_raycast_vision_15_right = raycast


## Collision avoidance logic
## Vision detection logic
func _check_vision_detection() -> void:
	var raycasts = [
		_raycast_vision,
		_raycast_vision_7_5_left,
		_raycast_vision_7_5_right,
		_raycast_vision_15_left,
		_raycast_vision_15_right
	]

	# Reset defaults
	_enemy_in_sight = false
	_current_enemy = null

	# Iterate through raycasts to check for collisions
	for raycast in raycasts:
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and global_position.distance_to(collider.global_position) <= attack_range:
				# Set enemy detected and break early
				_enemy_in_sight = true
				_current_enemy = collider.global_position
				break


## Physics processing to handle collision avoidance and vision
func _physics_process(_delta: float) -> void:
	if is_caged:
		velocity = Vector2.ZERO
		_stop_walk()
		return
	
	if paralyzed:
		# Override any external movement:
		global_position = frozen_position
		velocity = Vector2.ZERO
		_animated_sprite.pause()
		return
		
	# Check for enemy vision
	_check_vision_detection()

	# Manage attack cool down
	if attack_timer > 0:
		attack_timer -= _delta

	# Update the individual monkey's animation based on its own velocity.
	if locked:
		_stop_walk()
	else:
		# Update the individual monkey's animation based on its own velocity.
		if velocity == Vector2.ZERO:
			if _last_velocity != Vector2.ZERO:
				_stop_walk()
		else:
			if velocity.y > 0:
				_walk_down()
			elif velocity.y < 0:
				_walk_up()
			elif velocity.x < 0:
				_walk_left()
			elif velocity.x > 0:
				_walk_right()

	# Update last velocity
	_last_velocity = velocity

	# If an enemy is in sight, you can add attack logic here
	if _enemy_in_sight and _current_enemy and attack_timer <= 0:
		_throw_banana_at_position(_current_enemy)

	if current_cooldown > 0:
		current_cooldown -= _delta

## Utility method for the monkey to play the walk left animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_left() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_left")
	_update_vision_rays(Vector2(-vision_range, 0))


## Utility method for the monkey to play the walk right animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_right() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_right")
	_update_vision_rays(Vector2(vision_range, 0))


## Utility method for the monkey to play the walk up animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_up() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_up")
	_update_vision_rays(Vector2(0, -vision_range))


## Utility method for the monkey to play the walk down animation and adjust its
## raycasts accordingly.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _walk_down() -> void:
	if paralyzed:
		return
	_animated_sprite.play("walk_down")
	_update_vision_rays(Vector2(0, vision_range))


## Utility method for the monkey to stop animating. The monkey essentially is
## visually frozen in place. Resets the monkey's last velocity to ZERO.
##
## NOTE: Should not be called by the player. The individual monkey should be
## responsible for its animations.
func _stop_walk() -> void:
	if paralyzed:
		return
	_animated_sprite.pause()
	_last_velocity = Vector2.ZERO


## Helper function to update all vision ray casts
func _update_vision_rays(direction: Vector2) -> void:
	var angle_offsets = {
		_raycast_vision: 0.0,
		_raycast_vision_7_5_left: -7.5,
		_raycast_vision_7_5_right: 7.5,
		_raycast_vision_15_left: -15.0,
		_raycast_vision_15_right: 15.0
	}

	# Update each raycast's target_position with its respective angle
	for raycast in angle_offsets.keys():
		raycast.target_position = direction.rotated(deg_to_rad(angle_offsets[raycast]))


## Handles monkey death. Plays the death animation and cleans the monkey from
## the scene.
func _die() -> void:
	print_debug("Trying to _die for monkey", self)

	# Debug check if animation exists
	print_debug("Available animations:", _animated_sprite.sprite_frames.get_animation_names())
	print_debug("Current animation:", _animated_sprite.animation)

	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	# Hide the health bar
	if health_bar:
		health_bar.hide()
		print("Health bar hidden")

	# zero out the velocity to stop additional movement
	velocity = Vector2.ZERO

	var parent = get_parent()
	# Remove the monkey from the parent node to avoid having it continue to walk
	# and conflict with the die animation
	# parent --> the 'Monkeys' node
	# parent.get_parent() --> the level node
	if parent:
		parent.get_parent().remove_monkey(self)

	# Try to play death animation
	if _animated_sprite.sprite_frames.has_animation("die"):
			print_debug("Found die animation, attempting to play")
			_animated_sprite.stop()
			_animated_sprite.play("die")
	else:
			print_debug("ERROR: No die animation found!")
			queue_free()


## Takes the specified amount of damage from the monkey's health.
func take_damage(amount: float) -> void:
	if current_cooldown <= 0:
		current_health = max(0, current_health - amount)
		current_cooldown = damage_cooldown
		print_debug("Monkey took damage. Current health:", current_health)

		# momentarily recolor the monkey to indicate damage
		_animated_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_animated_sprite.modulate = Color(1, 1, 1, 1)

		if health_bar:
			health_bar.value = current_health

		if current_health <= 0:
			print_debug("Health <= 0, calling _die()")
			_die()

		health_bar.health = current_health


## Function to throw a banana at a specific position
## Function to throw a banana at a specific position
func _throw_banana_at_position(target_position: Vector2) -> void:
	if banana_boomerang_scene == null:
		return

	var projectile = banana_boomerang_scene.instantiate()
	if projectile == null:
		return
	
	# Tag the projectile as friendly
	projectile.set_meta("friendly", true)
	projectile.set_meta("owner", self)
	
	var shoot_direction = (target_position - global_position).normalized()
	var offset_distance = 30.0
	var spawn_offset = shoot_direction * offset_distance
	var spawn_global_position = global_position + spawn_offset
	print_debug("BANANA POS (global):", spawn_global_position)
	print_debug("MONKEY POS (global):", global_position)

	# Calculate the projectile velocity
	var bullet_speed = 550.0
	var main_velocity = shoot_direction * bullet_speed

	# Calculate the perpendicular component of the monkey's velocity
	var orth_factor = 0.75  # Scaling for the perpendicular component
	var parallel_velocity = velocity.dot(shoot_direction) * shoot_direction
	var perpendicular_velocity = velocity - parallel_velocity

	# Final velocity is a combination of the main velocity and a portion of the perpendicular velocity
	var final_velocity = main_velocity + (perpendicular_velocity * orth_factor)

	projectile.velocity = final_velocity
	projectile.scale = Vector2(1.5, 1.5)

	# Add the projectile to the 'Projectiles' node safely
	var projectiles_node = get_tree().get_current_scene().get_node("Projectiles") if get_tree().get_current_scene().has_node("Projectiles") else null
	if projectiles_node:
		# Convert the global spawn position to the local coordinate system of the 'Projectiles' node
		var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
		projectile.position = local_spawn_pos

		projectiles_node.call_deferred("add_child", projectile)
		print_debug("Projectile added to the Projectiles node at:", local_spawn_pos)
	else:
		print_debug("Projectiles node not found. Projectile not spawned.")

	# Reset the attack cooldown
	attack_timer = attack_cooldown

	# Play attack animation or effects if needed
	print("Banana thrown at position:", target_position)


## Called when the monkey's AnimatedSprite2D node finishes playing an animation.
## If the animation is "die", the monkey is queued for deletion.
func _on_animated_sprite_2d_animation_finished() -> void:
	if _animated_sprite.animation == "die":
		_animated_sprite.stop()
		queue_free()

func heal(amount: float) -> void:
	# Increase current health but do not exceed max_health.
	current_health = min(max_health, current_health + amount)

	# Update the health bar if it exists.
	if health_bar:
		health_bar.value = current_health
		health_bar.health = current_health  # If you use a separate property for health

	# Apply a light blue tint to indicate healing.
	_animated_sprite.modulate = Color(0.7, 0.7, 1, 1)  # Light blue tint
	await get_tree().create_timer(0.5).timeout  # Wait 0.5 seconds
	_animated_sprite.modulate = Color(1, 1, 1, 1)    # Reset to normal color

	print_debug("Monkey healed by ", amount, ". Current health: ", current_health)
	
	
func apply_blindness(seconds: float) -> void:
	var prev_range = attack_range
	attack_range = 0
	
	# momentarily recolor the monkey to indicate damage
	_animated_sprite.modulate = Color(1, 0.55, 0, 1)
	await get_tree().create_timer(seconds).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)
	attack_range = prev_range
	
func paralyze(duration: float) -> void:
	paralyzed = true
	frozen_position = global_position  # Save the current position
	_animated_sprite.modulate = Color(0.7, 0.7, 1, 1)  # Light blue tint
	await get_tree().create_timer(duration).timeout
	_animated_sprite.modulate = Color(1, 1, 1, 1)
	paralyzed = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Handle interactions with Area2D nodes (e.g., projectiles)
	if area.is_in_group("projectiles"):
		# Ignore friendly projectiles (those spawned by player or troop)
		if area.get_meta("friendly", false):
			return  # Skip damage from this monkey's own banana projectiles
		# Apply damage from non-friendly (enemy) projectiles
		var damage = 1.0  # Default damage if no specific value is provided
		if area.has_method("get_damage"):
			damage = area.get_damage()
		elif "damage" in area:  # Check if the projectile has a damage property
			damage = area.damage
		take_damage(damage)
		print_debug("Monkey hit by projectile area: ", area.name, " for damage: ", damage)
		# Optionally remove the projectile after hitting
		if area.has_method("queue_free"):
			area.queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Handle interactions with physics bodies (e.g., enemies)
	if body.is_in_group("player") or body.is_in_group("troop"):
		print_debug("Monkey collided with: ", body.name)
	elif body.is_in_group("player") or body.is_in_group("troop"):
		# Optional: Handle player or troop collision (e.g., ignore or push)
		print_debug("Monkey collided with: ", body.name)

func _on_hitbox_body_exited(body: Node2D) -> void:
	# Handle when a body exits the hitbox
	if body.is_in_group("boids"):
		print_debug("Boid exited monkey hitbox: ", body.name)
	elif body.is_in_group("player") or body.is_in_group("troop"):
		print_debug("Player or troop exited monkey hitbox: ", body.name)
