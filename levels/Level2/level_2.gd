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

# -------------------------
# Puzzle internal variables
# -------------------------
@export_group("Puzzle Variables")

@onready var _buttons: Array[Node] = $World/Buttons.get_children()
@onready var _lasers: Array[Node] = $World/Lasers.get_children()
@onready var _gears: Array[Node] = $World/Gears.get_children()

## Track button states (button name -> pressed state)
var _button_states: Dictionary[String, bool] = {}

## Button-to-laser puzzle configuration
@export var buttons_to_lasers: Dictionary[Array, Array] = {
	["Button1", "Button2", "Button3"]: ["Laser1"],
	["Button4"]: ["Laser2"],
	["Button5", "Button6", "Button7"]: ["Laser3", "Laser4"]
}

## Gear-to-laser puzzle configuration
@export var gears_to_lasers: Dictionary[Array, Array] = {
	["Gear1"]: ["Laser6"],
	["Gear2"]: ["Laser5"]
}

## Preloaded node references for quick access
var _gear_nodes: Dictionary[String, Node] = {}
var _laser_nodes: Dictionary[String, Node] = {}
var _button_nodes: Dictionary[String, Node] = {}

## Track deactivated laser states to prevent re-deactivation
var _deactivated_lasers: Array[String] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Audio setup
	_validate_audio_nodes()
	background_music.play()

	# Troop initialization
	if not _troop_data.is_empty():
		initialize_from_troop_data()

	# Boss trigger setup
	if has_node("World/BossTrigger"):
		$World/BossTrigger.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))

	# Preload puzzle nodes and connect signals
	_preload_puzzle_nodes()
	_connect_gear_signals()
	_connect_button_signals()

# Audio validation helper
func _validate_audio_nodes() -> void:
	print("Audio nodes check - Background music exists:", background_music != null)
	print("Audio nodes check - Boss music exists:", boss_music != null)
	print("Audio stream check - Background music has stream:", background_music.stream != null)
	print("Audio stream check - Boss music has stream:", boss_music.stream != null)

# Preload gear, laser, and button nodes into dictionaries
func _preload_puzzle_nodes() -> void:
	for gear in _gears:
		_gear_nodes[gear.name] = gear
	for laser in _lasers:
		_laser_nodes[laser.name] = laser
	for button in _buttons:
		_button_nodes[button.name] = button
		_button_states[button.name] = false

# Connect gear signals dynamically
func _connect_gear_signals() -> void:
	for gear_group in gears_to_lasers.keys():
		for gear_name in gear_group:
			if _gear_nodes.has(gear_name):
				_gear_nodes[gear_name].connect("gear_complete", Callable(self, "_on_gear_complete"))
			else:
				print("Warning: Gear node not found in scene: ", gear_name)

# Connect button signals dynamically
func _connect_button_signals() -> void:
	for button_group in buttons_to_lasers.keys():
		for button_name in button_group:
			if _button_nodes.has(button_name):
				_button_nodes[button_name].connect("body_entered", Callable(self, "_on_button_body_entered").bind(_button_nodes[button_name]))
				_button_nodes[button_name].connect("body_exited", Callable(self, "_on_button_body_exited").bind(_button_nodes[button_name]))
			else:
				print("Warning: Button node not found in scene: ", button_name)

# Button signal handlers
func _on_button_body_entered(_body: Node, button: Node) -> void:
	_button_states[button.name] = true
	_check_button_puzzles()

func _on_button_body_exited(_body: Node, button: Node) -> void:
	_button_states[button.name] = false
	_check_button_puzzles()

# Gear completion handler
func _on_gear_complete(gear: Node) -> void:
	print("Gear completed: ", gear.name)
	_check_gear_puzzles(gear)

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

# Helper: Deactivate multiple lasers
func _deactivate_lasers(laser_names: Array) -> void:
	for laser_name in laser_names:
		if laser_name not in _deactivated_lasers and _laser_nodes.has(laser_name):
			_laser_nodes[laser_name].deactivate_laser()
			_deactivated_lasers.append(laser_name)
			print("Deactivated laser: ", laser_name)
		elif not _laser_nodes.has(laser_name):
			print("Warning: Laser node not found: ", laser_name)

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
	if boss_instance and boss_instance.is_dead and not boss_dead:
		print("Boss death detected - transitioning music")

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

