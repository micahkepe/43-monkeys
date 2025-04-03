extends "res://levels/default_level.gd"
## Script for Level 1 logic
##
## Basic tutorial level with boid enemy NPCs, laser puzzles, and the PotionBoss
## boss fight at the end. The troop can grow up to 6 by the end of the level.

# Scene tree references
@onready var buttons: Array[Node] = $World/Buttons.get_children()
@onready var lasers: Array[Node] = $ForegroundTiles/Lasers.get_children()
@onready var door = $World/Doors/Door
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var boss_music: AudioStreamPlayer = $BossMusic
@onready var potion_boss = $World/PotionBoss
@onready var boss_dead: bool = false

# Puzzle configuration
@export_group("Puzzle Variables")
## Button-to-laser puzzle configuration
@export var buttons_to_lasers: Dictionary[Array, Array] = {
	["Buttons1", "Buttons2"]: ["Laser1", "Laser2", "Laser3"],
	["Buttons3", "Buttons4", "Buttons5", "Buttons6"]: ["Laser4"]
}

# Preloaded node references
var _button_nodes: Dictionary[String, Node] = {}
var _laser_nodes: Dictionary[String, Node] = {}

# State tracking
var _button_states: Dictionary[String, bool] = {}
var _deactivated_lasers: Array[String] = []

# Level transition scenes
@export var transition_scene: PackedScene = preload("res://cutscenes/LevelTransition/level_transition.tscn")
@export var next_level_scene: PackedScene = preload("res://levels/Level2/level_2.tscn")

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	background_music.play()
	_preload_puzzle_nodes()
	_connect_button_signals()

# Preload button and laser nodes into dictionaries
func _preload_puzzle_nodes() -> void:
	for button in buttons:
		_button_nodes[button.name] = button
		_button_states[button.name] = false
	for laser in lasers:
		_laser_nodes[laser.name] = laser

# Connect button signals dynamically
func _connect_button_signals() -> void:
	for button_group in buttons_to_lasers.keys():
		for button_name in button_group:
			if _button_nodes.has(button_name):
				_button_nodes[button_name].connect("button_state_changed",
				Callable(self, "_on_button_state_changed").bind(_button_nodes[button_name]))
			else:
				print("Warning: Button node not found in scene: ", button_name)

# Button state change handler
func _on_button_state_changed(is_pressed: bool, button: Node) -> void:
	_button_states[button.name] = is_pressed
	_check_button_puzzles()

# Check button-based puzzles
func _check_button_puzzles() -> void:
	for button_group in buttons_to_lasers.keys():
		if _are_buttons_complete(button_group):
			_deactivate_lasers(buttons_to_lasers[button_group])

# Helper: Check if all buttons in a group are pressed
func _are_buttons_complete(button_group: Array) -> bool:
	for button_name in button_group:
		if not _button_states.get(button_name, false):
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

# Called every frame
func _process(_delta: float) -> void:
	check_boss_death()

# Check if the boss is dead and handle door/music transition
func check_boss_death() -> void:
	if potion_boss and potion_boss.is_dead and door and door.is_active and not boss_dead:
		door.open_door()
		print("Boss death detected - transitioning music")
		fade_between_tracks(boss_music, background_music)
		boss_dead = true


# Handle level transition when player enters trigger
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
		transition_instance.next_level_scene = next_level_scene
		transition_instance.level_number = 2
		transition_instance.level_title = "Bioscience Center"
		transition_instance.set_troop_data(troop_data)
		get_tree().root.add_child(transition_instance)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = transition_instance

# Handle boss music trigger
func _on_boss_music_trigger_body_entered(_body: Node2D) -> void:
	if background_music.playing and not boss_dead:
		fade_between_tracks(background_music, boss_music)
