extends "res://levels/default_level.gd"
## Scripting logic for Level 2.

# Core level data
var _troop_data: Dictionary = {}

@export_group("Boss Variables")

## The RootBoss scene to instantiate.
@export var root_boss_scene: PackedScene

## A flag for whether the boss has spawned in the level scene yet.
var _boss_spawned: bool = false

## A reference to the RootBoss instance.
var boss_instance: Node = null

## Marker flag for whether the boss is dead.
@onready var boss_dead: bool = false

## Reference to the bg music player.
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

## Reference to the boss music player.
@onready var boss_music: AudioStreamPlayer = $BossMusic

@onready var door = $World/Doors/Door

@export var transition_scene: PackedScene = preload("res://cutscenes/LevelTransition/level_transition.tscn")
@export var next_scene: PackedScene = preload("res://levels/Level5/level_5.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## Button-to-laser puzzle configuration
	buttons_to_lasers = {
		["Button1", "Button2", "Button3"]: ["Laser1"],
		["Button4"]: ["Laser2"],
		["Button5", "Button6", "Button7"]: ["Laser3", "Laser4"]
	}

	## Gear-to-laser puzzle configuration
	gears_to_lasers = {
		["Gear1"]: ["Laser6"],
		["Gear2"]: ["Laser5"]
	}

	super._ready()

	# Audio setup
	_validate_audio_nodes()
	background_music.play()

	# Troop initialization
	if not _troop_data.is_empty():
		initialize_from_troop_data()

	# Boss trigger setup
	if has_node("World/BossTrigger"):
		$World/BossTrigger.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))


# Audio validation helper
func _validate_audio_nodes() -> void:
	print("Audio nodes check - Background music exists:", background_music != null)
	print("Audio nodes check - Boss music exists:", boss_music != null)
	print("Audio stream check - Background music has stream:", background_music.stream != null)
	print("Audio stream check - Boss music has stream:", boss_music.stream != null)

# Troop data setters and initializers
func set_troop_data(data: Dictionary) -> void:
	_troop_data = data

## Initialize the player and troop from the troop data.
func initialize_from_troop_data() -> void:
	var player = $World/Player
	if player and not _troop_data.is_empty():
		player.health = _troop_data["player_health"]
		# Recreate troop
		var current_count = player.get_troop_count()
		var target_count = _troop_data["count"]
		var monkey_health = _troop_data.get("monkey_health", [])

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
	if boss_instance and boss_instance.is_dead and not boss_dead and door and door.is_active and not boss_dead:
		print("Boss death detected - transitioning music")
		
		door.open_door()
		# Simple fade transition with safeguards
		simple_fade_transition(boss_music, background_music)

		boss_dead = true
		
		

## Spawn the RootBoss.
func spawn_root_boss() -> void:
	if not root_boss_scene:
		print("Error: RootBoss scene not set!")
		return

	boss_instance = root_boss_scene.instantiate()
	# Set the spawn position (center of the room)
	@warning_ignore("integer_division")
	var room_center = Vector2((1779 + 3016) / 2, (-3798 + -2446) / 2)
	boss_instance.global_position = room_center

	# Use call_deferred to avoid "flushing queries" error
	$World.call_deferred("add_child", boss_instance)
	print("RootBoss spawned at: ", boss_instance.global_position)

## Called when a body enters the boss trigger area.
func _on_boss_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _boss_spawned:
		spawn_root_boss()
		_boss_spawned = true
	if background_music.playing and not boss_dead:
		fade_between_tracks(background_music, boss_music)

# A simplified, more robust fade transition function
func simple_fade_transition(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	to_track.volume_db = -40.0
	to_track.play()
	var fade_out = create_tween()
	fade_out.tween_property(from_track, "volume_db", -40.0, music_fade_duration)
	fade_out.tween_callback(func(): from_track.stop())
	await get_tree().create_timer(0.1).timeout
	var fade_in = create_tween()
	fade_in.tween_property(to_track, "volume_db", 0.0, music_fade_duration)
	fade_in.tween_callback(func(): print("Fade transition complete"))


func _on_next_scene_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Transition to next level
		var player = $World/Player
		var troop_count = player.get_troop_count() if player else 6
		var monkey_health = []
		if player:
			for monkey in player.get_troop():
				# Use current_health instead of health
				monkey_health.append(monkey.current_health if "current_health" in monkey else 6.0)

		var troop_data = {
			"count": troop_count,
			"player_health": player.health if player else 6.0,
			"monkey_health": monkey_health
		}

		if player:
			player.heal(player.max_health - player.health)

		var transition_instance = transition_scene.instantiate()
		transition_instance.next_scene = next_scene
		transition_instance.level_number = 5
		transition_instance.level_title = "Neuroscience Lab"
		transition_instance.set_troop_data(troop_data)
		get_tree().root.add_child(transition_instance)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = transition_instance
