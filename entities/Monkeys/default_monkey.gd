extends CharacterBody2D
## A single monkey in the monkey troop.
##
## Handles walking animation, collision avoidance, and enemy detection.

## The AnimatedSprite2D node that plays the monkey's walking animation.
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## RayCast nodes for collision avoidance
@onready var _raycast_front: RayCast2D = $RayCastFront
@onready var _raycast_left: RayCast2D = $RayCastLeft
@onready var _raycast_right: RayCast2D = $RayCastRight

## Vision detection RayCast
@onready var _raycast_vision: RayCast2D = $RayCastVision
@onready var _raycast_vision_7_5_left: RayCast2D
@onready var _raycast_vision_7_5_right: RayCast2D
@onready var _raycast_vision_15_left: RayCast2D
@onready var _raycast_vision_15_right: RayCast2D


@onready var health_bar = $HealthBar

@export var banana_boomerang_scene: PackedScene
@export var attack_range: float = 400.0         # Distance to throw bananas
var attack_timer: float       # Time between throws
@export var attack_cooldown = 0.8


## Whether the monkey is currently detecting an enemy
var _enemy_in_sight: bool = false

## The detected enemy, if any
var _current_enemy = null

## Collision avoidance settings
@export var collision_avoidance_distance: float = 50.0
@export var collision_avoidance_angle: float = 45.0

## Vision detection settings
@export var vision_range: float = 200.0
@export var vision_angle: float = 60.0

@export var max_health: int = 5
var current_health : int
var damage_cooldown: float = 1.5 
var current_cooldown: float = 0.0

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_health = max_health
	health_bar.init_health(current_health)
	
	# Setup RayCasts for collision avoidance
	_setup_collision_raycasts()

	# Setup RayCast for vision detection
	_setup_vision_raycast()
	
	self.connect("body_entered", Callable(self, "_on_body_entered"))

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
func _check_collision_avoidance() -> Vector2:
	var avoidance_vector = Vector2.ZERO

	# Check front RayCast
	if _raycast_front.is_colliding():
		avoidance_vector += Vector2(-1, 0)

	# Check left RayCast
	if _raycast_left.is_colliding():
		avoidance_vector += Vector2(0, -1)

	# Check right RayCast
	if _raycast_right.is_colliding():
		avoidance_vector += Vector2(0, 1)

	return avoidance_vector.normalized()

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
	# Check for collision avoidance
	var avoidance_vector = _check_collision_avoidance()

	# Check for enemy vision
	_check_vision_detection()

	# Manage attack cooldown
	if attack_timer > 0:
		attack_timer -= _delta
	
	
	# If an enemy is in sight, you can add attack logic here
	if _enemy_in_sight and _current_enemy and attack_timer <= 0:
		_throw_banana_at_position(_current_enemy)
	
	if current_cooldown > 0:
		current_cooldown -= _delta

## Called by the Player when the player is moving left
func walk_left() -> void:
	_animated_sprite.play("walk_left")
	_update_vision_rays(Vector2(-vision_range, 0))

## Called by the Player when the player is moving right
func walk_right() -> void:
	_animated_sprite.play("walk_right")
	_update_vision_rays(Vector2(vision_range, 0))

## Called by the Player when the player is moving up
func walk_up() -> void:
	_animated_sprite.play("walk_up")
	_update_vision_rays(Vector2(0, -vision_range))

## Called by the Player when the player is moving down
func walk_down() -> void:
	_animated_sprite.play("walk_down")
	_update_vision_rays(Vector2(0, vision_range))

## Helper function to update all vision raycasts
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


## Called by the Player when no swarm-translation key is pressed (monkey idle)
func stop_walk() -> void:
	_animated_sprite.stop()

func die() -> void:
	if get_parent():
		get_parent().get_parent().remove_monkey(self)
	# Implement death behavior
	queue_free()
	
func take_damage(amount: float) -> void:
	if current_cooldown <= 0:
		current_health = max(0, current_health - amount)
		current_cooldown = damage_cooldown
		if health_bar:
			health_bar.value = current_health
		
		if current_health <= 0:
			die()
			
		health_bar.health = current_health
		

## Function to throw a banana at a specific position
## Function to throw a banana at a specific position
func _throw_banana_at_position(target_position: Vector2) -> void:
	if banana_boomerang_scene == null:
		return

	var projectile = banana_boomerang_scene.instantiate()
	if projectile == null:
		return

	var shoot_direction = (target_position - global_position).normalized()
	var offset_distance = 30.0
	var spawn_offset = shoot_direction * offset_distance
	var spawn_global_position = global_position + spawn_offset
	print("BANANA POS (global):", spawn_global_position)
	print("MONKEY POS (global):", global_position)

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
		print("Projectile added to the Projectiles node at:", local_spawn_pos)
	else:
		print_debug("Projectiles node not found. Projectile not spawned.")

	# Reset the attack cooldown
	attack_timer = attack_cooldown

	# Play attack animation or effects if needed
	print("Banana thrown at position:", target_position)
