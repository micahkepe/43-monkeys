extends CharacterBody2D
## A single monkey in the monkey troop.
##
## This script is responsible for playing the monkey's walking animation when
## the monkey is moving. The Player script controls the monkey's position
## directly.

## The AnimatedSprite2D node that plays the monkey's walking animation.
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Called by the Player when the player is moving left
func walk_left() -> void:
	_anim_sprite.play("walk_left")

## Called by the Player when the player is moving right
func walk_right() -> void:
	_anim_sprite.play("walk_right")

## Called by the Player when the player is moving up
func walk_up() -> void:
	_anim_sprite.play("walk_up")

## Called by the Player when the player is moving down
func walk_down() -> void:
	_anim_sprite.play("walk_down")

## Called by the Player when no swarm-translation key is pressed (monkey idle)
func stop_walk() -> void:
	_anim_sprite.stop()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# No movement logic: The Player script controls the monkey’s position directly.
	pass
