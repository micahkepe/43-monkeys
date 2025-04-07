extends CharacterBody2D
## Represents a 2D NPC enemy boid character that is part of a larger flock.
##
## Boids are autonomous agents that exhibit flocking behavior, such as alignment,
## cohesion, and separation. This script defines the behavior of a single boid
## character in the flock. This boid can be used or modified for use as a player
## character, enemy, or NPC. In addition to the basic separation, alignment, and
## cohesion, this script also includes wall avoidance behavior and a minimum
## speed to keep the boids in constant motion.
##
## Reference:
##		https://en.wikipedia.org/wiki/Boids

## The maximum speed of the boid.
@export var max_speed: float = 125.0

## The maximum force that can be applied to the boid.
@export var max_force: float = 150.0

## The distance to which the boid can see in its range of view.
@export var view_radius: float = 300.0

## The field of vision of the boid in degrees.
@export var view_angle_degrees: float = 270.0

## The distance at which the boid will avoid other boids.
@export var separation_distance: float = 35.0

## The weight of the separation force.
@export var weight_separation: float = 15.0

## The weight of the alignment force.
@export var weight_alignment: float = 1.0

## The weight of the cohesion force.
@export var weight_cohesion: float = 1.0

## The weight for wall avoidance.
@export var weight_avoidance: float = 2.0

## The length of the raycasts used for wall avoidance.
@export var raycast_length: float = 75.0

## The minimum speed of the boid.
@export var minimum_speed: float = 50.0

## The number of hits required to kill the boid.
@export var max_health: float = 5.0
@export var health: float = 5.0

## The animated sprite node for the boid.
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

## The hit box area node for the boid.
@onready var health_bar: ProgressBar = $HealthBar

## The right raycast node for wall avoidance.
@onready var _ray_right: RayCast2D = $RayRight

## The left raycast node for wall avoidance.
@onready var _ray_left: RayCast2D = $RayLeft

## The upward raycast node for wall avoidance.
@onready var _ray_up: RayCast2D = $RayUp

## The downward raycast node for wall avoidance.
@onready var _ray_down: RayCast2D = $RayDown

## Attack timer to control the rate of attacks.
var attack_timer: float = 0.0

## The damage dealt by the boid's attack.
@export var attack_damage: int = 1

## The cool down time between attacks (in seconds)
@export var attack_cooldown: float = 1.5

## The probability of the boid screaming when unaliving.
@export var scream_probability: float = 0.1

## The boid's current attacking state.
var is_attacking: bool = false

## The boid's current alive state.
var is_dead: bool = false


## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	# set default animation to "walk_down"
	_anim_sprite.play("walk_down")

	# Set up raycasts
	for ray in [_ray_right, _ray_left, _ray_up, _ray_down]:
		ray.target_position = ray.target_position.normalized() * raycast_length
		ray.enabled = true

	# Set initial velocity
	velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * max_speed

	# Initial health
	health_bar.max_value = max_health
	health_bar.value = health

## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer -= delta
	var target = _get_closest_target()
	var steering = Vector2.ZERO
	
	# Update the slow effect timer
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			_anim_sprite.modulate = Color(1, 1, 1, 1)

	# See if we have a target, else continue with boid-like movement
	if target:
		# seek out the target
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * max_speed
	else:
		# flocking behavior
		var neighbors = _get_neighbors()
		steering += _compute_separation(neighbors) * weight_separation
		steering += _compute_alignment(neighbors) * weight_alignment
		steering += _compute_cohesion(neighbors) * weight_cohesion

	# Add wall avoidance force
	steering += _compute_wall_avoidance() * weight_avoidance

	# Limit the steering force
	if steering.length() > max_force:
		steering = steering.normalized() * max_force

	velocity += steering * delta

	# Ensure minimum speed so that boid is always moving in some direction
	if velocity.length() < minimum_speed:
		velocity = velocity.normalized() * minimum_speed
	elif velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# Apply slow effect if active
	if is_slowed:
		velocity = velocity.normalized() * (max_speed * 0.65)
		
	move_and_slide()

	# Attack logic - Now checks for targets regardless of animation state
	if not is_dead and attack_timer <= 0:
		var overlapping_bodies = $HitBox.get_overlapping_bodies()
		var targets = []
		for body in overlapping_bodies:
			if body.is_in_group("player"):
				#print("=== HERE PLAYER")
				targets.append(body)
			elif body.is_in_group("troop"):
				print("==== HERE TROOP")
				if body.is_caged == true:
					targets.append(body)
				

		if targets.size() > 0:
			var closest_target = _get_closest_target_from_list(targets)
			if closest_target:
				_play_attack_animation(closest_target)
				if closest_target.has_method("take_damage"):
					closest_target.take_damage(attack_damage)
				attack_timer = attack_cooldown

	_update_animation()


## Helper function to get the closest target from a list
func _get_closest_target_from_list(target_list: Array) -> Node2D:
	if target_list.is_empty():
		return null
	var closest_target = target_list[0]
	var min_distance = global_position.distance_to(closest_target.global_position)
	for target in target_list.slice(1):
		var distance = global_position.distance_to(target.global_position)
		if distance < min_distance:
			closest_target = target
			min_distance = distance
	return closest_target

## Returns the closest target node within the boid's view radius.
## @returns Node2D - The closest target node within the boid's view radius.
func _get_closest_target() -> Node2D:
	var closest_target = null
	var min_distance = INF

	for group in ["player", "troop"]:
		for target in get_tree().get_nodes_in_group(group):
			var distance = global_position.distance_to(target.global_position)
			var direction = (target.global_position - global_position).normalized()

			# temporary line of sight raycast for targeting
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				global_position,
				target.global_position,
				1
			)
			var result = space_state.intersect_ray(query)

			if distance < view_radius and not result:
				var angle_between = velocity.angle_to(direction)

				if abs(angle_between) <= deg_to_rad(view_angle_degrees / 2.0):
					if distance < min_distance:
						closest_target = target
						min_distance = distance

	return closest_target


## Plays the attack animation and applies damage to the target node.
## @param target: Node2D - The target node to attack.
func _play_attack_animation(target: Node2D) -> void:
	var direction = (target.global_position - global_position).normalized()
	print_debug("Playing attack animation. Direction: ", direction)

	if abs(direction.x) > abs(direction.y):
		# Horizontal attack
		_anim_sprite.play("slash_right" if direction.x > 0 else "slash_left")
		print_debug("Playing horizontal attack animation: ", "slash_right" if direction.x > 0 else "slash_left")
	else:
		# Vertical attack
		_anim_sprite.play("slash_down" if direction.y > 0 else "slash_up")
		print_debug("Playing vertical attack animation: ", "slash_down" if direction.y > 0 else "slash_up")

	is_attacking = true


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
	if is_dead:
		return

	# If currently playing an attack animation, check if we should stop it
	if _anim_sprite.animation.begins_with("slash"):
		var overlapping_bodies = $HitBox.get_overlapping_bodies()
		var has_valid_target = false
		for body in overlapping_bodies:
			if body.is_in_group("player") or body.is_in_group("troop"):
				has_valid_target = true
				break

		if not has_valid_target:
			is_attacking = false
			# Transition back to movement animation
			if velocity.length() < minimum_speed:
				_anim_sprite.play("walk_down")  # Default animation
				return

	# Don't override attack animations that should continue
	if is_attacking:
		return

	# Simple animation logic using cardinal directions
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

## Handles the boid taking damage. If the boid has no more hits left, it will
## call the `_die()` function to handle its death.` You can specify the amount
## of damage to take.
## @param amount: float - The amount of damage to take.
func take_damage(amount: float) -> void:
	# decrement the number of hits required to kill the boid
	#print_debug("Boid taking damage:", amount, " | Hits left:", hits_to_kill)
	health -= amount

	health_bar.value = health

	print_debug("Health: ", health)

	# kill off the boid if it has no more hits left
	if health <= 0:
		_die()

	# momentarily recolor the boid to indicate damage
	_anim_sprite.modulate = Color(1, 0.5, 0.5, 1)
	await get_tree().create_timer(0.5).timeout
	if not is_slowed:
		_anim_sprite.modulate = Color(1, 1, 1, 1)

## Handles the boid's death.
func _die():
	# welp, this is it.
	is_dead = true
	health_bar.hide()

	# Stop any currently playing animation
	_anim_sprite.stop()

	## Disable physics and processing
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	# Disable the hit box to prevent further interactions
	if is_instance_valid($HitBox):
		$HitBox.set_deferred("monitoring", false)
		$HitBox.set_deferred("monitorable", false)

	print_debug("Boid died", self)
	print("==== BOID DIED")
	_anim_sprite.play("die")

	# Play a scream sound with a probability
	if randf() < scream_probability:
		$Sound/ScreamPlayer.play()

	# NOTE: The boid will be removed from the scene tree when the animation
	## finishes


## Handles the animation finished signal for the boid.
func _on_animated_sprite_2d_animation_finished() -> void:
	if _anim_sprite.animation == "die":
		if $Sound/ScreamPlayer.playing:
			await $Sound/ScreamPlayer.finished
		_anim_sprite.stop()
		queue_free()
	elif _anim_sprite.animation in ["slash_up", "slash_down", "slash_left", "slash_right"]:
		print_debug("Attack animation finished. Resetting is_attacking.")
		is_attacking = false
		_update_animation()


	elif _anim_sprite.animation in ["slash_up", "slash_down", "slash_left", "slash_right"]:
		print_debug("Attack animation finished. Resetting is_attacking.")
		is_attacking = false
		_update_animation()
		
		
# Variables to track slow effect state
var is_slowed: bool = false
var slow_timer: float = 0.0

func slow_down() -> void:
	is_slowed = true
	slow_timer = 5.0  # Effect lasts 5 seconds
	# Tint the sprite light blue
	_anim_sprite.modulate = Color(0.5, 0.8, 1, 1)
