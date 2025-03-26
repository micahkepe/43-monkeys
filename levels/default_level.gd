extends Node2D
## Default level settings that all levels inherit.

## Duration of music track fade (in seconds)
@export var music_fade_duration: float = 1.0

## Reference to the current music fade tween object.
var _current_music_fade_tween: Tween = null

## Called when there is an input event. The input event propagates up through
## the node tree until a node consumes it.
func _input(event):
	if event.is_action_pressed("toggle_full_screen"):
		# Toggle full screen mode
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

		# Reset all input actions to prevent "stuck" keys
		reset_input_actions()

## Helper function to release all actions that might be held down
func reset_input_actions():
	# Comprehensive list of actions from player.gd and standard UI actions
	var actions = [
		# Player movement
		"ui_right", "ui_left", "ui_up", "ui_down",
		# Swarm controls
		"rotate_swarm_clockwise", "toggle_lock",
		"translate_up", "translate_down", "translate_left", "translate_right",
		"inc_height_ellipse", "dec_height_ellipse",
		"inc_width_ellipse", "dec_width_ellipse",
		"reset_swarm",
		# Shooting
		"shoot_up", "shoot_down", "shoot_left", "shoot_right",
		# UI navigation (from menus)
		"ui_accept", "ui_cancel", "ui_select"
	]
	for action in actions:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func fade_between_tracks(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print("Starting fade from:", from_track.name, "to:", to_track.name)
	print("Initial states - From track playing:", from_track.playing, "volume:", from_track.volume_db)
	print("Initial states - To track playing:", to_track.playing, "volume:", to_track.volume_db)

	# Cancel any existing fade tween
	if _current_music_fade_tween:
		_current_music_fade_tween.kill()
		print("Killed existing tween")

	# Store original volumes
	var from_volume_db = from_track.volume_db
	var to_volume_db = to_track.volume_db if to_track.volume_db > -70.0 else 0.0  # Use 0.0 as default if too quiet

	print("Original volumes - From:", from_volume_db, "To:", to_volume_db)

	# Explicitly handle the transition
	to_track.volume_db = -80.0
	to_track.play()
	print("Started to_track:", to_track.name, "playing:", to_track.playing)

	# Create a new tween for fading
	_current_music_fade_tween = create_tween()

	# Fade out from_track
	_current_music_fade_tween.tween_property(from_track, "volume_db", -80.0, music_fade_duration)
	print("Started fade out of:", from_track.name)

	# After fade out completes
	_current_music_fade_tween.tween_callback(func():
		print("Fade out complete for:", from_track.name)
		from_track.stop()
		from_track.volume_db = from_volume_db
		print("Reset volume for:", from_track.name, "to:", from_volume_db)
	)

	# Create a separate tween for fading in (don't make it parallel to avoid timing issues)
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(to_track, "volume_db", to_volume_db, music_fade_duration)
	print("Started fade in of:", to_track.name, "to target volume:", to_volume_db)

	# After fade in completes
	fade_in_tween.tween_callback(func():
		print("Fade in complete for:", to_track.name)
		print("Final states - To track playing:", to_track.playing, "volume:", to_track.volume_db)
		)

