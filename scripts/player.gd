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

## The multiplier applied to speed when sprinting
@export
var sprint_multiplier: float = 2

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	pass

## Called every frame.
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame in seconds.
func _physics_process(delta: float) -> void:
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
