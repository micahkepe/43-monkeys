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

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
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

## Setup RayCast for vision detection
func _setup_vision_raycast() -> void:
	_raycast_vision = RayCast2D.new()
	_raycast_vision.name = "RayCastVision"
	_raycast_vision.enabled = true
	_raycast_vision.target_position = Vector2(vision_range, 0)
	_raycast_vision.collision_mask = 2  # Assuming enemies are on layer 2
	add_child(_raycast_vision)

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
	if _raycast_vision.is_colliding():
		var collider = _raycast_vision.get_collider()
		if collider.is_in_group("enemies"):
			_enemy_in_sight = true
			_current_enemy = collider
		else:
			_enemy_in_sight = false
			_current_enemy = null
	else:
		_enemy_in_sight = false
		_current_enemy = null

## Physics processing to handle collision avoidance and vision
func _physics_process(_delta: float) -> void:
	# Check for collision avoidance
	var avoidance_vector = _check_collision_avoidance()

	# Check for enemy vision
	_check_vision_detection()

	# If an enemy is in sight, you can add attack logic here
	if _enemy_in_sight and _current_enemy:
		# Example attack or approach logic
		# This would depend on your specific game mechanics
		pass

## Called by the Player when the player is moving left
func walk_left() -> void:
	_animated_sprite.play("walk_left")
	# Rotate vision RayCast to match direction
	_raycast_vision.target_position = Vector2(-vision_range, 0)

## Called by the Player when the player is moving right
func walk_right() -> void:
	_animated_sprite.play("walk_right")
	_raycast_vision.target_position = Vector2(vision_range, 0)

## Called by the Player when the player is moving up
func walk_up() -> void:
	_animated_sprite.play("walk_up")
	_raycast_vision.target_position = Vector2(0, -vision_range)

## Called by the Player when the player is moving down
func walk_down() -> void:
	_animated_sprite.play("walk_down")
	_raycast_vision.target_position = Vector2(0, vision_range)

## Called by the Player when no swarm-translation key is pressed (monkey idle)
func stop_walk() -> void:
	_animated_sprite.stop()
