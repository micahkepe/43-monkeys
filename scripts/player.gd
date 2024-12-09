extends CharacterBody2D
## Represents the player character in the game.
##
## The player character is controlled by the player and can move in four 
## directions (up, down, left, right). The player's movement is controlled by
## input mappings defined in the project settings for the following actions: 
## - ui_right: Move right 
## - ui_left: Move left 
## - ui_up: Move up 
## - ui_down: Move down 
##

## The AnimatedSprite2D node that displays the player's sprite.
@onready var _animated_sprite = $AnimatedSprite2D 

## The speed at which the player moves
@export 
var speed: float = 250.0

## Called when the node enters the scene tree for the first time.
## Initializes any setup required for the player character.
func _ready() -> void:
	pass

## Called every frame. 
## Handles input and updates the player's position and animation.
## @param delta: float - The elapsed time since the previous frame.
func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	
	# Movement input
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
		_animated_sprite.play("walk_right")
	elif Input.is_action_pressed("ui_left"):
		velocity.x -= 1
		_animated_sprite.play("walk_left")
	elif Input.is_action_pressed("ui_up"):
		velocity.y -= 1
		_animated_sprite.play("walk_up")
	elif Input.is_action_pressed("ui_down"):
		velocity.y += 1
		_animated_sprite.play("walk_down")
	else:
		_animated_sprite.stop()
	
	# Normalize diagonal movement
	if velocity != Vector2.ZERO:
			velocity = velocity.normalized()
	
	# Apply movement
	position += velocity * speed * delta
