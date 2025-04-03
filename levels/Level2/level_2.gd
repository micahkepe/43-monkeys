extends "res://levels/default_level.gd"
## Scripting logic for Level 2.

var _troop_data: Dictionary = {}

@export_group("Boss Variables")

## The RootBoss scene to instantiate.
@export var root_boss_scene: PackedScene

## A flag for whether the boss has spawned in the level scene yet.
var _boss_spawned: bool = false

## A reference to the RootBoss instance.
var boss_instance: Node = null

## A marker for whether the boss has died.
@onready var boss_dead = false

@onready var background_music = $BackgroundMusic
@onready var boss_music = $BossMusic

# -------------------------
# Puzzle internal variables
# -------------------------
@export_group("Puzzle Variables")

@onready var _buttons: Array[Node] = $World/Buttons.get_children()
@onready var _lasers: Array[Node] = $World/Lasers.get_children()

## Track which buttons are currently "pressed" (button name -> pressed state)
var _button_states: Dictionary[String, bool] = {}

## Puzzle 1: press Button[1-3] => unlock Laser1
var _laser1_deactivated = false

## Puzzle 2: press Button4 => unlock Laser2
var _laser2_deactivated = false

## Puzzle 3: press Button[5-7] => unlock Laser[3-4]
var _lasers_3_4_deactivated = false

### Gear puzzles

## Dictionary[Array[String], Array[String]] of gear(s) -> laser(s) unlocked
## upon all gear(s) spun completely.
@export var gears_to_lasers: Dictionary[Array, Array] = {
	["Gear1"]: ["Laser6"]
}

# -------------------------

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Audio nodes check - Background music exists:", background_music != null)
	print("Audio nodes check - Boss music exists:", boss_music != null)
	print("Audio stream check - Background music has stream:", background_music.stream != null)
	print("Audio stream check - Boss music has stream:", boss_music.stream != null)
	background_music.play()
	if not _troop_data.is_empty():
		initialize_from_troop_data()
	if has_node("World/BossTrigger"):
		$World/BossTrigger.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))

	for button in _buttons:
		_button_states[button.name] = false  # All buttons start as "unpressed"
		button.connect("body_entered", Callable(self, "_on_button_body_entered").bind(button))
		button.connect("body_exited", Callable(self, "_on_button_body_exited").bind(button))

    # Connect gear signals
	for gear_name in gears_to_lasers.keys():
		var gear = get_node("World/Gears/" + gear_name[0])
		if gear:
			gear.connect("gear_complete", Callable(self, "_on_gear_complete"))
		else:
			print("Warning: Gear node not found: ", gear_name[0])

func _on_button_body_entered(_body: Node, button: Node) -> void:
	_button_states[button.name] = true
	check_btn_puzzles()

func _on_button_body_exited(_body: Node, button: Node) -> void:
	_button_states[button.name] = false
	check_btn_puzzles()

func _on_gear_complete(gear_name: String) -> void:
	print("Gear completed: ", gear_name)

	# Check if this gear is part of the gears_to_lasers dictionary
	for gear_group in gears_to_lasers.keys():
		if gear_name in gear_group:
			# Check if all gears in this group are completed
			var all_gears_complete = true
			for g in gear_group:
				var gear_node = get_node("World/Gears/" + g)
				if gear_node and not gear_node.completed:
					all_gears_complete = false
					break

			# If all gears in the group are complete, deactivate the associated lasers
			if all_gears_complete:
				var lasers = gears_to_lasers[gear_group]
				for laser_name in lasers:
					var laser = get_node("World/Lasers/" + laser_name)
					if laser:
						laser.deactivate_laser()
						print("Deactivated laser: ", laser_name)
					else:
						print("Warning: Laser node not found: ", laser_name)


func check_btn_puzzles() -> void:
	# Puzzle 1: Button1, Button2, and Button3 unlock Laser1
	if are_buttons_pressed(["Button1", "Button2", "Button3"]):
		deactivate_laser_1()

	# Puzzle 2: Button4 unlocks Laser2
	if are_buttons_pressed(["Button4"]):
		deactivate_laser_2()

	# Puzzle 3: Button5, Button6, and Button7 unlock Lasers 3 and 4
	if are_buttons_pressed(["Button5", "Button6", "Button7"]):
		deactivate_lasers_3_and_4()

func are_buttons_pressed(names: Array[String]) -> bool:
	for btn_name in names:
		if not _button_states.get(btn_name, false):
			return false
	return true

func deactivate_laser_1() -> void:
	if _laser1_deactivated:
		return
	for laser in _lasers:
		if laser.name == "Laser1":
			laser.deactivate_laser()
			_laser1_deactivated = true
			return

func deactivate_laser_2() -> void:
	if _laser2_deactivated:
		return
	for laser in _lasers:
		if laser.name == "Laser2":
			laser.deactivate_laser()
			_laser2_deactivated = true
			return

func deactivate_lasers_3_and_4() -> void:
	if _lasers_3_4_deactivated:
		return
	for laser in _lasers:
		if laser.name in ["Laser3", "Laser4"]:
			laser.deactivate_laser()
	_lasers_3_4_deactivated = true


## Set the troop data for this level.
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
	if body.is_in_group("player") and not _boss_spawned:
		spawn_root_boss()
		_boss_spawned = true
	if background_music.playing and not boss_dead:
		fade_between_tracks(background_music, boss_music)

# A simplified, more robust fade transition function
func simple_fade_transition(from_track: AudioStreamPlayer, to_track: AudioStreamPlayer) -> void:
	print("Starting simplified fade transition")

	# Make sure the destination track is ready
	to_track.volume_db = -40.0  # Start at a very quiet level
	to_track.play()

	# Create separate tweens for fade-out and fade-in to avoid dependencies
	var fade_out = create_tween()
	fade_out.tween_property(from_track, "volume_db", -40.0, music_fade_duration)
	fade_out.tween_callback(func():
		from_track.stop()
	)

	# Small delay before starting fade-in to ensure they don't conflict
	await get_tree().create_timer(0.1).timeout

	# Now handle fade-in separately
	var fade_in = create_tween()
	fade_in.tween_property(to_track, "volume_db", 0.0, music_fade_duration)
	fade_in.tween_callback(func():
		print("Fade transition complete")
	)
