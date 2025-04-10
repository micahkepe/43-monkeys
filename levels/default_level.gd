extends Node2D
## Default level settings that all levels inherit.

## Duration of music track fade (in seconds)
@export var music_fade_duration: float = 4.0

## Reference to the current music fade tween object.
var _current_music_fade_tween: Tween = null

# Puzzle configuration
@onready var _buttons: Array[Node] = $World/Buttons.get_children()
@onready var _lasers: Array[Node] = $World/Lasers.get_children()
@onready var _gears: Array[Node] = $World/Gears.get_children()

## Button-to-laser puzzle configuration
@export var buttons_to_lasers: Dictionary[Array, Array] = {}
@export var gears_to_lasers: Dictionary[Array, Array] = {}

# Preloaded node references
var _button_nodes: Dictionary[String, Node] = {}
var _laser_nodes: Dictionary[String, Node] = {}
var _gear_nodes: Dictionary[String, Node] = {}

# State tracking
var _button_states: Dictionary[String, bool] = {}
var _deactivated_lasers: Array[String] = []

# Connect button signals dynamically
func _connect_button_signals() -> void:
	for button_group in buttons_to_lasers.keys():
		for button_name in button_group:
			if _button_nodes.has(button_name):
				_button_nodes[button_name].connect("button_state_changed",
				Callable(self, "_on_button_state_changed").bind(_button_nodes[button_name]))
			else:
				print("Warning: Button node not found in scene: ", button_name)

# Connect gear signals dynamically
func _connect_gear_signals() -> void:
	for gear_group in gears_to_lasers.keys():
		for gear_name in gear_group:
			if _gear_nodes.has(gear_name):
				_gear_nodes[gear_name].connect("gear_complete", Callable(self, "_on_gear_complete"))
			else:
				print("Warning: Gear node not found in scene: ", gear_name)


# Button state change handler
func _on_button_state_changed(is_pressed: bool, button: Node) -> void:
	_button_states[button.name] = is_pressed
	_check_button_puzzles()

# Check button-based puzzles
func _check_button_puzzles() -> void:
	for button_group in buttons_to_lasers.keys():
		if _are_buttons_complete(button_group):
			_deactivate_lasers(buttons_to_lasers[button_group])

# Check gear-based puzzles
func _check_gear_puzzles(completed_gear: Node) -> void:
	for gear_group in gears_to_lasers.keys():
		if completed_gear.name in gear_group:
			if _are_gears_complete(gear_group):
				_deactivate_lasers(gears_to_lasers[gear_group])

# Gear completion handler
func _on_gear_complete(gear: Node) -> void:
	print("Gear completed: ", gear.name)
	_check_gear_puzzles(gear)

# Helper: Check if all buttons in a group are pressed
func _are_buttons_complete(button_group: Array) -> bool:
	for button_name in button_group:
		if not _button_states.get(button_name, false):
			return false
	return true

# Helper: Check if all gears in a group are complete
func _are_gears_complete(gear_group: Array) -> bool:
	for gear_name in gear_group:
		if not _gear_nodes[gear_name].completed:
			return false
	return true

# Helper: Deactivate multiple _lasers
func _deactivate_lasers(laser_names: Array) -> void:
	for laser_name in laser_names:
		if laser_name not in _deactivated_lasers and _laser_nodes.has(laser_name):
			_laser_nodes[laser_name].deactivate_laser()
			_deactivated_lasers.append(laser_name)
			print("Deactivated laser: ", laser_name)
		elif not _laser_nodes.has(laser_name):
			print("Warning: Laser node not found: ", laser_name)

# Preload button, gear, and laser nodes into dictionaries
func _preload_puzzle_nodes() -> void:
	for gear in _gears:
		_gear_nodes[gear.name] = gear
	for button in _buttons:
		_button_nodes[button.name] = button
		_button_states[button.name] = false
	for laser in _lasers:
		_laser_nodes[laser.name] = laser


func _ready() -> void:
	# Load puzzle state
	_preload_puzzle_nodes()
	_connect_button_signals()
	_connect_gear_signals()


func fade_between_tracks(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print_debug("Starting fade from:", from_track.name, "to:", to_track.name)
	print_debug("Initial states - From track playing:", from_track.playing, "volume:", from_track.volume_db)
	print_debug("Initial states - To track playing:", to_track.playing, "volume:", to_track.volume_db)

	# Cancel any existing fade tween
	if _current_music_fade_tween:
		_current_music_fade_tween.kill()
		print_debug("Killed existing tween")

	# Store original volumes and set reasonable defaults if volumes are too low
	var from_volume_db = from_track.volume_db if from_track.volume_db > -40.0 else 0.0
	var to_volume_db = to_track.volume_db if to_track.volume_db > -40.0 else 0.0

	print_debug("Original volumes - From:", from_volume_db, "To:", to_volume_db)

	# Start the new track at a slightly reduced but still audible volume
	# This prevents the silent gap at the beginning of the transition
	to_track.volume_db = -20.0  # Start at -20dB - quiet but immediately audible
	to_track.play()
	print_debug("Started to_track:", to_track.name, "playing:", to_track.playing)

	# Create a single tween for both fading operations
	_current_music_fade_tween = create_tween()
	_current_music_fade_tween.set_parallel(true)  # Run both fade operations simultaneously

	# Use a shorter fade-out duration for the background track
	# This helps prevent the "silence gap" feeling
	var fade_out_duration = music_fade_duration * 0.7  # 70% of the full duration
	_current_music_fade_tween.tween_property(from_track, "volume_db", -80.0, fade_out_duration)
	_current_music_fade_tween.tween_property(to_track, "volume_db", to_volume_db, music_fade_duration)
	print_debug("Started crossfade - fading out", from_track.name, "and fading in", to_track.name)

	# After both fades complete
	_current_music_fade_tween.tween_callback(func():
		print_debug("Crossfade complete")
		from_track.stop()
		from_track.volume_db = from_volume_db  # Restore original volume for future use
		print_debug("Stopped and reset", from_track.name, "to:", from_volume_db)
		print_debug("Fading: Final states - To track playing:", to_track.playing, "volume:", to_track.volume_db)
	)

	# Debug: Track volume changes over time
	var elapsed = 0.0
	while elapsed < music_fade_duration:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if _current_music_fade_tween and _current_music_fade_tween.is_running():
			print_debug("Time:", elapsed, "s - From volume:", from_track.volume_db, "To volume:", to_track.volume_db)
