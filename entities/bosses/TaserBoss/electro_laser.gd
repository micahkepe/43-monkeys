extends Area2D

@onready var _animated_sprite = $AnimatedSprite2D

func _ready() -> void:
	# connect the animation_finished signal
	_animated_sprite.animation_finished.connect(_on_animation_finished)

	# Play the start_up animation
	_animated_sprite.play("start_up")

func _on_animation_finished():
	if _animated_sprite.animation == "start_up":
		_animated_sprite.play("idle")
