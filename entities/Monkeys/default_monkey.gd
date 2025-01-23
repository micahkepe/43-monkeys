extends CharacterBody2D

@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

##
# Called by the Player when we want this monkey to animate walking.
##
func walk_left() -> void:
	_anim_sprite.play("walk_left")

func walk_right() -> void:
	_anim_sprite.play("walk_right")

func walk_up() -> void:
	_anim_sprite.play("walk_up")

func walk_down() -> void:
	_anim_sprite.play("walk_down")
	

##
# Called by the Player when no swarm-translation key is pressed (monkey idle)
##
func stop_walk() -> void:
	_anim_sprite.stop()

func _physics_process(delta: float) -> void:
	# No movement logic: The Player script controls the monkey’s position directly.
	pass
