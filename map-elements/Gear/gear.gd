extends StaticBody2D
## A interactable gear puzzle element that the play can spin.
##
## This element can be interacted with for puzzles or game effects.

## The minimum distance away at which the player must be to interact (in pixels)
@export
var min_interact_distance: float = 100.0

## The time (in seconds) required for the gear to be considered fully spun.
@export
var unlock_time: float = 3.0

## Reference to the animated sprite node.
@onready var _animated_sprite: AnimatedSprite2D = get_node("AnimatedSprite2D")

## Reference to the animated sprite node.
@onready var _progress_bar: ProgressBar = get_node("ProgressBar")

## A flag for whether the gear has been fully spun.
var _fully_spun: bool = false

## Time spun so far (in seconds)
var _time_spun: float = 0.0

## Setter method to return the puzzle state of the gear.
var completed: bool:
	get:
		return _fully_spun

## Signal to be emitted when the gear is fully spun.
signal gear_complete(gear_name: String)

## Called upon scene initiation.
func _ready() -> void:
	# Ensure default (non-spinning) animation is playing at first
	_animated_sprite.play("default")

	# Initialize progress bar
	_progress_bar.value = _time_spun
	_progress_bar.max_value = unlock_time
	_progress_bar.visible = false


## Handle player interactions. Called once a frame in the game process function.
func _process(delta: float) -> void:

	# Called upon first frame that the user "just pressed" the interaction key
	if Input.is_action_just_pressed("interact") and not _fully_spun:
		var player = get_tree().get_first_node_in_group("player")

		# Spin the gear if the player is close enough
		if global_position.distance_to(player.global_position) <= min_interact_distance:
			spin()

	elif Input.is_action_pressed("interact"):
		_time_spun += delta
		_progress_bar.value = _time_spun

		if _time_spun >= unlock_time:
			_fully_spun = true
			_animated_sprite.play("default")
			gear_complete.emit(name)

	elif Input.is_action_just_released("interact"):
		_animated_sprite.play("default")
		if not _fully_spun:
			_progress_bar.visible = false

## Spins the gear. Will show the progress bar to show the user how complete the
## gear unlock is.
func spin() -> void:
	_progress_bar.visible = true
	_animated_sprite.play("spin")
