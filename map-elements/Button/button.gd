extends Area2D
## A button that can be pressed or unpressed by stepping on or off the button
##
## The button will animate when pressed or unpressed. The button will also
## emit a signal when pressed or unpressed.

## The AnimatedSprite2D node that will animate the button
@onready var _animated_sprite = $AnimatedSprite2D

## Tracks if the button is currently pressed
var is_pressed = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_animated_sprite.play("just_unpressed")


## Handles the body_entered signal
func _on_body_entered(_body: Node2D) -> void:
	if not is_pressed:
		is_pressed = true
		_animated_sprite.play("unpressed_to_pressed")
		_animated_sprite.play("just_pressed")

## Handles the body_exited signal
func _on_body_exited(_body: Node2D) -> void:
	if is_pressed:
		is_pressed = false
		_animated_sprite.play("pressed_to_unpressed")
		_animated_sprite.play("just_unpressed")
