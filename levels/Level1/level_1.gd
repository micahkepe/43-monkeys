extends "res://levels/default_level.gd"
## Script for Level 1 logic
##
## Basic tutorial level with boid enemy NPCs, laser puzzles and the PotionBoss
## boss fight at the end. The troop can grow up to 6 by the end of the level.

# Get all buttons and lasers from the scene tree.
@onready var buttons = $World/Buttons.get_children()
@onready var lasers = $ForegroundTiles/Lasers.get_children()

## A dictionary to track the state of each button.
var _button_states = {}

#------------------------------------------------------------------
# PUZZLE FLAGS
#------------------------------------------------------------------

## Tracker for whether the lasers 1, 2, 3 are deactivated (first button puzzle)
var _lasers_1_2_3_deactivated: bool = false

## Tracker for whether the laser 4 is deactivated (second button puzzle)
var _laser_4_deactivated: bool = false

## Scene for level transition to level 2.
@export var transition_scene: PackedScene = preload("res://cutscenes/LevelTransition/level_transition.tscn")
@export var next_level_scene: PackedScene = preload("res://levels/Level2/level_2.tscn")

## Track the boss.
@onready var potion_boss = $World/PotionBoss

#############

func _ready() -> void:
	for button in buttons:
		# Initialize each button's state as false (not pressed)
		_button_states[button] = false
		# Connect the button's signal to our callback.
		# (Note: we bind the button node so our callback knows which button sent the signal.)
		button.connect("button_state_changed", Callable(self, "on_button_state_changed").bind(button))

# This callback is called whenever a button's state changes.
func on_button_state_changed(is_pressed: bool, button: Node) -> void:
	_button_states[button] = is_pressed

	# Check if both Buttons 1 and Buttons 2 are pressed.
	if are_buttons_1_2_pressed():
		deactivate_lasers_1_2_3()
		_lasers_1_2_3_deactivated = true

	# Check if Buttons 3, 4, 5, 6 are all pressed
	if are_buttons_3_4_5_6_pressed():
		deactivate_laser_4()
		_laser_4_deactivated = true

# Returns true only if both Buttons 1 and Buttons 2 are pressed.
func are_buttons_1_2_pressed() -> bool:
	for button in _button_states.keys():
		if button.name in ["Buttons1", "Buttons2"]:
			if not _button_states[button]:
				return false
	return true

# Returns true only if Buttons 3, 4, 5, 6 are all pressed.
func are_buttons_3_4_5_6_pressed() -> bool:
	for button in _button_states.keys():
		if button.name in ["Buttons3", "Buttons4", "Buttons5", "Buttons6"]:
			if not _button_states[button]:
				return false
	return true

# Iterates through all lasers and deactivates lasers 1-3
func deactivate_lasers_1_2_3() -> void:
	# already done
	if _lasers_1_2_3_deactivated:
		return
	for laser in lasers:
		if laser.name in ["Laser1", "Laser2", "Laser3"]:
			laser.deactivate_laser()

# Deactivates Laser 4 when all required buttons are pressed.
func deactivate_laser_4() -> void:
	# you already completed this, no need to deactivate again
	if _laser_4_deactivated:
		return
	for laser in lasers:
		if laser.name == "Laser4":
			laser.deactivate_laser()

## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	check_boss_death()

## Check if the boss is dead and transition to the next level.
func check_boss_death() -> void:
	if potion_boss and potion_boss.is_dead:
		var player = $World/Player
		var troop_count = player.get_troop_count() if player else 6
		var monkey_health = []
		if player:
			for monkey in player.get_troop():
				monkey_health.append(monkey.health if "health" in monkey else 6.0)
		
		var troop_data = {
			"count": troop_count,
			"player_health": player.health if player else 6.0,
			"monkey_health": monkey_health
		}
		
		if player:
			player.heal(player.max_health - player.health)
			for monkey in player.get_troop():
				if "health" in monkey and "max_health" in monkey:
					monkey.health = monkey.max_health
		
		var transition_instance = transition_scene.instantiate()
		transition_instance.next_level_scene = next_level_scene
		transition_instance.level_number = 2  # Set the level number explicitly
		transition_instance.level_title = "The Next Challenge"  # Just the subtitle
		transition_instance.set_troop_data(troop_data)
		get_tree().root.add_child(transition_instance)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = transition_instance
