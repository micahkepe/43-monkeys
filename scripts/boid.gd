extends CharacterBody2D
## Represents a 2D boid character that is part of a larger flock.
##
## Boids are autonomous agents that exhibit flocking behavior, such as alignment,
## cohesion, and separation. This script defines the behavior of a single boid
## character in the flock. This boid can be used or modified for use as a player
## character, enemy, or NPC. In addition to the basic separation, alignment, and
## cohesion, this script also includes wall avoidance behavior and a minimum
## speed to keep the boids in constant motion.

#####################################
## TUNEABLE HYPERPARAMETERS
#####################################

## The maximum speed of the boid.
@export var max_speed: float = 200.0

## The maxiumum force that can be applied to the boid.
@export var max_force: float = 100.0

## The distance to which the boid can see in its range of view.
@export var view_radius: float = 150.0

## The field of vision of the boid in degrees.
@export var view_angle_degrees: float = 270.0

## The distance at which the boid will avoid other boids.
@export var separation_distance: float = 25.0

## The weight of the separation force.
@export var weight_separation: float = 1.5

## The weight of the alignment force.
@export var weight_alignment: float = 1.0

## The weight of the cohesion force.
@export var weight_cohesion: float = 1.0

## The weight for wall avoidance.
@export var weight_avoidance: float = 2.0

## The length of the raycasts used for wall avoidance.
@export var raycast_length: float = 50.0

## The minimum speed of the boid.
@export var minimum_speed: float = 50.0


#####################################
## INTERNAL VARIABLES
#####################################

## The animated sprite node for the boid.
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

## The right raycast node for wall avoidance.
@onready var _ray_right: RayCast2D = $RayRight

## The left raycast node for wall avoidance.
@onready var _ray_left: RayCast2D = $RayLeft

## The upward raycast node for wall avoidance.
@onready var _ray_up: RayCast2D = $RayUp

## The downward raycast node for wall avoidance.
@onready var _ray_down: RayCast2D = $RayDown


#####################################
## METHODS
#####################################

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	# Set up raycasts
		for ray in [_ray_right, _ray_left, _ray_up, _ray_down]:
			ray.target_position = ray.target_position.normalized() * raycast_length
			ray.enabled = true

		# Set initial velocity
		velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * max_speed


## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(delta: float) -> void:
	var neighbors = _get_neighbors()
	var force_separation = _compute_separation(neighbors) * weight_separation
	var force_alignment = _compute_alignment(neighbors) * weight_alignment
	var force_cohesion = _compute_cohesion(neighbors) * weight_cohesion
	var force_avoidance = _compute_wall_avoidance() * weight_avoidance

	var steering = force_separation + force_alignment + force_cohesion + force_avoidance
	if steering.length() > max_force:
		steering = steering.normalized() * max_force

	velocity += steering * delta

	# Ensure minimum speed so that boid is always moving in some direction
	if velocity.length() < minimum_speed:
		velocity = velocity.normalized() * minimum_speed
	elif velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	move_and_slide()
	_update_animation()


## Computes the avoidance force to avoid walls.
## Returns a Vector2 representing the avoidance force.
func _compute_wall_avoidance() -> Vector2:
	var avoidance = Vector2.ZERO

	# Check each raycast and add avoidance force if we detect a wall
	if _ray_right.is_colliding():
		avoidance += Vector2.LEFT
	if _ray_left.is_colliding():
		avoidance += Vector2.RIGHT
	if _ray_up.is_colliding():
		avoidance += Vector2.DOWN
	if _ray_down.is_colliding():
		avoidance += Vector2.UP

	if avoidance.length() > 0:
		avoidance = avoidance.normalized() * max_force

	return avoidance


## Updates the boid's animation based on its velocity.
## The boid will play the appropriate animation based on its velocity.
func _update_animation() -> void:
	if velocity.length() < minimum_speed:
		_anim_sprite.stop()
		return

	# Simple animation logic using cardinal directions
	# TODO: make this more sophisticated
	var abs_x = abs(velocity.x)
	var abs_y = abs(velocity.y)

	if abs_x > abs_y:
		# Horizontal movement takes precedence
			if velocity.x > 0:
				_anim_sprite.play("walk_right")
			else:
				_anim_sprite.play("walk_left")
	else:
		# Vertical movement
			if velocity.y > 0:
				_anim_sprite.play("walk_down")
			else:
				_anim_sprite.play("walk_up")


## Returns an array of neighboring boids within the view radius and angle.
## Neighbors are other boids in the same group as this boid.
## @return Array - An array of neighboring boids.
func _get_neighbors() -> Array:
	var all_boids = get_tree().get_nodes_in_group("boids")
	var neighbors := []

	for b in all_boids:
		if b == self:
			continue

		var to_other = b.global_position - global_position
		if to_other.length() > view_radius:
			continue

		var angle_between = velocity.angle_to(to_other)
		if abs(angle_between) > deg_to_rad(view_angle_degrees / 2.0):
			continue

		neighbors.append(b)

	return neighbors


## Computes the separation force to avoid crowding other boids.
## @param neighbors: Array - An array of neighboring boids.
## @return Vector2 - A Vector2 representing the separation force.
func _compute_separation(neighbors: Array) -> Vector2:
	if neighbors.is_empty():
		return Vector2.ZERO

	var steer = Vector2.ZERO
	for b in neighbors:
		var diff = global_position - b.global_position
		var dist = diff.length()
		if dist < separation_distance and dist > 0:
			diff = diff.normalized() / dist
			steer += diff

	if steer.length() > 0:
		steer = steer.normalized() * max_force

	return steer


## Computes the alignment force to match the velocity of neighboring boids.
## @param neighbors: Array - An array of neighboring boids.
## @return Vector2 - A Vector2 representing the alignment force.
func _compute_alignment(neighbors: Array) -> Vector2:
	if neighbors.is_empty():
		return Vector2.ZERO

	var avg_vel = Vector2.ZERO
	for b in neighbors:
		if b is CharacterBody2D:
			avg_vel += b.velocity
	avg_vel /= neighbors.size()

	var steer = avg_vel - velocity
	if steer.length() > 0:
		steer = steer.normalized() * max_force

	return steer


## Computes the cohesion force to move toward the center of mass of neighboring
## boids.
## @param neighbors: Array - An array of neighboring boids.
## @return Vector2 - A Vector2 representing the cohesion force.
func _compute_cohesion(neighbors: Array) -> Vector2:
	if neighbors.is_empty():
		return Vector2.ZERO

	var avg_pos = Vector2.ZERO
	for b in neighbors:
		avg_pos += b.global_position
	avg_pos /= neighbors.size()

	var desired = avg_pos - global_position
	if desired.length() > 0:
		desired = desired.normalized() * max_speed

	var steer = desired - velocity
	if steer.length() > max_force:
		steer = steer.normalized() * max_force

	return steer
