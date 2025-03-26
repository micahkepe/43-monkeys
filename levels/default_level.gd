extends Node2D
## Default level settings that all levels inherit.

## Duration of music track fade (in seconds)
@export var music_fade_duration: float = 4.0

## Reference to the current music fade tween object.
var _current_music_fade_tween: Tween = null

## Called when there is an input event. The input event propagates up through
## the node tree until a node consumes it.
func _input(event):
	if event.is_action_pressed("toggle_full_screen"):
		print("DebuggingFading: Toggle full screen pressed")
		# Toggle full screen mode
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			print("DebuggingFading: Switched to windowed mode")
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			print("DebuggingFading: Switched to fullscreen mode")

		# Reset all input actions to prevent "stuck" keys
		reset_input_actions()

## Helper function to release all actions that might be held down
func reset_input_actions():
	print("DebuggingFading: Resetting input actions")
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
			print("DebuggingFading: Released action:", action)


func fade_between_tracks(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print("DebuggingFading: Starting fade from:", from_track.name, "to:", to_track.name)
	print("DebuggingFading: Initial states - From track playing:", from_track.playing, "volume:", from_track.volume_db)
	print("DebuggingFading: Initial states - To track playing:", to_track.playing, "volume:", to_track.volume_db)

	# Cancel any existing fade tween
	if _current_music_fade_tween:
		_current_music_fade_tween.kill()
		print("DebuggingFading: Killed existing tween")

	# Store original volumes and set reasonable defaults if volumes are too low
	var from_volume_db = from_track.volume_db if from_track.volume_db > -40.0 else 0.0
	var to_volume_db = to_track.volume_db if to_track.volume_db > -40.0 else 0.0
	
	print("DebuggingFading: Original volumes - From:", from_volume_db, "To:", to_volume_db)

	# Start the new track at a slightly reduced but still audible volume
	# This prevents the silent gap at the beginning of the transition
	to_track.volume_db = -20.0  # Start at -20dB - quiet but immediately audible
	to_track.play()
	print("DebuggingFading: Started to_track:", to_track.name, "playing:", to_track.playing)

	# Create a single tween for both fading operations
	_current_music_fade_tween = create_tween()
	_current_music_fade_tween.set_parallel(true)  # Run both fade operations simultaneously

	# Use a shorter fade-out duration for the background track
	# This helps prevent the "silence gap" feeling
	var fade_out_duration = music_fade_duration * 0.7  # 70% of the full duration
	_current_music_fade_tween.tween_property(from_track, "volume_db", -80.0, fade_out_duration)
	_current_music_fade_tween.tween_property(to_track, "volume_db", to_volume_db, music_fade_duration)
	print("DebuggingFading: Started crossfade - fading out", from_track.name, "and fading in", to_track.name)

	# After both fades complete
	_current_music_fade_tween.tween_callback(func():
		print("DebuggingFading: Crossfade complete")
		from_track.stop()
		from_track.volume_db = from_volume_db  # Restore original volume for future use
		print("DebuggingFading: Stopped and reset", from_track.name, "to:", from_volume_db)
		print("DebuggingFading: Final states - To track playing:", to_track.playing, "volume:", to_track.volume_db)
	)

	# Debug: Track volume changes over time
	var elapsed = 0.0
	while elapsed < music_fade_duration:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if _current_music_fade_tween and _current_music_fade_tween.is_running():
			print("DebuggingFading: Time:", elapsed, "s - From volume:", from_track.volume_db, "To volume:", to_track.volume_db)
