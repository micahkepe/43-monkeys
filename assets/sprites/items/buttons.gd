extends Area2D
## A button that can be pressed or unpressed by stepping on or off the button

@onready var _animated_sprite = $AnimatedSprite2D
signal button_pressed
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_animated_sprite.play("just_unpressed")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_body_entered(body: Node2D) -> void:
	print("collided")
	_animated_sprite.play("unpressed_to_pressed")
	_animated_sprite.play("just_pressed")
	emit_signal("button_pressed")
	

func _on_body_exited(body: Node2D) -> void:
	_animated_sprite.play("pressed_to_unpressed")
	_animated_sprite.play("just_unpressed")
	print("exited")
