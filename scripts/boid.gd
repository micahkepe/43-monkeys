extends CharacterBody2D
## Represents a 2D boid character that is part of a larger flock.
##
## Boids are autonomous agents that exhibit flocking behavior, such as alignment,
## cohesion, and separation. This script defines the behavior of a single boid
## character in the flock. This boid can be used or modified for use as a player
## character, enemy, or NPC.

@export var max_speed: float = 200.0
@export var max_force: float = 100.0
@export var view_radius: float = 150.0
@export var view_angle_degrees: float = 270.0

@export var separation_distance: float = 25.0
@export var weight_separation: float = 1.5
@export var weight_alignment: float = 1.0
@export var weight_cohesion: float = 1.0
@export var weight_avoidance: float = 2.0  # Weight for wall avoidance
@export var raycast_length: float = 50.0  # How far ahead to check for walls
@export var minimum_speed: float = 50.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_right: RayCast2D = $RayRight
@onready var ray_left: RayCast2D = $RayLeft
@onready var ray_up: RayCast2D = $RayUp
@onready var ray_down: RayCast2D = $RayDown

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
    # Set up raycasts
    for ray in [ray_right, ray_left, ray_up, ray_down]:
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
    if ray_right.is_colliding():
        avoidance += Vector2.LEFT
    if ray_left.is_colliding():
        avoidance += Vector2.RIGHT
    if ray_up.is_colliding():
        avoidance += Vector2.DOWN
    if ray_down.is_colliding():
        avoidance += Vector2.UP

    if avoidance.length() > 0:
        avoidance = avoidance.normalized() * max_force

    return avoidance

func _update_animation() -> void:
    if velocity.length() < minimum_speed:
        anim_sprite.stop()
        return

    # Simplified animation logic using just cardinal directions
    var abs_x = abs(velocity.x)
    var abs_y = abs(velocity.y)

    if abs_x > abs_y:
        # Horizontal movement takes precedence
        if velocity.x > 0:
            anim_sprite.play("walk_right")
        else:
            anim_sprite.play("walk_left")
    else:
        # Vertical movement
        if velocity.y > 0:
            anim_sprite.play("walk_down")
        else:
            anim_sprite.play("walk_up")


## Returns an array of neighboring boids within the view radius and angle.
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
