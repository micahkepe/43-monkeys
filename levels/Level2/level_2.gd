extends "res://levels/default_level.gd"

var troop_data: Dictionary = {}

@export var root_boss_scene: PackedScene  # Assign res://entities/bosses/RootBoss/root_boss.tscn in the editor
var boss_spawned: bool = false
var boss_instance: Node = null
@onready var boss_dead = false

@onready var background_music = $BackgroundMusic
@onready var boss_music = $BossMusic
@export var fade_duration: float = 1.0  # Duration of fade in seconds
var _current_fade_tween: Tween = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Audio nodes check - Background music exists:", background_music != null)
	print("Audio nodes check - Boss music exists:", boss_music != null)
	print("Audio stream check - Background music has stream:", background_music.stream != null)
	print("Audio stream check - Boss music has stream:", boss_music.stream != null)
	background_music.play()
	if not troop_data.is_empty():
		initialize_from_troop_data()
	if has_node("World/BossTrigger"):
		$World/BossTrigger.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))

## Set the troop data for this level.
func set_troop_data(data: Dictionary) -> void:
	troop_data = data

## Initialize the player and troop from the troop data.
func initialize_from_troop_data() -> void:
	var player = $World/Player
	if player and not troop_data.is_empty():
		player.health = troop_data["player_health"]
		# Recreate troop
		var current_count = player.get_troop_count()
		var target_count = troop_data["count"]
		var monkey_health = troop_data.get("monkey_health", [])
		
		# Remove excess monkeys if any
		while current_count > target_count:
			if player._swarm_monkeys.size() > 0:
				var monkey = player._swarm_monkeys.pop_back()["node"]
				monkey.queue_free()
			current_count -= 1
		
		# Add missing monkeys
		while current_count < target_count:
			player.add_monkey_to_swarm()
			current_count += 1
		
		# Restore monkey health if tracked
		if not monkey_health.is_empty():
			for i in range(min(player._swarm_monkeys.size(), monkey_health.size())):
				var monkey = player._swarm_monkeys[i]["node"]
				if "current_health" in monkey and "health_bar" in monkey:
					monkey.current_health = monkey_health[i]
					
					# Ensure the health bar is properly initialized and visible
					if monkey.health_bar:
						monkey.health_bar.value = monkey.current_health
						monkey.health_bar.health = monkey.current_health
						monkey.health_bar.show()  # Always show health bar, regardless of health value
					
					print_debug("Restored monkey #", i, " health to: ", monkey.current_health)

## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	check_boss_death()

## Check if the boss is dead and transition to the next level.
func check_boss_death() -> void:
	if boss_instance and boss_instance.is_dead and not boss_dead:
		print("Boss death detected - transitioning music")
		
		# Simple fade transition with safeguards
		simple_fade_transition(boss_music, background_music)
		
		boss_dead = true
		
## Spawn the RootBoss at a specific position.
func spawn_root_boss() -> void:
	if not root_boss_scene:
		print("Error: RootBoss scene not set!")
		return
	
	boss_instance = root_boss_scene.instantiate()
	# Set the spawn position (center of the room)
	@warning_ignore("integer_division")
	var room_center = Vector2((1779 + 3016) / 2, (-3798 + -2446) / 2)  # (2397.5, -3122)

	boss_instance.global_position = room_center
	
	# Use call_deferred to avoid "flushing queries" error
	$World.call_deferred("add_child", boss_instance)
	print("RootBoss spawned at: ", boss_instance.global_position)

## Called when a body enters the boss trigger area.
func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not boss_spawned:
		spawn_root_boss()
		boss_spawned = true
	if background_music.playing and not boss_dead:
		fade_between_tracks(background_music, boss_music)
		
func fade_between_tracks(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print("Starting fade from:", from_track.name, "to:", to_track.name)
	print("Initial states - From track playing:", from_track.playing, "volume:", from_track.volume_db)
	print("Initial states - To track playing:", to_track.playing, "volume:", to_track.volume_db)
	
	# Cancel any existing fade tween
	if _current_fade_tween:
		_current_fade_tween.kill()
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
	_current_fade_tween = create_tween()
	
	# Fade out from_track
	_current_fade_tween.tween_property(from_track, "volume_db", -80.0, fade_duration)
	print("Started fade out of:", from_track.name)
	
	# After fade out completes
	_current_fade_tween.tween_callback(func():
		print("Fade out complete for:", from_track.name)
		from_track.stop()
		from_track.volume_db = from_volume_db
		print("Reset volume for:", from_track.name, "to:", from_volume_db)
	)
	
	# Create a separate tween for fading in (don't make it parallel to avoid timing issues)
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(to_track, "volume_db", to_volume_db, fade_duration)
	print("Started fade in of:", to_track.name, "to target volume:", to_volume_db)
	
	# After fade in completes
	fade_in_tween.tween_callback(func():
		print("Fade in complete for:", to_track.name)
		print("Final states - To track playing:", to_track.playing, "volume:", to_track.volume_db)
	)

# A simplified, more robust fade transition function
func simple_fade_transition(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print("Starting simplified fade transition")
	
	# Make sure the destination track is ready
	to_track.volume_db = -40.0  # Start at a very quiet level
	to_track.play()
	
	# Create separate tweens for fade-out and fade-in to avoid dependencies
	var fade_out = create_tween()
	fade_out.tween_property(from_track, "volume_db", -40.0, fade_duration)
	fade_out.tween_callback(func():
		from_track.stop()
	)
	
	# Small delay before starting fade-in to ensure they don't conflict
	await get_tree().create_timer(0.1).timeout
	
	# Now handle fade-in separately
	var fade_in = create_tween()
	fade_in.tween_property(to_track, "volume_db", 0.0, fade_duration)
	fade_in.tween_callback(func():
		print("Fade transition complete")
	)
