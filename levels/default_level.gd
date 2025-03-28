extends Node2D
## Default level settings that all levels inherit.

## Duration of music track fade (in seconds)
@export var music_fade_duration: float = 4.0

## Reference to the current music fade tween object.
var _current_music_fade_tween: Tween = null

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
