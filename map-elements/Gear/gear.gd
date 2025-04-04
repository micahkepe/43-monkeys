extends StaticBody2D
## An interactable gear puzzle element that the player can spin.

## The minimum distance away at which the player must be to interact (in pixels)
@export
var min_interact_distance: float = 100.0

## The time (in seconds) required for the gear to be considered fully spun.
@export
var unlock_time: float = 3.0

## Reference to the animated sprite node.
@onready var _animated_sprite: AnimatedSprite2D = get_node("AnimatedSprite2D")

## Reference to the progress bar node.
@onready var _progress_bar: ProgressBar = get_node("ProgressBar")

## A flag for whether the gear has been fully spun.
var _fully_spun: bool = false

## Time spun so far (in seconds)
var _time_spun: float = 0.0

## Whether the gear is currently being spun.
var _is_spinning: bool = false

## Getter method to return the puzzle state of the gear.
var completed: bool:
	get:
		return _fully_spun

## Signal to be emitted when the gear is fully spun.
signal gear_complete(gear: Node)

## Called upon scene initiation.
func _ready() -> void:
	# Ensure default (non-spinning) animation is playing at first
	_animated_sprite.play("default")

	# Initialize progress bar
	_progress_bar.value = _time_spun
	_progress_bar.max_value = unlock_time
	_progress_bar.visible = false
	add_to_group("gears")  # Add to group for closest gear check


## Handle player interactions. Called once a frame.
func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or _fully_spun:
		return

	var distance = global_position.distance_to(player.global_position)
	if distance > min_interact_distance:
		if _is_spinning:
			stop_spinning()
		return

	# Only spin if this is the closest gear
	var is_closest = true
	for gear in get_tree().get_nodes_in_group("gears"):
		if gear != self and not gear.completed:
			if gear.global_position.distance_to(player.global_position) < distance:
				is_closest = false
				break

	if not is_closest:
		if _is_spinning:
			stop_spinning()
		return

	if Input.is_action_just_pressed("interact"):
		start_spinning()
	elif Input.is_action_pressed("interact") and _is_spinning:
		_time_spun += delta
		_progress_bar.value = _time_spun

		if _time_spun >= unlock_time:
			_fully_spun = true
			_animated_sprite.play("default")
			_progress_bar.visible = false
			_is_spinning = false
			print_debug(name, ": Emitting gear_complete")
			gear_complete.emit(self)

	elif Input.is_action_just_released("interact"):
		stop_spinning()


## Start spinning the gear.
func start_spinning() -> void:
	if not _is_spinning:
		_is_spinning = true
		_progress_bar.visible = true
		_animated_sprite.play("spin")


## Stop spinning the gear.
func stop_spinning() -> void:
	if _is_spinning:
		_is_spinning = false
		_animated_sprite.play("default")
		if not _fully_spun:
			_progress_bar.visible = false

