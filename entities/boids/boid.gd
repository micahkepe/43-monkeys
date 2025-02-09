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

## The maxiumum force that can be applied to the boid.
@export var max_force: float = 150.0

## The distance to which the boid can see in its range of view.
@export var view_radius: float = 300.0

## The field of vision of the boid in degrees.
@export var view_angle_degrees: float = 270.0

## The distance at which the boid will avoid other boids.
@export var separation_distance: float = 25.0

## The weight of the separation force.
@export var weight_separation: float = 2.0

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
@export var hits_to_kill: int = 2

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

## Attack timer to control the rate of attacks.
var attack_timer: float = 0.0

@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.5

var is_attacking: bool = false

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

	# Connect the animation finished signal to the handler
	_anim_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

	$HitBox.connect("area_entered", Callable(self, "_on_hit_box_area_entered"))
	$HitBox.connect("body_entered", Callable(self, "_on_hit_box_body_entered"))
	$HitBox.connect("body_exited", Callable(self, "_on_hit_box_body_exited"))

## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_attacking or _anim_sprite.animation.begins_with("slash"):
		return

	attack_timer -= delta
	var target = _get_closest_target()
	var steering = Vector2.ZERO

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

	move_and_slide()
	_update_animation()


## Returns the closest target node within the boid's view radius.
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

	if is_attacking or _anim_sprite.animation.begins_with("slash"):
		return

	# Ensure the boid is always moving and playing an animation
	if velocity.length() < minimum_speed:
		# If velocity is too low, set a default animation
		# _anim_sprite.play("walk_down")
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
	print_debug("Boid taking damage:", amount, " | Hits left:", hits_to_kill)

	if hits_to_kill > 0:
		if amount > 1:
			hits_to_kill -= int(amount)
		else:
			hits_to_kill -= 1

		print_debug("Hits to kill: ", hits_to_kill)

		# kill off the boid if it has no more hits left
		if hits_to_kill == 0:
			_die()

		# momentarily recolor the monkey to indicate damage
		_anim_sprite.modulate = Color(1, 0.5, 0.5, 1)
		await get_tree().create_timer(0.5).timeout
		_anim_sprite.modulate = Color(1, 1, 1, 1)

## Handles the boid's death.
func _die():
	is_dead = true

	## Disable physics and processing
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0

	# Disable the hitbox to prevent further interactions
	if is_instance_valid($HitBox):
		$HitBox.set_deferred("monitoring", false)
		$HitBox.set_deferred("monitorable", false)

	print_debug("Boid died", self)
	_anim_sprite.play("die")

	# NOTE: The boid will be removed from the scene tree when the animation
	## finishes

func _handle_hit(hit: Node) -> void:
	if hit.is_in_group("projectiles"):
		print_debug("Boid hit by: ", hit)
		take_damage(1.0)
		hit.queue_free()

	elif attack_timer <= 0 and (hit.is_in_group("player") or hit.is_in_group("troop")):
		print_debug("Attacking target:", hit)
		_play_attack_animation(hit)

		if hit.has_method("take_damage"):
			print_debug("Applying damage to target: ", hit.name)
			hit.take_damage(attack_damage)
		attack_timer = attack_cooldown

func _on_hit_box_area_entered(area: Area2D) -> void:
	_handle_hit(area)

func _on_hit_box_body_entered(body: Node) -> void:
	_handle_hit(body)


## Handles the animation finished signal for the boid.
func _on_animated_sprite_2d_animation_finished() -> void:
	if _anim_sprite.animation == "die":
		_anim_sprite.stop()
		queue_free()

	elif _anim_sprite.animation in ["slash_up", "slash_down", "slash_left", "slash_right"]:
		print_debug("Attack animation finished. Resetting is_attacking.")
		is_attacking = false
		_update_animation()


## Handles the hit box area entered signal.
func _on_hit_box_body_exited(body:Node2D) -> void:
	if is_dead:
		return

	print_debug("Boid hit box exited body: ", body)
	is_attacking = false

	# Reset the animation to the walk animation
	_anim_sprite.play("walk_down")

