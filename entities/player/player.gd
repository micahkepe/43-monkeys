extends CharacterBody2D
## Represents a 2D player character in the game.
##
## The player character is controlled by the player and can move in four
## directions (up, down, left, right). The player's movement is controlled by
## input mappings defined in the project settings for the following actions:
## "ui_right" "ui_left" "ui_up" "ui_down"
##
## @tutorial: https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html

## The AnimatedSprite2D node that displays the player's sprite.
@onready var _animated_sprite = $AnimatedSprite2D

## The base speed at which the player moves
@export
var speed: float = 300.0

## The player's current health
@export
var health: int = 100

## The multiplier applied to speed when sprinting
@export
var sprint_multiplier: float = 1.5

## The current shoot cooldown
var _current_shoot_cooldown: float

## The time taken between each shot
@export
var shoot_cooldown_duration: float = 0.25

## Bannana boomerang scene
var banana_boomerang = preload("res://projectiles/banana-boomerang/banana_boomerang.tscn")

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	## Set the player's initial animation
	_animated_sprite.play("walk_down")


## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(_delta: float) -> void:
	## The player's current velocity
	var input_velocity = Vector2.ZERO

	# Get current movement speed (base or sprint)
	var current_speed = speed * sprint_multiplier if Input.is_key_pressed(KEY_SHIFT) else speed

	# Movement input
	if Input.is_action_pressed("ui_right"):
		input_velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		input_velocity.x -= 1
	if Input.is_action_pressed("ui_up"):
		input_velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_velocity.y += 1

	# Normalize diagonal movement
	if input_velocity != Vector2.ZERO:
		input_velocity = input_velocity.normalized()

	## Set animation based on movement direction
	if input_velocity.y < 0:
		_animated_sprite.play("walk_up")
	elif input_velocity.y > 0:
		_animated_sprite.play("walk_down")
	elif input_velocity.x > 0:
		_animated_sprite.play("walk_right")
	elif input_velocity.x < 0:
		_animated_sprite.play("walk_left")
	else:
		_animated_sprite.stop()

	## Set the velocity and move the character
	velocity = input_velocity * current_speed
	move_and_slide()

	# Decrement the shoot cooldown
	if _current_shoot_cooldown > 0.0:
		_current_shoot_cooldown -= _delta
		if _current_shoot_cooldown < 0.0:
			_current_shoot_cooldown = 0.0

	#Handle banana shooting
	handle_shooting()


func handle_shooting() -> void:
# Depending on which button is pressed, pass a direction vector
# If we are still in the cooldown, do nothing
	if _current_shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed("shoot_up"):
		print()
		spawn_projectile(Vector2.UP)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_down"):
		spawn_projectile(Vector2.DOWN)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_left"):
		spawn_projectile(Vector2.LEFT)
		_current_shoot_cooldown = shoot_cooldown_duration
	elif Input.is_action_pressed("shoot_right"):
		spawn_projectile(Vector2.RIGHT)
		_current_shoot_cooldown = shoot_cooldown_duration


## Spawns a projectile in the given direction.
## @param shoot_direction: Vector2 - The direction in which to shoot the
## projectile.
func spawn_projectile(shoot_direction: Vector2) -> void:
	if banana_boomerang == null:
		return

	if not banana_boomerang.can_instantiate():
		return

	var projectile = banana_boomerang.instantiate()

	if projectile == null:
		return

	var offset_distance = 90.0
	var spawn_offset = shoot_direction.normalized() * offset_distance
	var spawn_global_position = global_position + spawn_offset

	# calculating velocity
	var bullet_speed = 375.0
	var shot_dir = shoot_direction.normalized()
	var main_vel = shot_dir * bullet_speed

	# only add perpindicular portion of players velocity onto shot velocity
	# so if you're walking up while shooting up, it won't slow or speed up the bullet.
	# But if you're walking right while shooting up, the bullet goes diagonal.
	var orth_factor = 0.75

	# shoutout chatgpt for the math
	var parallel = (velocity.dot(shot_dir)) * shot_dir
	var orth_vel = velocity - parallel

	var final_vel = main_vel + (orth_vel * orth_factor)

	projectile.velocity = final_vel

	projectile.scale = Vector2(1.5, 1.5)

	# CASE 1: standalone player node, no world --> spawn projectile in local space
	if get_parent().get_node("World") == null:
		projectile.position = spawn_offset
		add_child(projectile)
		return

	# CASE 2: player node is in world --> spawn projectile in world space
	# check if "Projectiles" node exists if in another scene
	if get_parent().get_parent().get_node("Projectiles") == null:
		print_debug("Projectiles node not found, projectile not spawned")
		return

	var projectiles_node = get_parent().get_parent().get_node("Projectiles")

	var local_spawn_pos = projectiles_node.to_local(spawn_global_position)
	projectile.position = local_spawn_pos

	projectiles_node.call_deferred("add_child", projectile)
